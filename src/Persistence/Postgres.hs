{-# LANGUAGE OverloadedStrings #-}

module Persistence.Postgres
  ( Store
  , guardPersona
  , selectedPersonaId
  , withStore
  , loadGameView
  , resolveState
  , StoreError (..)
  , authenticate
  , completeCasting
  , contemplateEvent
  , contemplationCosts
  , contemplationContext
  , createQuestion
  , deleteQuestion
  , getGameView
  , login
  , migrate
  , newCasting
  , newStore
  , nextCasting
  , register
  , saveJournal
  , updateQuestion
  )
where

import Control.Exception (Exception, bracket, throwIO, try)
import Crypto.BCrypt (hashPasswordUsingPolicy, slowerBcryptHashingPolicy, validatePassword)
import Crypto.Random (getRandomBytes)
import qualified Data.ByteString as BS
import Data.Char (isAlphaNum)
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Database.PostgreSQL.Simple
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import qualified Database.PostgreSQL.Simple.Newtypes as PG
import Domain.Persona (Persona, personaPrompt)
import Domain.Game
import qualified Persistence.PersonaSchema as PersonaSchema
import Domain.Contemplation
import Domain.Types (DomainData (..), LeelaState (..))
import Engine.Casting (CastingResult, CastingState, initialCastingState, nextCastingState, result)
import Engine.Game (accessibleStateIds, applyCastingMovement)
import Interpretation.ContemplationModel (ContemplationModel (..), ModelError (..))
import Numeric (showHex)
import Data.Word (Word8)

newtype Store = Store BS.ByteString

data StoreError
  = InvalidCredentials
  | UsernameTaken
  | InvalidInput Text
  | NotFound Text
  | Conflict Text
  | CorruptData Text
  | ExternalService Text
  deriving (Eq, Show)

instance Exception StoreError

newStore :: BS.ByteString -> Store
newStore = Store

withStore :: Store -> (Connection -> IO a) -> IO a
withStore (Store connectionString) =
  bracket (connectPostgreSQL connectionString) close

migrate :: Store -> IO ()
migrate store = withStore store $ \connection -> withTransaction connection $ do
  _ <- execute_ connection "CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, username TEXT NOT NULL UNIQUE, password_hash BYTEA NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now())"
  _ <- execute_ connection "CREATE TABLE IF NOT EXISTS auth_sessions (token TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, created_at TIMESTAMPTZ NOT NULL DEFAULT now())"
  _ <- execute_ connection "CREATE TABLE IF NOT EXISTS game_sessions (id SERIAL PRIMARY KEY, user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE, current_state_id INTEGER NOT NULL DEFAULT 1 CHECK (current_state_id BETWEEN 1 AND 72), previous_state_id INTEGER, casting JSONB, updated_at TIMESTAMPTZ NOT NULL DEFAULT now())"
  _ <- execute_ connection "CREATE TABLE IF NOT EXISTS questions (id SERIAL PRIMARY KEY, game_session_id INTEGER NOT NULL REFERENCES game_sessions(id) ON DELETE CASCADE, state_id INTEGER NOT NULL, body TEXT NOT NULL, UNIQUE(game_session_id, state_id))"
  _ <- execute_ connection "CREATE TABLE IF NOT EXISTS game_events (id SERIAL PRIMARY KEY, game_session_id INTEGER NOT NULL REFERENCES game_sessions(id) ON DELETE CASCADE, from_state_id INTEGER NOT NULL, to_state_id INTEGER NOT NULL, question TEXT NOT NULL, journal TEXT NOT NULL DEFAULT '', casting_result JSONB NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now())"
  _ <- execute_ connection "CREATE TABLE IF NOT EXISTS contemplations (game_event_id INTEGER PRIMARY KEY REFERENCES game_events(id) ON DELETE CASCADE, response JSONB NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now())"
  _ <- execute_ connection "CREATE TABLE IF NOT EXISTS llm_requests (id SERIAL PRIMARY KEY, game_event_id INTEGER REFERENCES game_events(id) ON DELETE SET NULL, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, requested_at TIMESTAMPTZ NOT NULL DEFAULT now(), provider TEXT NOT NULL, model TEXT NOT NULL, input_tokens INTEGER NOT NULL DEFAULT 0, output_tokens INTEGER NOT NULL DEFAULT 0, cached_input_tokens INTEGER NOT NULL DEFAULT 0, latency_ms INTEGER NOT NULL DEFAULT 0, estimated_cost_micros INTEGER NOT NULL DEFAULT 0, succeeded BOOLEAN NOT NULL, error_message TEXT)"
  _ <- execute_ connection "CREATE TABLE IF NOT EXISTS journey_workflows (user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, document JSONB NOT NULL, updated_at TIMESTAMPTZ NOT NULL DEFAULT now())"
  _ <- execute_ connection "ALTER TABLE game_events ADD COLUMN IF NOT EXISTS raw_casting JSONB"
  _ <- execute_ connection "ALTER TABLE game_events ADD COLUMN IF NOT EXISTS previous_state_id INTEGER"
  PersonaSchema.migratePersonas connection

register :: Store -> AuthRequest -> IO AuthResponse
register store request = do
  validateAuth request
  hashed <- hashPasswordUsingPolicy slowerBcryptHashingPolicy (TE.encodeUtf8 (authPassword request))
  passwordHash <- maybe (throwIO (CorruptData "Could not hash password")) pure hashed
  withStore store $ \connection -> withTransaction connection $ do
    inserted <- query connection "INSERT INTO users (username, password_hash) VALUES (?, ?) ON CONFLICT (username) DO NOTHING RETURNING id" (normalizedUsername request, passwordHash) :: IO [Only Int]
    case inserted of
      [Only newUserId] -> do
        issueToken connection (User newUserId (normalizedUsername request) Nothing)
      _ -> throwIO UsernameTaken

login :: Store -> AuthRequest -> IO AuthResponse
login store request = withStore store $ \connection -> do
  matches <- query connection "SELECT id, username, password_hash FROM users WHERE username = ?" (Only (normalizedUsername request)) :: IO [(Int, Text, BS.ByteString)]
  case matches of
    [(matchedId, matchedName, passwordHash)]
      | validatePassword passwordHash (TE.encodeUtf8 (authPassword request)) ->
          issueToken connection (User matchedId matchedName Nothing)
    _ -> throwIO InvalidCredentials

authenticate :: Store -> Text -> IO User
authenticate store rawToken = withStore store $ \connection -> do
  rows <- query connection "SELECT users.id, users.username, CASE WHEN personas.archived=FALSE THEN auth_sessions.persona_id ELSE NULL END FROM auth_sessions LEFT JOIN personas ON personas.id=auth_sessions.persona_id JOIN users ON users.id = auth_sessions.user_id WHERE token = ?" (Only (stripBearer rawToken))
  maybe (throwIO InvalidCredentials) (pure . userFromRow) (listToMaybe rows)

getGameView :: Store -> DomainData -> User -> IO GameView
getGameView store domain user = withStore store $ \connection -> loadGameView connection domain user

createQuestion :: Store -> DomainData -> User -> QuestionRequest -> IO GameView
createQuestion store domain user request = do
  body <- validateText "Question" (requestedQuestionText request)
  withStore store $ \connection -> withTransaction connection $ do
    guardWorkflow connection user
    journey <- loadJourney connection user
    inserted <- query connection "INSERT INTO questions (game_session_id, state_id, body) VALUES (?, ?, ?) ON CONFLICT (game_session_id, state_id) DO NOTHING RETURNING id" (journeySessionId journey, journeyCurrentStateId journey, body) :: IO [Only Int]
    if null inserted then throwIO (Conflict "A question already exists for this encounter") else loadGameView connection domain user

updateQuestion :: Store -> DomainData -> User -> Int -> QuestionRequest -> IO GameView
updateQuestion store domain user requestedId request = do
  body <- validateText "Question" (requestedQuestionText request)
  withStore store $ \connection -> withTransaction connection $ do
    guardWorkflow connection user
    changed <- execute connection "UPDATE questions SET body = ? FROM game_sessions WHERE questions.id = ? AND questions.game_session_id = game_sessions.id AND game_sessions.persona_id = ? AND questions.state_id = game_sessions.current_state_id" (body, requestedId, selectedPersonaId user)
    if changed == 0 then throwIO (NotFound "Question") else loadGameView connection domain user

deleteQuestion :: Store -> DomainData -> User -> Int -> IO GameView
deleteQuestion store domain user requestedId = withStore store $ \connection -> withTransaction connection $ do
  guardWorkflow connection user
  changed <- execute connection "DELETE FROM questions USING game_sessions WHERE questions.id = ? AND questions.game_session_id = game_sessions.id AND game_sessions.persona_id = ? AND questions.state_id = game_sessions.current_state_id" (requestedId, selectedPersonaId user)
  if changed == 0 then throwIO (NotFound "Question") else loadGameView connection domain user

newCasting :: Store -> DomainData -> User -> IO GameView
newCasting store domain user = withStore store $ \connection -> withTransaction connection $ do
  guardWorkflow connection user
  changed <- execute connection "UPDATE game_sessions SET casting = ?, updated_at = now() WHERE persona_id = ?" (PG.Aeson initialCastingState, selectedPersonaId user)
  if changed == 0 then throwIO (NotFound "Game session") else loadGameView connection domain user

nextCasting :: Store -> DomainData -> User -> IO GameView
nextCasting store domain user = withStore store $ \connection -> withTransaction connection $ do
  guardWorkflow connection user
  journey <- loadJourney connection user
  activeQuestion <- loadQuestion connection journey
  case activeQuestion of
    Nothing -> throwIO (Conflict "Create a question before beginning the casting")
    Just question -> do
      currentCasting <- loadCasting connection journey
      let advanced = nextCastingState currentCasting
      _ <- execute connection "UPDATE game_sessions SET casting = ?, updated_at = now() WHERE id = ?" (PG.Aeson advanced, journeySessionId journey)
      case result advanced of
        Just castingResult | result currentCasting == Nothing -> completeCasting connection journey question advanced castingResult
        _ -> pure ()
      loadGameView connection domain user

completeCasting :: Connection -> JourneyState -> Question -> CastingState -> CastingResult -> IO ()
completeCasting connection journey question castingState castingResult = do
  _ <- execute connection "UPDATE questions SET finalized_at=now() WHERE id=?" (Only (questionId question))
  let destination = applyCastingMovement (journeyCurrentStateId journey) castingResult
  _ <- execute connection "INSERT INTO game_events (game_session_id, from_state_id, to_state_id, question, casting_result) VALUES (?, ?, ?, ?, ?)" (journeySessionId journey, journeyCurrentStateId journey, destination, questionText question, PG.Aeson castingResult)
  _ <- execute connection "UPDATE game_sessions SET previous_state_id = current_state_id, current_state_id = ?, casting = ?, updated_at = now() WHERE id = ?" (destination, PG.Aeson castingState, journeySessionId journey)
  pure ()

saveJournal :: Store -> DomainData -> User -> Int -> JournalRequest -> IO GameView
saveJournal store domain user eventId request = withStore store $ \connection -> withTransaction connection $ do
  guardWorkflow connection user
  changed <- execute connection "UPDATE game_events SET journal = ? FROM game_sessions WHERE game_events.id = ? AND game_events.game_session_id = game_sessions.id AND game_sessions.persona_id = ?" (T.strip (journalText request), eventId, selectedPersonaId user)
  if changed == 0 then throwIO (NotFound "Game event") else loadGameView connection domain user

contemplateEvent :: Store -> DomainData -> ContemplationModel -> User -> Int -> IO ContemplationView
contemplateEvent store domain model user requestedEventId = do
  context <- contemplationContext store domain user requestedEventId
  cached <- withStore store $ \connection -> query connection "SELECT response FROM contemplations WHERE game_event_id = ?" (Only requestedEventId) :: IO [Only (PG.Aeson ContemplationResponse)]
  case cached of
    [Only (PG.Aeson response)] -> pure (ContemplationView requestedEventId context response)
    _ -> generateContemplation store domain model user requestedEventId

generateContemplation :: Store -> DomainData -> ContemplationModel -> User -> Int -> IO ContemplationView
generateContemplation store domain model user requestedEventId = do
  context <- contemplationContext store domain user requestedEventId
  outcome <- try (contemplate model context) :: IO (Either ModelError ModelResult)
  case outcome of
    Left modelError -> do
      withStore store $ \connection -> do
        _ <- execute connection "INSERT INTO llm_requests (game_event_id, user_id, provider, model, succeeded, error_message) VALUES (?, ?, 'openai', 'unavailable', FALSE, ?)" (requestedEventId, userId user, renderModelError modelError)
        pure ()
      throwIO (ExternalService (renderModelError modelError))
    Right modelResult -> withStore store $ \connection -> withTransaction connection $ do
      _ <- execute connection "INSERT INTO contemplations (game_event_id, response) VALUES (?, ?) ON CONFLICT (game_event_id) DO UPDATE SET response = EXCLUDED.response, created_at = now()" (requestedEventId, PG.Aeson (modelContemplation modelResult))
      _ <- execute connection "INSERT INTO llm_requests (game_event_id, user_id, provider, model, input_tokens, output_tokens, cached_input_tokens, latency_ms, estimated_cost_micros, succeeded) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, TRUE)" (requestedEventId, userId user, modelProvider modelResult, modelName modelResult, modelInputTokens modelResult, modelOutputTokens modelResult, modelCachedInputTokens modelResult, modelLatencyMilliseconds modelResult, modelEstimatedCostMicros modelResult)
      pure (ContemplationView requestedEventId context (modelContemplation modelResult))

contemplationContext :: Store -> DomainData -> User -> Int -> IO ContemplationContext
contemplationContext store domain user requestedEventId = do
  (event, fromState) <- withStore store $ \connection -> do
    rows <- query connection "SELECT game_events.id, from_state_id, to_state_id, question, journal, casting_result FROM game_events JOIN game_sessions ON game_sessions.id = game_events.game_session_id WHERE game_events.id = ? AND game_sessions.persona_id = ?" (requestedEventId, selectedPersonaId user)
    case rows of
      [row] -> let found = eventFromRow row in pure (found, resolveState domain (gameEventFromStateId found))
      _ -> throwIO (NotFound "Game event")
  previous <- withStore store $ \connection -> query connection "SELECT previous_state_id FROM game_events WHERE id = ?" (Only requestedEventId) :: IO [Only (Maybe Int)]
  context <- either (throwIO . CorruptData) pure (buildContemplationContext fromState (gameEventQuestion event) (gameEventCastingResult event))
  personaRows <- withStore store $ \connection -> query connection "SELECT document FROM personas WHERE id=? AND player_id=?" (selectedPersonaId user, userId user) :: IO [Only (PG.Aeson Persona)]
  pure context {contemplationPersonaContext = case personaRows of [Only (PG.Aeson persona)] -> Just (personaPrompt persona); _ -> Nothing
    , contemplationPreviousLeelaState = case previous of [Only value] -> resolveState domain <$> value; _ -> Nothing}

contemplationCosts :: Store -> User -> IO CostSummary
contemplationCosts store user = withStore store $ \connection -> do
  rows <- query connection "SELECT COUNT(*), COALESCE(AVG(estimated_cost_micros), 0)::bigint, COALESCE(SUM(estimated_cost_micros), 0)::bigint, COALESCE(AVG(input_tokens + output_tokens), 0)::bigint FROM llm_requests WHERE user_id = ? AND succeeded = TRUE AND requested_at >= date_trunc('month', now())" (Only (userId user)) :: IO [(Int, Int, Int, Int)]
  case rows of
    [(count, averageCost, totalCost, averageTokens)] -> pure (CostSummary count averageCost totalCost averageTokens)
    _ -> pure (CostSummary 0 0 0 0)

loadGameView :: Connection -> DomainData -> User -> IO GameView
loadGameView connection domain user = do
  journey <- loadJourney connection user
  activeQuestion <- loadQuestion connection journey
  activeCasting <- loadCastingMaybe connection journey
  eventRows <- query connection "SELECT id, from_state_id, to_state_id, question, journal, casting_result FROM game_events WHERE game_session_id = ? ORDER BY id DESC LIMIT 20" (Only (journeySessionId journey))
  pure GameView
    { gameUser = user
    , gameJourney = journey
    , gameCurrentState = resolveState domain (journeyCurrentStateId journey)
    , gameAccessibleStates = resolveState domain <$> accessibleStateIds (journeyCurrentStateId journey)
    , gameQuestion = activeQuestion
    , gameCasting = activeCasting
    , gameHistory = eventFromRow <$> eventRows
    }

loadJourney :: Connection -> User -> IO JourneyState
loadJourney connection user = do
  case userPersonaId user of Nothing -> throwIO (Conflict "Select a Persona before entering the Leela Field"); Just _ -> pure ()
  rows <- query connection "SELECT id, persona_id, current_state_id, previous_state_id FROM game_sessions WHERE persona_id = ?" (Only (selectedPersonaId user))
  maybe (throwIO (NotFound "Game session")) (pure . journeyFromRow) (listToMaybe rows)

loadQuestion :: Connection -> JourneyState -> IO (Maybe Question)
loadQuestion connection journey = do
  rows <- query connection "SELECT id, game_session_id, state_id, body, ai_proposed_text, finalized_at::text FROM questions WHERE game_session_id = ? AND state_id = ?" (journeySessionId journey, journeyCurrentStateId journey)
  pure (questionFromRow <$> listToMaybe rows)

loadCastingMaybe :: Connection -> JourneyState -> IO (Maybe CastingState)
loadCastingMaybe connection journey = do
  rows <- query connection "SELECT casting FROM game_sessions WHERE id = ? AND casting IS NOT NULL" (Only (journeySessionId journey)) :: IO [Only (PG.Aeson CastingState)]
  case rows of
    [] -> pure Nothing
    [Only (PG.Aeson casting)] -> pure (Just casting)
    _ -> throwIO (CorruptData "Multiple game sessions found")

loadCasting :: Connection -> JourneyState -> IO CastingState
loadCasting connection journey = maybe initialCastingState id <$> loadCastingMaybe connection journey

resolveState :: DomainData -> Int -> LeelaState
resolveState domain requestedId =
  case filter ((== requestedId) . stateId) (leelaStates domain) of
    state : _ -> state
    [] -> LeelaState requestedId ("Lila State " <> T.pack (show requestedId)) "Consciousness-state commentary is not yet seeded for this prototype." "Unseeded state"

issueToken :: Connection -> User -> IO AuthResponse
issueToken connection user = do
  randomBytes <- getRandomBytes 32
  let token = T.pack (concatMap byteHex (BS.unpack randomBytes))
  _ <- execute connection "INSERT INTO auth_sessions (token, user_id, persona_id) VALUES (?, ?, (SELECT id FROM personas WHERE player_id=? AND archived=FALSE ORDER BY id LIMIT 1))" (token, userId user, userId user)
  pure (AuthResponse token user)

validateAuth :: AuthRequest -> IO ()
validateAuth request = do
  let name = normalizedUsername request
      password = authPassword request
  if T.length name < 3 || T.length name > 40 || T.any (not . validNameCharacter) name
    then throwIO (InvalidInput "Username must be 3-40 letters, numbers, underscores, or hyphens")
    else pure ()
  if T.length password < 10
    then throwIO (InvalidInput "Password must contain at least 10 characters")
    else pure ()

validateText :: Text -> Text -> IO Text
validateText label value =
  let clean = T.strip value
   in if T.null clean then throwIO (InvalidInput (label <> " must not be empty")) else pure clean

normalizedUsername :: AuthRequest -> Text
normalizedUsername = T.toCaseFold . T.strip . authUsername

validNameCharacter :: Char -> Bool
validNameCharacter value = isAlphaNum value || value == '_' || value == '-'

stripBearer :: Text -> Text
stripBearer raw = maybe raw id (T.stripPrefix "Bearer " raw)

byteHex :: Word8 -> String
byteHex value = let encoded = showHex value "" in if length encoded == 1 then '0' : encoded else encoded

newtype UserRow = UserRow {userFromRow :: User}
instance FromRow UserRow where
  fromRow = UserRow <$> (User <$> field <*> field <*> field)

newtype JourneyRow = JourneyRow {journeyFromRow :: JourneyState}
instance FromRow JourneyRow where
  fromRow = JourneyRow <$> (JourneyState <$> field <*> field <*> field <*> field)

newtype QuestionRow = QuestionRow {questionFromRow :: Question}
instance FromRow QuestionRow where
  fromRow = QuestionRow <$> (Question <$> field <*> field <*> field <*> field <*> field <*> field)

newtype EventRow = EventRow {eventFromRow :: GameEvent}
instance FromRow EventRow where
  fromRow = EventRow <$> (GameEvent <$> field <*> field <*> field <*> field <*> field <*> (unwrapJson <$> field))
    where
      unwrapJson (PG.Aeson value) = value

-- All encounter mutations lock the session before consulting workflow ownership.
guardWorkflow :: Connection -> User -> IO ()
guardWorkflow connection user = do
  guardPersona connection user
  _ <- query connection "SELECT id FROM game_sessions WHERE persona_id = ? FOR UPDATE" (Only (selectedPersonaId user)) :: IO [Only Int]
  active <- query connection "SELECT persona_id FROM journey_workflows WHERE persona_id = ? AND document->>'workflowStage' <> 'progress'" (Only (selectedPersonaId user)) :: IO [Only Int]
  if null active then pure () else throwIO (Conflict "Resume the active encounter in /journey/ before using prototype controls")

-- Captured at authentication, so switching another request cannot retarget this one.
selectedPersonaId :: User -> Maybe Int
selectedPersonaId = userPersonaId

-- Lock identity before journey writes so archiving cannot race a mutation.
guardPersona :: Connection -> User -> IO ()
guardPersona connection user = do
  rows <- query connection "SELECT id FROM personas WHERE id=? AND player_id=? AND archived=FALSE FOR UPDATE" (selectedPersonaId user,userId user) :: IO [Only Int]
  if null rows then throwIO (Conflict "Select an active Persona before entering the Leela Field") else pure ()

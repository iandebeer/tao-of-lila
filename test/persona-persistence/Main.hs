{-# LANGUAGE OverloadedStrings #-}
module Main (main) where
import Control.Exception (bracket, finally, try)
import Control.Monad (unless)
import qualified Data.ByteString.Char8 as B
import qualified Data.Text as T
import Data.Time.Clock.POSIX (getPOSIXTime)
import Database.PostgreSQL.Simple
import Data.String (fromString)
import qualified Database.PostgreSQL.Simple.Newtypes as PG
import Data.Aeson (Value (..), fromJSON, Result (..))
import qualified Data.Aeson.KeyMap as KM
import Domain.Contemplation (ContemplationResponse (..))
import Domain.Game
import Domain.Journey
import Domain.Persona
import Domain.Loading (loadDomainData)
import qualified Engine.Casting as Casting
import Persistence.Postgres
import qualified Persistence.Persona as P
import qualified Persistence.Journey as J
import System.Environment (lookupEnv)

main :: IO ()
main = do
  configured <- lookupEnv "TAO_PERSONA_TEST_DB"
  case configured of
    Nothing -> putStrLn "SKIP PostgreSQL persona acceptance: set TAO_PERSONA_TEST_DB to a disposable PostgreSQL connection string"
    Just raw -> do
      stamp <- round . (*1000000) <$> getPOSIXTime :: IO Integer
      let schema = "persona_test_" ++ show stamp
          scoped = if "postgres" `T.isPrefixOf` T.pack raw
            then raw ++ (if '?' `elem` raw then "&" else "?") ++ "options=-csearch_path%3D" ++ schema
            else raw ++ " options='-c search_path=" ++ schema ++ "'"
          store = newStore (B.pack scoped)
      bracket (connectPostgreSQL (B.pack raw)) close $ \admin -> do
        _ <- execute_ admin (fromString ("CREATE SCHEMA " ++ schema))
        acceptance store `finally` execute_ admin (fromString ("DROP SCHEMA " ++ schema ++ " CASCADE"))

acceptance :: Store -> IO ()
acceptance store = do
  domain <- loadDomainData "data" >>= either (fail . show) pure
  -- Reproduce the pre-Persona schema before invoking the real startup migration.
  withStore store $ \c -> do
    _ <- execute_ c "CREATE TABLE users(id SERIAL PRIMARY KEY, username TEXT UNIQUE NOT NULL,password_hash BYTEA NOT NULL,created_at TIMESTAMPTZ DEFAULT now())"
    _ <- execute_ c "CREATE TABLE game_sessions(id SERIAL PRIMARY KEY,user_id INTEGER NOT NULL UNIQUE REFERENCES users(id),current_state_id INTEGER DEFAULT 1,previous_state_id INTEGER,casting JSONB,updated_at TIMESTAMPTZ DEFAULT now())"
    _ <- execute_ c "CREATE TABLE journey_workflows(user_id INTEGER PRIMARY KEY REFERENCES users(id),document JSONB NOT NULL,updated_at TIMESTAMPTZ DEFAULT now())"
    _ <- execute_ c "CREATE TABLE questions(id SERIAL PRIMARY KEY,game_session_id INTEGER REFERENCES game_sessions(id),state_id INTEGER,body TEXT,UNIQUE(game_session_id,state_id))"
    _ <- execute_ c "CREATE TABLE game_events(id SERIAL PRIMARY KEY,game_session_id INTEGER REFERENCES game_sessions(id),from_state_id INTEGER,to_state_id INTEGER,question TEXT,journal TEXT NOT NULL DEFAULT '',casting_result JSONB,created_at TIMESTAMPTZ DEFAULT now())"
    _ <- execute_ c "INSERT INTO users(username,password_hash) VALUES('legacy','legacy')"
    _ <- execute c "INSERT INTO game_sessions(user_id,current_state_id,casting) VALUES(1,27,?)" (Only (PG.Aeson Casting.initialCastingState))
    _ <- execute_ c "INSERT INTO questions(game_session_id,state_id,body) VALUES(1,27,'Legacy question')"
    let legacyCast = until ((/=Nothing) . Casting.result) Casting.nextCastingState Casting.initialCastingState
    _ <- execute c "INSERT INTO game_events(game_session_id,from_state_id,to_state_id,question,journal,casting_result) VALUES(1,20,27,'Legacy encounter','Legacy reflection',?)" (Only (PG.Aeson (Casting.result legacyCast)))
    _ <- execute c "INSERT INTO journey_workflows(user_id,document) VALUES(1,?)" (Only (PG.Aeson (initialWorkflow 27 (Just 20))))
    pure ()
  migrate store
  migrate store
  let legacy = User 1 "legacy" Nothing
  adopted <- P.listPersonas store legacy
  assert "migration creates exactly one neutral Persona" (length adopted == 1 && personaName (head adopted) == "Legacy persona")
  old <- getGameView store domain legacy {userPersonaId=Just (personaId (head adopted))}
  assert "migration preserves session ID, board position and casting" (journeySessionId (gameJourney old)==1 && journeyCurrentStateId (gameJourney old)==27 && gameCasting old==Just Casting.initialCastingState)
  assert "migration retains existing questions and journal history" (fmap questionText (gameQuestion old)==Just "Legacy question" && map gameEventJournal (gameHistory old)==["Legacy reflection"])
  workflow <- withStore store $ \c -> query_ c "SELECT document FROM journey_workflows" :: IO [Only (PG.Aeson Workflow)]
  assert "migration preserves workflow exactly" (case workflow of [Only (PG.Aeson w)] -> w==initialWorkflow 27 (Just 20); _ -> False)
  let draft = PersonaDraft "Constructed scholar" "elderly, fictional" [] "" Nothing Nothing
  a <- P.createPersona store legacy draft
  b <- P.createPersona store legacy draft
  assert "one Player can create multiple Personas" (personaId a/=personaId b && personaPlayerId a==personaPlayerId b)
  let ua=legacy {userPersonaId=Just (personaId a)}; ub=legacy {userPersonaId=Just (personaId b)}
  _ <- createQuestion store domain ua (QuestionRequest "A question")
  _ <- newCasting store domain ua
  ga <- getGameView store domain ua
  let complete=until ((/=Nothing) . Casting.result) Casting.nextCastingState Casting.initialCastingState
  case (gameQuestion ga,Casting.result complete) of
    (Just q,Just r) -> withStore store $ \c -> completeCasting c (gameJourney ga) q complete r
    _ -> fail "Fixture casting did not complete"
  after <- getGameView store domain ua
  _ <- saveJournal store domain ua (gameEventId (head (gameHistory after))) (JournalRequest "A private journal")
  untouched <- getGameView store domain ub
  assert "independent board positions" (journeyCurrentStateId (gameJourney untouched)==1)
  assert "independent casting histories" (gameCasting untouched==Nothing && null (gameHistory untouched))
  assert "independent questions and journals" (gameQuestion untouched==Nothing && null (gameHistory untouched))
  edited <- P.updatePersona store legacy (personaId a) draft {draftDescription="changed",draftRevision=Just 0}
  sibling <- P.getPersona store legacy (personaId b)
  assert "editing A leaves B unchanged" (sibling==b && personaInitialDescription edited==personaDescription a)
  denied <- try (P.getPersona store (User 999 "unrelated" Nothing) (personaId a)) :: IO (Either StoreError Persona)
  assert "another Player cannot read the Persona" (case denied of Left (NotFound _) -> True; _ -> False)
  evidence <- P.recordEvidence store legacy (personaId a) "uncertainty" (Evidence "question:1" AIInferred "question:1" 0.5 True "2026-09-23")
  assert "inferred evidence is persisted separately from initial context" (not (null (personaThemes evidence)) && personaInitialDescription evidence==personaDescription a)
  rejected <- P.rejectTheme store legacy (personaId a) "uncertainty"
  audit <- P.personaHistory store legacy (personaId a)
  assert "Player can reject inferred themes while audit remains" (null (personaThemes rejected) && not (null audit))
  -- A previous model response supplies a proposal; edits must not replace it.
  withStore store $ \c -> do
    _ <- execute c "INSERT INTO contemplations(game_event_id,response) VALUES(?,?)" (gameEventId (head (gameHistory after)),PG.Aeson (ContemplationResponse "context" "primary" [] "change" [] ["AI proposed question"]))
    pure ()
  initial <- J.getJourney store domain ua
  questioning <- J.commandJourney store domain ua (JourneyCommand (revision initial) (userPersonaId ua) "question" Nothing Nothing)
  suggested <- J.commandJourney store domain ua (JourneyCommand (revision questioning) (userPersonaId ua) "suggest" Nothing Nothing)
  drafted <- J.commandJourney store domain ua (JourneyCommand (revision suggested) (userPersonaId ua) "draft" (Just "Player replacement") Nothing)
  _ <- J.commandJourney store domain ua (JourneyCommand (revision drafted) (userPersonaId ua) "begin" Nothing Nothing)
  stored <- withStore store $ \c -> query c "SELECT ai_proposed_text,player_final_text,finalized_at IS NOT NULL FROM persona_questions WHERE persona_id=? ORDER BY id DESC LIMIT 1" (Only (personaId a)) :: IO [(T.Text,T.Text,Bool)]
  assert "AI proposal and final Player question both survive" (stored==[("AI proposed question","Player replacement",True)])
  mismatch <- try (J.commandJourney store domain ub (JourneyCommand 0 (userPersonaId ua) "question" Nothing Nothing)) :: IO (Either StoreError Value)
  assert "stale Persona selection cannot retarget a command" (case mismatch of Left (Conflict _) -> True; _ -> False)
  _ <- P.archivePersona store legacy (personaId a)
  retained <- getGameView store domain ub
  assert "archive preserves sibling journey and Player" (gameUser retained==ub && gameJourney retained==gameJourney untouched)
  rows <- withStore store $ \c -> query_ c "SELECT COUNT(*) FROM game_events" :: IO [Only Int]
  assert "archive retains historical events" (rows==[Only 2])
  _ <- J.getJourney store domain ub
  putStrLn "PostgreSQL persona acceptance passed"

assert :: String -> Bool -> IO ()
assert label ok = unless ok (fail label) >> putStrLn ("ok - " ++ label)

revision :: Value -> Int
revision (Object document) = case KM.lookup "workflow" document of
  Just value -> case fromJSON value of Success workflow -> workflowRevision workflow; _ -> error "Invalid workflow fixture"
  _ -> error "Missing workflow fixture"
revision _ = error "Missing journey fixture"

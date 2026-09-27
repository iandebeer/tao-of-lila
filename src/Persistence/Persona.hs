{-# LANGUAGE OverloadedStrings #-}
module Persistence.Persona
  ( listPersonas, getPersona, createPersona, updatePersona, selectPersona
  , archivePersona, personaHistory, rejectTheme, recordEvidence, questionContext, loadPersona, proposeQuestion
  ) where
import Control.Exception (throwIO)
import Data.Aeson (Value, object, (.=))
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (getCurrentTime)
import Database.PostgreSQL.Simple
import qualified Database.PostgreSQL.Simple.Newtypes as PG
import Domain.Game (User (..), GameView (..))
import Domain.Persona
import Domain.Types (DomainData)
import Persistence.Postgres (Store, StoreError (..), withStore, loadGameView)

listPersonas :: Store -> User -> IO [Persona]
listPersonas store user = withStore store $ \c -> do
  rows <- query c "SELECT document FROM personas WHERE player_id=? ORDER BY id" (Only (userId user))
  pure [p | Only (PG.Aeson p) <- rows]

loadPersona :: Connection -> User -> Int -> IO Persona
loadPersona c user ident = do
  rows <- query c "SELECT document FROM personas WHERE id=? AND player_id=?" (ident,userId user)
  case rows of
    [Only (PG.Aeson p)] -> pure p
    _ -> throwIO (NotFound "Persona")

getPersona :: Store -> User -> Int -> IO Persona
getPersona store user ident = withStore store $ \c -> loadPersona c user ident

createPersona :: Store -> User -> PersonaDraft -> IO Persona
createPersona store user draft = withStore store $ \c -> withTransaction c $ do
  timestamp <- T.pack . show <$> getCurrentTime
  base <- either (throwIO . InvalidInput) pure (newPersona 0 (Player (userId user)) timestamp draft)
  rows <- query c "INSERT INTO personas(player_id,document) VALUES (?,?) RETURNING id" (userId user, PG.Aeson base) :: IO [Only Int]
  case rows of
    [Only ident] -> do
      let persona = base {personaId=ident}
      _ <- execute c "UPDATE personas SET document=? WHERE id=?" (PG.Aeson persona,ident)
      _ <- execute c "INSERT INTO game_sessions(user_id,persona_id) VALUES (?,?)" (userId user,ident)
      pure persona
    _ -> throwIO (CorruptData "Could not create Persona")

updatePersona :: Store -> User -> Int -> PersonaDraft -> IO Persona
updatePersona store user ident draft = withStore store $ \c -> withTransaction c $ do
  lockPersona c user ident
  old <- loadPersona c user ident
  timestamp <- T.pack . show <$> getCurrentTime
  new <- either (throwIO . Conflict) pure (revisePersona timestamp draft old)
  _ <- execute c "UPDATE personas SET document=? WHERE id=?" (PG.Aeson new,ident)
  pure new

lockPersona :: Connection -> User -> Int -> IO ()
lockPersona c user ident = do
  rows <- query c "SELECT id FROM personas WHERE id=? AND player_id=? FOR UPDATE" (ident,userId user) :: IO [Only Int]
  if null rows then throwIO (NotFound "Persona") else pure ()

selectPersona :: Store -> User -> Text -> Int -> IO Persona
selectPersona store user authorization ident = withStore store $ \c -> withTransaction c $ do
  lockPersona c user ident
  persona <- loadPersona c user ident
  if personaArchived persona then throwIO (Conflict "Persona is archived") else pure ()
  let token = maybe authorization id (T.stripPrefix "Bearer " authorization)
  _ <- execute c "UPDATE auth_sessions SET persona_id=? WHERE token=? AND user_id=?" (ident,token,userId user)
  pure persona

archivePersona :: Store -> User -> Int -> IO Persona
archivePersona store user ident = withStore store $ \c -> withTransaction c $ do
  lockPersona c user ident
  old <- loadPersona c user ident
  timestamp <- T.pack . show <$> getCurrentTime
  let new = old {personaArchived=True, personaRevision=personaRevision old+1, personaUpdatedAt=timestamp}
  _ <- execute c "UPDATE personas SET archived=TRUE,document=? WHERE id=?" (PG.Aeson new,ident)
  _ <- execute c "UPDATE auth_sessions SET persona_id=NULL WHERE persona_id=?" (Only ident)
  pure new

questionContext :: Store -> DomainData -> User -> Int -> IO Value
questionContext store domain user ident = withStore store $ \c -> do
  persona <- loadPersona c user ident
  game <- loadGameView c domain user {userPersonaId=Just ident}
  history <- query c "SELECT to_jsonb(e) FROM game_events e JOIN game_sessions s ON s.id=e.game_session_id WHERE s.persona_id=? ORDER BY e.id DESC" (Only ident) :: IO [Only (PG.Aeson Value)]
  unresolved <- query c "SELECT to_jsonb(q) FROM persona_questions q WHERE persona_id=? AND event_id IS NULL ORDER BY id" (Only ident) :: IO [Only (PG.Aeson Value)]
  pure $ object ["personaContext" .= personaPrompt persona, "currentJourney" .= gameJourney game, "currentLeelaState" .= gameCurrentState game
    , "journeyHistory" .= [v | Only (PG.Aeson v) <- history]
    , "unresolvedQuestions" .= [v | Only (PG.Aeson v) <- unresolved]]

-- Provider-neutral proposal ingestion is intentionally not exposed as a client
-- supplied AI claim. A future generator calls this with its inspected context.
proposeQuestion :: Connection -> Int -> Int -> Text -> Value -> IO Int
proposeQuestion c ident journey text basis = do
  rows <- query c "INSERT INTO persona_questions(persona_id,journey_id,ai_proposed_text,contextual_basis) SELECT ?,id,?,? FROM game_sessions WHERE id=? AND persona_id=? RETURNING id" (ident,text,PG.Aeson basis,journey,ident) :: IO [Only Int]
  case rows of [Only key] -> pure key; _ -> throwIO (NotFound "Persona journey")

personaHistory :: Store -> User -> Int -> IO [Value]
personaHistory store user ident = withStore store $ \c -> do
  _ <- loadPersona c user ident
  rows <- query c "SELECT to_jsonb(a) FROM persona_audit a WHERE persona_id=? ORDER BY id" (Only ident) :: IO [Only (PG.Aeson Value)]
  pure [v | Only (PG.Aeson v) <- rows]

-- Trusted interpretation boundary: no client endpoint can forge AI provenance.
recordEvidence :: Store -> User -> Int -> Text -> Evidence -> IO Persona
recordEvidence store user ident theme evidence = withStore store $ \c -> withTransaction c $ do
  lockPersona c user ident
  old <- loadPersona c user ident
  observed <- either (throwIO . InvalidInput) pure (observeTheme theme evidence old)
  if observed == old then pure old else do
    let new = observed {personaRevision=personaRevision old+1}
    _ <- execute c "UPDATE personas SET document=? WHERE id=?" (PG.Aeson new,ident)
    pure new

rejectTheme :: Store -> User -> Int -> Text -> IO Persona
rejectTheme store user ident theme = withStore store $ \c -> withTransaction c $ do
  lockPersona c user ident
  old <- loadPersona c user ident
  if personaArchived old then throwIO (Conflict "Persona is archived") else pure ()
  timestamp <- T.pack . show <$> getCurrentTime
  let new = old {personaThemes=filter ((/=theme) . themeName) (personaThemes old),personaRevision=personaRevision old+1,personaUpdatedAt=timestamp}
  _ <- execute c "UPDATE personas SET document=? WHERE id=?" (PG.Aeson new,ident)
  pure new

{-# LANGUAGE OverloadedStrings #-}
module Persistence.Journey (getJourney, commandJourney) where

import Control.Exception (throwIO)
import Data.Aeson (Result (..), fromJSON, object, (.=))
import qualified Data.Aeson.KeyMap as KM
import Data.Aeson (Value (..))
import Data.Maybe (fromMaybe)
import qualified Data.Text as T
import Database.PostgreSQL.Simple
import qualified Database.PostgreSQL.Simple.Newtypes as PG
import Domain.Contemplation (ContemplationResponse (..))
import Domain.Game
import Domain.Journey
import Domain.Types (DomainData)
import qualified Engine.Casting as Casting
import Engine.Game (applyCastingMovement)
import Persistence.Postgres (Store, guardPersona, selectedPersonaId, StoreError (..), withStore, loadGameView, resolveState)

getJourney :: Store -> DomainData -> User -> IO Value
getJourney store domain user = withStore store $ \connection -> withTransaction connection $ do
  workflow <- loadLocked connection domain user
  projection connection domain user workflow

commandJourney :: Store -> DomainData -> User -> JourneyCommand -> IO Value
commandJourney store domain user command = withStore store $ \connection -> withTransaction connection $ do
  if commandPersonaId command /= Nothing && commandPersonaId command /= selectedPersonaId user then throwIO (Conflict "Selected Persona changed. Reload before continuing.") else pure ()
  current <- loadLocked connection domain user
  if expectedRevision command /= workflowRevision current then throwIO (Conflict "Journey changed. Reload the saved encounter before continuing.") else pure ()
  if allowedStage (commandAction command) (workflowStage current) then pure () else throwIO (Conflict "This action is not available at the current journey stage")
  next <- transition connection domain user current command
  let saved = next {workflowRevision = workflowRevision current + 1}
  _ <- execute connection "UPDATE journey_workflows SET document = ?, updated_at = now() WHERE persona_id = ?" (PG.Aeson saved, selectedPersonaId user)
  projection connection domain user saved

loadLocked :: Connection -> DomainData -> User -> IO Workflow
loadLocked connection domain user = do
  guardPersona connection user
  _ <- query connection "SELECT id FROM game_sessions WHERE persona_id = ? FOR UPDATE" (Only (selectedPersonaId user)) :: IO [Only Int]
  rows <- query connection "SELECT document FROM journey_workflows WHERE persona_id = ? FOR UPDATE" (Only (selectedPersonaId user)) :: IO [Only (PG.Aeson Workflow)]
  case rows of
    [Only (PG.Aeson workflow)] -> pure workflow
    _ -> do
      game <- loadGameView connection domain user
      let journey = gameJourney game
          base = initialWorkflow (journeyCurrentStateId journey) (journeyPreviousStateId journey)
          question = maybe "" questionText (gameQuestion game)
          adopted = base {workflowQuestion = question}
      case gameCasting game of
        Just casting | Casting.result casting == Nothing && Casting.stateId casting > 0 -> throwIO (Conflict "Finish the existing prototype casting at /?prototype before starting this journey interface")
        _ -> pure ()
      _ <- execute connection "INSERT INTO journey_workflows (persona_id, document) VALUES (?, ?)" (selectedPersonaId user, PG.Aeson adopted)
      pure adopted

transition :: Connection -> DomainData -> User -> Workflow -> JourneyCommand -> IO Workflow
transition connection domain user workflow command = case commandAction command of
  "question" -> do
    game <- loadGameView connection domain user
    let journey = gameJourney game
    pure workflow {workflowStage = "question", workflowFrom = journeyCurrentStateId journey, workflowPrevious = journeyPreviousStateId journey}
  "suggest" -> do
    game <- loadGameView connection domain user
    proposals <- query connection "SELECT c.response FROM contemplations c JOIN game_events e ON e.id=c.game_event_id WHERE e.game_session_id=? ORDER BY e.id DESC LIMIT 1" (Only (journeySessionId (gameJourney game))) :: IO [Only (PG.Aeson ContemplationResponse)]
    text <- case proposals of
      [Only (PG.Aeson response)] -> case contemplationQuestions response of q:_ -> pure q; [] -> throwIO (Conflict "No suggested question is available yet")
      _ -> throwIO (Conflict "Request an interpretation of a completed encounter first, or write your own question")
    _ <- execute connection "INSERT INTO persona_questions(persona_id,journey_id,ai_proposed_text,contextual_basis) SELECT ?,?,?,jsonb_build_object('persona',document,'source','previous contemplation','workflow',?::jsonb) FROM personas WHERE id=?" (selectedPersonaId user,journeySessionId (gameJourney game),text,PG.Aeson workflow,selectedPersonaId user)
    pure workflow {workflowQuestion=text}
  "draft" -> do
    let text = fromMaybe "" (commandText command)
    _ <- execute connection "UPDATE persona_questions SET player_final_text=? WHERE id=(SELECT id FROM persona_questions WHERE persona_id=? AND finalized_at IS NULL ORDER BY id DESC LIMIT 1)" (text,selectedPersonaId user)
    pure workflow {workflowQuestion=text}
  "begin" -> if T.null (T.strip (workflowQuestion workflow)) then throwIO (InvalidInput "Enter a question before casting")
    else do
      game <- loadGameView connection domain user
      finalized <- execute connection "UPDATE persona_questions SET player_final_text=?,finalized_at=now() WHERE id=(SELECT id FROM persona_questions WHERE persona_id=? AND finalized_at IS NULL ORDER BY id DESC LIMIT 1)" (workflowQuestion workflow,selectedPersonaId user)
      if finalized > 0 then pure () else do
        _ <- execute connection "INSERT INTO persona_questions(persona_id,journey_id,player_final_text,contextual_basis,finalized_at) VALUES (?,?,?,jsonb_build_object('workflow',?::jsonb),now())" (selectedPersonaId user,journeySessionId (gameJourney game),workflowQuestion workflow,PG.Aeson workflow)
        pure ()
      pure workflow {workflowStage = "casting", workflowCasting = Just Casting.initialCastingState, workflowVisual = Nothing, workflowEventId = Nothing, workflowJournal = ""}
  "next" -> do
    casting <- requireCasting workflow
    if Casting.result casting /= Nothing then throwIO (Conflict "Casting is already complete") else pure ()
    let advanced = Casting.nextCastingState casting
    pure workflow {workflowCasting = Just advanced}
  "visual" -> do
    casting <- requireCasting workflow
    visual <- maybe (throwIO (InvalidInput "Visual snapshot is required")) pure (commandVisual command)
    let supplied = case visual of Object value -> KM.lookup "engine" value; _ -> Nothing
    case supplied of
      Just value | Success casting == fromJSON value -> pure workflow {workflowVisual = Just visual}
      _ -> throwIO (Conflict "Visual snapshot does not match the saved casting")
  "result" -> do
    casting <- requireCasting workflow
    result <- maybe (throwIO (Conflict "Complete all six lines first")) pure (Casting.result casting)
    game <- loadGameView connection domain user
    let destination = applyCastingMovement (workflowFrom workflow) result
    rows <- query connection "INSERT INTO game_events (game_session_id, from_state_id, to_state_id, question, journal, casting_result, raw_casting, previous_state_id) VALUES (?, ?, ?, ?, '', ?, ?, ?) RETURNING id" (journeySessionId (gameJourney game), workflowFrom workflow, destination, workflowQuestion workflow, PG.Aeson result, PG.Aeson casting, workflowPrevious workflow) :: IO [Only Int]
    case rows of
      [Only eventId] -> do
        _ <- execute connection "UPDATE persona_questions SET event_id=? WHERE id=(SELECT id FROM persona_questions WHERE persona_id=? AND finalized_at IS NOT NULL AND event_id IS NULL ORDER BY id DESC LIMIT 1)" (eventId,selectedPersonaId user)
        pure workflow {workflowStage = "result", workflowEventId = Just eventId}
      _ -> throwIO (CorruptData "Could not record casting")
  "interpretation" -> pure workflow {workflowStage = "interpretation"}
  "reflection" -> pure workflow {workflowStage = "reflection"}
  "journal" -> saveReflection connection workflow (fromMaybe "" (commandText command))
  "movement" -> do
    saved <- saveReflection connection workflow (fromMaybe (workflowJournal workflow) (commandText command))
    pure saved {workflowStage = "movement"}
  "acknowledge" -> do
    casting <- requireCasting workflow
    result <- maybe (throwIO (Conflict "No completed casting")) pure (Casting.result casting)
    let destination = applyCastingMovement (workflowFrom workflow) result
    _ <- execute connection "UPDATE game_sessions SET previous_state_id = ?, current_state_id = ?, casting = ?, updated_at = now() WHERE persona_id = ?" (workflowFrom workflow, destination, PG.Aeson casting, selectedPersonaId user)
    pure (initialWorkflow destination (Just (workflowFrom workflow)))
  _ -> throwIO (InvalidInput "Unknown journey command")

saveReflection :: Connection -> Workflow -> T.Text -> IO Workflow
saveReflection connection workflow body = do
  eventId <- maybe (throwIO (Conflict "No event to reflect on")) pure (workflowEventId workflow)
  _ <- execute connection "UPDATE game_events SET journal = ? WHERE id = ?" (body, eventId)
  pure workflow {workflowJournal = body}

requireCasting :: Workflow -> IO Casting.CastingState
requireCasting = maybe (throwIO (Conflict "Begin a casting first")) pure . workflowCasting

projection :: Connection -> DomainData -> User -> Workflow -> IO Value
projection connection domain user workflow = do
  game <- loadGameView connection domain user
  advice <- query connection "SELECT response FROM contemplations WHERE game_event_id = ?" (Only (workflowEventId workflow)) :: IO [Only (PG.Aeson Value)]
  history <- query connection "SELECT jsonb_build_object('eventId', e.id, 'from', e.from_state_id, 'to', e.to_state_id, 'question', e.question, 'journal', e.journal, 'casting', e.casting_result, 'rawCasting', e.raw_casting, 'createdAt', e.created_at, 'interpretation', c.response) FROM game_events e LEFT JOIN contemplations c ON c.game_event_id = e.id WHERE e.game_session_id = ? ORDER BY e.id DESC" (Only (journeySessionId (gameJourney game))) :: IO [Only (PG.Aeson Value)]
  questions <- query connection "SELECT to_jsonb(q) FROM persona_questions q WHERE persona_id=? ORDER BY id DESC" (Only (selectedPersonaId user)) :: IO [Only (PG.Aeson Value)]
  let result = workflowCasting workflow >>= Casting.result
      movement = fmap (\casting -> object ["amount" .= Casting.lilaMoveSquares casting, "from" .= resolveState domain (workflowFrom workflow), "landing" .= resolveState domain (applyCastingMovement (workflowFrom workflow) casting), "final" .= resolveState domain (applyCastingMovement (workflowFrom workflow) casting), "consequence" .= (Nothing :: Maybe T.Text)]) result
  pure $ object
    [ "workflow" .= workflow, "game" .= game
    , "fromState" .= resolveState domain (workflowFrom workflow)
    , "previousState" .= fmap (resolveState domain) (if workflowStage workflow == "progress" then journeyPreviousStateId (gameJourney game) else workflowPrevious workflow)
    , "interpretation" .= case advice of [Only (PG.Aeson value)] -> Just value; _ -> Nothing
    , "movement" .= movement
    , "questions" .= [value | Only (PG.Aeson value) <- questions]
    , "history" .= [value | Only (PG.Aeson value) <- history]
    , "terminal" .= False
    , "topologyAvailable" .= False
    ]

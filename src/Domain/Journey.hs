{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- Durable orchestration state; casting and movement remain in their engines.
module Domain.Journey (Workflow (..), JourneyCommand (..), initialWorkflow, allowedStage, validWorkflow) where

import Data.Aeson (FromJSON, ToJSON, Value)
import Data.Text (Text)
import Engine.Casting (CastingState)
import qualified Engine.Casting as Casting
import GHC.Generics (Generic)

data Workflow = Workflow
  { workflowRevision :: Int
  , workflowStage :: Text
  , workflowQuestion :: Text
  , workflowCasting :: Maybe CastingState
  , workflowVisual :: Maybe Value
  , workflowEventId :: Maybe Int
  , workflowFrom :: Int
  , workflowPrevious :: Maybe Int
  , workflowJournal :: Text
  } deriving (Eq, Show, Generic)
instance ToJSON Workflow
instance FromJSON Workflow

data JourneyCommand = JourneyCommand
  { expectedRevision :: Int
  , commandPersonaId :: Maybe Int
  , commandAction :: Text
  , commandText :: Maybe Text
  , commandVisual :: Maybe Value
  } deriving (Eq, Show, Generic)
instance ToJSON JourneyCommand
instance FromJSON JourneyCommand

initialWorkflow :: Int -> Maybe Int -> Workflow
initialWorkflow from previous = Workflow 0 "progress" "" Nothing Nothing Nothing from previous ""

allowedStage :: Text -> Text -> Bool
allowedStage action stage = case action of
  "question" -> stage `elem` ["progress", "question"]
  "draft" -> stage == "question"
  "suggest" -> stage == "question"
  "begin" -> stage == "question"
  "next" -> stage == "casting"
  "line" -> stage == "casting"
  "visual" -> stage == "casting"
  "result" -> stage == "casting"
  "interpretation" -> stage == "result"
  "reflection" -> stage == "interpretation"
  "journal" -> stage == "reflection"
  "movement" -> stage == "reflection"
  "acknowledge" -> stage == "movement"
  _ -> False

-- A saved encounter must still be usable by the current workflow before resume.
validWorkflow :: Int -> Workflow -> Bool
validWorkflow current workflow =
  current >= 1 && current <= 72 && workflowFrom workflow == current
  && workflowRevision workflow >= 0
  && maybe True (\n -> n >= 1 && n <= 72) (workflowPrevious workflow)
  && case workflowStage workflow of
    "progress" -> True
    "question" -> True
    "casting" -> workflowCasting workflow /= Nothing
    stage | stage `elem` ["result", "interpretation", "reflection", "movement"] ->
      (workflowCasting workflow >>= Casting.result) /= Nothing && workflowEventId workflow /= Nothing
    _ -> False

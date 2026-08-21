{-# LANGUAGE DeriveGeneric #-}

module Domain.Game
  ( AuthRequest (..)
  , AuthResponse (..)
  , GameEvent (..)
  , GameView (..)
  , JournalRequest (..)
  , JourneyState (..)
  , Question (..)
  , QuestionRequest (..)
  , User (..)
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import Domain.Types (LeelaState)
import Engine.Casting (CastingResult, CastingState)
import GHC.Generics (Generic)

data AuthRequest = AuthRequest
  { authUsername :: Text
  , authPassword :: Text
  }
  deriving (Eq, Show, Generic)

instance FromJSON AuthRequest
instance ToJSON AuthRequest

data User = User
  { userId :: Int
  , username :: Text
  }
  deriving (Eq, Show, Generic)

instance FromJSON User
instance ToJSON User

data AuthResponse = AuthResponse
  { authToken :: Text
  , authUser :: User
  }
  deriving (Eq, Show, Generic)

instance FromJSON AuthResponse
instance ToJSON AuthResponse

data JourneyState = JourneyState
  { journeySessionId :: Int
  , journeyCurrentStateId :: Int
  , journeyPreviousStateId :: Maybe Int
  }
  deriving (Eq, Show, Generic)

instance FromJSON JourneyState
instance ToJSON JourneyState

data Question = Question
  { questionId :: Int
  , questionSessionId :: Int
  , questionStateId :: Int
  , questionText :: Text
  }
  deriving (Eq, Show, Generic)

instance FromJSON Question
instance ToJSON Question

newtype QuestionRequest = QuestionRequest
  { requestedQuestionText :: Text
  }
  deriving (Eq, Show, Generic)

instance FromJSON QuestionRequest
instance ToJSON QuestionRequest

newtype JournalRequest = JournalRequest
  { journalText :: Text
  }
  deriving (Eq, Show, Generic)

instance FromJSON JournalRequest
instance ToJSON JournalRequest

data GameEvent = GameEvent
  { gameEventId :: Int
  , gameEventFromStateId :: Int
  , gameEventToStateId :: Int
  , gameEventQuestion :: Text
  , gameEventJournal :: Text
  , gameEventCastingResult :: CastingResult
  }
  deriving (Eq, Show, Generic)

instance FromJSON GameEvent
instance ToJSON GameEvent

data GameView = GameView
  { gameUser :: User
  , gameJourney :: JourneyState
  , gameCurrentState :: LeelaState
  , gameAccessibleStates :: [LeelaState]
  , gameQuestion :: Maybe Question
  , gameCasting :: Maybe CastingState
  , gameHistory :: [GameEvent]
  }
  deriving (Eq, Show, Generic)

instance FromJSON GameView
instance ToJSON GameView

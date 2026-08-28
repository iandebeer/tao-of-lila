{-# LANGUAGE OverloadedStrings #-}

module Interpretation.ContemplationModel
  ( ContemplationModel (..)
  , ModelError (..)
  , disabledContemplationModel
  )
where

import Control.Exception (Exception, throwIO)
import Data.Text (Text)
import Domain.Contemplation (ContemplationContext, ModelResult)

newtype ModelError = ModelError {renderModelError :: Text}
  deriving (Eq, Show)

instance Exception ModelError

newtype ContemplationModel = ContemplationModel
  { contemplate :: ContemplationContext -> IO ModelResult
  }

disabledContemplationModel :: ContemplationModel
disabledContemplationModel =
  ContemplationModel (const (throwIO (ModelError "Contemplation is not configured; set OPENAI_API_KEY")))

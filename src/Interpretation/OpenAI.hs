{-# LANGUAGE OverloadedStrings #-}

module Interpretation.OpenAI
  ( OpenAIConfig (..)
  , openAIContemplationModel
  )
where

import Control.Exception (throwIO)
import Data.Aeson
  ( FromJSON (..), Value, eitherDecode, eitherDecodeStrict', encode, object, withObject
  , (.:), (.:?), (.!=), (.=)
  )
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Text.Encoding.Error (lenientDecode)
import Data.Time.Clock (diffUTCTime, getCurrentTime)
import Domain.Contemplation
import Interpretation.ContemplationModel
import Network.HTTP.Client
  ( Request (..), RequestBody (RequestBodyLBS), httpLbs, newManager, parseRequest
  , responseBody, responseStatus, responseTimeoutMicro
  )
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Types.Status (statusCode)

data OpenAIConfig = OpenAIConfig
  { openAIApiKey :: Text
  , openAIModelName :: Text
  , openAIMaxOutputTokens :: Int
  , openAIInputCostMicrosPerMillion :: Int
  , openAICachedInputCostMicrosPerMillion :: Int
  , openAIOutputCostMicrosPerMillion :: Int
  }

openAIContemplationModel :: OpenAIConfig -> IO ContemplationModel
openAIContemplationModel config = do
  manager <- newManager tlsManagerSettings
  baseRequest <- parseRequest "https://api.openai.com/v1/responses"
  pure $ ContemplationModel $ \context -> do
    started <- getCurrentTime
    let request =
          baseRequest
            { method = "POST"
            , requestHeaders =
                [ ("authorization", "Bearer " <> TE.encodeUtf8 (openAIApiKey config))
                , ("content-type", "application/json")
                ]
            , requestBody = RequestBodyLBS (encode (requestValue config context))
            , responseTimeout = responseTimeoutMicro 30000000
            }
    response <- httpLbs request manager
    finished <- getCurrentTime
    if statusCode (responseStatus response) < 200 || statusCode (responseStatus response) >= 300
      then throwIO (ModelError ("OpenAI request failed: " <> decodeBody (responseBody response)))
      else case eitherDecode (responseBody response) of
        Left message -> throwIO (ModelError ("Could not decode OpenAI response: " <> T.pack message))
        Right envelope -> do
          contemplationValue <- case eitherDecodeStrict' (TE.encodeUtf8 (responseOutputText envelope)) of
            Left message -> throwIO (ModelError ("Could not decode structured contemplation: " <> T.pack message))
            Right value -> pure value
          let usage = responseUsage envelope
              latency = round (realToFrac (diffUTCTime finished started) * (1000 :: Double))
              cost = estimateCost config usage
          pure ModelResult
            { modelContemplation = contemplationValue
            , modelProvider = "openai"
            , modelName = responseModel envelope
            , modelInputTokens = usageInputTokens usage
            , modelOutputTokens = usageOutputTokens usage
            , modelCachedInputTokens = usageCachedInputTokens usage
            , modelLatencyMilliseconds = latency
            , modelEstimatedCostMicros = cost
            }

requestValue :: OpenAIConfig -> ContemplationContext -> Value
requestValue config context =
  object
    [ "model" .= openAIModelName config
    , "store" .= False
    , "instructions" .= systemInstruction
    , "input" .= [object ["role" .= ("user" :: Text), "content" .= [object ["type" .= ("input_text" :: Text), "text" .= contextText]]]]
    , "max_output_tokens" .= openAIMaxOutputTokens config
    , "text" .= object ["format" .= responseFormat]
    ]
  where
    contextText = "Contemplate only this structured casting context:\n" <> TE.decodeUtf8 (LBS.toStrict (encode context))

responseFormat :: Value
responseFormat = object
  [ "type" .= ("json_schema" :: Text)
  , "name" .= ("tao_of_lila_contemplation" :: Text)
  , "strict" .= True
  , "schema" .= object
      [ "type" .= ("object" :: Text)
      , "additionalProperties" .= False
      , "required" .= (["context", "primary_hexagram", "changing_lines", "transformation", "possible_readings", "questions_for_contemplation"] :: [Text])
      , "properties" .= object
          [ "context" .= stringSchema
          , "primary_hexagram" .= stringSchema
          , "changing_lines" .= arrayStringSchema
          , "transformation" .= stringSchema
          , "possible_readings" .= arrayStringSchema
          , "questions_for_contemplation" .= arrayStringSchema
          ]
      ]
  ]
  where
    stringSchema = object ["type" .= ("string" :: Text)]
    arrayStringSchema = object ["type" .= ("array" :: Text), "items" .= stringSchema]

systemInstruction :: Text
systemInstruction = T.unlines
  [ "You are the contemplative interpretation component of Tao of Lila."
  , "You are not an oracle, spiritual authority, prophet, healer, guru, or source of supernatural knowledge."
  , "The casting was performed independently. Never alter, second-guess, or recalculate it."
  , "Place the question, Leela state, primary hexagram, changing lines, resulting hexagram, Chinese text, lexical notes, and translations beside one another."
  , "Identify relationships, tensions, images, transformations, ambiguities, and possible contemplative perspectives."
  , "Distinguish ancient text, linguistic possibility, later interpretation, and your contemporary reflection."
  , "Never claim the universe or Tao chose, wants, proves, predicts, or commands anything. Avoid 'you must' and 'this means'."
  , "Prefer 'one possible reading', 'may invite consideration', and open questions. Preserve ambiguity."
  , "Do not use pseudo-scientific, quantum, energy, healing, or metaphysical claims."
  , "Help the participant see the lived question differently; do not resolve it. Keep the response concise and spacious."
  ]

data ResponseEnvelope = ResponseEnvelope
  { responseOutputText :: Text
  , responseModel :: Text
  , responseUsage :: Usage
  }

instance FromJSON ResponseEnvelope where
  parseJSON = withObject "ResponseEnvelope" $ \value ->
    ResponseEnvelope <$> value .: "output_text" <*> value .: "model" <*> value .: "usage"

data Usage = Usage
  { usageInputTokens :: Int
  , usageOutputTokens :: Int
  , usageCachedInputTokens :: Int
  }

instance FromJSON Usage where
  parseJSON = withObject "Usage" $ \value -> do
    details <- value .:? "input_tokens_details"
    cached <- maybe (pure 0) (\item -> item .:? "cached_tokens" .!= 0) details
    Usage <$> value .: "input_tokens" <*> value .: "output_tokens" <*> pure cached

estimateCost :: OpenAIConfig -> Usage -> Int
estimateCost config usage =
  let cached = usageCachedInputTokens usage
      uncached = max 0 (usageInputTokens usage - cached)
      weighted =
        uncached * openAIInputCostMicrosPerMillion config
          + cached * openAICachedInputCostMicrosPerMillion config
          + usageOutputTokens usage * openAIOutputCostMicrosPerMillion config
   in weighted `div` 1000000

decodeBody :: LBS.ByteString -> Text
decodeBody = TE.decodeUtf8With lenientDecode . LBS.toStrict

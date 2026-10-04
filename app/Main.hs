module Main
  ( main
  )
where

import API.Server (app)
import Domain.StateView (loadStateCatalog)
import qualified Data.ByteString.Char8 as B8
import qualified Data.Text as T
import Domain.Loading (DataLoadError (..), loadDomainData)
import Network.Wai.Handler.Warp (run)
import Interpretation.ContemplationModel (ContemplationModel, disabledContemplationModel)
import Interpretation.OpenAI (OpenAIConfig (..), openAIContemplationModel)
import Persistence.Postgres (migrate, newStore)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

main :: IO ()
main = do
  port <- resolvePort
  loaded <- loadDomainData "data"
  case loaded of
    Left err -> fail (show (renderDataLoadError err))
    Right domain -> do
      stateCatalog <- loadStateCatalog "data/state-views.json" >>= either fail pure
      databaseUrl <- resolveDatabaseUrl
      let store = newStore (B8.pack databaseUrl)
      migrate store
      model <- resolveContemplationModel
      putStrLn ("The Tao of Lila API listening on port " <> show port)
      run port (app "app/public" domain stateCatalog store model)

resolvePort :: IO Int
resolvePort = do
  maybePort <- lookupEnv "PORT"
  pure $
    case maybePort >>= readMaybe of
      Just port -> port
      Nothing -> 8080

resolveDatabaseUrl :: IO String
resolveDatabaseUrl = do
  configured <- lookupEnv "DATABASE_URL"
  pure (maybe "postgresql://tao:tao@localhost:5432/tao_of_lila" id configured)

resolveContemplationModel :: IO ContemplationModel
resolveContemplationModel = do
  apiKey <- lookupEnv "OPENAI_API_KEY"
  modelName <- lookupEnv "OPENAI_MODEL"
  inputRate <- resolveIntEnv "OPENAI_INPUT_COST_MICROS_PER_MILLION"
  cachedInputRate <- resolveIntEnv "OPENAI_CACHED_INPUT_COST_MICROS_PER_MILLION"
  outputRate <- resolveIntEnv "OPENAI_OUTPUT_COST_MICROS_PER_MILLION"
  case apiKey of
    Nothing -> pure disabledContemplationModel
    Just key -> openAIContemplationModel OpenAIConfig
      { openAIApiKey = T.pack key
      , openAIModelName = T.pack (maybe "gpt-5-mini" id modelName)
      , openAIMaxOutputTokens = 1200
      , openAIInputCostMicrosPerMillion = inputRate
      , openAICachedInputCostMicrosPerMillion = cachedInputRate
      , openAIOutputCostMicrosPerMillion = outputRate
      }

resolveIntEnv :: String -> IO Int
resolveIntEnv name = do
  configured <- lookupEnv name
  pure (maybe 0 id (configured >>= readMaybe))

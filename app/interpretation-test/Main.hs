{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Exception (try)
import Data.Aeson (encode)
import qualified Data.ByteString.Lazy.Char8 as LBS
import Data.List (find)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Domain.Contemplation
import Domain.Loading (loadDomainData)
import Domain.Types (DomainData (..), LeelaState (..))
import Interpretation.ContemplationModel (ContemplationModel (..), ModelError (..), disabledContemplationModel)
import Interpretation.OpenAI (OpenAIConfig (..), openAIContemplationModel)
import System.Environment (getArgs, lookupEnv)
import System.Exit (die)
import Text.Read (readMaybe)
import Web (runWeb)

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["--help"] -> putStrLn usage
    ["--web"] -> do
      loaded <- loadDomainData "data"
      domain <- either (die . show) pure loaded
      provider <- resolveProvider
      runWeb domain provider
    _ -> do
      let dryRun = "--dry-run" `elem` args
          positional = filter (/= "--dry-run") args
      case positional of
        [primary, resulting, question] -> run dryRun primary resulting question "1"
        [primary, resulting, question, leela] -> run dryRun primary resulting question leela
        _ -> die usage

usage :: String
usage = unlines
  [ "Usage: cabal run tao-of-lila-interpretation-test -- [--dry-run] PRIMARY RESULTING QUESTION [LEELA_STATE_ID]"
  , "Web interface: cabal run tao-of-lila-interpretation-test -- --web"
  , "King Wen numbers: 1..64. Current source-text corpus: 11 and 36."
  , "Leela state defaults to 1. Run from the repository root."
  , "--dry-run prints context JSON without an API key or network request."
  , "Live mode uses OPENAI_API_KEY and OPENAI_MODEL (default: gpt-5-mini)."
  , "No database, login, casting ceremony, or game movement is needed."
  ]

run :: Bool -> String -> String -> String -> String -> IO ()
run dryRun primaryArg resultingArg questionArg stateArg = do
  primary <- parseNumber "Primary King Wen number" primaryArg
  resulting <- parseNumber "Resulting King Wen number" resultingArg
  selectedState <- parseNumber "Leela state ID" stateArg
  let question = T.strip (T.pack questionArg)
  if T.null question then die "Question must not be empty" else pure ()
  loaded <- loadDomainData "data"
  domain <- either (die . show) pure loaded
  leela <- maybe (die "Leela state ID was not found") pure
    (find ((== selectedState) . stateId) (leelaStates domain))
  context <- either (die . T.unpack) pure
    (buildPairContemplationContext leela question primary resulting)
  if dryRun then LBS.putStrLn (encode context) else do
    provider <- resolveProvider
    TIO.putStrLn ("Hexagram " <> T.pack (show primary) <> " → " <> T.pack (show resulting))
    putStrLn ("Changing lines (bottom to top): " <> show (map changingLineNumber (contemplationChangingLines context)))
    outcome <- try (contemplate provider context) :: IO (Either ModelError ModelResult)
    result <- either (die . T.unpack . renderModelError) pure outcome
    let response = modelContemplation result
        section title body = TIO.putStrLn ("\n" <> title <> "\n" <> body)
        items title values = section title (T.intercalate "\n" (map ("• " <>) values))
    section "Context" (contemplationResponseContext response)
    section "Primary hexagram" (contemplationPrimaryReflection response)
    items "Changing lines" (contemplationLineReflections response)
    section "Transformation" (contemplationTransformation response)
    items "Possible readings" (contemplationPossibleReadings response)
    items "Questions for contemplation" (contemplationQuestions response)
    TIO.putStrLn ("\nModel: " <> modelName result)
    putStrLn ("Tokens: " <> show (modelInputTokens result) <> " input / " <> show (modelOutputTokens result) <> " output")

parseNumber :: String -> String -> IO Int
parseNumber label value = maybe (die (label <> " must be an integer")) pure (readMaybe value)

resolveProvider :: IO ContemplationModel
resolveProvider = do
  apiKey <- lookupEnv "OPENAI_API_KEY"
  model <- lookupEnv "OPENAI_MODEL"
  case apiKey of
    Just key | not (null key) -> openAIContemplationModel OpenAIConfig
      { openAIApiKey = T.pack key
      , openAIModelName = maybe "gpt-5-mini" T.pack model
      , openAIMaxOutputTokens = 4000
      , openAIInputCostMicrosPerMillion = 0
      , openAICachedInputCostMicrosPerMillion = 0
      , openAIOutputCostMicrosPerMillion = 0
      }
    _ -> pure disabledContemplationModel

module Main
  ( main
  )
where

import API.Server (app)
import qualified Data.ByteString.Char8 as B8
import Domain.Loading (DataLoadError (..), loadDomainData)
import Network.Wai.Handler.Warp (run)
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
      databaseUrl <- resolveDatabaseUrl
      let store = newStore (B8.pack databaseUrl)
      migrate store
      putStrLn ("The Tao of Lila API listening on port " <> show port)
      run port (app "app/public" domain store)

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

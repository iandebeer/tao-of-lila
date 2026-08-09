module Main
  ( main
  )
where

import API.Server (app)
import Data.IORef (newIORef)
import Domain.Loading (DataLoadError (..), loadDomainData)
import Engine.Casting (initialCastingState)
import Network.Wai.Handler.Warp (run)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

main :: IO ()
main = do
  port <- resolvePort
  loaded <- loadDomainData "data"
  case loaded of
    Left err -> fail (show (renderDataLoadError err))
    Right domain -> do
      castingRef <- newIORef initialCastingState
      putStrLn ("The Tao of Lila API listening on port " <> show port)
      run port (app "app/public" domain castingRef)

resolvePort :: IO Int
resolvePort = do
  maybePort <- lookupEnv "PORT"
  pure $
    case maybePort >>= readMaybe of
      Just port -> port
      Nothing -> 8080

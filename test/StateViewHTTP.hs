{-# LANGUAGE OverloadedStrings #-}
module StateViewHTTP (checkStateViewHTTP) where

import qualified API.Server as API
import Data.Aeson (eitherDecode)
import Control.Monad (replicateM)
import Data.List (nub)
import qualified Engine.Casting as Casting
import Data.ByteString.Builder (toLazyByteString)
import qualified Data.ByteString.Lazy as LBS
import Data.IORef (newIORef, modifyIORef', readIORef)
import Domain.StateView (StateCatalog)
import Domain.Types (DomainData)
import Interpretation.ContemplationModel (disabledContemplationModel)
import Network.HTTP.Types (hCacheControl, status200)
import Network.Wai (defaultRequest, pathInfo, responseToStream, responseHeaders)
import Network.Wai.Internal (ResponseReceived (..))
import Persistence.Postgres (newStore)

-- Exercise Servant and static dispatch without opening a socket or a database.
checkStateViewHTTP :: DomainData -> StateCatalog -> IO ()
checkStateViewHTTP domain catalog = do
  let application = API.app "app/public" domain catalog (newStore "") disabledContemplationModel
      get path = do
        bytes <- newIORef LBS.empty
        _ <- application defaultRequest {pathInfo = path} $ \response -> do
          let (status, _, withBody) = responseToStream response
          if status /= status200 then fail "State viewer HTTP request failed" else pure ()
          withBody $ \body -> body (\builder -> modifyIORef' bytes (<> toLazyByteString builder)) (pure ())
          pure ResponseReceived
        readIORef bytes
  castings <- replicateM 8 $ do
    body <- get ["casting", "initial"]
    either fail pure (eitherDecode body)
  if length (nub (map Casting.seed castings)) > 1 then pure ()
    else fail "Casting initial API reused a fixed seed"
  response <- get ["state-views"]
  case eitherDecode response of
    Right decoded | decoded == catalog -> pure ()
    _ -> fail "State viewer API did not return the validated catalogue"
  journey <- get ["journey", ""]
  expected <- LBS.readFile "app/public/journey/index.html"
  if journey == expected then pure () else fail "Journey directory did not serve its own index"
  mapM_ (\path -> do
    _ <- application defaultRequest {pathInfo = path} $ \assetResponse -> do
      if lookup hCacheControl (responseHeaders assetResponse) == Just "no-cache"
        then pure () else fail "Unversioned static assets must revalidate after deployment"
      pure ResponseReceived
    pure ()) [["journey", "app.js"], ["journey", "splash.js"], ["journey", "style.css"]]
  putStrLn "ok - public catalogue API and journey directory serve the expected data without a database"

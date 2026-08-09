{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module API.Server
  ( API
  , app
  )
where

import Control.Monad.IO.Class (liftIO)
import Data.Aeson (encode, object, (.=))
import Data.IORef (IORef, atomicModifyIORef', readIORef, writeIORef)
import Domain.Types
  ( DomainData (..)
  , Health (..)
  , Hexagram
  , Interpretation (..)
  , LeelaState
  , Reading (..)
  , ReadingRequest
  )
import Engine.Casting (CastingState, initialCastingState, nextCastingState)
import Engine.Reading (ReadingError (..), generateReading)
import Network.HTTP.Types (hContentType, status200)
import Network.Wai (Application, responseFile)
import Network.Wai.Application.Static (StaticSettings (..), defaultWebAppSettings)
import Servant
  ( (:<|>) (..)
  , (:>)
  , Get
  , Handler
  , JSON
  , Post
  , Proxy (..)
  , Raw
  , ReqBody
  , Server
  , err400
  , errBody
  , serve
  , throwError
  )
import Servant.Server.StaticFiles (serveDirectoryWith)
import System.FilePath ((</>))

type API =
  "states" :> Get '[JSON] [LeelaState]
    :<|> "hexagrams" :> Get '[JSON] [Hexagram]
    :<|> "reading" :> ReqBody '[JSON] ReadingRequest :> Post '[JSON] Reading
    :<|> "interpret" :> ReqBody '[JSON] ReadingRequest :> Post '[JSON] Interpretation
    :<|> "casting" :> "current" :> Get '[JSON] CastingState
    :<|> "casting" :> "new" :> Post '[JSON] CastingState
    :<|> "casting" :> "next" :> Post '[JSON] CastingState
    :<|> "health" :> Get '[JSON] Health
    :<|> Raw

app :: FilePath -> DomainData -> IORef CastingState -> Application
app staticDirectory domain castingRef =
  serve apiProxy (server staticDirectory domain castingRef)

apiProxy :: Proxy API
apiProxy = Proxy

server :: FilePath -> DomainData -> IORef CastingState -> Server API
server staticDirectory domain castingRef =
  pure (leelaStates domain)
    :<|> pure (hexagrams domain)
    :<|> createReading domain
    :<|> createInterpretation domain
    :<|> getCastingState castingRef
    :<|> startNewCasting castingRef
    :<|> advanceCasting castingRef
    :<|> pure (Health "ok" "tao-of-lila")
    :<|> serveStaticClient staticDirectory

serveStaticClient :: FilePath -> Server Raw
serveStaticClient staticDirectory =
  serveDirectoryWith
    ( (defaultWebAppSettings staticDirectory)
        { ss404Handler = Just (serveIndex staticDirectory)
        }
    )

serveIndex :: FilePath -> Application
serveIndex staticDirectory _ respond =
  respond $
    responseFile
      status200
      [(hContentType, "text/html; charset=utf-8")]
      (staticDirectory </> "index.html")
      Nothing

createReading :: DomainData -> ReadingRequest -> Handler Reading
createReading domain request =
  case generateReading domain request of
    Right reading -> pure reading
    Left err -> throwReadingError err

createInterpretation :: DomainData -> ReadingRequest -> Handler Interpretation
createInterpretation domain request =
  readingInterpretation <$> createReading domain request

getCastingState :: IORef CastingState -> Handler CastingState
getCastingState castingRef =
  liftIO (readIORef castingRef)

startNewCasting :: IORef CastingState -> Handler CastingState
startNewCasting castingRef =
  liftIO $ do
    writeIORef castingRef initialCastingState
    pure initialCastingState

advanceCasting :: IORef CastingState -> Handler CastingState
advanceCasting castingRef =
  liftIO $
    atomicModifyIORef'
      castingRef
      ( \state ->
          let nextState = nextCastingState state
           in (nextState, nextState)
      )

throwReadingError :: ReadingError -> Handler a
throwReadingError err =
  throwError
    err400
      { errBody =
          encode
            (object ["error" .= renderReadingError err])
      }

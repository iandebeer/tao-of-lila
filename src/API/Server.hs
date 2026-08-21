{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module API.Server (API, app) where

import Control.Exception (try)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (encode, object, (.=))
import Data.Text (Text)
import Domain.Game
import Domain.Types (DomainData (..), Health (..), Hexagram, Interpretation, LeelaState, Reading (..), ReadingRequest)
import Engine.Reading (ReadingError (..), generateReading)
import Network.HTTP.Types (hContentType, status200)
import Network.Wai (Application, responseFile)
import Network.Wai.Application.Static (StaticSettings (..), defaultWebAppSettings)
import Persistence.Postgres
import Servant
  ( (:<|>) (..), (:>), Capture, Delete, Get, Handler, Header, JSON, Post
  , Proxy (..), Put, Raw, ReqBody, Server, ServerError, err400, err401
  , err404, err409, err500, errBody, serve, throwError
  )
import Servant.Server.StaticFiles (serveDirectoryWith)
import System.FilePath ((</>))

type Protected = Header "Authorization" Text

type API =
  "states" :> Get '[JSON] [LeelaState]
    :<|> "hexagrams" :> Get '[JSON] [Hexagram]
    :<|> "reading" :> ReqBody '[JSON] ReadingRequest :> Post '[JSON] Reading
    :<|> "interpret" :> ReqBody '[JSON] ReadingRequest :> Post '[JSON] Interpretation
    :<|> "auth" :> "register" :> ReqBody '[JSON] AuthRequest :> Post '[JSON] AuthResponse
    :<|> "auth" :> "login" :> ReqBody '[JSON] AuthRequest :> Post '[JSON] AuthResponse
    :<|> "game" :> Protected :> Get '[JSON] GameView
    :<|> "game" :> "question" :> Protected :> ReqBody '[JSON] QuestionRequest :> Post '[JSON] GameView
    :<|> "game" :> "question" :> Capture "questionId" Int :> Protected :> ReqBody '[JSON] QuestionRequest :> Put '[JSON] GameView
    :<|> "game" :> "question" :> Capture "questionId" Int :> Protected :> Delete '[JSON] GameView
    :<|> "game" :> "casting" :> "new" :> Protected :> Post '[JSON] GameView
    :<|> "game" :> "casting" :> "next" :> Protected :> Post '[JSON] GameView
    :<|> "game" :> "journal" :> Capture "eventId" Int :> Protected :> ReqBody '[JSON] JournalRequest :> Put '[JSON] GameView
    :<|> "health" :> Get '[JSON] Health
    :<|> Raw

app :: FilePath -> DomainData -> Store -> Application
app staticDirectory domain store = serve (Proxy :: Proxy API) server
  where
    server :: Server API
    server =
      pure (leelaStates domain)
        :<|> pure (hexagrams domain)
        :<|> createReading domain
        :<|> createInterpretation domain
        :<|> (runStore . register store)
        :<|> (runStore . login store)
        :<|> withUser store (getGameView store domain)
        :<|> (\authorization request -> withUser store (\user -> createQuestion store domain user request) authorization)
        :<|> (\requestedQuestionId authorization request -> withUser store (\user -> updateQuestion store domain user requestedQuestionId request) authorization)
        :<|> (\requestedQuestionId authorization -> withUser store (\user -> deleteQuestion store domain user requestedQuestionId) authorization)
        :<|> withUser store (newCasting store domain)
        :<|> withUser store (nextCasting store domain)
        :<|> (\eventId authorization request -> withUser store (\user -> saveJournal store domain user eventId request) authorization)
        :<|> pure (Health "ok" "tao-of-lila")
        :<|> serveStaticClient staticDirectory

withUser :: Store -> (User -> IO a) -> Maybe Text -> Handler a
withUser store action authorization = do
  header <- maybe (throwError (jsonError err401 "Authorization is required")) pure authorization
  user <- runStore (authenticate store header)
  runStore (action user)

runStore :: IO a -> Handler a
runStore action = do
  outcome <- liftIO (try action)
  case outcome of
    Right value -> pure value
    Left storeError -> throwError (renderStoreError storeError)

renderStoreError :: StoreError -> ServerError
renderStoreError InvalidCredentials = jsonError err401 "Invalid username, password, or session"
renderStoreError UsernameTaken = jsonError err409 "That username is already registered"
renderStoreError (InvalidInput message) = jsonError err400 message
renderStoreError (NotFound message) = jsonError err404 (message <> " not found")
renderStoreError (Conflict message) = jsonError err409 message
renderStoreError (CorruptData message) = jsonError err500 message

jsonError :: ServerError -> Text -> ServerError
jsonError base message = base {errBody = encode (object ["error" .= message])}

serveStaticClient :: FilePath -> Server Raw
serveStaticClient staticDirectory = serveDirectoryWith ((defaultWebAppSettings staticDirectory) {ss404Handler = Just (serveIndex staticDirectory)})

serveIndex :: FilePath -> Application
serveIndex staticDirectory _ respond = respond $ responseFile status200 [(hContentType, "text/html; charset=utf-8")] (staticDirectory </> "index.html") Nothing

createReading :: DomainData -> ReadingRequest -> Handler Reading
createReading domain request = case generateReading domain request of
  Right reading -> pure reading
  Left err -> throwError (jsonError err400 (renderReadingError err))

createInterpretation :: DomainData -> ReadingRequest -> Handler Interpretation
createInterpretation domain request = readingInterpretation <$> createReading domain request

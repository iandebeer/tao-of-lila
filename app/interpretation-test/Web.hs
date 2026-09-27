{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module Web (runWeb) where

import Control.Exception (try)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (FromJSON, encode, object, (.=))
import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as T
import Domain.Contemplation
import Domain.Types (DomainData (..), LeelaState (..))
import GHC.Generics (Generic)
import Interpretation.ContemplationModel (ContemplationModel (..), ModelError (..))
import Network.Wai.Handler.Warp (defaultSettings, runSettings, setHost, setPort)
import Servant

data PairRequest = PairRequest
  { primary :: Int
  , resulting :: Int
  , question :: Text
  , leelaState :: Int
  } deriving (Generic)

instance FromJSON PairRequest

type TestAPI =
       "api" :> "states" :> Get '[JSON] [LeelaState]
  :<|> "api" :> "preview" :> ReqBody '[JSON] PairRequest :> Post '[JSON] ContemplationContext
  :<|> "api" :> "interpret" :> ReqBody '[JSON] PairRequest :> Post '[JSON] ModelResult
  :<|> Raw

runWeb :: DomainData -> ContemplationModel -> IO ()
runWeb domain model = do
  putStrLn "Interpretation test: http://127.0.0.1:8081/"
  runSettings (setHost "127.0.0.1" (setPort 8081 defaultSettings))
    (serve (Proxy :: Proxy TestAPI) server)
  where
    server :: Server TestAPI
    server = pure (leelaStates domain) :<|> preview :<|> interpret :<|> serveDirectoryFileServer "app/public/interpretation-test"
    preview :: PairRequest -> Handler ContemplationContext
    preview request = do
      let inquiry = T.strip (question request)
      if T.null inquiry then throwError (failure err400 "Please enter a question") else pure ()
      state <- maybe (throwError (failure err400 "Leela state was not found")) pure
        (find ((== leelaState request) . stateId) (leelaStates domain))
      either (throwError . failure err400) pure
        (buildPairContemplationContext state inquiry (primary request) (resulting request))
    interpret :: PairRequest -> Handler ModelResult
    interpret request = do
      context <- preview request
      outcome <- liftIO (try (contemplate model context) :: IO (Either ModelError ModelResult))
      either (throwError . failure err503 . renderModelError) pure outcome

failure :: ServerError -> Text -> ServerError
failure base message = base
  { errBody = encode (object ["error" .= message])
  , errHeaders = [("Content-Type", "application/json")]
  }

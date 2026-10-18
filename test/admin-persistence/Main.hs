{-# LANGUAGE OverloadedStrings #-}
module Main (main) where
import API.Admin
import Control.Exception (bracket, finally)
import Control.Monad (unless)
import Data.Aeson
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString.Char8 as B
import qualified Data.ByteString.Lazy as L
import Data.ByteString.Builder (toLazyByteString)
import Data.IORef
import Data.String (fromString)
import qualified Data.Text as T
import Data.Time.Clock.POSIX (getPOSIXTime)
import Database.PostgreSQL.Simple
import Network.HTTP.Types
import Network.Wai
import Network.Wai.Internal (ResponseReceived(..))
import Persistence.Postgres
import qualified Persistence.Analytics as Analytics
import Domain.Game
import System.Environment (lookupEnv)

main :: IO ()
main = do
  configured <- lookupEnv "TAO_ADMIN_TEST_DB"
  case configured of
    Nothing -> putStrLn "SKIP admin database acceptance: set TAO_ADMIN_TEST_DB to a disposable PostgreSQL connection string"
    Just raw -> do
      stamp <- round . (*1000000) <$> getPOSIXTime :: IO Integer
      let schema="admin_test_"<>show stamp
          scoped=if "postgres" `T.isPrefixOf` T.pack raw then raw<>(if '?' `elem` raw then "&" else "?")<>"options=-csearch_path%3D"<>schema else raw<>" options='-c search_path="<>schema<>"'"
      bracket (connectPostgreSQL (B.pack raw)) close $ \c -> do
        _ <- execute_ c (fromString ("CREATE SCHEMA "<>schema))
        acceptance (newStore (B.pack scoped)) `finally` execute_ c (fromString ("DROP SCHEMA "<>schema<>" CASCADE"))

acceptance :: Store -> IO ()
acceptance store = do
  migrate store
  migrate store
  let config=AdminConfig "https://play.leela.day" "test-only-setup-secret-at-least-32-characters"
      application=adminRouter (Just config) store "app/admin" (\_ respond -> respond (responseLBS status404 [] ""))
      credentials=object ["username" .= ("admin"::T.Text),"password" .= ("test-only-admin-password"::T.Text),"setupToken" .= adminSetupToken config]
      call method path body session=do
        chunks <- newIORef [L.toStrict (encode body)]
        responseRef <- newIORef (status500,[],L.empty)
        let request=defaultRequest {requestHeaderHost=Just "play.leela.day",isSecure=True,requestMethod=method,pathInfo=["admin","api",path],requestHeaders=[(hOrigin,"https://play.leela.day"),("X-Admin-Request","1"),(hCookie,session)],requestBody=atomicModifyIORef' chunks (\xs -> case xs of [] -> ([],B.empty); x:rest -> (rest,x))}
        _ <- application request $ \response -> do
          let (status,hs,withBody)=responseToStream response
          bytes <- newIORef L.empty
          withBody $ \stream -> stream (\builder -> modifyIORef' bytes (<>toLazyByteString builder)) (pure ())
          content <- readIORef bytes
          writeIORef responseRef (status,hs,content)
          pure ResponseReceived
        readIORef responseRef
      expect label wanted (actual,_,_)=unless (wanted==actual) (fail label)
  call methodGet "stats" Null "" >>= expect "unauthenticated stats" status401
  result@(_,hs,_) <- call methodPost "setup" credentials ""
  expect "one-time setup" status200 result
  let session=B.takeWhile (/=';') (maybe "" id (lookup "Set-Cookie" hs))
  unless (not (B.null session) && all (\flag -> maybe False (B.isInfixOf flag) (lookup "Set-Cookie" hs)) ["Secure","HttpOnly","SameSite=Strict"]) (fail "secure cookie flags")
  call methodPost "setup" credentials "" >>= expect "setup cannot overwrite existing account" status401
  call methodGet "stats" Null session >>= expect "authenticated dashboard" status200
  call methodGet "stats" Null "__Host-leela_admin=invalid" >>= expect "invalid session" status401
  _ <- register store (AuthRequest "analytics-test-player" "test-only-player-password")
  _ <- login store (AuthRequest "analytics-test-player" "test-only-player-password")
  withStore store $ \c -> do
    [Only uid] <- query_ c "SELECT id FROM users" :: IO [Only Int]
    Analytics.recordActivity c uid
    Analytics.recordActivity c uid
    Analytics.recordEvent c uid "cast" (Just 123)
    Analytics.recordEvent c uid "cast" (Just 123)
    Analytics.recordEvent c uid "move" (Just 123)
    _ <- execute c "INSERT INTO player_activity(user_id,day) VALUES (?,(now() AT TIME ZONE 'UTC')::date-1)" (Only uid)
    _ <- execute c "INSERT INTO personas(player_id,document,archived) VALUES (?,'{}',FALSE),(?,'{}',TRUE)" (uid,uid)
    mapM_ (\period -> do
      value <- Analytics.dashboard c period 0
      let field key (Object fields)=KM.lookup key fields
          field _ _=Nothing
          expected key number=unless ((field "summary" value >>= field key)==Just (Number number)) (fail ("wrong metric "<>show key))
      expected "players" 1
      expected "personas" 2
      expected "activePersonas" 1
      expected "archivedPersonas" 1
      expected "newPersonas" 2
      expected "logins" 1
      expected "casts" 1
      expected "moves" 1
      expected "dailyActive" 1
      expected "returningPlayers" 1
      case field "trends" value of
        Just (Array values) -> unless (length values==(if period=="daily" then 30 else 12)) (fail "bucket count")
        _ -> fail "missing trends") ["daily","weekly","monthly"]
    _ <- execute_ c "UPDATE admin_sessions SET last_seen=now()-interval '31 minutes'"
    pure ()
  call methodGet "stats" Null session >>= expect "idle expiry" status401
  (_,loginHeaders,_) <- call methodPost "login" credentials ""
  let nextSession=B.takeWhile (/=';') (maybe "" id (lookup "Set-Cookie" loginHeaders))
  withStore store $ \c -> do
    _ <- execute_ c "UPDATE admin_sessions SET created_at=now()-interval '13 hours'"
    pure ()
  call methodGet "stats" Null nextSession >>= expect "absolute expiry" status401
  (_,freshHeaders,_) <- call methodPost "login" credentials ""
  let freshSession=B.takeWhile (/=';') (maybe "" id (lookup "Set-Cookie" freshHeaders))
  call methodPost "logout" (object []) freshSession >>= expect "logout" status200
  call methodGet "stats" Null freshSession >>= expect "revoked session" status401
  let wrong=object ["username" .= ("admin"::T.Text),"password" .= ("incorrect-test-password"::T.Text)]
  mapM_ (\_ -> call methodPost "login" wrong "" >>= expect "bad login" status401) [1..5::Int]
  call methodPost "login" credentials "" >>= expect "persistent rate limit" status429
  withStore store $ \c -> do
    _ <- execute_ c "UPDATE admin_attempts SET window_start=now()-interval '16 minutes'"
    pure ()
  call methodPost "login" credentials "" >>= expect "rate limit window resets" status200
  putStrLn "ok - admin setup, cookies, auth, expiry, logout, throttling, analytics deduplication, Persona counts and reporting periods"

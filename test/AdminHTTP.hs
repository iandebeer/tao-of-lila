{-# LANGUAGE OverloadedStrings #-}
module AdminHTTP (checkAdminHTTP) where
import API.Admin
import Control.Monad (unless)
import Network.HTTP.Types
import Network.Wai
import Network.Wai.Internal (ResponseReceived(..))
import Persistence.Postgres (newStore)
import qualified Data.Text as T

checkAdminHTTP :: IO ()
checkAdminHTTP = do
  let config=AdminConfig "https://admin.leela.day" ""
      public _ respond=respond (responseLBS status418 [] "public")
      application=adminRouter (Just config) (newStore "") "app/admin" public
      request=defaultRequest {requestHeaderHost=Just "admin.leela.day",isSecure=True}
      check label req expected=do
        _ <- application req $ \response -> do
          unless (responseStatus response==expected) (fail label)
          if expected==status418 then pure () else do
            unless (lookup hCacheControl (responseHeaders response)==Just "no-store") (fail "admin response is cacheable")
            unless (lookup "X-Frame-Options" (responseHeaders response)==Just "DENY") (fail "admin can be framed")
          pure ResponseReceived
        putStrLn ("ok - "<>label)
  check "admin login page served only on configured host" request status200
  check "public host never dispatches admin API" request {requestHeaderHost=Just "play.leela.day",pathInfo=["api","stats"]} status418
  check "HTTPS required" request {isSecure=False} status403
  check "unknown admin route does not fall through to game" request {pathInfo=["game"]} status404
  check "cross-origin admin setup rejected before touching database" request {requestMethod=methodPost,pathInfo=["api","setup"],requestHeaders=[(hOrigin,"https://play.leela.day"),("X-Admin-Request","1")]} status403
  check "missing CSRF header rejected" request {requestMethod=methodPost,pathInfo=["api","logout"],requestHeaders=[(hOrigin,"https://admin.leela.day")]} status403
  unless (validOrigin "https://admin.leela.day" && all (not . validOrigin) ["http://admin.leela.day","https://admin.leela.day/path","https://admin.leela.day@evil.test"]) (fail "admin origin validation")
  unless (passwordValid "testing-password-only" && not (passwordValid "short") && not (passwordValid (T.replicate 25 "界"))) (fail "bcrypt byte limit validation")

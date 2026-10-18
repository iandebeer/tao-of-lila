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
  let config=AdminConfig "https://play.leela.day" ""
      public _ respond=respond (responseLBS status418 [] "public")
      application=adminRouter (Just config) (newStore "") "app/admin" public
      request=defaultRequest {requestHeaderHost=Just "play.leela.day",isSecure=True,pathInfo=["admin"]}
      check label req expected=do
        _ <- application req $ \response -> do
          unless (responseStatus response==expected) (fail label)
          if expected==status418 then pure () else do
            unless (lookup hCacheControl (responseHeaders response)==Just "no-store") (fail "admin response is cacheable")
            unless (lookup "X-Frame-Options" (responseHeaders response)==Just "DENY") (fail "admin can be framed")
          pure ResponseReceived
        putStrLn ("ok - "<>label)
  check "admin login page served only on configured host" request status200
  check "public host never dispatches admin API" request {requestHeaderHost=Just "other.leela.day",pathInfo=["admin","api","stats"]} status418
  check "trailing slash serves dashboard" request {pathInfo=["admin",""]} status200
  check "game route remains public" request {pathInfo=["journey"]} status418
  check "public root remains public" request {pathInfo=[]} status418
  check "unprefixed API remains public" request {pathInfo=["api","stats"]} status418
  check "similar prefix remains public" request {pathInfo=["administrator"]} status418
  check "admin asset is mounted under prefix" request {pathInfo=["admin","admin.js"]} status200
  _ <- adminRouter Nothing (newStore "") "app/admin" public request $ \response -> do
    unless (responseStatus response==status418) (fail "disabled administration falls through")
    pure ResponseReceived
  check "HTTPS required" request {isSecure=False} status403
  check "unknown admin route does not fall through to game" request {pathInfo=["admin","unknown"]} status404
  check "cross-origin admin setup rejected before touching database" request {requestMethod=methodPost,pathInfo=["admin","api","setup"],requestHeaders=[(hOrigin,"https://other.leela.day"),("X-Admin-Request","1")]} status403
  check "missing CSRF header rejected" request {requestMethod=methodPost,pathInfo=["admin","api","logout"],requestHeaders=[(hOrigin,"https://play.leela.day")]} status403
  unless (validOrigin "https://play.leela.day" && all (not . validOrigin) ["http://play.leela.day","https://play.leela.day/path","https://play.leela.day@evil.test"]) (fail "admin origin validation")
  unless (passwordValid "testing-password-only" && not (passwordValid "short") && not (passwordValid (T.replicate 25 "界"))) (fail "bcrypt byte limit validation")

{-# LANGUAGE OverloadedStrings #-}
module API.Admin (AdminConfig(..), adminRouter, validOrigin, passwordValid) where

import Control.Exception (try, SomeException)
import Crypto.BCrypt (hashPasswordUsingPolicy, slowerBcryptHashingPolicy, validatePassword)
import Crypto.Hash (hash, Digest, SHA256)
import Crypto.Random (getRandomBytes)
import Data.Aeson (Value, object, (.=), eitherDecode)
import Data.Aeson.Types (parseMaybe, withObject, (.:))
import qualified Data.Aeson as A
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as B8
import qualified Data.ByteString.Lazy as LBS
import qualified Data.ByteArray as BA
import Data.Char (isAsciiLower, isDigit)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Database.PostgreSQL.Simple
import Network.HTTP.Types
import Network.Wai
import Numeric (showHex)
import Persistence.Postgres (Store, withStore)
import qualified Persistence.Analytics as Analytics
import System.FilePath ((</>))
import Text.Read (readMaybe)

data AdminConfig = AdminConfig { adminOrigin :: Text, adminSetupToken :: Text }

-- An explicit origin prevents accidentally exposing administration on game hosts.
validOrigin :: Text -> Bool
validOrigin origin = case T.stripPrefix "https://" origin of
  Just host -> not (T.null host) && T.any (=='.') host && T.all (\c -> isAsciiLower c || isDigit c || c=='.' || c=='-') host
  _ -> False

passwordValid :: Text -> Bool
passwordValid password = T.length password >= 12 && BS.length (TE.encodeUtf8 password) <= 72

digest :: BS.ByteString -> Text
digest = T.pack . show . (hash :: BS.ByteString -> Digest SHA256)

-- Compare digests using the cryptographic library's constant-time primitive.
sameSecret :: Text -> Text -> Bool
sameSecret a b = BA.constEq (TE.encodeUtf8 (digest (TE.encodeUtf8 a))) (TE.encodeUtf8 (digest (TE.encodeUtf8 b)))

adminRouter :: Maybe AdminConfig -> Store -> FilePath -> Application -> Application
adminRouter Nothing _ _ public = public
adminRouter (Just config) store directory public = \request respond ->
  if requestHeaderHost request /= Just (TE.encodeUtf8 (T.drop 8 (adminOrigin config))) then public request respond
  else if not (isSecure request || lookup "X-Forwarded-Proto" (requestHeaders request)==Just "https")
    then respond (json status403 [] (object ["error" .= ("HTTPS is required" :: Text)]))
    else do
      result <- try (route config store directory request) :: IO (Either SomeException Response)
      respond $ either (const (json status500 [] (object ["error" .= ("Administration is temporarily unavailable" :: Text)]))) id result

headers :: ResponseHeaders
headers = [(hCacheControl,"no-store"),("X-Content-Type-Options","nosniff"),("X-Frame-Options","DENY"),("Referrer-Policy","no-referrer"),("Content-Security-Policy","default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'"),("Strict-Transport-Security","max-age=31536000"),("X-Robots-Tag","noindex, nofollow")]

json :: Status -> ResponseHeaders -> Value -> Response
json status extra value = responseLBS status ((hContentType,"application/json"):extra++headers) (A.encode value)

cookie :: BS.ByteString -> BS.ByteString
cookie token = "__Host-leela_admin="<>token<>"; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=43200"

sessionHash :: Request -> Text
sessionHash request = digest $ fromMaybe "" $ lookup "__Host-leela_admin" pairs
  where
    pairs = map (\part -> let (key,val)=B8.break (=='=') (B8.dropWhile (==' ') part) in (key,BS.drop 1 val)) (B8.split ';' (fromMaybe "" (lookup hCookie (requestHeaders request))))

route :: AdminConfig -> Store -> FilePath -> Request -> IO Response
route config store directory request
  | requestMethod request==methodGet, pathInfo request==[] = pure (asset "index.html" "text/html; charset=utf-8")
  | requestMethod request==methodGet, pathInfo request==["admin.js"] = pure (asset "admin.js" "text/javascript; charset=utf-8")
  | requestMethod request==methodGet, pathInfo request==["admin.css"] = pure (asset "admin.css" "text/css; charset=utf-8")
  | requestMethod request==methodGet, pathInfo request==["api","status"] = withStore store $ \c -> do
      accounts <- query_ c "SELECT EXISTS(SELECT 1 FROM admin_account)" :: IO [Only Bool]
      pure (json status200 [] (object ["needsSetup" .= (accounts==[Only False]),"setupEnabled" .= (T.length (adminSetupToken config)>=32)]))
  | requestMethod request==methodPost && not sameOrigin = pure (json status403 [] (object ["error" .= ("Same-origin request required" :: Text)]))
  | requestMethod request==methodPost, pathInfo request `elem` [["api","login"],["api","setup"]] = do
      body <- limitedBody request
      case body >>= either (const Nothing) Just . eitherDecode of
        Nothing -> pure (json status400 [] (object ["error" .= ("Invalid request" :: Text)]))
        Just value -> credentials config store (pathInfo request==["api","setup"]) value
  | requestMethod request==methodPost, pathInfo request==["api","logout"] = withStore store $ \c -> do
      _ <- execute c "DELETE FROM admin_sessions WHERE token_hash=?" (Only (sessionHash request))
      pure (json status200 [("Set-Cookie","__Host-leela_admin=; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=0")] (object ["ok" .= True]))
  | requestMethod request==methodGet, pathInfo request==["api","stats"] = withStore store $ \c -> withTransaction c $ do
      session <- query c "UPDATE admin_sessions SET last_seen=now() WHERE token_hash=? AND last_seen>now()-interval '30 minutes' AND created_at>now()-interval '12 hours' RETURNING token_hash" (Only (sessionHash request)) :: IO [Only Text]
      if null session then pure (json status401 [] (object ["error" .= ("Please sign in. Your session may have expired." :: Text)])) else do
        let period = TE.decodeUtf8 (fromMaybe "daily" (lookup "period" (queryString request) >>= id))
            page = fromMaybe 0 (lookup "page" (queryString request) >>= id >>= readMaybe . B8.unpack)
        if period `notElem` ["daily","weekly","monthly"] || page<0 || page>100000 then pure (json status400 [] (object ["error" .= ("Invalid reporting period or page" :: Text)]))
        else json status200 [] <$> Analytics.dashboard c period page
  | otherwise = pure (json status404 [] (object ["error" .= ("Not found" :: Text)]))
  where
    asset name mime = responseFile status200 ((hContentType,mime):headers) (directory </> name) Nothing
    sameOrigin = lookup hOrigin (requestHeaders request)==Just (TE.encodeUtf8 (adminOrigin config)) && lookup "X-Admin-Request" (requestHeaders request)==Just "1"

limitedBody :: Request -> IO (Maybe LBS.ByteString)
limitedBody request = loop 0 []
  where
    loop count chunks = do
      chunk <- getRequestBodyChunk request
      let size = count + BS.length chunk
      if size>4096 then pure Nothing
      else if BS.null chunk then pure (Just (LBS.fromChunks (reverse chunks))) else loop size (chunk:chunks)

credentials :: AdminConfig -> Store -> Bool -> Value -> IO Response
credentials config store setup value = withStore store $ \c -> withTransaction c $ do
  -- A database row lock shares the rate limit and setup exclusion across replicas.
  _ <- query_ c "SELECT singleton FROM admin_attempts FOR UPDATE" :: IO [Only Bool]
  _ <- execute_ c "UPDATE admin_attempts SET window_start=now(),attempts=0 WHERE window_start<=now()-interval '15 minutes'"
  attempts <- query_ c "UPDATE admin_attempts SET attempts=attempts+1 RETURNING attempts" :: IO [Only Int]
  if any ((>5) . fromOnly) attempts then pure (json status429 [("Retry-After","900")] (object ["error" .= ("Too many attempts. Try again in 15 minutes." :: Text)])) else do
    let get key = fromMaybe "" (parseMaybe (withObject "credentials" (.: key)) value)
        password = get "password"
        username = get "username" :: Text
    accounts <- query_ c "SELECT password_hash FROM admin_account" :: IO [Only BS.ByteString]
    accepted <- if setup then
      if null accounts && T.length (adminSetupToken config)>=32 && sameSecret (get "setupToken") (adminSetupToken config) && passwordValid password && username=="admin"
      then do
        hashed <- hashPasswordUsingPolicy slowerBcryptHashingPolicy (TE.encodeUtf8 password)
        case hashed of
          Just passwordHash -> do
            _ <- execute c "INSERT INTO admin_account(singleton,password_hash) VALUES(TRUE,?)" (Only passwordHash)
            pure True
          Nothing -> pure False
      else pure False
      else pure $ case accounts of
        [Only passwordHash] -> username=="admin" && passwordValid password && validatePassword passwordHash (TE.encodeUtf8 password)
        _ -> False
    if not accepted then pure (json status401 [] (object ["error" .= (if setup then "Setup failed. Check the setup secret and use a password of at least 12 characters and at most 72 UTF-8 bytes." else "Incorrect administrator credentials." :: Text)])) else do
      bytes <- getRandomBytes 32 :: IO BS.ByteString
      let token = B8.pack (concatMap (\v -> let h=showHex v "" in if length h==1 then '0':h else h) (BS.unpack bytes))
      _ <- execute_ c "DELETE FROM admin_sessions WHERE last_seen<=now()-interval '30 minutes' OR created_at<=now()-interval '12 hours'"
      _ <- execute c "INSERT INTO admin_sessions(token_hash) VALUES(?)" (Only (digest token))
      _ <- execute_ c "UPDATE admin_attempts SET attempts=0,window_start=now()"
      pure (json status200 [("Set-Cookie",cookie token)] (object ["ok" .= True]))

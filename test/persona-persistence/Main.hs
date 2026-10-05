{-# LANGUAGE OverloadedStrings #-}
module Main (main) where
import Control.Exception (bracket, finally, try)
import Control.Monad (unless)
import qualified Data.ByteString.Char8 as B
import qualified Data.Text as T
import Data.Time.Clock.POSIX (getPOSIXTime)
import Database.PostgreSQL.Simple
import Data.String (fromString)
import qualified Database.PostgreSQL.Simple.Newtypes as PG
import Data.Aeson (Value (..), fromJSON, Result (..))
import qualified Data.Aeson.KeyMap as KM
import Domain.Contemplation (ContemplationResponse (..))
import Domain.Game
import Domain.Journey
import Domain.Persona
import Domain.Loading (loadDomainData)
import qualified Engine.Casting as Casting
import Persistence.Postgres
import qualified Persistence.Persona as P
import qualified Persistence.Journey as J
import System.Environment (lookupEnv)

main :: IO ()
main = do
  configured <- lookupEnv "TAO_PERSONA_TEST_DB"
  case configured of
    Nothing -> putStrLn "SKIP PostgreSQL persona acceptance: set TAO_PERSONA_TEST_DB to a disposable PostgreSQL connection string"
    Just raw -> do
      stamp <- round . (*1000000) <$> getPOSIXTime :: IO Integer
      let schema = "persona_test_" ++ show stamp
          scoped = if "postgres" `T.isPrefixOf` T.pack raw
            then raw ++ (if '?' `elem` raw then "&" else "?") ++ "options=-csearch_path%3D" ++ schema
            else raw ++ " options='-c search_path=" ++ schema ++ "'"
          store = newStore (B.pack scoped)
      bracket (connectPostgreSQL (B.pack raw)) close $ \admin -> do
        _ <- execute_ admin (fromString ("CREATE SCHEMA " ++ schema))
        acceptance store `finally` execute_ admin (fromString ("DROP SCHEMA " ++ schema ++ " CASCADE"))

acceptance :: Store -> IO ()
acceptance store = do
  domain <- loadDomainData "data" >>= either (fail . show) pure
  migrate store
  migrate store
  -- Registration must round-trip through the same stored hash on later login.
  let credentials = AuthRequest "  Returning_Player  " "known-test-password"
  registered <- register store credentials
  loggedIn <- login store (AuthRequest "returning_player" "known-test-password")
  assert "registered Player can log in with a persisted password" (userId (authUser registered) == userId (authUser loggedIn))
  invalid <- try (login store (AuthRequest "returning_player" "incorrect-test-password")) :: IO (Either StoreError AuthResponse)
  assert "incorrect passwords are rejected" (invalid == Left InvalidCredentials)
  duplicate <- try (register store credentials) :: IO (Either StoreError AuthResponse)
  assert "duplicate registration is rejected independently of login" (duplicate == Left UsernameTaken)
  verified <- authenticate store (authToken loggedIn)
  assert "login token authenticates the same Player" (userId verified == userId (authUser registered))
  expired <- try (authenticate store "missing-session") :: IO (Either StoreError User)
  assert "expired session is distinct from incorrect credentials" (expired == Left InvalidSession)
  let owner = verified
  empty <- P.listPersonas store owner
  assert "new account has no invented Personas" (null empty)
  let profile = [PersonaAttribute "sex" (String "Female") PlayerSpecified [],PersonaAttribute "age" (Number 62) PlayerSpecified [],PersonaAttribute "raceEthnicity" (String "Self-described heritage") PlayerSpecified [],PersonaAttribute "historicalPeriod" (String "Medieval period") PlayerSpecified []]
      draft = PersonaDraft "Constructed scholar" "elderly, fictional" profile "Additional information" Nothing Nothing
  a <- P.createPersona store owner draft
  oneLogin <- login store credentials
  oneUser <- authenticate store (authToken oneLogin)
  assert "login selects the only active persona" (userPersonaId oneUser == Just (personaId a))
  b <- P.createPersona store owner draft
  manyLogin <- login store credentials
  manyUser <- authenticate store (authToken manyLogin)
  assert "login with multiple personas requires an explicit selection" (userPersonaId manyUser == Nothing)
  migrate store
  stable <- P.listPersonas store owner
  assert "normal startup retains personas in the current schema" (length stable == 2)
  storedProfile <- P.getPersona store owner (personaId a)
  assert "structured Persona attributes and additional information persist" (personaInitialAttributes storedProfile==profile && personaContext storedProfile=="Additional information")
  assert "one Player can create multiple Personas" (personaId a/=personaId b && personaPlayerId a==personaPlayerId b)
  let ua=owner {userPersonaId=Just (personaId a)}; ub=owner {userPersonaId=Just (personaId b)}
  _ <- createQuestion store domain ua (QuestionRequest "A question")
  starts <- mapM (\_ -> newCasting store domain ua) ([1..8] :: [Int])
  assert "new prototype castings receive fresh seeds" (any ((/= gameCasting (head starts)) . gameCasting) (tail starts))
  ga <- getGameView store domain ua
  assert "loading a casting preserves its seed" (gameCasting ga == gameCasting (last starts))
  let complete=until ((/=Nothing) . Casting.result) Casting.nextCastingState Casting.initialCastingState
  case (gameQuestion ga,Casting.result complete) of
    (Just q,Just r) -> withStore store $ \c -> completeCasting c (gameJourney ga) q complete r
    _ -> fail "Fixture casting did not complete"
  after <- getGameView store domain ua
  _ <- saveJournal store domain ua (gameEventId (head (gameHistory after))) (JournalRequest "A private journal")
  untouched <- getGameView store domain ub
  assert "independent board positions" (journeyCurrentStateId (gameJourney untouched)==1)
  assert "independent casting histories" (gameCasting untouched==Nothing && null (gameHistory untouched))
  assert "independent questions and journals" (gameQuestion untouched==Nothing && null (gameHistory untouched))
  edited <- P.updatePersona store owner (personaId a) draft {draftDescription="changed",draftRevision=Just 0}
  sibling <- P.getPersona store owner (personaId b)
  assert "editing A leaves B unchanged" (sibling==b && personaInitialDescription edited==personaDescription a)
  denied <- try (P.getPersona store (User 999 "unrelated" Nothing) (personaId a)) :: IO (Either StoreError Persona)
  assert "another Player cannot read the Persona" (case denied of Left (NotFound _) -> True; _ -> False)
  evidence <- P.recordEvidence store owner (personaId a) "uncertainty" (Evidence "question:1" AIInferred "question:1" 0.5 True "2026-09-23")
  assert "inferred evidence is persisted separately from initial context" (not (null (personaThemes evidence)) && personaInitialDescription evidence==personaDescription a)
  rejected <- P.rejectTheme store owner (personaId a) "uncertainty"
  audit <- P.personaHistory store owner (personaId a)
  assert "Player can reject inferred themes while audit remains" (null (personaThemes rejected) && not (null audit))
  -- A previous model response supplies a proposal; edits must not replace it.
  withStore store $ \c -> do
    _ <- execute c "INSERT INTO contemplations(game_event_id,response) VALUES(?,?)" (gameEventId (head (gameHistory after)),PG.Aeson (ContemplationResponse "context" "primary" [] "change" [] ["AI proposed question"]))
    pure ()
  initial <- J.getJourney store domain ua
  questioning <- J.commandJourney store domain ua (JourneyCommand (revision initial) (userPersonaId ua) "question" Nothing Nothing)
  suggested <- J.commandJourney store domain ua (JourneyCommand (revision questioning) (userPersonaId ua) "suggest" Nothing Nothing)
  drafted <- J.commandJourney store domain ua (JourneyCommand (revision suggested) (userPersonaId ua) "draft" (Just "Player replacement") Nothing)
  begun <- J.commandJourney store domain ua (JourneyCommand (revision drafted) (userPersonaId ua) "begin" Nothing Nothing)
  resumed <- J.getJourney store domain ua
  assert "reloading a journey preserves the casting" (begun == resumed)
  stored <- withStore store $ \c -> query c "SELECT ai_proposed_text,player_final_text,finalized_at IS NOT NULL FROM persona_questions WHERE persona_id=? ORDER BY id DESC LIMIT 1" (Only (personaId a)) :: IO [(T.Text,T.Text,Bool)]
  assert "AI proposal and final Player question both survive" (stored==[("AI proposed question","Player replacement",True)])
  mismatch <- try (J.commandJourney store domain ub (JourneyCommand 0 (userPersonaId ua) "question" Nothing Nothing)) :: IO (Either StoreError Value)
  assert "stale Persona selection cannot retarget a command" (case mismatch of Left (Conflict _) -> True; _ -> False)
  _ <- P.archivePersona store owner (personaId a)
  retained <- getGameView store domain ub
  assert "archive preserves sibling journey and Player" (gameUser retained==ub && gameJourney retained==gameJourney untouched)
  rows <- withStore store $ \c -> query_ c "SELECT COUNT(*) FROM game_events" :: IO [Only Int]
  assert "archive retains historical events" (rows==[Only 1])
  _ <- J.getJourney store domain ub
  -- Exercise the disposable development reset, not a legacy data migration.
  withStore store $ \c -> do
    _ <- execute_ c "ALTER TABLE journey_workflows ADD COLUMN user_id INTEGER"
    pure ()
  migrate store
  reset <- P.listPersonas store owner
  assert "obsolete development tables reset without creating legacy personas" (null reset)
  resetLogin <- login store credentials
  resetUser <- authenticate store (authToken resetLogin)
  assert "development reset retains account authentication and clears persona selection" (userId resetUser == userId owner && userPersonaId resetUser == Nothing)
  putStrLn "PostgreSQL persona acceptance passed"

assert :: String -> Bool -> IO ()
assert label ok = unless ok (fail label) >> putStrLn ("ok - " ++ label)

revision :: Value -> Int
revision (Object document) = case KM.lookup "workflow" document of
  Just value -> case fromJSON value of Success workflow -> workflowRevision workflow; _ -> error "Invalid workflow fixture"
  _ -> error "Missing workflow fixture"
revision _ = error "Missing journey fixture"

{-# LANGUAGE OverloadedStrings #-}
module Persistence.Analytics (migrateAnalytics, recordActivity, recordEvent, dashboard) where

import Data.Aeson (Value)
import qualified Data.ByteString.Char8 as B8
import Data.Text (Text)
import Database.PostgreSQL.Simple
import qualified Database.PostgreSQL.Simple.Newtypes as PG
import Database.PostgreSQL.Simple.Types (Query(..))

migrateAnalytics :: Connection -> IO ()
migrateAnalytics c = mapM_ (execute_ c)
  [ "CREATE TABLE IF NOT EXISTS analytics_start (singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK(singleton), started_at TIMESTAMPTZ NOT NULL DEFAULT now())"
  , "INSERT INTO analytics_start(singleton) VALUES(TRUE) ON CONFLICT DO NOTHING"
  , "CREATE TABLE IF NOT EXISTS player_activity (user_id INTEGER NOT NULL REFERENCES users(id), day DATE NOT NULL, PRIMARY KEY(user_id,day))"
  , "CREATE TABLE IF NOT EXISTS usage_events (id BIGSERIAL PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), kind TEXT NOT NULL CHECK(kind IN ('login','cast','move')), event_id INTEGER, occurred_at TIMESTAMPTZ NOT NULL DEFAULT now())"
  , "CREATE UNIQUE INDEX IF NOT EXISTS usage_event_once ON usage_events(kind,event_id) WHERE event_id IS NOT NULL"
  , "INSERT INTO usage_events(user_id,kind,event_id,occurred_at) SELECT s.user_id,'cast',e.id,e.created_at FROM game_events e JOIN game_sessions s ON s.id=e.game_session_id ON CONFLICT DO NOTHING"
  , "CREATE INDEX IF NOT EXISTS usage_event_time ON usage_events(occurred_at,kind)"
  , "CREATE INDEX IF NOT EXISTS usage_event_user ON usage_events(user_id,kind,occurred_at)"
  , "CREATE INDEX IF NOT EXISTS player_activity_day ON player_activity(day,user_id)"
  , "CREATE TABLE IF NOT EXISTS admin_account (singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK(singleton), password_hash BYTEA NOT NULL)"
  , "CREATE TABLE IF NOT EXISTS admin_sessions (token_hash TEXT PRIMARY KEY, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), last_seen TIMESTAMPTZ NOT NULL DEFAULT now())"
  , "CREATE TABLE IF NOT EXISTS admin_attempts (singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK(singleton), window_start TIMESTAMPTZ NOT NULL DEFAULT now(), attempts INTEGER NOT NULL DEFAULT 0)"
  , "INSERT INTO admin_attempts(singleton) VALUES(TRUE) ON CONFLICT DO NOTHING"
  ]

-- One participation record per player per UTC day, regardless of login count.
recordActivity :: Connection -> Int -> IO ()
recordActivity c uid = do
  _ <- execute c "INSERT INTO player_activity(user_id,day) VALUES (?,(now() AT TIME ZONE 'UTC')::date) ON CONFLICT DO NOTHING" (Only uid)
  pure ()

recordEvent :: Connection -> Int -> Text -> Maybe Int -> IO ()
recordEvent c uid kind eventId = do
  _ <- execute c "INSERT INTO usage_events(user_id,kind,event_id) VALUES (?,?,?) ON CONFLICT DO NOTHING" (uid,kind,eventId)
  pure ()

-- Static, allowlisted SQL fragments only; player-supplied values are parameters.
dashboard :: Connection -> Text -> Int -> IO Value
dashboard c period page = do
  let (unit, count, spanText) = case period of
        "weekly" -> ("week",12,"11 weeks")
        "monthly" -> ("month",12,"11 months")
        _ -> ("day",30,"29 days")
      sql = unlines
        [ "WITH bounds AS (SELECT date_trunc('"<>unit<>"',now() AT TIME ZONE 'UTC') - interval '"<>spanText<>"' AS start),"
        , "buckets AS (SELECT generate_series(start,date_trunc('"<>unit<>"',now() AT TIME ZONE 'UTC'),interval '1 "<>unit<>"') AS start FROM bounds),"
        , "people AS (SELECT u.id,u.username,u.created_at,"
        , "(SELECT count(*) FROM personas p WHERE p.player_id=u.id) AS personas,"
        , "(SELECT max(occurred_at) FROM usage_events e WHERE e.user_id=u.id AND kind='login') AS last_login,"
        , "(SELECT count(*) FROM usage_events e WHERE e.user_id=u.id AND kind='login') AS total_logins,"
        , "(SELECT count(*) FROM usage_events e WHERE e.user_id=u.id AND kind='login' AND (occurred_at AT TIME ZONE 'UTC')::date=(now() AT TIME ZONE 'UTC')::date) AS today_logins,"
        , "(SELECT count(*) FROM usage_events e WHERE e.user_id=u.id AND kind='login' AND (occurred_at AT TIME ZONE 'UTC')::date >= (now() AT TIME ZONE 'UTC')::date-6) AS week_logins,"
        , "(SELECT count(*) FROM usage_events e WHERE e.user_id=u.id AND kind='login' AND (occurred_at AT TIME ZONE 'UTC')::date >= (now() AT TIME ZONE 'UTC')::date-29) AS month_logins,"
        , "(SELECT count(*) FROM player_activity a WHERE a.user_id=u.id AND day >= (now() AT TIME ZONE 'UTC')::date-29) AS active_days_30"
        , "FROM users u ORDER BY u.id LIMIT 100 OFFSET ?),"
        , "trends AS (SELECT b.start::date AS period,"
        , "(SELECT count(*) FROM usage_events e WHERE kind='login' AND occurred_at AT TIME ZONE 'UTC' >= b.start AND occurred_at AT TIME ZONE 'UTC' < b.start+interval '1 "<>unit<>"') AS logins,"
        , "(SELECT count(DISTINCT user_id) FROM player_activity a WHERE a.day>=b.start::date AND a.day<(b.start+interval '1 "<>unit<>"')::date) AS active_players,"
        , "(SELECT count(*) FROM usage_events e WHERE kind='cast' AND occurred_at AT TIME ZONE 'UTC'>=b.start AND occurred_at AT TIME ZONE 'UTC'<b.start+interval '1 "<>unit<>"') AS casts,"
        , "(SELECT count(*) FROM usage_events e WHERE kind='move' AND occurred_at AT TIME ZONE 'UTC'>=b.start AND occurred_at AT TIME ZONE 'UTC'<b.start+interval '1 "<>unit<>"') AS moves FROM buckets b ORDER BY b.start)"
        , "SELECT jsonb_build_object('trackingSince',(SELECT started_at FROM analytics_start),'timezone','UTC','period',?::text,'bucketCount',?::int,'page',?::int,"
        , "'summary',jsonb_build_object('players',(SELECT count(*) FROM users),'personas',(SELECT count(*) FROM personas),'activePersonas',(SELECT count(*) FROM personas WHERE NOT archived),'archivedPersonas',(SELECT count(*) FROM personas WHERE archived),"
        , "'newPersonas',(SELECT count(DISTINCT persona_id) FROM persona_audit,bounds WHERE event_type='personas:INSERT' AND created_at AT TIME ZONE 'UTC'>=bounds.start),"
        , "'logins',(SELECT count(*) FROM usage_events WHERE kind='login'),'casts',(SELECT count(*) FROM usage_events WHERE kind='cast'),'moves',(SELECT count(*) FROM usage_events WHERE kind='move'),"
        , "'dailyActive',(SELECT count(DISTINCT user_id) FROM player_activity WHERE day=(now() AT TIME ZONE 'UTC')::date),'weeklyActive',(SELECT count(DISTINCT user_id) FROM player_activity WHERE day>=(now() AT TIME ZONE 'UTC')::date-6),'monthlyActive',(SELECT count(DISTINCT user_id) FROM player_activity WHERE day>=(now() AT TIME ZONE 'UTC')::date-29),"
        , "'newPlayers',(SELECT count(*) FROM users,bounds WHERE created_at AT TIME ZONE 'UTC'>=bounds.start),"
        , "'returningPlayers',(SELECT count(DISTINCT a.user_id) FROM player_activity a,bounds WHERE a.day>=bounds.start::date AND EXISTS(SELECT 1 FROM player_activity earlier WHERE earlier.user_id=a.user_id AND earlier.day<a.day))),"
        , "'players',COALESCE((SELECT jsonb_agg(to_jsonb(people) ORDER BY id) FROM people),'[]'::jsonb),'trends',COALESCE((SELECT jsonb_agg(to_jsonb(trends) ORDER BY period) FROM trends),'[]'::jsonb))"
        ]
  rows <- query c (Query (B8.pack sql)) (page*100,period,count::Int,page) :: IO [Only (PG.Aeson Value)]
  case rows of
    [Only (PG.Aeson value)] -> pure value
    _ -> fail "Dashboard query returned no result"

{-# LANGUAGE OverloadedStrings #-}
module Persistence.PersonaSchema (migratePersonas) where
import Database.PostgreSQL.Simple

migratePersonas :: Connection -> IO ()
migratePersonas connection = mapM_ (execute_ connection)
  [ "CREATE TABLE IF NOT EXISTS personas (id SERIAL PRIMARY KEY, player_id INTEGER NOT NULL REFERENCES users(id), document JSONB NOT NULL, archived BOOLEAN NOT NULL DEFAULT FALSE, UNIQUE(id, player_id))"
  , "ALTER TABLE questions ADD COLUMN IF NOT EXISTS ai_proposed_text TEXT"
  , "ALTER TABLE questions ADD COLUMN IF NOT EXISTS finalized_at TIMESTAMPTZ"
  , "ALTER TABLE game_sessions ADD COLUMN IF NOT EXISTS persona_id INTEGER REFERENCES personas(id)"
  , "ALTER TABLE auth_sessions ADD COLUMN IF NOT EXISTS persona_id INTEGER REFERENCES personas(id)"
  , "ALTER TABLE journey_workflows ADD COLUMN IF NOT EXISTS persona_id INTEGER REFERENCES personas(id)"
  , "CREATE TABLE IF NOT EXISTS persona_audit (id BIGSERIAL PRIMARY KEY, persona_id INTEGER NOT NULL REFERENCES personas(id), event_type TEXT NOT NULL, before_document JSONB, after_document JSONB, created_at TIMESTAMPTZ NOT NULL DEFAULT now())"
  , "CREATE TABLE IF NOT EXISTS persona_questions (id SERIAL PRIMARY KEY, persona_id INTEGER NOT NULL REFERENCES personas(id), journey_id INTEGER NOT NULL REFERENCES game_sessions(id), ai_proposed_text TEXT, player_final_text TEXT, contextual_basis JSONB NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), finalized_at TIMESTAMPTZ, event_id INTEGER REFERENCES game_events(id))"
  , "DO $$ DECLARE legacy RECORD; pid INTEGER; stamp TEXT; BEGIN FOR legacy IN SELECT * FROM game_sessions WHERE persona_id IS NULL LOOP stamp := now()::text; INSERT INTO personas(player_id, document) VALUES (legacy.user_id, '{}'::jsonb) RETURNING id INTO pid; UPDATE personas SET document = jsonb_build_object('personaId',pid,'personaPlayerId',legacy.user_id,'personaName','Legacy persona','personaDescription','Imported journey; no personal attributes assumed.','personaInitialDescription','Imported journey; no personal attributes assumed.','personaAvatar',NULL,'personaCreatedAt',stamp,'personaUpdatedAt',stamp,'personaInitialAttributes','[]'::jsonb,'personaEvolvingAttributes','[]'::jsonb,'personaThemes','[]'::jsonb,'personaInitialContext','','personaContext','','personaRevision',0,'personaArchived',FALSE) WHERE id=pid; UPDATE game_sessions SET persona_id=pid WHERE id=legacy.id; UPDATE journey_workflows SET persona_id=pid WHERE user_id=legacy.user_id AND persona_id IS NULL; UPDATE auth_sessions SET persona_id=pid WHERE user_id=legacy.user_id AND persona_id IS NULL; INSERT INTO persona_audit(persona_id,event_type,after_document) SELECT pid,'LegacyJourneyAdopted',to_jsonb(g) FROM game_sessions g WHERE id=legacy.id; END LOOP; END $$"
  , "ALTER TABLE game_sessions DROP CONSTRAINT IF EXISTS game_sessions_user_id_key"
  , "ALTER TABLE game_sessions ALTER COLUMN persona_id SET NOT NULL"
  , "CREATE UNIQUE INDEX IF NOT EXISTS game_sessions_persona_key ON game_sessions(persona_id)"
  , "ALTER TABLE journey_workflows DROP CONSTRAINT IF EXISTS journey_workflows_pkey"
  , "ALTER TABLE journey_workflows ALTER COLUMN user_id DROP NOT NULL"
  , "ALTER TABLE journey_workflows ALTER COLUMN persona_id SET NOT NULL"
  , "CREATE UNIQUE INDEX IF NOT EXISTS journey_workflows_persona_key ON journey_workflows(persona_id)"
  , "DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='game_session_persona_owner' AND conrelid='game_sessions'::regclass) THEN ALTER TABLE game_sessions ADD CONSTRAINT game_session_persona_owner FOREIGN KEY(persona_id,user_id) REFERENCES personas(id,player_id); ALTER TABLE auth_sessions ADD CONSTRAINT auth_session_persona_owner FOREIGN KEY(persona_id,user_id) REFERENCES personas(id,player_id); END IF; END $$"
  , "CREATE OR REPLACE FUNCTION audit_persona_change() RETURNS trigger LANGUAGE plpgsql AS $$ DECLARE before_row JSONB; after_row JSONB; row_data JSONB; pid INTEGER; BEGIN IF TG_OP <> 'INSERT' THEN before_row := to_jsonb(OLD); END IF; IF TG_OP <> 'DELETE' THEN after_row := to_jsonb(NEW); END IF; row_data := COALESCE(after_row,before_row); IF TG_TABLE_NAME='personas' THEN pid := (row_data->>'id')::integer; ELSIF TG_TABLE_NAME IN ('game_events','questions') THEN SELECT persona_id INTO pid FROM game_sessions WHERE id=(row_data->>'game_session_id')::integer; ELSE pid := (row_data->>'persona_id')::integer; END IF; IF pid IS NOT NULL THEN INSERT INTO persona_audit(persona_id,event_type,before_document,after_document) VALUES(pid,TG_TABLE_NAME || ':' || TG_OP,before_row,after_row); END IF; RETURN NULL; END $$"
  , "DO $$ DECLARE tab TEXT; BEGIN FOREACH tab IN ARRAY ARRAY['personas','game_sessions','game_events','questions','persona_questions','journey_workflows'] LOOP EXECUTE format('DROP TRIGGER IF EXISTS persona_history ON %I',tab); EXECUTE format('CREATE TRIGGER persona_history AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION audit_persona_change()',tab); END LOOP; END $$"
  ]

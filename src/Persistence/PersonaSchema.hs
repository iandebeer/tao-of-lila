{-# LANGUAGE OverloadedStrings #-}
module Persistence.PersonaSchema (migratePersonas) where
import Database.PostgreSQL.Simple

migratePersonas :: Connection -> IO ()
migratePersonas connection = mapM_ (execute_ connection)
  [ "CREATE TABLE IF NOT EXISTS persona_audit (id BIGSERIAL PRIMARY KEY, persona_id INTEGER NOT NULL REFERENCES personas(id), event_type TEXT NOT NULL, before_document JSONB, after_document JSONB, created_at TIMESTAMPTZ NOT NULL DEFAULT now())"
  , "CREATE TABLE IF NOT EXISTS persona_questions (id SERIAL PRIMARY KEY, persona_id INTEGER NOT NULL REFERENCES personas(id), journey_id INTEGER NOT NULL REFERENCES game_sessions(id), ai_proposed_text TEXT, player_final_text TEXT, contextual_basis JSONB NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), finalized_at TIMESTAMPTZ, event_id INTEGER REFERENCES game_events(id))"
  , "CREATE OR REPLACE FUNCTION audit_persona_change() RETURNS trigger LANGUAGE plpgsql AS $$ DECLARE before_row JSONB; after_row JSONB; row_data JSONB; pid INTEGER; BEGIN IF TG_OP <> 'INSERT' THEN before_row := to_jsonb(OLD); END IF; IF TG_OP <> 'DELETE' THEN after_row := to_jsonb(NEW); END IF; row_data := COALESCE(after_row,before_row); IF TG_TABLE_NAME='personas' THEN pid := (row_data->>'id')::integer; ELSIF TG_TABLE_NAME IN ('game_events','questions') THEN SELECT persona_id INTO pid FROM game_sessions WHERE id=(row_data->>'game_session_id')::integer; ELSE pid := (row_data->>'persona_id')::integer; END IF; IF pid IS NOT NULL THEN INSERT INTO persona_audit(persona_id,event_type,before_document,after_document) VALUES(pid,TG_TABLE_NAME || ':' || TG_OP,before_row,after_row); END IF; RETURN NULL; END $$"
  , "DO $$ DECLARE tab TEXT; BEGIN FOREACH tab IN ARRAY ARRAY['personas','game_sessions','game_events','questions','persona_questions','journey_workflows'] LOOP EXECUTE format('DROP TRIGGER IF EXISTS persona_history ON %I',tab); EXECUTE format('CREATE TRIGGER persona_history AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION audit_persona_change()',tab); END LOOP; END $$"
  ]

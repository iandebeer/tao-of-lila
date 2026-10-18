{-# LANGUAGE OverloadedStrings #-}
module Persistence.Reference
  ( migrateReferences, installReferenceLibrary, loadCastingReferences ) where

import Control.Exception (throwIO)
import Control.Monad (forM_, unless)
import Data.Text (Text)
import Database.PostgreSQL.Simple
import qualified Database.PostgreSQL.Simple.Newtypes as PG
import Domain.Contemplation (HexagramText, SourceTranslation)
import Domain.Reference
import Domain.Types (LeelaState (..))

migrateReferences :: Connection -> IO ()
migrateReferences connection = do
  _ <- execute_ connection "CREATE TABLE IF NOT EXISTS reference_documents (version TEXT NOT NULL, document_id TEXT NOT NULL, document JSONB NOT NULL, PRIMARY KEY(version,document_id))"
  _ <- execute_ connection "CREATE TABLE IF NOT EXISTS reference_hexagrams (version TEXT NOT NULL, binary_value INTEGER NOT NULL CHECK(binary_value BETWEEN 0 AND 63), document JSONB NOT NULL, PRIMARY KEY(version,binary_value))"
  _ <- execute_ connection "CREATE TABLE IF NOT EXISTS reference_leela (version TEXT NOT NULL, tile INTEGER NOT NULL CHECK(tile BETWEEN 1 AND 72), document JSONB NOT NULL, PRIMARY KEY(version,tile))"
  _ <- execute_ connection "CREATE TABLE IF NOT EXISTS reference_chapters (version TEXT NOT NULL, chapter INTEGER NOT NULL CHECK(chapter BETWEEN 1 AND 18), document JSONB NOT NULL, PRIMARY KEY(version,chapter))"
  _ <- execute_ connection "CREATE TABLE IF NOT EXISTS reference_active (singleton INTEGER PRIMARY KEY CHECK(singleton=1), version TEXT NOT NULL)"
  pure ()

-- A deployment installs its bundled, validated edition in a single transaction.
-- Content-derived versions retain older editions; no external retrieval occurs.
installReferenceLibrary :: Connection -> ReferenceLibrary -> IO ()
installReferenceLibrary connection library = do
  either (throwIO . userError) (const (pure ())) (validateReferenceLibrary library)
  withTransaction connection $ do
    let version = referenceVersion library
    forM_ (referenceDocuments library) $ \document -> do
      _ <- execute connection "INSERT INTO reference_documents(version,document_id,document) VALUES (?,?,?) ON CONFLICT DO NOTHING" (version, documentId document, PG.Aeson document)
      pure ()
    forM_ (referenceHexagrams library) $ \entry -> do
      _ <- execute connection "INSERT INTO reference_hexagrams(version,binary_value,document) VALUES (?,?,?) ON CONFLICT DO NOTHING" (version, referenceBinary entry, PG.Aeson (referenceText entry))
      pure ()
    forM_ (referenceLeela library) $ \entry -> do
      _ <- execute connection "INSERT INTO reference_leela(version,tile,document) VALUES (?,?,?) ON CONFLICT DO NOTHING" (version, stateId (referenceState entry), PG.Aeson entry)
      pure ()
    forM_ (referenceChapters library) $ \entry -> do
      _ <- execute connection "INSERT INTO reference_chapters(version,chapter,document) VALUES (?,?,?) ON CONFLICT DO NOTHING" (version, chapterNumber entry, PG.Aeson entry)
      pure ()
    _ <- execute connection "INSERT INTO reference_active(singleton,version) VALUES (1,?) ON CONFLICT(singleton) DO UPDATE SET version=EXCLUDED.version" (Only version)
    pure ()

loadCastingReferences :: Connection -> Int -> Int -> Int -> IO (Text, LeelaState, [(Int, HexagramText)], [SourceTranslation])
loadCastingReferences connection tile primary resulting = do
  versions <- query_ connection "SELECT version FROM reference_active WHERE singleton=1" :: IO [Only Text]
  version <- case versions of
    [Only value] -> pure value
    _ -> throwIO (userError "Reference library is not installed")
  hexes <- query connection "SELECT binary_value,document FROM reference_hexagrams WHERE version=? AND binary_value IN (?,?)" (version,primary,resulting) :: IO [(Int, PG.Aeson HexagramText)]
  unless (length hexes == if primary == resulting then 1 else 2) (throwIO (userError "Reference hexagram is missing"))
  states <- query connection "SELECT document FROM reference_leela WHERE version=? AND tile=?" (version,tile) :: IO [Only (PG.Aeson ReferenceLeela)]
  entry <- case states of
    [Only (PG.Aeson value)] -> pure value
    _ -> throwIO (userError "Reference tile is missing")
  chapters <- query connection "SELECT document FROM reference_chapters WHERE version=? AND chapter=?" (version,referenceChapter entry) :: IO [Only (PG.Aeson ReferenceChapter)]
  background <- case chapters of
    [Only (PG.Aeson value)] -> pure [chapterSource value]
    _ -> throwIO (userError "Reference background chapter is missing")
  let state = referenceState entry
  pure (version, state {stateDescription = stateDescription state <> "\n\n" <> referenceCommentary entry}, [(key,value) | (key,PG.Aeson value) <- hexes], background)

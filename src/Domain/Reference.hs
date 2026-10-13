{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
module Domain.Reference
  ( ReferenceDocument (..), ReferenceHexagram (..), ReferenceLeela (..)
  , ReferenceChapter (..), ReferenceLibrary (..), loadReferenceLibrary
  , validateReferenceLibrary, lookupReferenceHexagram, referenceBackground, withReferenceBackground
  ) where

import Crypto.Hash (Digest, SHA256, hash)
import Data.Aeson (FromJSON, ToJSON, eitherDecodeFileStrict')
import Data.List (find, sort, nub)
import Data.Bits (testBit)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Domain.Contemplation
import Domain.HexagramIndex (binaryToKingWen)
import Domain.Types (LeelaState (..))
import GHC.Generics (Generic)

data ReferenceDocument = ReferenceDocument
  { documentId :: Text, documentTitle :: Text, documentAuthor :: Text
  , documentYear :: Int, documentSource :: Text, documentRights :: Text
  , documentDigest :: Text, documentBody :: Text
  } deriving (Eq, Show, Generic)
instance FromJSON ReferenceDocument
instance ToJSON ReferenceDocument

data ReferenceHexagram = ReferenceHexagram
  { referenceBinary :: Int, referenceText :: HexagramText } deriving (Eq, Show, Generic)
instance FromJSON ReferenceHexagram
instance ToJSON ReferenceHexagram

data ReferenceLeela = ReferenceLeela
  { referenceState :: LeelaState, referenceCommentary :: Text, referenceCommentarySource :: Text, referenceChapter :: Int
  } deriving (Eq, Show, Generic)
instance FromJSON ReferenceLeela
instance ToJSON ReferenceLeela

data ReferenceChapter = ReferenceChapter
  { chapterNumber :: Int, chapterSource :: SourceTranslation, chapterBody :: Text
  } deriving (Eq, Show, Generic)
instance FromJSON ReferenceChapter
instance ToJSON ReferenceChapter

data ReferenceLibrary = ReferenceLibrary
  { referenceVersion :: Text, referenceDocuments :: [ReferenceDocument]
  , referenceHexagrams :: [ReferenceHexagram], referenceLeela :: [ReferenceLeela]
  , referenceChapters :: [ReferenceChapter]
  } deriving (Eq, Show, Generic)
instance FromJSON ReferenceLibrary
instance ToJSON ReferenceLibrary

loadReferenceLibrary :: FilePath -> IO (Either String ReferenceLibrary)
loadReferenceLibrary path = do
  decoded <- eitherDecodeFileStrict' path
  pure (decoded >>= validateReferenceLibrary)

validateReferenceLibrary :: ReferenceLibrary -> Either String ReferenceLibrary
validateReferenceLibrary library
  | T.null (referenceVersion library) = Left "Reference corpus needs a version"
  | sort (map referenceBinary hexes) /= [0..63] = Left "Reference corpus requires every binary hexagram exactly once"
  | not (all validHex hexes) = Left "Reference hexagram has a mismatched key, missing bilingual passage or attribution"
  | sort (map (stateId . referenceState) states) /= [1..72] = Left "Reference corpus requires all 72 Lila tiles"
  | not (all validState states) = Left "Reference tile is missing its description, commentary or background link"
  | sort (map chapterNumber chapters) /= [1..18] = Left "Reference corpus requires all 18 Gita chapters"
  | not (all (\c -> validSource (chapterSource c) && not (T.null (chapterBody c))) chapters) = Left "Reference chapter is empty or unattributed"
  | null docs || length (nub (map documentId docs)) /= length docs || not (all validDocument docs) = Left "Reference document has invalid provenance or digest"
  | otherwise = Right library
  where
    hexes = referenceHexagrams library; states = referenceLeela library
    chapters = referenceChapters library; docs = referenceDocuments library
    nonempty = not . T.null . T.strip
    validSource s = translationCopyrightStatus s == "public_domain"
      && all nonempty [translationText s, translationTitle s, translationTranslator s, translationSourceReference s]
    validHex entry = let h = referenceText entry in
      binaryToKingWen (referenceBinary entry) == Just (textHexagramNumber h)
      && all nonempty [textChineseName h, textJudgmentChinese h, textImageChinese h]
      && length (textLineChinese h) == 6 && all nonempty (textLineChinese h)
      && and [T.isInfixOf (if testBit (referenceBinary entry) bit then "九" else "六") (T.takeWhile (/= '：') line) | (bit,line) <- zip [0..5] (textLineChinese h)]
      && (case (textAdditionalChinese h,textAdditionalLegge h) of
            (Just chinese, Just translation) -> textHexagramNumber h `elem` [1,2] && nonempty chinese && validSource translation
            (Nothing, Nothing) -> textHexagramNumber h `notElem` [1,2]
            _ -> False)
      && length (textLeggeLines h) == 6 && all validSource (textLeggeLines h)
      && validSource (textLeggeJudgment h) && maybe False validSource (textLeggeImage h)
    validState s = all nonempty [stateName (referenceState s), stateDescription (referenceState s), referenceCommentary s]
      && referenceChapter s >= 1 && referenceChapter s <= 18
    validDocument d = documentRights d == "public_domain"
      && all nonempty [documentId d, documentTitle d, documentSource d, documentBody d]
      && documentDigest d == T.pack (show (hash (TE.encodeUtf8 (documentBody d)) :: Digest SHA256))

lookupReferenceHexagram :: ReferenceLibrary -> Int -> Maybe HexagramText
lookupReferenceHexagram library binary = referenceText <$> find ((== binary) . referenceBinary) (referenceHexagrams library)

referenceBackground :: ReferenceLibrary -> Int -> [SourceTranslation]
referenceBackground library number = do
  tile <- filter ((== number) . stateId . referenceState) (referenceLeela library)
  chapter <- filter ((== referenceChapter tile) . chapterNumber) (referenceChapters library)
  pure (chapterSource chapter)

withReferenceBackground :: ReferenceLibrary -> ContemplationContext -> ContemplationContext
withReferenceBackground library context = context
  { contemplationBackgroundSources = Just (referenceBackground library (stateId (contemplationLeelaState context)))
  , contemplationCorpusVersion = Just (referenceVersion library)
  }

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- Stable, read-only information for the viewer and future prompt composition.
-- These relationships never change a live game's movement rules.
module Domain.StateView
  ( VisualIdentity (..), TransitionKind (..), StateTransition (..), TraditionalState (..)
  , LeelaStateView (..), TrigramView (..), HexagramView (..), StateCatalog (..)
  , loadStateCatalog, validateStateCatalog, lookupStateView, lookupTrigramView
  , lookupHexagramView, transitionDestination
  ) where

import Data.Aeson (FromJSON (..), ToJSON (..), Value (String), withText, eitherDecodeFileStrict')
import Data.List (find, sort)
import Data.Text (Text)
import qualified Data.Text as T
import Domain.Types (LeelaState (..))
import Domain.HexagramIndex (binaryToKingWen)
import GHC.Generics (Generic)

-- Hue is an editorial colour, not a moral rank or a probability weight.
data VisualIdentity = VisualIdentity
  { hue :: Maybe Text, imageAsset :: Maybe Text, symbol :: Maybe Text, element :: Maybe Text }
  deriving (Eq, Show, Generic)
instance FromJSON VisualIdentity
instance ToJSON VisualIdentity

data TransitionKind = Snake | Ladder deriving (Eq, Show)
instance FromJSON TransitionKind where
  parseJSON = withText "TransitionKind" $ \kind -> case kind of
    "snake" -> pure Snake
    "ladder" -> pure Ladder
    _ -> fail "Expected snake or ladder"
instance ToJSON TransitionKind where
  toJSON Snake = String "snake"
  toJSON Ladder = String "ladder"

data StateTransition = StateTransition
  { transitionType :: TransitionKind, destination :: Int, transitionInterpretation :: Text }
  deriving (Eq, Show, Generic)
instance FromJSON StateTransition
instance ToJSON StateTransition

data TraditionalState = TraditionalState
  { sanskritName :: Text, englishName :: Text, coreMeaning :: Text
  , traditionalInterpretation :: Text, transition :: Maybe StateTransition }
  deriving (Eq, Show, Generic)
instance FromJSON TraditionalState
instance ToJSON TraditionalState

data LeelaStateView = LeelaStateView
  { identity :: LeelaState, canonicalInterpretation :: Maybe Text
  , visualIdentity :: VisualIdentity, traditionalReference :: Maybe TraditionalState }
  deriving (Eq, Show, Generic)
instance FromJSON LeelaStateView
instance ToJSON LeelaStateView

data TrigramView = TrigramView
  { trigramBinary :: Int, trigramChinese :: Text, trigramPinyin :: Text
  , naturalImage :: Text, linesBottomToTop :: [Int], family :: Text, animal :: Text
  , trigramVisual :: VisualIdentity, animalImageAsset :: Maybe Text
  , earlierHeavenDirection :: Text, laterHeavenDirection :: Text }
  deriving (Eq, Show, Generic)
instance FromJSON TrigramView
instance ToJSON TrigramView

data HexagramView = HexagramView
  { binaryValue :: Int, kingWenNumber :: Int, translatedName :: Text
  , chineseName :: Maybe Text, glyph :: Text, upperBinary :: Int, lowerBinary :: Int
  , traditionalSummary :: Maybe Text }
  deriving (Eq, Show, Generic)
instance FromJSON HexagramView
instance ToJSON HexagramView

data StateCatalog = StateCatalog
  { catalogVersion :: Text, catalogNote :: Text, sources :: [Text]
  , stateViews :: [LeelaStateView], trigramViews :: [TrigramView], hexagramViews :: [HexagramView] }
  deriving (Eq, Show, Generic)
instance FromJSON StateCatalog
instance ToJSON StateCatalog

loadStateCatalog :: FilePath -> IO (Either String StateCatalog)
loadStateCatalog file = do
  decoded <- eitherDecodeFileStrict' file
  pure (decoded >>= validateStateCatalog)

lookupStateView :: StateCatalog -> Int -> Maybe LeelaStateView
lookupStateView catalog number = find ((== number) . stateId . identity) (stateViews catalog)
lookupTrigramView :: StateCatalog -> Int -> Maybe TrigramView
lookupTrigramView catalog binary = find ((== binary) . trigramBinary) (trigramViews catalog)
lookupHexagramView :: StateCatalog -> Int -> Maybe HexagramView
lookupHexagramView catalog binary = find ((== binary) . binaryValue) (hexagramViews catalog)

-- The destination's identity comes from the same reference edition as its origin.
transitionDestination :: StateCatalog -> LeelaStateView -> Maybe TraditionalState
transitionDestination catalog origin = do
  reference <- traditionalReference origin
  relation <- transition reference
  target <- lookupStateView catalog (destination relation)
  traditionalReference target

validateStateCatalog :: StateCatalog -> Either String StateCatalog
validateStateCatalog catalog
  | sort (map (stateId . identity) states) /= [1..72] = Left "State viewer requires exactly tiles 1..72"
  | sort (map trigramBinary trigrams) /= [0..7] = Left "State viewer requires exactly trigrams 0..7"
  | sort (map binaryValue hexes) /= [0..63] = Left "State viewer requires exactly hexagrams 0..63"
  | not (all validHex hexes) = Left "Invalid hexagram structure or King Wen lookup"
  | not (all validTrigram trigrams) = Left "Invalid bottom-to-top trigram lines"
  | not (all validTransition states) = Left "Invalid reference transition"
  | not (all validVisual (map visualIdentity states ++ map trigramVisual trigrams)) = Left "Invalid visual asset or hue"
  | not (all (validAsset . animalImageAsset) trigrams) = Left "Invalid animal asset"
  | otherwise = Right catalog
  where
    states = stateViews catalog
    trigrams = trigramViews catalog
    hexes = hexagramViews catalog
    validHex h = binaryToKingWen (binaryValue h) == Just (kingWenNumber h)
      && lowerBinary h == binaryValue h `mod` 8 && upperBinary h == binaryValue h `div` 8
    validTrigram t = linesBottomToTop t == [trigramBinary t `div` (2^bit) `mod` 2 | bit <- [0..2 :: Int]]
    validTransition s = case traditionalReference s >>= transition of
      Nothing -> True
      Just relation -> destination relation >= 1 && destination relation <= 72
        && not (T.null (transitionInterpretation relation))
        && transitionDestination catalog s /= Nothing
        && case transitionType relation of
          Snake -> destination relation < stateId (identity s)
          Ladder -> destination relation > stateId (identity s)
    validVisual v = maybe True (\c -> T.length c == 7 && T.head c == '#' && T.all (`elem` ("0123456789abcdefABCDEF" :: String)) (T.tail c)) (hue v)
      && validAsset (imageAsset v)
    validAsset = maybe True (\p -> "/assets/" `T.isPrefixOf` p && not (".." `T.isInfixOf` p))

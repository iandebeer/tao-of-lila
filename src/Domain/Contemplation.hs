{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.Contemplation
  ( ChangingLineContext (..)
  , ContemplationContext (..)
  , ContemplationResponse (..)
  , ContemplationView (..)
  , CostSummary (..)
  , HexagramText (..)
  , LexicalNote (..)
  , ModelResult (..)
  , SourceTranslation (..)
  , buildContemplationContext
  , buildPairContemplationContext
  , lookupHexagramText
  )
where

import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.=))
import Data.Bits (testBit, xor)
import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as T
import Domain.HexagramIndex (kingWenToBinary)
import Domain.Types (LeelaState)
import Engine.Casting (CastingResult (..))
import GHC.Generics (Generic)

data LexicalNote = LexicalNote
  { lexicalExpression :: Text
  , lexicalPinyin :: Text
  , lexicalPossibilities :: [Text]
  }
  deriving (Eq, Show, Generic)

instance FromJSON LexicalNote
instance ToJSON LexicalNote

data SourceTranslation = SourceTranslation
  { translationTranslator :: Text
  , translationTitle :: Text
  , translationYear :: Int
  , translationCopyrightStatus :: Text
  , translationSourceReference :: Text
  , translationText :: Text
  }
  deriving (Eq, Show, Generic)

instance FromJSON SourceTranslation
instance ToJSON SourceTranslation

data HexagramText = HexagramText
  { textHexagramNumber :: Int
  , textChineseName :: Text
  , textPinyin :: Text
  , textUnicodeSymbol :: Text
  , textLowerTrigram :: Text
  , textUpperTrigram :: Text
  , textJudgmentChinese :: Text
  , textImageChinese :: Text
  , textLineChinese :: [Text]
  , textLexicalNotes :: [LexicalNote]
  , textWorkingTranslation :: Text
  , textLineWorkingTranslations :: [Text]
  , textLeggeJudgment :: SourceTranslation
  , textLeggeLines :: [SourceTranslation]
  }
  deriving (Eq, Show, Generic)

instance FromJSON HexagramText
instance ToJSON HexagramText

data ChangingLineContext = ChangingLineContext
  { changingLineNumber :: Int
  , changingLineValue :: Int
  , changingLineChinese :: Text
  , changingLineLexicalNotes :: [LexicalNote]
  , changingLineWorkingTranslation :: Text
  , changingLineLegge :: SourceTranslation
  }
  deriving (Eq, Show, Generic)

instance FromJSON ChangingLineContext
instance ToJSON ChangingLineContext

data ContemplationContext = ContemplationContext
  { contemplationLeelaState :: LeelaState
  , contemplationQuestion :: Text
  , contemplationPrimaryHexagram :: HexagramText
  , contemplationChangingLines :: [ChangingLineContext]
  , contemplationResultingHexagram :: HexagramText
  }
  deriving (Eq, Show, Generic)

instance FromJSON ContemplationContext
instance ToJSON ContemplationContext

data ContemplationResponse = ContemplationResponse
  { contemplationResponseContext :: Text
  , contemplationPrimaryReflection :: Text
  , contemplationLineReflections :: [Text]
  , contemplationTransformation :: Text
  , contemplationPossibleReadings :: [Text]
  , contemplationQuestions :: [Text]
  }
  deriving (Eq, Show, Generic)

instance FromJSON ContemplationResponse where
  parseJSON = withObject "ContemplationResponse" $ \value ->
    ContemplationResponse
      <$> value .: "context"
      <*> value .: "primary_hexagram"
      <*> value .: "changing_lines"
      <*> value .: "transformation"
      <*> value .: "possible_readings"
      <*> value .: "questions_for_contemplation"

instance ToJSON ContemplationResponse where
  toJSON response = object
    [ "context" .= contemplationResponseContext response
    , "primary_hexagram" .= contemplationPrimaryReflection response
    , "changing_lines" .= contemplationLineReflections response
    , "transformation" .= contemplationTransformation response
    , "possible_readings" .= contemplationPossibleReadings response
    , "questions_for_contemplation" .= contemplationQuestions response
    ]

data ModelResult = ModelResult
  { modelContemplation :: ContemplationResponse
  , modelProvider :: Text
  , modelName :: Text
  , modelInputTokens :: Int
  , modelOutputTokens :: Int
  , modelCachedInputTokens :: Int
  , modelLatencyMilliseconds :: Int
  , modelEstimatedCostMicros :: Int
  }
  deriving (Eq, Show, Generic)

instance FromJSON ModelResult
instance ToJSON ModelResult

data ContemplationView = ContemplationView
  { contemplationEventId :: Int
  , contemplationViewContext :: ContemplationContext
  , contemplationViewResponse :: ContemplationResponse
  }
  deriving (Eq, Show, Generic)

instance FromJSON ContemplationView
instance ToJSON ContemplationView

data CostSummary = CostSummary
  { summaryContemplations :: Int
  , summaryAverageCostMicros :: Int
  , summaryTotalCostMicros :: Int
  , summaryAverageTokens :: Int
  }
  deriving (Eq, Show, Generic)

instance FromJSON CostSummary
instance ToJSON CostSummary

buildContemplationContext :: LeelaState -> Text -> CastingResult -> Either Text ContemplationContext
buildContemplationContext leela question casting = do
  primaryNumber <- maybe (Left "The primary King Wen number is unavailable") Right (primaryKingWenNumber casting)
  resultingNumber <- maybe (Left "The resulting King Wen number is unavailable") Right (transformedKingWenNumber casting)
  primary <- maybe (Left "Canonical text for the primary hexagram is not seeded") Right (lookupHexagramText primaryNumber)
  resulting <- maybe (Left "Canonical text for the resulting hexagram is not seeded") Right (lookupHexagramText resultingNumber)
  activeLines <- traverse (lineContext primary (primaryBinaryValue casting)) (changingLines casting)
  pure (ContemplationContext leela question primary activeLines resulting)

-- Supply the observed pair directly, without simulating a casting or movement.
buildPairContemplationContext :: LeelaState -> Text -> Int -> Int -> Either Text ContemplationContext
buildPairContemplationContext leela question primaryNumber resultingNumber = do
  primaryBinary <- resolveNumber "Primary" primaryNumber
  resultingBinary <- resolveNumber "Resulting" resultingNumber
  primary <- resolveText primaryNumber
  resulting <- resolveText resultingNumber
  let changed = [line | line <- [1 .. 6], testBit (primaryBinary `xor` resultingBinary) (line - 1)]
  activeLines <- traverse (lineContext primary primaryBinary) changed
  pure (ContemplationContext leela question primary activeLines resulting)
  where
    resolveNumber label number = maybe
      (Left (label <> " King Wen number must be between 1 and 64")) Right
      (kingWenToBinary number)
    resolveText number = maybe
      (Left ("Canonical text for Hexagram " <> T.pack (show number)
        <> " is not seeded. The current interpretation corpus contains 11 and 36.")) Right
      (lookupHexagramText number)

lineContext :: HexagramText -> Int -> Int -> Either Text ChangingLineContext
lineContext hexagram binary line = do
  chinese <- atLine (textLineChinese hexagram) line
  working <- atLine (textLineWorkingTranslations hexagram) line
  leggeLine <- atLine (textLeggeLines hexagram) line
  pure
    ChangingLineContext
      { changingLineNumber = line
      , changingLineValue = if testBit binary (line - 1) then 9 else 6
      , changingLineChinese = chinese
      , changingLineLexicalNotes = textLexicalNotes hexagram
      , changingLineWorkingTranslation = working
      , changingLineLegge = leggeLine
      }

atLine :: [a] -> Int -> Either Text a
atLine values number =
  case drop (number - 1) values of
    value : _ -> Right value
    [] -> Left "Canonical changing-line text is unavailable"

lookupHexagramText :: Int -> Maybe HexagramText
lookupHexagramText number = find ((== number) . textHexagramNumber) initialCorpus

initialCorpus :: [HexagramText]
initialCorpus = [hexagram11, hexagram36]

legge :: Text -> SourceTranslation
legge passage = SourceTranslation "James Legge" "The Yî King" 1882 "public_domain" "Sacred Books of the East, volume 16" passage

emptyLegge :: SourceTranslation
emptyLegge = legge "Not included in the initial reference slice."

hexagram11 :: HexagramText
hexagram11 =
  HexagramText 11 "泰" "Tài" "䷊" "乾 Qián — Heaven" "坤 Kūn — Earth"
    "小往大來，吉亨。"
    "天地交，泰；后以財成天地之道，輔相天地之宜，以左右民。"
    [ "初九：拔茅茹，以其彙，征吉。"
    , "九二：包荒，用馮河，不遐遺，朋亡，得尚于中行。"
    , "九三：無平不陂，無往不復，艱貞無咎。勿恤其孚，于食有福。"
    , "六四：翩翩，不富以其鄰，不戒以孚。"
    , "六五：帝乙歸妹，以祉元吉。"
    , "上六：城復于隍，勿用師。自邑告命，貞吝。"
    ]
    [ LexicalNote "泰" "tài" ["great", "expansive", "peaceful", "at ease", "flourishing", "harmonious"]
    , LexicalNote "包荒" "bāo huāng" ["embrace the wild", "contain the uncultivated", "encompass what has been neglected"]
    , LexicalNote "馮河" "píng hé" ["cross the river on foot", "venture across without a boat"]
    , LexicalNote "中行" "zhōng xíng" ["the central course", "conduct in the middle", "walking the middle path"]
    ]
    "The small goes; the great comes. Auspicious—opening through."
    [ "Pulling up grass-roots, entangled with their kind. Setting forth: auspicious."
    , "Embracing the uncultivated; crossing the river without a boat; not abandoning what is distant; letting companions fall away; finding esteem in the central course."
    , "No level ground without a slope; no going without return. In difficulty, constancy is without fault. Do not grieve over what is trustworthy; in nourishment there is blessing."
    , "Fluttering, not relying on wealth, together with the neighbours; without warning, through trust."
    , "Emperor Yi gives his younger sister in marriage. Through blessing: fundamentally auspicious."
    , "The wall returns to the moat. Do not use the army. From the city, declare the mandate. Constancy brings constraint."
    ]
    (legge "The little gone and the great come. Good fortune, with progress and success.")
    [ emptyLegge
    , legge "One who can bear with the uncultivated, cross the Ho without a boat, not forget the distant, and have no selfish friendships—thus acting in accordance with the due Mean."
    , emptyLegge, emptyLegge, emptyLegge, emptyLegge
    ]

hexagram36 :: HexagramText
hexagram36 =
  HexagramText 36 "明夷" "Míng Yí" "䷣" "離 Lí — Fire" "坤 Kūn — Earth"
    "明夷，利艱貞。"
    "明入地中，明夷；君子以莅眾，用晦而明。"
    [ "初九：明夷于飛，垂其翼。君子于行，三日不食。有攸往，主人有言。"
    , "六二：明夷，夷于左股，用拯馬壯，吉。"
    , "九三：明夷于南狩，得其大首，不可疾貞。"
    , "六四：入于左腹，獲明夷之心，于出門庭。"
    , "六五：箕子之明夷，利貞。"
    , "上六：不明晦，初登于天，後入于地。"
    ]
    [ LexicalNote "明" "míng" ["bright", "luminous", "clear", "illumination", "understanding"]
    , LexicalNote "夷" "yí" ["injure", "level", "bring low", "concealment under adversity"]
    , LexicalNote "艱貞" "jiān zhēn" ["constancy in difficulty", "steadfastness amid hardship"]
    ]
    "Brightness wounded; illumination brought low. Constancy amid difficulty is fruitful."
    [ "Brightness wounded in flight, lowering its wings. The cultivated person travels, three days without eating. There is somewhere to go; the host has words."
    , "Brightness wounded in the left thigh. Rescue with the strength of a horse: auspicious."
    , "Brightness wounded in the southern hunt; its great leader is taken. Constancy cannot be hurried."
    , "Entering the left side of the belly, obtaining the heart of brightness wounded, then leaving gate and courtyard."
    , "The brightness wounded of Jizi. Constancy is fruitful."
    , "Not light but darkness: first ascending to heaven, afterward entering the earth."
    ]
    (legge "It will be advantageous to realise the difficulty of the position, and maintain firm correctness.")
    [emptyLegge, emptyLegge, emptyLegge, emptyLegge, emptyLegge, emptyLegge]

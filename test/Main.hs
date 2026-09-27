{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  )
where

import Data.Aeson (Value (..), toJSON, fromJSON, Result (..))
import qualified Data.Aeson.KeyMap as KM
import Data.Bits (testBit, xor)
import Engine.Movement (movementFromChangingLines)
import Domain.Types
  ( DomainData (..)
  , Hexagram (..)
  , LeelaState (..)
  , MovingLine (..)
  , Reading (..)
  , ReadingRequest (..)
  )
import Domain.HexagramIndex (binaryToKingWen)
import Domain.Contemplation
import qualified Engine.Casting as Casting
import Engine.Reading (generateReading)
import Engine.Game (accessibleStateIds, applyCastingMovement)

main :: IO ()
main = do
  let weights = [sum [3 ^ (6 - length positions) | mask <- [0..63 :: Int], let positions = [i+1 | i <- [0..5], testBit mask i], movementFromChangingLines positions == move] | move <- [0..6]] :: [Int]
  assert "exact independent yarrow movement probabilities" (weights == 1054 : replicate 6 507)
  let final = until ((/=Nothing) . Casting.result) Casting.nextCastingState Casting.initialCastingState
  case Casting.result final of
    Nothing -> fail "Missing casting result"
    Just casting -> do
      let positions = [Casting.lineNumber line | line <- Casting.completedLines final, Casting.lineValue line `elem` [6,9]]
          primary = sum [2 ^ (Casting.lineNumber line-1) | line <- Casting.completedLines final, Casting.lineValue line `elem` [7,9]]
          mask = sum [2 ^ (position-1) | position <- positions]
      assert "casting facts remain separate from movement" (Casting.numberChanging casting == length positions && Casting.changingLines casting == positions && Casting.lilaMoveSquares casting == movementFromChangingLines positions)
      assert "hexagrams still reflect the authentic line values" (Casting.primaryBinaryValue casting == primary && Casting.transformedBinaryValue casting == (primary `xor` mask))
      let legacy = case fromJSON (encodeResult casting) :: Result Casting.CastingResult of
            Success old -> Casting.movementRule old == "changing-line-count-v1" && Casting.lilaMoveSquares old == Casting.numberChanging casting
            Error _ -> False
      assert "legacy casting keeps its recorded count-based movement" legacy
  mapM_ (\(positions, expected) -> assert ("position movement " <> show positions) (movementFromChangingLines positions == expected))
    [([],0),([1],1),([4],4),([6],6),([1,4],5),([2,5],0),([2,4,6],5),([1..6],0)]
  assert "explicit state is honored" explicitStateIsHonored
  assert "generated readings are deterministic" generatedReadingsAreDeterministic
  assert "empty explicit moving lines are rejected" emptyMovingLinesRejected
  assert "binary values map to King Wen numbers" binaryValuesMapToKingWenNumbers
  assert "invalid binary values are rejected" invalidBinaryValuesRejected
  assert "casting begins with one stalk set aside" castingBeginsWithOneStalkSetAside
  assert "casting removes the ritual stalk from the right heap" castingRemovesRitualStalkFromRightHeap
  assert "casting completes six yarrow lines" castingCompletesSixYarrowLines
  assert "game exposes the next six reachable states" gameExposesSixReachableStates
  assert "casting result advances and bounds the Lila state" castingAdvancesLilaState
  assert "Innocence 11 changing line 2 becomes 36 contemplation context" contemplationContextMatchesFirstCase

assert :: String -> Bool -> IO ()
assert label condition =
  if condition
    then putStrLn ("ok - " <> label)
    else fail ("failed - " <> label)

explicitStateIsHonored :: Bool
explicitStateIsHonored =
  case generateReading sampleDomain request of
    Right reading -> stateId (readingState reading) == 2
    Left _ -> False
  where
    request =
      ReadingRequest
        { question = "What is asking for attention?"
        , leelaStateId = Just 2
        , hexagramNumberInput = Just 1
        , movingLinesInput = Just [Foundation, Vision]
        }

generatedReadingsAreDeterministic :: Bool
generatedReadingsAreDeterministic =
  generateReading sampleDomain request == generateReading sampleDomain request
  where
    request =
      ReadingRequest
        { question = "How should I meet this transition?"
        , leelaStateId = Nothing
        , hexagramNumberInput = Nothing
        , movingLinesInput = Nothing
        }

emptyMovingLinesRejected :: Bool
emptyMovingLinesRejected =
  case generateReading sampleDomain request of
    Left _ -> True
    Right _ -> False
  where
    request =
      ReadingRequest
        { question = "Can an empty line set pass?"
        , leelaStateId = Nothing
        , hexagramNumberInput = Nothing
        , movingLinesInput = Just []
        }

binaryValuesMapToKingWenNumbers :: Bool
binaryValuesMapToKingWenNumbers =
  all mappingMatches kingWenMappings
  where
    mappingMatches (binaryValue, kingWenNumber) =
      binaryToKingWen binaryValue == Just kingWenNumber

invalidBinaryValuesRejected :: Bool
invalidBinaryValuesRejected =
  binaryToKingWen (-1) == Nothing
    && binaryToKingWen 64 == Nothing

castingBeginsWithOneStalkSetAside :: Bool
castingBeginsWithOneStalkSetAside =
  let state = Casting.nextCastingState Casting.initialCastingState
   in Casting.event state == "LineStarted"
        && Casting.setAside state == 1
        && Casting.workingStalks state == 49
        && Casting.currentLine state == 1
        && Casting.currentRound state == 1

castingRemovesRitualStalkFromRightHeap :: Bool
castingRemovesRitualStalkFromRightHeap =
  case Casting.roundSnapshot state of
    Just snapshot ->
      Casting.removedSide snapshot == Just "RIGHT"
        && Casting.rightAfterSingle snapshot == (subtract 1 <$> Casting.rightHeap snapshot)
        && Casting.leftAfterSingle snapshot == Casting.leftHeap snapshot
    Nothing -> False
  where
    state = iterate Casting.nextCastingState Casting.initialCastingState !! 3

castingCompletesSixYarrowLines :: Bool
castingCompletesSixYarrowLines =
  Casting.event finalState == "CastingComplete"
    && length (Casting.completedLines finalState) == 6
    && all validLineValue (Casting.completedLines finalState)
    && Casting.result finalState /= Nothing
  where
    finalState = iterate Casting.nextCastingState Casting.initialCastingState !! 96
    validLineValue line = Casting.lineValue line `elem` [6, 7, 8, 9]

gameExposesSixReachableStates :: Bool
gameExposesSixReachableStates =
  accessibleStateIds 1 == [2 .. 7]
    && accessibleStateIds 69 == [70, 71, 72]
    && accessibleStateIds 72 == []

castingAdvancesLilaState :: Bool
castingAdvancesLilaState =
  case Casting.result completedCasting of
    Just castingResult ->
      applyCastingMovement 10 castingResult
        == min 72 (10 + Casting.lilaMoveSquares castingResult)
        && applyCastingMovement 71 castingResult <= 72
    Nothing -> False
  where
    completedCasting = iterate Casting.nextCastingState Casting.initialCastingState !! 96

contemplationContextMatchesFirstCase :: Bool
contemplationContextMatchesFirstCase =
  case buildContemplationContext innocence questionText casting of
    Right context ->
      textChineseName (contemplationPrimaryHexagram context) == "泰"
        && textChineseName (contemplationResultingHexagram context) == "明夷"
        && case contemplationChangingLines context of
          [activeLine] ->
            changingLineNumber activeLine == 2
              && changingLineValue activeLine == 9
              && changingLineChinese activeLine == "九二：包荒，用馮河，不遐遺，朋亡，得尚于中行。"
          _ -> False
    Left _ -> False
  where
    innocence = LeelaState 1 "Innocence" "Direct experience before self-protection." "Beginner's mind"
    questionText = "How can I retain my innocence in moving forward in this world?"
    heaven = Casting.TrigramResult "Heaven" "☰" 7
    earth = Casting.TrigramResult "Earth" "☷" 0
    fire = Casting.TrigramResult "Fire" "☲" 5
    casting = Casting.CastingResult
      { Casting.primaryBinaryValue = 7
      , Casting.transformedBinaryValue = 5
      , Casting.primaryKingWenNumber = Just 11
      , Casting.transformedKingWenNumber = Just 36
      , Casting.changingLines = [2]
      , Casting.numberChanging = 1
      , Casting.upperTrigramResult = earth
      , Casting.lowerTrigramResult = heaven
      , Casting.nuclearUpperTrigramResult = earth
      , Casting.nuclearLowerTrigramResult = fire
      , Casting.movementRule = "changing-line-positions-mod7-v1"
      , Casting.lilaMoveSquares = 2
      }

kingWenMappings :: [(Int, Int)]
kingWenMappings =
  [ (0, 2)
  , (1, 24)
  , (2, 7)
  , (3, 19)
  , (4, 15)
  , (5, 36)
  , (6, 46)
  , (7, 11)
  , (8, 16)
  , (9, 51)
  , (10, 40)
  , (11, 54)
  , (12, 62)
  , (13, 55)
  , (14, 32)
  , (15, 34)
  , (16, 8)
  , (17, 3)
  , (18, 29)
  , (19, 60)
  , (20, 39)
  , (21, 63)
  , (22, 48)
  , (23, 5)
  , (24, 45)
  , (25, 17)
  , (26, 47)
  , (27, 58)
  , (28, 31)
  , (29, 49)
  , (30, 28)
  , (31, 43)
  , (32, 23)
  , (33, 27)
  , (34, 4)
  , (35, 41)
  , (36, 52)
  , (37, 22)
  , (38, 18)
  , (39, 26)
  , (40, 35)
  , (41, 21)
  , (42, 64)
  , (43, 38)
  , (44, 56)
  , (45, 30)
  , (46, 50)
  , (47, 14)
  , (48, 20)
  , (49, 42)
  , (50, 59)
  , (51, 61)
  , (52, 53)
  , (53, 37)
  , (54, 57)
  , (55, 9)
  , (56, 12)
  , (57, 25)
  , (58, 6)
  , (59, 10)
  , (60, 33)
  , (61, 13)
  , (62, 44)
  , (63, 1)
  ]

sampleDomain :: DomainData
sampleDomain =
  DomainData
    { leelaStates =
        [ LeelaState 1 "Innocence" "Direct experience." "Beginner's mind"
        , LeelaState 2 "Seeking" "Longing becomes movement." "Pilgrim"
        ]
    , hexagrams =
        [ Hexagram 1 "The Creative" "Persevere." "Heaven moves." "Heaven" "Heaven"
        , Hexagram 2 "The Receptive" "Receive." "Earth yields." "Earth" "Earth"
        ]
    , movingLineFocuses = []
    }

encodeResult :: Casting.CastingResult -> Value
encodeResult casting = case toJSON casting of
  Object fields -> Object (KM.insert "lilaMoveSquares" (toJSON (Casting.numberChanging casting)) (KM.delete "movementRule" fields))
  value -> value

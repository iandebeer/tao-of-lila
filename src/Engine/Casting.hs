{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Engine.Casting
  ( CastingDebug (..)
  , CastingEvent
  , CastingResult (..)
  , CastingState (..)
  , HeapSide
  , LineResult (..)
  , RoundSnapshot (..)
  , TrigramResult (..)
  , initialCastingState
  , nextCastingState
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.Bits (clearBit, setBit, testBit)
import Data.Text (Text)
import qualified Data.Text as T
import Domain.HexagramIndex (binaryToKingWen)
import GHC.Generics (Generic)

type CastingEvent = Text

type HeapSide = Text

data RoundSnapshot = RoundSnapshot
  { previousWorkingStalks :: Int
  , leftHeap :: Maybe Int
  , rightHeap :: Maybe Int
  , removedSide :: Maybe HeapSide
  , leftAfterSingle :: Maybe Int
  , rightAfterSingle :: Maybe Int
  , singleRemoved :: Int
  , leftGroupsOfFour :: Maybe Int
  , rightGroupsOfFour :: Maybe Int
  , leftRemainder :: Maybe Int
  , rightRemainder :: Maybe Int
  , totalRemoved :: Maybe Int
  , stalksRemaining :: Maybe Int
  }
  deriving (Eq, Show, Generic)

instance ToJSON RoundSnapshot
instance FromJSON RoundSnapshot

data LineResult = LineResult
  { lineNumber :: Int
  , finalStalkCount :: Int
  , lineValue :: Int
  , lineInterpretation :: Text
  , isChanging :: Bool
  }
  deriving (Eq, Show, Generic)

instance ToJSON LineResult
instance FromJSON LineResult

data TrigramResult = TrigramResult
  { trigramName :: Text
  , trigramSymbol :: Text
  , trigramBinaryValue :: Int
  }
  deriving (Eq, Show, Generic)

instance ToJSON TrigramResult
instance FromJSON TrigramResult

data CastingResult = CastingResult
  { primaryBinaryValue :: Int
  , transformedBinaryValue :: Int
  , primaryKingWenNumber :: Maybe Int
  , transformedKingWenNumber :: Maybe Int
  , changingLines :: [Int]
  , numberChanging :: Int
  , upperTrigramResult :: TrigramResult
  , lowerTrigramResult :: TrigramResult
  , nuclearUpperTrigramResult :: TrigramResult
  , nuclearLowerTrigramResult :: TrigramResult
  , lilaMoveSquares :: Int
  }
  deriving (Eq, Show, Generic)

instance ToJSON CastingResult
instance FromJSON CastingResult

data CastingDebug = CastingDebug
  { debugSeed :: Int
  , debugCastingId :: Text
  , debugStateId :: Int
  , debugEvent :: CastingEvent
  , debugDivisionPoint :: Maybe Int
  , debugRemovedSide :: Maybe HeapSide
  , debugWorkingBefore :: Int
  , debugWorkingAfter :: Int
  }
  deriving (Eq, Show, Generic)

instance ToJSON CastingDebug
instance FromJSON CastingDebug

data CastingState = CastingState
  { castingId :: Text
  , seed :: Int
  , stateId :: Int
  , event :: CastingEvent
  , prompt :: Text
  , totalStalks :: Int
  , setAside :: Int
  , workingStalks :: Int
  , currentLine :: Int
  , currentRound :: Int
  , roundSnapshot :: Maybe RoundSnapshot
  , completedLines :: [LineResult]
  , result :: Maybe CastingResult
  , debug :: CastingDebug
  }
  deriving (Eq, Show, Generic)

instance ToJSON CastingState
instance FromJSON CastingState

initialCastingState :: CastingState
initialCastingState =
  mkState
    827364923
    0
    "CastingNew"
    "[CLICK TO BEGIN]"
    0
    49
    1
    0
    Nothing
    []
    Nothing
    (Nothing, Nothing)
    49
    49

nextCastingState :: CastingState -> CastingState
nextCastingState state =
  case event state of
    "CastingNew" -> startRound state 1 1 49
    "LineStarted" -> divideHeaps state
    "HeapsDivided" -> removeSingleStalk state
    "SingleStalkRemoved" -> countRemainders state
    "RemaindersCounted" -> completeRound state
    "RoundComplete" -> advanceAfterRound state
    "LineComplete" -> advanceAfterLine state
    "CastingComplete" -> state
    _ -> state

startRound :: CastingState -> Int -> Int -> Int -> CastingState
startRound state line roundNumber working =
  mkState
    (seed state)
    (stateId state + 1)
    "LineStarted"
    "[CLICK TO DIVIDE]"
    1
    working
    line
    roundNumber
    (Just (emptyRoundSnapshot working))
    (completedLines state)
    Nothing
    (Nothing, Nothing)
    working
    working

divideHeaps :: CastingState -> CastingState
divideHeaps state =
  case roundSnapshot state of
    Nothing -> state
    Just snapshot ->
      let newSeed = nextSeed (seed state) (stateId state)
          divisionPoint = 2 + (newSeed `mod` (previousWorkingStalks snapshot - 3))
          right = previousWorkingStalks snapshot - divisionPoint
          nextSnapshot =
            snapshot
              { leftHeap = Just divisionPoint
              , rightHeap = Just right
              }
       in mkState
            newSeed
            (stateId state + 1)
            "HeapsDivided"
            "[CLICK TO REMOVE ONE STALK]"
            (setAside state)
            (workingStalks state)
            (currentLine state)
            (currentRound state)
            (Just nextSnapshot)
            (completedLines state)
            Nothing
            (Just divisionPoint, Nothing)
            (previousWorkingStalks snapshot)
            (previousWorkingStalks snapshot)

removeSingleStalk :: CastingState -> CastingState
removeSingleStalk state =
  case roundSnapshot state of
    Just snapshot ->
      case (leftHeap snapshot, rightHeap snapshot) of
        (Just left, Just right) ->
          let side = "RIGHT"
              leftAfter = left
              rightAfter = right - 1
              nextSnapshot =
                snapshot
                  { removedSide = Just side
                  , leftAfterSingle = Just leftAfter
                  , rightAfterSingle = Just rightAfter
                  }
           in mkState
                (seed state)
                (stateId state + 1)
                "SingleStalkRemoved"
                "[CLICK TO COUNT REMAINDERS]"
                (setAside state)
                (workingStalks state)
                (currentLine state)
                (currentRound state)
                (Just nextSnapshot)
                (completedLines state)
                Nothing
                (Nothing, Just side)
                (previousWorkingStalks snapshot)
                (leftAfter + rightAfter)
        _ -> state
    Nothing -> state

countRemainders :: CastingState -> CastingState
countRemainders state =
  case roundSnapshot state of
    Just snapshot ->
      case (leftAfterSingle snapshot, rightAfterSingle snapshot) of
        (Just left, Just right) ->
          let leftRemainderValue = yarrowRemainder left
              rightRemainderValue = yarrowRemainder right
              total = singleRemoved snapshot + leftRemainderValue + rightRemainderValue
              remaining = previousWorkingStalks snapshot - total
              nextSnapshot =
                snapshot
                  { leftGroupsOfFour = Just ((left - leftRemainderValue) `div` 4)
                  , rightGroupsOfFour = Just ((right - rightRemainderValue) `div` 4)
                  , leftRemainder = Just leftRemainderValue
                  , rightRemainder = Just rightRemainderValue
                  , totalRemoved = Just total
                  , stalksRemaining = Just remaining
                  }
           in mkState
                (seed state)
                (stateId state + 1)
                "RemaindersCounted"
                "[CLICK TO REMOVE REMAINDER]"
                (setAside state)
                (workingStalks state)
                (currentLine state)
                (currentRound state)
                (Just nextSnapshot)
                (completedLines state)
                Nothing
                (Nothing, removedSide snapshot)
                (previousWorkingStalks snapshot)
                remaining
        _ -> state
    Nothing -> state

completeRound :: CastingState -> CastingState
completeRound state =
  case roundSnapshot state >>= stalksRemaining of
    Nothing -> state
    Just remaining ->
      mkState
        (seed state)
        (stateId state + 1)
        "RoundComplete"
        ( if currentRound state < 3
            then "[CLICK FOR ROUND " <> showText (currentRound state + 1) <> "]"
            else "[CLICK TO COMPLETE LINE]"
        )
        (setAside state)
        remaining
        (currentLine state)
        (currentRound state)
        (roundSnapshot state)
        (completedLines state)
        Nothing
        (Nothing, roundSnapshot state >>= removedSide)
        (workingStalks state)
        remaining

advanceAfterRound :: CastingState -> CastingState
advanceAfterRound state =
  if currentRound state < 3
    then startRound state (currentLine state) (currentRound state + 1) (workingStalks state)
    else completeLine state

completeLine :: CastingState -> CastingState
completeLine state =
  let value = workingStalks state `div` 4
      line =
        LineResult
          { lineNumber = currentLine state
          , finalStalkCount = workingStalks state
          , lineValue = value
          , lineInterpretation = interpretLineValue value
          , isChanging = value == 6 || value == 9
          }
      linesNow = completedLines state <> [line]
      finalResult =
        if length linesNow == 6
          then Just (buildCastingResult linesNow)
          else Nothing
      nextEvent =
        if length linesNow == 6
          then "CastingComplete"
          else "LineComplete"
      nextPrompt =
        if length linesNow == 6
          then "[NEW CASTING]"
          else "[CLICK TO CAST LINE " <> showText (currentLine state + 1) <> "]"
   in mkState
        (seed state)
        (stateId state + 1)
        nextEvent
        nextPrompt
        (setAside state)
        (workingStalks state)
        (currentLine state)
        3
        (roundSnapshot state)
        linesNow
        finalResult
        (Nothing, roundSnapshot state >>= removedSide)
        (workingStalks state)
        (workingStalks state)

advanceAfterLine :: CastingState -> CastingState
advanceAfterLine state =
  startRound state (currentLine state + 1) 1 49

buildCastingResult :: [LineResult] -> CastingResult
buildCastingResult linesNow =
  let primary = lineResultsToBinary linesNow
      changing = lineNumber <$> filter isChanging linesNow
      transformed = foldl flipChangingLine primary changing
   in CastingResult
        { primaryBinaryValue = primary
        , transformedBinaryValue = transformed
        , primaryKingWenNumber = binaryToKingWen primary
        , transformedKingWenNumber = binaryToKingWen transformed
        , changingLines = changing
        , numberChanging = length changing
        , upperTrigramResult = trigramFromBinary ((primary `div` 8) `mod` 8)
        , lowerTrigramResult = trigramFromBinary (primary `mod` 8)
        , nuclearUpperTrigramResult = trigramFromBinary (nuclearUpper primary)
        , nuclearLowerTrigramResult = trigramFromBinary (nuclearLower primary)
        , lilaMoveSquares = length changing
        }

lineResultsToBinary :: [LineResult] -> Int
lineResultsToBinary =
  foldl setLine 0
  where
    setLine accumulator line =
      if lineValue line == 7 || lineValue line == 9
        then setBit accumulator (lineNumber line - 1)
        else clearBit accumulator (lineNumber line - 1)

flipChangingLine :: Int -> Int -> Int
flipChangingLine binary line =
  let bitIndex = line - 1
   in if testBit binary bitIndex
        then clearBit binary bitIndex
        else setBit binary bitIndex

nuclearLower :: Int -> Int
nuclearLower binary =
  bitValue 1 0 + bitValue 2 1 + bitValue 3 2
  where
    bitValue source target =
      if testBit binary source
        then setBit 0 target
        else 0

nuclearUpper :: Int -> Int
nuclearUpper binary =
  bitValue 2 0 + bitValue 3 1 + bitValue 4 2
  where
    bitValue source target =
      if testBit binary source
        then setBit 0 target
        else 0

trigramFromBinary :: Int -> TrigramResult
trigramFromBinary 0 = TrigramResult "Kun" "000" 0
trigramFromBinary 1 = TrigramResult "Zhen" "100" 1
trigramFromBinary 2 = TrigramResult "Kan" "010" 2
trigramFromBinary 3 = TrigramResult "Dui" "110" 3
trigramFromBinary 4 = TrigramResult "Gen" "001" 4
trigramFromBinary 5 = TrigramResult "Li" "101" 5
trigramFromBinary 6 = TrigramResult "Xun" "011" 6
trigramFromBinary _ = TrigramResult "Qian" "111" 7

interpretLineValue :: Int -> Text
interpretLineValue 6 = "Changing Yin"
interpretLineValue 7 = "Stable Yang"
interpretLineValue 8 = "Stable Yin"
interpretLineValue 9 = "Changing Yang"
interpretLineValue _ = "Unknown"

yarrowRemainder :: Int -> Int
yarrowRemainder value =
  case value `mod` 4 of
    0 -> 4
    remainder -> remainder

emptyRoundSnapshot :: Int -> RoundSnapshot
emptyRoundSnapshot working =
  RoundSnapshot
    { previousWorkingStalks = working
    , leftHeap = Nothing
    , rightHeap = Nothing
    , removedSide = Nothing
    , leftAfterSingle = Nothing
    , rightAfterSingle = Nothing
    , singleRemoved = 1
    , leftGroupsOfFour = Nothing
    , rightGroupsOfFour = Nothing
    , leftRemainder = Nothing
    , rightRemainder = Nothing
    , totalRemoved = Nothing
    , stalksRemaining = Nothing
    }

mkState ::
  Int ->
  Int ->
  CastingEvent ->
  Text ->
  Int ->
  Int ->
  Int ->
  Int ->
  Maybe RoundSnapshot ->
  [LineResult] ->
  Maybe CastingResult ->
  (Maybe Int, Maybe HeapSide) ->
  Int ->
  Int ->
  CastingState
mkState nextSeedValue nextStateId nextEvent nextPrompt nextSetAside nextWorking line roundNumber snapshot linesNow finalResult randomChoice workingBefore workingAfter =
  let castingIdentifier = "casting-827364923"
   in CastingState
        { castingId = castingIdentifier
        , seed = nextSeedValue
        , stateId = nextStateId
        , event = nextEvent
        , prompt = nextPrompt
        , totalStalks = 50
        , setAside = nextSetAside
        , workingStalks = nextWorking
        , currentLine = line
        , currentRound = roundNumber
        , roundSnapshot = snapshot
        , completedLines = linesNow
        , result = finalResult
        , debug =
            CastingDebug
              { debugSeed = nextSeedValue
              , debugCastingId = castingIdentifier
              , debugStateId = nextStateId
              , debugEvent = nextEvent
              , debugDivisionPoint = fst randomChoice
              , debugRemovedSide = snd randomChoice
              , debugWorkingBefore = workingBefore
              , debugWorkingAfter = workingAfter
              }
        }

nextSeed :: Int -> Int -> Int
nextSeed current salt =
  (current * 1103515245 + 12345 + salt * 97) `mod` 2147483647

showText :: Show a => a -> Text
showText =
  fromString . show

fromString :: String -> Text
fromString =
  T.pack

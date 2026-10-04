{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  )
where

import qualified Domain.Persona as P
import qualified Domain.StateView as SV
import StateViewHTTP (checkStateViewHTTP)
import qualified Data.Text as T
import Data.Text (Text)
import Data.Aeson (Value (..), toJSON, encode, object, (.=), fromJSON, Result (..))
import qualified Data.Aeson.KeyMap as KM
import Data.Bits (testBit, xor)
import qualified Data.Text.Encoding as TE
import qualified Data.ByteString.Lazy as LBS
import Interpretation.OpenAI (decodeContemplationResponse)
import Domain.Types
  ( DomainData (..)
  , Hexagram (..)
  , LeelaState (..)
  , MovingLine (..)
  , Reading (..)
  , ReadingRequest (..)
  )
import Engine.Movement (movementFromChangingLines)
import Domain.Journey (allowedStage)
import Domain.HexagramIndex (binaryToKingWen, kingWenToBinary)
import Domain.Contemplation
import qualified Engine.Casting as Casting
import Runtime.Casting (freshCastingState)
import Control.Monad (replicateM)
import Data.List (nub)
import Engine.Reading (generateReading)
import Engine.Game (accessibleStateIds, applyCastingMovement)

main :: IO ()
main = do
  fresh <- replicateM 32 freshCastingState
  assert "new castings draw varied seeds" (length (nub (map Casting.seed fresh)) > 1)
  assert "initial debug seed matches engine seed" (all (\s -> Casting.debugSeed (Casting.debug s) == Casting.seed s) fresh)
  let complete = until ((/= Nothing) . Casting.result) Casting.nextCastingState
      seeded = Casting.initialCastingStateWithSeed 123456
      partial = iterate Casting.nextCastingState seeded !! 37
  assert "saved casting resumes identically" (complete partial == complete seeded)
  let contexts = [buildContemplationContext (LeelaState 1 "Innocence" "" "") "What can I learn?" result | casting <- fresh, Just result <- [Casting.result (complete casting)]]
  assert "fresh casting results can all be interpreted" (all (either (const False) (const True)) contexts)
  let baseline = maybe (error "Fixture casting did not finish") id (Casting.result (complete seeded))
      allPairs = [baseline {Casting.primaryBinaryValue = binary, Casting.transformedBinaryValue = binary `xor` 63, Casting.primaryKingWenNumber = binaryToKingWen binary, Casting.transformedKingWenNumber = binaryToKingWen (binary `xor` 63), Casting.changingLines = [1..6], Casting.numberChanging = 6} | binary <- [0..63]]
  assert "all 64 primary/resulting configurations have live interpretation context" (all (either (const False) ((== 6) . length . contemplationChangingLines) . buildContemplationContext (LeelaState 1 "Innocence" "" "") "What can I learn?") allPairs)

  assert "same seed replays exactly" (complete seeded == complete (Casting.initialCastingStateWithSeed 123456))
  assert "fresh castings produce varied results" (length (nub (map (Casting.result . complete) fresh)) > 1)
  catalog <- SV.loadStateCatalog "data/state-views.json" >>= either fail pure
  assert "all 72 canonical view identities are retrievable" (all (\n -> maybe False ((== n) . stateId . SV.identity) (SV.lookupStateView catalog n)) [1..72])
  assert "invalid tile has no identity" (SV.lookupStateView catalog 73 == Nothing)
  assert "all eight trigrams are retrievable" (all (\n -> maybe False ((== n) . SV.trigramBinary) (SV.lookupTrigramView catalog n)) [0..7])
  assert "all binary-keyed hexagrams match King Wen lookup" (all (\n -> fmap SV.kingWenNumber (SV.lookupHexagramView catalog n) == binaryToKingWen n) [0..63])
  let relation n = SV.lookupStateView catalog n >>= SV.traditionalReference >>= SV.transition
  assert "snake reference is 55 to 3" (fmap SV.destination (relation 55) == Just 3)
  assert "arrow reference is 37 to 66" (fmap SV.destination (relation 37) == Just 66)
  assert "snake destination uses reference identity, not prototype Discipline" (fmap SV.englishName (SV.lookupStateView catalog 55 >>= SV.transitionDestination catalog) == Just "Anger")
  assert "missing artwork remains valid" (SV.validateStateCatalog catalog == Right catalog)
  assert "duplicate canonical identities rejected" (isLeft (SV.validateStateCatalog catalog {SV.stateViews = take 1 (SV.stateViews catalog) ++ SV.stateViews catalog}))
  let badStates = map (\v -> if stateId (SV.identity v) == 55 then v {SV.traditionalReference = fmap (\r -> r {SV.transition = Just (SV.StateTransition SV.Snake 99 "Invalid")}) (SV.traditionalReference v)} else v) (SV.stateViews catalog)
  assert "out-of-range transition rejected" (isLeft (SV.validateStateCatalog catalog {SV.stateViews = badStates}))
  checkStateViewHTTP sampleDomain catalog
  let draft = P.PersonaDraft "Scholar" "An elderly fictional scholar" [] "Community responsibilities" Nothing Nothing
  a <- either (fail . T.unpack) pure (P.newPersona 1 (P.Player 7) "2026-09-23" draft)
  b <- either (fail . T.unpack) pure (P.newPersona 2 (P.Player 7) "2026-09-23" draft)
  changed <- either (fail . T.unpack) pure (P.revisePersona "2026-09-24" draft {P.draftDescription="A later intervention", P.draftRevision=Just 0} a)
  assert "one Player owns distinct Personas" (P.personaPlayerId a == P.personaPlayerId b && P.personaId a /= P.personaId b)
  assert "editing preserves initial Persona and leaves sibling unchanged" (P.personaInitialDescription changed == P.personaDescription a && P.personaDescription b /= P.personaDescription changed)
  assert "stale Persona edit rejected" (case P.revisePersona "later" draft changed of Left _ -> True; _ -> False)
  let profile = [P.PersonaAttribute "sex" (String "Female") P.PlayerSpecified [], P.PersonaAttribute "age" (Number 45) P.PlayerSpecified [], P.PersonaAttribute "raceEthnicity" (String "Self-described heritage") P.PlayerSpecified [], P.PersonaAttribute "historicalPeriod" (String "Renaissance") P.PlayerSpecified []]
      structured = draft {P.draftAttributes=profile,P.draftContext="Additional information"}
  profiled <- either (fail . T.unpack) pure (P.newPersona 3 (P.Player 7) "2026-10-04" structured)
  revisedProfile <- either (fail . T.unpack) pure (P.revisePersona "later" structured {P.draftAttributes=[P.PersonaAttribute "age" Null P.PlayerIntervention []],P.draftRevision=Just 0} profiled)
  assert "structured attributes preserve initial identity when cleared" (P.personaInitialAttributes revisedProfile == profile && map P.attributeValue (P.personaEvolvingAttributes revisedProfile) == [Null])
  assert "negative Persona age is rejected" (isLeft (P.newPersona 4 (P.Player 7) "now" structured {P.draftAttributes=[P.PersonaAttribute "age" (Number (-1)) P.PlayerSpecified []]}))
  assert "fractional Persona age is rejected" (isLeft (P.newPersona 4 (P.Player 7) "now" structured {P.draftAttributes=[P.PersonaAttribute "age" (Number 2.5) P.PlayerSpecified []]}))
  assert "structured text cannot be an arbitrary JSON object" (isLeft (P.newPersona 4 (P.Player 7) "now" structured {P.draftAttributes=[P.PersonaAttribute "sex" (object []) P.PlayerSpecified []]}))
  assert "duplicate Persona attributes rejected" (isLeft (P.newPersona 4 (P.Player 7) "now" structured {P.draftAttributes=profile++profile}))
  assert "prompt treats demographic fields as narrative context without stereotypes" ("demographic stereotypes" `T.isInfixOf` P.personaPrompt profiled)
  let evidence = P.Evidence "event:1" P.AIInferred "question:1" 1 True "2026-09-23"
  supported <- either (fail . T.unpack) pure (P.observeTheme "loss" evidence a)
  duplicate <- either (fail . T.unpack) pure (P.observeTheme "loss" evidence supported)
  contradicted <- either (fail . T.unpack) pure (P.observeTheme "loss" evidence {P.evidenceId="event:2",P.evidenceSupports=False} supported)
  assert "evidence strengthens themes with uncertainty" (map P.themeConfidence (P.personaThemes supported) == [2/3])
  assert "duplicate evidence is idempotent" (supported == duplicate)
  assert "contradiction weakens themes" (map P.themeConfidence (P.personaThemes contradicted) == [0.5])
  assert "theme observations do not change initial context or siblings" (null (P.personaThemes b) && P.personaInitialDescription supported == P.personaInitialDescription a)
  assert "AI prompt marks constructed Persona and protects Player privacy" ("fictional or constructed persona" `T.isInfixOf` P.personaPrompt a && "never factual attributes of the Player" `T.isInfixOf` P.personaPrompt a)
  assert "archived Persona rejects edits" (case P.revisePersona "later" draft {P.draftRevision=Just 0} a {P.personaArchived=True} of Left _ -> True; _ -> False)

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
  assert "finalized questions cannot be edited" (all (not . allowedStage "draft") ["casting", "result", "interpretation", "reflection", "movement"])
  assert "movement cannot be acknowledged before reflection" (all (not . allowedStage "acknowledge") ["progress", "question", "casting", "result", "interpretation", "reflection"])
  assert "a completed movement cannot be acknowledged twice" (allowedStage "acknowledge" "movement" && not (allowedStage "acknowledge" "progress"))
  assert "journal edits are restricted to reflection" (allowedStage "journal" "reflection" && not (allowedStage "journal" "casting"))
  assert "King Wen lookup round-trips all 64 values" (all (\n -> (kingWenToBinary n >>= binaryToKingWen) == Just n) [1..64])
  assert "King Wen lookup rejects out-of-range inputs" (all ((== Nothing) . kingWenToBinary) [-1,0,65])
  assert "direct pair changes line 2 from Yang" (pairLines 11 36 == Right [(2,9)])
  assert "reversed pair changes line 2 from Yin" (pairLines 36 11 == Right [(2,6)])
  assert "identical hexagrams have no changes" (pairLines 11 11 == Right [])
  assert "direct pair rejects invalid numbers" (isLeft (pairLines 0 36) && isLeft (pairLines 11 65))
  assert "unseeded pair reports unavailable corpus" (isLeft (pairLines 1 2))
  assert "raw Responses API output is decoded after reasoning items" (decodeContemplationResponse (wireResponse "completed" textContent) == Right sampleContemplation)
  let limited = encode (object ["status" .= ("incomplete" :: Text), "incomplete_details" .= object ["reason" .= ("max_output_tokens" :: Text)]])
      filtered = encode (object ["status" .= ("incomplete" :: Text), "incomplete_details" .= object ["reason" .= ("content_filter" :: Text)]])
  assert "output exhaustion explains the configuration and preserves the casting" (case decodeContemplationResponse limited of Left message -> "output limit" `T.isInfixOf` T.pack message; _ -> False)
  assert "content filtering is distinguished from output exhaustion" (case decodeContemplationResponse filtered of Left message -> "content filter" `T.isInfixOf` T.pack message; _ -> False)
  assert "incomplete Responses API output is rejected" (isLeft (decodeContemplationResponse (wireResponse "incomplete" textContent)))
  assert "refused Responses API output is rejected" (isLeft (decodeContemplationResponse (wireResponse "completed" [object ["type" .= ("refusal" :: String), "refusal" .= ("Declined" :: String)]])) )
  assert "missing output text is rejected" (isLeft (decodeContemplationResponse (wireResponse "completed" [])))
  assert "invalid structured response is rejected" (isLeft (decodeContemplationResponse (wireResponse "completed" [object ["type" .= ("output_text" :: String), "text" .= ("not JSON" :: String)]])) )

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

isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft _ = False

pairLines :: Int -> Int -> Either Text [(Int, Int)]
pairLines primary resulting = do
  context <- buildPairContemplationContext
    (LeelaState 1 "Innocence" "Direct experience." "Beginner's mind")
    "How can I meet this change?" primary resulting
  pure [(changingLineNumber line, changingLineValue line) | line <- contemplationChangingLines context]

sampleContemplation :: ContemplationResponse
sampleContemplation = ContemplationResponse "Context" "Primary" ["Line 2"] "Change" ["A reading"] ["A question?"]

textContent :: [Value]
textContent = [object ["type" .= ("output_text" :: String), "text" .= TE.decodeUtf8 (LBS.toStrict (encode sampleContemplation))]]

wireResponse :: String -> [Value] -> LBS.ByteString
wireResponse status content = encode (object
  [ "status" .= status
  , "model" .= ("test-model" :: String)
  , "output" .= [object ["type" .= ("reasoning" :: String)], object ["type" .= ("message" :: String), "content" .= content]]
  , "usage" .= object ["input_tokens" .= (10 :: Int), "output_tokens" .= (20 :: Int)]
  ])

encodeResult :: Casting.CastingResult -> Value
encodeResult casting = case toJSON casting of
  Object fields -> Object (KM.insert "lilaMoveSquares" (toJSON (Casting.numberChanging casting)) (KM.delete "movementRule" fields))
  value -> value

module Main (main) where

import qualified Engine.Casting as C
import Engine.Movement (movementFromChangingLines)
import Data.List (foldl')
import Text.Printf (printf)

sampleSize :: Int
sampleSize = 100000

main :: IO ()
main = do
  let (lineCounts, moveCounts, masks, hexagrams) = foldl' sample (replicate 4 0, replicate 7 0, replicate 64 0, replicate 64 0) [1..sampleSize]
      lineFrequencies = map ((/ fromIntegral (sampleSize * 6)) . fromIntegral) lineCounts :: [Double]
      moveFrequencies = map ((/ fromIntegral sampleSize) . fromIntegral) moveCounts :: [Double]
      expectedLines = replicate 4 (1/4)
      expectedMoves = 10/64 : replicate 6 (9/64)
      linePass = and (zipWith (near 0.004) lineFrequencies expectedLines)
      movePass = and (zipWith (near 0.006) moveFrequencies expectedMoves)
      uniform :: [Int] -> Bool
      uniform counts = all (\n -> near (0.0015 :: Double) (fromIntegral n / fromIntegral sampleSize) (1/64)) counts
      independentPass = uniform masks && uniform hexagrams
      equalPass = maximum (tail moveFrequencies) - minimum (tail moveFrequencies) < 0.006
  putStrLn "100000 deterministic full engine castings; seeds 1..100000"
  mapM_ (\(v,p) -> printf "Line %d: %.4f%%\n" v (100*p)) (zip ([6..9] :: [Int]) lineFrequencies)
  mapM_ (\(v,p) -> printf "Move %d: %.4f%%\n" v (100*p)) (zip ([0..6] :: [Int]) moveFrequencies)
  putStrLn ("Movement target frequencies: " <> show movePass <> "; equal nonzero movements: " <> show equalPass)
  putStrLn ("Leela balanced line frequencies: " <> show linePass)
  putStrLn ("Independent changing-line patterns and uniform primary hexagrams: " <> show independentPass)
  if linePass && movePass && equalPass && independentPass then pure ()
    else fail "Statistical acceptance failed. Do not alter oracle sampling to compensate in board movement."
  where
    near tolerance actual expected = abs (actual-expected) < tolerance

sample :: ([Int],[Int],[Int],[Int]) -> Int -> ([Int],[Int],[Int],[Int])
sample (linesBefore,movesBefore,masksBefore,hexagramsBefore) seed =
  let final = until ((/=Nothing) . C.result) C.nextCastingState (C.initialCastingStateWithSeed seed)
      values = map C.lineValue (C.completedLines final)
      positions = [C.lineNumber line | line <- C.completedLines final, C.lineValue line `elem` [6,9]]
      movement = movementFromChangingLines positions
      linesAfter = zipWith (+) linesBefore [length (filter (==v) values) | v <- [6..9]]
      movesAfter = zipWith (+) movesBefore [if v==movement then 1 else 0 | v <- [0..6]]
      mask :: Int
      mask = sum [2^(position-1) | position <- positions]
      masksAfter = zipWith (+) masksBefore [if v==mask then 1 else 0 | v <- [0..63]]
      primary :: Int
      primary = sum [2^(C.lineNumber line-1) | line <- C.completedLines final, odd (C.lineValue line)]
      hexagramsAfter = zipWith (+) hexagramsBefore [if v==primary then 1 else 0 | v <- [0..63]]
      valid = case C.result final of
        Just result -> C.changingLines result == positions && C.numberChanging result == length positions && C.lilaMoveSquares result == movement
        Nothing -> False
   in if valid then force linesAfter `seq` force movesAfter `seq` force masksAfter `seq` force hexagramsAfter `seq` (linesAfter,movesAfter,masksAfter,hexagramsAfter)
      else error "Casting facts and movement projection disagree"
  where force = foldl' (+) 0

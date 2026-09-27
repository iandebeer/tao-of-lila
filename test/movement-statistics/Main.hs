module Main (main) where

import qualified Engine.Casting as C
import Engine.Movement (movementFromChangingLines)
import Data.List (foldl')
import Text.Printf (printf)

sampleSize :: Int
sampleSize = 100000

main :: IO ()
main = do
  let (lineCounts, moveCounts) = foldl' sample (replicate 4 0, replicate 7 0) [1..sampleSize]
      lineFrequencies = map ((/ fromIntegral (sampleSize * 6)) . fromIntegral) lineCounts :: [Double]
      moveFrequencies = map ((/ fromIntegral sampleSize) . fromIntegral) moveCounts :: [Double]
      expectedLines = [1/16,5/16,7/16,3/16]
      expectedMoves = 527/2048 : replicate 6 (507/4096)
      linePass = and (zipWith (near 0.004) lineFrequencies expectedLines)
      movePass = and (zipWith (near 0.006) moveFrequencies expectedMoves)
      equalPass = maximum (tail moveFrequencies) - minimum (tail moveFrequencies) < 0.006
  putStrLn "100000 deterministic full engine castings; seeds 1..100000"
  mapM_ (\(v,p) -> printf "Line %d: %.4f%%\n" v (100*p)) (zip ([6..9] :: [Int]) lineFrequencies)
  mapM_ (\(v,p) -> printf "Move %d: %.4f%%\n" v (100*p)) (zip ([0..6] :: [Int]) moveFrequencies)
  putStrLn ("Movement target frequencies: " <> show movePass <> "; equal nonzero movements: " <> show equalPass)
  putStrLn ("Traditional yarrow line frequencies: " <> show linePass)
  if linePass && movePass && equalPass then pure ()
    else fail "Statistical acceptance failed. Do not alter oracle sampling to compensate in board movement."
  where
    near tolerance actual expected = abs (actual-expected) < tolerance

sample :: ([Int],[Int]) -> Int -> ([Int],[Int])
sample (linesBefore,movesBefore) seed =
  let final = until ((/=Nothing) . C.result) C.nextCastingState (C.initialCastingState {C.seed=seed})
      values = map C.lineValue (C.completedLines final)
      positions = [C.lineNumber line | line <- C.completedLines final, C.lineValue line `elem` [6,9]]
      movement = movementFromChangingLines positions
      linesAfter = zipWith (+) linesBefore [length (filter (==v) values) | v <- [6..9]]
      movesAfter = zipWith (+) movesBefore [if v==movement then 1 else 0 | v <- [0..6]]
      valid = case C.result final of
        Just result -> C.changingLines result == positions && C.numberChanging result == length positions && C.lilaMoveSquares result == movement
        Nothing -> False
   in if valid then force linesAfter `seq` force movesAfter `seq` (linesAfter,movesAfter)
      else error "Casting facts and movement projection disagree"
  where force = foldl' (+) 0

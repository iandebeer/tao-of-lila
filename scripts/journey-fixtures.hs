{-# LANGUAGE OverloadedStrings #-}
-- Run: cabal exec -- runghc -isrc scripts/journey-fixtures.hs > app/public/journey/castings.json
import qualified Engine.Casting as C
import Engine.Game (applyCastingMovement)
import Data.Aeson (encode, object, (.=))
import qualified Data.ByteString.Lazy.Char8 as L
import Data.Maybe (fromJust)

trace :: Int -> [C.CastingState]
trace seed = go (C.initialCastingState {C.seed = seed}) where
  go s = s : if C.result s /= Nothing then [] else go (C.nextCastingState s)

example :: Int -> [C.CastingState]
example count = head [states | seed <- [1..100000], let states = trace seed, C.numberChanging (fromJust (C.result (last states))) == count, count /= 1 || C.lilaMoveSquares (fromJust (C.result (last states))) == 1]
main :: IO ()
main = L.putStrLn $ encode $ object ["zero" .= example 0, "ordinary" .= example 1, "six" .= example 6, "still-changing" .= head [states | seed <- [1..100000], let states = trace seed, C.changingLines (fromJust (C.result (last states))) == [2,5]], "moves" .= [[applyCastingMovement current ((fromJust (C.result (last (example 0)))) {C.lilaMoveSquares = count}) | count <- [0..6]] | current <- [1..72]]]

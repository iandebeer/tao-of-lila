module Engine.Game
  ( accessibleStateIds
  , applyCastingMovement
  )
where

import Engine.Casting (CastingResult (..))

accessibleStateIds :: Int -> [Int]
accessibleStateIds current =
  take 6 [current + 1 .. 72]

applyCastingMovement :: Int -> CastingResult -> Int
applyCastingMovement current castingResult =
  min 72 (current + lilaMoveSquares castingResult)

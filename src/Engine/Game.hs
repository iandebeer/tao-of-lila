module Engine.Game
  ( accessibleStateIds
  , BoardTransition (..)
  , boardTransitions
  , transitionAt
  , castingLanding
  , castingTransition
  , applyCastingMovement
  )
where

import Engine.Casting (CastingResult (..))

data BoardTransition = Snake | Ladder deriving (Eq, Show)

-- The same 72-square edition used by the tile catalogue. Regression tests keep
-- the engine's authoritative rules and the published reference endpoints aligned.
boardTransitions :: [(Int, BoardTransition, Int)]
boardTransitions =
  [(10,Ladder,23),(17,Ladder,69),(20,Ladder,32),(22,Ladder,60)
  ,(27,Ladder,41),(28,Ladder,50),(37,Ladder,66),(45,Ladder,67)
  ,(46,Ladder,62),(54,Ladder,68)
  ,(12,Snake,8),(16,Snake,4),(24,Snake,7),(29,Snake,6)
  ,(44,Snake,9),(52,Snake,35),(55,Snake,3),(61,Snake,13)
  ,(63,Snake,2),(72,Snake,51)]

transitionAt :: Int -> Maybe (BoardTransition, Int)
transitionAt tile = lookup tile [(origin,(kind,target)) | (origin,kind,target) <- boardTransitions]

accessibleStateIds :: Int -> [Int]
accessibleStateIds current = take 6 [current + 1 .. 72]

castingLanding :: Int -> CastingResult -> Int
castingLanding current castingResult = min 72 (current + lilaMoveSquares castingResult)

-- Stillness does not land on a new square and must not retrigger a transition.
castingTransition :: Int -> CastingResult -> Maybe (BoardTransition, Int)
castingTransition current castingResult
  | lilaMoveSquares castingResult <= 0 = Nothing
  | otherwise = transitionAt (castingLanding current castingResult)

applyCastingMovement :: Int -> CastingResult -> Int
applyCastingMovement current castingResult =
  maybe (castingLanding current castingResult) snd (castingTransition current castingResult)

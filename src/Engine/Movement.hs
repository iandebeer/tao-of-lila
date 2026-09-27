-- Board movement is a projection of oracle facts, not part of sampling them.
module Engine.Movement (movementFromChangingLines) where

-- Positions are the canonical bottom-to-top line numbers 1 through 6.
movementFromChangingLines :: [Int] -> Int
movementFromChangingLines positions = sum positions `mod` 7

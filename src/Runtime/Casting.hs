module Runtime.Casting (freshCastingState) where

import Crypto.Random (getRandomBytes)
import qualified Data.ByteString as BS
import Engine.Casting (CastingState, initialCastingStateWithSeed)

-- Entropy belongs in the IO shell. The saved engine state remains sufficient
-- to replay or resume every subsequent step without drawing new randomness.
freshCastingState :: IO CastingState
freshCastingState = do
  bytes <- getRandomBytes 4 :: IO BS.ByteString
  let value = BS.foldl' (\acc byte -> acc * 256 + fromIntegral byte) 0 bytes :: Integer
      candidate = value `mod` 2147483648
  -- Rejection keeps the draw uniform over the engine's seed range.
  if candidate == 2147483647 then freshCastingState
    else pure (initialCastingStateWithSeed (fromInteger candidate))

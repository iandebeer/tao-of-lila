module Domain.HexagramIndex
  ( BinaryValue
  , KingWenNumber
  , binaryToKingWen
  , binaryToKingWenTable
  , validBinaryValue
  )
where

import Data.Array (Array, bounds, listArray, (!))

type BinaryValue = Int

type KingWenNumber = Int

binaryToKingWen :: BinaryValue -> Maybe KingWenNumber
binaryToKingWen binaryValue
  | validBinaryValue binaryValue = Just (binaryToKingWenTable ! binaryValue)
  | otherwise = Nothing

validBinaryValue :: BinaryValue -> Bool
validBinaryValue binaryValue =
  binaryValue >= lowerBound && binaryValue <= upperBound
  where
    (lowerBound, upperBound) = bounds binaryToKingWenTable

binaryToKingWenTable :: Array BinaryValue KingWenNumber
binaryToKingWenTable =
  listArray
    (0, 63)
    [ 2
    , 24
    , 7
    , 19
    , 15
    , 36
    , 46
    , 11
    , 16
    , 51
    , 40
    , 54
    , 62
    , 55
    , 32
    , 34
    , 8
    , 3
    , 29
    , 60
    , 39
    , 63
    , 48
    , 5
    , 45
    , 17
    , 47
    , 58
    , 31
    , 49
    , 28
    , 43
    , 23
    , 27
    , 4
    , 41
    , 52
    , 22
    , 18
    , 26
    , 35
    , 21
    , 64
    , 38
    , 56
    , 30
    , 50
    , 14
    , 20
    , 42
    , 59
    , 61
    , 53
    , 37
    , 57
    , 9
    , 12
    , 25
    , 6
    , 10
    , 33
    , 13
    , 44
    , 1
    ]

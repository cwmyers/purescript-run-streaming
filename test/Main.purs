module Test.Main where

import Prelude hiding (map)
import Control.Monad.Eff (Eff)
import Data.Array as A
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..))
import Run (Run, run)
import Run.Streaming.Prelude as S
import Run.Streaming.Push as Push
import Run.Streaming.Pull as Pull
import Test.Assert (ASSERT, assert')

toArray ∷ ∀ x. Run (S.Producer x ()) Unit → Array x
toArray = run <<< S.fold A.snoc [] id

-- Push based take
take' ∷ ∀ x r. Int → x → Run (S.Transformer x x r) Unit
take' 0 _ = pure unit
take' n x = S.yield x >>= S.request >>= take' (n - 1)

data Req = A Int | B Int
type Rep = String

main ∷ Eff (assert ∷ ASSERT) Unit
main = do
  assert' "pull/take"
    let
      test =
        S.succ 1
          # S.feed (S.take 10)
          # toArray
    in
      test == 1 A... 10

  assert' "push/take"
    let
      test =
        S.succ 1
          # Push.chain (take' 10)
          # toArray
    in
      test == 1 A... 10

  assert' "pull/map"
    let
      test =
        S.succ 1
          # S.feed (S.map show)
          # S.feed (S.take 10)
          # toArray
    in
      test == (show <$> 1 A... 10)

  assert' "pull/filter"
    let
      test =
        S.succ 1
          # S.feed (S.filter \n → n/2*2 == n)
          # S.feed (S.take 5)
          # toArray
    in
      test == [2, 4, 6, 8, 10]

  assert' "push/each"
    let
      test =
        S.each (1 A... 10)
          # toArray
    in
      test == (1 A... 10)

  assert' "pull/concat"
    let
      test =
        S.each [Just 1, Nothing, Just 3, Just 4]
          # S.feed S.concat
          # toArray
    in
      test == [1, 3, 4]

  assert' "pull/concatMap"
    let
      test =
        S.succ 1
          # S.feed (S.concatMap \n → if n/2*2 == n then Just n else Nothing)
          # S.feed (S.take 5)
          # toArray
    in
      test == [2, 4, 6, 8, 10]

  assert' "pull/takeWhile"
    let
      test =
        S.succ 1
          # S.feed (S.takeWhile (_ <= 10))
          # toArray
    in
      test == 1 A... 10

  assert' "pull/drop"
    let
      test =
        S.succ 1
          # S.feed (S.drop 10)
          # S.feed (S.take 10)
          # toArray
    in
      test == 11 A... 20

  assert' "pull/dropWhile"
    let
      test =
        S.succ 1
          # S.feed (S.dropWhile (_ <= 10))
          # S.feed (S.take 10)
          # toArray
    in
      test == 11 A... 20

  assert' "pull/scan"
    let
      test =
        S.succ 1
          # S.feed (S.scan (+) 0 show)
          # S.feed (S.take 5)
          # toArray
    in
      test == ["0", "1", "3", "6", "10"]

  assert' "push/zipWith"
    let
      test =
        S.zipWith (+) (S.succ 1) (S.succ 1)
          # S.feed (S.take 5)
          # toArray
    in
      test == [2, 4, 6, 8, 10]

  assert' "null"
    let
      test =
        S.each []
          # S.null
    in
      run test

  assert' "head"
    let
      test =
        S.succ 1
          # S.head
    in
      run test == Just 1

  assert' "last"
    let
      test =
        S.succ 1
          # S.feed (S.take 10)
          # S.last
    in
      run test == Just 10

  assert' "all/true"
    let
      test =
        S.succ 1
          # S.feed (S.take 10)
          # S.all (_ < 11)
    in
      run test

  assert' "all/false"
    let
      test =
        S.succ 1
          # S.feed (S.take 10)
          # S.all (_ < 10)
    in
      not run test

  assert' "any/true"
    let
      test =
        S.succ 1
          # S.feed (S.take 10)
          # S.any (_ > 5)
    in
      run test

  assert' "any/false"
    let
      test =
        S.succ 1
          # S.feed (S.take 10)
          # S.any (_ > 10)
    in
      not run test

  assert' "elem/true"
    let
      test =
        S.succ 1
          # S.feed (S.take 10)
          # S.elem 5
    in
      run test

  assert' "elem/false"
    let
      test =
        S.succ 1
          # S.feed (S.take 10)
          # S.elem 11
    in
      not run test

  assert' "find"
    let
      test =
        S.succ 1
          # S.find (_ == 5)
    in
      run test == Just 5

  assert' "index"
    let
      test =
        S.succ 1
          # S.index 4
    in
      run test == Just 5

  assert' "findIndex"
    let
      test =
        S.succ 1
          # S.findIndex (_ == 5)
    in
      run test == Just (Tuple 4 5)

  assert' "length"
    let
      test =
        S.succ 1
          # S.feed (S.take 10)
          # S.length
    in
      run test == 10

  assert' "sum"
    let
      test =
        S.succ 1
          # S.feed (S.take 10)
          # S.sum
    in
      run test == 55

  assert' "product"
    let
      test =
        S.succ 1
          # S.feed (S.take 10)
          # S.product
    in
      run test == 3628800

  assert' "minimum"
    let
      test =
        S.each (10 A... 1)
          # S.minimum
    in
      run test == Just 1

  assert' "maximum"
    let
      test =
        S.each (1 A... 10)
          # S.maximum
    in
      run test == Just 10

  assert' "server/client"
    let
      client =
        S.for (S.succ 1) \n → do
          s ← S.request if n/2*2 /= n then A n else B n
          S.yield s

      server m req =
        S.respond case req of
          A n → "A: " <> show n <> " @ " <> show m
          B n → "B: " <> show n <> " @ " <> show m
        >>= server (m + 10)

      test =
        client
          # Pull.chain (server 10)
          # S.feed (S.take 4)
          # toArray
    in
      test ==
        [ "A: 1 @ 10"
        , "B: 2 @ 20"
        , "A: 3 @ 30"
        , "B: 4 @ 40"
        ]

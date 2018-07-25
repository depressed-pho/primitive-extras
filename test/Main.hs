module Main where

import Prelude
import Test.QuickCheck.Instances
import Test.Tasty
import Test.Tasty.Runners
import Test.Tasty.HUnit
import Test.Tasty.QuickCheck
import PrimitiveExtras.SparseSmallArray (SparseSmallArray)
import qualified Test.QuickCheck as QuickCheck
import qualified Test.QuickCheck.Property as QuickCheck
import qualified Main.Transaction as Transaction
import qualified Main.Gens as Gen
import qualified PrimitiveExtras.SparseSmallArray as SparseSmallArray
import qualified PrimitiveExtras.SmallArray as SmallArray


main =
  defaultMain $
  testGroup "All" $
  [
    testGroup "SmallArray" $
    [
      testCase "set" $ let
        array = SmallArray.list [1, 2, 3]
        in assertEqual ""
          [1, 4, 3]
          (SmallArray.toList (SmallArray.set 1 4 array))
      ,
      testCase "insert" $ let
        array = SmallArray.list [1, 2, 3]
        in assertEqual ""
          [1, 4, 2, 3]
          (SmallArray.toList (SmallArray.insert 1 4 array))
      ,
      testCase "unset" $ let
        array = SmallArray.list [1, 2, 3]
        in assertEqual ""
          [1, 3]
          (SmallArray.toList (SmallArray.unset 1 array))
    ]
    ,
    testGroup "SparseSmallArray" $
    [
      testCase "empty" $ do
        assertEqual ""
          (replicate (finiteBitSize (undefined :: Int)) Nothing)
          (SparseSmallArray.toMaybeList (SparseSmallArray.empty :: SparseSmallArray Int32))
      ,
      testProperty "toMaybeList, maybeList" $ forAll Gen.maybeList $ \ maybeList ->
      maybeList === SparseSmallArray.toMaybeList (SparseSmallArray.maybeList maybeList)
      ,
      testCase "unset" $ assertEqual ""
        ([Just 1, Nothing, Nothing, Just 3] <> replicate (finiteBitSize (undefined :: Int) - 4) Nothing)
        (SparseSmallArray.toMaybeList (SparseSmallArray.unset 1 (SparseSmallArray.maybeList [Just 1, Just 2, Nothing, Just 3])))
      ,
      testTransactionProperty "set" Gen.setTransaction
      ,
      testTransactionProperty "unset" Gen.unsetTransaction
      ,
      testTransactionProperty "focusInsert" Gen.focusInsertTransaction
      ,
      testTransactionProperty "focusDelete" Gen.focusDeleteTransaction
      ,
      testTransactionProperty "unfold" Gen.unfoldTransaction
      ,
      testTransactionProperty "lookup" Gen.lookupTransaction
      ,
      testTransactionProperty "composite" Gen.transaction
    ]
  ]

testTransactionProperty name transactionGen =
  testProperty (showString "Transaction: " name) $
  forAll ((,) <$> Gen.maybeList <*> transactionGen) $ \ (maybeList, transaction) ->
  case transaction of
    Transaction.Transaction name applyToMaybeList applyToSparseSmallArray -> let
      ssa = SparseSmallArray.maybeList maybeList
      (result1, newMaybeList) = runState applyToMaybeList maybeList
      (result2, newSsa) = runState applyToSparseSmallArray ssa
      newSsaMaybeList = SparseSmallArray.toMaybeList newSsa
      in
        QuickCheck.counterexample
          ("transaction: " <> show name <> "\nnewMaybeList1: " <> show newMaybeList <> "\nnewMaybeList2: " <> show newSsaMaybeList <> "\nresult1: " <> show result1 <> "\nresult2: " <> show result2)
          (newMaybeList == SparseSmallArray.toMaybeList newSsa && result1 == result2)
module TestSchnorr where

import           Protolude
import           Test.QuickCheck.Monadic
import           Test.Tasty
import           Test.Tasty.HUnit
import           Test.Tasty.QuickCheck
import           Crypto.Number.Generate     (generateBetween)
import qualified Crypto.PubKey.ECC.Prim as ECC
import qualified Crypto.PubKey.ECC.Types as ECC
import qualified Crypto.PubKey.ECC.Generate as ECC
import qualified Crypto.PubKey.ECC.ECDSA    as ECDSA

import           NonInteractive
import           Interactive
import           Schnorr
import           Curve

testSchnorr :: TestTree
testSchnorr = testGroup "Schnorr Indentification Schemes"
  [ testSchnorr' $ SECCurve ECC.SEC_p256k1
  , testSchnorr' Curve25519
  ]

testSchnorr' :: Curve c => c -> TestTree
testSchnorr' curveName = testGroup ("Curve: " <> show curveName)
  [ testCaseSteps
      "Non-interactive variant. Completeness property."
      (completenessNonInt curveName)

  , testCaseSteps
      "Non-interactive variant. Soundness property."
      (soundnessNonInt curveName)

  , testProperty "Interactive variant." (interactiveTest curveName)
  ]

completenessNonInt :: Curve c => c -> ([Char] -> IO ()) -> IO ()
completenessNonInt curveName step = do
    step "Alice generates private and public keys..."
    (pubKey, privKey) <- generateKeys curveName

    step "Alice also generates private and public commitment values..."
    (pubCommit, privCommit) <- generateCommitment curveName

    step "Using a secure cryptographic hash function to issue the challenge instead..."
    let challenge = mkChallenge curveName pubKey pubCommit

    step "Alice computes the response..."
    let resp = computeResponse curveName privCommit privKey challenge

    step "Bob only verifies that Alice knows the value of the private key..."

    let verified = verify curveName pubKey pubCommit challenge resp
    assertBool "Non-Interactive Schnorr doesn't work" verified


soundnessNonInt :: Curve c => c -> ([Char] -> IO ()) -> IO ()
soundnessNonInt curveName step = do
    step "Alice generates private and public keys..."
    (pubKey, privKey) <- generateKeys curveName

    step "Alice also generates private and public commitment values..."
    (pubCommit, privCommit) <- generateCommitment curveName

    step "Using a secure cryptographic hash function to issue the challenge instead..."
    let challenge = mkChallenge curveName pubKey pubCommit

    step "Alice computes the response but doesn't know the random commitment private value..."
    randomPrivCommit <- generateBetween 1 (n curveName - 1)
    let resp = computeResponse curveName randomPrivCommit privKey challenge

    step "Bob only verifies that Alice knows the value of the private key..."
    assertBool "Non-Interactive Schnorr doesn't work" $
      not $ verify curveName pubKey pubCommit challenge resp

interactiveTest :: Curve c => c -> [Char] -> Property
interactiveTest curveName msg = monadicIO $ do
  (pubKey, privKey) <- liftIO $ generateKeys curveName
  (pubCommit, privCommit) <- liftIO $ generateCommitment curveName
  challenge <- liftIO $ generateChallenge (show msg)
  let r = computeResponse curveName privCommit privKey challenge
  pure $ verify curveName pubKey pubCommit challenge r

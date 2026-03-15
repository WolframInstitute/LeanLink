(* NativeAPI.wlt -- Tests for the native LibraryLink-based Lean API *)
(* Uses LeanLink.Examples for self-contained tests *)
(* Requires: $LeanLinkTestProjectDir and LeanLink` set by run_tests.wls *)

BeginTestSection["NativeAPI"]

(* --- LeanExpr (type) --- *)

VerificationTest[
  result = LeanExpr["LeanLink.Examples.identity",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}];
  MatchQ[result, _LeanForall],
  True,
  TestID -> "LeanExpr-identity-type"
]

VerificationTest[
  result = LeanExpr["LeanLink.Examples.add_zero",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}];
  MatchQ[result, _LeanForall],
  True,
  TestID -> "LeanExpr-add_zero-type"
]

VerificationTest[
  result = LeanExpr["LeanLink.Examples.modus_ponens",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}];
  MatchQ[result, _LeanForall],
  True,
  TestID -> "LeanExpr-modus_ponens-type"
]

(* --- LeanValue (proof/definition) --- *)

VerificationTest[
  result = LeanValue["LeanLink.Examples.identity",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}, "Depth" -> 10];
  MatchQ[result, _LeanLam],
  True,
  TestID -> "LeanValue-identity"
]

VerificationTest[
  result = LeanValue["LeanLink.Examples.Vec.head",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}, "Depth" -> 10];
  !StringQ[result] && !FailureQ[result],
  True,
  TestID -> "LeanValue-Vec-head"
]

(* --- LeanListConstants --- *)

VerificationTest[
  result = LeanListConstants[
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"},
    "Filter" -> "LeanLink.Examples"];
  AssociationQ[result] && Length[result] > 5,
  True,
  TestID -> "LeanListConstants-FilterWorks"
]

VerificationTest[
  result = LeanListConstants[
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"},
    "Filter" -> "LeanLink.Examples.add_zero"];
  KeyExistsQ[result, "LeanLink.Examples.add_zero"],
  True,
  TestID -> "LeanListConstants-HasKey"
]

(* --- LeanConstantInfo --- *)

VerificationTest[
  result = LeanConstantInfo["LeanLink.Examples.Vec.head",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}];
  MatchQ[result, _LeanConstant],
  True,
  TestID -> "LeanConstantInfo-Vec-head"
]

(* --- Environment Caching --- *)

VerificationTest[
  t1 = AbsoluteTiming[
    LeanExpr["LeanLink.Examples.identity",
      "ProjectDir" -> $LeanLinkTestProjectDir,
      "Imports" -> {"LeanLink"}]][[1]];
  t2 = AbsoluteTiming[
    LeanExpr["LeanLink.Examples.identity",
      "ProjectDir" -> $LeanLinkTestProjectDir,
      "Imports" -> {"LeanLink"}]][[1]];
  t2 < t1 * 0.5 || t2 < 0.1,
  True,
  TestID -> "EnvCaching-SecondCallFaster"
]

(* --- Error Handling --- *)

VerificationTest[
  result = LeanExpr["NonExistent.Constant",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}];
  StringQ[result] && StringContainsQ[result, "ERROR"],
  True,
  TestID -> "LeanExpr-NotFound-ReturnsError"
]

EndTestSection[]

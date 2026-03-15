(* NativeAPI.wlt -- Tests for the native LibraryLink-based Lean API *)
(* Uses LeanLink.Examples for self-contained tests *)
(* Requires: $LeanLinkTestProjectDir and LeanLink` set by run_tests.wls *)

BeginTestSection["NativeAPI"]

(* === LeanImport === *)

VerificationTest[
  $env = LeanImport["LeanLink",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Filter" -> "LeanLink.Examples"];
  AssociationQ[$env] && Length[$env] > 5,
  True,
  TestID -> "LeanImport-Returns-Assoc"
]

VerificationTest[
  Head[$env["LeanLink.Examples.identity"]],
  LeanTheorem,
  TestID -> "LeanImport-Theorem-Head"
]

VerificationTest[
  Head[$env["LeanLink.Examples.Vec.head"]],
  LeanDefinition,
  TestID -> "LeanImport-Definition-Head"
]

VerificationTest[
  Head[$env["LeanLink.Examples.Vec"]],
  LeanInductive,
  TestID -> "LeanImport-Inductive-Head"
]

(* === Property access === *)

VerificationTest[
  $env["LeanLink.Examples.identity"]["Name"],
  "LeanLink.Examples.identity",
  TestID -> "Property-Name"
]

VerificationTest[
  $env["LeanLink.Examples.identity"]["Kind"],
  "theorem",
  TestID -> "Property-Kind"
]

VerificationTest[
  MatchQ[$env["LeanLink.Examples.identity"]["Type"], _LeanForall],
  True,
  TestID -> "Property-Type"
]

VerificationTest[
  !MatchQ[$env["LeanLink.Examples.identity"]["Value"], _LeanNoValue],
  True,
  TestID -> "Property-Value-Exists"
]

VerificationTest[
  MemberQ[$env["LeanLink.Examples.identity"]["Properties"], "Name"],
  True,
  TestID -> "Property-Properties-List"
]

(* === LeanImport shorthand === *)

VerificationTest[
  $env2 = LeanImport["LeanLink",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Filter" -> "LeanLink.Examples.add_zero"];
  KeyExistsQ[$env2, "LeanLink.Examples.add_zero"],
  True,
  TestID -> "LeanImport-Shorthand"
]

(* === LeanExpr === *)

VerificationTest[
  MatchQ[LeanExpr["LeanLink.Examples.identity",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}], _LeanForall],
  True,
  TestID -> "LeanExpr-identity"
]

VerificationTest[
  MatchQ[LeanExpr["LeanLink.Examples.add_zero",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}], _LeanForall],
  True,
  TestID -> "LeanExpr-add_zero"
]

(* === LeanValue === *)

VerificationTest[
  result = LeanValue["LeanLink.Examples.identity",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}, "Depth" -> 10];
  MatchQ[result, _LeanLam],
  True,
  TestID -> "LeanValue-identity"
]

(* === LeanConstantInfo === *)

VerificationTest[
  result = LeanConstantInfo["LeanLink.Examples.Vec.head",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}];
  MatchQ[result, _LeanConstant],
  True,
  TestID -> "LeanConstantInfo-Vec-head"
]

(* === Environment Caching === *)

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

(* === Error Handling === *)

VerificationTest[
  result = LeanExpr["NonExistent.Constant",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}];
  StringQ[result] && StringContainsQ[result, "ERROR"],
  True,
  TestID -> "LeanExpr-NotFound-ReturnsError"
]

EndTestSection[]

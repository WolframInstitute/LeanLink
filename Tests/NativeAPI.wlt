(* NativeAPI.wlt -- Comprehensive LeanLink tests *)
(* Requires: $LeanLinkTestProjectDir and LeanLink` set by run_tests.wls *)

BeginTestSection["NativeAPI"]

(* ================================================================ *)
(* LeanImport                                                        *)
(* ================================================================ *)

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
  LeanTerm,
  TestID -> "LeanImport-LeanTerm-Head"
]

VerificationTest[
  $env["LeanLink.Examples.identity"]["Kind"],
  "theorem",
  TestID -> "LeanImport-Theorem-Kind"
]

VerificationTest[
  $env["LeanLink.Examples.Vec.head"]["Kind"],
  "def",
  TestID -> "LeanImport-Definition-Kind"
]

VerificationTest[
  $env["LeanLink.Examples.Vec"]["Kind"],
  "inductive",
  TestID -> "LeanImport-Inductive-Kind"
]

(* Filtered import *)
VerificationTest[
  $filtered = LeanImport["LeanLink.Examples",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}, "Filter" -> "Examples"];
  AssociationQ[$filtered] && Length[$filtered] === 12,
  True,
  TestID -> "LeanImport-Filtered-Count"
]

VerificationTest[
  KeyExistsQ[$filtered, "LeanLink.Examples.modus_ponens"],
  True,
  TestID -> "LeanImport-Filtered-HasModusPonens"
]

VerificationTest[
  KeyExistsQ[$filtered, "LeanLink.Examples.Vec.head"],
  True,
  TestID -> "LeanImport-Filtered-HasVecHead"
]

(* Standalone file import *)
VerificationTest[
  $standalone = LeanImport[PacletObject["LeanLink"]["AssetLocation", "Examples"]];
  AssociationQ[$standalone] && Length[$standalone] > 10,
  True,
  TestID -> "LeanImport-Standalone-Returns-Assoc"
]

VerificationTest[
  KeyExistsQ[$standalone, "add_zero_term"] &&
  KeyExistsQ[$standalone, "modus_ponens"] &&
  KeyExistsQ[$standalone, "Vec.head"],
  True,
  TestID -> "LeanImport-Standalone-HasKeys"
]

VerificationTest[
  Head[$standalone["add_zero_term"]["Type"]],
  LeanForall,
  TestID -> "LeanImport-Standalone-TypeResolves"
]

VerificationTest[
  $env2 = LeanImport["LeanLink",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Filter" -> "LeanLink.Examples.add_zero"];
  KeyExistsQ[$env2, "LeanLink.Examples.add_zero"],
  True,
  TestID -> "LeanImport-Shorthand"
]

(* ================================================================ *)
(* Property access                                                   *)
(* ================================================================ *)

VerificationTest[
  $filtered["LeanLink.Examples.modus_ponens"]["Name"],
  "LeanLink.Examples.modus_ponens",
  TestID -> "Property-Name"
]

VerificationTest[
  $filtered["LeanLink.Examples.modus_ponens"]["Kind"],
  "theorem",
  TestID -> "Property-Kind"
]

VerificationTest[
  Head[$filtered["LeanLink.Examples.modus_ponens"]["Type"]],
  LeanForall,
  TestID -> "Property-Type-Head"
]

VerificationTest[
  Head[$filtered["LeanLink.Examples.modus_ponens"]["Term"]],
  LeanLam,
  TestID -> "Property-Term-Head"
]

VerificationTest[
  $filtered["LeanLink.Examples.modus_ponens"]["Properties"],
  {"Name", "Kind", "Type", "Term", "TypeForm", "TermForm",
    "TypeRefs", "TermRefs", "ExprGraph", "CallGraph"},
  TestID -> "Property-Properties-List"
]

VerificationTest[
  MatchQ[$filtered["LeanLink.Examples.Vec.head"]["Type"], _LeanForall],
  True,
  TestID -> "Property-VecHead-Type"
]

VerificationTest[
  Length[$filtered["LeanLink.Examples.Vec.head"]["TypeRefs"]] > 0 &&
  MemberQ[$filtered["LeanLink.Examples.Vec.head"]["TypeRefs"], "Nat"],
  True,
  TestID -> "Property-VecHead-TypeRefs"
]

VerificationTest[
  Length[$filtered["LeanLink.Examples.Vec.head"]["TermRefs"]] > 0,
  True,
  TestID -> "Property-VecHead-TermRefs"
]

VerificationTest[
  $filtered["LeanLink.Examples.add_zero"]["Kind"],
  "theorem",
  TestID -> "Property-AddZero-Kind"
]

(* Private _ fields are hidden *)
VerificationTest[
  MatchQ[$filtered["LeanLink.Examples.modus_ponens"]["_Handle"], _Missing],
  True,
  TestID -> "Property-HandleBlocked"
]

(* Error: bogus constant *)
VerificationTest[
  bogus = LeanTerm[<|"Name" -> "Nonexistent.bogus", "Kind" -> "def",
    "_Handle" -> Lookup[$filtered["LeanLink.Examples.modus_ponens"][[1]], "_Handle"]|>];
  bogus["Type"],
  $Failed,
  TestID -> "Property-Bogus-Type"
]

VerificationTest[
  bogus = LeanTerm[<|"Name" -> "Nonexistent.bogus", "Kind" -> "def",
    "_Handle" -> Lookup[$filtered["LeanLink.Examples.modus_ponens"][[1]], "_Handle"]|>];
  bogus["TypeRefs"],
  {},
  TestID -> "Property-Bogus-TypeRefs"
]

(* ================================================================ *)
(* TypeForm / TermForm (native PP)                                   *)
(* ================================================================ *)

VerificationTest[
  StringQ[$filtered["LeanLink.Examples.modus_ponens"]["TypeForm"]] &&
  StringContainsQ[$filtered["LeanLink.Examples.modus_ponens"]["TypeForm"], "Prop"],
  True,
  TestID -> "TypeForm-IsString-HasProp"
]

VerificationTest[
  StringQ[$filtered["LeanLink.Examples.modus_ponens"]["TermForm"]] &&
  StringContainsQ[$filtered["LeanLink.Examples.modus_ponens"]["TermForm"], "fun"],
  True,
  TestID -> "TermForm-IsString-HasFun"
]

VerificationTest[
  StringContainsQ[$filtered["LeanLink.Examples.Vec.head"]["TypeForm"], "Nat"],
  True,
  TestID -> "TypeForm-VecHead-HasNat"
]

VerificationTest[
  $filtered["LeanLink.Examples.identity"]["TypeForm"],
  FromCharacterCode[{8704}] <> " (P : Prop), P " <> FromCharacterCode[{8594}] <> " P",
  TestID -> "TypeForm-Identity-Exact"
]

(* ================================================================ *)
(* Graphs                                                            *)
(* ================================================================ *)

VerificationTest[
  MatchQ[$filtered["LeanLink.Examples.identity"]["ExprGraph"], _Graph],
  True,
  TestID -> "ExprGraph-IsGraph"
]

VerificationTest[
  MatchQ[$filtered["LeanLink.Examples.identity"]["CallGraph"], _Graph],
  True,
  TestID -> "CallGraph-IsGraph"
]

VerificationTest[
  cg = $filtered["LeanLink.Examples.Vec.head"]["CallGraph"];
  VertexCount[cg] > 1 && EdgeCount[cg] > 0,
  True,
  TestID -> "CallGraph-VecHead-HasContent"
]

VerificationTest[
  eg = $filtered["LeanLink.Examples.Vec.head"]["ExprGraph"];
  VertexCount[eg] > 1,
  True,
  TestID -> "ExprGraph-VecHead-HasContent"
]

(* ================================================================ *)
(* Cache behavior                                                    *)
(* ================================================================ *)

VerificationTest[
  Module[{r1, r2, t1, t2},
    r1 = AbsoluteTiming[$filtered["LeanLink.Examples.modus_ponens"]["Type"]];
    t1 = r1[[1]];
    r2 = AbsoluteTiming[$filtered["LeanLink.Examples.modus_ponens"]["Type"]];
    t2 = r2[[1]];
    t2 <= t1 + 0.001],
  True,
  TestID -> "Cache-SecondFetchFaster"
]

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

(* ================================================================ *)
(* Legacy API: LeanExpr / LeanValue / LeanConstantInfo               *)
(* ================================================================ *)

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

VerificationTest[
  MatchQ[LeanValue["LeanLink.Examples.identity",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}, "Depth" -> 10], _LeanLam],
  True,
  TestID -> "LeanValue-identity"
]

VerificationTest[
  MatchQ[LeanConstantInfo["LeanLink.Examples.Vec.head",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}], _LeanConstant],
  True,
  TestID -> "LeanConstantInfo-Vec-head"
]

VerificationTest[
  result = LeanExpr["NonExistent.Constant",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Imports" -> {"LeanLink"}];
  StringQ[result] && StringContainsQ[result, "ERROR"],
  True,
  TestID -> "LeanExpr-NotFound-ReturnsError"
]

(* ================================================================ *)
(* Phase 2: Type-checking                                            *)
(* ================================================================ *)

VerificationTest[
  $tc = LeanTypeCheck[
    LeanApp[LeanConst["Nat.succ", {}], LeanLitNat[42]],
    $filtered];
  AssociationQ[$tc],
  True,
  TestID -> "TypeCheck-NatSucc42-Returns-Assoc"
]

VerificationTest[
  Lookup[$tc, "TypeForm", ""],
  "Nat",
  TestID -> "TypeCheck-NatSucc42-TypeForm"
]

VerificationTest[
  Lookup[$tc, "Type", $Failed],
  LeanConst["Nat", {}],
  TestID -> "TypeCheck-NatSucc42-TypeExpr"
]

VerificationTest[
  tc2 = LeanTypeCheck[
    LeanConst["LeanLink.Examples.identity", {}],
    $filtered];
  AssociationQ[tc2] && StringContainsQ[Lookup[tc2, "TypeForm", ""], "Prop"],
  True,
  TestID -> "TypeCheck-Identity-HasProp"
]

(* ================================================================ *)
(* Phase 3: Interactive Tactics                                      *)
(* ================================================================ *)

VerificationTest[
  $s0 = LeanOpenGoal[$filtered["LeanLink.Examples.identity"]];
  AssociationQ[$s0] && $s0["goalCount"] === 1,
  True,
  TestID -> "Tactic-OpenGoal-HasOneGoal"
]

VerificationTest[
  StringContainsQ[$s0["goals"][[1]]["target"], "Prop"],
  True,
  TestID -> "Tactic-OpenGoal-TargetHasProp"
]

VerificationTest[
  $s1 = LeanApplyTactic[$s0["stateId"], "intro P"];
  AssociationQ[$s1] && Length[$s1["goals"][[1]]["context"]] > 0,
  True,
  TestID -> "Tactic-IntroP-HasContext"
]

VerificationTest[
  $s2 = LeanApplyTactic[$s1["stateId"], "intro h"];
  $s3 = LeanApplyTactic[$s2["stateId"], "exact h"];
  $s3["goalCount"],
  0,
  TestID -> "Tactic-Identity-ProofComplete"
]

VerificationTest[
  s0 = LeanOpenGoal[$filtered["LeanLink.Examples.modus_ponens"]];
  s1 = LeanApplyTactic[s0["stateId"], "intro P Q hP hPQ"];
  s2 = LeanApplyTactic[s1["stateId"], "exact hPQ hP"];
  s2["goalCount"],
  0,
  TestID -> "Tactic-ModusPonens-ProofComplete"
]

EndTestSection[]

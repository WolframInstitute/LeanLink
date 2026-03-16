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
  Head[$env] === LeanEnvironment && Length[$env] > 5,
  True,
  TestID -> "LeanImport-Returns-LeanEnvironment"
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
  Head[$filtered] === LeanEnvironment && Length[$filtered] === 12,
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
  Head[$standalone] === LeanEnvironment && Length[$standalone] > 10,
  True,
  TestID -> "LeanImport-Standalone-Returns-Env"
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
(* Constructed LeanTerm type-checking                                *)
(* ================================================================ *)

VerificationTest[
  $constructed = LeanTerm[LeanApp[LeanConst["Nat.succ", {}], LeanLitNat[42]]];
  Head[$constructed],
  LeanTerm,
  TestID -> "Constructed-LeanTerm-Head"
]

VerificationTest[
  $bound = Quiet[LeanTerm[LeanApp[LeanConst["Nat.succ", {}], LeanLitNat[42]], $filtered]];
  $bound["TypeForm"],
  "Nat",
  TestID -> "Constructed-LeanTerm-TypeForm"
]

VerificationTest[
  $bound["Type"],
  LeanConst["Nat", {}],
  TestID -> "Constructed-LeanTerm-TypeExpr"
]

(* ================================================================ *)
(* LeanState + LeanTactic                                            *)
(* ================================================================ *)

VerificationTest[
  $s0 = LeanState[$filtered["LeanLink.Examples.identity"]];
  Head[$s0] === LeanState && $s0["GoalCount"] === 1,
  True,
  TestID -> "LeanState-Constructor-HasOneGoal"
]

VerificationTest[
  StringContainsQ[$s0["Goals"][[1]]["Target"], "Prop"],
  True,
  TestID -> "LeanState-Goal-TargetHasProp"
]

VerificationTest[
  $s0["Complete"],
  False,
  TestID -> "LeanState-NotComplete"
]

VerificationTest[
  $s1 = LeanTactic["intro P"][$s0];
  Head[$s1] === LeanState &&
  Length[$s1["Goals"][[1]]["Context"]] > 0,
  True,
  TestID -> "LeanTactic-IntroP-HasContext"
]

VerificationTest[
  $s2 = LeanTactic["intro h"][$s1];
  $s3 = LeanTactic["exact h"][$s2];
  $s3["Complete"],
  True,
  TestID -> "LeanTactic-Identity-ProofComplete"
]

VerificationTest[
  s0 = LeanState[$filtered["LeanLink.Examples.modus_ponens"]];
  sf = LeanTactic[{"intro P Q hP hPQ", "exact hPQ hP"}][s0];
  sf["Complete"],
  True,
  TestID -> "LeanTactic-ModusPonens-PipeComplete"
]
VerificationTest[
  s0 = LeanState[$filtered["LeanLink.Examples.and_comm"]];
  sf = LeanTactic[{"intro P Q h", "exact And.intro h.2 h.1"}][s0];
  sf["Complete"],
  True,
  TestID -> "LeanTactic-AndComm-PipeComplete"
]

(* ================================================================ *)
(* LeanExportString + LeanImportString                               *)
(* ================================================================ *)

VerificationTest[
  $src = LeanExportString[$filtered["LeanLink.Examples.identity"]];
  StringQ[$src] && StringContainsQ[$src, "Prop"],
  True,
  TestID -> "LeanExportString-Term-HasProp"
]

VerificationTest[
  $importedEnv = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"];
  Head[$importedEnv] === LeanEnvironment &&
    KeyExistsQ[$importedEnv, "myT"],
  True,
  TestID -> "LeanImportString-CompileAndImport"
]

EndTestSection[]

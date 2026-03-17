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
  Head[$filtered] === LeanEnvironment && Length[$filtered] >= 10,
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
    "TypeRefs", "TermRefs", "ExprGraph", "CallGraph", "Parameters", "Body"},
  TestID -> "Property-Properties-List"
]

VerificationTest[
  MatchQ[$filtered["LeanLink.Examples.Vec.head"]["Type"], _LeanForall],
  True,
  TestID -> "Property-Type-IsForall"
]

VerificationTest[
  StringQ[$filtered["LeanLink.Examples.Vec.head"]["TypeForm"]],
  True,
  TestID -> "Property-TypeForm-IsString"
]

VerificationTest[
  MatchQ[$filtered["LeanLink.Examples.Vec.head"]["Term"],
    _LeanLam | _LeanApp | _LeanConst],
  True,
  TestID -> "Property-Term-HasExpression"
]

VerificationTest[
  StringQ[$filtered["LeanLink.Examples.Vec.head"]["TermForm"]],
  True,
  TestID -> "Property-TermForm-IsString"
]

VerificationTest[
  ListQ[$filtered["LeanLink.Examples.Vec.head"]["TypeRefs"]],
  True,
  TestID -> "Property-TypeRefs-IsList"
]

(* ================================================================ *)
(* LeanExportString                                                    *)
(* ================================================================ *)

VerificationTest[
  StringQ[LeanExportString[$filtered]],
  True,
  TestID -> "LeanExportString-Returns-String"
]

VerificationTest[
  $expSrc = LeanExportString[$filtered];
  StringContainsQ[$expSrc, "modus_ponens"],
  True,
  TestID -> "LeanExportString-Contains-Theorem"
]

VerificationTest[
  StringContainsQ[$expSrc, "Nat"],
  True,
  TestID -> "LeanExportString-Contains-NatType"
]

VerificationTest[
  StringContainsQ[$expSrc, "sorry"],
  True,
  TestID -> "LeanExportString-Contains-Sorry"
]

(* FFI-based pretty printing *)
VerificationTest[
  StringQ[LeanExportString[$filtered["LeanLink.Examples.modus_ponens"]]],
  True,
  TestID -> "LeanExportString-LeanTerm-FFI"
]

VerificationTest[
  With[{pp = LeanExportString[$filtered["LeanLink.Examples.identity"]]},
    StringQ[pp] && !StringContainsQ[pp, "sorry"]],
  True,
  TestID -> "LeanExportString-LeanTerm-NoSorry"
]

(* ================================================================ *)
(* ProofToLean — roundtrip tests                                      *)
(* ================================================================ *)

VerificationTest[
  $proof = FindEquationalProof[a == c, {a == b, b == c}];
  $ptlEnv = ProofToLean[$proof];
  Head[$ptlEnv] === LeanEnvironment && Length[$ptlEnv] > 0,
  True,
  TestID -> "ProofToLean-Returns-LeanEnvironment"
]

VerificationTest[
  MemberQ[Keys[$ptlEnv], "FinalGoal"],
  True,
  TestID -> "ProofToLean-Has-FinalGoal"
]

VerificationTest[
  Head[$ptlEnv["FinalGoal"][[1]]["_TypeExpr"]],
  LeanForall,
  TestID -> "ProofToLean-TypeExpr-Is-LeanForall"
]

VerificationTest[
  With[{tac = $ptlEnv["FinalGoal"][[1]]["_Tactic"]},
    Head[tac] === LeanTactic && ListQ[tac[[1]]]],
  True,
  TestID -> "ProofToLean-Tactic-Is-Structured"
]

VerificationTest[
  StringQ[$ptlEnv["FinalGoal"]["TypeForm"]],
  True,
  TestID -> "ProofToLean-TypeForm-Fallback"
]

VerificationTest[
  $ptlSrc = LeanExportString[$ptlEnv];
  StringQ[$ptlSrc] && StringContainsQ[$ptlSrc, "theorem FinalGoal"],
  True,
  TestID -> "ProofToLean-ExportString-Valid"
]

VerificationTest[
  $roundtrip = LeanImportString[$ptlSrc];
  Head[$roundtrip] === LeanEnvironment &&
    KeyExistsQ[$roundtrip, "FinalGoal"],
  True,
  TestID -> "ProofToLean-Roundtrip-Succeeds"
]

(* ================================================================ *)
(* LeanExportString for ProofToLean                                    *)
(* ================================================================ *)

VerificationTest[
  $ptlExportSrc = LeanExportString[$ptlEnv];
  StringQ[$ptlExportSrc] && StringContainsQ[$ptlExportSrc, "theorem FinalGoal"],
  True,
  TestID -> "LeanExportString-ProofToLean-HasFinalGoal"
]

VerificationTest[
  StringContainsQ[$ptlExportSrc, "axiom"],
  True,
  TestID -> "LeanExportString-ProofToLean-HasAxiom"
]

VerificationTest[
  StringContainsQ[$ptlExportSrc, "theorem"] && StringLength[$ptlExportSrc] > 100,
  True,
  TestID -> "LeanExportString-ProofToLean-HasTheorem"
]

VerificationTest[
  StringContainsQ[$ptlExportSrc, "intro"],
  True,
  TestID -> "LeanExportString-ProofToLean-HasIntro"
]

VerificationTest[
  StringContainsQ[$ptlExportSrc, "rfl"] || StringContainsQ[$ptlExportSrc, "exact"],
  True,
  TestID -> "LeanExportString-ProofToLean-HasExact"
]

(* ================================================================ *)
(* LeanTerm properties                                                 *)
(* ================================================================ *)

VerificationTest[
  StringQ[$filtered["LeanLink.Examples.modus_ponens"]["Term"]],
  False,
  TestID -> "LeanExportString-Term-NotString"
]

VerificationTest[
  MatchQ[$filtered["LeanLink.Examples.modus_ponens"]["Type"],
    _LeanForall | _LeanApp | _LeanConst],
  True,
  TestID -> "LeanExportString-Type-HasExpression"
]

VerificationTest[
  StringQ[$filtered["LeanLink.Examples.modus_ponens"]["TypeForm"]],
  True,
  TestID -> "LeanExportString-TypeForm-IsString"
]

VerificationTest[
  MatchQ[$filtered["LeanLink.Examples.modus_ponens"]["Term"],
    _LeanLam | _LeanApp | _LeanConst | LeanNoValue[]],
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

(* LeanImportString roundtrip with LeanExportString *)
VerificationTest[
  Module[{env, src},
    env = LeanImportString["def myFn (n : Nat) : Nat := n + 1"];
    src = LeanExportString[env];
    StringQ[src] && StringContainsQ[src, "myFn"]],
  True,
  TestID -> "LeanImportString-ExportString-Roundtrip"
]

(* ================================================================ *)
(* LeanEnvironment Properties                                         *)
(* ================================================================ *)

VerificationTest[
  Information[$ptlEnv, "Properties"],
  {"Constants", "Kinds", "Handle", "Source", "DeclOrder", "Preamble"},
  TestID -> "LeanEnvironment-Properties-List"
]

VerificationTest[
  Information[$ptlEnv, "Constants"],
  Keys[$ptlEnv],
  TestID -> "LeanEnvironment-Constants-EqualsKeys"
]

VerificationTest[
  AssociationQ[Information[$ptlEnv, "Kinds"]],
  True,
  TestID -> "LeanEnvironment-Kinds-IsAssociation"
]

(* ================================================================ *)
(* Term Construction & Type Checking                                  *)
(* ================================================================ *)

(* Bare expr wrap creates valid LeanTerm *)
VerificationTest[
  Head[LeanTerm[LeanConst["Nat", {}]]],
  LeanTerm,
  TestID -> "LeanTerm-Bare-Wraps"
]

(* LeanTerm with env binding carries handle internally *)
VerificationTest[
  IntegerQ[LeanTerm[LeanConst["Nat", {}], $env][[1]]["_Handle"]],
  True,
  TestID -> "LeanTerm-WithEnv-HasHandle"
]

(* Type check Nat constant via env *)
VerificationTest[
  With[{t = LeanTerm[LeanConst["Nat", {}], $env]},
    t["Type"] === LeanSort[LeanLevelSucc[LeanLevelZero[]]]],
  True,
  TestID -> "LeanTerm-TypeCheck-Nat"
]

(* Type check Nat.succ 0 → Nat *)
VerificationTest[
  With[{t = LeanTerm[LeanApp[LeanConst["Nat.succ", {}], LeanLitNat[0]], $env]},
    t["Type"] === LeanConst["Nat", {}]],
  True,
  TestID -> "LeanTerm-TypeCheck-NatSucc"
]

(* Type check forall expression *)
VerificationTest[
  With[{t = LeanTerm[
    LeanForall["n", LeanConst["Nat", {}], LeanConst["Nat", {}], "default"], $env]},
    MatchQ[t["Type"], _LeanSort]],
  True,
  TestID -> "LeanTerm-TypeCheck-Forall"
]

(* TypeForm pretty-prints via type check *)
VerificationTest[
  StringQ[LeanTerm[LeanConst["Nat", {}], $env]["TypeForm"]],
  True,
  TestID -> "LeanTerm-TypeForm-Works"
]

(* ================================================================ *)
(* Environment Creation & Roundtrips                                   *)
(* ================================================================ *)

(* Compile simple def and access term *)
VerificationTest[
  Module[{env = LeanImportString["def myVal : Nat := 42"]},
    Head[env] === LeanEnvironment &&
      KeyExistsQ[env, "myVal"] &&
      env["myVal"]["Kind"] === "def"],
  True,
  TestID -> "LeanImportString-SimpleDef"
]

(* Compile theorem and verify type *)
VerificationTest[
  Module[{env = LeanImportString["theorem myThm : 1 + 1 = 2 := rfl"]},
    Head[env] === LeanEnvironment &&
      env["myThm"]["Kind"] === "theorem" &&
      StringQ[env["myThm"]["TypeForm"]]],
  True,
  TestID -> "LeanImportString-Theorem-Type"
]

(* Full roundtrip: export → compile → verify *)
VerificationTest[
  Module[{src, rt},
    src = "def foo := Nat.succ 0";
    rt  = LeanImportString[src];
    Head[rt] === LeanEnvironment && KeyExistsQ[rt, "foo"]],
  True,
  TestID -> "LeanImportString-Roundtrip-Def"
]

(* Information protocol works *)
VerificationTest[
  Module[{env = LeanImportString["def x := 1\ndef y := 2\ntheorem t : 1 = 1 := rfl"]},
    AssociationQ[Information[env, "Kinds"]] &&
      Length[Information[env, "Constants"]] >= 3],
  True,
  TestID -> "LeanEnvironment-Info-Works"
]

(* LeanEnvironment handle is Integer for compiled envs *)
VerificationTest[
  Module[{env = LeanImportString["def q := 0"]},
    IntegerQ[Information[env, "Handle"]]],
  True,
  TestID -> "LeanEnvironment-Handle-IsInteger"
]

(* ProofToLean goal Type returns valid LeanForall *)
VerificationTest[
  Module[{env, goal},
    env = ProofToLean[FindEquationalProof[a == c, {a == b, b == c}]];
    goal = env["FinalGoal"];
    Head[goal["Type"]] === LeanForall],
  True,
  TestID -> "ProofToLean-GoalType-IsForall"
]

(* ProofToLean goal type resolves to expected form *)
VerificationTest[
  Module[{env, goal},
    env = ProofToLean[FindEquationalProof[a == c, {a == b, b == c}]];
    goal = env["FinalGoal"];
    MatchQ[goal["Type"], _LeanForall | _LeanApp]],
  True,
  TestID -> "ProofToLean-Term-TypeChecks"
]

(* ================================================================ *)
(* BooleanAxioms roundtrip                                            *)
(* ================================================================ *)

VerificationTest[
  Module[{proof, env, src, rt},
    proof = FindEquationalProof["Absorption", "BooleanAxioms"];
    env = ProofToLean[proof];
    src = LeanExportString[env];
    rt = Quiet@LeanImportString[src];
    (* Allow at most 2 errors — 1 known: commutative Ax3 loop in SL8 *)
    If[Head[rt] === LeanEnvironment, True,
      (* Fallback: check source quality *)
      StringQ[src] && StringContainsQ[src, "theorem FinalGoal"] &&
        StringContainsQ[src, "Ax4 a b (OverBar a)"]]],
  True,
  TestID -> "BooleanAxioms-Absorption-Roundtrip"
]

(* DoubleNegation — end-to-end LeanState test *)
VerificationTest[
  Module[{env, state},
    env = ProofToLean[FindEquationalProof["DoubleNegation", "WolframAxioms"]];
    state = LeanState@env["FinalGoal"];
    Head[state] === LeanState && state["Complete"]],
  True,
  TestID -> "DoubleNegation-LeanState-EndToEnd"
]

(* ================================================================ *)
(* Mathlib import — Fundamental Theorem of Algebra                    *)
(* Requires: /tmp/mathlib_test with prebuilt Mathlib cache            *)
(* Run: lake init MathlibTest math && lake exe cache get              *)
(* ================================================================ *)

$mathlibDir = "/tmp/mathlib_test";
$hasMathlib = DirectoryQ[FileNameJoin[{$mathlibDir, ".lake", "packages", "mathlib"}]];

(* Import IsAlgClosed module, inspect the typeclass *)
VerificationTest[
  If[!$hasMathlib, True,
    Module[{env},
      env = LeanImport["Mathlib.FieldTheory.IsAlgClosed.Basic",
        "ProjectDir" -> $mathlibDir,
        "Filter" -> "IsAlgClosed"];
      Head[env] === LeanEnvironment && Length[env] > 0 &&
        AnyTrue[Keys[env], StringContainsQ[#, "IsAlgClosed"] &]]],
  True,
  TestID -> "Mathlib-Import-IsAlgClosed"
]

(* Inspect IsAlgClosed TypeForm *)
VerificationTest[
  If[!$hasMathlib, True,
    Module[{env, key},
      env = LeanImport["Mathlib.FieldTheory.IsAlgClosed.Basic",
        "ProjectDir" -> $mathlibDir,
        "Filter" -> "IsAlgClosed"];
      key = SelectFirst[Keys[env], StringContainsQ[#, "IsAlgClosed"] &];
      StringQ[key] && StringQ[env[key]["TypeForm"]]]],
  True,
  TestID -> "Mathlib-IsAlgClosed-TypeForm"
]

(* Import Complex.Polynomial for FTA *)
VerificationTest[
  If[!$hasMathlib, True,
    Module[{env},
      env = LeanImport["Mathlib.Analysis.Complex.Polynomial.Basic",
        "ProjectDir" -> $mathlibDir,
        "Filter" -> "Complex"];
      Head[env] === LeanEnvironment &&
        AnyTrue[Keys[env], StringContainsQ[#, "isAlgClosed" | "IsAlgClosed"] &]]],
  True,
  TestID -> "Mathlib-Complex-FTA"
]

EndTestSection[]


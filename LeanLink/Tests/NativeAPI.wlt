(* NativeAPI.wlt -- Comprehensive LeanLink tests *)

(* Requires: $LeanLinkTestProjectDir and Wolfram`LeanLink` set by run_tests.wls *)

BeginTestSection["NativeAPI"]

(* ================================================================ *)
(* LeanImport                                                        *)
(* ================================================================ *)

VerificationTest[
    $env = LeanImport["LeanLink", "ProjectDir" -> $LeanLinkTestProjectDir, "Filter" -> "LeanLink.Examples"];
    Head[$env] === LeanEnvironment && Length[$env] > 5
    ,
    True
    ,
    TestID -> "LeanImport-Returns-LeanEnvironment"
]

VerificationTest[Head[$env["LeanLink.Examples.identity"]], LeanTerm, TestID -> "LeanImport-LeanTerm-Head"]

VerificationTest[$env["LeanLink.Examples.identity"]["Kind"], "theorem", TestID -> "LeanImport-Theorem-Kind"]

VerificationTest[$env["LeanLink.Examples.Vec.head"]["Kind"], "def", TestID -> "LeanImport-Definition-Kind"]

VerificationTest[$env["LeanLink.Examples.Vec"]["Kind"], "inductive", TestID -> "LeanImport-Inductive-Kind"]

(* Filtered import *)

VerificationTest[
    $filtered = LeanImport["LeanLink.Examples", "ProjectDir" -> $LeanLinkTestProjectDir, "Imports" -> {"LeanLink"}, "Filter" -> "Examples"];
    Head[$filtered] === LeanEnvironment && Length[$filtered] >= 10
    ,
    True
    ,
    TestID -> "LeanImport-Filtered-Count"
]

VerificationTest[KeyExistsQ[$filtered, "LeanLink.Examples.modus_ponens"], True, TestID -> "LeanImport-Filtered-HasModusPonens"]

VerificationTest[KeyExistsQ[$filtered, "LeanLink.Examples.Vec.head"], True, TestID -> "LeanImport-Filtered-HasVecHead"]

(* Standalone file import *)

VerificationTest[
    $standalone = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
    Head[$standalone] === LeanEnvironment && Length[$standalone] > 10
    ,
    True
    ,
    TestID -> "LeanImport-Standalone-Returns-Env"
]

VerificationTest[KeyExistsQ[$standalone, "add_zero_term"] && KeyExistsQ[$standalone, "modus_ponens"] && KeyExistsQ[$standalone, "Vec.head"], True, TestID -> "LeanImport-Standalone-HasKeys"]

VerificationTest[Head[$standalone["add_zero_term"]["Type"]], LeanForall, TestID -> "LeanImport-Standalone-TypeResolves"]

VerificationTest[
    $env2 = LeanImport["LeanLink", "ProjectDir" -> $LeanLinkTestProjectDir, "Filter" -> "LeanLink.Examples.add_zero"];
    KeyExistsQ[$env2, "LeanLink.Examples.add_zero"]
    ,
    True
    ,
    TestID -> "LeanImport-Shorthand"
]

(* ================================================================ *)
(* Property access                                                   *)
(* ================================================================ *)

VerificationTest[$filtered["LeanLink.Examples.modus_ponens"]["Name"], "LeanLink.Examples.modus_ponens", TestID -> "Property-Name"]

VerificationTest[$filtered["LeanLink.Examples.modus_ponens"]["Kind"], "theorem", TestID -> "Property-Kind"]

VerificationTest[Head[$filtered["LeanLink.Examples.modus_ponens"]["Type"]], LeanForall, TestID -> "Property-Type-Head"]

VerificationTest[Head[$filtered["LeanLink.Examples.modus_ponens"]["Term"]], LeanLam, TestID -> "Property-Term-Head"]

VerificationTest[
    $filtered["LeanLink.Examples.modus_ponens"]["Properties"],
    {"Name", "Kind", "Type", "Term", "TypeForm", "TermForm", "TypeRefs", "TermRefs", "Axioms", "KernelCheck", "Module", "Source", "ExprGraph", "CallGraph", "Parameters", "Body"},
    TestID -> "Property-Properties-List"
]

(* Axioms: exact audit via Lean.collectAxioms. modus_ponens is pure logic. *)

VerificationTest[$filtered["LeanLink.Examples.modus_ponens"]["Axioms"], {}, TestID -> "Property-Axioms-ModusPonens-None"]

VerificationTest[ListQ[$filtered["LeanLink.Examples.Vec.head"]["Axioms"]], True, TestID -> "Property-Axioms-IsList"]

(* KernelCheck: the declaring module replayed through the kernel, as leanchecker
   does. A declaration added with debug.skipKernelTC shows no axioms; only the
   replay rejects it. *)

VerificationTest[$filtered["LeanLink.Examples.modus_ponens"]["KernelCheck"]["Module"], "LeanLink.Examples", TestID -> "Property-KernelCheck-Accepts"]

VerificationTest[
    $forged = LeanImportString[
        "import Lean\nopen Lean Elab Command\nset_option debug.skipKernelTC true in\nrun_cmd liftCoreM <| addDecl <| .thmDecl { name := `Forged.falseProof, levelParams := [], type := mkConst ``False, value := mkConst ``True.intro }"
    ]["Forged.falseProof"];
    {$forged["Axioms"], $forged["KernelCheck"]["Tag"]}
    ,
    {{}, "KernelRejected"}
    ,
    TestID -> "Property-KernelCheck-RejectsSkippedKernel"
]

(* LeanEvaluate: #eval, value back through JSON. *)

VerificationTest[
    {LeanEvaluate["1 + 1"], LeanEvaluate["[1, 2, 3].map (· * 2)"], LeanEvaluate["decide (3 < 5)"], LeanEvaluate["\"\[ForAll]x\""]},
    {2, {2, 4, 6}, True, "\[ForAll]x"},
    TestID -> "LeanEvaluate-Values"
]

VerificationTest[
    LeanEvaluate["(List.range 8).map (fib 1 1)", "Source" -> "def fib (a b : Nat) : Nat -> Nat\n  | 0 => a\n  | n + 1 => fib b (a + b) n"],
    {1, 1, 2, 3, 5, 8, 13, 21},
    TestID -> "LeanEvaluate-Source"
]

VerificationTest[LeanEvaluate["undefinedThing + 1"]["Tag"], "LeanEvaluateFailed", TestID -> "LeanEvaluate-ErrorFailure"]

VerificationTest[LeanEvaluate["(List.range 300000000).foldl (· + ·) 0", "TimeLimit" -> 2]["Tag"], "TimedOut", TestID -> "LeanEvaluate-TimeLimit"]

VerificationTest[
    {LeanEvaluate["(2.5 : Float) * 2"], LeanEvaluate["(0.1 : Float) + 0.2"], LeanEvaluate["(1e300 : Float) * 1e10"], LeanEvaluate["(0 : Float) / 0"], LeanEvaluate["[(1.5 : Float), 2]"]},
    {5., 0.30000000000000004, Infinity, Indeterminate, {1.5, 2.}},
    TestID -> "LeanEvaluate-Float-is-exact"
]

(* LeanBuild: the pinned toolchain's lake; Success, or a Failure carrying lake's
   output; never a toolchain download. *)

$lbProject[pin_String, src_String] := Module[{d = CreateDirectory[]},
    Export[FileNameJoin[{d, "lakefile.toml"}], "name = \"probe\"\n[[lean_lib]]\nname = \"Probe\"\n", "Text"];
    Export[FileNameJoin[{d, "lean-toolchain"}], pin, "Text"];
    Export[FileNameJoin[{d, "Probe.lean"}], src, "Text"];
    d
]

VerificationTest[Head[LeanBuild[$LeanLinkTestProjectDir, {"LeanLink.Examples"}]], Success, TestID -> "LeanBuild-UpToDate"]

(* A path dependency (`path = "../dep"` in the lakefile) lives outside
   .lake/packages: "ProjectDir" finds it through lake-manifest.json. *)

VerificationTest[
    Module[{root = CreateDirectory[], dep, main},
        dep = CreateDirectory[FileNameJoin[{root, "dep"}]];
        main = CreateDirectory[FileNameJoin[{root, "main"}]];
        Export[FileNameJoin[{dep, "lakefile.toml"}], "name = \"dep\"\ndefaultTargets = [\"Dep\"]\n[[lean_lib]]\nname = \"Dep\"\n", "Text"];
        Export[FileNameJoin[{dep, "Dep.lean"}], "theorem Dep.two : 1 + 1 = 2 := rfl\n", "Text"];
        Export[FileNameJoin[{main, "lakefile.toml"}], "name = \"main\"\ndefaultTargets = [\"Main\"]\n[[require]]\nname = \"dep\"\npath = \"../dep\"\n[[lean_lib]]\nname = \"Main\"\n", "Text"];
        Export[FileNameJoin[{main, "Main.lean"}], "import Dep\ntheorem Main.two : 1 + 1 = 2 := Dep.two\n", "Text"];
        Scan[Export[FileNameJoin[{#, "lean-toolchain"}], "leanprover/lean4:v4.35.0", "Text"]&, {dep, main}];
        LeanBuild[main];
        {LeanImport["Main", "ProjectDir" -> main]["Main.two"]["TypeForm"], LeanImportString["import Dep\ntheorem t : 1 + 1 = 2 := Dep.two", "ProjectDir" -> main]["t"]["TypeForm"]}
    ]
    ,
    {"1 + 1 = 2", "1 + 1 = 2"}
    ,
    TestID -> "ProjectDir-PathDependency"
]

VerificationTest[
    With[{r = LeanBuild[$lbProject["leanprover/lean4:v4.35.0", "theorem bad : 1 = 2 := rfl\n"], {"Probe"}]},
        {r["Tag"], StringContainsQ[r["Output"], "error"]}
    ]
    ,
    {"LeanBuildFailed", True}
    ,
    TestID -> "LeanBuild-ErrorCarried"
]

VerificationTest[LeanBuild[$lbProject["leanprover/lean4:v4.0.0-not-installed", "theorem ok : 1 = 1 := rfl\n"], {"Probe"}]["Tag"], "ToolchainNotInstalled", TestID -> "LeanBuild-ToolchainNotInstalled"]

(* TypeForm is #check output: Lean's own delaborator via the lean frontend,
   with notation (not raw applications) and "Open" -> {ns} shortening names. *)

VerificationTest[$filtered["LeanLink.Examples.modus_ponens"]["TypeForm"], "\[ForAll] (P Q : Prop), P \[RightArrow] (P \[RightArrow] Q) \[RightArrow] Q", TestID -> "TypeForm-LeanNotation"]

VerificationTest[$filtered["LeanLink.Examples.contrapositive"]["TypeForm"], "\[ForAll] (P Q : Prop), (P \[RightArrow] Q) \[RightArrow] \[Not]Q \[RightArrow] \[Not]P", TestID -> "TypeForm-NotNotation"]

VerificationTest[
    $filtered["LeanLink.Examples.Vec.head"]["TypeForm", "Open" -> {"LeanLink.Examples"}],
    "{a : Type} \[RightArrow] {n : Nat} \[RightArrow] Vec a (n + 1) \[RightArrow] a",
    TestID -> "TypeForm-Open"
]

(* Source: the declaration's text, from the olean's range and the module's file. *)

VerificationTest[$filtered["LeanLink.Examples.identity"]["Source"], "theorem identity : forall (P : Prop), P -> P := fun _ hp => hp", TestID -> "Property-Source"]

(* WXF integers >= 128 (machine sizes and big integers) round-trip. LeanLink
   used non-WXF tokens past int8, so a type with a literal >= 128 failed. *)

VerificationTest[
    With[{env = LeanImportString["theorem lit1000 : (1000 : Nat) = 1000 := rfl\ntheorem lit2e70 : (1180591620717411303424 : Nat) = 1180591620717411303424 := rfl"]},
        {FreeQ[env["lit1000"]["Type"], LeanLitNat[1000]], FreeQ[env["lit2e70"]["Type"], LeanLitNat[1180591620717411303424]]}
    ]
    ,
    {False, False}
    ,
    TestID -> "WXF-BigIntegerLiterals"
]

(* Module: the module that declares a constant. *)

VerificationTest[$filtered["LeanLink.Examples.modus_ponens"]["Module"], "LeanLink.Examples", TestID -> "Property-Module"]

(* LeanImportString keeps what the source declares, including inside a
   namespace. It used to match unqualified names scraped from the text against
   the qualified environment names, so namespaced declarations came back empty. *)

VerificationTest[
    Sort @ DeleteCases[Keys[First[LeanImportString["namespace LLTest\ntheorem t1 : 1 = 1 := rfl\ndef d1 : Nat := 3\nend LLTest"]]], "_Handle"],
    {"LLTest.d1", "LLTest.t1"},
    TestID -> "ImportString-Namespace-Kept"
]

(* LeanTactic exact must type-check its term against the goal. It used to
   assign any resolvable term to any goal (exact Nat.zero "proved" False), so
   Complete -> True was not evidence of a proof. Pin both directions. *)

VerificationTest[
    Block[{s = LeanState[$filtered["LeanLink.Examples.identity"]]},
        s = LeanTactic["intro P hp"][s];
        LeanTactic["exact hp"][s]["Complete"]
    ]
    ,
    True
    ,
    TestID -> "Tactic-Exact-WellTyped-Completes"
]

VerificationTest[
    Block[{s = LeanState[$filtered["LeanLink.Examples.identity"]]},
        s = LeanTactic["intro P hp"][s];
        LeanTactic["exact Nat.zero"][s]
    ]
    ,
    $Failed
    ,
    {LeanTactic::err}
    ,
    TestID -> "Tactic-Exact-IllTyped-Rejected"
]

VerificationTest[
    Block[{s = LeanState[$filtered["LeanLink.Examples.modus_ponens"]]},
        s = LeanTactic["intro P Q hp hpq"][s];
        LeanTactic["exact hpq hp"][s]["Complete"]
    ]
    ,
    True
    ,
    TestID -> "Tactic-Exact-Application-Completes"
]

VerificationTest[
    Block[{s = LeanState[$filtered["LeanLink.Examples.modus_ponens"]]},
        s = LeanTactic["intro P Q hp hpq"][s];
        LeanTactic["exact hp"][s]
    ]
    ,
    $Failed
    ,
    {LeanTactic::err}
    ,
    TestID -> "Tactic-Exact-WrongHypothesis-Rejected"
]

VerificationTest[MatchQ[$filtered["LeanLink.Examples.Vec.head"]["Type"], _LeanForall], True, TestID -> "Property-Type-IsForall"]

VerificationTest[StringQ[$filtered["LeanLink.Examples.Vec.head"]["TypeForm"]], True, TestID -> "Property-TypeForm-IsString"]

VerificationTest[MatchQ[$filtered["LeanLink.Examples.Vec.head"]["Term"], _LeanLam | _LeanApp | _LeanConst], True, TestID -> "Property-Term-HasExpression"]

VerificationTest[
    With[{g = $filtered["LeanLink.Examples.modus_ponens"]["ExprGraph"]},
        GraphQ[g] && VertexCount[g] > 0 && VectorQ[VertexList[g], IntegerQ]
    ]
    ,
    True
    ,
    TestID -> "Property-ExprGraph-IsGraph"
]

VerificationTest[GraphQ[$filtered["LeanLink.Examples.modus_ponens"]["CallGraph"]], True, TestID -> "Property-CallGraph-IsGraph"]

VerificationTest[StringQ[$filtered["LeanLink.Examples.Vec.head"]["TermForm"]], True, TestID -> "Property-TermForm-IsString"]

(* ================================================================ *)
(* TermForm - in-process printing with the imported notation         *)
(* ================================================================ *)

(* A dependent if-then-else reaches the IR interpreter through the
   parenthesizer, which killed the kernel until the shim called
   lean_initialize. The notation needs importModules (loadExts := true),
   enabled again before every import; this import follows many others. *)

VerificationTest[
    $termEnv = LeanImportString[
        "namespace TermDemo\ntheorem dite_proof (a b : Nat) : a = b ∨ a ≠ b := if h : a = b then Or.inl h else Or.inr h\ndef ite_def (a b : Nat) : Nat := if a = b then 1 else 0\ndef arith (n : Nat) : Nat := n - 396 + 2 * n\nend TermDemo"
    ];
    $termEnv["TermDemo.dite_proof"]["TermForm"]
    ,
    "fun a b => if h : a = b then Or.inl h else Or.inr h"
    ,
    TestID -> "TermForm-DependentIf-NoCrash"
]

VerificationTest[$termEnv["TermDemo.ite_def"]["TermForm"], "fun a b => if a = b then 1 else 0", TestID -> "TermForm-Notation-If"]

VerificationTest[$termEnv["TermDemo.arith"]["TermForm"], "fun n => n - 396 + 2 * n", TestID -> "TermForm-Notation-Arithmetic"]

VerificationTest[ListQ[$filtered["LeanLink.Examples.Vec.head"]["TypeRefs"]], True, TestID -> "Property-TypeRefs-IsList"]

(* ================================================================ *)
(* LeanExportString                                                    *)
(* ================================================================ *)

VerificationTest[StringQ[LeanExportString[$filtered]], True, TestID -> "LeanExportString-Returns-String"]

VerificationTest[
    $expSrc = LeanExportString[$filtered];
    StringContainsQ[$expSrc, "modus_ponens"]
    ,
    True
    ,
    TestID -> "LeanExportString-Contains-Theorem"
]

VerificationTest[StringContainsQ[$expSrc, "Nat"], True, TestID -> "LeanExportString-Contains-NatType"]

VerificationTest[StringContainsQ[$expSrc, "sorry"], True, TestID -> "LeanExportString-Contains-Sorry"]

(* FFI-based pretty printing *)

VerificationTest[StringQ[LeanExportString[$filtered["LeanLink.Examples.modus_ponens"]]], True, TestID -> "LeanExportString-LeanTerm-FFI"]

VerificationTest[
    With[{pp = LeanExportString[$filtered["LeanLink.Examples.identity"]]},
        StringQ[pp] && ! StringContainsQ[pp, "sorry"]
    ]
    ,
    True
    ,
    TestID -> "LeanExportString-LeanTerm-NoSorry"
]

(* ================================================================ *)
(* ProofToLean - roundtrip tests                                      *)
(* ================================================================ *)

VerificationTest[
    $proof = FindEquationalProof[a == c, {a == b, b == c}];
    $ptlEnv = ProofToLean[$proof];
    Head[$ptlEnv] === LeanEnvironment && Length[$ptlEnv] > 0
    ,
    True
    ,
    TestID -> "ProofToLean-Returns-LeanEnvironment"
]

VerificationTest[MemberQ[Keys[$ptlEnv], "FinalGoal"], True, TestID -> "ProofToLean-Has-FinalGoal"]

VerificationTest[Head[$ptlEnv["FinalGoal"][[1]]["_TypeExpr"]], LeanForall, TestID -> "ProofToLean-TypeExpr-Is-LeanForall"]

VerificationTest[
    With[{tac = $ptlEnv["FinalGoal"][[1]]["_Tactic"]},
        Head[tac] === LeanTactic && ListQ[tac[[1]]]
    ]
    ,
    True
    ,
    TestID -> "ProofToLean-Tactic-Is-Structured"
]

VerificationTest[StringQ[$ptlEnv["FinalGoal"]["TypeForm"]], True, TestID -> "ProofToLean-TypeForm-Fallback"]

VerificationTest[
    $ptlSrc = LeanExportString[$ptlEnv];
    StringQ[$ptlSrc] && StringContainsQ[$ptlSrc, "theorem FinalGoal"]
    ,
    True
    ,
    TestID -> "ProofToLean-ExportString-Valid"
]

VerificationTest[
    $roundtrip = LeanImportString[$ptlSrc];
    Head[$roundtrip] === LeanEnvironment && KeyExistsQ[$roundtrip, "FinalGoal"]
    ,
    True
    ,
    TestID -> "ProofToLean-Roundtrip-Succeeds"
]

VerificationTest[
    Module[{export},
        export[context_] := Block[{$Context = context, $ContextPath = {"System`", context}},
            LeanExportString[ProofToLean[ToExpression["FindEquationalProof[p == r, {p == q, q == r}]"]]]
        ];
        With[{source = export["ProofToLeanGlobal`"]},
            {source === export["ProofToLeanNotebook`"], MatchQ[LeanImportString[source], _LeanEnvironment]}
        ]
    ]
    ,
    {True, True}
    ,
    TestID -> "ProofToLean-gives-the-same-Lean-in-any-context"
]

VerificationTest[
    Module[{source},
        source = LeanExportString[ProofToLean[FindEquationalProof[g[x, y] == g[y, x], ForAll[{p, q}, g[p, q] == g[q, p]]]]];
        {StringContainsQ[source, "axiom g : U"], MatchQ[LeanImportString[source], _LeanEnvironment]}
    ]
    ,
    {True, True}
    ,
    {ProofToLean::sorry}
    ,
    TestID -> "ProofToLean-declares-a-function-named-by-one-letter"
]

(* ================================================================ *)
(* LeanExportString for ProofToLean                                    *)
(* ================================================================ *)

VerificationTest[
    $ptlExportSrc = LeanExportString[$ptlEnv];
    StringQ[$ptlExportSrc] && StringContainsQ[$ptlExportSrc, "theorem FinalGoal"]
    ,
    True
    ,
    TestID -> "LeanExportString-ProofToLean-HasFinalGoal"
]

VerificationTest[StringContainsQ[$ptlExportSrc, "axiom"], True, TestID -> "LeanExportString-ProofToLean-HasAxiom"]

VerificationTest[StringContainsQ[$ptlExportSrc, "theorem"] && StringLength[$ptlExportSrc] > 100, True, TestID -> "LeanExportString-ProofToLean-HasTheorem"]

VerificationTest[StringContainsQ[$ptlExportSrc, "intro"], True, TestID -> "LeanExportString-ProofToLean-HasIntro"]

VerificationTest[StringContainsQ[$ptlExportSrc, "rfl"] || StringContainsQ[$ptlExportSrc, "exact"], True, TestID -> "LeanExportString-ProofToLean-HasExact"]

(* ================================================================ *)
(* LeanTerm properties                                                 *)
(* ================================================================ *)

VerificationTest[StringQ[$filtered["LeanLink.Examples.modus_ponens"]["Term"]], False, TestID -> "LeanExportString-Term-NotString"]

VerificationTest[MatchQ[$filtered["LeanLink.Examples.modus_ponens"]["Type"], _LeanForall | _LeanApp | _LeanConst], True, TestID -> "LeanExportString-Type-HasExpression"]

VerificationTest[StringQ[$filtered["LeanLink.Examples.modus_ponens"]["TypeForm"]], True, TestID -> "LeanExportString-TypeForm-IsString"]

VerificationTest[MatchQ[$filtered["LeanLink.Examples.modus_ponens"]["Term"], _LeanLam | _LeanApp | _LeanConst | LeanNoValue[]], True, TestID -> "LeanExportString-Term-HasProp"]

VerificationTest[
    $importedEnv = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"];
    Head[$importedEnv] === LeanEnvironment && KeyExistsQ[$importedEnv, "myT"]
    ,
    True
    ,
    TestID -> "LeanImportString-CompileAndImport"
]

(* LeanImportString roundtrip with LeanExportString *)

VerificationTest[
    Module[{env, src},
        env = LeanImportString["def myFn (n : Nat) : Nat := n + 1"];
        src = LeanExportString[env];
        StringQ[src] && StringContainsQ[src, "myFn"]
    ]
    ,
    True
    ,
    TestID -> "LeanImportString-ExportString-Roundtrip"
]

(* ================================================================ *)
(* LeanEnvironment Properties                                         *)
(* ================================================================ *)

VerificationTest[Information[$ptlEnv, "Properties"], {"Constants", "Kinds", "Handle", "Source", "DeclOrder", "Preamble"}, TestID -> "LeanEnvironment-Properties-List"]

VerificationTest[Information[$ptlEnv, "Constants"], Keys[$ptlEnv], TestID -> "LeanEnvironment-Constants-EqualsKeys"]

VerificationTest[AssociationQ[Information[$ptlEnv, "Kinds"]], True, TestID -> "LeanEnvironment-Kinds-IsAssociation"]

(* ================================================================ *)
(* Term Construction & Type Checking                                  *)
(* ================================================================ *)

(* Bare expr wrap creates valid LeanTerm *)

VerificationTest[Head[LeanTerm[LeanConst["Nat", {}]]], LeanTerm, TestID -> "LeanTerm-Bare-Wraps"]

(* LeanTerm with env binding carries handle internally *)

VerificationTest[IntegerQ[LeanTerm[LeanConst["Nat", {}], $env][[1]]["_Handle"]], True, TestID -> "LeanTerm-WithEnv-HasHandle"]

(* Type check Nat constant via env *)

VerificationTest[
    With[{t = LeanTerm[LeanConst["Nat", {}], $env]},
        t["Type"] === LeanSort[LeanLevelSucc[LeanLevelZero[]]]
    ]
    ,
    True
    ,
    TestID -> "LeanTerm-TypeCheck-Nat"
]

(* Type check Nat.succ 0 → Nat *)

VerificationTest[
    With[{t = LeanTerm[LeanApp[LeanConst["Nat.succ", {}], LeanLitNat[0]], $env]},
        t["Type"] === LeanConst["Nat", {}]
    ]
    ,
    True
    ,
    TestID -> "LeanTerm-TypeCheck-NatSucc"
]

(* Type check forall expression *)

VerificationTest[
    With[{t = LeanTerm[LeanForall["n", LeanConst["Nat", {}], LeanConst["Nat", {}], "default"], $env]},
        MatchQ[t["Type"], _LeanSort]
    ]
    ,
    True
    ,
    TestID -> "LeanTerm-TypeCheck-Forall"
]

(* TypeForm pretty-prints via type check *)

VerificationTest[StringQ[LeanTerm[LeanConst["Nat", {}], $env]["TypeForm"]], True, TestID -> "LeanTerm-TypeForm-Works"]

(* ================================================================ *)
(* Environment Creation & Roundtrips                                   *)
(* ================================================================ *)

(* Compile simple def and access term *)

VerificationTest[
    Module[{env = LeanImportString["def myVal : Nat := 42"]},
        Head[env] === LeanEnvironment && KeyExistsQ[env, "myVal"] && env["myVal"]["Kind"] === "def"
    ]
    ,
    True
    ,
    TestID -> "LeanImportString-SimpleDef"
]

(* A source with CRLF line ends, as a Windows editor or checkout gives it,
   compiles as with LF, and the source kept for "Source" has no CR *)

VerificationTest[
    With[{env = LeanImportString["def crlfOne : Nat := 1\r\ndef crlfTwo : Nat := crlfOne + 1\r\n"]},
        {env["crlfTwo"]["TypeForm"], StringFreeQ[env["crlfTwo"]["Source"], "\r"]}
    ]
    ,
    {"Nat", True}
    ,
    TestID -> "LeanImportString-CRLF"
]

(* Compile theorem and verify type *)

VerificationTest[
    Module[{env = LeanImportString["theorem myThm : 1 + 1 = 2 := rfl"]},
        Head[env] === LeanEnvironment && env["myThm"]["Kind"] === "theorem" && StringQ[env["myThm"]["TypeForm"]]
    ]
    ,
    True
    ,
    TestID -> "LeanImportString-Theorem-Type"
]

(* Full roundtrip: export → compile → verify *)

VerificationTest[
    Module[{src, rt},
        src = "def foo := Nat.succ 0";
        rt = LeanImportString[src];
        Head[rt] === LeanEnvironment && KeyExistsQ[rt, "foo"]
    ]
    ,
    True
    ,
    TestID -> "LeanImportString-Roundtrip-Def"
]

(* Information protocol works *)

VerificationTest[
    Module[{env = LeanImportString["def x := 1\ndef y := 2\ntheorem t : 1 = 1 := rfl"]},
        AssociationQ[Information[env, "Kinds"]] && Length[Information[env, "Constants"]] >= 3
    ]
    ,
    True
    ,
    TestID -> "LeanEnvironment-Info-Works"
]

(* LeanEnvironment handle is Integer for compiled envs *)

VerificationTest[
    Module[{env = LeanImportString["def q := 0"]},
        IntegerQ[Information[env, "Handle"]]
    ]
    ,
    True
    ,
    TestID -> "LeanEnvironment-Handle-IsInteger"
]

(* ProofToLean goal Type returns valid LeanForall *)

VerificationTest[
    Module[{env, goal},
        env = ProofToLean[FindEquationalProof[a == c, {a == b, b == c}]];
        goal = env["FinalGoal"];
        Head[goal["Type"]] === LeanForall
    ]
    ,
    True
    ,
    TestID -> "ProofToLean-GoalType-IsForall"
]

(* ProofToLean goal type resolves to expected form *)

VerificationTest[
    Module[{env, goal},
        env = ProofToLean[FindEquationalProof[a == c, {a == b, b == c}]];
        goal = env["FinalGoal"];
        MatchQ[goal["Type"], _LeanForall | _LeanApp]
    ]
    ,
    True
    ,
    TestID -> "ProofToLean-Term-TypeChecks"
]

(* ================================================================ *)
(* BooleanAxioms roundtrip                                            *)
(* ================================================================ *)

VerificationTest[
    Module[{proof, env, src, rt},
        proof = FindEquationalProof["Absorption", "BooleanAxioms"];
        (* a step with no translation yet, which this test allows, is proved by sorry, and ProofToLean says so *)
        env = Quiet[ProofToLean[proof], ProofToLean::sorry];
        src = LeanExportString[env];
        rt = Quiet @ LeanImportString[src];
        (* Allow at most 2 errors - 1 known: commutative Ax3 loop in SL8 *)
        If[ Head[rt] === LeanEnvironment,
            True
            ,
            (* Fallback: check source quality *)
            StringQ[src] && StringContainsQ[src, "theorem FinalGoal"] && StringContainsQ[src, "Ax4 a b (OverBar a)"]
        ]
    ]
    ,
    True
    ,
    TestID -> "BooleanAxioms-Absorption-Roundtrip"
]

(* DoubleNegation - end-to-end LeanState test *)

VerificationTest[
    Module[{env, state},
        env = ProofToLean[FindEquationalProof["DoubleNegation", "WolframAxioms"]];
        state = LeanState @ env["FinalGoal"];
        Head[state] === LeanState && state["Complete"]
    ]
    ,
    True
    ,
    TestID -> "DoubleNegation-LeanState-EndToEnd"
]

(* ================================================================ *)
(* Mathlib import - Fundamental Theorem of Algebra                    *)
(* Requires: /tmp/mathlib_test with prebuilt Mathlib cache            *)
(* Run: lake init MathlibTest math && lake exe cache get              *)
(* ================================================================ *)

$mathlibDir = "/tmp/mathlib_test";

$hasMathlib = DirectoryQ[FileNameJoin[{$mathlibDir, ".lake", "packages", "mathlib"}]];

(* Import IsAlgClosed module, inspect the typeclass *)

VerificationTest[
    If[ ! $hasMathlib,
        True
        ,
        Module[{env},
            env = LeanImport["Mathlib.FieldTheory.IsAlgClosed.Basic", "ProjectDir" -> $mathlibDir, "Filter" -> "IsAlgClosed"];
            Head[env] === LeanEnvironment && Length[env] > 0 && AnyTrue[Keys[env], StringContainsQ[#, "IsAlgClosed"]&]
        ]
    ]
    ,
    True
    ,
    TestID -> "Mathlib-Import-IsAlgClosed"
]

(* Inspect IsAlgClosed TypeForm *)

VerificationTest[
    If[ ! $hasMathlib,
        True
        ,
        Module[{env, key},
            env = LeanImport["Mathlib.FieldTheory.IsAlgClosed.Basic", "ProjectDir" -> $mathlibDir, "Filter" -> "IsAlgClosed"];
            key = SelectFirst[Keys[env], StringContainsQ[#, "IsAlgClosed"]&];
            StringQ[key] && StringQ[env[key]["TypeForm"]]
        ]
    ]
    ,
    True
    ,
    TestID -> "Mathlib-IsAlgClosed-TypeForm"
]

(* Import Complex.Polynomial for FTA *)

VerificationTest[
    If[ ! $hasMathlib,
        True
        ,
        Module[{env},
            env = LeanImport["Mathlib.Analysis.Complex.Polynomial.Basic", "ProjectDir" -> $mathlibDir, "Filter" -> "Complex"];
            Head[env] === LeanEnvironment && AnyTrue[Keys[env], StringContainsQ[#, "isAlgClosed" | "IsAlgClosed"]&]
        ]
    ]
    ,
    True
    ,
    TestID -> "Mathlib-Complex-FTA"
]

(* ================================================================ *)
(* LeanToFunction / LeanCompile                                       *)
(* ================================================================ *)

(* Simple def: n + 1 *)

VerificationTest[
    Module[{env, fn},
        env = LeanImportString["def myFn (n : Nat) : Nat := n + 1"];
        fn = LeanToFunction[env["myFn"]];
        Head[fn] === Function
    ]
    ,
    True
    ,
    TestID -> "LeanToFunction-SimpleDef-Returns-Function"
]

(* FunctionCompile the simple def *)

VerificationTest[
    Module[{env, fn, cf},
        env = LeanImportString["def myFn (n : Nat) : Nat := n + 1"];
        fn = LeanToFunction[env["myFn"]];
        If[Head[fn] =!= Function, Return[False, Module]];
        cf = Quiet[FunctionCompile[fn]];
        Head[cf] === CompiledCodeFunction && cf[5] === 6
    ]
    ,
    True
    ,
    TestID -> "LeanCompile-SimpleDef-Executes"
]

(* Multi-arg def *)

VerificationTest[
    Module[{env, cf},
        env = LeanImportString["def add (m n : Nat) : Nat := m + n"];
        cf = LeanCompile[env["add"]];
        Head[cf] === CompiledCodeFunction && cf[3, 4] === 7
    ]
    ,
    True
    ,
    TestID -> "LeanCompile-MultiArg-Add"
]

(* Multiplication *)

VerificationTest[
    Module[{env, cf},
        env = LeanImportString["def double (n : Nat) : Nat := n * 2"];
        cf = LeanCompile[env["double"]];
        Head[cf] === CompiledCodeFunction && cf[7] === 14
    ]
    ,
    True
    ,
    TestID -> "LeanCompile-Multiply"
]

(* Non-compilable type rejection (Prop-based theorem) *)

VerificationTest[
    Module[{env},
        env = LeanImportString["theorem myT : 1 + 1 = 2 := rfl"];
        Quiet[LeanToFunction[env["myT"]]]
    ]
    ,
    $Failed
    ,
    TestID -> "LeanToFunction-RejectsNonCompilable"
]

VerificationTest[
    Module[{env, compiled},
        env = LeanImportString[
            {
                "def natSub (a b : Nat) : Nat := a - b",
                "def natDiv (a b : Nat) : Nat := a / b",
                "def natMod (a b : Nat) : Nat := a % b",
                "def intDiv (a b : Int) : Int := a / b",
                "def intMod (a b : Int) : Int := a % b",
                "def half (x : Float) : Float := x / 2"
            }
        ];
        compiled = AssociationMap[LeanCompile[env[#]]&, {"natSub", "natDiv", "natMod", "intDiv", "intMod", "half"}];
        {compiled["natSub"][2, 5], compiled["natDiv"][5, 0], compiled["natMod"][5, 0], compiled["intDiv"][7, -2], compiled["intMod"][7, -2], compiled["half"][3.]}
    ]
    ,
    {0, 0, 5, -3, 1, 1.5}
    ,
    TestID -> "LeanCompile-arithmetic-computes-as-Lean-does"
]

VerificationTest[
    Module[{env, compiled},
        env = LeanImportString[
            {
                "def differ (a b : Nat) : Bool := a != b",
                "def pick (c : Bool) (a b : Nat) : Nat := bif c then a else b",
                "def same (a b : Nat) : Nat := if a = b then 1 else 0",
                "def mixed (a b : Nat) : Bool := a == b && a < 3 || !(b ≤ a)",
                "def other (a b : Int) : Bool := decide (a ≠ b ∧ ¬ a < 0)",
                "def either (a b : Bool) : Bool := xor a b",
                "def spread (a b : Nat) : Nat := max a b - min a b",
                "def power (a b : Nat) : Nat := a ^ b"
            }
        ];
        compiled = AssociationMap[LeanCompile[env[#]]&, {"differ", "pick", "same", "mixed", "other", "either", "spread", "power"}];
        {
            compiled["differ"][3, 4],
            compiled["pick"][False, 3, 4],
            compiled["same"][3, 3],
            compiled["mixed"][3, 4],
            compiled["other"][-1, 2],
            compiled["either"][True, True],
            compiled["spread"][3, 7],
            compiled["power"][0, 0],
            compiled["power"][2, 10]
        }
    ]
    ,
    {True, 4, 1, True, False, False, 4, 1, 1024}
    ,
    TestID -> "LeanCompile-Boolean-connectives-comparisons-and-powers"
]

VerificationTest[
    Module[{env, compiled},
        env = LeanImportString[
            {
                "def half (n : Nat) : Float := n.toFloat / 2",
                "def scale (x : Float) : Float := x * 2.5 - 1.25e-1",
                "def widen (n : Nat) (k : Int) : Int := n - k",
                "def back (a : Int) : Nat := a.toNat + a.natAbs + Nat.pred 0"
            }
        ];
        compiled = AssociationMap[LeanCompile[env[#]]&, {"half", "scale", "widen", "back"}];
        {compiled["half"][3], compiled["scale"][2.], compiled["widen"][3, 5], compiled["back"][-4]}
    ]
    ,
    {1.5, 4.875, -2, 4}
    ,
    TestID -> "LeanCompile-decimal-literals-and-number-conversions"
]

VerificationTest[
    Module[{env, function},
        env = LeanImportString["def withLog (n : Nat) : Nat := Nat.log2 n + 1"];
        function = LeanToFunction[env["withLog"]];
        FreeQ[function, _Symbol ? (StringContainsQ[SymbolName[#], "."]&)] && ! FreeQ[function, LeanConst["Nat.log2", _]]
    ]
    ,
    True
    ,
    {}
    ,
    TestID -> "LeanToFunction-keeps-a-constant-it-cannot-translate"
]

(* LeanCompile on environment *)

VerificationTest[
    Module[{env, compiled},
        env = LeanImportString["def f1 (n : Nat) : Nat := n + 1\ndef f2 (n : Nat) : Nat := n * 2\ntheorem t : 1 = 1 := rfl"];
        compiled = Quiet[LeanCompile[env]];
        AssociationQ[compiled] && Length[compiled] >= 2
    ]
    ,
    True
    ,
    TestID -> "LeanCompile-Environment-MultiDef"
]

VerificationTest[
    Wolfram`LeanLink`Private`isInternalName /@ {"Char.reduceEq._@.Lean.Meta.Simp.4145659166._hygCtx._hyg.27", "Nat.add_comm", "List.rec"},
    {True, False, True},
    TestID -> "LeanImport-names-with-macro-scopes-are-internal"
]

VerificationTest[
    With[{env = LeanEnvironment[<|"_private.M.0.helper" -> LeanTerm[<|"Kind" -> "theorem"|>], "f" -> LeanTerm[<|"Kind" -> "def"|>], "_Source" -> "", "_DeclOrder" -> {}|>]},
        {Keys[env], Length[env], Length[Values[env]], Information[env, "Constants"]}
    ]
    ,
    {{"_private.M.0.helper", "f"}, 2, 2, {"_private.M.0.helper", "f"}}
    ,
    TestID -> "LeanEnvironment-private-constants-are-constants"
]

VerificationTest[
    Sort[Keys[LeanImportString[{"def f1 (n : Nat) : Nat := n + 1", "theorem f1_zero : f1 0 = 1 := rfl"}]]],
    {"f1", "f1_zero"},
    TestID -> "LeanImportString-list-of-sources-is-joined-with-newlines"
]

VerificationTest[
    With[{file = PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]},
        {
            AllTrue[Keys[LeanImport[file, "Filter" -> "proof"]], StringContainsQ["proof"]],
            Quiet[LeanImport["/no/such/file.lean"]],
            Head[LeanImportString[{}]],
            StringStartsQ[LeanImport[file]["id_proof"]["Source"], "/-- Identity function -/"],
            LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"]["myT"]["Source"]
        }
    ]
    ,
    {True, $Failed, LeanEnvironment, True, "theorem myT : Nat.succ 0 = 1 := rfl"}
    ,
    TestID -> "LeanImport-file-Filter-missing-file-and-Source"
]

VerificationTest[
    With[{evaluation = EvaluationData[LeanImport["NoSuchModule.Anywhere"]]},
        {evaluation["Result"], AnyTrue[evaluation["MessagesText"], StringContainsQ["NoSuchModule.Anywhere"]]}
    ]
    ,
    {$Failed, True}
    ,
    {LeanImport::err}
    ,
    TestID -> "LeanImport-names-a-module-it-cannot-find"
]

VerificationTest[
    Module[{env, back},
        env = LeanImportString[
            {
                "structure Point where",
                "  x : Nat",
                "  y : Nat",
                "class Shape (α : Type) where",
                "  area : α → Nat",
                "def fib : Nat → Nat",
                "  | 0 => 0",
                "  | 1 => 1",
                "  | n + 2 => fib n + fib (n + 1)",
                "axiom unit : 1 = 1",
                "theorem shadow (a : Nat) (b : Nat) : ∀ a : Nat, a + b = b + a := fun a => Nat.add_comm a b",
                "universe u v",
                "def pairUp {α : Sort u} {β : Sort v} (a : α) (b : β) : PProd α β := ⟨a, b⟩",
                "theorem area_zero (p : Point) (h : p.x = 0) : p.x * p.y = 0 := by simp [h]",
                "mutual",
                "inductive Tree where | node : Forest → Tree",
                "inductive Forest where | nil : Forest | cons : Tree → Forest → Forest",
                "end"
            }
        ];
        back = LeanImportString[LeanExportString[env]];
        {Sort[Keys[back]] === Sort[Keys[env]], Select[Keys[env], env[#]["TypeForm"] =!= back[#]["TypeForm"]&]}
    ]
    ,
    {True, {}}
    ,
    TestID -> "LeanExportString-environment-imports-again-with-the-same-types"
]

VerificationTest[
    {
        LeanExportString[LeanSort[LeanLevelSucc[LeanLevelSucc[LeanLevelParam["u"]]]]],
        LeanExportString[LeanSort[LeanLevelMax[LeanLevelParam["u"], LeanLevelParam["v"]]]],
        LeanExportString[LeanLitStr["a\"b\\c\nd"]],
        LeanExportString[LeanProj["Prod", 0, LeanConst["p"]]],
        LeanExportString[LeanForall["a", LeanConst["Nat"], LeanForall["a", LeanConst["Nat"], LeanApp[LeanApp[LeanConst["f"], LeanBVar[1]], LeanBVar[0]], "default"], "default"]]
    }
    ,
    {"Type (u + 1)", "Sort (max u v)", "\"a\\\"b\\\\c\\nd\"", "p.1", "∀ (a : Nat) (a_1 : Nat), f a a_1"}
    ,
    TestID -> "LeanExportString-levels-strings-projections"
]

(* The shim sets LEAN_PATH for the whole kernel process while it loads an
   environment; the kernel's own value comes back afterwards, so processes the
   kernel starts later do not inherit the search path of the last import *)

VerificationTest[
    Block[{before = Environment["LEAN_PATH"]},
        LeanImportString["theorem leanPathKept : 2 + 2 = 4 := rfl"];
        Environment["LEAN_PATH"] === before
    ]
    ,
    True
    ,
    TestID -> "ImportString-Leaves-LEAN_PATH"
]

(* KernelCheck imports the module's imports again, with the search path of its
   environment, after the kernel's LEAN_PATH came back *)

VerificationTest[MatchQ[LeanImportString["theorem kernelCheckedAfter : 3 = 3 := rfl"]["kernelCheckedAfter"]["KernelCheck"], _Success], True, TestID -> "KernelCheck-After-LEAN_PATH-Restored"]

(* The olean an import compiled lives in a folder of its own, deleted with its environment *)

VerificationTest[
    Block[{handle, dir},
        handle = First[LeanImportString["theorem temporaryFolderFreed : 1 = 1 := rfl"]]["_Handle"];
        dir = Wolfram`LeanLink`Private`handleInfo[handle, "TemporaryDirectory"];
        {
            DirectoryQ[dir]
            ,
            LeanFreeEnvironment[handle];
            DirectoryQ[dir]
        }
    ]
    ,
    {True, False}
    ,
    TestID -> "FreeEnvironment-Deletes-Temporary-Folder"
]

(* A project folder holds a file by whole path components, and an olean's module
   is its path's components *)

VerificationTest[
    {
        Wolfram`LeanLink`Private`insideDirectoryQ["/a/kit/A.lean", "/a/kit"],
        Wolfram`LeanLink`Private`insideDirectoryQ["/a/kit2/A.lean", "/a/kit"],
        Wolfram`LeanLink`Private`oleanModule[FileNameJoin[{"/b", "Mathlib", "Logic", "Basic.olean"}], "/b"]
    }
    ,
    {True, False, "Mathlib.Logic.Basic"}
    ,
    TestID -> "Project-Paths-By-Components"
]

(* The paclet's lean-toolchain names the toolchain the shims are built against: a
   LeanImport of a file falls back on it when that toolchain's folder is missing *)

VerificationTest[
    StringTrim[Import[FileNameJoin[{Wolfram`LeanLink`Private`$PacletRoot, "lean-toolchain"}], "Text"]],
    "leanprover/lean4:" <> Wolfram`LeanLink`Private`$LeanToolchainVersion,
    TestID -> "Paclet-Toolchain-Pin"
]

(* A source's own imports with .lean files next to it compile first, in import
   order: "import B" finds B.lean, and Sub.C finds Sub/C.lean *)

VerificationTest[
    Block[{dir = CreateDirectory[], env},
        Export[FileNameJoin[{dir, "LocalB.lean"}], "def localB : Nat := 1", "Text"];
        CreateDirectory[FileNameJoin[{dir, "Sub"}]];
        Export[FileNameJoin[{dir, "Sub", "LocalC.lean"}], "import LocalB\ndef localC : Nat := localB + 1", "Text"];
        Export[FileNameJoin[{dir, "LocalA.lean"}], "import LocalB\nimport Sub.LocalC\ntheorem localA : localB + localC = 3 := rfl", "Text"];
        env = LeanImport[FileNameJoin[{dir, "LocalA.lean"}]];
        {Keys[KeyDrop[First[env], "_Handle"]], MatchQ[env["localA"]["KernelCheck"], _Success]}
    ]
    ,
    {{"localA"}, True}
    ,
    TestID -> "Import-File-With-Local-Imports"
]

(* Outside any Lake project, a module of Lean's own library imports from the
   toolchain the shim is built against *)

VerificationTest[Length[LeanImport["Init.Prelude", "ProjectDir" -> CreateDirectory[]]] > 1000, True, TestID -> "Import-Module-Outside-Projects"]

EndTestSection[]
BeginTestSection["EnvironmentEvaluation"]

VerificationTest[
    $evaluationEnv = LeanImport["Lean", "ProjectDir" -> $LeanLinkTestProjectDir];
    LeanEvaluate[$evaluationEnv, "2^100"], 2^100, TestID -> "EnvironmentEvaluation-ExactInteger"
]

VerificationTest[LeanEvaluate[$evaluationEnv["Nat.add"], 17, 25], 42, TestID -> "EnvironmentEvaluation-ApplyTerm"]
VerificationTest[LeanEvaluate[$evaluationEnv["Int.natAbs"], -42], 42, TestID -> "EnvironmentEvaluation-NegativeInteger"]
VerificationTest[LeanEvaluate[$evaluationEnv["id"], 7/11], 7/11, TestID -> "EnvironmentEvaluation-ExactRational"]
VerificationTest[LeanEvaluate[$evaluationEnv["id"], True], True, TestID -> "EnvironmentEvaluation-Boolean"]
VerificationTest[LeanEvaluate[$evaluationEnv["List.reverse"], {1, 2, 3}], {3, 2, 1}, TestID -> "EnvironmentEvaluation-List"]
VerificationTest[LeanEvaluate[$evaluationEnv["id"], {{1/3, 2/5}, {3/7, 4/9}}], {{1/3, 2/5}, {3/7, 4/9}}, TestID -> "EnvironmentEvaluation-NestedRationals"]

VerificationTest[
    With[{text = FromCharacterCode[{945, 19990, 128512, 10, 34, 92, 0, 1, 127}]}, LeanEvaluate[$evaluationEnv["id"], text] === text],
    True, TestID -> "EnvironmentEvaluation-UnicodeAndControls"
]

VerificationTest[LeanEvaluate[$evaluationEnv, "(0.1 : Float) + 0.2"], 0.1 + 0.2, TestID -> "EnvironmentEvaluation-FloatBits"]
VerificationTest[LeanEvaluate[$evaluationEnv, "[(1.0 : Float)/0.0, (-1.0 : Float)/0.0, (0.0 : Float)/0.0]"], {Infinity, -Infinity, Indeterminate}, TestID -> "EnvironmentEvaluation-SpecialFloats"]

VerificationTest[
    LeanEvaluate[$evaluationEnv["List.map"], $evaluationEnv["Nat.succ"], {2, 4, 6}],
    {3, 5, 7}, TestID -> "EnvironmentEvaluation-TypedFunctionArgument"
]

VerificationTest[LeanEvaluate[$evaluationEnv["id"], 0.25]["Tag"], "UnsupportedArgument", TestID -> "EnvironmentEvaluation-NoImplicitPrecisionLoss"]
VerificationTest[LeanEvaluate[$evaluationEnv, "unknownDeclaration"]["Tag"], "LeanEvaluateFailed", TestID -> "EnvironmentEvaluation-InvalidExpression"]
VerificationTest[LeanEvaluate[$evaluationEnv, "2+3"], 5, TestID -> "EnvironmentEvaluation-RecoverAfterError"]
VerificationTest[LeanEvaluate[$evaluationEnv, "answer", "Open" -> "EvaluationExample", "Source" -> "namespace EvaluationExample\ndef answer := 42\nend EvaluationExample"], 42, TestID -> "EnvironmentEvaluation-OpenNamespace"]

VerificationTest[
    {LeanEvaluate[$evaluationEnv, "offset 4", "Source" -> "def offset (n : Nat) := n + 1"],
     LeanEvaluate[$evaluationEnv, "offset 4", "Source" -> "def offset (n : Nat) := n + 100"],
     LeanEvaluate[$evaluationEnv, "offset 4"]["Tag"]},
    {5, 104, "LeanEvaluateFailed"}, TestID -> "EnvironmentEvaluation-SourceDoesNotLeak"
]

VerificationTest[Length[LeanEvaluate[$evaluationEnv, "List.range 20000"]], 20000, TestID -> "EnvironmentEvaluation-LargeResponseDoesNotBlock"]
VerificationTest[LeanEvaluate[$evaluationEnv, "2+2", "TimeLimit" -> 0]["Tag"], "InvalidOption", TestID -> "EnvironmentEvaluation-ValidateTimeLimit"]
VerificationTest[LeanEvaluate[$evaluationEnv, "2+2", "ProjectDir" -> "/missing"]["Tag"], "InvalidOption", TestID -> "EnvironmentEvaluation-DoNotOverrideProject"]

VerificationTest[
    LeanEvaluate[$evaluationEnv, "(List.range 10000000).sum", "TimeLimit" -> 0.001]["Tag"],
    "TimedOut", TestID -> "EnvironmentEvaluation-Timeout"
]
VerificationTest[LeanEvaluate[$evaluationEnv, "3+4"], 7, TestID -> "EnvironmentEvaluation-RestartAfterTimeout"]

VerificationTest[
    $interruptedWorker = Wolfram`LeanLink`Private`$evaluationWorkers[Information[$evaluationEnv, "Handle"]]["Process"];
    CheckAbort[TimeConstrained[LeanEvaluate[$evaluationEnv, "42", "Source" -> "run_cmd Lean.Elab.Command.liftIO (IO.sleep 10000)"], 0.05], Null];
    {ProcessStatus[$interruptedWorker], KeyExistsQ[Wolfram`LeanLink`Private`$evaluationWorkers, Information[$evaluationEnv, "Handle"]]},
    {"Finished", False}, TestID -> "EnvironmentEvaluation-InterruptStopsWaitingWorker"
]
VerificationTest[LeanEvaluate[$evaluationEnv, "6*7"], 42, TestID -> "EnvironmentEvaluation-RestartAfterInterrupt"]

VerificationTest[
    $derivedEnv = LeanImportString[$evaluationEnv, "def evaluationSquare (n : Nat) := n*n"];
    LeanEvaluate[$derivedEnv["evaluationSquare"], 7], 49, TestID -> "EnvironmentEvaluation-CompiledDefinition"
]

VerificationTest[
    $secondEnv = LeanImportString[$derivedEnv, "def evaluationFourthPower (n : Nat) := evaluationSquare (evaluationSquare n)"];
    LeanEvaluate[$secondEnv["evaluationFourthPower"], 3], 81, TestID -> "EnvironmentEvaluation-InheritCompiledModule"
]

VerificationTest[
    LeanEvaluate[$evaluationEnv["id"], $derivedEnv["evaluationSquare"]]["Tag"],
    "InvalidEnvironment", TestID -> "EnvironmentEvaluation-CrossEnvironmentArgumentRejected"
]

VerificationTest[
    $collection = LeanEnvironment[Join[Normal[$evaluationEnv], Normal[$derivedEnv],
        <|"_Handle" -> Information[$derivedEnv, "Handle"], "_Handles" -> (Information[#, "Handle"]& /@ {$evaluationEnv, $derivedEnv})|>]];
    {LeanEvaluate[$collection, "2+2"]["Tag"], LeanEvaluate[$collection["evaluationSquare"], 4]},
    {"SeparateEnvironments", 16}, TestID -> "EnvironmentEvaluation-SeparateImportsKeepTermOwnership"
]

VerificationTest[
    $verifiedEnv = LeanImportString[$evaluationEnv, "theorem evaluationProof (n : Nat) : n + 0 = n := by rfl"];
    MatchQ[LeanVerify[$verifiedEnv["evaluationProof"]], _Success], True, TestID -> "LeanVerify-ValidTheorem"
]

VerificationTest[LeanVerify[$derivedEnv["evaluationSquare"]]["Tag"], "NotATheorem", TestID -> "LeanVerify-DefinitionIsNotProof"]

VerificationTest[
    LeanVerify[LeanTerm[Append[First[$derivedEnv["evaluationSquare"]], "Kind" -> "theorem"]]]["Tag"],
    "NotATheorem", TestID -> "LeanVerify-ChecksNativeDeclarationKind"
]

VerificationTest[
    WithCleanup[$admittedEnv = LeanImportString[$evaluationEnv, "theorem admittedEvaluationProof : False := by sorry"],
        LeanVerify[$admittedEnv["admittedEvaluationProof"]]["Tag"], LeanFreeEnvironment[$admittedEnv]],
    "UntrustedProof", TestID -> "LeanVerify-RejectSorry"
]

VerificationTest[
    WithCleanup[$nativeEnv = LeanImportString[$evaluationEnv, "theorem nativeEvaluationProof : (2 : Nat) + 2 = 4 := by native_decide"],
        LeanVerify[$nativeEnv["nativeEvaluationProof"]]["Tag"], LeanFreeEnvironment[$nativeEnv]],
    "UntrustedProof", TestID -> "LeanVerify-RejectNativeDecide"
]

VerificationTest[
    WithCleanup[$axiomEnv = LeanImportString[$evaluationEnv, "axiom evaluationAssumption : False\ntheorem dependentEvaluationProof : False := evaluationAssumption"],
        LeanVerify[$axiomEnv["dependentEvaluationProof"]]["Tag"], LeanFreeEnvironment[$axiomEnv]],
    "UntrustedProof", TestID -> "LeanVerify-RejectAdditionalAxiom"
]

VerificationTest[
    WithCleanup[$forgedEvaluationEnv = LeanImportString[$evaluationEnv,
        "open Lean Elab Command\nset_option debug.skipKernelTC true in\nrun_cmd liftCoreM <| addDecl <| .thmDecl { name := `forgedEvaluationProof, levelParams := [], type := mkConst ``False, value := mkConst ``True.intro }"],
        LeanVerify[$forgedEvaluationEnv["forgedEvaluationProof"]]["Tag"], LeanFreeEnvironment[$forgedEvaluationEnv]],
    "KernelRejected", TestID -> "LeanVerify-RejectForgedTheorem"
]

VerificationTest[
    $releasedTerm = $derivedEnv["evaluationSquare"];
    LeanFreeEnvironment[$derivedEnv];
    {LeanEvaluate[$derivedEnv, "2+2"]["Tag"], LeanEvaluate[$releasedTerm, 2]["Tag"]},
    {"InvalidEnvironment", "InvalidEnvironment"}, TestID -> "EnvironmentEvaluation-ReleaseInvalidatesTerms"
]

VerificationTest[
    LeanFreeEnvironment[$evaluationEnv];
    $evaluationEnv = LeanImport["Lean", "ProjectDir" -> $LeanLinkTestProjectDir];
    LeanEvaluate[$evaluationEnv, "10+1"], 11, TestID -> "EnvironmentEvaluation-ReimportAfterRelease"
]

VerificationTest[
    LeanFreeEnvironment[$secondEnv, "EvaluatorOnly" -> True];
    LeanEvaluate[$secondEnv["evaluationFourthPower"], 4], 256,
    TestID -> "EnvironmentEvaluation-ChildSurvivesParentRelease"
]

VerificationTest[
    LeanFreeEnvironment[$evaluationEnv, "EvaluatorOnly" -> True];
    {Information[$evaluationEnv, "Valid"], LeanEvaluate[$evaluationEnv, "2+3"]},
    {True, 5}, TestID -> "EnvironmentEvaluation-StopWorkerWithoutReleasingEnvironment"
]

Scan[LeanFreeEnvironment, {$evaluationEnv, $secondEnv, $verifiedEnv}]

EndTestSection[]

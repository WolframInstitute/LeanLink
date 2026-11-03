BeginTestSection["EvaluationStartup"]

VerificationTest[Wolfram`LeanLink`Private`$evaluationWorkers, <||>, TestID -> "EvaluationStartup-NeedsDoesNotStartWorker"]

VerificationTest[
    $startupEnv = LeanImport["Init", "ProjectDir" -> $LeanLinkTestProjectDir];
    $startupHandle = Information[$startupEnv, "Handle"];
    KeyExistsQ[Wolfram`LeanLink`Private`$evaluationWorkers, $startupHandle]
    ,
    False
    ,
    TestID -> "EvaluationStartup-ImportIsLazyByDefault"
]

(* preparing makes the state evaluations start from in the shim, and starts no process *)
VerificationTest[
    $startupEnv = LeanImport["Init", "ProjectDir" -> $LeanLinkTestProjectDir, "PrepareEvaluation" -> True];
    {Information[$startupEnv, "Handle"] === $startupHandle, Wolfram`LeanLink`Private`$evaluationWorkers, LeanEvaluate[$startupEnv["Nat.add"], 17, 25]}
    ,
    {True, <||>, 42}
    ,
    TestID -> "EvaluationStartup-PreparedImportIsReady"
]

VerificationTest[
    $startupDerived = LeanImportString[$startupEnv, "def startupSquare (n : Nat) := n*n", "PrepareEvaluation" -> True];
    LeanEvaluate[$startupDerived["startupSquare"], 7]
    ,
    49
    ,
    TestID -> "EvaluationStartup-PrepareCompiledSource"
]

VerificationTest[
    $startupHandles = Keys[Wolfram`LeanLink`Private`$handleSource];
    Quiet[LeanImport["NoSuchStartupModule", "ProjectDir" -> $LeanLinkTestProjectDir, "PrepareEvaluation" -> True]];
    Keys[Wolfram`LeanLink`Private`$handleSource] === $startupHandles
    ,
    True
    ,
    TestID -> "EvaluationStartup-FailedImportKeepsHandles"
]

VerificationTest[
    $startupHandles = Keys[Wolfram`LeanLink`Private`$handleSource];
    CheckAbort[
        Wolfram`LeanLink`Private`withEvaluationPreparation[
            LeanImportString["def startupAborted := 1"];
            Abort[]
            ,
            True
        ]
        ,
        Null
    ];
    Keys[Wolfram`LeanLink`Private`$handleSource] === $startupHandles
    ,
    True
    ,
    TestID -> "EvaluationStartup-AbortedImportReleasesNewHandles"
]

(* an environment from the cache keeps its handle when its preparation times out; Init's state needs Lean's JSON
   modules imported again, which takes longer than the limit *)
VerificationTest[
    LeanFreeEnvironment[$startupEnv, "EvaluatorOnly" -> True];
    $startupOptions = Options[LeanEvaluate];
    WithCleanup[
        SetOptions[LeanEvaluate, "TimeLimit" -> 0.000001],
        $startupTimeout = LeanImport["Init", "ProjectDir" -> $LeanLinkTestProjectDir, "PrepareEvaluation" -> True],
        Options[LeanEvaluate] = $startupOptions
    ];
    {$startupTimeout["Tag"], Information[$startupEnv, "Valid"]}
    ,
    {"TimedOut", True}
    ,
    TestID -> "EvaluationStartup-TimeoutPreservesBorrowedEnvironment"
]

VerificationTest[
    $startupHandles = Keys[Wolfram`LeanLink`Private`$handleSource];
    $startupDirectories = FileNames["leanlink_*", $TemporaryDirectory];
    WithCleanup[
        SetOptions[LeanEvaluate, "TimeLimit" -> 0.000001],
        $startupTimeout = LeanImportString["def startupTimeoutValue := 42", "PrepareEvaluation" -> True],
        Options[LeanEvaluate] = $startupOptions
    ];
    {$startupTimeout["Tag"], Keys[Wolfram`LeanLink`Private`$handleSource] === $startupHandles, Complement[FileNames["leanlink_*", $TemporaryDirectory], $startupDirectories]}
    ,
    {"TimedOut", True, {}}
    ,
    TestID -> "EvaluationStartup-TimeoutReleasesOwnedEnvironmentAndFiles"
]

VerificationTest[LeanEvaluate[$startupEnv, "20+22"], 42, TestID -> "EvaluationStartup-EvaluateAfterPreparationTimeout"]

(* an isolated evaluator starts on its first use, and one that cannot start leaves the environment usable *)
VerificationTest[
    {LeanEvaluate[$startupEnv, "21*2", "Isolated" -> True], ProcessStatus[Wolfram`LeanLink`Private`$evaluationWorkers[$startupHandle]["Process"]]},
    {42, "Running"},
    TestID -> "EvaluationStartup-IsolatedEvaluatorStartsOnUse"
]

VerificationTest[
    LeanFreeEnvironment[$startupEnv, "EvaluatorOnly" -> True];
    Block[{Wolfram`LeanLink`Private`evaluatorCommand = Function[toolchain, {Wolfram`LeanLink`Private`leanProgram[FileNameJoin[{toolchain, "bin"}], "lean"], "--version"}]},
        $startupFailed = LeanEvaluate[$startupEnv, "1", "Isolated" -> True]
    ];
    {$startupFailed["Tag"], Information[$startupEnv, "Valid"], KeyExistsQ[Wolfram`LeanLink`Private`$evaluationWorkers, $startupHandle], LeanEvaluate[$startupEnv, "2"]}
    ,
    {"LeanEvaluateFailed", True, False, 2}
    ,
    TestID -> "EvaluationStartup-DeadWorkerPreservesEnvironment"
]

VerificationTest[LeanImport["ProjectDir" -> $LeanLinkTestProjectDir, "PrepareEvaluation" -> True]["Tag"], "SeparateEnvironments", TestID -> "EvaluationStartup-DiscoveryIsNotPrepared"]

VerificationTest[
    LeanEvaluate[$startupDerived["startupSquare"], 5, "Isolated" -> True];
    Scan[LeanFreeEnvironment, {$startupEnv, $startupDerived}];
    Wolfram`LeanLink`Private`$evaluationWorkers
    ,
    <||>
    ,
    TestID -> "EvaluationStartup-ReleaseStopsAllWorkers"
]

EndTestSection[]

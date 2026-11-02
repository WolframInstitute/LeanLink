BeginTestSection["EvaluationStartup"]

VerificationTest[Wolfram`LeanLink`Private`$evaluationWorkers, <||>, TestID -> "EvaluationStartup-NeedsDoesNotStartWorker"]

VerificationTest[
    $startupEnv = LeanImport["Init", "ProjectDir" -> $LeanLinkTestProjectDir];
    $startupHandle = Information[$startupEnv, "Handle"];
    KeyExistsQ[Wolfram`LeanLink`Private`$evaluationWorkers, $startupHandle],
    False, TestID -> "EvaluationStartup-ImportIsLazyByDefault"
]

VerificationTest[
    $startupEnv = LeanImport["Init", "ProjectDir" -> $LeanLinkTestProjectDir, "PrepareEvaluation" -> True];
    $startupWorker = Wolfram`LeanLink`Private`$evaluationWorkers[$startupHandle]["Process"];
    {ProcessStatus[$startupWorker], KeyExistsQ[Wolfram`LeanLink`Private`$evaluationWorkers[$startupHandle], "RequestID"], LeanEvaluate[$startupEnv["Nat.add"], 17, 25]},
    {"Running", False, 42}, TestID -> "EvaluationStartup-PreparedImportIsReady"
]

VerificationTest[
    LeanImport["Init", "ProjectDir" -> $LeanLinkTestProjectDir, "PrepareEvaluation" -> True, "Filter" -> "Nat.add"];
    Wolfram`LeanLink`Private`$evaluationWorkers[$startupHandle]["Process"] === $startupWorker,
    True, TestID -> "EvaluationStartup-ReusePreparedWorker"
]

VerificationTest[
    $startupDerived = LeanImportString[$startupEnv, "def startupSquare (n : Nat) := n*n", "PrepareEvaluation" -> True];
    {KeyExistsQ[Wolfram`LeanLink`Private`$evaluationWorkers, Information[$startupDerived, "Handle"]], LeanEvaluate[$startupDerived["startupSquare"], 7]},
    {True, 49}, TestID -> "EvaluationStartup-PrepareCompiledSource"
]

VerificationTest[
    $startupProcesses = Processes[];
    $startupHandles = Keys[Wolfram`LeanLink`Private`$handleSource];
    Quiet[LeanImport["NoSuchStartupModule", "ProjectDir" -> $LeanLinkTestProjectDir, "PrepareEvaluation" -> True]];
    {Keys[Wolfram`LeanLink`Private`$handleSource] === $startupHandles,
     Select[Complement[Processes[], $startupProcesses], ProcessStatus[#] === "Running"&]},
    {True, {}}, TestID -> "EvaluationStartup-FailedImportStopsPendingProcess"
]

VerificationTest[
    $startupProcesses = Processes[];
    CheckAbort[Wolfram`LeanLink`Private`withPreparedEvaluation[Abort[], {"Init"}, Wolfram`LeanLink`Private`resolveSearchPath[$LeanLinkTestProjectDir]], Null];
    Select[Complement[Processes[], $startupProcesses], ProcessStatus[#] === "Running"&],
    {}, TestID -> "EvaluationStartup-AbortedImportStopsPendingProcess"
]

VerificationTest[
    LeanFreeEnvironment[$startupEnv, "EvaluatorOnly" -> True];
    $startupOptions = Options[LeanEvaluate];
    WithCleanup[SetOptions[LeanEvaluate, "TimeLimit" -> 0.000001],
        $startupTimeout = LeanImport["Init", "ProjectDir" -> $LeanLinkTestProjectDir, "PrepareEvaluation" -> True],
        Options[LeanEvaluate] = $startupOptions];
    {$startupTimeout["Tag"], Information[$startupEnv, "Valid"], KeyExistsQ[Wolfram`LeanLink`Private`$evaluationWorkers, $startupHandle]},
    {"TimedOut", True, False}, TestID -> "EvaluationStartup-TimeoutPreservesBorrowedEnvironment"
]

VerificationTest[
    $startupHandles = Keys[Wolfram`LeanLink`Private`$handleSource];
    $startupDirectories = FileNames["leanlink_*", $TemporaryDirectory];
    WithCleanup[SetOptions[LeanEvaluate, "TimeLimit" -> 0.000001],
        $startupTimeout = LeanImportString["def startupTimeoutValue := 42", "PrepareEvaluation" -> True],
        Options[LeanEvaluate] = $startupOptions];
    {$startupTimeout["Tag"], Keys[Wolfram`LeanLink`Private`$handleSource] === $startupHandles,
     Complement[FileNames["leanlink_*", $TemporaryDirectory], $startupDirectories]},
    {"TimedOut", True, {}}, TestID -> "EvaluationStartup-TimeoutReleasesOwnedEnvironmentAndFiles"
]

VerificationTest[LeanEvaluate[$startupEnv, "20+22"], 42, TestID -> "EvaluationStartup-EvaluateAfterPreparationTimeout"]

VerificationTest[
    LeanFreeEnvironment[$startupEnv, "EvaluatorOnly" -> True];
    Block[{Wolfram`LeanLink`Private`evaluatorCommand = Function[toolchain, {Wolfram`LeanLink`Private`leanProgram[FileNameJoin[{toolchain, "bin"}], "lean"], "--version"}]},
        $startupFailed = LeanImport["Init", "ProjectDir" -> $LeanLinkTestProjectDir, "PrepareEvaluation" -> True]];
    {$startupFailed["Tag"], Information[$startupEnv, "Valid"], KeyExistsQ[Wolfram`LeanLink`Private`$evaluationWorkers, $startupHandle]},
    {"LeanEvaluateFailed", True, False}, TestID -> "EvaluationStartup-DeadWorkerPreservesBorrowedEnvironment"
]

VerificationTest[
    Block[{Wolfram`LeanLink`Private`evaluatorCommand = Function[toolchain,
        {Wolfram`LeanLink`Private`leanProgram[FileNameJoin[{toolchain, "bin"}], "lean"], "--run", FileNameJoin[{Wolfram`LeanLink`Private`$PacletRoot, "Assets", "code.lean"}], "evaluate"}]},
        LeanEvaluate[$startupEnv, "21*2"]],
    42, TestID -> "EvaluationStartup-SourceFallback"
]

VerificationTest[
    LeanImport["ProjectDir" -> $LeanLinkTestProjectDir, "PrepareEvaluation" -> True]["Tag"],
    "SeparateEnvironments", TestID -> "EvaluationStartup-DiscoveryDoesNotStartManyWorkers"
]

VerificationTest[
    Scan[LeanFreeEnvironment, {$startupEnv, $startupDerived}];
    Wolfram`LeanLink`Private`$evaluationWorkers,
    <||>, TestID -> "EvaluationStartup-ReleaseStopsAllWorkers"
]

EndTestSection[]

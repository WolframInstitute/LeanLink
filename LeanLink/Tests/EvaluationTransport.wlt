BeginTestSection["EvaluationTransport"]

transportProcess[] := StartProcess[{
    Wolfram`LeanLink`Private`leanProgram[FileNameJoin[{Wolfram`LeanLink`Private`leanToolchainDir[], "bin"}], "lean"],
    "--run", FileNameJoin[{Wolfram`LeanLink`Private`$PacletRoot, "Tests", "Fixtures", "EvaluationTransport.lean"}]
}]

transportResponse[process_, limit_ : 30] := Wolfram`LeanLink`Private`evaluatorResponse[process, "transport", AbsoluteTime[] + limit]

transportCall[process_, command_] := (WriteString[process, command <> "\n"]; transportResponse[process])

VerificationTest[
    $transportProcess = transportProcess[];
    transportResponse[$transportProcess]["value"], {42}, TestID -> "EvaluationTransport-Ready"
]

VerificationTest[
    transportCall[$transportProcess, "fragment"]["value"],
    {FromCharacterCode[{945, 19990, 128512, 10, 34, 92}]}, TestID -> "EvaluationTransport-FragmentedUnicodeReply"
]

VerificationTest[
    transportCall[$transportProcess, "large"]["value"], {Range[0, 199999]}, TestID -> "EvaluationTransport-ReplyLargerThanPipeBuffer"
]

VerificationTest[
    transportCall[$transportProcess, "stderr"]["value"], {42}, TestID -> "EvaluationTransport-DrainLargeStderrBeforeReply"
]

VerificationTest[
    transportCall[$transportProcess, "noise"]["value"], {42}, TestID -> "EvaluationTransport-IgnoreDiagnosticsAndOtherRequests"
]

VerificationTest[
    transportCall[$transportProcess, "again"]["value"], {42}, TestID -> "EvaluationTransport-ReuseAfterLargeAndFragmentedReplies"
]

Quiet[KillProcess[$transportProcess]]

VerificationTest[
    WithCleanup[
        $transportProcess = transportProcess[],
        transportResponse[$transportProcess];
        $transportFailure = transportCall[$transportProcess, "crash"];
        {$transportFailure["Tag"], StringStartsQ[$transportFailure["Output"], "worker stopped: "], StringLength[$transportFailure["Output"]] <= 4096 + StringLength["unfinished reply"]},
        Quiet[KillProcess[$transportProcess]]
    ],
    {"LeanEvaluateFailed", True, True}, TestID -> "EvaluationTransport-WorkerExitKeepsBoundedDiagnostics"
]

VerificationTest[
    Table[
        WithCleanup[
            process = transportProcess[],
            transportResponse[process];
            WriteString[process, command <> "\n"];
            transportResponse[process, 0.05]["Tag"],
            Quiet[KillProcess[process]]
        ],
        {command, {"idle", "partial", "flood"}}
    ],
    {"TimedOut", "TimedOut", "TimedOut"}, TestID -> "EvaluationTransport-DeadlineWithIdlePartialOrContinuousOutput"
]

EndTestSection[]

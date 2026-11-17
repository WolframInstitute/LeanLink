BeginTestSection["Toolchain"]

(* InstallLeanToolchain, and what installations share: progress, cancellation, the processes they start, downloads and
   the log. Every test replaces the processes, downloads and directories an installation would use, so none of them
   installs anything. *)

(* ---- Pins ---- *)

VerificationTest[
    With[{pins = Import[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Elan"], "RawJSON"]},
        pins["ElanVersion"] === "4.2.4" && Length[pins["ElanArchives"]] === 5 && AllTrue[
            Values[pins["ElanArchives"]],
            StringStartsQ[#["URL"], "https://github.com/leanprover/elan/releases/download/v4.2.4/"] && StringMatchQ[#["SHA256"], RegularExpression["[0-9a-f]{64}"]]&
        ]
    ],
    True,
    TestID -> "Toolchain-ElanInstallersPinned"
]

VerificationTest[Wolfram`LeanLink`Private`leanToolchainName[], "leanprover/lean4:v4.35.0", TestID -> "Toolchain-Name"]

(* ---- Options and callbacks ---- *)

VerificationTest[InstallLeanToolchain["Unknown" -> True]["Tag"], "InvalidOption", TestID -> "Toolchain-UnknownOptionRejected"]

VerificationTest[InstallLeanToolchain["ProgressFunction" -> 42]["Tag"], "InvalidOption", TestID -> "Toolchain-ProgressFunctionChecked"]

VerificationTest[
    Block[{Wolfram`LeanLink`Private`installToolchain = (Throw["Unexpected installation"]&)}, InstallLeanToolchain["CancellationFunction" -> (True&)]["Tag"]],
    "InstallCancelled",
    TestID -> "Toolchain-CancelledBeforeAnyWork"
]

VerificationTest[
    Wolfram`LeanLink`Private`installVersionQ @@@ {{"1.2.5", "1.2.5"}, {"1.2.10", "1.2.5"}, {"1.2.4", "1.2.5"}},
    {True, True, False},
    TestID -> "Toolchain-VersionsCompareNumerically"
]

(* ---- The toolchain ---- *)

(* an installed toolchain is used as it is: no process, no download *)

VerificationTest[
    Module[{directory = CreateDirectory[], result},
        CreateDirectory[FileNameJoin[{directory, "bin"}]];
        CreateFile[Wolfram`LeanLink`Private`leanProgram[FileNameJoin[{directory, "bin"}], "lean"]];
        WithCleanup[
            result = Block[
                {
                    Wolfram`LeanLink`Private`leanToolchainPath = (directory&),
                    StartProcess = (Throw["Unexpected process"]&),
                    URLDownload = (Throw["Unexpected download"]&)
                },
                Reap[InstallLeanToolchain["ProgressFunction" -> Function[{stage, fraction}, Sow[stage]]]]
            ];
            result === {File[directory], {{"Preparing..."}}}
            ,
            DeleteDirectory[directory, DeleteContents -> True]
        ]
    ],
    True,
    TestID -> "Toolchain-InstalledStartsNoProcess"
]

(* a missing toolchain is installed with elan, which is given the toolchain's name *)

VerificationTest[
    Module[{directory = CreateDirectory[], lean, result},
        lean = Wolfram`LeanLink`Private`leanProgram[FileNameJoin[{directory, "bin"}], "lean"];
        WithCleanup[
            result = Block[
                {
                    Wolfram`LeanLink`Private`leanToolchainPath = (directory&),
                    Wolfram`LeanLink`Private`installElan = ("/elan"&),
                    Wolfram`LeanLink`Private`installRun = Function[{command, workingDirectory},
                        Sow[command];
                        CreateDirectory[DirectoryName[lean]];
                        CreateFile[lean];
                        <|"ExitCode" -> 0, "StandardOutput" -> "", "StandardError" -> ""|>
                    ]
                },
                Reap[InstallLeanToolchain[]]
            ];
            result === {File[directory], {{{"/elan", "toolchain", "install", "leanprover/lean4:v4.35.0"}}}}
            ,
            DeleteDirectory[directory, DeleteContents -> True]
        ]
    ],
    True,
    TestID -> "Toolchain-InstalledWithElan"
]

VerificationTest[
    Block[
        {
            Wolfram`LeanLink`Private`leanToolchainPath = ("/missing-toolchain"&),
            Wolfram`LeanLink`Private`installElan = ("/elan"&),
            Wolfram`LeanLink`Private`installRun = (<|"ExitCode" -> 1, "StandardOutput" -> "", "StandardError" -> "no network"|>&)
        },
        InstallLeanToolchain[]["Tag"]
    ],
    "ToolchainInstallFailed",
    TestID -> "Toolchain-FailedInstallationReported"
]

(* ---- elan and downloads ---- *)

VerificationTest[
    Block[
        {
            Wolfram`LeanLink`Private`elanExecutable = ("/existing/elan"&),
            Wolfram`LeanLink`Private`installRun = (<|"ExitCode" -> 0, "StandardOutput" -> "elan 4.2.4\n"|>&),
            Wolfram`LeanLink`Private`installDownload = (Throw["Unexpected download"]&)
        },
        Wolfram`LeanLink`Private`installElan[]
    ],
    "/existing/elan",
    TestID -> "Toolchain-WorkingElanReused"
]

VerificationTest[
    Module[{directory = CreateDirectory[], elan},
        CreateDirectory[FileNameJoin[{directory, "bin"}]];
        elan = Wolfram`LeanLink`Private`leanProgram[FileNameJoin[{directory, "bin"}], "elan"];
        Export[elan, "fixture", "Text"];
        WithCleanup[
            Block[{Wolfram`LeanLink`Private`elanHome = (directory&)}, Wolfram`LeanLink`Private`elanExecutable[]] === elan,
            DeleteDirectory[directory, DeleteContents -> True]
        ]
    ],
    True,
    TestID -> "Toolchain-ElanHomeBeforePath"
]

VerificationTest[
    Module[{directory = CreateDirectory[], file, asset},
        file = FileNameJoin[{directory, "archive"}];
        Export[file, "verified archive fixture", "Text"];
        asset = <|"URL" -> "https://example.invalid/archive", "SHA256" -> IntegerString[FileHash[file, "SHA256"], 16, 64]|>;
        WithCleanup[
            Block[{URLDownload = (Throw["Unexpected download"]&)}, Wolfram`LeanLink`Private`installDownload[asset, file]] === file,
            DeleteDirectory[directory, DeleteContents -> True]
        ]
    ],
    True,
    TestID -> "Toolchain-VerifiedDownloadReused"
]

VerificationTest[
    Block[{Wolfram`LeanLink`Private`$installCancellation = (True&), URLDownload = (Throw["Unexpected download"]&)},
        Catch[Wolfram`LeanLink`Private`installDownload[<||>, "unused"], "LeanLinkInstall"]["Tag"]
    ],
    "InstallCancelled",
    TestID -> "Toolchain-CancellationBeforeDownload"
]

(* a download that does not match its pinned checksum is not kept *)

VerificationTest[
    Module[{directory = CreateDirectory[], file, result},
        file = FileNameJoin[{directory, "archive"}];
        WithCleanup[
            result = Block[{URLDownload = Function[{url, target}, Export[target, "tampered", "Text"]; File[target]]},
                Catch[Wolfram`LeanLink`Private`installDownload[<|"URL" -> "https://example.invalid/archive", "SHA256" -> StringRepeat["0", 64]|>, file], "LeanLinkInstall"]
            ];
            {result["Tag"], FileExistsQ[file]}
            ,
            DeleteDirectory[directory, DeleteContents -> True]
        ]
    ],
    {"DownloadChecksum", False},
    TestID -> "Toolchain-DownloadKeptOnlyWithItsChecksum"
]

(* ---- The environment of child processes ---- *)

VerificationTest[
    Module[{before = GetEnvironment[], environment},
        environment = Block[{Wolfram`LeanLink`Private`elanHome = ("/local/elan"&)},
            Wolfram`LeanLink`Private`installEnvironment[{"/local/first", "/local/second", "/local/first"}, <|"LEANLINK_TEST" -> "child-only"|>]
        ];
        {environment["ELAN_HOME"], environment["LEANLINK_TEST"], environment["PATH"], GetEnvironment[] === before}
    ],
    {"/local/elan", "child-only", StringRiffle[{"/local/first", "/local/second"}, Wolfram`LeanLink`Private`$searchPathSeparator], True},
    TestID -> "Toolchain-EnvironmentOnlyForChildProcesses"
]

VerificationTest[
    Block[{GetEnvironment = ({"Path" -> "/windows", "LEAN_PATH" -> "/lean", "HOME" -> "/home"}&)},
        Select[Keys[Wolfram`LeanLink`Private`installEnvironment[{"/tools"}]], MemberQ[{"PATH", "LEAN_PATH"}, ToUpperCase[#]]&]
    ],
    {"PATH"},
    TestID -> "Toolchain-EnvironmentHasOnePathAndNoLeanPath"
]

(* ---- The log ---- *)

(* the log keeps the bytes a process wrote, a UTF-8 check mark among them, and the installation's own text as UTF-8 *)

VerificationTest[
    Module[{directory = CreateDirectory[], file, stream},
        file = FileNameJoin[{directory, "install.log"}];
        stream = OpenWrite[file, BinaryFormat -> True];
        WithCleanup[
            Block[{Wolfram`LeanLink`Private`$installLog = stream},
                Wolfram`LeanLink`Private`installLogText["lake build \[RightArrow] " <> FromCharacterCode[8469] <> "\n"];
                Wolfram`LeanLink`Private`installLog[FromCharacterCode[{226, 156, 148}] <> " built\n"]
            ];
            Close[stream];
            BinaryReadList[file, "Byte"] === ToCharacterCode["lake build \[RightArrow] " <> FromCharacterCode[8469] <> "\n" <> FromCharacterCode[10004] <> " built\n", "UTF-8"]
            ,
            DeleteDirectory[directory, DeleteContents -> True]
        ]
    ],
    True,
    TestID -> "Toolchain-LogKeepsBytesAndUTF8"
]

(* ---- Processes ---- *)

(* a cancelled installation starts no process *)

VerificationTest[
    Block[{Wolfram`LeanLink`Private`$installCancellation = (True&), RunProcess = (Throw["Unexpected process"]&)},
        Catch[Wolfram`LeanLink`Private`installRun[{"/bin/echo"}, Directory[]], "LeanLinkInstall"]["Tag"]
    ],
    "InstallCancelled",
    TestID -> "Process-NotStartedOnceCancelled"
]

(* kill -0 also succeeds for a Linux zombie waiting for its parent, so /proc is read on Linux. An unknown or live state
   fails the cleanup tests. *)

installerProcessState[pid_String] := Module[{file, status, states, result},
    If[ StringStartsQ[$SystemID, "Linux"],
        file = FileNameJoin[{"/proc", pid, "status"}];
        status = Quiet[Check[ReadString[file], $Failed]];
        states = If[StringQ[status], StringCases[status, RegularExpression["(?m)^State:\\s+([A-Za-z])"] -> "$1"], {}];
        Return[If[Length[states] === 1, First[states], If[DirectoryQ[DirectoryName[file]], "Unknown", "Absent"]], Module]
    ];
    result = Quiet[Check[RunProcess[{"/bin/kill", "-0", pid}], $Failed]];
    Which[
        AssociationQ[result] && result["ExitCode"] === 0,
            "Alive"
        ,
        AssociationQ[result] && result["ExitCode"] === 1,
            "Absent"
        ,
        True,
            "Unknown"
    ]
]

installerTerminatedQ[state_] := MemberQ[{"Absent", "Z", "X"}, state]

installerWaitForTermination[pids_List] := Module[{deadline = AbsoluteTime[] + 2, states},
    states = installerProcessState /@ pids;
    While[! AllTrue[states, installerTerminatedQ] && AbsoluteTime[] < deadline,
        Pause[0.02];
        states = installerProcessState /@ pids
    ];
    states
]

If[ $OperatingSystem =!= "Windows",
    VerificationTest[
        Module[{process, pid, before, after},
            process = StartProcess[{"/bin/sh", "-c", "printf '%s\\n' \"$$\"; exec sleep 30"}];
            WithCleanup[
                pid = TimeConstrained[ReadLine[process], 3, $TimedOut];
                If[! StringQ[pid] || ! StringMatchQ[pid, DigitCharacter ..], Return[{pid, False}, Module]];
                before = installerTerminatedQ[installerProcessState[pid]];
                KillProcess[process];
                after = AllTrue[installerWaitForTermination[{pid}], installerTerminatedQ];
                {before, after}
                ,
                If[ProcessStatus[process] === "Running", KillProcess[process]]
            ]
        ],
        {False, True},
        TestID -> "Process-CleanupCheckTellsLiveFromTerminated"
    ];
    (* The process starts a child and a grandchild, each of which writes its own PID. The time limit, an abort as the
       user's is, stops all three, and nothing else. *)
    VerificationTest[
        Module[{directory = CreateDirectory[], files, result, pids = {}, states},
            files = FileNameJoin[{directory, #}]& /@ {"child", "grandchild"};
            WithCleanup[
                result = Wolfram`LeanLink`Private`installRun[
                    Join[{"/bin/sh", "-c", "sh -c 'sleep 30 & printf \"%s\\n\" \"$!\" > \"$1\"; wait' sh \"$2\" & printf '%s\\n' \"$!\" > \"$1\"; wait", "sh"}, files],
                    directory,
                    Automatic,
                    1
                ];
                pids = Select[StringTrim[Import[#, "Text"]]& /@ Select[files, FileExistsQ], StringMatchQ[#, DigitCharacter ..]&];
                states = installerWaitForTermination[pids];
                {result, Length[pids], AllTrue[states, installerTerminatedQ]}
                ,
                Scan[Quiet[RunProcess[{"/bin/kill", "-KILL", #}]]&, pids];
                DeleteDirectory[directory, DeleteContents -> True]
            ]
        ],
        {$TimedOut, 2, True},
        TestID -> "Process-TimeLimitStopsProcessAndDescendants"
    ];
    (* both pipes are read while the process runs, so a large output on each does not block it *)
    VerificationTest[
        Module[{out = StringRepeat["o", 256], err = StringRepeat["e", 256]},
            KeyTake[
                Wolfram`LeanLink`Private`installRun[
                    {"/bin/sh", "-c", "i=0; while [ $i -lt 4096 ]; do printf '" <> out <> "'; printf '" <> err <> "' >&2; i=$((i+1)); done; exit 7"},
                    Directory[]
                ],
                {"ExitCode", "StandardOutput", "StandardError"}
            ] === <|"ExitCode" -> 7, "StandardOutput" -> StringRepeat[out, 4096], "StandardError" -> StringRepeat[err, 4096]|>
        ],
        True,
        TestID -> "Process-LargeOutputOnBothStreams"
    ]
]

EndTestSection[]

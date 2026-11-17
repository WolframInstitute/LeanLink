BeginTestSection["Mathlib"]

(* InstallMathlib and MathlibInstallation. Every test but the last few replaces the processes and directories an
   installation would use, so none of them installs anything; the last few use an installed mathlib when there is one,
   in the default directory or in LEANLINK_MATHLIB_DIRECTORY. *)

(* ---- Pins ---- *)

VerificationTest[
    KeyTake[MathlibInstallation[], {"Toolchain", "Revision"}],
    <|"Toolchain" -> "leanprover/lean4:v4.35.0", "Revision" -> "56a005855ea17e0b0958f73ec801ae140b0a1679"|>,
    TestID -> "Mathlib-PinnedRelease"
]

VerificationTest[
    MathlibInstallation[]["Directory"],
    FileNameJoin[{$UserBaseDirectory, "ApplicationData", "LeanLink", "Mathlib", "v4.35.0"}],
    TestID -> "Mathlib-DefaultDirectory"
]

VerificationTest[
    Keys[MathlibInstallation[]],
    {"Status", "Directory", "Toolchain", "Revision", "DocumentationURL", "Executables", "OtherVersions"},
    TestID -> "Mathlib-InstallationKeys"
]

(* The project requires Mathlib at the tag of LeanLink's toolchain, and its manifest, which Lake wrote, pins Mathlib at
   that tag and every package by commit *)

VerificationTest[
    Module[{project = PacletObject["Wolfram/LeanLink"]["AssetLocation", "Mathlib"], lakefile, manifest, mathlib},
        lakefile = ReadString[FileNameJoin[{project, "lakefile.toml"}]];
        manifest = Import[FileNameJoin[{project, "lake-manifest.json"}], "RawJSON"];
        mathlib = SelectFirst[manifest["packages"], #["name"] === "mathlib"&];
        {
            StringContainsQ[lakefile, "rev = \"" <> Wolfram`LeanLink`Private`$LeanToolchainVersion <> "\""],
            StringContainsQ[lakefile, "name = \"" <> manifest["name"] <> "\""],
            mathlib["inputRev"] === Wolfram`LeanLink`Private`$LeanToolchainVersion,
            mathlib["url"] === "https://github.com/leanprover-community/mathlib4",
            AllTrue[manifest["packages"], #["type"] === "git" && StringMatchQ[#["rev"], RegularExpression["[0-9a-f]{40}"]]&]
        }
    ],
    {True, True, True, True, True},
    TestID -> "Mathlib-ProjectPinsTheToolchainsRelease"
]

(* ---- Options and callbacks ---- *)

VerificationTest[MathlibInstallation["Directory" -> 42]["Tag"], "InvalidOption", TestID -> "Mathlib-DirectoryChecked"]

VerificationTest[InstallMathlib["Unknown" -> True]["Tag"], "InvalidOption", TestID -> "Mathlib-UnknownOptionRejected"]

VerificationTest[InstallMathlib["ProgressFunction" -> 42]["Tag"], "InvalidOption", TestID -> "Mathlib-ProgressFunctionChecked"]

VerificationTest[InstallMathlib["RemoveOtherVersions" -> "yes"]["Tag"], "InvalidOption", TestID -> "Mathlib-RemoveOtherVersionsChecked"]

VerificationTest[InstallMathlib["CancellationFunction" -> (Missing["Unknown"]&)]["Tag"], "InvalidCallback", TestID -> "Mathlib-CancellationMustBeBoolean"]

VerificationTest[
    With[
        {
            result = Block[
                {
                    Wolfram`LeanLink`Private`installToolchain = (Throw["Unexpected installation"]&),
                    Wolfram`LeanLink`Private`mathlibExecutable = (Throw["Unexpected process lookup"]&)
                },
                InstallMathlib["CancellationFunction" -> (True&)]
            ]
        },
        {result["Tag"], result["MessageParameters"]}
    ],
    {"InstallCancelled", {"InstallMathlib"}},
    TestID -> "Mathlib-CancelledBeforeAnyWork"
]

(* ---- Installation ---- *)

VerificationTest[
    Block[
        {
            Wolfram`LeanLink`Private`installToolchain = (Throw["Unexpected toolchain check"]&),
            Wolfram`LeanLink`Private`mathlibRequireTool = (Throw["Unexpected tool check"]&),
            Wolfram`LeanLink`Private`mathlibInstallationReadyQ = (True&),
            RunProcess = (Throw["Unexpected process"]&)
        },
        With[{result = Reap[InstallMathlib["ProgressFunction" -> Function[{stage, fraction}, Sow[{stage, fraction}]]]]},
            {MatchQ[First[result], _File], Last[result]}
        ]
    ],
    {True, {{{"Checking...", None}}}},
    TestID -> "Mathlib-ReadyInstallationStartsNoProcess"
]

(* An installation with the toolchain and the tools replaced, and installRun replaced by run, which is given
   {command, working directory} and Sows it. The result, what was run, and the directory. *)

installationFixture[run_, ready_ : (False&)] := Module[{temporary = CreateDirectory[], directory, result, commands},
    directory = FileNameJoin[{temporary, "mathlib"}];
    WithCleanup[
        {result, commands} = Block[
            {
                Wolfram`LeanLink`Private`installToolchain = ("/toolchain"&),
                Wolfram`LeanLink`Private`leanToolchainPath = ("/toolchain"&),
                Wolfram`LeanLink`Private`mathlibRequireTool = ("/fixture/" <> #&),
                Wolfram`LeanLink`Private`mathlibInstallationReadyQ = ready,
                Wolfram`LeanLink`Private`installRun = (Sow[{#1, #2}]; run[#1, #2])&
            },
            Reap[InstallMathlib["Directory" -> directory]]
        ];
        <|
            "Result" -> result,
            "Commands" -> Replace[commands, {{c_} :> c, {} -> {}}],
            "Directory" -> directory,
            "ProjectFiles" -> projectFilesQ[directory],
            "Record" -> Quiet[Check[Import[FileNameJoin[{directory, "leanlink-mathlib.json"}], "RawJSON"], None]],
            "Log" -> Quiet[Check[ReadString[FileNameJoin[{directory, "leanlink-mathlib.log"}]], None]],
            "Package" -> DirectoryQ[FileNameJoin[{directory, ".lake", "packages", "mathlib"}]]
        |>
        ,
        DeleteDirectory[temporary, DeleteContents -> True]
    ]
]

(* the project's files in directory are the paclet's, byte for byte *)

projectFilesQ[directory_String] := AllTrue[
    Normal[Wolfram`LeanLink`Private`mathlibProjectFiles[]],
    With[{file = FileNameJoin[{directory, First[#]}]}, FileExistsQ[file] && FileHash[file] === FileHash[Last[#]]]&
]

(* a run where every command succeeds, and git clone checks out commit, as a clone of a tag does: HEAD names it *)

cloneAt[commit_String][command_List, workingDirectory_String] := (
    If[ MemberQ[command, "clone"],
        CreateDirectory[FileNameJoin[{Last[command], ".git"}], CreateIntermediateDirectories -> True];
        Export[FileNameJoin[{Last[command], ".git", "HEAD"}], commit <> "\n", "Text"]
    ];
    <|"ExitCode" -> 0, "StandardOutput" -> "", "StandardError" -> ""|>
)

pinnedClone = cloneAt[Wolfram`LeanLink`Private`mathlibPin[]["rev"]]

(* The project's files are copied in; Mathlib's tag is cloned where Lake keeps the package; lake exe cache get and
   lake build Mathlib run in the directory with the toolchain's own lake; the commands go to the log; the record comes
   last *)

VerificationTest[
    Module[{checks = 0, fixture, lake, package},
        fixture = installationFixture[pinnedClone, (checks++ > 0&)];
        lake = Wolfram`LeanLink`Private`leanProgram[FileNameJoin[{"/toolchain", "bin"}], "lake"];
        package = FileNameJoin[{fixture["Directory"], ".lake", "packages", "mathlib"}];
        {
            fixture["Result"] === File[fixture["Directory"]],
            fixture["Commands"] === {
                {{"/fixture/git", "-c", "advice.detachedHead=false", "clone", "--depth", "1", "--branch", "v4.35.0", "https://github.com/leanprover-community/mathlib4", package}, fixture["Directory"]},
                {{lake, "exe", "cache", "get"}, fixture["Directory"]},
                {{lake, "build", "Mathlib"}, fixture["Directory"]}
            },
            fixture["ProjectFiles"],
            fixture["Record"] === Wolfram`LeanLink`Private`mathlibRecord[],
            fixture["Log"] === StringRiffle[{"/fixture/git", "-c", "advice.detachedHead=false", "clone", "--depth", "1", "--branch", "v4.35.0", "https://github.com/leanprover-community/mathlib4", package}, " "] <> "\n" <> lake <> " exe cache get\n" <> lake <> " build Mathlib\n",
            fixture["Package"]
        }
    ],
    {True, True, True, True, True, True},
    TestID -> "Mathlib-InstallationClonesThenRunsCacheGetAndBuild"
]

(* a clone at another commit is removed, and Lake fetches the pinned commit itself *)

VerificationTest[
    Module[{checks = 0, fixture},
        fixture = installationFixture[cloneAt[StringRepeat["0", 40]], (checks++ > 0&)];
        {MatchQ[fixture["Result"], _File], Rest[First[#]][[;; 2]]& /@ Rest[fixture["Commands"]], fixture["Package"]}
    ],
    {True, {{"exe", "cache"}, {"build", "Mathlib"}}, False},
    TestID -> "Mathlib-CloneAtAnotherCommitLeftToLake"
]

(* an installation that stops keeps its project, for the run that resumes it, removes a clone that did not finish, and
   leaves no record *)

VerificationTest[
    With[{fixture = installationFixture[Throw[Wolfram`LeanLink`Private`installFailure["InstallCancelled", "Cancelled."], "LeanLinkInstall"]&]},
        {fixture["Result"]["Tag"], fixture["ProjectFiles"], fixture["Package"], fixture["Record"]}
    ],
    {"InstallCancelled", True, False, None},
    TestID -> "Mathlib-StoppedInstallationKeepsItsProject"
]

VerificationTest[
    With[{fixture = installationFixture[<|"ExitCode" -> 1, "StandardOutput" -> "", "StandardError" -> "error: no network"|>&]},
        {
            fixture["Result"]["Tag"],
            fixture["Result"]["Log"] === File[FileNameJoin[{fixture["Directory"], "leanlink-mathlib.log"}]],
            MemberQ[fixture["Result"]["Command"], "clone"],
            fixture["Package"],
            fixture["Record"]
        }
    ],
    {"MathlibInstallFailed", True, True, False, None},
    TestID -> "Mathlib-FailedStepNamesTheLog"
]

VerificationTest[
    With[{fixture = installationFixture[Function[{command, workingDirectory}, If[MemberQ[command, "build"], <|"ExitCode" -> 1, "StandardOutput" -> "", "StandardError" -> "error"|>, pinnedClone[command, workingDirectory]]]]},
        {fixture["Result"]["Tag"], Rest[fixture["Result"]["Command"]], fixture["Package"], fixture["Record"]}
    ],
    {"MathlibInstallFailed", {"build", "Mathlib"}, True, None},
    TestID -> "Mathlib-FailedBuildKeepsWhatWasFetched"
]

(* a directory with other files, or a Lake project of its own such as a Mathlib checkout, is refused and left as it is *)

directoryInUseFixture[files_List] := Module[{directory = CreateDirectory[], result, before},
    Scan[Export[FileNameJoin[{directory, #}], "keep", "Text"]&, files];
    before = FileNames["*", directory];
    WithCleanup[
        result = Block[
            {
                Wolfram`LeanLink`Private`installToolchain = ("/toolchain"&),
                Wolfram`LeanLink`Private`mathlibRequireTool = (Null&),
                Wolfram`LeanLink`Private`mathlibInstallationReadyQ = (False&),
                Wolfram`LeanLink`Private`installRun = (Throw["Unexpected process"]&)
            },
            InstallMathlib["Directory" -> directory]
        ];
        {result["Tag"], FileNames["*", directory] === before, Union[Import[#, "Text"]& /@ before]}
        ,
        DeleteDirectory[directory, DeleteContents -> True]
    ]
]

VerificationTest[directoryInUseFixture[{"notes.txt"}], {"MathlibDirectoryInUse", True, {"keep"}}, TestID -> "Mathlib-OtherFilesKept"]

VerificationTest[directoryInUseFixture[{"lakefile.lean", "leanlink-mathlib.json"}], {"MathlibDirectoryInUse", True, {"keep"}}, TestID -> "Mathlib-LakeProjectKept"]

(* ---- Readiness ---- *)

(* An installation as InstallMathlib leaves it: the project's files, its record, and Mathlib's package with its build,
   beside a toolchain with lean; then without the file named, or with it changed *)

readinessFixture[change_ : None] := Module[{temporary = CreateDirectory[], directory, toolchain, build},
    directory = FileNameJoin[{temporary, "mathlib"}];
    toolchain = FileNameJoin[{temporary, "toolchain"}];
    build = FileNameJoin[{directory, ".lake", "packages", "mathlib", ".lake", "build", "lib", "lean"}];
    CreateDirectory[build, CreateIntermediateDirectories -> True];
    CreateFile[FileNameJoin[{build, "Mathlib.olean"}]];
    CreateDirectory[FileNameJoin[{toolchain, "bin"}], CreateIntermediateDirectories -> True];
    CreateFile[Wolfram`LeanLink`Private`leanProgram[FileNameJoin[{toolchain, "bin"}], "lean"]];
    KeyValueMap[CopyFile[#2, FileNameJoin[{directory, #1}]]&, Wolfram`LeanLink`Private`mathlibProjectFiles[]];
    Export[FileNameJoin[{directory, "leanlink-mathlib.json"}], Wolfram`LeanLink`Private`mathlibRecord[], "RawJSON"];
    Replace[change, {{"Delete", file_} :> DeleteFile[FileNameJoin[{temporary, file}]], {"Change", file_} :> Export[FileNameJoin[{temporary, file}], "changed", "Text"]}];
    WithCleanup[
        Block[{Wolfram`LeanLink`Private`leanToolchainPath = (toolchain&), RunProcess = (Throw["Unexpected process"]&)},
            Wolfram`LeanLink`Private`mathlibInstallationReadyQ[directory]
        ],
        DeleteDirectory[temporary, DeleteContents -> True]
    ]
]

VerificationTest[readinessFixture[], True, TestID -> "Mathlib-ReadyWithoutAnyProcess"]

VerificationTest[readinessFixture[{"Change", "mathlib/leanlink-mathlib.json"}], False, TestID -> "Mathlib-OtherRecordIsNotReady"]

VerificationTest[readinessFixture[{"Delete", "mathlib/.lake/packages/mathlib/.lake/build/lib/lean/Mathlib.olean"}], False, TestID -> "Mathlib-MissingBuildIsNotReady"]

VerificationTest[readinessFixture[{"Delete", Wolfram`LeanLink`Private`leanProgram["toolchain/bin", "lean"]}], False, TestID -> "Mathlib-MissingToolchainIsNotReady"]

(* ---- Git and curl ---- *)

VerificationTest[
    Module[{directory = FileNameJoin[{$TemporaryDirectory, "leanlink-never-created-" <> CreateUUID[]}], result},
        result = Block[
            {
                Wolfram`LeanLink`Private`installToolchain = ("/toolchain"&),
                Wolfram`LeanLink`Private`mathlibExecutable = (Missing["NotFound", #]&)
            },
            InstallMathlib["Directory" -> directory]
        ];
        {
            result["Tag"],
            result["MessageParameters"] === {Wolfram`LeanLink`Private`mathlibToolNeed["git"], Wolfram`LeanLink`Private`mathlibToolAdvice["git", $OperatingSystem]},
            FileExistsQ[directory]
        }
    ],
    {"GitUnavailable", True, False},
    TestID -> "Mathlib-MissingGitExplained"
]

VerificationTest[
    Block[
        {
            Wolfram`LeanLink`Private`installToolchain = ("/toolchain"&),
            Wolfram`LeanLink`Private`mathlibExecutable = ("/fixture/" <> #&),
            Wolfram`LeanLink`Private`mathlibGitWorkingQ = (True&),
            Wolfram`LeanLink`Private`mathlibCurlWorkingQ = (False&)
        },
        InstallMathlib[]["Tag"]
    ],
    "CurlUnavailable",
    TestID -> "Mathlib-UnusableCurlExplained"
]

If[ $OperatingSystem === "MacOSX",
    VerificationTest[
        Block[
            {
                Wolfram`LeanLink`Private`installRun = Function[{command, directory},
                    Sow[command];
                    <|"ExitCode" -> 1, "StandardOutput" -> "", "StandardError" -> "No developer directory"|>
                ]
            },
            Reap[Wolfram`LeanLink`Private`mathlibGitWorkingQ["/usr/bin/git"]]
        ],
        {False, {{{"/usr/bin/xcode-select", "-p"}}}},
        TestID -> "Mathlib-AppleGitLauncherNotRun"
    ]
]

(* any curl that runs with HTTPS: Mathlib's cache tool decides how to use it by its version *)

VerificationTest[
    Function[output,
        Block[{Wolfram`LeanLink`Private`installRun = (<|"ExitCode" -> 0, "StandardOutput" -> output|>&)}, Wolfram`LeanLink`Private`mathlibCurlWorkingQ["curl"]]
    ] /@ {"curl 7.61.1 (fixture)\nProtocols: file http https\n", "curl 8.23.0 (fixture)\nProtocols: file http\n"},
    {True, False},
    TestID -> "Mathlib-CurlNeedsHTTPS"
]

(* the processes find the toolchain's programs first, then Git and curl where InstallMathlib found them *)

VerificationTest[
    Block[
        {
            Wolfram`LeanLink`Private`leanToolchainPath = ("/toolchain"&),
            Wolfram`LeanLink`Private`pathDirectories = ({"/first", "/second"}&),
            Wolfram`LeanLink`Private`mathlibToolDirectories = ({"/git"}&)
        },
        Wolfram`LeanLink`Private`mathlibEnvironment[]["PATH"]
    ],
    StringRiffle[{FileNameJoin[{"/toolchain", "bin"}], "/first", "/second", "/git"}, Wolfram`LeanLink`Private`$searchPathSeparator],
    TestID -> "Mathlib-ChildPathHasTheToolchainFirst"
]

(* ---- Other versions ---- *)

(* Installations for v4.34.0 and the current toolchain, one of them outside the default directory, and a directory
   without a record *)

otherVersionsFixture[] := Module[{root = CreateDirectory[]},
    Scan[CreateDirectory[FileNameJoin[{root, #}]]&, {"v4.33.0", "v4.34.0", "v4.35.0", "elsewhere"}];
    Export[FileNameJoin[{root, "v4.34.0", "leanlink-mathlib.json"}], <|"Toolchain" -> "leanprover/lean4:v4.34.0"|>, "RawJSON"];
    Scan[Export[FileNameJoin[{root, #, "leanlink-mathlib.json"}], <|"Toolchain" -> "leanprover/lean4:v4.35.0"|>, "RawJSON"]&, {"v4.35.0", "elsewhere"}];
    root
]

VerificationTest[
    Module[{root = otherVersionsFixture[]},
        WithCleanup[
            Block[{Wolfram`LeanLink`Private`mathlibRoot = (root&)}, FileNameTake /@ MathlibInstallation[]["OtherVersions"]],
            DeleteDirectory[root, DeleteContents -> True]
        ]
    ],
    {"v4.34.0"},
    TestID -> "Mathlib-OtherVersionsByTheirRecord"
]

VerificationTest[
    Module[{root = otherVersionsFixture[]},
        WithCleanup[
            Block[{Wolfram`LeanLink`Private`mathlibRoot = (root&)}, Wolfram`LeanLink`Private`mathlibCleanOtherVersions[FileNameJoin[{root, "v4.35.0"}], False]];
            FileNameTake /@ FileNames["*", root]
            ,
            DeleteDirectory[root, DeleteContents -> True]
        ]
    ],
    {"elsewhere", "v4.33.0", "v4.34.0", "v4.35.0"},
    {InstallMathlib::other},
    TestID -> "Mathlib-OtherVersionsNamed"
]

(* only after an installation that succeeds, and only when asked *)

VerificationTest[
    Module[{root = otherVersionsFixture[], failed, kept},
        WithCleanup[
            Block[{Wolfram`LeanLink`Private`mathlibRoot = (root&)},
                failed = Block[{Wolfram`LeanLink`Private`installMathlib = (Wolfram`LeanLink`Private`installFailure["MathlibInstallFailed", "Failed."]&)}, InstallMathlib["RemoveOtherVersions" -> True]["Tag"]];
                kept = DirectoryQ[FileNameJoin[{root, "v4.34.0"}]];
                Block[{Wolfram`LeanLink`Private`installMathlib = (File[#]&)}, InstallMathlib["RemoveOtherVersions" -> True]]
            ];
            {failed, kept, FileNameTake /@ FileNames["*", root]}
            ,
            DeleteDirectory[root, DeleteContents -> True]
        ]
    ],
    {"MathlibInstallFailed", True, {"elsewhere", "v4.33.0", "v4.35.0"}},
    TestID -> "Mathlib-OtherVersionsRemovedWhenAsked"
]

(* ---- An installed mathlib ---- *)

$mathlibTestDirectory = Replace[Environment["LEANLINK_MATHLIB_DIRECTORY"], Except[_String] -> Automatic]

$mathlibInstallation = MathlibInstallation["Directory" -> $mathlibTestDirectory]

VerificationTest[
    If[ $mathlibInstallation["Status"] =!= "Ready",
        True
        ,
        $mathlibEnv = LeanImport["Mathlib.Data.Nat.Choose.Basic", "ProjectDir" -> $mathlibInstallation["Directory"]];
        LeanEvaluate[$mathlibEnv["Nat.choose"], 10, 4] === 210
    ],
    True,
    TestID -> "Mathlib-Installed-Evaluate"
]

VerificationTest[
    If[ $mathlibInstallation["Status"] =!= "Ready",
        True
        ,
        MatchQ[LeanVerify[LeanImportString[$mathlibEnv, "theorem chooseOneRight (n : Nat) : Nat.choose n 1 = n := Nat.choose_one_right n"]["chooseOneRight"]], _Success]
    ],
    True,
    TestID -> "Mathlib-Installed-Verify"
]

If[$mathlibInstallation["Status"] === "Ready", LeanFreeEnvironment[$mathlibEnv]]

EndTestSection[]

(* ::Package:: *)

(* Mathlib.wl -- InstallMathlib and MathlibInstallation: the Mathlib release built with the toolchain LeanLink's native
   library is built against, installed as a Lake project that requires it.

   The project is Assets/Mathlib: a lakefile that requires Mathlib at the tag of LeanLink's toolchain, and the
   lake-manifest.json that lake update wrote for it, which pins Mathlib and each package it uses by commit;
   update_mathlib.wls writes both. InstallMathlib copies them, with the paclet's lean-toolchain, into its directory and
   puts a shallow clone of Mathlib's tag where Lake keeps the package; lake exe cache get then fetches the other
   packages at their commits, with Mathlib's build cache, and lake build Mathlib checks it. Git and curl are the
   machine's own: Lake fetches packages with git, and Mathlib's cache tool runs git and curl itself. *)

BeginPackage["Wolfram`LeanLink`"];

InstallMathlib::usage = "InstallMathlib[] installs the Mathlib release for LeanLink's Lean toolchain, with the toolchain, and gives File[dir] for the Lake project that requires it. InstallMathlib[\"Directory\" -> dir] installs it in dir."

InstallMathlib::other = "Mathlib is also installed for other toolchains, which this version of LeanLink cannot load, in `1`. InstallMathlib[\"RemoveOtherVersions\" -> True] removes them."

MathlibInstallation::usage = "MathlibInstallation[] gives the status, directory and pinned versions of the Mathlib installation. MathlibInstallation[\"Directory\" -> dir] checks the installation in dir."

Begin["`Private`"];

(* ============================================================================ *)
(* The project                                                                  *)
(* ============================================================================ *)

(* The files InstallMathlib copies into its directory: the paclet's lean-toolchain, and the project's lakefile and
   manifest *)

mathlibProjectFiles[] := <|
    "lean-toolchain" -> FileNameJoin[{$PacletRoot, "lean-toolchain"}],
    "lakefile.toml" -> FileNameJoin[{$PacletRoot, "Assets", "Mathlib", "lakefile.toml"}],
    "lake-manifest.json" -> FileNameJoin[{$PacletRoot, "Assets", "Mathlib", "lake-manifest.json"}]
|>

(* Mathlib's entry in the manifest: its repository, the tag it is pinned at, and that tag's commit *)

mathlibPin[] := mathlibPin[] = SelectFirst[Import[mathlibProjectFiles[]["lake-manifest.json"], "RawJSON"]["packages"], #["name"] === "mathlib"&]

$mathlibDocumentation = "https://leanprover-community.github.io/mathlib4_docs/"

(* Mathlib tags each release with the version of the toolchain it is built with, v4.35.0 for leanprover/lean4:v4.35.0;
   the installation for each has a directory of its own *)

mathlibRoot[] := FileNameJoin[{$UserBaseDirectory, "ApplicationData", "LeanLink", "Mathlib"}]

mathlibDirectory[Automatic] := FileNameJoin[{mathlibRoot[], $LeanToolchainVersion}]

mathlibDirectory[directory_String] := ExpandFileName[directory]

mathlibDirectory[_] := installFailure["InvalidOption", "\"Directory\" must be Automatic or a directory."]

(* Mathlib itself, where Lake puts a package the project requires *)

mathlibPackageDirectory[directory_String] := FileNameJoin[{directory, ".lake", "packages", "mathlib"}]

(* The installation's own files in its directory: the record of a finished installation, and the output of its
   commands *)

$mathlibStamp = "leanlink-mathlib.json"

$mathlibLog = "leanlink-mathlib.log"

mathlibRecord[] := <|"Toolchain" -> $LeanToolchain, "Revision" -> mathlibPin[]["rev"], "ManifestSHA256" -> fileSHA256[mathlibProjectFiles[]["lake-manifest.json"]]|>

(* ============================================================================ *)
(* Git and curl                                                                 *)
(* ============================================================================ *)

(* Lake fetches the packages with git, and Mathlib's cache tool runs git and curl: those found first on the PATH of the
   processes InstallMathlib starts. Git for Windows is put on the PATH of processes started after it is installed, which
   a running kernel can predate, so its usual directories come last on that PATH. *)

mathlibToolDirectories[] := If[ $OperatingSystem === "Windows",
    Select[
        FileNameJoin[{#, "Git", "cmd"}]& /@ Select[{Environment["ProgramFiles"], Replace[Environment["LOCALAPPDATA"], local_String :> FileNameJoin[{local, "Programs"}]]}, StringQ],
        DirectoryQ
    ],
    {}
]

mathlibExecutable[name_String] := findExecutable[name, Join[pathDirectories[], mathlibToolDirectories[]]]

mathlibExecutables[] := <|
    "Elan" -> elanExecutable[],
    "Lake" -> With[{lake = toolchainProgram["lake"]}, If[FileExistsQ[lake], lake, Missing["NotInstalled", "lake"]]],
    "Git" -> mathlibExecutable["git"],
    "Curl" -> mathlibExecutable["curl"]
|>

(* The processes' PATH: the toolchain's programs first, as Lake runs them, then the directories mathlibExecutable
   searches, in its order *)

mathlibEnvironment[] := installEnvironment[Join[{FileNameJoin[{leanToolchainPath[], "bin"}]}, pathDirectories[], mathlibToolDirectories[]]]

(* Apple's /usr/bin/git is a launcher that can open the developer tools installer. It is run only when xcode-select
   names a developer directory. *)

mathlibGitWorkingQ[path_String] := Block[{result},
    If[ $OperatingSystem === "MacOSX" && path === "/usr/bin/git",
        result = TimeConstrained[installRun[{"/usr/bin/xcode-select", "-p"}, Directory[]], 10, $Failed];
        If[! AssociationQ[result] || result["ExitCode"] =!= 0, Return[False, Block]]
    ];
    result = TimeConstrained[installRun[{path, "--version"}, Directory[]], 10, $Failed];
    AssociationQ[result] && result["ExitCode"] === 0 && StringStartsQ[StringTrim[result["StandardOutput"]], "git version "]
]

mathlibGitWorkingQ[___] := False

(* Mathlib's cache tool takes curl 7.75 or later, with HTTPS; on Linux it fetches a newer curl of its own in place of an
   older one *)

mathlibCurlWorkingQ[path_String, system_String : $SystemID] := Block[{result, versions},
    result = TimeConstrained[installRun[{path, "--version"}, Directory[]], 10, $Failed];
    If[! AssociationQ[result] || result["ExitCode"] =!= 0, Return[False, Block]];
    versions = StringCases[result["StandardOutput"], RegularExpression["(?m)^curl ([0-9]+\\.[0-9]+\\.[0-9]+)"] -> "$1"];
    And[
        Length[versions] === 1,
        StringStartsQ[system, "Linux"] || installVersionQ[First[versions], "7.75.0"],
        StringContainsQ[result["StandardOutput"], RegularExpression["(?m)^Protocols:[^\\n]*\\bhttps\\b"]]
    ]
]

mathlibCurlWorkingQ[___] := False

(* What a tool is for, and how to install it, for the failure that names a missing one *)

mathlibToolNeed["git"] = "Git, which Lake fetches Mathlib and its packages with"

mathlibToolNeed["curl"] = "curl 7.75 or later with HTTPS, which Mathlib's cache tool downloads with"

mathlibToolAdvice["git", "MacOSX"] = "Install Apple's command line developer tools, which include Git, by running xcode-select --install in a terminal"

mathlibToolAdvice["git", "Windows"] = "Install Git for Windows from https://git-scm.com/download/win"

mathlibToolAdvice["git", _] = "Install Git with the system's package manager"

mathlibToolAdvice["curl", "Windows"] = "Install a current curl from https://curl.se/windows/ and put it on the PATH"

mathlibToolAdvice["curl", _] = "Install a current curl with the system's package manager"

mathlibRequireTool[name_String] := With[{path = mathlibExecutable[name]},
    If[ If[name === "git", mathlibGitWorkingQ[path], mathlibCurlWorkingQ[path]],
        path,
        Throw[
            installFailure[
                Capitalize[name] <> "Unavailable",
                "InstallMathlib needs `1`. `2`, then run InstallMathlib[] again.",
                <|"MessageParameters" -> {mathlibToolNeed[name], mathlibToolAdvice[name, $OperatingSystem]}, "Executable" -> path|>
            ],
            "LeanLinkInstall"
        ]
    ]
]

(* ============================================================================ *)
(* Readiness                                                                    *)
(* ============================================================================ *)

(* LeanLink can load the installation when its native library loads Lean's Init from the pinned toolchain. That runs no
   elan and compiles nothing, and once it has passed it holds for the rest of the kernel session. *)

$mathlibRuntimeReady = False

mathlibRuntimeReadyQ[] := TrueQ[$mathlibRuntimeReady] || With[{handle = Quiet[LeanLoadEnvironment[{"Init"}, FileNameJoin[{leanToolchainPath[], "lib", "lean"}]]]},
    If[ IntegerQ[handle] && handle > 0,
        LeanFreeEnvironment[handle];
        $mathlibRuntimeReady = True
        ,
        False
    ]
]

(* the project's files in directory are the paclet's, byte for byte *)

mathlibProjectFilesQ[directory_String] := AllTrue[
    Normal[mathlibProjectFiles[]],
    With[{file = FileNameJoin[{directory, First[#]}]}, FileExistsQ[file] && fileSHA256[file] === fileSHA256[Last[#]]]&
]

(* Ready: the record and the project's files are the paclet's, Mathlib is checked out at the pinned commit with no
   change to a tracked file and is built, and LeanLink can load the toolchain's runtime *)

mathlibInstallationReadyQ[directory_String] := Block[
    {package = mathlibPackageDirectory[directory], stamp = FileNameJoin[{directory, $mathlibStamp}], git = mathlibExecutable["git"]}
    ,
    And[
        AllTrue[{stamp, FileNameJoin[{lakeBuildLib[package], "Mathlib.olean"}], toolchainProgram["lean"]}, FileExistsQ],
        Quiet[Check[Import[stamp, "RawJSON"] === mathlibRecord[], False]],
        mathlibProjectFilesQ[directory],
        mathlibGitWorkingQ[git],
        With[{head = installRun[{git, "rev-parse", "HEAD"}, package]}, AssociationQ[head] && head["ExitCode"] === 0 && StringTrim[head["StandardOutput"]] === mathlibPin[]["rev"]],
        With[{changes = installRun[{git, "diff", "--quiet", "HEAD"}, package]}, AssociationQ[changes] && changes["ExitCode"] === 0],
        mathlibRuntimeReadyQ[]
    ]
]

(* ============================================================================ *)
(* Installation                                                                 *)
(* ============================================================================ *)

(* A directory InstallMathlib installs into: a new or empty one, or one with its record or its lakefile, as an
   installation that did not finish leaves it. Any other, and any Lake project of its own, is refused and left as it
   is. *)

mathlibDirectoryUsableQ[directory_String] := Or[
    ! FileExistsQ[directory],
    DirectoryQ[directory] && Or[
        Select[FileNames["*", directory], ! StringStartsQ[FileNameTake[#], "."]&] === {},
        ! FileExistsQ[FileNameJoin[{directory, "lakefile.lean"}]] && Or[
            FileExistsQ[FileNameJoin[{directory, $mathlibStamp}]],
            With[{lakefile = FileNameJoin[{directory, "lakefile.toml"}]}, FileExistsQ[lakefile] && fileSHA256[lakefile] === fileSHA256[mathlibProjectFiles[]["lakefile.toml"]]]
        ]
    ]
]

(* The record goes first and comes back last, so an installation that does not finish leaves none; what it fetched
   stays for the run that resumes it *)

installMathlib[directory_String] := Block[{toolchain, git, copied, log, result},
    installStage["Preparing..."];
    toolchain = installToolchain[];
    If[FailureQ[toolchain], Return[toolchain, Block]];
    installStage["Checking..."];
    git = mathlibRequireTool["git"];
    mathlibRequireTool["curl"];
    If[mathlibInstallationReadyQ[directory], Return[File[directory], Block]];
    If[ ! mathlibDirectoryUsableQ[directory],
        Return[installFailure["MathlibDirectoryInUse", "`1` holds other files. Choose a new or empty directory.", <|"MessageParameters" -> {directory}, "Directory" -> directory|>], Block]
    ];
    If[ ! DirectoryQ[directory] && ! StringQ[Quiet[Check[CreateDirectory[directory, CreateIntermediateDirectories -> True], $Failed]]],
        Return[installFailure["MathlibDirectoryInUse", "`1` could not be created.", <|"MessageParameters" -> {directory}, "Directory" -> directory|>], Block]
    ];
    Quiet[DeleteFile[FileNameJoin[{directory, $mathlibStamp}]]];
    copied = KeyValueMap[Quiet[CopyFile[#2, FileNameJoin[{directory, #1}], OverwriteTarget -> True]]&, mathlibProjectFiles[]];
    If[! AllTrue[copied, StringQ], Return[installFailure["MathlibDirectoryInUse", "The project files could not be written into `1`.", <|"MessageParameters" -> {directory}, "Directory" -> directory|>], Block]];
    log = OpenWrite[FileNameJoin[{directory, $mathlibLog}], BinaryFormat -> True];
    result = WithCleanup[
        Block[{$installLog = log},
            Replace[mathlibClone[git, directory], Null :> mathlibBuild[toolchainProgram["lake"], directory]]
        ],
        Close[log]
    ];
    If[FailureQ[result], Return[result, Block]];
    installStage["Checking..."];
    Export[FileNameJoin[{directory, $mathlibStamp}], mathlibRecord[], "RawJSON"];
    If[ mathlibInstallationReadyQ[directory],
        File[directory],
        installFailure["MathlibRuntimeUnavailable", "Mathlib was built, but LeanLink could not load the Lean runtime of `1`. Restart the kernel and run InstallMathlib[] again.", <|"MessageParameters" -> {$LeanToolchain}, "Toolchain" -> $LeanToolchain|>]
    ]
]

(* Lake fetches a package as a partial clone of its pinned commit, with the whole history: for Mathlib, tens of
   thousands of commits, then the files of the checkout, in several minutes. A shallow clone of the pinned tag, in the
   place Lake gives the package, takes a fraction of that, and Lake uses a package already at its pinned commit as it
   is. One at another commit is removed, and Lake fetches the pinned commit itself. A clone that does not finish is
   removed too. *)

mathlibClone[git_String, directory_String] := Block[{package = mathlibPackageDirectory[directory], command, result, head, complete = False},
    If[DirectoryQ[package], Return[Null, Block]];
    installStage["Downloading..."];
    command = {git, "-c", "advice.detachedHead=false", "clone", "--depth", "1", "--branch", mathlibPin[]["inputRev"], mathlibPin[]["url"], package};
    installLogText[StringRiffle[command, " "] <> "\n"];
    WithCleanup[
        Quiet[CreateDirectory[DirectoryName[package], CreateIntermediateDirectories -> True]];
        result = installRun[command, directory, mathlibEnvironment[]];
        If[ ! AssociationQ[result] || result["ExitCode"] =!= 0,
            Return[
                installFailure[
                    "MathlibInstallFailed",
                    "Mathlib's installation did not finish. Run InstallMathlib[] again after resolving the error in the log.",
                    <|"Command" -> command, "Log" -> File[FileNameJoin[{directory, $mathlibLog}]], "Result" -> result|>
                ],
                Block
            ]
        ];
        head = installRun[{git, "rev-parse", "HEAD"}, package];
        complete = AssociationQ[head] && StringTrim[head["StandardOutput"]] === mathlibPin[]["rev"];
        Null
        ,
        If[! complete, Quiet[DeleteDirectory[package, DeleteContents -> True]]]
    ]
]

(* lake exe cache get fetches the packages the manifest pins, at their commits, and Mathlib's build cache, every module
   compiled; lake build Mathlib checks it, and builds what the cache lacks *)

mathlibBuild[lake_String, directory_String] := Block[{environment = mathlibEnvironment[], result},
    Do[
        installStage[First[step]];
        installLogText[StringRiffle[Last[step], " "] <> "\n"];
        result = installRun[Last[step], directory, environment];
        If[ ! AssociationQ[result] || result["ExitCode"] =!= 0,
            Return[
                installFailure[
                    "MathlibInstallFailed",
                    "Mathlib's installation did not finish. Run InstallMathlib[] again after resolving the error in the log.",
                    <|"Command" -> Last[step], "Log" -> File[FileNameJoin[{directory, $mathlibLog}]], "Result" -> result|>
                ],
                Block
            ]
        ]
        ,
        {step, {{"Downloading...", {lake, "exe", "cache", "get"}}, {"Installing...", {lake, "build", "Mathlib"}}}}
    ]
]

(* ============================================================================ *)
(* Other versions                                                               *)
(* ============================================================================ *)

(* Mathlib that InstallMathlib installed for other toolchains, which this version of LeanLink cannot load: the
   directories beside the default one whose record names another toolchain *)

mathlibOtherVersions[directory_String] := Select[
    FileNames["*", mathlibRoot[]],
    DirectoryQ[#] && # =!= directory && With[{record = Quiet[Check[Import[FileNameJoin[{#, $mathlibStamp}], "RawJSON"], $Failed]]},
        AssociationQ[record] && StringQ[record["Toolchain"]] && record["Toolchain"] =!= $LeanToolchain
    ]&
]

(* after an installation, other versions are removed when that is asked for, and named otherwise *)

mathlibCleanOtherVersions[directory_String, remove_] := With[{others = mathlibOtherVersions[directory]},
    Which[
        others === {},
            Null
        ,
        TrueQ[remove],
            Scan[Quiet[DeleteDirectory[#, DeleteContents -> True]]&, others]
        ,
        True,
            Message[InstallMathlib::other, others]
    ]
]

(* ============================================================================ *)
(* Public API                                                                   *)
(* ============================================================================ *)

Options[InstallMathlib] = {"Directory" -> Automatic, "ProgressFunction" -> (Null&), "CancellationFunction" -> (False&), "RemoveOtherVersions" -> False}

Options[MathlibInstallation] = {"Directory" -> Automatic}

MathlibInstallation[opts : OptionsPattern[]] := Block[{directory},
    If[! installOptionsQ[MathlibInstallation, {opts}], Return[installFailure["InvalidOption", "Unknown installation option."], Block]];
    directory = mathlibDirectory[OptionValue["Directory"]];
    If[FailureQ[directory], Return[directory, Block]];
    <|
        "Status" -> Which[mathlibInstallationReadyQ[directory], "Ready", DirectoryQ[directory], "Needs setup", True, "Not installed"],
        "Directory" -> directory,
        "Toolchain" -> $LeanToolchain,
        "Revision" -> mathlibPin[]["rev"],
        "DocumentationURL" -> $mathlibDocumentation,
        "Executables" -> mathlibExecutables[],
        "OtherVersions" -> mathlibOtherVersions[directory]
    |>
]

InstallMathlib[opts : OptionsPattern[]] := Block[{callbacks = installCallbacks[InstallMathlib, {opts}], directory, remove, result},
    If[FailureQ[callbacks], Return[callbacks, Block]];
    {directory, remove} = OptionValue[{"Directory", "RemoveOtherVersions"}];
    directory = mathlibDirectory[directory];
    If[FailureQ[directory], Return[directory, Block]];
    If[! BooleanQ[remove], Return[installFailure["InvalidOption", "\"RemoveOtherVersions\" must be True or False."], Block]];
    result = Catch[
        Block[{$installFunction = "InstallMathlib", $installProgress = First[callbacks], $installCancellation = Last[callbacks]}, installMathlib[directory]],
        "LeanLinkInstall"
    ];
    If[MatchQ[result, _File], mathlibCleanOtherVersions[directory, remove]];
    result
]

End[];

EndPackage[];

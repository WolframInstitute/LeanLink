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

mathlibDirectory[_] := evaluationFailure["InvalidOption", "\"Directory\" must be Automatic or a directory."]

(* Mathlib itself, where Lake puts a package the project requires *)

mathlibPackageDirectory[directory_String] := FileNameJoin[{directory, ".lake", "packages", "mathlib"}]

(* The installation's own files in its directory: the record of a finished installation, and the output of its
   commands *)

$mathlibStamp = "leanlink-mathlib.json"

$mathlibLog = "leanlink-mathlib.log"

mathlibRecord[] := mathlibRecord[] = <|"Toolchain" -> $LeanToolchain, "Revision" -> mathlibPin[]["rev"], "ManifestSHA256" -> fileSHA256[mathlibProjectFiles[]["lake-manifest.json"]]|>

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

mathlibGitWorkingQ[git_] := And[
    $OperatingSystem =!= "MacOSX" || git =!= "/usr/bin/git" || installSucceededQ[installRun[{"/usr/bin/xcode-select", "-p"}, $TemporaryDirectory, Automatic, 10]],
    StringStartsQ[installVersionText[git], "git version "]
]

(* Mathlib's cache tool decides by its version how to use the curl it finds, and fetches a newer one where it needs to;
   InstallMathlib asks only for a curl that runs, with HTTPS. Should the cache tool still fail, its reason is in the log. *)

mathlibCurlWorkingQ[curl_] := StringContainsQ[installVersionText[curl], RegularExpression["(?m)^Protocols:[^\\n]*\\bhttps\\b"]]

(* What a tool is for, and how to install it, for the failure that names a missing one *)

mathlibToolNeed["git"] = "Git, which Lake fetches Mathlib and its packages with"

mathlibToolNeed["curl"] = "curl with HTTPS, which Mathlib's cache tool downloads with"

mathlibToolAdvice["git", "MacOSX"] = "Install Apple's command line developer tools, which include Git, by running xcode-select --install in a terminal"

mathlibToolAdvice["git", "Windows"] = "Install Git for Windows from https://git-scm.com/download/win"

mathlibToolAdvice["git", _] = "Install Git with the system's package manager"

mathlibToolAdvice["curl", "Windows"] = "Install a current curl from https://curl.se/windows/ and put it on the PATH"

mathlibToolAdvice["curl", _] = "Install a current curl with the system's package manager"

mathlibRequireTool[name_String] := With[{path = mathlibExecutable[name]},
    If[ ! If[name === "git", mathlibGitWorkingQ[path], mathlibCurlWorkingQ[path]],
        installThrow[
            Capitalize[name] <> "Unavailable",
            "InstallMathlib needs `1`. `2`, then run InstallMathlib[] again.",
            <|"MessageParameters" -> {mathlibToolNeed[name], mathlibToolAdvice[name, $OperatingSystem]}, "Executable" -> path|>
        ]
    ];
    path
]

(* ============================================================================ *)
(* Readiness                                                                    *)
(* ============================================================================ *)

(* Ready: InstallMathlib's record, written once lake build Mathlib has checked every module, names the paclet's toolchain
   and Mathlib project; Mathlib's build is in place; and so is the toolchain. These are file checks: no process starts.
   Lake checks the packages' commits whenever InstallMathlib runs it. *)

mathlibInstallationReadyQ[directory_String] := With[{stamp = FileNameJoin[{directory, $mathlibStamp}]},
    And[
        AllTrue[{stamp, FileNameJoin[{lakeBuildLib[mathlibPackageDirectory[directory]], "Mathlib.olean"}], toolchainProgram["lean"]}, FileExistsQ],
        Quiet[Check[Import[stamp, "RawJSON"] === mathlibRecord[], False]]
    ]
]

(* "ProjectDir" -> Automatic: the current directory when it is a Lake project, else the Mathlib that InstallMathlib
   installed in its default directory when it is ready, else the current directory. An explicit "ProjectDir" always
   wins. Readiness reads files only, so this costs a millisecond or two. *)

defaultProjectDirectory[] := Which[
    isLakeProject[Directory[]], Directory[],
    mathlibInstallationReadyQ[mathlibDirectory[Automatic]], mathlibDirectory[Automatic],
    True, Directory[]
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

mathlibDirectoryFailure[message_String, directory_String] := installThrow["MathlibDirectoryInUse", message, <|"MessageParameters" -> {directory}, "Directory" -> directory|>]

(* A step of the installation, in its directory with the processes' PATH; its failure names the log *)

mathlibStep[stage_String, command_List, directory_String] := (
    installStage[stage];
    installStep[
        "MathlibInstallFailed",
        "Mathlib's installation did not finish. Run InstallMathlib[] again after resolving the error in the log.",
        command,
        directory,
        mathlibEnvironment[],
        <|"Log" -> File[FileNameJoin[{directory, $mathlibLog}]]|>
    ]
)

(* Lake fetches a package as a partial clone of its pinned commit, with the whole history: for Mathlib, tens of
   thousands of commits, then the files of the checkout, in several minutes. A shallow clone of the pinned tag, in the
   place Lake gives the package, takes a fraction of that, and Lake uses a package already at its pinned commit as it
   is. One at another commit is removed, and Lake fetches the pinned commit itself. A clone that does not finish is
   removed too. *)

mathlibClone[git_String, directory_String] := Block[{package = mathlibPackageDirectory[directory], complete = False},
    If[DirectoryQ[package], Return[Null, Block]];
    WithCleanup[
        Quiet[CreateDirectory[DirectoryName[package], CreateIntermediateDirectories -> True]];
        mathlibStep["Downloading...", {git, "-c", "advice.detachedHead=false", "clone", "--depth", "1", "--branch", mathlibPin[]["inputRev"], mathlibPin[]["url"], package}, directory];
        (* a clone of a tag has a detached HEAD: the file holds the commit *)
        complete = Quiet[Check[StringTrim[ReadString[FileNameJoin[{package, ".git", "HEAD"}]]], ""]] === mathlibPin[]["rev"]
        ,
        If[! complete, Quiet[DeleteDirectory[package, DeleteContents -> True]]]
    ];
]

(* The record goes first and comes back last, so an installation that does not finish leaves none; what it fetched
   stays for the run that resumes it. lake exe cache get fetches the packages the manifest pins, at their commits, and
   Mathlib's build cache, every module compiled; lake build Mathlib checks it, and builds what the cache lacks. *)

mathlibInstall[directory_String] := Block[{git, log},
    installStage["Preparing..."];
    installToolchain[];
    git = mathlibRequireTool["git"];
    mathlibRequireTool["curl"];
    If[! mathlibDirectoryUsableQ[directory], mathlibDirectoryFailure["`1` holds other files. Choose a new or empty directory.", directory]];
    If[! DirectoryQ[directory] && ! StringQ[Quiet[Check[CreateDirectory[directory, CreateIntermediateDirectories -> True], $Failed]]], mathlibDirectoryFailure["`1` could not be created.", directory]];
    Quiet[DeleteFile[FileNameJoin[{directory, $mathlibStamp}]]];
    If[ ! AllTrue[KeyValueMap[Quiet[CopyFile[#2, FileNameJoin[{directory, #1}], OverwriteTarget -> True]]&, mathlibProjectFiles[]], StringQ],
        mathlibDirectoryFailure["The project files could not be written into `1`.", directory]
    ];
    log = OpenWrite[FileNameJoin[{directory, $mathlibLog}], BinaryFormat -> True];
    WithCleanup[
        Block[{$installLog = log},
            mathlibClone[git, directory];
            mathlibStep["Downloading...", {toolchainProgram["lake"], "exe", "cache", "get"}, directory];
            mathlibStep["Installing...", {toolchainProgram["lake"], "build", "Mathlib"}, directory]
        ],
        Close[log]
    ];
    installStage["Checking..."];
    Export[FileNameJoin[{directory, $mathlibStamp}], mathlibRecord[], "RawJSON"];
    If[ ! mathlibInstallationReadyQ[directory],
        installThrow["MathlibInstallFailed", "lake build Mathlib finished, but Mathlib's build is not in `1`.", <|"MessageParameters" -> {lakeBuildLib[mathlibPackageDirectory[directory]]}, "Log" -> File[FileNameJoin[{directory, $mathlibLog}]]|>]
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

Options[InstallMathlib] = Join[{"Directory" -> Automatic, "RemoveOtherVersions" -> False}, Options[InstallLeanToolchain]]

Options[MathlibInstallation] = {"Directory" -> Automatic}

MathlibInstallation[opts : OptionsPattern[]] := Block[{directory},
    If[! installOptionsQ[MathlibInstallation, {opts}], Return[evaluationFailure["InvalidOption", "Unknown installation option."], Block]];
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

(* The options are checked first; a ready installation is given as it is, without the toolchain or the tools *)

installMathlib[directoryOption_, remove_] := Block[{directory = mathlibDirectory[directoryOption]},
    If[FailureQ[directory], Throw[directory, "LeanLinkInstall"]];
    If[! BooleanQ[remove], installThrow["InvalidOption", "\"RemoveOtherVersions\" must be True or False."]];
    installStage["Checking..."];
    If[! mathlibInstallationReadyQ[directory], mathlibInstall[directory]];
    mathlibCleanOtherVersions[directory, remove];
    File[directory]
]

InstallMathlib[opts : OptionsPattern[]] := installFrame[InstallMathlib, {opts}, installMathlib @@ OptionValue[InstallMathlib, {opts}, {"Directory", "RemoveOtherVersions"}]]

End[];

EndPackage[];

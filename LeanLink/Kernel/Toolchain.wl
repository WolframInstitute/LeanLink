(* ::Package:: *)

(* Toolchain.wl -- InstallLeanToolchain: the Lean toolchain LeanLink's native library is built against, installed with
   elan; and what installations share: their options, progress and cancellation, the processes they start and their
   pinned downloads.

   Loading LeanLink installs nothing, downloads nothing and starts no process: only InstallLeanToolchain and
   InstallMathlib do. elan's installers are pinned by URL and SHA-256 in Assets/Elan.json. Nothing is changed outside
   the directories named here: no shell profile, no elan default toolchain, no PATH of the kernel. *)

BeginPackage["Wolfram`LeanLink`"];

InstallLeanToolchain::usage = "InstallLeanToolchain[] installs the Lean toolchain LeanLink is built against, with elan when there is no working elan, and gives File[dir] for the toolchain."

Begin["`Private`"];

(* ============================================================================ *)
(* Pins and places                                                              *)
(* ============================================================================ *)

(* elan's installers by URL and SHA-256, read from beside the loaded code *)

elanPins[] := Import[FileNameJoin[{$PacletRoot, "Assets", "Elan.json"}], "RawJSON"]

(* verified downloads, in the user's cache since they can be downloaded again, kept so that an installation run again
   does not download them again *)

installDownloadsDirectory[] := FileNameJoin[{cacheBase[], "LeanLink", "Downloads"}]

pathDirectories[] := StringSplit[Replace[Environment["PATH"], Except[_String] -> ""], $searchPathSeparator]

(* the first program called name in directories, as a process searches them *)

findExecutable[name_String, directories_List] := SelectFirst[leanProgram[#, name]& /@ directories, FileExistsQ, Missing["NotFound", name]]

(* ============================================================================ *)
(* Options, progress, cancellation and failures                                 *)
(* ============================================================================ *)

Options[InstallLeanToolchain] = {"ProgressFunction" -> (Null&), "CancellationFunction" -> (False&)}

$installFunction = "InstallLeanToolchain"

$installProgress = (Null&)

$installCancellation = (False&)

(* an option the function does not have is reported, not ignored *)

installOptionsQ[function_Symbol, options_List] := SubsetQ[Keys[Options[function]], Keys[Flatten[options]]]

(* A failure of an installation is thrown to the function the user called, which gives it *)

installThrow[tag_String, message_String, data_Association : <||>] := Throw[evaluationFailure[tag, message, data], "LeanLinkInstall"]

(* An installation function: its options are checked before OptionValue reads them, which would report an unknown one
   with a message, then body runs with the callbacks, and what it throws is the result *)

SetAttributes[installFrame, HoldRest]

installFrame[function_Symbol, options_List, body_] := Block[{callbacks},
    If[! installOptionsQ[function, options], Return[evaluationFailure["InvalidOption", "Unknown installation option."], Block]];
    callbacks = OptionValue[function, options, {"ProgressFunction", "CancellationFunction"}];
    If[ ! AllTrue[callbacks, MatchQ[#, _Function | _Symbol] && ! MemberQ[{True, False, None, Null}, #]&],
        Return[evaluationFailure["InvalidOption", "\"ProgressFunction\" and \"CancellationFunction\" must be functions."], Block]
    ];
    Catch[
        Block[{$installFunction = SymbolName[function], $installProgress = First[callbacks], $installCancellation = Last[callbacks]}, body],
        "LeanLinkInstall"
    ]
]

(* The cancellation function is asked at each stage and before each process *)

installCheckCancellation[] := With[{cancelled = Quiet[Check[$installCancellation[], $Failed]]},
    Which[
        TrueQ[cancelled],
            installThrow["InstallCancelled", "The installation was cancelled. Run `1`[] to resume.", <|"MessageParameters" -> {$installFunction}|>]
        ,
        cancelled =!= False,
            installThrow["InvalidCallback", "\"CancellationFunction\" must return True or False."]
    ]
]

(* the progress function is given each stage, such as "Downloading..." *)

installStage[stage_String] := (
    installCheckCancellation[];
    If[Quiet[Check[$installProgress[stage], $Failed]] === $Failed, installThrow["InvalidCallback", "\"ProgressFunction\" could not report the installation stage."]]
)

(* ============================================================================ *)
(* Processes                                                                    *)
(* ============================================================================ *)

(* The environment of every process an installation starts: the kernel's, with path as its PATH, ELAN_HOME, and no
   LEAN_PATH, as runLean drops it. Windows' "Path" goes with the kernel's PATH. The kernel's own environment is left as
   it is. *)

installEnvironment[path_List, extra_Association : <||>] := Join[
    KeySelect[Association[GetEnvironment[]], ! MemberQ[{"PATH", "LEAN_PATH"}, ToUpperCase[#]]&],
    <|"PATH" -> StringRiffle[DeleteDuplicates[path], $searchPathSeparator], "ELAN_HOME" -> elanHome[]|>,
    extra
]

(* The log of an installation, an output stream, or None. It takes the bytes the processes wrote, which reach the
   kernel a byte a character, and the installation's own text as UTF-8. *)

$installLog = None

installLog[bytes_String] := If[$installLog =!= None && bytes =!= "", BinaryWrite[$installLog, ToCharacterCode[bytes, "ISO8859-1"]]]

installLogText[text_String] := If[$installLog =!= None, BinaryWrite[$installLog, ToCharacterCode[text, "UTF-8"]]]

(* A process of an installation, run with RunProcess, which reads both pipes while the process runs and waits without
   polling. It is not started once the installation is cancelled; an abort, or the time limit given, stops it with the
   processes it started. Its output goes to the log, and is decoded for the result. *)

installRun[command_List, directory_String, environment_ : Automatic, limit_ : Infinity] := Block[{result},
    installCheckCancellation[];
    result = TimeConstrained[
        Quiet[Check[RunProcess[command, ProcessDirectory -> directory, ProcessEnvironment -> Replace[environment, Automatic :> installEnvironment[pathDirectories[]]]], $Failed]],
        limit,
        $TimedOut
    ];
    If[ AssociationQ[result],
        installLog[result["StandardOutput"] <> result["StandardError"]];
        Join[result, <|"StandardOutput" -> utf8Text[result["StandardOutput"]], "StandardError" -> utf8Text[result["StandardError"]]|>],
        result
    ]
]

installSucceededQ[result_] := AssociationQ[result] && result["ExitCode"] === 0

(* A process that must succeed, logged by its command: a failure is thrown with tag and message, the command and its
   result *)

installStep[tag_String, message_String, command_List, directory_String, environment_ : Automatic, data_Association : <||>] := Block[{result},
    installLogText[StringRiffle[command, " "] <> "\n"];
    result = installRun[command, directory, environment];
    If[! installSucceededQ[result], installThrow[tag, message, Join[<|"Command" -> command, "Result" -> result|>, data]]];
    result
]

(* what a program prints for --version, within ten seconds, or "" when it does not run *)

installVersionText[program_String] := With[{result = installRun[{program, "--version"}, $TemporaryDirectory, Automatic, 10]},
    If[installSucceededQ[result], result["StandardOutput"], ""]
]

installVersionText[_] := ""

(* ============================================================================ *)
(* Downloads                                                                    *)
(* ============================================================================ *)

(* A pinned file: one already downloaded with the pinned checksum is used without the network, and a download is kept
   only with that checksum. elan's installer, the one download, takes seconds; an abort stops it. *)

installDownload[asset_Association, file_String] := Block[{result},
    installCheckCancellation[];
    If[FileExistsQ[file] && fileSHA256[file] === asset["SHA256"], Return[file, Block]];
    installStage["Downloading..."];
    result = Quiet[Check[URLDownload[asset["URL"], file, CreateIntermediateDirectories -> True, ProgressReporting -> False], $Failed]];
    Which[
        ! MatchQ[result, _File] || ! FileExistsQ[file],
            installThrow["DownloadFailed", "A download did not finish.", <|"URL" -> asset["URL"]|>]
        ,
        fileSHA256[file] =!= asset["SHA256"],
            Quiet[DeleteFile[file]];
            installThrow["DownloadChecksum", "A download does not match its pinned checksum.", <|"URL" -> asset["URL"]|>]
    ];
    installCheckCancellation[];
    file
]

(* ============================================================================ *)
(* elan and the toolchain                                                       *)
(* ============================================================================ *)

(* elan: ELAN_HOME's, else one on PATH *)

elanExecutable[] := findExecutable["elan", Prepend[pathDirectories[], FileNameJoin[{elanHome[], "bin"}]]]

elanWorkingQ[elan_] := StringStartsQ[StringTrim[installVersionText[elan]], "elan "]

(* A working elan is used as it is. Otherwise the pinned installer puts elan into ELAN_HOME, with --no-modify-path and
   no default toolchain. *)

installElan[] := Block[{elan = elanExecutable[], asset, archive, temporary, installer},
    If[elanWorkingQ[elan], Return[elan, Block]];
    asset = Lookup[elanPins[]["ElanArchives"], $SystemID, None];
    If[! AssociationQ[asset], installThrow["UnsupportedPlatform", "No pinned elan installer is available for this system.", <|"SystemID" -> $SystemID|>]];
    archive = installDownload[asset, FileNameJoin[{installDownloadsDirectory[], Last[StringSplit[asset["URL"], "/"]]}]];
    temporary = CreateDirectory[];
    WithCleanup[
        installStage["Installing..."];
        installer = leanProgram[temporary, "elan-init"];
        If[Quiet[Check[ExtractArchive[archive, temporary], $Failed]] === $Failed || ! FileExistsQ[installer], installThrow["ElanInstallFailed", "The elan installer could not be extracted."]];
        If[$OperatingSystem =!= "Windows", installStep["ElanInstallFailed", "The elan installer could not be made executable.", {"/bin/chmod", "u+x", installer}, temporary]];
        installStep["ElanInstallFailed", "The elan installation did not finish.", {installer, "-y", "--no-modify-path", "--default-toolchain", "none"}, temporary];
        elan = leanProgram[FileNameJoin[{elanHome[], "bin"}], "elan"];
        If[! elanWorkingQ[elan], installThrow["ElanInstallFailed", "The installed elan could not run."]];
        elan
        ,
        DeleteDirectory[temporary, DeleteContents -> True]
    ]
]

(* LeanLink can use the toolchain when its native library loads Lean's Init from it. That compiles nothing, and once it
   has passed it holds for the rest of the kernel session. *)

$leanRuntimeReady = False

leanRuntimeReadyQ[] := TrueQ[$leanRuntimeReady] || With[{handle = Quiet[LeanLoadEnvironment[{"Init"}, FileNameJoin[{leanToolchainPath[], "lib", "lean"}]]]},
    If[ IntegerQ[handle] && handle > 0,
        LeanFreeEnvironment[handle];
        $leanRuntimeReady = True
        ,
        False
    ]
]

(* The toolchain is installed when its lean is. elan installs it otherwise, as elan toolchain install does in a shell,
   with no change to elan's default toolchain. Either way LeanLink must then load its runtime. *)

installToolchain[] := Block[{lean = toolchainProgram["lean"], elan},
    If[ ! FileExistsQ[lean],
        elan = installElan[];
        installStage["Downloading..."];
        installStep["ToolchainInstallFailed", "elan could not install the toolchain `1`.", {elan, "toolchain", "install", $LeanToolchain}, $TemporaryDirectory, Automatic, <|"MessageParameters" -> {$LeanToolchain}|>];
        If[! FileExistsQ[lean], installThrow["ToolchainInstallFailed", "elan did not install the toolchain `1`.", <|"MessageParameters" -> {$LeanToolchain}|>]]
    ];
    If[! leanRuntimeReadyQ[], installThrow["RuntimeUnavailable", "The toolchain `1` is installed, but LeanLink's native library could not load its Lean runtime.", <|"MessageParameters" -> {$LeanToolchain}|>]];
    leanToolchainPath[]
]

(* ============================================================================ *)
(* Public API                                                                   *)
(* ============================================================================ *)

InstallLeanToolchain[opts : OptionsPattern[]] := installFrame[InstallLeanToolchain, {opts}, installStage["Preparing..."]; File[installToolchain[]]]

End[];

EndPackage[];

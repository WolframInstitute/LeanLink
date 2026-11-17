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

installFailure[tag_String, message_String, data_Association : <||>] := Failure[tag, Join[<|"MessageTemplate" -> message|>, data]]

(* an option the function does not have is reported, not ignored *)

installOptionsQ[function_Symbol, options_List] := SubsetQ[Keys[Options[function]], Keys[Flatten[options]]]

pathDirectories[] := StringSplit[Replace[Environment["PATH"], Except[_String] -> ""], $searchPathSeparator]

(* the first program called name in directories, as a process searches them *)

findExecutable[name_String, directories_List] := SelectFirst[leanProgram[#, name]& /@ directories, FileExistsQ, Missing["NotFound", name]]

(* ============================================================================ *)
(* Progress and cancellation                                                    *)
(* ============================================================================ *)

Options[InstallLeanToolchain] = {"ProgressFunction" -> (Null&), "CancellationFunction" -> (False&)}

$installFunction = "InstallLeanToolchain"

$installProgress = (Null&)

$installCancellation = (False&)

(* The callbacks of an installation function, {progress, cancellation}, or a Failure. The options are checked before
   OptionValue reads them, which would report an unknown one with a message. *)

installCallbacks[function_Symbol, options_List] := Block[{callbacks},
    If[! installOptionsQ[function, options], Return[installFailure["InvalidOption", "Unknown installation option."], Block]];
    callbacks = OptionValue[function, options, {"ProgressFunction", "CancellationFunction"}];
    If[ AllTrue[callbacks, MatchQ[#, _Function | _Symbol] && ! MemberQ[{True, False, None, Null}, #]&],
        callbacks,
        installFailure["InvalidOption", "\"ProgressFunction\" and \"CancellationFunction\" must be functions."]
    ]
]

(* An installation asks the cancellation function between its steps and while it waits for a download or a process.
   Its failures are thrown to the function the user called, which catches them. *)

installCheckCancellation[] := With[{cancelled = Quiet[Check[$installCancellation[], $Failed]]},
    Which[
        TrueQ[cancelled],
            Throw[installFailure["InstallCancelled", "The installation was cancelled. Run `1`[] to resume.", <|"MessageParameters" -> {$installFunction}|>], "LeanLinkInstall"]
        ,
        cancelled === False,
            Null
        ,
        True,
            Throw[installFailure["InvalidCallback", "\"CancellationFunction\" must return True or False."], "LeanLinkInstall"]
    ]
]

installReportProgress[stage_String, fraction_] := If[ Quiet[Check[$installProgress[stage, fraction], $Failed]] === $Failed,
    installFailure["InvalidCallback", "\"ProgressFunction\" could not report the installation stage."],
    Null
]

installStage[stage_String, fraction_ : None] := (
    installCheckCancellation[];
    With[{reported = installReportProgress[stage, fraction]}, If[FailureQ[reported], Throw[reported, "LeanLinkInstall"]]];
    installCheckCancellation[]
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
            Throw[installFailure["DownloadFailed", "A download did not finish.", <|"URL" -> asset["URL"]|>], "LeanLinkInstall"]
        ,
        fileSHA256[file] =!= asset["SHA256"],
            Quiet[DeleteFile[file]];
            Throw[installFailure["DownloadChecksum", "A download does not match its pinned checksum.", <|"URL" -> asset["URL"]|>], "LeanLinkInstall"]
        ,
        True,
            installCheckCancellation[];
            file
    ]
]

(* ============================================================================ *)
(* elan and the toolchain                                                       *)
(* ============================================================================ *)

(* elan: ELAN_HOME's, else one on PATH *)

elanExecutable[] := findExecutable["elan", Prepend[pathDirectories[], FileNameJoin[{elanHome[], "bin"}]]]

(* A working elan is used as it is. Otherwise the pinned installer puts elan into ELAN_HOME, with --no-modify-path and
   no default toolchain. *)

installElan[] := Block[{elan = elanExecutable[], checked, asset, archive, temporary, installer, result},
    If[ StringQ[elan],
        checked = installRun[{elan, "--version"}, $TemporaryDirectory];
        If[AssociationQ[checked] && checked["ExitCode"] === 0 && StringStartsQ[StringTrim[checked["StandardOutput"]], "elan "], Return[elan, Block]]
    ];
    asset = Lookup[elanPins[]["ElanArchives"], $SystemID, None];
    If[! AssociationQ[asset], Return[installFailure["UnsupportedPlatform", "No pinned elan installer is available for this system.", <|"SystemID" -> $SystemID|>], Block]];
    archive = installDownload[asset, FileNameJoin[{installDownloadsDirectory[], Last[StringSplit[asset["URL"], "/"]]}]];
    temporary = CreateDirectory[];
    WithCleanup[
        installStage["Installing..."];
        result = Quiet[Check[ExtractArchive[archive, temporary], $Failed]];
        installer = leanProgram[temporary, "elan-init"];
        If[result === $Failed || ! FileExistsQ[installer], Return[installFailure["ElanInstallFailed", "The elan installer could not be extracted."], Block]];
        If[ $OperatingSystem =!= "Windows",
            result = installRun[{"/bin/chmod", "u+x", installer}, temporary];
            If[! AssociationQ[result] || result["ExitCode"] =!= 0, Return[installFailure["ElanInstallFailed", "The elan installer could not be made executable."], Block]]
        ];
        result = installRun[{installer, "-y", "--no-modify-path", "--default-toolchain", "none"}, temporary];
        If[! AssociationQ[result] || result["ExitCode"] =!= 0, Return[installFailure["ElanInstallFailed", "The elan installation did not finish.", <|"Result" -> result|>], Block]];
        elan = leanProgram[FileNameJoin[{elanHome[], "bin"}], "elan"];
        checked = installRun[{elan, "--version"}, temporary];
        If[! AssociationQ[checked] || checked["ExitCode"] =!= 0, Return[installFailure["ElanInstallFailed", "The installed elan could not run.", <|"Result" -> checked|>], Block]];
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

installToolchain[] := Block[{lean = toolchainProgram["lean"], elan, result},
    If[ ! FileExistsQ[lean],
        elan = installElan[];
        If[FailureQ[elan], Return[elan, Block]];
        installStage["Downloading..."];
        result = installRun[{elan, "toolchain", "install", $LeanToolchain}, $TemporaryDirectory];
        If[ ! AssociationQ[result] || result["ExitCode"] =!= 0 || ! FileExistsQ[lean],
            Return[installFailure["ToolchainInstallFailed", "elan could not install the toolchain `1`.", <|"MessageParameters" -> {$LeanToolchain}, "Result" -> result|>], Block]
        ]
    ];
    If[ ! leanRuntimeReadyQ[],
        Return[installFailure["RuntimeUnavailable", "The toolchain `1` is installed, but LeanLink's native library could not load its Lean runtime.", <|"MessageParameters" -> {$LeanToolchain}|>], Block]
    ];
    leanToolchainPath[]
]

(* ============================================================================ *)
(* Public API                                                                   *)
(* ============================================================================ *)

InstallLeanToolchain[opts : OptionsPattern[]] := Block[{callbacks = installCallbacks[InstallLeanToolchain, {opts}]},
    If[FailureQ[callbacks], Return[callbacks, Block]];
    Catch[
        Block[{$installFunction = "InstallLeanToolchain", $installProgress = First[callbacks], $installCancellation = Last[callbacks]},
            installStage["Preparing..."];
            Replace[installToolchain[], directory_String :> File[directory]]
        ],
        "LeanLinkInstall"
    ]
]

End[];

EndPackage[];

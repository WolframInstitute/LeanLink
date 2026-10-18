(* ::Package:: *)

(* pacletpage.wl - what build_docs.wls and release.wls share: loading PacletPage
   (WolframInstitute/PacletPage) and the options LeanLink is built and published
   with, kept in one place so the two scripts cannot drift apart. *)

$repoDir = DirectoryName[$InputFileName]

$leanlinkDir = FileNameJoin[{$repoDir, "LeanLink"}]

$docsDir = FileNameJoin[{$repoDir, "docs", "paclet", "en"}]

(* The documentation site, and the paclet resource it is built around, belong to
   this account. PacletPage refuses to publish from a kernel connected as any
   other, and never connects by itself. *)

$siteAccount = "wolframinstitute@wolframinstitute.org"

(* PacletPage evaluates each tutorial in one context, since LeanLink's tutorials
   use in later sections what earlier ones define, and runs every other page's
   sections, and each example between ---, in a clean context. 0.3.8 reports a
   section reading a name only an earlier section gave a value (the reset has
   cleared it, so the cell renders unevaluated or wrong while the page still
   builds), and lets a dry run that does not build report the account check
   rather than refuse. 0.3.11 stops a deploy at the first failed cloud write and
   replaces the documentation in place, so a deploy that stops leaves the live
   pages served; an older one could leave the resource without them. *)

$minPacletPage = "0.3.11"

$pacletPageResource = "https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/PacletPage"

versionKey[v_String] := PadRight[FromDigits /@ StringCases[v, DigitCharacter ..], 3]

newEnoughQ[p_PacletObject] := Order[versionKey[p["Version"]], versionKey[$minPacletPage]] <= 0

newEnoughQ[_] := False

(* The newest PacletPage this machine has, with a checkout named by PACLETPAGE_DIR
   added to the candidates. Nothing is installed: a missing or older PacletPage
   stops the script with the line that installs the current release. *)

loadPacletPage[] := Block[{dir = Environment["PACLETPAGE_DIR"], paclet},
    If[ StringQ[dir],
        If[! DirectoryQ[dir], Print["FATAL: PACLETPAGE_DIR is not a directory: ", dir]; Exit[1]];
        PacletDirectoryLoad[dir]
    ];
    paclet = First[PacletFind["WolframInstitute/PacletPage"], None];
    If[ ! newEnoughQ[paclet],
        Print["FATAL: PacletPage ", $minPacletPage, " or later is needed; this machine has ", If[paclet === None, "none", paclet["Version"]], ". Install it in a fresh kernel with"];
        Print["    PacletInstall[ResourceObject[\"", $pacletPageResource, "\"]]"];
        Print["or set PACLETPAGE_DIR to a PacletPage checkout."];
        Exit[1]
    ];
    Needs["WolframInstitute`PacletPage`"];
    paclet["Version"]
]

(* The pages build from docs/paclet/en with PacletPage's defaults. *)

$buildOptions = {"Source" -> $docsDir}

(* A build is good when every page converted and no section reads a name that
   only an earlier section gave a value. PacletPage keeps such a page out of its
   cache, so every build reports it until it is fixed. *)

checkBuild[result_] := Block[{unevaluated},
    If[! AssociationQ[result], Print["FATAL: BuildPacletDocumentation gave ", Short[result, 2]]; Exit[1]];
    Print["pages: ", Length[result["Notebooks"]], " (", Length[result["Evaluated"]], " evaluated, ", Length[result["Cached"]], " cached)   definition: ", result["Definition"]];
    If[ result["Failed"] =!= {},
        Print["FAILED: ", result["Failed"]];
        Exit[1]
    ];
    unevaluated = Lookup[result, "Unevaluated", <||>];
    If[ Length[unevaluated] > 0,
        KeyValueMap[Function[{file, reports}, Print["UNEVALUATED ", FileNameTake[file], ": ", StringRiffle[Map[#["Heading"] <> " reads " <> StringRiffle[ToString /@ #["Symbols"], ", "] &, reports], "; "]]], unevaluated];
        Exit[1]
    ]
]

(* The documentation built, every example evaluated again when --no-cache is on
   the command line, and checked: a bad build stops the script. The function is
   named in full: this file is read before PacletPage is loaded. *)

buildDocumentation[] := checkBuild[WolframInstitute`PacletPage`BuildPacletDocumentation[$leanlinkDir, Sequence @@ $buildOptions, Sequence @@ If[MemberQ[$ScriptCommandLine, "--no-cache"], {"UseCache" -> False}, {}]]]

(* At load the kernel links the Lean runtime (libleanshared and its siblings,
   about 160 MB) from the user's own toolchain next to each shim. Those links must
   never reach the archive, which ships only the shims. *)

$resourceOptions = {
    "Exclude" -> {
        "LibraryResources/*/libleanshared*",
        "LibraryResources/*/libInit_shared*",
        "LibraryResources/*/libLake_shared*"
    }
}

(* Feedback sent through the site's form is readable by the site's owner, by
   signed-in wolframinstitute.org accounts, and by the readers listed. *)

$siteOptions = {
    "FeedbackOptions" -> {"Domains" -> {"wolframinstitute.org"}, "Readers" -> {"nikm@wolfram.com"}}
}

#!/usr/bin/env wolframscript
(* Pin LeanLink/Assets/Mathlib, the Lake project InstallMathlib installs, to the Mathlib release of the toolchain in
   LeanLink/lean-toolchain: Mathlib tags each release with the version of the toolchain it is built with. The script
   writes the project's lakefile.toml, which requires Mathlib at that tag, runs lake update in a scratch copy of the
   project, and keeps the lake-manifest.json Lake writes, which pins Mathlib and each package it uses by commit.
   MATHLIB_NO_CACHE_ON_UPDATE keeps lake update from downloading Mathlib's build cache.

   Run it after changing the toolchain, with that toolchain installed, then run the Mathlib tests:

       wolframscript -file update_mathlib.wls
*)

root = DirectoryName[$InputFileName];

toolchainFile = FileNameJoin[{root, "LeanLink", "lean-toolchain"}];

toolchain = StringTrim[ReadString[toolchainFile]];

project = FileNameJoin[{root, "LeanLink", "Assets", "Mathlib"}];

elanHome = Replace[Environment["ELAN_HOME"], Except[_String] :> FileNameJoin[{$HomeDirectory, ".elan"}]];

(* the toolchain's own lake, as InstallMathlib runs it: elan's proxy would download a missing toolchain *)

lake = FileNameJoin[{elanHome, "toolchains", StringReplace[toolchain, {"/" -> "--", ":" -> "---"}], "bin", "lake" <> If[$OperatingSystem === "Windows", ".exe", ""]}];

If[ ! FileExistsQ[lake],
    Print["The toolchain ", toolchain, " is not installed. Install it with InstallLeanToolchain[] in LeanLink, or with: elan toolchain install ", toolchain];
    Exit[1]
];

lakefile = StringRiffle[
    {
        "# The Lake project InstallMathlib installs: Mathlib at the tag of LeanLink's toolchain. lake-manifest.json pins",
        "# Mathlib and each package it uses by commit. update_mathlib.wls writes both.",
        "",
        "name = \"LeanLinkMathlib\"",
        "",
        "[[require]]",
        "name = \"mathlib\"",
        "git = \"https://github.com/leanprover-community/mathlib4\"",
        "rev = \"" <> Last[StringSplit[toolchain, ":"]] <> "\"",
        ""
    },
    "\n"
];

scratch = CreateDirectory[];

manifest = WithCleanup[
    CopyFile[toolchainFile, FileNameJoin[{scratch, "lean-toolchain"}]];
    Export[FileNameJoin[{scratch, "lakefile.toml"}], lakefile, "String"];
    result = RunProcess[{lake, "update"}, ProcessDirectory -> scratch, ProcessEnvironment -> Association[GetEnvironment[], "MATHLIB_NO_CACHE_ON_UPDATE" -> "1"]];
    If[ ! AssociationQ[result] || result["ExitCode"] =!= 0 || ! FileExistsQ[FileNameJoin[{scratch, "lake-manifest.json"}]],
        Print["lake update failed:\n", If[AssociationQ[result], result["StandardOutput"] <> result["StandardError"], result]];
        $Failed
        ,
        If[! DirectoryQ[project], CreateDirectory[project]];
        CopyFile[FileNameJoin[{scratch, #}], FileNameJoin[{project, #}], OverwriteTarget -> True]& /@ {"lakefile.toml", "lake-manifest.json"};
        Import[FileNameJoin[{project, "lake-manifest.json"}], "RawJSON"]
    ]
    ,
    DeleteDirectory[scratch, DeleteContents -> True]
];

If[manifest === $Failed, Exit[1]];

Print[
    "Pinned Mathlib ",
    Last[StringSplit[toolchain, ":"]],
    " at ",
    SelectFirst[manifest["packages"], #["name"] === "mathlib"&]["rev"],
    ", with ",
    Length[manifest["packages"]],
    " packages, in ",
    project
];

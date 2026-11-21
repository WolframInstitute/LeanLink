#!/usr/bin/env wolframscript
(* Pin LeanLink/Assets/Mathlib, the Lake project InstallMathlib installs, to the Mathlib release of the toolchain in
   LeanLink/Assets/lean-toolchain: Mathlib tags each release with the version of the toolchain it is built with. The script
   writes the project's lakefile.toml, which requires Mathlib at that tag, runs lake update in a scratch copy of the
   project, and keeps the lake-manifest.json Lake writes, which pins Mathlib and each package it uses by commit.
   MATHLIB_NO_CACHE_ON_UPDATE keeps lake update from downloading Mathlib's build cache.

   It takes the pin, the toolchain's lake and the project's files from the paclet in this checkout, as InstallMathlib
   does. Run it after changing the toolchain, with that toolchain installed, then run the Mathlib tests:

       wolframscript -file update_mathlib.wls
*)

PacletDirectoryLoad[FileNameJoin[{DirectoryName[$InputFileName], "LeanLink"}]];

Needs["Wolfram`LeanLink`"];

files = Wolfram`LeanLink`Private`mathlibProjectFiles[];

lake = Wolfram`LeanLink`Private`toolchainProgram["lake"];

If[ ! FileExistsQ[lake],
    Print["The toolchain ", Wolfram`LeanLink`Private`$LeanToolchain, " is not installed. Install it with: elan toolchain install ", Wolfram`LeanLink`Private`$LeanToolchain];
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
        "rev = \"" <> Wolfram`LeanLink`Private`$LeanToolchainVersion <> "\"",
        ""
    },
    "\n"
];

scratch = CreateDirectory[];

updated = WithCleanup[
    CopyFile[files["lean-toolchain"], FileNameJoin[{scratch, "lean-toolchain"}]];
    Export[FileNameJoin[{scratch, "lakefile.toml"}], lakefile, "String"];
    result = RunProcess[{lake, "update"}, ProcessDirectory -> scratch, ProcessEnvironment -> Association[GetEnvironment[], "MATHLIB_NO_CACHE_ON_UPDATE" -> "1"]];
    If[ ! AssociationQ[result] || result["ExitCode"] =!= 0 || ! FileExistsQ[FileNameJoin[{scratch, "lake-manifest.json"}]],
        Print["lake update failed:\n", If[AssociationQ[result], result["StandardOutput"] <> result["StandardError"], result]];
        False
        ,
        If[! DirectoryQ[DirectoryName[files["lakefile.toml"]]], CreateDirectory[DirectoryName[files["lakefile.toml"]]]];
        CopyFile[FileNameJoin[{scratch, #}], files[#], OverwriteTarget -> True]& /@ {"lakefile.toml", "lake-manifest.json"};
        True
    ]
    ,
    DeleteDirectory[scratch, DeleteContents -> True]
];

If[! updated, Exit[1]];

(* read for the first time here, from the manifest just written *)

Print[
    "Pinned Mathlib ",
    Wolfram`LeanLink`Private`mathlibPin[]["inputRev"],
    " at ",
    Wolfram`LeanLink`Private`mathlibPin[]["rev"],
    " in ",
    DirectoryName[files["lake-manifest.json"]]
];

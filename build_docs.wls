#!/usr/bin/env wolframscript
(* Build the LeanLink paclet documentation from the literate markdown in
   docs/, writing each notebook into the standard paclet layout under
   LeanLink/Documentation/English/, and the paclet-repository submission
   notebook (ResourceDefinition) to LeanLink/ResourceDefinition.nb.

   Run with the `wl` CLI, not wolframscript - wolframscript's init can wedge
   the kernel mid-build:

       wl -f build_docs.wls
*)

(* Pin the front end appearance to Light up front: a headless session
   resolves the Automatic appearance to Dark, which would invert colours
   in any rasterised example output (Lean expression / call graphs) and
   leave the notebooks looking nothing like the cloud / paclet viewer. *)

Quiet @ UsingFrontEnd[CurrentValue[$FrontEnd, LightDark] = "Light"]

rootDir = DirectoryName[$InputFileName]

pacletDir = FileNameJoin[{rootDir, "LeanLink"}]

(* Register the dev paclet so PacletObject["Wolfram/LeanLink"] resolves inside
   the example cells, then load the package by its context. The context
   "Wolfram`LeanLink`" resolves to Kernel/LeanLink.wl; that entry file's last
   step Gets Compiler.wl, which Gets a forked Wolfram compiler (TypePi.m, ...)
   that need not be present - Quiet swallows that one expected miss while every
   core symbol still loads. Loading here registers the context in $Packages, so
   MarkdownToNotebook's own Needs["Wolfram`LeanLink`"] is a no-op. *)

PacletDirectoryLoad[pacletDir]

Quiet @ Needs["Wolfram`LeanLink`"]

If[ ! NameQ["Wolfram`LeanLink`LeanImport"],
    Print["FATAL: Wolfram`LeanLink` failed to load (LeanImport undefined)."];
    Exit[1]
]

(* MarkdownToNotebook is the deployed cloud resource - no local copy - so the
   build needs a cloud connection. A headless `wl` session does not connect
   automatically; CloudConnect[] reconnects silently from cached credentials. *)

Quiet @ Check[If[! TrueQ[$CloudConnected], CloudConnect[]], Null]

mtn = ResourceFunction["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]

If[ ! MatchQ[mtn, _ResourceFunction],
    Print["FATAL: could not load the deployed MarkdownToNotebook resource."];
    Print["  Run `wolframscript -c CloudConnect` once to cache credentials, then retry."];
    Exit[1]
]

(* Documentation/English subtree for each template. *)

subdir = <|
    "Symbol" -> {"Documentation", "English", "ReferencePages", "Symbols"},
    "Guide" -> {"Documentation", "English", "Guides"},
    "TechNote" -> {"Documentation", "English", "Tutorials"},
    "Overview" -> {"Documentation", "English", "Tutorials"}
|>

(* Read the Template value straight from the YAML frontmatter, so we do not
   depend on any particular MarkdownToNotebook "Association" output mode. *)

frontmatterTemplate[srcFile_String] := Block[{text = Import[srcFile, "Text"], m},
    m = StringCases[text, StartOfLine ~~ "Template:" ~~ Whitespace... ~~ v : Except["\n"].. :> StringTrim[v], 1];
    If[m === {}, Missing[], First[m]]
]

(* Tutorials thread state across sections (a LeanEnvironment imported in one
   section is queried in the next), so the whole notebook evaluates in a single
   context. EvaluateSeparator -> None disables the per-heading context reset;
   the default Automatic clears those bindings at each heading, leaving later
   sections with unevaluated references. *)

buildDoc[srcFile_String] := Block[
    {tmpl, baseName, dir, out}
    ,
(* Skip plain-markdown files with no YAML frontmatter (DOC_GUIDE.md is a
   house-style guide for authors, not a doc page). *)
    If[ ! StringStartsQ[StringTrim @ Import[srcFile, "Text"], "---"],
        Print["  (skip ", FileNameTake[srcFile], ": no frontmatter)"];
        Return[]
    ];
    tmpl = frontmatterTemplate[srcFile];
    If[ ! KeyExistsQ[subdir, tmpl],
        Print["  (skip ", FileNameTake[srcFile], ": template ", tmpl, " not a doc page)"];
        Return[]
    ];
    baseName = FileBaseName[srcFile];
    dir = FileNameJoin[Prepend[subdir[tmpl], pacletDir]];
    Quiet @ CreateDirectory[dir, CreateIntermediateDirectories -> True];
    out = FileNameJoin[{dir, baseName <> ".nb"}];
    mtn[srcFile, out, "EvaluateSeparator" -> None];
    Print[
        "  ", FileNameTake[srcFile], " -> Documentation/English/", Last[subdir[tmpl]], "/", baseName, ".nb"
    ]
]

Print["building LeanLink documentation"]

Scan[buildDoc, Sort @ FileNames["*.md", FileNameJoin[{rootDir, "docs"}], Infinity]]

(* Resource-definition notebook -> LeanLink/ResourceDefinition.nb. *)

rd = FileNameJoin[{rootDir, "docs", "ResourceDefinition.md"}]

If[ FileExistsQ[rd],
    mtn[rd, FileNameJoin[{pacletDir, "ResourceDefinition.nb"}], "EvaluateSeparator" -> None];
    Print["  ResourceDefinition.md -> LeanLink/ResourceDefinition.nb"]
]

Print["done"]
#!/usr/bin/env wolframscript
(* Build the LeanLink documentation with PacletPage: each docs/paclet/en/**/*.md page whose
   frontmatter names a page template (Symbol, Guide, TechNote) becomes a notebook
   under LeanLink/Documentation/English/, and docs/paclet/en/ResourceDefinition.md becomes
   LeanLink/ResourceDefinition.nb, the definition notebook submit.wls submits.
   Other markdown (DOC_GUIDE.md) is skipped. No cloud login is needed.

   The build fails on a page that did not convert, and on a section that reads a
   name only an earlier section gave a value (see checkBuild in pacletpage.wl).

   A page is converted again only when its source or the paclet's Wolfram Language
   code (PacletInfo.wl, Kernel/) has changed. The native shim is not part of that:
   after rebuilding only the shim, pass --no-cache to evaluate every example again.

   When every page is evaluated again, as after a change to Kernel/, the Mathlib pages
   load environments of several GB in each of PacletPage's parallel kernels, past 24 GB
   in all. --per-page evaluates each page in a kernel of its own, one after another, into
   the cache (each needs under 4 GB), then builds everything from the cache.

   Run with the `wl` CLI, not wolframscript - wolframscript's init can wedge the
   kernel mid-build:

       wl -f build_docs.wls [--no-cache]
       wl -f build_docs.wls --per-page
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "pacletpage.wl"}]]

Print["PacletPage ", loadPacletPage[]]

(* the pages, by file name, but the author notes and the definition, which the whole build makes *)
documentationPages[] := Select[
	FileNameTake /@ FileNames["*.md", $docsDir, Infinity],
	Function[page, ! MemberQ[{"DOC_GUIDE.md", "ResourceDefinition.md"}, page]]
]

(* one page, evaluated in this kernel, into the cache: what --per-page runs for each page *)
buildPage[page_String] := With[
	{result = WolframInstitute`PacletPage`BuildPacletDocumentation[$leanlinkDir, "Files" -> page, "Parallel" -> False, "Definition" -> None, Sequence @@ $buildOptions]},
	Print[page, ": ", If[AssociationQ[result], {Length[result["Evaluated"]], " evaluated, failed ", result["Failed"]}, result]];
	If[! AssociationQ[result] || result["Failed"] =!= {}, Exit[1]]
]

Which[
	MemberQ[$ScriptCommandLine, "--page"],
		buildPage[Last[$ScriptCommandLine]],
	MemberQ[$ScriptCommandLine, "--per-page"],
		Scan[
			Function[page, Print[StringTrim[RunProcess[{"wl", "-f", $InputFileName, "--page", page}, "StandardOutput"]]]],
			documentationPages[]
		];
		buildDocumentation[],
	True,
		buildDocumentation[]
]

Print["done"]

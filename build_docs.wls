#!/usr/bin/env wolframscript
(* Build the LeanLink documentation with PacletPage: each docs/**/*.md page whose
   frontmatter names a page template (Symbol, Guide, TechNote) becomes a notebook
   under LeanLink/Documentation/English/, and docs/ResourceDefinition.md becomes
   LeanLink/ResourceDefinition.nb, the definition notebook submit.wls submits.
   Other markdown (docs/DOC_GUIDE.md) is skipped. No cloud login is needed.

   The build fails on a page that did not convert, and on a section that reads a
   name only an earlier section gave a value (see checkBuild in pacletpage.wl).

   A page is converted again only when its source or the paclet's Wolfram Language
   code (PacletInfo.wl, Kernel/) has changed. The native shim is not part of that:
   after rebuilding only the shim, pass --no-cache to evaluate every example again.

   Run with the `wl` CLI, not wolframscript - wolframscript's init can wedge the
   kernel mid-build:

       wl -f build_docs.wls [--no-cache]
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "pacletpage.wl"}]]

Print["PacletPage ", loadPacletPage[]]

buildDocumentation[]

Print["done"]

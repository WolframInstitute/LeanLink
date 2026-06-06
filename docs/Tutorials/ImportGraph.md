---
Template: TechNote
Name: ImportGraph
Title: An Import Graph for Mathlib
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/tutorial/ImportGraph
Keywords: [Lean, Mathlib, import, graph, dependency, namespace, visualization]
RelatedGuides: [LeanLink]
RelatedTutorials: [LeanLinkIntro, ExploringMathlib]
---

Lean modules declare their dependencies with `import` lines at the top of each file. Scanning those across a whole project yields a dependency graph. This tutorial builds the import graph of [Mathlib](https://github.com/leanprover-community/mathlib4), aggregated by top-level namespace, straight from the source tree - no build required, since it only reads `.lean` headers. It complements LeanLink's declaration-level [LeanCallGraph]().

## Prerequisites

You need a Mathlib **source** checkout (the `.lean` files; the project need not be compiled for import scanning):

```
(* Terminal:
   git clone https://github.com/leanprover-community/mathlib4 ~/src/mathlib4
*)
```

```wl
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
mathlibSrc = FileNameJoin[{mathlibDir, "Mathlib"}];
mathlibReady = DirectoryQ[mathlibSrc]
```

<!-- => True (when the source is present) -->

## Scanning the Source Tree

Every `.lean` file under `Mathlib/`:

```wl
leanFiles = If[mathlibReady, FileNames["*.lean", mathlibSrc, Infinity], {}];
Length[leanFiles]
```

<!-- => 7791 -->

A module's top-level namespace is the component just after `Mathlib` (so `Mathlib.Algebra.Group.Basic` is in `Algebra`). These helpers map a module name, and a file path, to that namespace:

```wl
namespaceOf[mod_String] := With[{p = StringSplit[mod, "."]},
    If[Length[p] >= 2 && p[[1]] == "Mathlib", p[[2]], Missing[]]];

fileNamespace[file_String] := namespaceOf @ StringRiffle[
    FileNameSplit[StringReplace[FileNameDrop[file, FileNameDepth[mathlibDir]], ".lean" -> ""]], "."];
```

Imports live at the top of a file, so reading only the first 60 lines keeps the scan fast (a couple of seconds for all 7791 files). We keep just the `Mathlib.*` imports and map each to its namespace:

```wl
readImportNamespaces[file_String] := Module[{stream = OpenRead[file], lines},
    lines = ReadList[stream, "String", 60];
    Close[stream];
    DeleteMissing[namespaceOf /@ (
        StringTrim[StringReplace[#, "import " -> ""]] & /@
            Select[lines, StringStartsQ[#, "import "] &])]
];
```

## Building the Namespace Graph

Each file contributes edges from its own namespace to the namespaces it imports; we drop self-loops and duplicates:

```wl
nsEdges = If[ mathlibReady,
    DeleteDuplicates @ DeleteCases[
        Flatten @ Map[
            file |-> (DirectedEdge[fileNamespace[file], #] & /@ readImportNamespaces[file]),
            leanFiles],
        DirectedEdge[x_, x_]],
    {}];
Length[nsEdges]
```

<!-- => 72 -->

Count the files in each namespace - this both sizes the nodes and orders the legend:

```wl
nsCounts = If[mathlibReady, Reverse @ Sort @ Counts[fileNamespace /@ leanFiles], <||>];
Take[Normal[nsCounts], UpTo[5]]
```

<!-- => {"Algebra" -> 1284, "CategoryTheory" -> 1031, "Analysis" -> 779, "RingTheory" -> 657, "Data" -> 639} -->

Color each namespace from the standard scheme, size each node by its file count, and lay the graph out. No background is pinned, so it reads on both light and dark themes:

```wl
importGraph = If[ mathlibReady,
    Module[{namespaces = Keys[nsCounts], maxCount = Max[nsCounts], colorOf},
        colorOf = AssociationThread[namespaces -> (ColorData[97] /@ Range[Length[namespaces]])];
        Graph[namespaces, nsEdges,
            VertexStyle -> Normal[colorOf],
            VertexSize -> AssociationMap[0.3 + 0.7 Sqrt[nsCounts[#]/maxCount] &, namespaces],
            VertexLabels -> Placed["Name", Tooltip],
            EdgeStyle -> Directive[Opacity[0.2], GrayLevel[0.5], Arrowheads[0.012]],
            GraphLayout -> "SpringElectricalEmbedding",
            ImageSize -> 540]
    ],
    "Mathlib source not found"]
```

<!-- => Graph of 32 namespaces, sized by file count, edges = import dependencies -->

## Statistics

The full ranking of namespaces by file count:

```wl
If[ mathlibReady,
    Dataset @ KeyValueMap[<|"Namespace" -> #1, "Files" -> #2|> &, nsCounts],
    "Mathlib source not found"]
```

<!-- => Dataset: Algebra 1284, CategoryTheory 1031, Analysis 779, ... -->

## Declaration-Level Dependencies

This graph is file-level: which *modules* import which. For a finer view - which *declarations* a single constant depends on - LeanLink offers [LeanCallGraph]() and the `"CallGraph"` property of a [LeanTerm](), which trace the proof-term dependencies of one theorem rather than the import structure of whole files.

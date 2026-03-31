# Import Graph for Mathlib

## Setup

```wolfram
Get["Wolfram`LeanLink`"];
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
```

## Scanning Mathlib Source Files

Discover all `.lean` files under `Mathlib/` and parse their `import` statements:

```wolfram
mathlibSrcDir = FileNameJoin[{mathlibDir, "Mathlib"}];
leanFiles = FileNames["*.lean", mathlibSrcDir, Infinity];
Length[leanFiles]
```

```wolfram
(* Build module name from file path: Mathlib/Algebra/Group/Basic.lean -> Mathlib.Algebra.Group.Basic *)
fileToModule[file_String] := Module[{rel, parts},
  rel = FileNameDrop[file, FileNameDepth[mathlibDir]];
  parts = FileNameSplit[StringReplace[rel, ".lean" -> ""]];
  StringRiffle[parts, "."]
];

(* Parse import lines from a file *)
parseImports[file_String] := Module[{lines},
  lines = StringSplit[Import[file, "Text"], "\n"];
  StringTrim[StringReplace[#, "import " -> ""]] & /@
    Select[lines, StringMatchQ[#, "import " ~~ __] &]
];

(* Build all edges — this takes a minute for ~5000 files *)
allModules = fileToModule /@ leanFiles;
importEdges = Flatten[
  Function[file,
    With[{src = fileToModule[file]},
      DirectedEdge[src, #] & /@ parseImports[file]
    ]
  ] /@ leanFiles
];

(* Keep only Mathlib-internal edges *)
moduleSet = Association[# -> True & /@ allModules];
internalEdges = Select[importEdges, KeyExistsQ[moduleSet, #[[2]]] &];
{Length[allModules], Length[internalEdges]}
```

## Module Groups & Colors

Color each node by its top-level Mathlib namespace, matching the leanprover-community import graph style:

```wolfram
topNamespace[name_String] := Module[{parts = StringSplit[name, "."]},
  If[Length[parts] >= 2, parts[[2]], "Other"]
];

(* Curated color palette for Mathlib's major namespaces *)
nameColors = <|
  "Algebra" -> Hue[0.05, 0.85, 0.95],
  "AlgebraicGeometry" -> Hue[0.0, 0.7, 0.85],
  "AlgebraicTopology" -> Hue[0.95, 0.8, 0.7],
  "Analysis" -> Hue[0.12, 0.9, 0.9],
  "CategoryTheory" -> Hue[0.45, 0.8, 0.7],
  "Combinatorics" -> Hue[0.5, 0.7, 0.75],
  "Computability" -> Hue[0.55, 0.6, 0.65],
  "Condensed" -> Hue[0.42, 0.5, 0.6],
  "Control" -> Hue[0.35, 0.7, 0.6],
  "Data" -> Hue[0.4, 0.6, 0.55],
  "Deprecated" -> GrayLevel[0.4],
  "Dynamics" -> Hue[0.3, 0.7, 0.55],
  "FieldTheory" -> Hue[0.15, 0.8, 0.85],
  "Geometry" -> Hue[0.48, 0.75, 0.65],
  "GroupTheory" -> Hue[0.22, 0.85, 0.8],
  "InformationTheory" -> Hue[0.52, 0.5, 0.5],
  "Init" -> Hue[0.58, 0.8, 0.85],
  "Lean" -> Hue[0.55, 0.6, 0.7],
  "LinearAlgebra" -> Hue[0.62, 0.7, 0.75],
  "Logic" -> Hue[0.65, 0.6, 0.6],
  "MeasureTheory" -> Hue[0.7, 0.65, 0.7],
  "ModelTheory" -> Hue[0.72, 0.5, 0.6],
  "NumberTheory" -> Hue[0.78, 0.7, 0.8],
  "Order" -> Hue[0.82, 0.65, 0.75],
  "Probability" -> Hue[0.88, 0.6, 0.7],
  "RepresentationTheory" -> Hue[0.92, 0.55, 0.65],
  "RingTheory" -> Hue[0.02, 0.75, 0.9],
  "SetTheory" -> Hue[0.6, 0.55, 0.65],
  "Tactic" -> Hue[0.18, 0.5, 0.5],
  "Testing" -> GrayLevel[0.45],
  "Topology" -> Hue[0.68, 0.8, 0.85],
  "Util" -> GrayLevel[0.5]
|>;

colorFor[mod_] := Lookup[nameColors, topNamespace[mod], GrayLevel[0.5]]
```

## Import Graph Visualization

```wolfram
(* Count declarations per module as a proxy for size *)
declCounts = Counts[topNamespace /@ allModules];

(* File line counts for node sizing *)
fileSizes = Association[
  Rule[fileToModule[#],
    With[{n = StringCount[Import[#, "Text"], "\n"]}, n]
  ] & /@ leanFiles
];
maxLines = Max[Values[fileSizes]];
nodeSize[mod_] := With[{n = Lookup[fileSizes, mod, 20]},
  Max[0.05, 0.6 (n / maxLines)]
]

(* Build the graph *)
graphNodes = Union[First /@ internalEdges, Last /@ internalEdges];

importGraph = Graph[graphNodes, internalEdges,
  VertexStyle -> (# -> Directive[
    EdgeForm[None], colorFor[#]
  ] & /@ graphNodes),
  VertexSize -> (# -> nodeSize[#] & /@ graphNodes),
  EdgeStyle -> Directive[GrayLevel[0.35, 0.15], AbsoluteThickness[0.1]],
  GraphLayout -> {"SpringElectricalEmbedding",
    "RepulsiveForcePower" -> -1.5,
    "SpringConstant" -> 0.5},
  Background -> GrayLevel[0.12],
  ImageSize -> 1200,
  PlotLabel -> Style["Import Graph for Mathlib", White, Bold, 24,
    FontFamily -> "Helvetica Neue"],
  PlotRangePadding -> Scaled[0.02],
  PerformanceGoal -> "Speed"
]
```

## Legend

```wolfram
legendEntry[label_String, color_] := Row[{
  Graphics[{color, Rectangle[]}, ImageSize -> {12, 12}],
  Style[" " <> label, White, 10, FontFamily -> "Helvetica Neue"]
}, Spacer[2]];

namespaces = Sort[Keys[nameColors]];
legend = Framed[
  Grid[Partition[legendEntry @@@ Normal[KeyTake[nameColors, namespaces]], UpTo[8]],
    Spacings -> {1.5, 0.5}, Alignment -> Left],
  Background -> GrayLevel[0.12],
  FrameStyle -> GrayLevel[0.3],
  RoundingRadius -> 5,
  FrameMargins -> 10
];
legend
```

## Statistics

```wolfram
Grid[
  Prepend[
    SortBy[Tally[topNamespace /@ allModules], -Last[#] &],
    {"Namespace", "File Count"}
  ],
  Frame -> All,
  FrameStyle -> GrayLevel[0.3],
  Background -> GrayLevel[0.12],
  BaseStyle -> {White, 11, FontFamily -> "Helvetica Neue"},
  Alignment -> Left
]
```

---
Template: Symbol
Name: LeanExprGraph
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanExprGraph
Keywords: [Lean, expression, graph, subprocess, visualization, DOT]
SeeAlso: [LeanCallGraph, LeanListTheorems, LeanTerm, ImportDOT]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanExprGraph]()[*root*]</code> generates the expression graph of a Lean constant *root* as a [Graph](), computed by a Lean subprocess.

## Details & Options

- The graph shows the constant's type and term as a tree of expression nodes. Where the in-process `"ExprGraph"` property of a [LeanTerm]() works from an already-imported environment, [LeanExprGraph]() runs the Lean toolchain out of process and reads back a DOT graph (via [ImportDOT]()).
- Options include `"Files"` (bare `.lean` files to load), `"Imports"` / `"ProjectDir"` (a lake project and modules), `"ConstDepth"` (how many constant definitions to expand into, default `1`), and `"Depth"`.
- A subprocess call needs `lean` / `lake` on `PATH`. Loading a large project (Mathlib) into the subprocess is slow; prefer bare `"Files"` for quick graphs.

## Basic Examples

The expression graph of a constant in the bundled examples file:

```wl
ex = PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"];
LeanExprGraph["id_proof", "Files" -> {ex}]
```

<!-- => Graph (6 vertices) of the id_proof expression tree -->

## Properties and Relations

For a constant already in a [LeanEnvironment](), the in-process `"ExprGraph"` property gives the same picture without a subprocess:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
VertexCount @ env["id_proof"]["ExprGraph"]
```

<!-- => 6 -->

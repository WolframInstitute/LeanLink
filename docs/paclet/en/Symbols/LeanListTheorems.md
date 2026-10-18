---
Template: Symbol
Name: LeanListTheorems
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanListTheorems
Keywords: [Lean, theorems, list, subprocess, dataset, filter]
SeeAlso: [LeanListConstants, LeanExprGraph, LeanCallGraph]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanListTheorems]()[]</code> lists a project's theorems, returning a [Dataset]() with `"Kind"` and `"Name"` columns, computed by a Lean subprocess.

## Details & Options

- Options: `"Files"`, `"Imports"` / `"ProjectDir"`, and `"Filter"` (keep only names containing the substring).
- Loading a file pulls in its full transitive environment - including the Lean prelude - so an unfiltered call returns tens of thousands of rows. Always pass a `"Filter"`.

## Basic Examples

List the theorems in the bundled examples file, narrowed by name:

```wl
ex = PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"];
LeanListTheorems["Files" -> {ex}, "Filter" -> "modus_ponens"]
```

<!-- => Dataset: {<|"Kind" -> "theorem", "Name" -> "modus_ponens"|>} -->

## Possible Issues

Without a `"Filter"`, [LeanListTheorems]() returns the entire transitive environment (the prelude alone is tens of thousands of declarations). Narrow with `"Filter"`, or use the [LeanEnvironment]() from [LeanImport]() with a filter for a typed, queryable result.

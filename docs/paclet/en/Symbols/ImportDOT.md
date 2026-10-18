---
Template: Symbol
Name: ImportDOT
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/ImportDOT
Keywords: [DOT, graphviz, import, graph, digraph, visualization]
SeeAlso: [LeanExprGraph, LeanCallGraph]
RelatedGuides: [LeanLink]
---

## Usage

<code>[ImportDOT]()[*"file.dot"*]</code> imports a DOT digraph file as a [Graph](), carrying over node colors, labels, and edge styles.

## Details & Options

- [ImportDOT]() is the reader behind [LeanExprGraph]() and [LeanCallGraph](): the Lean subprocess emits a DOT graph, and [ImportDOT]() turns it into a styled [Graph]().
- It expects the Graphviz convention of **quoted** node and edge names, one statement per line: `"name" [label=..., fillcolor=...];` for nodes and `"src" -> "tgt" [color=...];` for edges. Node `fillcolor`/`label`/`type` and edge `color`/`style`/`penwidth`/`label` attributes are honored.
- All [Graph]() options pass through.

## Basic Examples

Import a small DOT digraph:

```wl
dotSource = StringRiffle[{
    "digraph G {",
    "  \"add_comm\" [label=\"add_comm\", fillcolor=\"#3366cc\", type=\"theorem\"];",
    "  \"Add\" [label=\"Add\", fillcolor=\"#cc6633\"];",
    "  \"add_comm\" -> \"Add\";",
    "}"
}, "\n"];
dotFile = Export[FileNameJoin[{$TemporaryDirectory, "ll_demo.dot"}], dotSource, "Text"];
ImportDOT[dotFile]
```

<!-- => Graph: vertices {"add_comm", "Add"}, edge add_comm -> Add -->

## Possible Issues

Unquoted node names (`a -> b` rather than `"a" -> "b"`) are not recognized - the parser keys on quoted identifiers, the form the Lean tooling emits. Quote every node and edge endpoint.

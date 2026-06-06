---
Template: Symbol
Name: LeanLevelMVar
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanLevelMVar
Keywords: [Lean, universe, level, metavariable, elaboration]
SeeAlso: [LeanLevelParam, LeanMVar, LeanSort]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanLevelMVar]()[*id*]</code> is a universe metavariable - an unresolved universe level the elaborator has yet to assign.

## Details & Options

- It is the universe-level analogue of [LeanMVar](): a placeholder appearing in partially elaborated expressions. It renders as `?id`.

## Basic Examples

A universe metavariable:

```wl
LeanLevelMVar["m"]
```

<!-- => renders as: ?m -->

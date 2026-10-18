---
Template: Symbol
Name: LeanMVar
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanMVar
Keywords: [Lean, metavariable, placeholder, elaboration, CIC]
SeeAlso: [LeanFVar, LeanBVar, LeanLevelMVar]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanMVar]()[*id*]</code> represents a metavariable - an unresolved placeholder that Lean's elaborator has yet to assign.

## Details & Options

- Metavariables appear in partially elaborated expressions and open proof goals, standing for a term to be filled in. It renders as `?id`.

## Basic Examples

A metavariable placeholder:

```wl
LeanMVar["m"]
```

<!-- => renders as: ?m -->

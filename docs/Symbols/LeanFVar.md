---
Template: Symbol
Name: LeanFVar
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanFVar
Keywords: [Lean, free variable, hypothesis, parameter, CIC]
SeeAlso: [LeanBVar, LeanMVar, LeanProj]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanFVar]()[*id*]</code> represents a free variable - a local hypothesis or function parameter named *id*.

## Details & Options

- Where a [LeanBVar]() is bound by position (a de Bruijn index), a [LeanFVar]() is a named local that is free in the current expression, such as a hypothesis in a proof context.
- It renders as its name.

## Basic Examples

A free variable standing for a local hypothesis:

```wl
LeanFVar["h"]
```

<!-- => renders as: h -->

---
Template: Symbol
Name: LeanGoal
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanGoal
Keywords: [Lean, goal, target, context, proof state, hypotheses]
SeeAlso: [LeanState, LeanTactic]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanGoal]()[*assoc*]</code> represents a single proof goal - a target proposition together with its local hypothesis context. Goals are the elements of a [LeanState]()'s `"Goals"` list.

## Details & Options

- A [LeanGoal]() renders as a summary box and exposes `"Target"` (the proposition to prove, as Lean source) and `"Context"` (the local hypotheses).
- After an `intro`-style tactic moves a binder into the context, the introduced hypotheses appear in `"Context"`; the `"Target"` shrinks to what remains to be shown.
- You do not usually build a [LeanGoal]() directly - read it off a [LeanState]().

## Basic Examples

The goal of a freshly opened state:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
s0 = LeanState[env["id_proof"]];
g = s0["Goals"][[1]]
```

<!-- => LeanGoal summary box -->

Its target proposition:

```wl
g["Target"]
```

<!-- => "∀ (P : Prop), P → P" -->

Its local context - empty before any hypotheses are introduced:

```wl
g["Context"]
```

<!-- => {} -->

## Properties and Relations

A [LeanState]() holds one or more [LeanGoal]()s; `"GoalCount"` is the length of its `"Goals"` list.

```wl
Length[s0["Goals"]] == s0["GoalCount"]
```

<!-- => True -->

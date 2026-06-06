---
Template: Symbol
Name: LeanState
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanState
Keywords: [Lean, proof, state, goal, tactic, interactive]
SeeAlso: [LeanTactic, LeanGoal, LeanTerm, LeanEnvironment]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanState]()[*term*]</code> opens the [LeanTerm]() *term* as a proof goal and returns a proof state.

<code>[LeanState]()[*env*, *name*]</code> opens the constant *name* from environment *env*.

## Details & Options

- A [LeanState]() renders as a summary box and exposes properties: `"Goals"` (a list of [LeanGoal]()s), `"GoalCount"`, and `"Complete"` (whether no goals remain).
- Advance the state by applying a [LeanTactic](): <code>[LeanTactic]()[*tac*][*state*]</code> returns the new [LeanState](). A proof is finished when `"Complete"` is `True`.
- Opening a state from a fully-proved theorem still presents the statement as a goal to re-derive interactively; tactics operate on the goal stack the same way Lean's tactic mode does.

## Basic Examples

Open a theorem as a goal:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
s0 = LeanState[env["id_proof"]]
```

<!-- => LeanState summary box, 1 goal -->

How many goals remain, and whether it is finished:

```wl
s0["GoalCount"]
```

<!-- => 1 -->

```wl
s0["Complete"]
```

<!-- => False -->

The first goal's target:

```wl
s0["Goals"][[1]]["Target"]
```

<!-- => "∀ (P : Prop), P → P" -->

## Scope

Drive the proof to completion with a sequence of tactics:

```wl
LeanTactic[{"intro P", "intro h", "exact h"}][s0]["Complete"]
```

<!-- => True -->

The two-argument form opens a constant straight from an environment:

```wl
LeanState[env, "modus_ponens"]["GoalCount"]
```

<!-- => 1 -->

## Possible Issues

A native proof state holds a handle into the Lean runtime; it is valid for the life of the kernel session. Re-import the environment and reopen the state in a fresh session rather than reusing a state captured from a previous one.

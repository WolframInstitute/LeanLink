---
Template: Symbol
Name: LeanTactic
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanTactic
Keywords: [Lean, tactic, proof, state, intro, exact, apply]
SeeAlso: [LeanState, LeanGoal, LeanConst]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanTactic]()[*tac*]</code> represents a Lean tactic given as a source string such as `"intro P"` or `"exact h"`.

<code>[LeanTactic]()[*name*, *args*]</code> builds a structured tactic from a Lean-native name and arguments.

<code>[LeanTactic]()[{*tac1*, *tac2*, ...}]</code> is a tactic sequence.

A tactic is applied to a [LeanState]() by function application: <code>[LeanTactic]()[*tac*][*state*]</code> returns the new [LeanState]().

## Details & Options

- The string form takes ordinary Lean tactic syntax. The structured form names a tactic and supplies its arguments as Wolfram values: <code>[LeanTactic]()["intro", {"P", "h"}]</code>, <code>[LeanTactic]()["exact", [LeanConst]()["h"]]</code>.
- A list groups tactics into a sequence applied left to right, equivalent to applying each in turn.
- Application is a pure transformation of proof states: each step returns a new [LeanState]() rather than mutating the old one.

## Basic Examples

A tactic as a value:

```wl
LeanTactic["intro P"]
```

<!-- => LeanTactic["intro P"] -->

The example environment bundled with the paclet:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]]
```

<!-- => LeanEnvironment summary box: 32 constants -->

Its identity theorem, opened as a proof state:

```wl
s0 = LeanState[env["id_proof"]]
```

<!-- => 1 goal: ⊢ ∀ (P : Prop), P → P -->

Apply a sequence to the proof state:

```wl
s1 = LeanTactic[{"intro P", "intro h", "exact h"}][s0]
```

<!-- => No goals -->

It closes the goal:

```wl
s1["Complete"]
```

<!-- => True -->

## Scope

The example environment bundled with the paclet:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]]
```

<!-- => LeanEnvironment summary box: 32 constants -->

Its identity theorem, opened as a proof state:

```wl
s0 = LeanState[env["id_proof"]]
```

<!-- => 1 goal: ⊢ ∀ (P : Prop), P → P -->

Step one tactic at a time, threading the state. Introduce the proposition:

```wl
s1 = LeanTactic["intro P"][s0]
```

<!-- => 1 goal: P : Prop ⊢ P → P -->

Then the hypothesis:

```wl
s2 = LeanTactic["intro h"][s1]
```

<!-- => 1 goal: P : Prop, h : P ⊢ P -->

And close the goal with the hypothesis:

```wl
s3 = LeanTactic["exact h"][s2]
```

<!-- => No goals -->

The proof is complete:

```wl
s3["Complete"]
```

<!-- => True -->

The structured form names the tactic and passes arguments as Wolfram values:

```wl
LeanTactic["exact", LeanConst["h"]]
```

<!-- => exact h -->

It applies to a state as a string tactic does. After two structured `intro` steps, it closes the identity's goal:

```wl
LeanTactic["exact", LeanConst["h"]][LeanTactic["intro", {"h"}][LeanTactic["intro", {"P"}][s0]]]
```

<!-- => No goals -->

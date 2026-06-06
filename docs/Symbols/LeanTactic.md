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

Apply a sequence to a proof state and check it closes:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
s0 = LeanState[env["id_proof"]];
LeanTactic[{"intro P", "intro h", "exact h"}][s0]["Complete"]
```

<!-- => True -->

## Scope

Step one tactic at a time, threading the state:

```wl
s1 = LeanTactic["intro P"][s0];
s2 = LeanTactic["intro h"][s1];
s3 = LeanTactic["exact h"][s2];
s3["Complete"]
```

<!-- => True -->

The structured form names the tactic and passes arguments as Wolfram values:

```wl
LeanTactic["exact", LeanConst["h"]]
```

<!-- => LeanTactic["exact", LeanConst["h", {}]] -->

```wl
LeanTactic["exact", LeanConst["h"]][LeanTactic["intro", {"h"}][LeanTactic["intro", {"P"}][s0]]]["Complete"]
```

<!-- => True -->

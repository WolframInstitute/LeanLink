---
Template: Symbol
Name: LeanImport
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanImport
Keywords: [Lean, import, module, Mathlib, environment, olean, constants]
SeeAlso: [LeanImportString, LeanEnvironment, LeanTerm, LeanListConstants, LeanExport]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanImport]()[*module*]</code> imports the constants of a compiled Lean module and returns a [LeanEnvironment]().

<code>[LeanImport]()[*file*]</code> imports from a `.lean` source file path.

## Details & Options

- The result is a [LeanEnvironment]() - a typed wrapper over <code>[Association]()[*name* -> [LeanTerm](), ...]</code>. Index it by constant name, or query it with [Keys](), [Length](), and [Information]().
- A *module* argument (`"Mathlib.Algebra.Group.Basic"`) is resolved inside a Lean project; a *file* argument is a path to a `.lean` source file (such as the bundled `Examples.lean`).
- The following options are accepted:

| Option | Default | Description |
|---|---|---|
| `"ProjectDir"` | `Automatic` | the Lake project the module is resolved in, with its packages and path dependencies |
| `"Imports"` | `{}` | extra modules to load alongside the target |
| `"Filter"` | `""` | keep only constants whose name contains this substring |
| `"IncludeInternal"` | `False` | include compiler-internal / private declarations |

- Importing a module requires that project to be **built** (`lake build`). A module with no compiled `.olean` file in the project's search path fails: [LeanImport]() returns [$Failed]() with a message that names it.

## Basic Examples

Import the bundled example environment from its file path:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]]
```

<!-- => LeanEnvironment summary box: 32 constants -->

How many constants it holds:

```wl
Length[env]
```

<!-- => 32 -->

The constant names:

```wl
Keys[env]
```

<!-- => {"Vec.head", "id_proof", "add_zero_term", "fin_example", "add_comm_proof", "contrapositive", ...} -->

A single constant, indexed by name, is a [LeanTerm]():

```wl
env["id_proof"]["TypeForm"]
```

<!-- => "∀ (P : Prop), P → P" -->

## Scope

Import a module from a built mathlib4 checkout with `"ProjectDir"`, narrowing to one theorem with `"Filter"` (gated so the page builds without Mathlib):

```wl
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
If[ DirectoryQ[FileNameJoin[{mathlibDir, ".lake", "build"}]],
    algEnv = LeanImport["Mathlib.Algebra.Group.Basic",
        "ProjectDir" -> mathlibDir, "Filter" -> "mul_comm"];
    algEnv["mul_comm"]["TypeForm"],
    "Mathlib not built - run: lake exe cache get && lake build Mathlib.Algebra.Group.Basic"
]
```

<!-- => "∀ {G : Type u_1} [inst : CommMagma G] (a b : G), a * b = b * a" -->

The example environment bundled with the paclet:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]]
```

<!-- => LeanEnvironment summary box: 32 constants -->

The breakdown of the bundled environment's constants by kind:

```wl
Information[env, "Kinds"]
```

<!-- => <|"theorem" -> 18, "def" -> 11, "constructor" -> 2, "inductive" -> 1|> -->

## Possible Issues

`"Filter"` matches a substring of the *fully qualified* name, so `"comm"` keeps `mul_comm`, `add_comm`, `And.comm`, and so on. Use a more specific fragment to narrow further:

```wl
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
If[ DirectoryQ[FileNameJoin[{mathlibDir, ".lake", "build"}]],
    Length @ LeanImport["Mathlib.Logic.Basic",
        "ProjectDir" -> mathlibDir, "Filter" -> "comm"],
    "Mathlib not built"
]
```

<!-- => 476 (or "Mathlib not built") -->

---

A module that is not in the search path fails, and the message names it; here the name of Lean's prelude has a typo:

```wl
LeanImport["Init.Prelud"]
```

<!-- => LeanImport::err message: Failed to load environment: no directory of the search path has the module Init.Prelud; then $Failed -->

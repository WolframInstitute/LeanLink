---
Template: Symbol
Name: LeanImport
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanImport
Keywords: [Lean, import, module, Mathlib, environment, olean, constants]
SeeAlso: [LeanImportString, LeanEnvironment, LeanTerm, LeanListConstants, LeanExport, MathlibInstallation]
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
| `"PrepareEvaluation"` | `False` | make the state evaluations start from while importing, so the first [LeanEvaluate]() needs no setup |
| `"LoadExtensions"` | `True` | load the state of Lean's environment extensions: notation, instances, simp sets |

- `"ProjectDir" -> Automatic` is the current directory when it is a Lake project. Otherwise it is the Mathlib that [InstallMathlib]() installed in its default directory, once [MathlibInstallation]() reports it `"Ready"`, and the current directory when there is none. [LeanExpr]() and the other functions whose `"ProjectDir"` defaults to `Automatic` resolve it the same way, except that those given `"Files"` use the folder of the first file.
- Importing a module requires that project to be **built** (`lake build`). A module with no compiled `.olean` file in the project's search path fails: [LeanImport]() returns [$Failed]() with a message that names it. When Lean itself cannot load the modules, the message gives Lean's reason.
- `"LoadExtensions" -> False` imports the constants without the state of Lean's environment extensions, which for a large import is most of its time. Reading constants, their types and values, and [LeanToTypeTheory]() work as before. Evaluation needs the extensions, so `"PrepareEvaluation" -> True` is refused with it.
- A *file* can `import` other `.lean` files of its folder, or of the Lake project around it: they are compiled first, in import order, so `import B` finds `B.lean` next to the file and `import Sub.C` finds `Sub/C.lean`. A GitHub URL import does the same with the files it downloads.
- `"PrepareEvaluation" -> True` makes the state evaluations start from during the import. That takes a few milliseconds, or longer for an environment without Lean's JSON modules, such as `Init`, which imports them once. It requires explicit modules or a source file, rather than a collection of separately discovered environments. Preparation uses the default `"TimeLimit"` of [LeanEvaluate](); when it fails or is interrupted, the environments the import made are released.

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

Import a module from the Mathlib that [InstallMathlib]() installed, with `"ProjectDir"` at its directory, narrowing to one theorem with `"Filter"` (gated so the page builds without Mathlib):

```wl
mathlibDir = MathlibInstallation[]["Directory"];
If[ MathlibInstallation[]["Status"] === "Ready",
    algEnv = LeanImport["Mathlib.Algebra.Group.Basic",
        "ProjectDir" -> mathlibDir, "Filter" -> "mul_comm"];
    algEnv["mul_comm"]["TypeForm"],
    "Mathlib is not installed - run InstallMathlib[]"
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

## Options

### PrepareEvaluation

Prepare evaluation while importing a module:

```wl
env = LeanImport["Init", "PrepareEvaluation" -> True, "Filter" -> "Nat.add"]
```

Apply its addition function:

```wl
LeanEvaluate[env["Nat.add"], 17, 25]
```

<!-- => 42 -->

Release the environment:

```wl
LeanFreeEnvironment[env]
```

## Possible Issues

`"Filter"` matches a substring of the *fully qualified* name, so `"comm"` keeps `mul_comm`, `add_comm`, `And.comm`, and so on. Use a more specific fragment to narrow further:

```wl
mathlibDir = MathlibInstallation[]["Directory"];
If[ MathlibInstallation[]["Status"] === "Ready",
    Length @ LeanImport["Mathlib.Basic.Logic.Basic",
        "ProjectDir" -> mathlibDir, "Filter" -> "comm"],
    "Mathlib is not installed"
]
```

<!-- => 463 (or "Mathlib is not installed") -->

---

A module that is not in the search path fails, and the message names it; here the name of Lean's prelude has a typo:

```wl
LeanImport["Init.Prelud"]
```

<!-- => LeanImport::err message: Failed to load environment: no directory of the search path has the module Init.Prelud; then $Failed -->

---

A `"Filter"` that no constant name contains also gives `$Failed`, with a message saying the modules loaded:

```wl
LeanImport["Init.Prelude", "Filter" -> "noConstantHasThisName"]
```

<!-- => LeanImport::nomatch message: The imports {Init.Prelude} loaded, but no constant of them has a name containing "noConstantHasThisName"; then $Failed -->

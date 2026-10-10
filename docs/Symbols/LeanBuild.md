---
Template: Symbol
Name: LeanBuild
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanBuild
Keywords: [Lean, lake, build, olean, toolchain, project, compile]
SeeAlso: [LeanImport, LeanEvaluate, LeanImportString]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanBuild]()[*dir*, {*"Module1"*, ...}]</code> builds those modules of the Lake project in *dir* and returns [Success]() or a [Failure]() carrying lake's output.

<code>[LeanBuild]()[*dir*]</code> builds the project's default targets.

## Details & Options

- [LeanImport]() loads a project's compiled `.olean` files, so the modules must be built first; [LeanBuild]() does that from the Wolfram Language.
- The build uses the `lake` of the toolchain that the project's `lean-toolchain` file pins, called directly rather than through elan's proxy, so a build never downloads a toolchain. A pin that is not installed returns a `"ToolchainNotInstalled"` [Failure]() naming the `elan toolchain install` command.
- A failed build returns a `"LeanBuildFailed"` [Failure]() whose `"Output"` holds lake's messages and whose `"ExitCode"` is lake's exit code.
- A successful build drops LeanLink's cached environments for that project, so the next [LeanImport]() loads the new `.olean` files.
- The project should pin the same Lean version as LeanLink's runtime (`leanprover/lean4:v4.30.0`); otherwise [LeanBuild]() warns, since [LeanImport]() cannot load the result.

## Basic Examples

Build a module of a small Lake project, then import it:

```wl
dir = CreateDirectory[];
Export[FileNameJoin[{dir, "lakefile.toml"}], "name = \"demo\"\n[[lean_lib]]\nname = \"Demo\"\n", "Text"];
Export[FileNameJoin[{dir, "lean-toolchain"}], "leanprover/lean4:v4.30.0", "Text"];
Export[FileNameJoin[{dir, "Demo.lean"}], "theorem two_eq : 1 + 1 = 2 := rfl\n", "Text"];
LeanBuild[dir, {"Demo"}]
```

<!-- => Success["Built", ...] -->

```wl
LeanImport["Demo", "ProjectDir" -> dir, "Filter" -> "two_eq"]["two_eq"]["TypeForm"]
```

<!-- => "1 + 1 = 2" -->

## Possible Issues

A module that does not compile gives a [Failure]() whose `"Output"` carries Lean's error:

```wl
Export[FileNameJoin[{dir, "Demo.lean"}], "theorem bad : 1 + 1 = 3 := rfl\n", "Text"];
r = LeanBuild[dir, {"Demo"}];
{r["Tag"], StringContainsQ[r["Output"], "error"]}
```

<!-- => {"LeanBuildFailed", True} -->

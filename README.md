# LeanLink

Wolfram Language paclet for native integration with [Lean 4](https://lean-lang.org/).

**Documentation:** [wolframcloud.com/obj/wolframinstitute/LeanLink](https://www.wolframcloud.com/obj/wolframinstitute/LeanLink)

## Install

From the [Wolfram Paclet Repository](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/LeanLink/):

```wolfram
PacletInstall["Wolfram/LeanLink"]
Needs["Wolfram`LeanLink`"]
```

LeanLink loads the Lean runtime from the toolchain it is built against, installed with [elan](https://github.com/leanprover/elan):

```bash
elan toolchain install leanprover/lean4:v4.30.0
```

The TypeTheory bridge (`LeanToTypeTheory`, `TypeTheoryToLean`) also needs the paclet [WolframInstitute/TypeTheory](https://www.wolframcloud.com/obj/wolframinstitute/TypeTheory), which it loads on first use:

```wolfram
PacletInstall[ResourceObject["https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/TypeTheory"]]
```

## Features

- **Native LibraryLink bridge** — embeds the Lean runtime directly via a C shim, no subprocess overhead
- **Environment loading** — imports modules from Lake projects (Mathlib included), `.lean` files and source strings; queries constants, theorems, types
- **Lean notation** — `"TypeForm"` prints a type with Lean's own pretty-printer, opening the namespaces you name
- **Symbolic expressions** — Lean expressions as `LeanApp`, `LeanConst`, `LeanForall`, etc., displayed in Lean notation
- **Interactive proofs** — `LeanState`/`LeanTactic` for step-by-step proof construction
- **Provenance and verification** — the axioms a theorem depends on, a kernel replay of its module that catches declarations which skipped the kernel, the module that declares it, and its source
- **Builds and evaluation** — `LeanBuild` builds a Lake project; `LeanEvaluate` runs `#eval` and returns the value as Wolfram data
- **Graphs** — expression trees and the dependency graph of a proof
- **ProofToLean** — transpile Wolfram `ProofObject` to Lean environments
- **TypeTheory bridge**: `LeanToTypeTheory` imports Lean constants into the Wolfram Language proof engine [TypeTheory](https://www.wolframcloud.com/obj/wolframinstitute/TypeTheory), whose own kernel checks them again: all of Lean's `Init.Prelude`, whole Mathlib modules such as `Mathlib.Logic.Nonempty`, mutual and nested inductive types, string literals, quotients with their computation rule, and arithmetic on literals, which TypeTheory computes with integers as Lean's kernel does with GMP; `TypeTheoryToLean` writes TypeTheory proofs, mutual blocks included, as Lean source for Lean's kernel
- **LeanCompile** — lower Lean definitions to native code through `FunctionCompile`

## Quick Start

```wolfram
Needs["Wolfram`LeanLink`"]

(* The example environment bundled with the paclet *)
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
env["id_proof"]["TypeForm"]
(* "∀ (P : Prop), P → P" *)

(* Prove it tactic by tactic *)
LeanTactic[{"intro P", "intro h", "exact h"}][LeanState[env["id_proof"]]]["Complete"]
(* True *)

(* A theorem from a built mathlib4 checkout *)
alg = LeanImport["Mathlib.Algebra.Group.Basic",
  "ProjectDir" -> FileNameJoin[{$HomeDirectory, "src", "mathlib4"}], "Filter" -> "mul_comm"];
alg["mul_comm"]["TypeForm"]
(* "∀ {G : Type u_1} [inst : CommMagma G] (a b : G), a * b = b * a" *)

alg["mul_comm"]["Module"]
(* "Mathlib.Algebra.Group.Defs" *)

(* Evaluate Lean code *)
LeanEvaluate["(List.range 10).map (· ^ 2)"]
(* {0, 1, 4, 9, 16, 25, 36, 49, 64, 81} *)
```

## Documentation

The [documentation site](https://www.wolframcloud.com/obj/wolframinstitute/LeanLink) has a reference page for every symbol, the guide [Lean 4 from the Wolfram Language](https://www.wolframcloud.com/obj/wolframinstitute/LeanLink#guide/LeanLink), and four tutorials:

- [Getting Started with LeanLink](https://www.wolframcloud.com/obj/wolframinstitute/LeanLink#tutorial/LeanLinkIntro) — environments, terms, proof states and tactics
- [Exploring Mathlib with LeanLink](https://www.wolframcloud.com/obj/wolframinstitute/LeanLink#tutorial/ExploringMathlib) — Mathlib theorems, their binders and typeclasses
- [An Import Graph for Mathlib](https://www.wolframcloud.com/obj/wolframinstitute/LeanLink#tutorial/ImportGraph) — Mathlib's module dependencies, by namespace
- [Checking Mathlib with TypeTheory](https://www.wolframcloud.com/obj/wolframinstitute/LeanLink#tutorial/CheckingMathlib) — a whole module of Mathlib, checked again by TypeTheory's kernel

The same pages install with the paclet and open in the Documentation Center.

A standalone notebook, not part of the documentation: [TuringMachineSuccessor](https://www.wolframcloud.com/obj/nikm/LeanLink/TuringMachineSuccessor.nb) — proving Turing machines compute successor, with proof term graphs for every class in (2,2) and (3,2).

## Building

### Prerequisites

- [Lean 4](https://leanprover.github.io/lean4/doc/setup.html) via elan
- [Wolfram Language](https://www.wolfram.com/language/) 15.0+
- CMake 3.20+, C compiler

### Native library

```bash
./build.sh
```

This runs `lake build` for the Lean library, then cross-compiles the C shim with CMake for macOS (ARM64, x86-64), Linux (x86-64, ARM64) and Windows (x86-64), into `LeanLink/LibraryResources/<platform>/`.

### Tests

```bash
./run_tests.wls
```

### Documentation

```bash
wl -f build_docs.wls
```

Builds the markdown pages in `docs/paclet/en/` into notebooks under `LeanLink/Documentation/English/`, and `docs/paclet/en/ResourceDefinition.md` into `LeanLink/ResourceDefinition.nb`, with [PacletPage](https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/PacletPage) 0.3.11 or later, installed or in a checkout named by `PACLETPAGE_DIR`. The build stops on a page that does not convert, or whose section reads a variable that only an earlier section set. Unchanged pages come from a cache; pass `--no-cache` after rebuilding only the native library. [docs/paclet/en/DOC_GUIDE.md](docs/paclet/en/DOC_GUIDE.md) is the guide to writing the pages.

### Publishing

```bash
wl -f release.wls              # the documentation site and the paclet resource
wl -f release.wls --dry-run    # build and check, deploy nothing
wl -f release.wls --republish  # replace this version's release, as after a docs-only fix
wolframscript -f submit.wls    # the Wolfram Paclet Repository
```

`release.wls` builds and checks the documentation as `build_docs.wls` does, then builds the paclet archive (without the Lean runtime), checks that the archive loads on its own in a fresh kernel, deploys the paclet resource, and publishes and checks the [documentation site](https://www.wolframcloud.com/obj/wolframinstitute/LeanLink). It publishes from a kernel connected as `wolframinstitute@wolframinstitute.org`. A dry run deploys nothing, runs under any login, and leaves the archive in `LeanLink/build/`, ready for `PacletInstall`. PacletPage refuses to replace a version already published from another commit: bump the version, or pass `--republish` for a documentation-only fix.

`submit.wls` submits `LeanLink/ResourceDefinition.nb` to the Paclet Repository as an account authorized for the paclet's `Wolfram` publisher ID. Each script connects as the account in `WOLFRAM_ID` / `WOLFRAM_PASSWORD` when they are set, and otherwise uses the cached login.

## Architecture

```
LeanLink/
├── LeanLink/                  # Paclet root
│   ├── PacletInfo.wl
│   ├── Kernel/                # Wolfram Language package
│   │   ├── LeanLink.wl        # Entry point
│   │   ├── Lean.wl            # Main API, pretty-printer, proof engine
│   │   ├── ProofToLean.wl     # ProofObject -> Lean transpiler
│   │   ├── TypeTheoryBridge.wl       # LeanToTypeTheory, TypeTheoryToLean: entry points
│   │   ├── TypeTheoryTranslation.wl  # The bridge, loaded with TypeTheory on first use
│   │   └── Utilities.wl       # ImportDOT and other helpers
│   ├── Assets/                # Bundled .lean files, hero image
│   ├── Tests/                 # .wlt test suite
│   ├── Documentation/         # Built documentation notebooks (gitignored)
│   └── LibraryResources/      # Built shims (per-platform, gitignored)
├── Native/                    # Lean + C source
│   ├── lib/LeanLink/          # Lean 4 source
│   │   ├── EnvStore.lean      # Environment loading, WXF goal export
│   │   └── WXF.lean           # WXF binary serialization
│   └── shim/
│       ├── leanlink_shim.c    # LibraryLink C bridge
│       └── CMakeLists.txt     # Multi-platform build
├── docs/paclet/en/            # Paclet documentation sources (markdown) and DOC_GUIDE.md
├── Notebooks/                 # Standalone example notebooks (markdown sources)
├── GUIDE.md                   # Wolfram Language style guide for the sources
├── build.sh                   # Native build
├── build_docs.wls             # Documentation build (PacletPage)
├── release.wls                # Documentation site and paclet resource (PacletPage)
├── pacletpage.wl              # Settings shared by build_docs.wls and release.wls
├── submit.wls                 # Paclet Repository submission
├── typetheory_coverage.wls    # How much of a Lean library TypeTheory checks
└── run_tests.wls              # Test runner
```

## License

MIT

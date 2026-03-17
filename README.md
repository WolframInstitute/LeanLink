# LeanLink

Wolfram Language paclet for native integration with [Lean 4](https://lean-lang.org/).

## Features

- **Native LibraryLink bridge** — embeds the Lean runtime directly via a C shim, no subprocess overhead
- **Environment loading** — loads `.olean` environments, queries constants, theorems, types
- **Symbolic expressions** — Lean expressions as `LeanApp`, `LeanConst`, `LeanForall`, etc.
- **Pretty printing** — WL-side notation rules for source-code-like output (`a * b = b * a`)
- **Interactive proofs** — `LeanState`/`LeanTactic` for step-by-step proof construction
- **Mathlib support** — import and inspect Mathlib modules
- **ProofToLean** — transpile Wolfram `ProofObject` to Lean environments

## Quick Start

```wolfram
<< LeanLink`

(* Import Mathlib algebra *)
env = LeanImport["Mathlib.Algebra.Group.Basic",
  "ProjectDir" -> "~/src/mathlib4",
  "Imports" -> {"Mathlib.Algebra.Group.Basic"}];

env["mul_comm"]["TypeForm"]
(* "∀ {G : Type u_1} [inst : CommMagma G] (a : G) (b : G), a * b = b * a" *)

(* Interactive proof *)
state = LeanState[env["one_mul"]];
state // LeanTactic["simp"]
```

## Building

### Prerequisites

- [Lean 4](https://leanprover.github.io/lean4/doc/setup.html) via elan
- [Wolfram Language](https://www.wolfram.com/language/) 15.0+
- CMake 3.20+, C compiler

### Build

```bash
./build.sh
```

This runs `lake build` for the Lean library, then `cmake` + `make` for the C shim.
The dylib is output to `LeanLink/LibraryResources/<platform>/`.

### Paclet archive

```bash
wolframscript -f build.wls
```

Packs `LeanLink/` into a `.paclet` file, installs it, and uploads to Wolfram Cloud.

### Tests

```bash
wolframscript -f run_tests.wls
```

### Publish notebooks

```bash
wolframscript -f publish_notebooks.wls
```

Converts `.md` → `.nb`, evaluates all cells (via headless `MathematicaServer`), uploads to Wolfram Cloud.

## Notebooks

- [LeanLinkIntro](https://www.wolframcloud.com/obj/nikm/LeanLink/LeanLinkIntro.nb) — Getting started with LeanLink
- [MathlibExamples](https://www.wolframcloud.com/obj/nikm/LeanLink/MathlibExamples.nb) — Exploring Mathlib from Wolfram Language

## Architecture

```
LeanLink/
├── LeanLink/                  # Paclet root
│   ├── PacletInfo.wl
│   ├── Kernel/                # Wolfram Language package
│   │   └── Lean.wl            # Main API, pretty-printer, proof engine
│   ├── Assets/                # Bundled .lean files
│   ├── Tests/                 # .wlt test suite
│   └── LibraryResources/      # Built dylibs (per-platform, gitignored)
├── Native/                    # Lean + C source
│   ├── lib/LeanLink/          # Lean 4 source
│   │   ├── EnvStore.lean      # Environment loading, WXF goal export
│   │   └── WXF.lean           # WXF binary serialization
│   └── shim/
│       ├── leanlink_shim.c    # LibraryLink C bridge
│       └── CMakeLists.txt     # Multi-platform build
├── Notebooks/                 # Example notebooks (.md source + .nb)
├── build.sh                   # Native build script
├── build.wls                  # Paclet archive script
├── publish_notebooks.wls      # Notebook evaluation + cloud upload
└── run_tests.wls              # Test runner
```

## License

MIT

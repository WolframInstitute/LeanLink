# Coverage of Mathlib in TypeTheory

`typetheory_coverage.wls` imports every constant of a list of Lean modules, with what it depends on, into one
TypeTheory environment, a constant at a time, and reports what checks. The tutorial *Checking Mathlib with TypeTheory*
quotes its figures for the module lists here.

| List | Modules | What it is |
|---|---|---|
| `mathlib-bottom.txt` | 39 | every module of Mathlib v4.35.0 outside `Tactic`, `Lean` and `Util` whose only Mathlib import is `Mathlib.Init` |
| `mathlib-higher.txt` | 27 | one module for each topic the tutorial names, from the real numbers to the p-adic numbers, with `Real.sqrt`, quadratic reciprocity, `Data.Int.Init` and tensor products of algebras |

## Figures

| List | Constants | Checked | Time | Peak memory | Versions |
|---|---|---|---|---|---|
| `mathlib-bottom.txt` | 10,465 | 10,465 | 568 s | 0.9 GB | LeanLink 1.2.13, TypeTheory 0.46.0, Wolfram 15.0, macOS ARM64 |
| `mathlib-higher.txt` | not measured yet | | | | |

## Running a list

What a machine needs:

- **Wolfram 15.0** with `wolframscript`.
- **Lean v4.35.0**, installed with elan as the toolchain `leanprover/lean4:v4.35.0` (`elan toolchain install
  leanprover/lean4:v4.35.0`). LeanLink finds it under `~/.elan/toolchains`, or under `$ELAN_HOME`.
- **Mathlib at the tag `v4.35.0`** (commit `56a005855e`), built: `git clone --branch v4.35.0 --depth 1
  https://github.com/leanprover-community/mathlib4`, then `lake exe cache get` in it, which downloads the compiled
  `.olean` files, about 6 GB under `.lake/build/lib`, with no compilation.
- **This repository** at `main`, with the native shim of the machine's platform in
  `LeanLink/LibraryResources/<SystemID>/`. The shims are not in git. Take the one for the platform from the released
  paclet, `unzip Wolfram__LeanLink-1.2.13.paclet 'Wolfram__LeanLink-1.2.13/LibraryResources/Linux-x86-64/*'` and move
  that folder to `LeanLink/LibraryResources/Linux-x86-64/`, or build all of them with `./build.sh`, which needs cmake,
  a C compiler and the Lean toolchain. The archive is the `PacletFile` of the resource
  `https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/Wolfram/LeanLink`.
- **TypeTheory** 0.46.0 or later, installed as a paclet, or a checkout given with `--typetheory`.

The command, from the repository:

```
wolframscript -file typetheory_coverage.wls --modules coverage/mathlib-higher.txt \
    --project-dir ~/mathlib4 --time-limit 300 --out higher-status.wl
```

It prints a line every 200 constants and one after each module, and ends with `walked N, checked N, failed N,
blocked N` and the constants that took longest. `--out` saves every constant's verdict every 100 constants, and the
constant being checked in `higher-status.wl.current`, so a run that is stopped leaves what it found. At the end it also
writes every constant's seconds to `higher-status.wl.seconds.wl`.

Two more options:

- `--constants name,name,...` checks the cones of those constants alone, with the modules only as the imports that
  declare them: a proof's headline theorems, not every constant of their modules.
- `--budget seconds` and `--resume` split a run over several kernels, for a machine that allows only short runs. With
  `--budget`, a run stops once its kernel has run that many seconds, writes the TypeTheory environment it built, the
  verdicts and the walk next to `--out`, and exits with status 3. Run the same command with `--resume` until it exits
  with 0. Each constant is still checked once, in an environment of constants that checked. A loop of such runs, each
  under a memory cap of 2 GB and 120 s, checked the 7,192 constants of a proof's two theorems in ten runs.

The higher list reaches most of Mathlib's base, about 70,000 constants. Checked a constant at a time at the bottom
list's rate, 18 a second, that is one to two hours on one core. The run before imports were shared took 7 GB; allow
8 GB.

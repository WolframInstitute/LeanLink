# Saved cones

Cones of Mathlib as saved TypeTheory environments: each file holds a constant of Mathlib and every constant it
depends on, as `LeanToTypeTheory` imports them. They are the cases of `typetheory_benchmark.wls` (`bench/Cases.wl`),
for kernels to check: `TypeTheoryEnvironment[File["bench/cones/omega.wxf"], "Check" -> True]` reads a file and
replays every declaration with `TypeTheoryCheck`, on any kernel.

| File | Constant | Constants |
|---|---|---|
| `binaryRec.wxf` | `Nat.binaryRec.eq_def` | 721 |
| `omega.wxf` | `Int.Internal.Linear.Poly.denote'_go_eq_denote` | 1008 |
| `balanceL.wxf` | `_private.Std.Data.DTreeMap.Internal.Balancing.0.Std.DTreeMap.Internal.Impl.balanceL._proof_9` | 1544 |

They were written by TypeTheory 0.15.1 from Mathlib `56a005855e` (2026-10-13) on Lean v4.35.0, and are kept as they
are: they are the files with which a kernel's TypeTheory check caught a kernel bug, on 2026-10-31.
`bench/save_cones.wls` writes them again, from the Mathlib and TypeTheory checked out:

```sh
wl -f bench/save_cones.wls                        # binaryRec, omega and balanceL, to bench/cones
wl -f bench/save_cones.wls sqrt --out /tmp/cones  # another case of bench/Cases.wl, elsewhere
```

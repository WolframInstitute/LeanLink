/- Lean's side of typetheory_benchmark.wls: imports a module of a Lake project, and replays the cone of each
   root constant (every constant it depends on, with whole inductive blocks, which is what TypeTheory's import
   checks) into an empty environment, as lean4checker does, and prints how long the replay took.

       cd ~/src/mathlib4 && lake env lean --run <LeanLink>/bench/ConeReplay.lean Module Root ... [--modules M ...]
-/

import Lean
open Lean

/-- Every constant `root` depends on, with whole inductive blocks: what TypeTheory's import checks. -/
partial def cone (env : Environment) (roots : List Name) : Std.HashMap Name ConstantInfo := Id.run do
  let mut seen : Std.HashMap Name ConstantInfo := {}
  let mut todo := roots
  while true do
    match todo with
    | [] => break
    | name :: rest =>
      todo := rest
      if seen.contains name then continue
      let some ci := env.find? name | continue
      seen := seen.insert name ci
      let mut next : List Name := ci.getUsedConstantsAsSet.toList
      match ci with
      | .inductInfo info =>
        next := next ++ info.all ++ info.ctors ++ info.all.map (· ++ `rec)
        -- the recursors on the containers a nested type is nested in, X.rec_1, X.rec_2, ...
        for i in [1:info.numNested + 1] do
          next := (info.all.head! ++ Name.mkSimple s!"rec_{i}") :: next
      | .ctorInfo info => next := info.induct :: next
      | .recInfo info => next := next ++ info.all
      | _ => pure ()
      todo := next ++ todo
  return seen

def main (args : List String) : IO Unit := do
  let module := args.head!.toName
  -- the roots, and with --modules M1 M2 ..., every constant those modules declare, as one more root set
  let (rootArgs, moduleArgs) := match args.tail!.span (· != "--modules") with
    | (r, _ :: ms) => (r, ms)
    | (r, []) => (r, [])
  let roots := rootArgs.map String.toName
  initSearchPath (← findSysroot)
  let t0 ← IO.monoMsNow
  let env ← importModules #[{ module }] {} 0
  let t1 ← IO.monoMsNow
  IO.println s!"imported {module} in {t1 - t0} ms"
  unless moduleArgs.isEmpty do
    let mut moduleRoots : List Name := []
    for m in moduleArgs do
      match env.getModuleIdx? m.toName with
      | some idx => moduleRoots := moduleRoots ++ (env.header.moduleData[idx.toNat]!.constNames.toList)
      | none => IO.println s!"no module {m}"
    let all := cone env moduleRoots
    let empty ← mkEmptyEnvironment
    let t2 ← IO.monoMsNow
    let _ ← empty.replay all
    let t3 ← IO.monoMsNow
    IO.println s!"{moduleArgs.length} modules: {moduleRoots.length} constants of their own, cone of {all.size} constants replayed in {t3 - t2} ms"
  for root in roots do
    let all := cone env [root]
    let empty ← mkEmptyEnvironment
    let t2 ← IO.monoMsNow
    let checked ← empty.replay all
    let t3 ← IO.monoMsNow
    -- the root alone, on an environment with everything else of its cone
    let rest := all.erase root
    let base ← empty.replay rest
    let t4 ← IO.monoMsNow
    let _ ← base.replay (({} : Std.HashMap Name ConstantInfo).insert root (all.get! root))
    let t5 ← IO.monoMsNow
    IO.println s!"{root}: cone of {all.size} constants replayed in {t3 - t2} ms; the root alone in {t5 - t4} ms ({checked.constants.fold (fun n _ _ => n + 1) 0} constants)"

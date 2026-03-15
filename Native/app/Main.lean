/-
  LeanLink CLI — pre-compiled binary that outputs WXF to stdout.

  Usage:
    leanlink list <searchPath> <imports> [filter]
    leanlink type <searchPath> <imports> <name> [depth]
    leanlink value <searchPath> <imports> <name> [depth]
    leanlink constant <searchPath> <imports> <name>

  Where:
    searchPath = colon-separated search paths
    imports = comma-separated module names
    filter = substring filter for list command
    depth = max expression depth (default 100)

  Output is WXF binary written to stdout.
-/
import Lean
import LeanLink

set_option linter.deprecated false
open Lean LeanLink

unsafe def main (args : List String) : IO UInt32 := do
  match args with
  | ["list", searchPath, imports] =>
    let env ← loadEnv (imports.splitOn ",").toArray searchPath
    let entries := env.constants.fold (init := #[]) fun acc name ci =>
      acc.push (WXF.string name.toString, WXF.constantToWXF ci)
    let wxf := WXF.serialize (WXF.wlAssociation entries)
    let stdout ← IO.getStdout
    stdout.write wxf
    return 0

  | ["list", searchPath, imports, filter] =>
    let env ← loadEnv (imports.splitOn ",").toArray searchPath
    let entries := env.constants.fold (init := #[]) fun acc name ci =>
      let nameStr := name.toString
      if filter == "" || (nameStr.splitOn filter).length > 1 then
        acc.push (WXF.string nameStr, WXF.constantToWXF ci)
      else acc
    let wxf := WXF.serialize (WXF.wlAssociation entries)
    let stdout ← IO.getStdout
    stdout.write wxf
    return 0

  | ["type", searchPath, imports, name] =>
    let env ← loadEnv (imports.splitOn ",").toArray searchPath
    match env.find? name.toName with
    | some ci =>
      let wxf := WXF.serialize (WXF.exprToWXF ci.type)
      let stdout ← IO.getStdout
      stdout.write wxf
    | none => IO.eprintln s!"ERROR: not found: {name}"
    return 0

  | ["type", searchPath, imports, name, depthStr] =>
    let env ← loadEnv (imports.splitOn ",").toArray searchPath
    let depth := depthStr.toNat?.getD 100
    match env.find? name.toName with
    | some ci =>
      let wxf := WXF.serialize (WXF.exprToWXF ci.type depth)
      let stdout ← IO.getStdout
      stdout.write wxf
    | none => IO.eprintln s!"ERROR: not found: {name}"
    return 0

  | ["value", searchPath, imports, name] =>
    let env ← loadEnv (imports.splitOn ",").toArray searchPath
    match env.find? name.toName with
    | some ci =>
      match ci.value? with
      | some v =>
        let wxf := WXF.serialize (WXF.exprToWXF v)
        let stdout ← IO.getStdout
        stdout.write wxf
      | none => IO.eprintln s!"No value for: {name}"
    | none => IO.eprintln s!"ERROR: not found: {name}"
    return 0

  | ["value", searchPath, imports, name, depthStr] =>
    let env ← loadEnv (imports.splitOn ",").toArray searchPath
    let depth := depthStr.toNat?.getD 100
    match env.find? name.toName with
    | some ci =>
      match ci.value? with
      | some v =>
        let wxf := WXF.serialize (WXF.exprToWXF v depth)
        let stdout ← IO.getStdout
        stdout.write wxf
      | none => IO.eprintln s!"No value for: {name}"
    | none => IO.eprintln s!"ERROR: not found: {name}"
    return 0

  | ["constant", searchPath, imports, name] =>
    let env ← loadEnv (imports.splitOn ",").toArray searchPath
    match env.find? name.toName with
    | some ci =>
      let wxf := WXF.serialize (WXF.constantToWXF ci)
      let stdout ← IO.getStdout
      stdout.write wxf
    | none => IO.eprintln s!"ERROR: not found: {name}"
    return 0

  | _ =>
    IO.eprintln "Usage: leanlink <command> <searchPath> <imports> [args...]"
    IO.eprintln "Commands: list, type, value, constant"
    return 1

/-
  Environment store — manages loaded Lean Environments keyed by opaque IDs.
  Provides @[export] entry points for loading/freeing envs and querying them.
-/
import Lean
import LeanLink.WXF

set_option linter.deprecated false
open Lean

namespace LeanLink

-- ============================================================================
-- Global environment store
-- ============================================================================

/-- Global mutable store of loaded environments, keyed by UInt64 handle. -/
private initialize envStore : IO.Ref (Std.HashMap UInt64 Environment) ← IO.mkRef {}

/-- Global counter for generating unique handles. -/
private initialize nextHandle : IO.Ref UInt64 ← IO.mkRef 1

-- ============================================================================
-- Internal helpers
-- ============================================================================

/-- Load an environment from module imports with a given search path. -/
def loadEnv (imports : Array String) (searchPath : String) : IO Environment := do
  -- Build search path from user-provided paths
  let userPaths : List System.FilePath := (searchPath.splitOn ":").filter (· ≠ "") |>.map (⟨·⟩)
  -- Try to add lean stdlib path from env vars
  let sysroot ← IO.getEnv "LEAN_SYSROOT"
  let leanPath ← IO.getEnv "LEAN_PATH"
  let libPaths : List System.FilePath := match sysroot with
    | some sr => [⟨sr ++ "/lib/lean/library"⟩, ⟨sr ++ "/lib/lean"⟩]
    | none => match leanPath with
      | some lp => (lp.splitOn ":").filter (· ≠ "") |>.map (⟨·⟩)
      | none => []
  Lean.searchPathRef.set (userPaths ++ libPaths)
  -- Import modules
  let modules : Array Import := imports.map fun m => { module := m.toName }
  let env ← Lean.importModules modules {} 0
  return env

-- ============================================================================
-- Exported C API
-- ============================================================================

/-- Initialize the Lean runtime. Must be called once before any other function.
    Returns 0 on success. -/
@[export leanlink_init]
def initLeanLink : IO UInt32 := do
  return 0

/-- Load an environment from comma-separated imports and colon-separated search paths.
    Returns a handle (UInt64) for the loaded environment. Returns 0 on failure. -/
@[export leanlink_load_env]
def loadEnvExport (importsStr : @& String) (searchPathStr : @& String) : IO UInt64 := do
  let imports := (importsStr.splitOn ",").toArray.filter (· ≠ "")
  try
    let env ← loadEnv imports searchPathStr
    let handle ← nextHandle.get
    nextHandle.set (handle + 1)
    envStore.modify fun m => m.insert handle env
    return handle
  catch e =>
    IO.eprintln s!"[LeanLink] loadEnv error: {e}"
    return 0

/-- Free a previously loaded environment. -/
@[export leanlink_free_env]
def freeEnvExport (handle : UInt64) : IO Unit := do
  envStore.modify fun m => m.erase handle

/-- List theorems/constants in the environment, filtered by prefix.
    Returns WXF-encoded Association: <|name -> LeanConstant[...], ...|> -/
@[export leanlink_list_theorems]
def listTheoremsExport (handle : UInt64) (filterStr : @& String) : IO ByteArray := do
  let store ← envStore.get
  let some env := store[handle]? | return WXF.serialize (WXF.string "ERROR: invalid handle")
  let filter := filterStr.trim
  let entries := env.constants.fold (init := #[]) fun acc name ci =>
    let nameStr := name.toString
    if filter == "" || (nameStr.splitOn filter).length > 1 then
      acc.push (WXF.string nameStr, WXF.constantToWXF ci)
    else acc
  return WXF.serialize (WXF.wlAssociation entries)

/-- List constant names only (no types/values), filtered by substring.
    Returns WXF-encoded List of strings. Much faster than listTheorems for large envs. -/
@[export leanlink_list_constant_names]
def listConstantNamesExport (handle : UInt64) (filterStr : @& String) : IO ByteArray := do
  let store ← envStore.get
  let some env := store[handle]? | return WXF.serialize (WXF.string "ERROR: invalid handle")
  let filter := filterStr.trim
  let names := env.constants.fold (init := #[]) fun acc name _ci =>
    let nameStr := name.toString
    if filter == "" || (nameStr.splitOn filter).length > 1 then
      acc.push (WXF.string nameStr)
    else acc
  return WXF.serialize (WXF.wlList names)

/-- Get the type of a constant as WXF-encoded Lean expression. -/
@[export leanlink_get_type]
def getTypeExport (handle : UInt64) (constName : @& String) (depth : UInt32) : IO ByteArray := do
  let store ← envStore.get
  let some env := store[handle]? | return WXF.serialize (WXF.string "ERROR: invalid handle")
  let name := constName.toName
  match env.find? name with
  | some ci => return WXF.serialize (WXF.exprToWXF ci.type depth.toNat)
  | none => return WXF.serialize (WXF.string s!"ERROR: constant not found: {constName}")

/-- Get the value/proof of a constant as WXF-encoded Lean expression. -/
@[export leanlink_get_value]
def getValueExport (handle : UInt64) (constName : @& String) (depth : UInt32) : IO ByteArray := do
  let store ← envStore.get
  let some env := store[handle]? | return WXF.serialize (WXF.string "ERROR: invalid handle")
  let name := constName.toName
  match env.find? name with
  | some ci =>
    match ci.value? with
    | some v => return WXF.serialize (WXF.exprToWXF v depth.toNat)
    | none => return WXF.serialize (WXF.string s!"No value for: {constName}")
  | none => return WXF.serialize (WXF.string s!"ERROR: constant not found: {constName}")

/-- Get full constant info as WXF. -/
@[export leanlink_get_constant]
def getConstantExport (handle : UInt64) (constName : @& String) : IO ByteArray := do
  let store ← envStore.get
  let some env := store[handle]? | return WXF.serialize (WXF.string "ERROR: invalid handle")
  let name := constName.toName
  match env.find? name with
  | some ci => return WXF.serialize (WXF.constantToWXF ci)
  | none => return WXF.serialize (WXF.string s!"ERROR: constant not found: {constName}")

/-- Get used constants from a constant's type and value expressions.
    Returns WXF-encoded Association: <|"type" -> {names...}, "value" -> {names...}|> -/
@[export leanlink_get_used_constants]
def getUsedConstantsExport (handle : UInt64) (constName : @& String) : IO ByteArray := do
  let store ← envStore.get
  let some env := store[handle]? | return WXF.serialize (WXF.string "ERROR: invalid handle")
  let name := constName.toName
  match env.find? name with
  | some ci =>
    let typeNames := ci.type.getUsedConstants
    let typeConsts := typeNames.map fun n => WXF.string n.toString
    let valueNames := match ci.value? with
      | some v => v.getUsedConstants
      | none => #[]
    let valueConsts := valueNames.map fun n => WXF.string n.toString
    -- Also include structural refs (e.g. inductive→constructor) via getUsedConstantsAsSet
    let allUsed := ci.getUsedConstantsAsSet
    let typeSet : Lean.NameHashSet := typeNames.foldl (fun s n => s.insert n) {}
    let valueSet : Lean.NameHashSet := valueNames.foldl (fun s n => s.insert n) {}
    let structConsts := allUsed.fold (init := #[]) fun acc n =>
      if typeSet.contains n || valueSet.contains n then acc
      else acc.push (WXF.string n.toString)
    let result := WXF.wlAssociation #[
      (WXF.string "type", WXF.wlList typeConsts),
      (WXF.string "value", WXF.wlList (valueConsts ++ structConsts))
    ]
    return WXF.serialize result
  | none => return WXF.serialize (WXF.string s!"ERROR: constant not found: {constName}")

end LeanLink

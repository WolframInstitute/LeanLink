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
  IO.println s!"[loadEnv] imports={imports}, searchPath={searchPath}"
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
  let sp := userPaths ++ libPaths
  IO.println s!"[loadEnv] search paths = {sp}"
  Lean.searchPathRef.set sp
  IO.println s!"[loadEnv] searchPathRef set OK"
  -- Import modules
  let modules : Array Import := imports.map fun m => { module := m.toName }
  IO.println s!"[loadEnv] calling importModules for {modules.size} modules..."
  let env ← Lean.importModules modules {} 0
  IO.println s!"[loadEnv] importModules OK"
  return env

-- ============================================================================
-- Exported C API
-- ============================================================================

/-- Initialize the Lean runtime. Must be called once before any other function.
    Returns 0 on success. -/
@[export leanlink_init]
def initLeanLink : IO UInt32 := do
  IO.println "[leanlink_init] OK"
  return 0

/-- Load an environment from comma-separated imports and colon-separated search paths.
    Returns a handle (UInt64) for the loaded environment. Returns 0 on failure. -/
@[export leanlink_load_env]
def loadEnvExport (importsStr : @& String) (searchPathStr : @& String) : IO UInt64 := do
  IO.println s!"[loadEnvExport] called with imports='{importsStr}' search='{searchPathStr}'"
  let imports := (importsStr.splitOn ",").toArray.filter (· ≠ "")
  try
    let env ← loadEnv imports searchPathStr
    let handle ← nextHandle.get
    nextHandle.set (handle + 1)
    envStore.modify fun m => m.insert handle env
    IO.println s!"[loadEnvExport] success, handle={handle}"
    return handle
  catch e =>
    IO.println s!"[loadEnvExport] ERROR: {toString e}"
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

end LeanLink

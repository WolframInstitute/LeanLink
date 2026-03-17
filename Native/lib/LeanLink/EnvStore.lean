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
  -- Also check environment variables for additional paths
  let leanPath ← IO.getEnv "LEAN_PATH"
  let libPaths : List System.FilePath := match leanPath with
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

/-- List constant names with their kinds, filtered by substring.
    Returns WXF-encoded Association: <|name -> kind, ...|>. No type/term serialization. -/
@[export leanlink_list_constant_kinds]
def listConstantKindsExport (handle : UInt64) (filterStr : @& String) : IO ByteArray := do
  let store ← envStore.get
  let some env := store[handle]? | return WXF.serialize (WXF.string "ERROR: invalid handle")
  let filter := filterStr.trim
  let entries := env.constants.fold (init := #[]) fun acc name ci =>
    let nameStr := name.toString
    if filter == "" || (nameStr.splitOn filter).length > 1 then
      acc.push (WXF.string nameStr, WXF.string (WXF.constantKind ci))
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

-- ============================================================================
-- Definition unfolding
-- ============================================================================

/-- Try to unfold the head of an application chain.
    Given `f a1 a2 ... an` where `f` is a const with a definition,
    replace `f` with its definition body and beta-reduce. -/
private def unfoldHead (env : Environment) (e : Expr) : Expr :=
  let fn := e.getAppFn
  let args := e.getAppArgs
  match fn with
  | .const name _ =>
    match env.find? name with
    | some ci =>
      match ci.value? with
      | some v => (Lean.mkAppN v args).headBeta
      | none => e
    | none => e
  | _ => e

/-- Unfold constants in an expression by the given number of levels.
    Level 0 = no unfolding. Level 1 = unfold each definition once, etc. -/
partial def unfoldExpr (env : Environment) (e : Expr) (level : Nat) : Expr :=
  if level == 0 then e
  else
    let e' := unfoldHead env e
    if Expr.equal e' e then
      -- Head didn't unfold — recurse into subexpressions
      match e with
      | .forallE n t b bi =>
        .forallE n (unfoldExpr env t level) (unfoldExpr env b level) bi
      | .lam n t b bi =>
        .lam n (unfoldExpr env t level) (unfoldExpr env b level) bi
      | .app fn arg =>
        .app (unfoldExpr env fn level) (unfoldExpr env arg level)
      | .letE n t v b nd =>
        .letE n (unfoldExpr env t level) (unfoldExpr env v level) (unfoldExpr env b level) nd
      | .mdata md inner => .mdata md (unfoldExpr env inner level)
      | _ => e
    else
      -- Head was unfolded — recurse on the result with level-1
      unfoldExpr env e' (level - 1)

/-- Get type with definition unfolding. unfoldLevel controls how many rounds. -/
@[export leanlink_get_type_unfolded]
def getTypeUnfoldedExport (handle : UInt64) (constName : @& String)
    (unfoldLevel : UInt32) : IO ByteArray := do
  let store ← envStore.get
  let some env := store[handle]? | return WXF.serialize (WXF.string "ERROR: invalid handle")
  let name := constName.toName
  match env.find? name with
  | some ci =>
    let ty := unfoldExpr env ci.type unfoldLevel.toNat
    return WXF.serialize (WXF.exprToWXF ty)
  | none => return WXF.serialize (WXF.string s!"ERROR: constant not found: {constName}")

/-- Get value with definition unfolding. -/
@[export leanlink_get_value_unfolded]
def getValueUnfoldedExport (handle : UInt64) (constName : @& String)
    (unfoldLevel : UInt32) : IO ByteArray := do
  let store ← envStore.get
  let some env := store[handle]? | return WXF.serialize (WXF.string "ERROR: invalid handle")
  let name := constName.toName
  match env.find? name with
  | some ci =>
    match ci.value? with
    | some v =>
      let v' := unfoldExpr env v unfoldLevel.toNat
      return WXF.serialize (WXF.exprToWXF v')
    | none => return WXF.serialize (WXF.string s!"No value for: {constName}")
  | none => return WXF.serialize (WXF.string s!"ERROR: constant not found: {constName}")

-- ============================================================================
-- Lean-native pretty-printing
-- ============================================================================

/-- Pretty-print an expression using Lean's built-in pretty-printer.
    Uses the environment's notations, so infix ops, implicit elision, etc. work. -/
def ppExprInEnv (env : Environment) (e : Expr) : IO String := do
  try
    let ctx : Core.Context := {
      fileName := "<pp>"
      fileMap := { source := "", positions := #[0] }
    }
    let st : Core.State := { env }
    let res ←
      ((Meta.MetaM.run' (do
        let fmt ← PrettyPrinter.ppExpr e
        return s!"{fmt}") : CoreM String).run ctx st).toIO'
    match res with
    | .ok (s, _) => return s
    | .error _ => return s!"{e.dbgToString}"
  catch _ =>
    return s!"{e.dbgToString}"

/-- Get pretty-printed type string. Optionally unfolds N levels first. -/
@[export leanlink_pp_type]
def ppTypeExport (handle : UInt64) (constName : @& String)
    (unfoldLevel : UInt32) : IO ByteArray := do
  let store ← envStore.get
  let some env := store[handle]? | return WXF.serialize (WXF.string "ERROR: invalid handle")
  let name := constName.toName
  match env.find? name with
  | some ci =>
    let ty := if unfoldLevel.toNat > 0
      then unfoldExpr env ci.type unfoldLevel.toNat
      else ci.type
    let s ← ppExprInEnv env ty
    return WXF.serialize (WXF.string s)
  | none => return WXF.serialize (WXF.string s!"ERROR: constant not found: {constName}")

/-- Get pretty-printed value/proof string. Optionally unfolds N levels first. -/
@[export leanlink_pp_value]
def ppValueExport (handle : UInt64) (constName : @& String)
    (unfoldLevel : UInt32) : IO ByteArray := do
  let store ← envStore.get
  let some env := store[handle]? | return WXF.serialize (WXF.string "ERROR: invalid handle")
  let name := constName.toName
  match env.find? name with
  | some ci =>
    match ci.value? with
    | some v =>
      let v' := if unfoldLevel.toNat > 0
        then unfoldExpr env v unfoldLevel.toNat
        else v
      let s ← ppExprInEnv env v'
      return WXF.serialize (WXF.string s)
    | none => return WXF.serialize (WXF.string s!"No value for: {constName}")
  | none => return WXF.serialize (WXF.string s!"ERROR: constant not found: {constName}")

/-- Type-check a WXF-encoded expression against an environment.
    Returns WXF with both the inferred type (as expr tree) and pretty-printed string. -/
@[export leanlink_type_check]
def typeCheckExport (handle : UInt64) (exprWXF : @& ByteArray) : IO ByteArray := do
  let store ← envStore.get
  let some env := store[handle]? | return WXF.serialize (WXF.string "ERROR: invalid handle")
  -- Deserialize WXF to Lean.Expr
  match WXF.deserializeExpr exprWXF with
  | none => return WXF.serialize (WXF.string "ERROR: failed to deserialize expression")
  | some expr =>
    -- Type-check in MetaM
    let ctx : Core.Context := {
      fileName := "<typecheck>"
      fileMap := { source := "", positions := #[0] }
    }
    let st : Core.State := { env }
    try
      let res ←
        ((Meta.MetaM.run' (do
          let ty ← Meta.inferType expr
          let ppStr ← PrettyPrinter.ppExpr ty
          return (ty, s!"{ppStr}")) : CoreM (Expr × String)).run ctx st).toIO'
      match res with
      | .ok ((ty, ppStr), _) =>
        -- Return association with both expr tree and string
        let tyWXF := WXF.exprToWXF ty
        let ppWXF := WXF.string ppStr
        return WXF.serialize (WXF.wlAssociation #[
          (WXF.string "Type", tyWXF),
          (WXF.string "TypeForm", ppWXF)])
      | .error _ => return WXF.serialize (WXF.string "ERROR: type check failed")
    catch _ =>
      return WXF.serialize (WXF.string "ERROR: type check exception")

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
    let structConsts := allUsed.toArray.foldl (init := #[]) fun acc n =>
      if typeSet.contains n || valueSet.contains n then acc
      else acc.push (WXF.string n.toString)
    let result := WXF.wlAssociation #[
      (WXF.string "type", WXF.wlList typeConsts),
      (WXF.string "value", WXF.wlList (valueConsts ++ structConsts))
    ]
    return WXF.serialize result
  | none => return WXF.serialize (WXF.string s!"ERROR: constant not found: {constName}")

-- ============================================================================
-- Phase 3: Proof state store for interactive tactics
-- ============================================================================

/-- Saved proof state: the MetaM state + list of remaining goal MVarIds -/
structure ProofState where
  env : Environment
  metaState : Meta.State
  coreState : Core.State
  goals : List MVarId

/-- Global mutable store of proof states, keyed by UInt64 ID. -/
private initialize proofStore : IO.Ref (Std.HashMap UInt64 ProofState) ← IO.mkRef {}

/-- Counter for proof state IDs. -/
private initialize nextProofId : IO.Ref UInt64 ← IO.mkRef 1

/-- Serialize a single goal to WXF -/
def goalToWXF (env : Environment) (mstate : Meta.State) (goalId : MVarId) : IO ByteArray := do
  let ctx : Core.Context := {
    fileName := "<tactic>"
    fileMap := { source := "", positions := #[0] }
  }
  let st : Core.State := { env }
  let res ←
    ((goalId.withContext do
      let target ← goalId.getType
      let targetPP ← PrettyPrinter.ppExpr target
      let lctx ← getLCtx
      let mut ctxEntries : Array ByteArray := #[]
      for ldecl in lctx do
        unless ldecl.isImplementationDetail do
          let tyPP ← PrettyPrinter.ppExpr ldecl.type
          ctxEntries := ctxEntries.push (WXF.wlAssociation #[
            (WXF.string "name", WXF.string ldecl.userName.toString),
            (WXF.string "type", WXF.string s!"{tyPP}"),
            (WXF.string "typeExpr", WXF.exprToWXF ldecl.type)])
      return WXF.wlAssociation #[
        (WXF.string "target", WXF.string s!"{targetPP}"),
        (WXF.string "targetExpr", WXF.exprToWXF target),
        (WXF.string "context", WXF.wlList ctxEntries)]
    : MetaM ByteArray).run' (s := mstate) |>.run ctx st).toIO'
  match res with
  | .ok (ba, _) => return ba
  | .error _ => return WXF.string "ERROR: failed to serialize goal"

/-- Open a proof goal for a named constant's type. -/
@[export leanlink_open_goal]
def openGoalExport (handle : UInt64) (constName : @& String) : IO ByteArray := do
  let store ← envStore.get
  let some env := store[handle]? | return WXF.serialize (WXF.string "ERROR: invalid handle")
  let name := constName.toName
  let some ci := env.find? name
    | return WXF.serialize (WXF.string s!"ERROR: constant not found: {constName}")
  let ctx : Core.Context := {
    fileName := "<tactic>"
    fileMap := { source := "", positions := #[0] }
  }
  let st : Core.State := { env }
  let res ←
    ((do
      let goalMVar ← Meta.mkFreshExprMVar (some ci.type) .syntheticOpaque `mainGoal
      let goalId := goalMVar.mvarId!
      let mstate ← getThe Meta.State
      return (goalId, mstate)
    : MetaM (MVarId × Meta.State)).run' |>.run ctx st).toIO'
  match res with
  | .error _ => return WXF.serialize (WXF.string "ERROR: failed to create goal")
  | .ok ((goalId, mstate), coreState') =>
    let proofId ← nextProofId.get
    nextProofId.set (proofId + 1)
    let ps : ProofState := {
      env := env
      metaState := mstate
      coreState := coreState'
      goals := [goalId]
    }
    proofStore.modify (·.insert proofId ps)
    let goalWXF ← goalToWXF env mstate goalId
    return WXF.serialize (WXF.wlAssociation #[
      (WXF.string "stateId", WXF.integer proofId.toNat),
      (WXF.string "goals", WXF.wlList #[goalWXF]),
      (WXF.string "goalCount", WXF.integer 1)])

/-- Apply a tactic string to a proof state. -/
@[export leanlink_apply_tactic]
def applyTacticExport (stateId : UInt64) (tacticStr : @& String) : IO ByteArray := do
  let store ← proofStore.get
  let some ps := store[stateId]?
    | return WXF.serialize (WXF.string s!"ERROR: invalid state ID: {stateId}")
  if ps.goals.isEmpty then
    return WXF.serialize (WXF.string "ERROR: no goals to solve")
  let ctx : Core.Context := {
    fileName := "<tactic>"
    fileMap := { source := "", positions := #[0] }
  }
  -- Direct MetaM-based tactic dispatch (bypasses parser extensions which aren't
  -- available in olean-loaded environments)
  let tacticParts := tacticStr.trim.splitOn " " |>.filter (· ≠ "")
  let tacticName := tacticParts.head!
  -- Strip parentheses from args (tacticSource may wrap apps in parens)
  let stripParens (s : String) : String :=
    s.replace "(" "" |>.replace ")" ""
  let tacticArgs := tacticParts.tail!.map stripParens |>.filter (· ≠ "")
  -- Run the tactic via MetaM
  let goalId := ps.goals.head!
  let res ←
    ((goalId.withContext do
      let newGoals : List MVarId ← match tacticName with
        | "intro" =>
          if tacticArgs.isEmpty then
            let (_, g) ← goalId.intro1
            pure [g]
          else
            let mut g := goalId
            for name in tacticArgs do
              let (_, g') ← g.intro name.toName
              g := g'
            pure [g]
        | "intros" =>
          let (_, g) ← goalId.intros
          pure [g]
        | "exact" =>
          -- Resolve each token (hypothesis or constant), fold into application
          let resolveToken (tok : String) : MetaM Expr := do
            let name := tok.toName
            let lctx ← getLCtx
            match lctx.findFromUserName? name with
            | some ldecl => pure ldecl.toExpr
            | none =>
              match ps.env.find? name with
              | some ci => pure (Lean.mkConst name (ci.levelParams.map Level.param))
              | none => throwError s!"unknown term: {tok}"
          if tacticArgs.isEmpty then throwError "exact requires an argument"
          let head ← resolveToken tacticArgs.head!
          let mut term := head
          for arg in tacticArgs.tail! do
            let argExpr ← resolveToken arg
            term := Lean.mkApp term argExpr
          goalId.assign term
          pure []
        | "apply" =>
          let termStr := " ".intercalate tacticArgs
          let name := termStr.toName
          let lctx ← getLCtx
          let e ← match lctx.findFromUserName? name with
            | some ldecl => pure ldecl.toExpr
            | none =>
              match ps.env.find? name with
              | some ci => pure (Lean.mkConst name (ci.levelParams.map Level.param))
              | none => throwError s!"unknown identifier: {termStr}"
          goalId.apply e
        | "assumption" =>
          goalId.assumption
          pure []
        | "rfl" =>
          goalId.refl
          pure []
        | "constructor" =>
          -- Manual constructor: find target inductive, apply first ctor
          let target ← goalId.getType
          let target ← Meta.whnf target
          let fn := Expr.getAppFn target
          let some indName := fn.constName?
            | throwError "constructor: target is not an inductive application"
          let some (.inductInfo val) := ps.env.find? indName
            | throwError s!"constructor: {indName} is not an inductive type"
          if val.ctors.isEmpty then throwError s!"constructor: {indName} has no constructors"
          let ctorName := val.ctors.head!
          let ctorExpr := Lean.mkConst ctorName (val.levelParams.map Level.param)
          goalId.apply ctorExpr
        | "trivial" =>
          try goalId.refl; pure []
          catch _ => do goalId.assumption; pure []
        | _ => throwError s!"unsupported tactic: {tacticName}"
      let mstate ← getThe Meta.State
      pure (newGoals, mstate)
    : MetaM (List MVarId × Meta.State)).run' (s := ps.metaState) |>.run ctx ps.coreState).toIO'
  match res with
  | .error e =>
    let errMsg ← e.toMessageData.toString
    return WXF.serialize (WXF.string s!"ERROR: tactic failed: {errMsg}")
  | .ok ((newGoals, newMetaState), newCoreState) =>
    let allGoals := newGoals ++ ps.goals.tail!
    let newProofId ← nextProofId.get
    nextProofId.set (newProofId + 1)
    let newPS : ProofState := {
      env := ps.env
      metaState := newMetaState
      coreState := newCoreState
      goals := allGoals
    }
    proofStore.modify (·.insert newProofId newPS)
    let mut goalWXFs : Array ByteArray := #[]
    for g in allGoals do
      goalWXFs := goalWXFs.push (← goalToWXF ps.env newMetaState g)
    return WXF.serialize (WXF.wlAssociation #[
      (WXF.string "stateId", WXF.integer newProofId.toNat),
      (WXF.string "goals", WXF.wlList goalWXFs),
      (WXF.string "goalCount", WXF.integer allGoals.length)])

end LeanLink

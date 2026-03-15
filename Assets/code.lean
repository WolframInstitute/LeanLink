/-
  code.lean — Unified Lean 4 graph extractor for proof analysis.

  Modes (first positional arg):
    expr   — Walk Expr trees, emit DOT with app/lam/forall/const/bvar nodes
    call   — Walk call dependencies via kernel env, emit DOT call graphs
    list   — Print available theorems/defs that can be graphed

  Usage:
    lake env lean --run call_graphs/code.lean expr modus_ponens
    lake env lean --run call_graphs/code.lean call MyModule.my_theorem
    lake env lean --run call_graphs/code.lean list
    lake env lean --run call_graphs/code.lean list +filter=succ
-/

import Lean
import Lean.Elab.Frontend
open Lean

-- ============================================================================
-- Shared utilities
-- ============================================================================

private def hasSubstr (s sub : String) : Bool :=
  (s.splitOn sub).length > 1

def isProjectName (_n : Name) : Bool := true

def isInternalName (n : Name) : Bool :=
  let s := n.toString
  hasSubstr s "._" || hasSubstr s ".match_" || hasSubstr s ".proof_" ||
  hasSubstr s "._uniq" || hasSubstr s ".brecOn" || hasSubstr s ".below" ||
  hasSubstr s ".casesOn" || hasSubstr s ".noConfusion"

def shortConstName (n : Name) : String :=
  let s := n.toString
  let s := match (s.splitOn "._@.") with | [base, _] => base | _ => s
  match (s.splitOn "._hyg.") with | [base, _] => base | _ => s

/-- Strip hygienic suffixes from binder names -/
def cleanBinderName (n : Name) : String :=
  if n.isAnonymous then "_"
  else
    let s := n.toString
    let s := match (s.splitOn "._@.") with | [base, _] => base | _ => s
    match (s.splitOn "._hyg.") with | [base, _] => base | _ => s

def getKind (ci : ConstantInfo) : String :=
  match ci with
  | .thmInfo _  => "theorem"
  | .defnInfo _ => "def"
  | .axiomInfo _ => "axiom"
  | .inductInfo _ => "structure"
  | .ctorInfo _ => "constructor"
  | .recInfo _ => "recursor"
  | .opaqueInfo _ => "opaque"
  | .quotInfo _ => "quot"

-- ============================================================================
-- Expr graph
-- ============================================================================

structure ExprNode where
  id : Nat
  label : String
  kind : String
  color : String

structure ExprEdge where
  src : Nat
  tgt : Nat
  label : String

structure ExprGraphData where
  nodes : Array ExprNode
  edges : Array ExprEdge
  expanded : Std.HashSet Name

def exprKindColor : String → String
  | "app"     => "#e1bee7"
  | "lam"     => "#fff9c4"
  | "forallE" => "#ffe0b2"
  | "letE"    => "#b2dfdb"
  | "const"   => "#bbdefb"
  | "bvar"    => "#f5f5f5"
  | "fvar"    => "#f5f5f5"
  | "mvar"    => "#ffcdd2"
  | "sort"    => "#d7ccc8"
  | "lit"     => "#c8e6c9"
  | "proj"    => "#b3e5fc"
  | "mdata"   => "#e0e0e0"
  | _         => "#e0e0e0"

structure WalkCfg where
  env : Environment
  constDepth : Nat
  maxNodes : Nat
  showLevels : Bool := false

private def mkLeaf (gd : ExprGraphData) (label kind color : String) : ExprGraphData × Nat :=
  let id := gd.nodes.size
  ({ gd with nodes := gd.nodes.push { id, label, kind, color } }, id)

def walkLevel (gd : ExprGraphData) (l : Level) : ExprGraphData × Nat :=
  match l with
  | .zero   => mkLeaf gd "zero" "level" (exprKindColor "level")
  | .succ inner =>
    let id := gd.nodes.size
    let gd := { gd with nodes := gd.nodes.push { id, label := "succ", kind := "level", color := exprKindColor "level" } }
    let (gd, innerId) := walkLevel gd inner
    ({ gd with edges := gd.edges.push { src := id, tgt := innerId, label := "" } }, id)
  | .max l1 l2 =>
    let id := gd.nodes.size
    let gd := { gd with nodes := gd.nodes.push { id, label := "max", kind := "level", color := exprKindColor "level" } }
    let (gd, id1) := walkLevel gd l1
    let (gd, id2) := walkLevel gd l2
    ({ gd with edges := gd.edges.push { src := id, tgt := id1, label := "l" }
                                |>.push { src := id, tgt := id2, label := "r" } }, id)
  | .imax l1 l2 =>
    let id := gd.nodes.size
    let gd := { gd with nodes := gd.nodes.push { id, label := "imax", kind := "level", color := exprKindColor "level" } }
    let (gd, id1) := walkLevel gd l1
    let (gd, id2) := walkLevel gd l2
    ({ gd with edges := gd.edges.push { src := id, tgt := id1, label := "l" }
                                |>.push { src := id, tgt := id2, label := "r" } }, id)
  | .param name => mkLeaf gd s!"{name}" "level" (exprKindColor "level")
  | .mvar _     => mkLeaf gd "mvar" "level" (exprKindColor "level")

def attachLevels (parentId : Nat) (gd : ExprGraphData) (levels : List Level) : ExprGraphData :=
  (levels.zip (List.range levels.length)).foldl (fun gd (lvl, i) =>
    let (gd, lvlId) := walkLevel gd lvl
    { gd with edges := gd.edges.push { src := parentId, tgt := lvlId, label := s!"u{i}" } }
  ) gd

private partial def mkExprLeaf (gd : ExprGraphData) (e : Expr) : ExprGraphData × Nat :=
  match e with
  | .const name _ => mkLeaf gd s!"{shortConstName name}" "const" (exprKindColor "const")
  | .bvar idx     => mkLeaf gd s!"bvar {idx}" "bvar" (exprKindColor "bvar")
  | .fvar _       => mkLeaf gd "fvar" "fvar" (exprKindColor "fvar")
  | .mvar _       => mkLeaf gd "mvar" "mvar" (exprKindColor "mvar")
  | .sort _       => mkLeaf gd "Sort" "sort" (exprKindColor "sort")
  | .lit (.natVal n) => mkLeaf gd s!"lit {n}" "lit" (exprKindColor "lit")
  | .lit (.strVal s) => mkLeaf gd s!"lit \\\"{s}\\\"" "lit" (exprKindColor "lit")
  | .app fn _     => mkExprLeaf gd fn
  | .lam _ _ body _     => mkExprLeaf gd body
  | .forallE _ _ body _ => mkExprLeaf gd body
  | .letE _ _ _ body _  => mkExprLeaf gd body
  | .mdata _ inner      => mkExprLeaf gd inner
  | .proj _ _ struct    => mkExprLeaf gd struct

private def isLeafExpr : Expr → Bool
  | .const .. | .bvar .. | .fvar .. | .mvar .. | .sort .. | .lit .. => true
  | _ => false

partial def walkExpr (cfg : WalkCfg) (e : Expr) (gd : ExprGraphData)
    (depth : Nat) (cd : Nat) : ExprGraphData × Nat :=
  let go (child : Expr) (gd : ExprGraphData) : ExprGraphData × Nat :=
    if gd.nodes.size >= cfg.maxNodes then mkExprLeaf gd child
    else if isLeafExpr child then
      if depth == 0 then mkExprLeaf gd child
      else walkExpr cfg child gd (depth - 1) cd
    else walkExpr cfg child gd (if depth == 0 then 0 else depth - 1) cd
  match e with
  | .const name levels =>
    let sn := shortConstName name
    if isProjectName name && !isInternalName name && cd > 0 && !gd.expanded.contains name then
      match cfg.env.find? name with
      | some ci =>
        match ci.value? with
        | some val =>
          let id := gd.nodes.size
          let node : ExprNode := { id, label := s!"{sn}", kind := "const", color := "#90caf9" }
          let gd := { gd with nodes := gd.nodes.push node, expanded := gd.expanded.insert name }
          let (gd, bodyId) := if depth == 0 then mkExprLeaf gd val
                              else walkExpr cfg val gd (depth - 1) (cd - 1)
          let gd := { gd with edges := gd.edges.push { src := id, tgt := bodyId, label := "def" } }
          let gd := if cfg.showLevels then attachLevels id gd levels else gd
          (gd, id)
        | none => mkLeaf gd s!"{sn}" "const" (exprKindColor "const")
      | none => mkLeaf gd s!"{sn}" "const" (exprKindColor "const")
    else
      let col := if gd.expanded.contains name then "#e3f2fd" else exprKindColor "const"
      if cfg.showLevels && !levels.isEmpty then
        let id := gd.nodes.size
        let gd := { gd with nodes := gd.nodes.push { id, label := s!"{sn}", kind := "const", color := col } }
        let gd := attachLevels id gd levels
        (gd, id)
      else mkLeaf gd s!"{sn}" "const" col
  | .bvar idx => mkLeaf gd s!"bvar {idx}" "bvar" (exprKindColor "bvar")
  | .fvar _   => mkLeaf gd "fvar" "fvar" (exprKindColor "fvar")
  | .mvar _   => mkLeaf gd "mvar" "mvar" (exprKindColor "mvar")
  | .sort level =>
    if cfg.showLevels then
      let id := gd.nodes.size
      let gd := { gd with nodes := gd.nodes.push { id, label := "Sort", kind := "sort", color := exprKindColor "sort" } }
      let (gd, lvlId) := walkLevel gd level
      ({ gd with edges := gd.edges.push { src := id, tgt := lvlId, label := "level" } }, id)
    else mkLeaf gd "Sort" "sort" (exprKindColor "sort")
  | .lit (.natVal n) => mkLeaf gd s!"lit {n}" "lit" (exprKindColor "lit")
  | .lit (.strVal s) => mkLeaf gd s!"lit \\\"{s}\\\"" "lit" (exprKindColor "lit")
  | .app fn arg =>
    let id := gd.nodes.size
    let gd := { gd with nodes := gd.nodes.push { id, label := "app", kind := "app", color := exprKindColor "app" } }
    let (gd, fnId) := go fn gd
    let (gd, argId) := go arg gd
    ({ gd with edges := gd.edges.push { src := id, tgt := fnId, label := "fn" }
                                |>.push { src := id, tgt := argId, label := "arg" } }, id)
  | .lam bname btype body _ =>
    let id := gd.nodes.size
    let bn := cleanBinderName bname
    let gd := { gd with nodes := gd.nodes.push { id, label := s!"λ {bn}", kind := "lam", color := exprKindColor "lam" } }
    let (gd, tyId) := go btype gd
    let (gd, bodyId) := go body gd
    ({ gd with edges := gd.edges.push { src := id, tgt := tyId, label := "type" }
                                |>.push { src := id, tgt := bodyId, label := "body" } }, id)
  | .forallE bname btype body _ =>
    let id := gd.nodes.size
    let bn := cleanBinderName bname
    let gd := { gd with nodes := gd.nodes.push { id, label := s!"∀ {bn}", kind := "forallE", color := exprKindColor "forallE" } }
    let (gd, tyId) := go btype gd
    let (gd, bodyId) := go body gd
    ({ gd with edges := gd.edges.push { src := id, tgt := tyId, label := "type" }
                                |>.push { src := id, tgt := bodyId, label := "body" } }, id)
  | .letE dn type value body _ =>
    let id := gd.nodes.size
    let dname := cleanBinderName dn
    let gd := { gd with nodes := gd.nodes.push { id, label := s!"let {dname}", kind := "letE", color := exprKindColor "letE" } }
    let (gd, tyId) := go type gd
    let (gd, valId) := go value gd
    let (gd, bodyId) := go body gd
    ({ gd with edges := gd.edges.push { src := id, tgt := tyId, label := "type" }
                                |>.push { src := id, tgt := valId, label := "val" }
                                |>.push { src := id, tgt := bodyId, label := "body" } }, id)
  | .mdata _ inner => walkExpr cfg inner gd depth cd
  | .proj typeName idx struct =>
    let id := gd.nodes.size
    let gd := { gd with nodes := gd.nodes.push { id, label := s!"proj {shortConstName typeName}.{idx}", kind := "proj", color := exprKindColor "proj" } }
    let (gd, sId) := go struct gd
    ({ gd with edges := gd.edges.push { src := id, tgt := sId, label := "struct" } }, id)

def exprGraphToDot (name : String) (gd : ExprGraphData) : String := Id.run do
  let mut lines : Array String := #[]
  lines := lines.push s!"digraph \"{name}\" \{"
  lines := lines.push "  rankdir=TB;"
  lines := lines.push "  node [shape=box, style=\"filled,rounded\", fontname=\"Menlo\", fontsize=8];"
  lines := lines.push "  edge [fontname=\"Menlo\", fontsize=6];"
  for n in gd.nodes do
    lines := lines.push s!"  \"n{n.id}\" [fillcolor=\"{n.color}\", label=\"{n.label}\", type=\"{n.kind}\"];"
  for e in gd.edges do
    lines := lines.push s!"  \"n{e.src}\" -> \"n{e.tgt}\" [label=\"{e.label}\"];"
  lines := lines.push "}"
  "\n".intercalate lines.toList

-- ============================================================================
-- Call graph
-- ============================================================================

def classifyEdge (ci : ConstantInfo) (callee : Name) : String :=
  let inType := ci.type.getUsedConstants.contains callee
  let inValue := match ci.value? with
    | some v => v.getUsedConstants.contains callee
    | none => false
  if inValue && inType then "term+type"
  else if inValue then "term"
  else if inType then "type"
  else "ref"

-- Source-level tactic parser

structure TacticInfo where
  tacticName : String
  index      : Nat
  refs       : List String
  deriving Inhabited

private def extractIdents (s : String) : List String := Id.run do
  let mut result : Array String := #[]
  let mut current : String := ""
  for c in s.toList do
    if c.isAlpha || c == '_' || (c.isDigit && !current.isEmpty) then
      current := current.push c
    else
      if current.length > 0 then
        result := result.push current
        current := ""
  if current.length > 0 then
    result := result.push current
  result.toList

private def tacticKeywords : List String :=
  ["simp", "rw", "rewrite", "exact", "apply", "have", "obtain",
   "refine", "use", "intro", "cases", "induction", "rcases",
   "constructor", "unfold", "delta", "norm_num", "ring", "omega",
   "native_decide", "decide", "ext", "funext", "calc", "conv", "show"]

private def builtinIdents : List String :=
  ["at", "with", "only", "by", "do", "fun", "let", "in", "if", "then",
   "else", "match", "true", "false", "rfl", "this", "h", "n", "m", "p",
   "k", "ih", "hn", "hc", "hlen", "fuel", "cfg", "heval", "hfb",
   "zero", "succ", "some", "none", "Or", "And", "Not", "Nat", "List",
   "Option", "String", "Bool", "Prop", "Type", "where", "return"]

def parseTactics (proofBody : String) : Array TacticInfo := Id.run do
  let lines := proofBody.splitOn "\n"
  let mut tactics : Array TacticInfo := #[]
  let mut idx : Nat := 0
  for line in lines do
    let trimmed := s!"{line.trim}"
    if trimmed.isEmpty then continue
    let mut foundTactic := ""
    for kw in tacticKeywords do
      if trimmed.startsWith kw then
        let rest := trimmed.drop kw.length
        if rest.isEmpty || rest.front == ' ' || rest.front == '[' || rest.front == '(' || rest.front == '\n' then
          foundTactic := kw
          break
    if foundTactic.isEmpty then
      let stripped := s!"{(trimmed.dropWhile (fun c => c == '·' || c == '|' || c == ' ')).trim}"
      for kw in tacticKeywords do
        if stripped.startsWith kw then
          let rest := stripped.drop kw.length
          if rest.isEmpty || rest.front == ' ' || rest.front == '[' || rest.front == '(' then
            foundTactic := kw
            break
    if foundTactic.isEmpty then continue
    let spacePos := (trimmed.posOf ' ').byteIdx
    let argPart := s!"{(trimmed.drop spacePos).trim}"
    let allIdents := extractIdents argPart
    let refs := allIdents.filter fun id =>
      !builtinIdents.contains id && !tacticKeywords.contains id && id.length > 1
    tactics := tactics.push { tacticName := foundTactic, index := idx, refs := refs }
    idx := idx + 1
  tactics

def getSourceBody (env : Environment) (name : Name) (srcDir : String)
    : IO (Option String) := do
  let some modIdx := env.getModuleIdxFor? name | return none
  let modName := env.allImportedModuleNames[modIdx.toNat]!
  let modPath := modName.toString.replace "." "/"
  let filePath := s!"{srcDir}/{modPath}.lean"
  let contents ← try IO.FS.readFile filePath catch _ => return none
  let shortN := shortConstName name
  let lines := contents.splitOn "\n"
  let mut inDecl := false
  let mut bodyLines : Array String := #[]
  let mut foundBy := false
  for line in lines do
    if inDecl then
      let trimmed := s!"{line.trim}"
      if !trimmed.isEmpty && !line.startsWith " " && !line.startsWith "\t" &&
         !trimmed.startsWith "|" && !trimmed.startsWith "·" &&
         !trimmed.startsWith "--" then
        for pfx in ["theorem ", "def ", "instance ", "lemma ", "abbrev ",
                    "structure ", "class ", "inductive ", "section ",
                    "namespace ", "end ", "open ", "import ", "#",
                    "noncomputable "] do
          if trimmed.startsWith pfx then
            inDecl := false
            break
      if inDecl then
        bodyLines := bodyLines.push line
        if hasSubstr line ":= by" || hasSubstr line "by" then
          foundBy := true
    else
      if hasSubstr line s!"theorem {shortN}" || hasSubstr line s!"def {shortN}" ||
         hasSubstr line s!"lemma {shortN}" || hasSubstr line s!"abbrev {shortN}" then
        inDecl := true
        bodyLines := bodyLines.push line
        if hasSubstr line ":= by" then
          foundBy := true
  if bodyLines.isEmpty then return none
  return some ("\n".intercalate bodyLines.toList)

def buildTacticMap (body : String) : Std.HashMap String String := Id.run do
  let tactics := parseTactics body
  let mut m : Std.HashMap String String := {}
  for t in tactics do
    let tag := s!"{t.tacticName}_{t.index}"
    for ref in t.refs do
      if !m.contains ref then
        m := m.insert ref tag
  m

-- BFS call graph builder

structure EdgeInfo where
  src : Name
  tgt : Name
  label : String
  tactic : String

structure CallGraphData where
  edges : Array EdgeInfo
  nodes : Std.HashMap Name String

def buildCallGraph (env : Environment) (roots : Array Name)
    (tacticMaps : Std.HashMap Name (Std.HashMap String String))
    (maxDepth : Nat := 0) : CallGraphData := Id.run do
  let mut queue : List (Name × Nat) := roots.toList.map (·, 0)
  let mut visited : Std.HashSet Name := {}
  for r in roots do visited := visited.insert r
  let mut edges : Array EdgeInfo := #[]
  let mut nodes : Std.HashMap Name String := {}
  for r in roots do
    match env.find? r with
    | some ci => nodes := nodes.insert r (getKind ci)
    | none => nodes := nodes.insert r "unknown"
  while !queue.isEmpty do
    match queue with
    | [] => break
    | (name, depth) :: rest =>
      queue := rest
      match env.find? name with
      | none => continue
      | some ci =>
        let used := ci.getUsedConstantsAsSet
        let tacMap := tacticMaps.getD name {}
        for callee in used.toList do
          if !isProjectName callee then continue
          if isInternalName callee then continue
          if callee == name then continue
          let label := classifyEdge ci callee
          let calleeShort := shortConstName callee
          let tactic := tacMap.getD calleeShort ""
          edges := edges.push { src := name, tgt := callee, label, tactic }
          if !visited.contains callee then
            visited := visited.insert callee
            match env.find? callee with
            | some cci => nodes := nodes.insert callee (getKind cci)
            | none => nodes := nodes.insert callee "unknown"
            if maxDepth == 0 || depth + 1 < maxDepth then
              queue := queue ++ [(callee, depth + 1)]
  let mut seen : Std.HashSet (Name × Name) := {}
  let mut uniqueEdges : Array EdgeInfo := #[]
  for e in edges do
    let key := (e.src, e.tgt)
    if !seen.contains key then
      seen := seen.insert key
      uniqueEdges := uniqueEdges.push e
  { edges := uniqueEdges, nodes := nodes }

-- Call graph DOT output

def callNodeColor (kind : String) : String :=
  match kind with
  | "theorem" => "#c8e6c9"
  | "def" => "#bbdefb"
  | "structure" => "#fff9c4"
  | "constructor" => "#e1bee7"
  | "axiom" => "#ffcdd2"
  | "recursor" => "#ffe0b2"
  | _ => "#e0e0e0"

def callEdgeColor (label : String) : String :=
  match label with
  | "term" => "#333333"
  | "type" => "#999999"
  | "term+type" => "#1565c0"
  | "ref" => "#666666"
  | _ => "#333333"

def callGraphToDot (graphName : String) (gd : CallGraphData) : String := Id.run do
  let mut lines : Array String := #[s!"digraph \"{graphName}\" \{"]
  lines := lines.push "  rankdir=TB;"
  lines := lines.push "  node [shape=box, style=\"filled,rounded\", fontname=\"Menlo\", fontsize=8];"
  lines := lines.push "  edge [fontname=\"Menlo\", fontsize=6];"
  for (name, kind) in gd.nodes.toList do
    let sn := shortConstName name
    let color := callNodeColor kind
    lines := lines.push s!"  \"{sn}\" [fillcolor=\"{color}\", label=\"{sn}\", type=\"{kind}\"];"
  for e in gd.edges do
    let ss := shortConstName e.src
    let st := shortConstName e.tgt
    let color := callEdgeColor e.label
    let style := if e.label == "type" then "dashed" else "solid"
    let pw := if e.label == "term" || e.label == "term+type" then "1.5"
              else if e.label == "type" then "0.8" else "1.2"
    let tacAttr := if e.tactic.isEmpty then "" else s!", tactic=\"{e.tactic}\""
    lines := lines.push s!"  \"{ss}\" -> \"{st}\" [label=\"{e.label}\", style={style}, color=\"{color}\", penwidth={pw}, fontcolor=\"{color}\"{tacAttr}];"
  lines := lines.push "}"
  "\n".intercalate lines.toList

-- ============================================================================
-- List mode
-- ============================================================================

def listTheorems (env : Environment) (filterStr : String) : Array (Name × String) :=
  env.constants.fold (init := #[]) fun acc name ci =>
    if isInternalName name then acc
    else
      let s := name.toString
      if hasSubstr s "._" || hasSubstr s ".proof_" then acc
      else
        let kind := getKind ci
        if kind == "theorem" || kind == "def" then
          if filterStr.isEmpty || hasSubstr s filterStr then
            acc.push (name, kind)
          else acc
        else acc

-- ============================================================================
-- Main — unified entry point
-- ============================================================================

unsafe def main (args : List String) : IO Unit := do
  let mode := match args with
    | m :: _ => m
    | [] => "help"
  let rest := match args with
    | _ :: r => r
    | [] => []

  if mode == "help" || mode == "--help" then
    IO.println "Usage: lake env lean --run code.lean <mode> [options] [roots...]"
    IO.println "Modes: expr, call, list"
    IO.println "Options: +import=Module +constdepth=N +depth=N +maxnodes=N +showlevels +outdir=DIR +filter=STR"
    return

  Lean.initSearchPath (← Lean.findSysroot)

  -- Parse shared CLI args
  let mut outDir : Option String := none
  let mut constDepth : Nat := 1
  let mut walkDepth : Nat := 10000
  let mut maxNodes : Nat := 200000
  let mut showLevels : Bool := true
  let mut callDepth : Nat := 0
  let mut filterStr : String := ""
  let mut fileArgs : List String := []
  let mut importArgs : List String := []
  let mut rootArgs : List String := []
  for a in rest do
    if a.startsWith "+outdir=" then outDir := some s!"{a.drop 8}"
    else if a.startsWith "+constdepth=" then constDepth := s!"{a.drop 12}" |>.toNat!
    else if a.startsWith "+depth=" then
      if mode == "call" then callDepth := s!"{a.drop 7}" |>.toNat!
      else walkDepth := s!"{a.drop 7}" |>.toNat!
    else if a.startsWith "+maxnodes=" then maxNodes := s!"{a.drop 10}" |>.toNat!
    else if a == "+showlevels" then showLevels := true
    else if a == "-showlevels" then showLevels := false
    else if a.startsWith "+import=" then importArgs := importArgs ++ [s!"{a.drop 8}"]
    else if a.startsWith "+file=" then fileArgs := fileArgs ++ [s!"{a.drop 6}"]
    else if a.startsWith "+filter=" then filterStr := s!"{a.drop 8}"
    else rootArgs := rootArgs ++ [a]

  -- Load environment: either from raw .lean files or from module imports
  let env ← if !fileArgs.isEmpty then do
    -- Process raw .lean files
    -- For standalone mode: just import the files as modules after reading
    let mut env ← Lean.importModules #[] {} 0
    for fp in fileArgs do
      -- Import the file as a module by adding its directory to search path
      let fname := System.FilePath.fileName fp |>.getD fp
      let modName := (fname.stripSuffix ".lean").toName
      let dir := System.FilePath.parent fp |>.getD "."
      Lean.searchPathRef.modify fun sp => dir.toString :: sp
      let modules : Array Import := #[{ module := modName }]
      env ← Lean.importModules modules {} 0
    IO.eprintln s!"Processed {fileArgs.length} file(s)"
    pure env
  else do
    let modules : Array Import :=
      (importArgs.map fun m => ({ module := m.toName } : Import)).toArray
    let env ← Lean.importModules modules {} 0
    IO.eprintln "Environment loaded"
    pure env

  match mode with
  | "list" =>
    let results := listTheorems env filterStr
    for (name, kind) in results do
      IO.println s!"{kind}\t{name}"
    IO.eprintln s!"{results.size} entries"

  | "expr" =>
    let roots := rootArgs.map String.toName
    let cfg : WalkCfg := { env, constDepth, maxNodes, showLevels }
    let processRoot (root : Name) : IO (Option String) := do
      match env.find? root with
      | none => IO.eprintln s!"NOT FOUND: {root}"; return none
      | some ci =>
        match ci.value? with
        | none => IO.eprintln s!"NO VALUE: {root} (opaque/axiom)"; return none
        | some val =>
          let emptyGd : ExprGraphData := { nodes := #[], edges := #[], expanded := {} }
          let (gd, _) := walkExpr cfg val emptyGd walkDepth constDepth
          let sn := shortConstName root
          let dot := exprGraphToDot sn gd
          IO.eprintln s!"{sn}: {gd.nodes.size} nodes, {gd.edges.size} edges"
          return some dot
    match outDir with
    | some dir =>
      IO.FS.createDirAll dir
      for root in roots do
        if let some dot ← processRoot root then
          IO.FS.writeFile s!"{dir}/{shortConstName root}.dot" dot
      IO.eprintln "Done!"
    | none =>
      for root in roots do
        if let some dot ← processRoot root then
          IO.println dot

  | "call" =>
    let roots ← if rootArgs.isEmpty then do
      let allConsts := env.constants.fold (init := #[]) fun acc name _ =>
        if isProjectName name then
          let s := name.toString
          if s.endsWith "_computesSucc" || s.endsWith "_succ" then
            acc.push name
          else acc
        else acc
      pure allConsts
    else pure (rootArgs.map String.toName).toArray

    IO.eprintln "Parsing source files for tactic annotations..."
    let mut tacticMaps : Std.HashMap Name (Std.HashMap String String) := {}
    let allProjectNames := env.constants.fold (init := #[]) fun acc name _ =>
      if isProjectName name && !isInternalName name then acc.push name else acc
    for name in allProjectNames do
      let body ← getSourceBody env name "."
      match body with
      | some b =>
        if hasSubstr b ":= by" then
          let tm := buildTacticMap b
          if !tm.isEmpty then tacticMaps := tacticMaps.insert name tm
      | none => pure ()
    IO.eprintln s!"  Parsed tactic maps for {tacticMaps.size} declarations"

    match outDir with
    | some dir =>
      IO.FS.createDirAll dir
      for root in roots do
        let gd := buildCallGraph env #[root] tacticMaps callDepth
        let graphName := shortConstName root
        let dot := callGraphToDot graphName gd
        IO.FS.writeFile s!"{dir}/{graphName}.dot" dot
        IO.eprintln s!"  {graphName}: {gd.edges.size} edges, {gd.nodes.toList.length} nodes"
      let gd := buildCallGraph env roots tacticMaps callDepth
      let dot := callGraphToDot "combined" gd
      IO.FS.writeFile s!"{dir}/combined.dot" dot
      IO.eprintln "Done!"
    | none =>
      for root in roots do
        let gd := buildCallGraph env #[root] tacticMaps callDepth
        let graphName := shortConstName root
        let dot := callGraphToDot graphName gd
        IO.println dot

  | other => IO.eprintln s!"Unknown mode: {other}. Use 'expr', 'call', or 'list'."

/-
  Evaluation in a loaded environment. An evaluation elaborates the expression in the environment a
  handle names, after the declarations of its source, encodes its value as JSON and runs the compiled
  term; the value comes back as WXF. Each evaluation starts from the same command state, so
  declarations and failures do not reach the next one.

  The encoding is `Lean.toJson` when the environment has Lean's JSON modules, as any that imports
  `Lean` or Mathlib does, so that types with their own `ToJson` instances work. An environment without
  them, such as one of `Init` alone, gets `LeanLinkEncoding.Encode` instead, declared in its command
  state: the same JSON for the types `Init` has, without importing anything again.

  An evaluation runs on a thread of its own, so the caller can wait with a time limit and stop
  waiting when Wolfram aborts. Stopping sets the evaluation's cancellation token: elaboration
  notices it at its next check, but compiled code that loops or sleeps runs until it returns.
-/
import Lean
import LeanLink.WXF
import LeanLink.EnvStore

open Lean

namespace LeanLink.Evaluate

/-- Float and Rat as JSON objects LeanLink decodes exactly: a Float by its bits, as its text keeps
    six digits, and a Rat by its numerator and denominator. -/
def toJsonSource : String :=
  "instance (priority := high) : Lean.ToJson Float where toJson x := Lean.Json.mkObj [(\"LeanLinkFloat\", Lean.toJson x.toBits.toNat)]\n" ++
  "instance (priority := high) : Lean.ToJson Rat where toJson x := Lean.Json.mkObj [(\"LeanLinkRational\", Lean.toJson (x.num, x.den))]"

/-- JSON text for the types of `Init`, as `Lean.toJson` with `toJsonSource` writes it. -/
def encodeSource : String := "
namespace LeanLinkEncoding

class Encode (α : Type) where
  encode : α → String

open Encode

def hexDigit (n : Nat) : Char := if n < 10 then Char.ofNat (48 + n) else Char.ofNat (87 + n)

def quote (s : String) : String := Id.run do
  let mut out := \"\\\"\"
  for c in s.toList do
    out := if c == '\"' then out ++ \"\\\\\\\"\"
      else if c == '\\\\' then out ++ \"\\\\\\\\\"
      else if c.toNat < 32 then out ++ \"\\\\u00\" ++ (hexDigit (c.toNat / 16)).toString ++ (hexDigit (c.toNat % 16)).toString
      else out.push c
  return out.push '\"'

instance : Encode Nat := ⟨toString⟩
instance : Encode Int := ⟨toString⟩
instance : Encode Bool := ⟨fun b => if b then \"true\" else \"false\"⟩
instance : Encode String := ⟨quote⟩
instance : Encode Char := ⟨fun c => quote c.toString⟩
instance : Encode Float := ⟨fun x => \"{\\\"LeanLinkFloat\\\":\" ++ toString x.toBits.toNat ++ \"}\"⟩
instance : Encode Rat := ⟨fun x => \"{\\\"LeanLinkRational\\\":[\" ++ toString x.num ++ \",\" ++ toString x.den ++ \"]}\"⟩
instance {α : Type} [Encode α] : Encode (List α) := ⟨fun l => \"[\" ++ \",\".intercalate (l.map encode) ++ \"]\"⟩
instance {α : Type} [Encode α] : Encode (Array α) := ⟨fun a => encode a.toList⟩
instance {α : Type} [Encode α] : Encode (Option α) := ⟨fun o => match o with | none => \"null\" | some a => encode a⟩
instance {α β : Type} [Encode α] [Encode β] : Encode (α × β) := ⟨fun p => \"[\" ++ encode p.1 ++ \",\" ++ encode p.2 ++ \"]\"⟩

end LeanLinkEncoding"

/-- The command state evaluations in an environment start from, and whether it encodes with `Lean.toJson`. -/
structure Base where
  state : Elab.Command.State
  toJson : Bool

/-- The base of each environment's evaluations, by handle: made by the first one. -/
private initialize baseStore : IO.Ref (Std.HashMap UInt64 Base) ← IO.mkRef {}

structure Job where
  task : Task (Except IO.Error ByteArray)
  cancel : IO.CancelToken

private initialize jobStore : IO.Ref (Std.HashMap UInt64 Job) ← IO.mkRef {}

private initialize nextJob : IO.Ref UInt64 ← IO.mkRef 1

/-- The text of a log's errors, one per line. -/
def errorText (log : MessageLog) : IO String := do
  let errors := log.toList.filter (·.severity == .error)
  return "\n".intercalate (← errors.mapM (·.data.toString))

/-- Runs `x` from `state` with the cancellation token `tk`, and gives its value and the state after it.
    An exception, an interruption among them, becomes an `IO` error with its text. -/
def runCommand {α : Type} (x : Elab.Command.CommandElabM α) (state : Elab.Command.State) (fileMap : FileMap) (cmdPos : String.Pos.Raw)
    (tk : IO.CancelToken) : IO (α × Elab.Command.State) := do
  let ctx : Elab.Command.Context := { fileName := "<LeanEvaluate>", fileMap, cmdPos, snap? := none, cancelTk? := some tk }
  match ← ((x.run ctx).run state).toIO' with
  | .ok result => return result
  | .error e => throw (IO.userError (← e.toMessageData.toString))

/-- Elaborates the commands of `source` one after another from `state`, as Lean's frontend does, but
    with the cancellation token, which the frontend leaves out. -/
def runCommands (state : Elab.Command.State) (source : String) (tk : IO.CancelToken) : IO Elab.Command.State := do
  let input := Parser.mkInputContext source "<LeanEvaluate>"
  let mut state := state
  let mut parser : Parser.ModuleParserState := {}
  repeat
    let scope := state.scopes.head!
    let pmctx : Parser.ParserModuleContext := { env := state.env, options := scope.opts, currNamespace := scope.currNamespace, openDecls := scope.openDecls }
    let (cmd, parser', messages) := Parser.parseCommand input pmctx parser state.messages
    let ((), state') ← runCommand (Elab.Command.elabCommandTopLevel cmd) { state with messages } input.fileMap parser.pos tk
    state := state'
    parser := parser'
    if Parser.isTerminalCommand cmd then break
  return state

/-- The base of the evaluations in an environment, made the first time. -/
def evaluationBase (handle : UInt64) (env : Environment) (tk : IO.CancelToken) : IO Base := do
  if let some base := (← baseStore.get)[handle]? then return base
  let toJson := env.contains ``Lean.Json.compress
  let state ← runCommands (Elab.Command.mkState env {} {}) (if toJson then toJsonSource else encodeSource) tk
  if state.messages.hasErrors then throw (IO.userError (← errorText state.messages))
  let base := { state := { state with messages := {} }, toJson }
  baseStore.modify (·.insert handle base)
  return base

unsafe def evaluateTermUnsafe (α : Type) [Nonempty α] (type : Name) (state : Elab.Command.State) (term : String) (tk : IO.CancelToken) : IO α := do
  let stx ← IO.ofExcept (Parser.runParserCategory state.env `term term "<LeanEvaluate>")
  let evaluate : Elab.Command.CommandElabM α :=
    Elab.Command.liftTermElabM (Elab.Term.withoutErrToSorry (Elab.Term.evalTerm α (mkConst type) stx))
  let (value, state') ← runCommand evaluate state (FileMap.ofString term) 0 tk
  if state'.messages.hasErrors then throw (IO.userError (← errorText state'.messages))
  return value

/-- The value of the term `term`, of the type named `type`, which must be `α`, elaborated and compiled in `state`. -/
@[implemented_by evaluateTermUnsafe]
opaque evaluateTerm (α : Type) [Nonempty α] (type : Name) (state : Elab.Command.State) (term : String) (tk : IO.CancelToken) : IO α

/-- A WXF machine real. -/
def real (x : Float) : ByteArray :=
  ⟨#[114] ++ WXF.leBytes x.toBits.toNat 8⟩

/-- A JSON value as the Wolfram Language expression `ImportString[..., "RawJSON"]` gives. -/
partial def jsonToWXF : Json → ByteArray
  | .null => WXF.symbol "Null"
  | .bool b => WXF.symbol (if b then "True" else "False")
  | .num n => if n.exponent == 0 then WXF.integer n.mantissa else real n.toFloat
  | .str s => WXF.string s
  | .arr elems => WXF.wlList (elems.map jsonToWXF)
  | .obj kvs => WXF.wlAssociation (kvs.toList.toArray.map fun (k, v) => (WXF.string k, jsonToWXF v))

def success (value : ByteArray) : ByteArray :=
  WXF.serialize (WXF.wlAssociation #[(WXF.string "ok", WXF.symbol "True"), (WXF.string "value", value)])

def failure (message : String) : ByteArray :=
  WXF.serialize (WXF.wlAssociation #[(WXF.string "ok", WXF.symbol "False"), (WXF.string "error", WXF.string message)])

/-- An evaluation: the value of `expression` after the declarations of `source`, with the namespaces of
    `opens` open. With neither, it only makes the environment's base. -/
def run (handle : UInt64) (env : Environment) (source expression : String) (opens : Array String) (tk : IO.CancelToken) : IO ByteArray := do
  try
    let base ← evaluationBase handle env tk
    if source.isEmpty && expression.isEmpty then return success (WXF.symbol "Null")
    let state ← if source.trimAscii.isEmpty then pure base.state else runCommands base.state source tk
    if state.messages.hasErrors then return failure (← errorText state.messages)
    let inOpens (term : String) := if opens.isEmpty then term else "open " ++ " ".intercalate opens.toList ++ " in " ++ term
    -- the line break ends a comment the expression may end with
    let json ← if base.toJson then
        evaluateTerm Json ``Json state (inOpens ("Lean.toJson (" ++ expression ++ "\n)")) tk
      else
        let text ← evaluateTerm String ``String state (inOpens ("LeanLinkEncoding.Encode.encode (" ++ expression ++ "\n)")) tk
        IO.ofExcept (Json.parse text)
    return success (jsonToWXF json)
  catch e =>
    return failure e.toString

/-- Starts an evaluation in the environment of `handle` on a thread of its own, and gives its job
    number, or 0 when the handle names no environment. `opens` holds namespaces separated by commas. -/
@[export leanlink_evaluate_start]
def startExport (handle : UInt64) (source expression opens : String) : IO UInt64 := do
  let some (env, _) ← loadedEnvironment? handle | return 0
  let opens := ((opens.splitOn ",").map (·.trimAscii.toString)).filter (· ≠ "") |>.toArray
  let tk ← IO.CancelToken.new
  let task ← IO.asTask (prio := .dedicated) (run handle env source expression opens tk)
  let job ← nextJob.modifyGet fun n => (n, n + 1)
  jobStore.modify (·.insert job { task, cancel := tk })
  return job

/-- 1 when the evaluation has finished, or when there is no such job. -/
@[export leanlink_evaluate_finished]
def finishedExport (job : UInt64) : IO UInt8 := do
  let some j := (← jobStore.get)[job]? | return 1
  return if ← IO.hasFinished j.task then 1 else 0

/-- Asks an evaluation to stop: elaboration stops at its next check, compiled code when it returns. -/
@[export leanlink_evaluate_cancel]
def cancelExport (job : UInt64) : IO Unit := do
  let some j := (← jobStore.get)[job]? | return
  j.cancel.set
  IO.cancel j.task

/-- The result of an evaluation, as `<|"ok" -> True, "value" -> value|>` or `<|"ok" -> False, "error" -> text|>`,
    waiting for it if it is still running. The job is forgotten. -/
@[export leanlink_evaluate_result]
def resultExport (job : UInt64) : IO ByteArray := do
  let some j := (← jobStore.get)[job]? | return failure s!"no evaluation {job}"
  let result ← IO.wait j.task
  jobStore.modify (·.erase job)
  match result with
  | .ok bytes => return bytes
  | .error e => return failure e.toString

/-- Forgets the base of the evaluations in the environment of `handle`. -/
@[export leanlink_evaluate_release]
def releaseExport (handle : UInt64) : IO Unit :=
  baseStore.modify (·.erase handle)

end LeanLink.Evaluate

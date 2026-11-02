import Lean

/- A worker owns one imported environment. Requests start from that environment,
   so local declarations and failed evaluations do not change later requests. -/
namespace LeanLinkEvaluator

open Lean

private def strings (request : Json) (key : String) : Except String (Array String) := do
  (← (request.getObjValD key).getArr?).mapM Json.getStr?

private def send (stdout : IO.FS.Stream) (response : Json) : IO Unit := do
  stdout.putStrLn ("LEANLINK_RESPONSE " ++ response.compress)
  stdout.flush

private def failure (id : Json) (message : String) : Json :=
  Json.mkObj [("id", id), ("ok", toJson false), ("error", toJson message)]

private def messages (state : Elab.Command.State) : IO String := do
  return String.intercalate "\n" (← state.messages.toList.mapM fun m => m.data.toString)

private def process (base : Elab.Command.State) (source : String) : IO Elab.Command.State := do
  let input := Parser.mkInputContext source "<LeanEvaluate>"
  return (← Elab.IO.processCommands input {} base).commandState

private def evaluate (base : Elab.Command.State) (request : Json) : IO Json := do
  let id := request.getObjValD "id"
  let expression ← IO.ofExcept ((request.getObjValD "expression").getStr?)
  let source ← IO.ofExcept ((request.getObjValD "source").getStr?)
  let opens ← IO.ofExcept (strings request "open")
  let marker := "LEANLINK_VALUE "
  let command := "#eval IO.println (\"" ++ marker ++
    "\" ++ (Lean.Json.arr #[Lean.toJson (" ++ expression ++ ")]).compress)"
  let command := if opens.isEmpty then command else
    "open " ++ String.intercalate " " opens.toList ++ " in\n" ++ command
  let state ← process base (source ++ "\n" ++ command)
  if state.messages.hasErrors then return failure id (← messages state)
  for message in state.messages.toList.reverse do
    let text ← message.data.toString
    if text.startsWith marker then
      let value ← IO.ofExcept (Json.parse (text.drop marker.length).toString)
      return Json.mkObj [("id", id), ("ok", toJson true), ("value", value)]
  return failure id "Lean did not return an evaluation result."

unsafe def main : IO Unit := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  initSearchPath (← findSysroot)
  enableInitializersExecution
  let setup ← IO.ofExcept (Json.parse (← stdin.getLine))
  let imports ← IO.ofExcept (strings setup "imports")
  let imports := (#["Lean.Data.Json", "Init.Data.Rat.Basic"] ++ imports).map fun name => { module := name.toName : Import }
  let env ← importModules imports {} (loadExts := true)
  let base ← process (Elab.Command.mkState env {} {})
    ("instance (priority := high) : Lean.ToJson Float where toJson x := Lean.Json.mkObj [(\"LeanLinkFloat\", Lean.toJson x.toBits.toNat)]\n" ++
      "instance (priority := high) : Lean.ToJson Rat where toJson x := Lean.Json.mkObj [(\"LeanLinkRational\", Lean.toJson (x.num, x.den))]")
  if base.messages.hasErrors then throw (IO.userError (← messages base))
  let base := { base with messages := {} }
  send stdout (Json.mkObj [("id", setup.getObjValD "id"), ("ok", toJson true)])
  while true do
    let line ← stdin.getLine
    if line.isEmpty then break
    let request ← IO.ofExcept (Json.parse line)
    try
      send stdout (← evaluate base request)
    catch error =>
      send stdout (failure (request.getObjValD "id") error.toString)

end LeanLinkEvaluator

unsafe def main : IO Unit := LeanLinkEvaluator.main

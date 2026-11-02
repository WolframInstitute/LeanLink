import Lean.Data.Json

private def response (id : String) (value : Lean.Json) : String :=
  "LEANLINK_RESPONSE " ++ (Lean.Json.mkObj [
    ("id", Lean.toJson id), ("ok", Lean.toJson true), ("value", Lean.Json.arr #[value])
  ]).compress ++ "\n"

private def send (stdout : IO.FS.Stream) (value : Lean.Json) : IO Unit := do
  stdout.putStr (response "transport" value)
  stdout.flush

def main : IO UInt32 := do
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  let stderr ← IO.getStderr
  send stdout (Lean.toJson 42)
  repeat
    let line ← stdin.getLine
    if line.isEmpty then return 0
    match line.trimAscii.toString with
    | "fragment" =>
      let bytes := (response "transport" (Lean.toJson "α世😀\n\"\\")).toUTF8
      for i in [:bytes.size] do
        stdout.write (bytes.extract i (i + 1))
        stdout.flush
        IO.sleep 1
    | "large" => send stdout (Lean.toJson (List.range 200000))
    | "stderr" =>
      stderr.putStr (String.ofList (List.replicate 1000000 'e'))
      stderr.flush
      send stdout (Lean.toJson 42)
    | "noise" =>
      stdout.putStrLn "diagnostic output"
      stdout.putStrLn "LEANLINK_RESPONSE invalid json"
      stdout.putStr (response "other-request" (Lean.toJson 0))
      send stdout (Lean.toJson 42)
    | "crash" =>
      stderr.putStr ("worker stopped: " ++ String.ofList (List.replicate 5000 'e'))
      stderr.flush
      stdout.putStr "unfinished reply"
      stdout.flush
      return 7
    | "idle" => IO.sleep 10000
    | "partial" =>
      stdout.putStr "LEANLINK_RESPONSE {"
      stdout.flush
      IO.sleep 10000
    | "flood" =>
      let chunk := String.ofList (List.replicate 8192 'x')
      for _ in [:100000] do
        stdout.putStrLn chunk
        stdout.flush
    | _ => send stdout (Lean.toJson 42)
  return 0

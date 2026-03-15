(* SubprocessAPI.wlt -- Tests for the subprocess-based Lean API *)
(* Uses Assets/Examples.lean for self-contained tests *)
(* Requires: $LeanLinkTestProjectDir and LeanLink` set by run_tests.wls *)

BeginTestSection["SubprocessAPI"]

$ExamplesFile = FileNameJoin[{DirectoryName[$LeanLinkTestProjectDir], "Assets", "Examples.lean"}];

(* --- LeanListTheorems --- *)

VerificationTest[
  result = LeanListTheorems[
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Files" -> {$ExamplesFile},
    "Filter" -> "modus_ponens"];
  Head[result] === Dataset,
  True,
  TestID -> "LeanListTheorems-ReturnsDataset"
]

VerificationTest[
  result = LeanListTheorems[
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Files" -> {$ExamplesFile},
    "Filter" -> "add_zero_term"];
  Length[result] >= 1,
  True,
  TestID -> "LeanListTheorems-FindsTheorem"
]

(* --- LeanExprGraph --- *)

VerificationTest[
  dot = LeanExprGraph["modus_ponens",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Files" -> {$ExamplesFile},
    "RawDOT" -> True, "Depth" -> 5];
  StringQ[dot] && StringContainsQ[dot, "digraph"],
  True,
  TestID -> "LeanExprGraph-RawDOT"
]

VerificationTest[
  g = LeanExprGraph["modus_ponens",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Files" -> {$ExamplesFile},
    "Depth" -> 5];
  Head[g] === Graph,
  True,
  TestID -> "LeanExprGraph-ReturnsGraph"
]

(* --- LeanCallGraph --- *)

VerificationTest[
  dot = LeanCallGraph["Vec.map",
    "ProjectDir" -> $LeanLinkTestProjectDir,
    "Files" -> {$ExamplesFile},
    "RawDOT" -> True];
  StringQ[dot] && StringContainsQ[dot, "digraph"],
  True,
  TestID -> "LeanCallGraph-RawDOT"
]

EndTestSection[]

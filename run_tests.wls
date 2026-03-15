#!/usr/bin/env wolframscript
(* run_tests.wls -- Run all .wlt test files and report results *)

$pacletDir = DirectoryName[$ScriptCommandLine[[1]]];
$testDir = FileNameJoin[{$pacletDir, "Tests"}];

(* Set globals for test files *)
PacletDirectoryLoad[$pacletDir];
Needs["LeanLink`"];

(* LeanLink Native build dir -- self-contained test environment *)
$LeanLinkTestProjectDir = ExpandFileName[FileNameJoin[{$pacletDir, "Native"}]];

Print["LeanLink Test Runner"];
Print["===================="];
Print["Paclet:  ", $pacletDir];
Print["Project: ", $LeanLinkTestProjectDir];
Print[""];

testFiles = FileNames["*.wlt", $testDir];

If[testFiles === {},
  Print["No .wlt files found in ", $testDir];
  Exit[1]];

allPassed = True;

Do[
  Print["Running: ", FileNameTake[file]];
  report = TestReport[file];

  passed = report["TestsSucceededCount"];
  failed = report["TestsFailedCount"];
  total = passed + failed;

  Print["  ", passed, "/", total, " passed"];

  If[failed > 0,
    allPassed = False;
    Print["  FAILURES:"];
    Do[
      If[tr["Outcome"] =!= "Success",
        Print["    ", tr["TestID"], ": ", tr["Outcome"]];
        If[tr["Outcome"] === "Failure",
          Print["      Expected: ", InputForm[tr["ExpectedOutput"]]];
          Print["      Actual:   ", InputForm[tr["ActualOutput"]]]]],
      {tr, Values[report["TestResults"]]}]];

  Print[],
  {file, testFiles}];

Print["===================="];
If[allPassed,
  Print["ALL TESTS PASSED"];
  Exit[0],
  Print["SOME TESTS FAILED"];
  Exit[1]]

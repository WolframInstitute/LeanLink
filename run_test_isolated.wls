#!/usr/bin/env wolframscript
(* run_test_isolated.wls -- run one test of a .wlt file in this kernel, after the file's setup, its top-level expressions
   that are not tests, so that a kernel under a small memory cap holds only that test:

       wolframscript -file run_test_isolated.wls NativeAPI.wlt "LeanImport-names-a-module-it-cannot-find"
       wolframscript -file run_test_isolated.wls NativeAPI.wlt --list

   With --list it prints the file's test IDs, one a line. Otherwise it prints "RESULT<TAB>id<TAB>outcome" and exits with
   0 when the test succeeds and 2 when it does not. A test that needs state an earlier test of its file leaves fails
   here; run_tests_capped.sh reports it with the others, to be read before it is taken for a bug. *)

$rootDir = DirectoryName[$ScriptCommandLine[[1]]];

$pacletDir = FileNameJoin[{$rootDir, "LeanLink"}];

$testDir = FileNameJoin[{$pacletDir, "Tests"}];

PacletDirectoryLoad[$pacletDir];

With[{typeTheory = FileNameJoin[{ParentDirectory[$rootDir], "TypeTheory", "TypeTheory"}]},
    If[PacletFind["WolframInstitute/TypeTheory"] === {} && DirectoryQ[typeTheory], PacletDirectoryLoad[typeTheory]]
];

Needs["Wolfram`LeanLink`"];

$LeanLinkTestProjectDir = ExpandFileName[FileNameJoin[{$rootDir, "Native"}]];

{$file, $which} = Replace[Rest[$ScriptCommandLine], {{file_String, which_String} :> {FileNameJoin[{$testDir, file}], which}, _ :> (Print["Usage: run_test_isolated.wls File.wlt TestID|--list"]; Exit[1])}];

(* the files are UTF-8, with non-ASCII Lean source in them *)
$held = Block[{$CharacterEncoding = "UTF-8"}, Import[$file, {"WL", "HeldExpressions"}]];

If[ ! ListQ[$held],
    Print["Cannot read ", $file];
    Exit[1]
];

testQ[HoldComplete[_VerificationTest]] := True

testQ[_] := False

testID[held_HoldComplete] := FirstCase[held, HoldPattern[TestID -> id_String] :> id, None, Infinity]

$tests = Select[$held, testQ];

If[ $which === "--list",
    Scan[Print, DeleteCases[testID /@ $tests, None]];
    Exit[0]
];

$test = SelectFirst[$tests, testID[#] === $which&, None];

If[ $test === None,
    Print["No test ", $which, " in ", $file];
    Exit[1]
];

Block[{$CharacterEncoding = "UTF-8"}, Scan[ReleaseHold, Select[$held, ! testQ[#]&]]];

$result = Block[{$CharacterEncoding = "UTF-8"}, ReleaseHold[$test]];

$outcome = Replace[Quiet[$result["Outcome"]], Except[_String] -> "Error"];

Print["RESULT\t", $which, "\t", $outcome];

If[ $outcome =!= "Success",
    Print["  actual: ", Short[Quiet[$result["ActualOutput"]], 6]];
    Print["  messages: ", Short[Quiet[$result["ActualMessages"]], 4]]
];

Exit[If[$outcome === "Success", 0, 2]]

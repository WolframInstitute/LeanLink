#!/usr/bin/env wolframscript
(* run_test_isolated.wls -- run one test of a .wlt file in this kernel, after the file's setup, its top-level expressions
   that are not tests, so that a kernel under a small memory cap holds only that test:

       wolframscript -file run_test_isolated.wls NativeAPI.wlt "LeanImport-names-a-module-it-cannot-find"
       wolframscript -file run_test_isolated.wls NativeAPI.wlt --list

   With --list it prints the file's test IDs, one a line. Otherwise it prints "RESULT<TAB>id<TAB>outcome" and exits with
   0 when the test succeeds and 2 when it does not. Tests leave state for later ones, as one that imports an environment
   into a variable the next ones read: before the test, the input of every earlier test that assigns a symbol the test
   reads, other than one it makes local, is evaluated too, and so on for what those read. TypeTheory comes from $TYPETHEORY_DIR when it
   is set, else as run_tests.wls finds it. *)

(* expanded, so that a relative path to the script works *)
$rootDir = DirectoryName[ExpandFileName[$ScriptCommandLine[[1]]]];

$pacletDir = FileNameJoin[{$rootDir, "LeanLink"}];

$testDir = FileNameJoin[{$pacletDir, "Tests"}];

PacletDirectoryLoad[$pacletDir];

With[{typeTheory = Replace[Environment["TYPETHEORY_DIR"], Except[_String] :> FileNameJoin[{ParentDirectory[$rootDir], "TypeTheory", "TypeTheory"}]]},
    If[(StringQ[Environment["TYPETHEORY_DIR"]] || PacletFind["WolframInstitute/TypeTheory"] === {}) && DirectoryQ[typeTheory], PacletDirectoryLoad[typeTheory]]
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

$position = FirstPosition[testID /@ $tests, $which, {None}][[1]];

If[ $position === None,
    Print["No test ", $which, " in ", $file];
    Exit[1]
];

$test = $tests[[$position]];

(* a test's input, held, and the symbols its top-level statements assign *)
testInput[HoldComplete[VerificationTest[input_, ___]]] := HoldComplete[input]

(* the symbols a test assigns anywhere in it, as one does inside an If, less those a Module, Block, With or Function of
   it makes local; the test stays held: Cases looks at it without evaluating it *)
assignedIn[held_HoldComplete] := Complement[
    Cases[held, HoldPattern[(Set | SetDelayed)[symbol_Symbol | symbol_Symbol[___], _]] :> HoldComplete[symbol], {0, Infinity}],
    localsIn[held]
]

localsIn[held_HoldComplete] := Union[
    Flatten[Cases[held, HoldPattern[(Module | Block | With)[{variables___}, ___]] :> Cases[HoldComplete[variables], v_Symbol | HoldPattern[(Set | SetDelayed)[v_Symbol, _]] :> HoldComplete[v], {1}], {0, Infinity}]],
    Flatten[Cases[held, HoldPattern[Function[{parameters___}, ___]] :> Cases[HoldComplete[parameters], v_Symbol :> HoldComplete[v], {1}], {0, Infinity}]],
    Cases[held, HoldPattern[Function[parameter_Symbol, ___]] :> HoldComplete[parameter], {0, Infinity}]
]

symbolsIn[held_] := DeleteDuplicates[Cases[held, s_Symbol /; Context[Unevaluated[s]] =!= "System`" :> HoldComplete[s], {0, Infinity}, Heads -> True]]

(* the earlier tests whose assignments the test reads, and those theirs read, in the file's order *)
$prerequisites = Module[{needed = symbolsIn[$test], chosen = {}},
    Do[
        With[{assigned = assignedIn[testInput[$tests[[k]]]]},
            If[ IntersectingQ[assigned, needed],
                PrependTo[chosen, k];
                needed = Union[needed, symbolsIn[$tests[[k]]]]
            ]
        ],
        {k, $position - 1, 1, -1}
    ];
    chosen
];

Block[{$CharacterEncoding = "UTF-8"}, Scan[ReleaseHold, Select[$held, ! testQ[#]&]]];

If[$prerequisites =!= {}, Print["  after the inputs of tests ", $prerequisites]];

Block[{$CharacterEncoding = "UTF-8"}, Scan[Function[k, Quiet[ReleaseHold[testInput[$tests[[k]]]]]], $prerequisites]];

$result = Block[{$CharacterEncoding = "UTF-8"}, ReleaseHold[$test]];

$outcome = Replace[Quiet[$result["Outcome"]], Except[_String] -> "Error"];

Print["RESULT\t", $which, "\t", $outcome];

If[ $outcome =!= "Success",
    Print["  actual: ", Short[Quiet[$result["ActualOutput"]], 6]];
    Print["  messages: ", Short[Quiet[$result["ActualMessages"]], 4]]
];

Exit[If[$outcome === "Success", 0, 2]]

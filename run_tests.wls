#!/usr/bin/env wolframscript
(* run_tests.wls -- Run all .wlt test files and report results; with file names after it, as
   wolframscript -file run_tests.wls TypeTheoryBridge.wlt, only those *)

(* expanded, so that a relative path to the script works *)
$rootDir = DirectoryName[ExpandFileName[$ScriptCommandLine[[1]]]];

$pacletDir = FileNameJoin[{$rootDir, "LeanLink"}];

$testDir = FileNameJoin[{$pacletDir, "Tests"}];

(* Set globals for test files *)

PacletDirectoryLoad[$pacletDir];

(* The TypeTheory bridge's tests need WolframInstitute/TypeTheory: installed, or a checkout next to this one *)

(* $TYPETHEORY_DIR names a TypeTheory paclet folder to use instead, as from a worktree, where no checkout is next to this one *)
With[{typeTheory = Replace[Environment["TYPETHEORY_DIR"], Except[_String] :> FileNameJoin[{ParentDirectory[$rootDir], "TypeTheory", "TypeTheory"}]]},
    If[(StringQ[Environment["TYPETHEORY_DIR"]] || PacletFind["WolframInstitute/TypeTheory"] === {}) && DirectoryQ[typeTheory], PacletDirectoryLoad[typeTheory]]
];

Needs["Wolfram`LeanLink`"];

(* LeanLink Native build dir -- self-contained test environment *)

$LeanLinkTestProjectDir = ExpandFileName[FileNameJoin[{$rootDir, "Native"}]];

Print["LeanLink Test Runner"];

Print["===================="];

Print["Kernel:  ", $Version];

Print["Paclet:  ", $pacletDir];

Print["Project: ", $LeanLinkTestProjectDir];

Print[""];

testFiles = Replace[Select[Rest[$ScriptCommandLine], StringEndsQ[".wlt"]], {{} :> FileNames["*.wlt", $testDir], names_ :> (FileNameJoin[{$testDir, #}]& /@ names)}];

If[ testFiles === {},
    Print["No .wlt files found in ", $testDir];
    Exit[1]
];

allPassed = True;

Do[
    Print["Running: ", FileNameTake[file]];
    (* The test files are UTF-8, with non-ASCII Lean source in them; a kernel reads a
       file in $CharacterEncoding, which on Windows is ISO8859-1 *)
    report = Block[{$CharacterEncoding = "UTF-8"}, TestReport[file]];
    passed = report["TestsSucceededCount"];
    failed = report["TestsFailedCount"];
    total = passed + failed;
    Print["  ", passed, "/", total, " passed"];
    If[ failed > 0,
        allPassed = False;
        Print["  FAILURES:"];
        Do[
            If[ tr["Outcome"] =!= "Success",
                Print["    ", tr["TestID"], ": ", tr["Outcome"]];
                If[ tr["Outcome"] === "Failure",
                    Print["      Expected: ", InputForm[tr["ExpectedOutput"]]];
                    Print["      Actual:   ", InputForm[tr["ActualOutput"]]]
                ]
            ]
            ,
            {tr, Replace[report["TestResults"], results_Association :> Values[results]]}
        ]
    ];
    Print[]
    ,
    {file, testFiles}
];

Print["===================="];

If[ allPassed,
    Print["ALL TESTS PASSED"];
    Exit[0]
    ,
    Print["SOME TESTS FAILED"];
    Exit[1]
]
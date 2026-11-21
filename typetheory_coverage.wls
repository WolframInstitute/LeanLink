#!/usr/bin/env wolframscript
(* Measure how much of a Lean library TypeTheory checks: every constant of the given modules, with
   every constant it depends on, is imported in dependency order into one TypeTheory environment, as
   LeanToTypeTheory imports them. A constant that fails is recorded with its failure; a constant that
   depends on one that did not check is blocked and not tried. It uses the bridge's internals, so it
   is a development tool and runs against this checkout of LeanLink.

       wolframscript -file typetheory_coverage.wls [module ...] [--modules file] [--project-dir dir] [--time-limit seconds]
           [--typetheory dir] [--out file] [--constants name,name,...] [--budget seconds] [--resume]

   The modules default to Init.Prelude. --constants checks the cones of the named constants alone,
   with the modules only as the imports that declare them, so a proof's few theorems are checked
   without every other constant of their modules.

   --budget and --resume split a run over several kernels, for machines that allow only short runs.
   With --budget, the run stops once its kernel has run that many seconds, finishing the constant in
   hand, writes the TypeTheory environment it built and every verdict so far next to --out (which it
   needs), and exits with status 3; a run that finishes exits with 0 and prints the summary. --resume
   reads them back, the environment as TypeTheory saved it, without checking it again, and goes on
   from the next constant. Run the same command with --resume until it exits with 0. Each constant
   is still checked once, in an environment of constants that checked.

   The project directory, a built Lake project such as Mathlib,
   defaults to ~/src/mathlib4; the time limit for each constant to 300 seconds. TypeTheory loads from
   --typetheory, by default the checkout next to this one when there is one, and otherwise as
   installed. --out saves the status of every constant to a file, <|name -> "OK" | {"Failed", tag,
   message} | {"Blocked", dependency}|>, which Get reads back; it is saved every 100 constants as well,
   and the constant being checked is in the file of the same name with ".current" added, so a run that
   crashes leaves what it found and where it stopped. Every constant's seconds go to the file of the same
   name with ".seconds.wl" added, <|name -> seconds|>, and the constants that took longest to check are
   listed at the end. *)

$RecursionLimit = 20000;

$rootDirectory = DirectoryName[$InputFileName];

arguments = Rest[Replace[$ScriptCommandLine, {} -> {$InputFileName}]];

optionNames = {"--project-dir", "--time-limit", "--typetheory", "--out", "--modules", "--constants", "--budget"};

(* --resume is a flag, with no value *)
$resume = MemberQ[arguments, "--resume"];

arguments = DeleteCases[arguments, "--resume"];

optionValues = Association[Cases[Partition[arguments, 2, 1], {name_String, value_String} /; MemberQ[optionNames, name] :> (name -> value)]];

optionPositions = Flatten[Function[position, {{position}, {position + 1}}] /@ Flatten[Position[arguments, Alternatives @@ optionNames, {1}]], 1];

(* --modules names a file of module names, one a line, as coverage/mathlib-bottom.txt *)
$modules = Replace[
    Join[Delete[arguments, optionPositions], If[KeyExistsQ[optionValues, "--modules"], Select[StringTrim /@ ReadList[optionValues["--modules"], String], # =!= "" && ! StringStartsQ[#, "#"]&], {}]],
    {} -> {"Init.Prelude"}
];

$projectDirectory = Lookup[optionValues, "--project-dir", FileNameJoin[{$HomeDirectory, "src", "mathlib4"}]];

$timeLimit = ToExpression[Lookup[optionValues, "--time-limit", "300"]];

$typeTheoryDirectory = Lookup[optionValues, "--typetheory", FileNameJoin[{ParentDirectory[$rootDirectory], "TypeTheory", "TypeTheory"}]];

$statusFile = Lookup[optionValues, "--out", None];

$constants = If[KeyExistsQ[optionValues, "--constants"], StringTrim /@ StringSplit[optionValues["--constants"], ","], None];

$budget = If[KeyExistsQ[optionValues, "--budget"], ToExpression[optionValues["--budget"]], None];

(* what a run stopped by its budget leaves for the next: the verdicts, and the name of the environment file *)
$resumeFile = If[StringQ[$statusFile], $statusFile <> ".resume.wl", None];

If[ ($budget =!= None || $resume) && ! StringQ[$statusFile],
    Print["--budget and --resume need --out."];
    Exit[1]
];

If[DirectoryQ[$typeTheoryDirectory], PacletDirectoryLoad[$typeTheoryDirectory]];

PacletDirectoryLoad[FileNameJoin[{$rootDirectory, "LeanLink"}]];

Needs["Wolfram`LeanLink`"];

(* with --constants the walk starts from names, not from the listing, so the listing, which otherwise holds every constant of
   the imports, Mathlib's included, is cut to the names containing the first of them *)
lean = LeanImport["ProjectDir" -> $projectDirectory, "Imports" -> $modules, Sequence @@ If[ListQ[$constants], {"Filter" -> First[$constants]}, {}]];

If[ FailureQ[lean],
    Print["The modules did not load: ", lean];
    Exit[1]
];

Print[
    "LeanLink ",
    PacletFind["Wolfram/LeanLink"][[1]]["Version"],
    ", TypeTheory ",
    PacletFind["WolframInstitute/TypeTheory"][[1]]["Version"],
    " from ",
    PacletFind["WolframInstitute/TypeTheory"][[1]]["Location"]
];

Wolfram`LeanLink`Private`loadTypeTheoryBridge[];

Begin["Wolfram`LeanLink`Private`"];

(* the dependency cone of the roots, in dependency order; a constant the walk cannot follow fails *)
coverageVisit[name_String] := With[{primary = Replace[Catch[primaryName[name], $bridgeTag], Except[_String] -> name]},
    If[ ! KeyExistsQ[$seen, primary],
        $seen[primary] = True;
        With[{dependencies = Catch[DeleteDuplicates[primaryName /@ DeleteCases[constantDependencies[primary], Alternatives @@ ownNames[primary]]], $bridgeTag]},
            If[ ListQ[dependencies],
                $dependencies[primary] = dependencies;
                Scan[coverageVisit, dependencies]
                ,
                $dependencies[primary] = {};
                $walkFailures[primary] = dependencies
            ]
        ];
        Sow[primary, $coneTag]
    ]
]

(* the constant being checked, in a file of its own, so a crash of the kernel names it *)
recordCurrent[name_String] := If[ StringQ[$statusFile],
    With[{stream = OpenWrite[$statusFile <> ".current"]},
        WriteString[stream, name];
        Close[stream]
    ]
]

failureStatus[failure_] := {"Failed", If[FailureQ[failure], First[failure], "Other"], StringTake[ToString[If[FailureQ[failure], failure["Message"], Short[failure]]], UpTo[400]]}

coverageStatus[name_String, environment_] := Which[
    KeyExistsQ[$walkFailures, name],
        {failureStatus[$walkFailures[name]], environment}
    ,
    AnyTrue[$dependencies[name], Function[dependency, Lookup[$status, dependency, "OK"] =!= "OK"]],
        {{"Blocked", SelectFirst[$dependencies[name], Function[dependency, Lookup[$status, dependency, "OK"] =!= "OK"]]}, environment}
    ,
    True,
        With[{
            result = TimeConstrained[
                Catch[
                    With[{extended = TypeTheoryEnvironment[environment, importedDeclarations[environment, name]]},
                        If[! FailureQ[extended] && constantKind[name] === "inductive", checkRecursor[extended, name]];
                        extended
                    ]
                    ,
                    $bridgeTag
                ]
                ,
                $timeLimit
                ,
                Failure["Timeout", <|"MessageTemplate" -> "It did not check within `1` seconds.", "MessageParameters" -> {$timeLimit}|>]
            ]
        },
            If[MatchQ[result, _TypeTheoryEnvironment], {"OK", result}, {failureStatus[result], environment}]
        ]
]

(* the import's own tables come from withImportState, the bridge's, which importConstants runs in: listed here, they fell
   behind the bridge's and nothing checked *)
coverage[handle_, rootGroups_List] := withImportState[handle, Block[{$seen = <||>, $dependencies = <||>, $walkFailures = <||>, $status = <||>, $seconds = <||>},
    Module[{environment = TypeTheoryEnvironment[quotientRules[]], start = AbsoluteTime[], stopped, saved = None, orders},
        If[$resume && FileExistsQ[$resumeFile], saved = Get[$resumeFile]];
        If[ AssociationQ[saved],
            $status = saved["Status"];
            $seconds = saved["Seconds"];
            {orders, $dependencies, $walkFailures} = Lookup[saved, {"Orders", "Dependencies", "WalkFailures"}];
            environment = TypeTheoryEnvironment[File[saved["Environment"]]];
            Print["resumed: ", Length[$status], " constants done, ", Count[$status, "OK"], " check, ", Round[SessionTime[]], " s into the kernel"]
            ,
            (* the walk, a constant at a time, is a few milliseconds a constant, minutes for a large cone, so a run stopped by
               its budget keeps it for the next instead of walking again *)
            orders = Function[group, Flatten[Last[Reap[Scan[coverageVisit, group], $coneTag]]]] /@ rootGroups;
            Print["walked ", Length[Flatten[orders]], " constants in ", Round[AbsoluteTime[] - start], " s"]
        ];
        stopped = Catch[
            Scan[
                Function[order,
                    Scan[
                        Function[name,
                            If[ ! KeyExistsQ[$status, name],
                                If[$budget =!= None && SessionTime[] > $budget, Throw[True, $budgetTag]];
                                recordCurrent[name];
                                With[{timed = AbsoluteTiming[coverageStatus[name, environment]]},
                                    $seconds[name] = First[timed];
                                    $status[name] = First[Last[timed]];
                                    (* an environment lives for the session, so the one replaced is removed, or each would stay *)
                                    If[Last[Last[timed]] =!= environment, Remove @@ {First[environment]}];
                                    environment = Last[Last[timed]]
                                ];
                                If[Mod[Length[$status], 100] == 0 && StringQ[$statusFile], Put[$status, $statusFile]];
                                If[Mod[Length[$status], 200] == 0, Print[Length[$status], " constants, ", Count[$status, "OK"], " check, ", Round[AbsoluteTime[] - start], " s, ", Round[MemoryInUse[] / 2.^30, 0.1], " GB"]]
                            ]
                        ]
                        ,
                        order
                    ];
                    Print["roots of a module done: ", Length[$status], " constants, ", Count[$status, "OK"], " check, ", Round[AbsoluteTime[] - start], " s"]
                ]
                ,
                orders
            ];
            False
            ,
            $budgetTag
        ];
        If[stopped, saveResume[environment, orders]];
        (* a constructor or recursor is checked with its inductive type *)
        {$status, AssociationMap[Function[name, Replace[Catch[primaryName[name], $bridgeTag], Except[_String] -> name]], Flatten[rootGroups]], $seconds, stopped}
    ]
]]

(* the environment goes to a file of its own first, and the verdicts that name it replace the last ones after, so a run
   killed while saving leaves the previous pair whole *)
saveResume[environment_, orders_List] := Block[
    {
        environmentFile = $statusFile <> ".env-" <> ToString[Length[$status]] <> ".wxf",
        previous = If[FileExistsQ[$resumeFile], Quiet[Get[$resumeFile]["Environment"]], None]
    },
    (* TypeTheory's Export of an environment gives File[file], not the file name *)
    If[ ! MatchQ[Export[environmentFile, environment], _String | File[_String]],
        Print["The environment could not be saved to ", environmentFile];
        Exit[1]
    ];
    Put[
        <|
            "Status" -> $status, "Seconds" -> $seconds, "Environment" -> environmentFile,
            "Orders" -> orders, "Dependencies" -> $dependencies, "WalkFailures" -> $walkFailures
        |>,
        $resumeFile <> ".new"
    ];
    RenameFile[$resumeFile <> ".new", $resumeFile, OverwriteTarget -> True];
    If[StringQ[previous] && previous =!= environmentFile && FileExistsQ[previous], DeleteFile[previous]]
]

End[];

If[ ListQ[$constants],
    roots = {$constants};
    Print["constants: ", $constants]
    ,
    moduleOf = AssociationMap[Function[name, Quiet[lean[name]["Module"]]], Keys[lean]];
    roots = Function[module, Select[Keys[lean], Function[name, moduleOf[name] === module]]] /@ $modules;
    Print["modules: ", AssociationThread[$modules, Length /@ roots]]
];

{status, primaryOf, seconds, stopped} = Wolfram`LeanLink`Private`coverage[Wolfram`LeanLink`Private`extractHandle[lean], roots];

If[StringQ[$statusFile], Put[status, $statusFile]];

(* every constant's seconds, beside the verdicts, for finding the slow ones *)
If[StringQ[$statusFile], Put[seconds, $statusFile <> ".seconds.wl"]];

If[ stopped,
    Print["stopped by the budget at ", Round[SessionTime[]], " s: ", Length[status], " constants done, ", Count[status, "OK"], " check; run again with --resume"];
    Exit[3]
];

(* a blocked constant is charged to the failure at the end of its chain of blocked dependencies *)
rootFailure[name_String] := FixedPoint[Function[current, Replace[status[current], {{"Blocked", dependency_} :> dependency, _ :> current}]], name];

Print["\nwalked ", Length[status], ", checked ", Count[status, "OK"], ", failed ", Count[status, {"Failed", ___}], ", blocked ", Count[status, {"Blocked", _}]];

Print["failures by tag: ", ReverseSort[Counts[Cases[Values[status], {"Failed", tag_, _} :> tag]]]];

Print["\nfailures, with the constants each one blocks:"];

With[{blocked = Counts[rootFailure /@ Keys[Select[status, MatchQ[{"Blocked", _}]]]]},
    Scan[
        Function[name, Print["  ", name, " (", status[name][[2]], ", blocks ", Lookup[blocked, name, 0], "): ", StringTake[status[name][[3]], UpTo[160]]]],
        ReverseSortBy[Keys[Select[status, MatchQ[{"Failed", ___}]]], Function[name, Lookup[blocked, name, 0]]]
    ]
];

If[ ListQ[$constants],
    Print["\nthe constants named:"];
    Scan[Function[name, Print["  ", name, ": ", Lookup[status, primaryOf[name], "NotWalked"]]], $constants]
    ,
    Print["\nper module, its own constants:"];
    Scan[
        Function[{pair},
            Print["  ", First[pair], ": ", Length[Last[pair]], " constants, ", Counts[Function[name, Replace[Lookup[status, primaryOf[name], "NotWalked"], {{kind_, ___} :> kind}]] /@ Last[pair]]]
        ]
        ,
        Transpose[{$modules, roots}]
    ]
];

Print["\nthe constants that took longest to check:"];

Scan[Function[name, Print["  ", name, ": ", Round[seconds[name], 0.01], " s"]], Take[ReverseSortBy[Keys[seconds], seconds], UpTo[10]]];

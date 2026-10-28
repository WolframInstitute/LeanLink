#!/usr/bin/env wolframscript
(* Time TypeTheory against Lean's kernel on fixed cones of Mathlib. In each case a constant is imported into
   TypeTheory with every constant it depends on, as LeanToTypeTheory imports it, and Lean's kernel replays the same
   cone into an empty environment (bench/ConeReplay.lean, lean4checker's Environment.replay), on this machine.

       wl -f typetheory_benchmark.wls [case ...] [--runs n] [--profile] [--no-lean] [--project-dir dir]
           [--typetheory dir] [--time-limit seconds] [--out file]

   Each case runs in a kernel of its own: once cold, the first import in a fresh kernel, then n times warm (3 by
   default), when TypeTheory, its prelude and Lean's environment are loaded. An import splits into translating
   Lean's terms into TypeTheory's and checking them, TypeTheory's kernel alone, which is what Lean's replay does;
   the ratio is of checking to Lean's time. Lean replays each cone 3 times and the fastest counts.

   A root case, le_union or lift_of_splits, imports its constant's cone without the constant first, then times the
   constant alone, n times, against Lean's check of it alone. These take long and run only when named.

   --profile adds a run that times the kernel's and the bridge's main functions: calls, exclusive time without the
   profiled functions they call, and the inclusive time of their outermost calls, each less the instrumentation's
   own cost, measured first. --no-lean skips Lean's replay. --out saves the results, for Get, with the engine, the
   commits of TypeTheory, LeanLink and Mathlib, and the machine. The project directory, built Mathlib, defaults to
   ~/src/mathlib4, TypeTheory to the checkout next to this one, the time limit of each run to 1800 s.

   Run it with the same engine (wl, which Wolfram it runs is in the results) for every before and after. *)

$RecursionLimit = 20000;

$rootDirectory = DirectoryName[$InputFileName];

(* name -> {module to import, constant whose cone is checked} *)
$cases = <|
    "binaryRec" -> {"Mathlib.Data.Nat.BinaryRec", "Nat.binaryRec.eq_def"},
    "omega" -> {"Mathlib.Data.Int.Init", "Int.Internal.Linear.Poly.denote'_go_eq_denote"},
    "balanceL" -> {"Mathlib.Data.Int.Init", "_private.Std.Data.DTreeMap.Internal.Balancing.0.Std.DTreeMap.Internal.Impl.balanceL._proof_9"},
    "grind" -> {"Mathlib.Data.Int.Init", "_private.Mathlib.Data.Int.Init.0.Int.inductionOn'_sub_one._proof_1_16"},
    "sqrt" -> {"Mathlib.Analysis.Real.Sqrt", "Real.sqrt_nonneg"}
|>

(* name -> {module, constant checked alone, its cone without it imported first} *)
$rootCases = <|
    "le_union" -> {"Mathlib.FieldTheory.Extension", "IntermediateField.Lifts.le_union"},
    "lift_of_splits" -> {"Mathlib.FieldTheory.Extension", "IntermediateField.Lifts.exists_lift_of_splits'"}
|>

(* the kernel's functions, and the bridge's, that --profile times, by name in any of TypeTheory's contexts or LeanLink's *)
$profiled = {
    "declareAxiom",
    "declareDefinition",
    "declareTheorem",
    "inferType",
    "inferTypeOf",
    "spineType",
    "applicationType",
    "checkHasType",
    "lambdaType",
    "functionTypeSort",
    "constantType",
    "projectionType",
    "weakHeadNormalForm",
    "reducedHead",
    "reducedHeadWithoutUnfolding",
    "reduceHead",
    "reduceConstant",
    "reduceRecursor",
    "reduceProjection",
    "unfoldDefinition",
    "definitionallyEqualQ",
    "definitionallyEqualCases",
    "sameHeadArgumentsEqualQ",
    "argumentsEqualQ",
    "proofIrrelevantEqualQ",
    "reducedEqualQ",
    "lazyDeltaEqualQ",
    "normalFormsEqualQ",
    "spinesEqualQ",
    "etaEqualQ",
    "structureEtaQ",
    "instantiateBoundVariables",
    "abstractFreeVariable",
    "instantiateUniverseParameters",
    "applicationSpine",
    "constantRecord",
    "levelEquivalentQ",
    "coneOrder",
    "importedDeclarations"
}

arguments = Rest[Replace[$ScriptCommandLine, {} -> {$InputFileName}]];

optionNames = {"--project-dir", "--typetheory", "--time-limit", "--out", "--case", "--runs"};

optionValues = Association[Cases[Partition[arguments, 2, 1], {name_String, value_String} /; MemberQ[optionNames, name] :> (name -> value)]];

flags = Select[arguments, MemberQ[{"--profile", "--no-lean"}, #]&];

(* the cases in the order given, or the cone cases *)
caseNames = Replace[
    DeleteCases[Delete[arguments, Flatten[Function[position, {{position}, {position + 1}}] /@ Flatten[Position[arguments, Alternatives @@ optionNames, {1}]], 1]], Alternatives @@ flags],
    {} -> Keys[$cases]
];

$projectDirectory = Lookup[optionValues, "--project-dir", FileNameJoin[{$HomeDirectory, "src", "mathlib4"}]];

$typeTheoryDirectory = Lookup[optionValues, "--typetheory", FileNameJoin[{ParentDirectory[$rootDirectory], "TypeTheory", "TypeTheory"}]];

$timeLimit = ToExpression[Lookup[optionValues, "--time-limit", "1800"]];

$runs = ToExpression[Lookup[optionValues, "--runs", "3"]];

(* loaded before the definitions below are read, so that LeanImport and LeanToTypeTheory in them are LeanLink's *)
If[DirectoryQ[$typeTheoryDirectory], PacletDirectoryLoad[$typeTheoryDirectory]];

PacletDirectoryLoad[FileNameJoin[{$rootDirectory, "LeanLink"}]];

Needs["Wolfram`LeanLink`"];

gitCommit[directory_String] := StringTrim[RunProcess[{"git", "-C", directory, "rev-parse", "--short", "HEAD"}, "StandardOutput"]] <> If[StringTrim[RunProcess[{"git", "-C", directory, "status", "--porcelain", "--untracked-files=no"}, "StandardOutput"]] === "", "", "+changes"]

(* the 1-minute load average of this machine, which other sessions share *)
loadAverage[] := Replace[StringCases[RunProcess[{"sysctl", "-n", "vm.loadavg"}, "StandardOutput"], number : NumberString :> ToExpression[number], 1], {{load_} :> load, _ -> Missing["Unknown"]}]

(* Worker: one case in this kernel; its result is printed on one line for the driver *)

(* one import: its record, with the seconds it spent translating and checking or why it failed, and its environment *)
timedImportWithEnvironment[lean_, constants_, opts___] := Block[{timing, result},
    Wolfram`LeanLink`Private`$lastImportTimings = <||>;
    {timing, result} = AbsoluteTiming[TimeConstrained[LeanToTypeTheory[lean, constants, opts], $timeLimit, $TimedOut]];
    {
        <|
            "Seconds" -> timing
            ,
            "Translating" -> Lookup[Wolfram`LeanLink`Private`$lastImportTimings, "Translating", Missing["Unknown"]]
            ,
            "Checking" -> Lookup[Wolfram`LeanLink`Private`$lastImportTimings, "Checking", Missing["Unknown"]]
            ,
            "Result" -> Which[
                result === $TimedOut,
                    "TimedOut"
                ,
                FailureQ[result],
                    First[result]
                ,
                True,
                    Length[result]
            ]
        |>
        ,
        result
    }
]

timedImport[lean_, constants_, opts___] := First[timedImportWithEnvironment[lean, constants, opts]]

summary[values_List] := If[AllTrue[values, NumberQ], <|"Median" -> Round[Median[values], 0.01], "Min" -> Round[Min[values], 0.01], "Max" -> Round[Max[values], 0.01]|>, Missing["Failed"]]

(* Every call of each profiled function is timed: its exclusive time, without the time of the profiled functions it
   calls, and the inclusive time of its outermost calls. The function's definitions move to another symbol, which the
   timed definition calls, so the calls it makes in turn are timed too; a condition that calls the function itself
   calls the moved copy, untimed. Functions that hold their arguments, and SubValues and UpValues, are left alone, so
   their time lands on their callers. *)
profiledSymbol[short_String] := SelectFirst[
    Join[Names["WolframInstitute`TypeTheory`*`" <> short], Names["Wolfram`LeanLink`*`" <> short]],
    Function[name, DownValues[name] =!= {} && FreeQ[Attributes[name], HoldAll | HoldFirst | HoldRest | HoldAllComplete]],
    None
]

SetAttributes[timedCall, HoldRest]

(* a call of a profiled function: counted, its time without its profiled callees' added to its exclusive time, its
   whole time to its caller's callees' and, if no call of the same function encloses it, to its outermost time *)
timedCall[short_, call_] := With[{
    timed = WithCleanup[
        $calls[short] += 1;
        $nesting[short] += 1
        ,
        Block[{$childSeconds = 0.},
            With[{inner = AbsoluteTiming[call]},
                $exclusive[short] += First[inner] - $childSeconds;
                inner
            ]
        ]
        ,
        $nesting[short] -= 1
    ]
},
    $childSeconds += First[timed];
    If[$nesting[short] === 0, $outermost[short] += First[timed]];
    Last[timed]
]

instrument[short_String] := With[{name = profiledSymbol[short]},
    If[ StringQ[name],
        With[{function = Symbol[name], moved = Symbol["profiled`" <> short]},
            $calls[short] = 0;
            $nesting[short] = 0;
            $exclusive[short] = 0.;
            $outermost[short] = 0.;
            (* the function's name replaced in each left side, under a condition too, f[x_] /; test *)
            DownValues[moved] = Map[Function[rule, MapAt[Function[left, left /. function -> moved], rule, {1}]], DownValues[function]];
            DownValues[function] = {HoldPattern[function[parts___]] :> timedCall[short, moved[parts]]};
            True
        ]
        ,
        False
    ]
]

(* the instrumentation's cost per call: a trivial function timed the same way *)
calibrationSeconds[] := Block[{$calls, $nesting, $exclusive, $outermost, $childSeconds = 0., trivial, n = 100000},
    $calls["trivial"] = 0;
    $nesting["trivial"] = 0;
    $exclusive["trivial"] = 0.;
    $outermost["trivial"] = 0.;
    trivial[x_] := x;
    With[{plain = First[AbsoluteTiming[Do[trivial[i], {i, n}]]], timed = First[AbsoluteTiming[Do[timedCall["trivial", trivial[i]], {i, n}]]]},
        (timed - plain) / n
    ]
]

runCase[name_String] := Block[{root, module, constant, lean, dependencies, base, cold, warm, profiled = None, profile = None, overhead = None, skipped = {}, load = loadAverage[]},
    root = KeyExistsQ[$rootCases, name];
    {module, constant} = If[root, $rootCases[name], $cases[name]];
    lean = LeanImport["ProjectDir" -> $projectDirectory, "Imports" -> {module}];
    If[ root,
        (* the cone without the constant, then the constant alone *)
        dependencies = DeleteCases[DeleteDuplicates[Join[lean[constant]["TypeRefs"], lean[constant]["TermRefs"]]], constant];
        {cold, base} = timedImportWithEnvironment[lean, dependencies];
        warm = If[IntegerQ[cold["Result"]], Table[timedImport[lean, constant, "Environment" -> base], {$runs}], {cold}]
        ,
        cold = timedImport[lean, constant];
        warm = Table[timedImport[lean, constant], {$runs}]
    ];
    If[ MemberQ[flags, "--profile"] && ! root,
        overhead = calibrationSeconds[];
        $childSeconds = 0.;
        skipped = Select[$profiled, ! instrument[#]&];
        profiled = timedImport[lean, constant];
        profile = Association[Function[short, short -> {$calls[short], Round[$exclusive[short] - $calls[short] overhead, 0.01], Round[$outermost[short], 0.01]}] /@ Complement[$profiled, skipped]]
    ];
    <|
        "Case" -> name,
        "Constant" -> constant,
        "Root" -> root,
        "Constants" -> If[root, If[IntegerQ[cold["Result"]], cold["Result"] + 1, cold["Result"]], cold["Result"]],
        "Results" -> DeleteDuplicates[Lookup[If[root, warm, Append[warm, cold]], "Result"]],
        "Cold" -> Round[cold["Seconds"], 0.1],
        "Warm" -> summary[Lookup[warm, "Seconds"]],
        "Checking" -> summary[Lookup[warm, "Checking"]],
        "Translating" -> summary[Lookup[warm, "Translating"]],
        "Profiled" -> If[profiled === None, None, Round[profiled["Seconds"], 0.1]],
        "Profile" -> profile,
        "ProfileOverhead" -> overhead,
        "NotProfiled" -> skipped,
        "Load" -> load,
        "Memory" -> Round[MaxMemoryUsed[] / 2.^30, 0.1],
        "Version" -> $Version,
        "TypeTheory" -> {PacletFind["WolframInstitute/TypeTheory"][[1]]["Version"], gitCommit[ParentDirectory[$typeTheoryDirectory]]},
        "LeanLink" -> gitCommit[$rootDirectory],
        "Mathlib" -> {gitCommit[$projectDirectory], StringTrim[Import[FileNameJoin[{$projectDirectory, "lean-toolchain"}], "Text"]]},
        "Machine" -> {$MachineName, $ProcessorType, $ProcessorCount}
    |>
]

If[ KeyExistsQ[optionValues, "--case"],
    Print["RESULT ", ToString[runCase[optionValues["--case"]], InputForm]];
    Exit[0]
]

(* Driver: each case in a kernel of its own, then Lean's replay of the same cones *)

(* Lean's fastest of 3 replays: the cone's size, its time, and the root's time alone on the rest of its cone *)
leanReplay[name_String] := Block[{module, constant, runs},
    {module, constant} = Lookup[Join[$cases, $rootCases], name];
    runs = Table[
        StringCases[
            RunProcess[{"lake", "env", "lean", "--run", FileNameJoin[{$rootDirectory, "bench", "ConeReplay.lean"}], module, constant}, ProcessDirectory -> $projectDirectory]["StandardOutput"],
            "cone of " ~~ size : DigitCharacter.. ~~ " constants replayed in " ~~ ms : DigitCharacter.. ~~ " ms; the root alone in " ~~ alone : DigitCharacter.. ~~ " ms" :> ToExpression /@ {
                size,
                ms,
                alone
            }
        ]
        ,
        {3}
    ];
    If[ AllTrue[runs, MatchQ[{{_Integer, _Integer, _Integer}, ___}]],
        <|"LeanConstants" -> runs[[1, 1, 1]], "LeanMilliseconds" -> Min[runs[[All, 1, 2]]], "LeanRootMilliseconds" -> Min[runs[[All, 1, 3]]]|>,
        <|"LeanConstants" -> Missing["NoReplay"], "LeanMilliseconds" -> Missing["NoReplay"], "LeanRootMilliseconds" -> Missing["NoReplay"]|>
    ]
]

runInKernel[name_String] := Block[{output, result},
    Print["--- ", name, ": ", Last[Lookup[Join[$cases, $rootCases], name]]];
    output = RunProcess[Join[{"wl", "-f", $InputFileName, "--case", name}, Flatten[KeyValueMap[List, KeyDrop[optionValues, {"--case", "--out"}]]], flags], "StandardOutput"];
    result = Join[
        Replace[
            StringCases[output, "RESULT " ~~ line : Except["\n"].. :> ToExpression[line]],
            {{found_Association, ___} :> found, _ :> <|"Case" -> name, "Failure" -> StringTake[output, -UpTo[600]]|>}
        ],
        If[MemberQ[flags, "--no-lean"], <||>, leanReplay[name]]
    ];
    Print["    ", KeyDrop[result, {"Profile"}]];
    result
]

results = runInKernel /@ caseNames;

(* a run that failed, or that gave a different count from one run to the next, gets no ratio *)
failedQ[result_] := ! IntegerQ[Lookup[result, "Constants"]] || ! MatchQ[Lookup[result, "Results", {}], {_Integer}]

ratio[result_] := Which[
    failedQ[result],
        "FAILED"
    ,
    IntegerQ[Lookup[result, "LeanConstants"]] && result["LeanConstants"] =!= result["Constants"],
        "cones differ"
    ,
    TrueQ[result["Root"]] && AssociationQ[result["Warm"]] && NumberQ[Lookup[result, "LeanRootMilliseconds"]] && result["LeanRootMilliseconds"] > 0,
        ToString[Round[1000 result["Warm"]["Median"] / result["LeanRootMilliseconds"]]] <> "x"
    ,
    AssociationQ[result["Checking"]] && NumberQ[Lookup[result, "LeanMilliseconds"]] && result["LeanMilliseconds"] > 0,
        ToString[Round[1000 result["Checking"]["Median"] / result["LeanMilliseconds"]]] <> "x"
    ,
    True,
        "-"
]

spread[value_] := If[AssociationQ[value], ToString[value["Median"]] <> " (" <> ToString[value["Min"]] <> "-" <> ToString[value["Max"]] <> ")", ToString[value]]

Print[];

Print[
    Lookup[First[results], "Version", "?"],
    "; TypeTheory ",
    Lookup[First[results], "TypeTheory", "?"],
    ", LeanLink ",
    Lookup[First[results], "LeanLink", "?"],
    ", Mathlib ",
    Lookup[First[results], "Mathlib", "?"],
    "; ",
    $runs,
    " warm runs, median (min-max)"
];

Print["case             constants (Lean)     cold s   warm s                 checking s             translating s     Lean ms   checking / Lean   load"];

Scan[
    Function[result,
        Print[
            StringPadRight[result["Case"], 17],
            StringPadRight[ToString[Lookup[result, "Constants", "-"]] <> " (" <> ToString[Lookup[result, "LeanConstants", "-"]] <> ")", 21],
            StringPadLeft[ToString[Lookup[result, "Cold", "-"]], 7],
            "   ",
            StringPadRight[spread[Lookup[result, "Warm", "-"]], 23],
            StringPadRight[spread[Lookup[result, "Checking", "-"]], 23],
            StringPadRight[spread[Lookup[result, "Translating", "-"]], 18],
            StringPadLeft[ToString[If[TrueQ[Lookup[result, "Root"]], Lookup[result, "LeanRootMilliseconds", "-"], Lookup[result, "LeanMilliseconds", "-"]]], 8],
            StringPadLeft[ratio[result], 18],
            StringPadLeft[ToString[Lookup[result, "Load", "-"]], 7]
        ]
    ]
    ,
    results
];

Print["checking / Lean is TypeTheory's checking against Lean's replay; for a root case, the root alone against Lean's check of it alone."];

If[ MemberQ[flags, "--profile"],
    Scan[
        Function[result,
            If[ AssociationQ[Lookup[result, "Profile"]],
                Print[];
                Print[
                    "profile of ",
                    result["Case"],
                    " (",
                    result["Profiled"],
                    " s profiled, less ",
                    Round[10^6 result["ProfileOverhead"], 0.1],
                    " us a call): calls, exclusive seconds, seconds in outermost calls"
                ];
                KeyValueMap[
                    Function[{function, entry},
                        Print["  ", StringPadRight[function, 30], StringPadLeft[ToString[entry[[1]]], 12], StringPadLeft[ToString[entry[[2]]], 10], StringPadLeft[ToString[entry[[3]]], 10]]
                    ]
                    ,
                    ReverseSortBy[result["Profile"], #[[2]]&]
                ];
                If[result["NotProfiled"] =!= {}, Print["  not profiled (not found, or holding their arguments): ", StringRiffle[result["NotProfiled"], ", "]]]
            ]
        ]
        ,
        results
    ]
];

If[KeyExistsQ[optionValues, "--out"], Put[results, optionValues["--out"]]];

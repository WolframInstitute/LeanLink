#!/usr/bin/env wolframscript
(* Time TypeTheory against Lean's kernel on fixed cones of Mathlib. In each case a constant is imported into
   TypeTheory with every constant it depends on, as LeanToTypeTheory imports it, and Lean's kernel replays the same
   cone into an empty environment (bench/ConeReplay.lean, lean4checker's Environment.replay), on this machine.

       wl -f typetheory_benchmark.wls [case ...] [--profile] [--no-lean] [--project-dir dir] [--typetheory dir]
           [--time-limit seconds] [--out file]

   Each case runs in a kernel of its own, twice: cold, the first import in a fresh kernel, then warm, the same
   import again, when TypeTheory, its prelude and Lean's environment are loaded. --profile adds a third run that
   times the kernel's and the bridge's main functions: for each, the number of calls and the inclusive time of its
   outermost calls, so a function that calls itself is counted once. Its times overlap (inferType includes the
   definitional equalities it asks), and the instrumentation slows the run, so the warm time is the one to compare.
   --no-lean skips Lean's replay. --out saves the results, a list of associations, for Get.

   The cases default to all of them. The project directory, built Mathlib, defaults to ~/src/mathlib4; TypeTheory
   loads from --typetheory, by default the checkout next to this one; the time limit for each run is 1800 s. *)

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

(* the kernel's functions, and the bridge's, that --profile times, by name in any of TypeTheory's contexts or LeanLink's *)
$profiled = {
    "declareAxiom",
    "declareDefinition",
    "declareTheorem",
    "inferType",
    "inferTypeOf",
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
    "constantRecord",
    "levelEquivalentQ",
    "coneOrder",
    "importedDeclarations"
}

arguments = Rest[Replace[$ScriptCommandLine, {} -> {$InputFileName}]];

optionNames = {"--project-dir", "--typetheory", "--time-limit", "--out", "--case"};

optionValues = Association[Cases[Partition[arguments, 2, 1], {name_String, value_String} /; MemberQ[optionNames, name] :> (name -> value)]];

flags = Select[arguments, MemberQ[{"--profile", "--no-lean"}, #]&];

(* the cases in the order given, or all of them *)
caseNames = Replace[
    DeleteCases[Delete[arguments, Flatten[Function[position, {{position}, {position + 1}}] /@ Flatten[Position[arguments, Alternatives @@ optionNames, {1}]], 1]], Alternatives @@ flags],
    {} -> Keys[$cases]
];

$projectDirectory = Lookup[optionValues, "--project-dir", FileNameJoin[{$HomeDirectory, "src", "mathlib4"}]];

$typeTheoryDirectory = Lookup[optionValues, "--typetheory", FileNameJoin[{ParentDirectory[$rootDirectory], "TypeTheory", "TypeTheory"}]];

$timeLimit = ToExpression[Lookup[optionValues, "--time-limit", "1800"]];

(* loaded before the definitions below are read, so that LeanImport and LeanToTypeTheory in them are LeanLink's *)
If[DirectoryQ[$typeTheoryDirectory], PacletDirectoryLoad[$typeTheoryDirectory]];

PacletDirectoryLoad[FileNameJoin[{$rootDirectory, "LeanLink"}]];

Needs["Wolfram`LeanLink`"];

(* Worker: one case, cold, warm and profiled, in this kernel; its result is printed on one line for the driver *)

timedImport[lean_, constant_String] := Block[{timing, result},
    {timing, result} = AbsoluteTiming[TimeConstrained[LeanToTypeTheory[lean, constant], $timeLimit, $TimedOut]];
    {
        timing
        ,
        Which[
            result === $TimedOut,
                "TimedOut"
            ,
            FailureQ[result],
                First[result]
            ,
            True,
                Length[result]
        ]
    }
]

(* Every call of each profiled function is timed: its exclusive time, without the time of the profiled functions it
   calls, and the inclusive time of its outermost calls. The function's definitions move to another symbol, which the
   timed definition calls, so the calls it makes in turn are timed too. Functions that hold their arguments are left
   alone. *)
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
            DownValues[function] = {HoldPattern[function[parts___]] :> timedCall[short, moved[parts]]}
        ]
    ]
]

runCase[name_String] := Block[{module, constant, lean, cold, warm, profiled = None, profile = None},
    {module, constant} = $cases[name];
    lean = LeanImport["ProjectDir" -> $projectDirectory, "Imports" -> {module}];
    cold = timedImport[lean, constant];
    warm = timedImport[lean, constant];
    If[ MemberQ[flags, "--profile"],
        $childSeconds = 0.;
        Scan[instrument, $profiled];
        profiled = timedImport[lean, constant];
        profile = Association[Function[short, short -> {$calls[short], Round[$exclusive[short], 0.01], Round[$outermost[short], 0.01]}] /@ Select[$profiled, NumberQ[$calls[#]]&]]
    ];
    <|
        "Case" -> name,
        "Constant" -> constant,
        "TypeTheory" -> PacletFind["WolframInstitute/TypeTheory"][[1]]["Version"],
        "Constants" -> Last[warm],
        "Cold" -> Round[First[cold], 0.1],
        "Warm" -> Round[First[warm], 0.1],
        "Profiled" -> If[profiled === None, None, Round[First[profiled], 0.1]],
        "Profile" -> profile,
        "Memory" -> Round[MaxMemoryUsed[] / 2.^30, 0.1]
    |>
]

If[ KeyExistsQ[optionValues, "--case"],
    Print["RESULT ", ToString[runCase[optionValues["--case"]], InputForm]];
    Exit[0]
]

(* Driver: each case in a kernel of its own, then Lean's replay of the same cones *)

leanReplay[name_String] := Block[{module, constant, output},
    {module, constant} = $cases[name];
    output = RunProcess[{"lake", "env", "lean", "--run", FileNameJoin[{$rootDirectory, "bench", "ConeReplay.lean"}], module, constant}, ProcessDirectory -> $projectDirectory];
    Replace[
        StringCases[output["StandardOutput"], "cone of " ~~ size : DigitCharacter.. ~~ " constants replayed in " ~~ ms : DigitCharacter.. ~~ " ms" :> {ToExpression[size], ToExpression[ms]}]
        ,
        {
            {{size_, ms_}, ___} :> <|"LeanConstants" -> size, "LeanMilliseconds" -> ms|>,
            _ :> <|"LeanConstants" -> Missing["NoReplay"], "LeanMilliseconds" -> Missing["NoReplay", StringTake[output["StandardError"], UpTo[300]]]|>
        }
    ]
]

runInKernel[name_String] := Block[{output, result},
    Print["--- ", name, ": ", Last[$cases[name]]];
    output = RunProcess[Join[{"wl", "-f", $InputFileName, "--case", name}, Flatten[KeyValueMap[List, KeyDrop[optionValues, {"--case", "--out"}]]], flags], "StandardOutput"];
    result = Join[
        Replace[
            StringCases[output, "RESULT " ~~ line : Except["\n"].. :> ToExpression[line]],
            {{found_Association, ___} :> found, _ :> <|"Case" -> name, "Failure" -> StringTake[output, -UpTo[600]]|>}
        ],
        If[MemberQ[flags, "--no-lean"], <||>, leanReplay[name]]
    ];
    Print["    ", result];
    result
]

results = runInKernel /@ caseNames;

Print[];

Print["case        constants      cold s     warm s     Lean ms     warm / Lean"];

Scan[
    Function[result,
        Print[
            StringPadRight[result["Case"], 12]
            ,
            StringPadLeft[ToString[Lookup[result, "Constants", "-"]], 9]
            ,
            StringPadLeft[ToString[Lookup[result, "Cold", "-"]], 12]
            ,
            StringPadLeft[ToString[Lookup[result, "Warm", "-"]], 11]
            ,
            StringPadLeft[ToString[Lookup[result, "LeanMilliseconds", "-"]], 12]
            ,
            StringPadLeft[
                If[NumberQ[Lookup[result, "Warm"]] && NumberQ[Lookup[result, "LeanMilliseconds"]] && result["LeanMilliseconds"] > 0, ToString[Round[1000 result["Warm"] / result["LeanMilliseconds"]]] <> "x", "-"], 16
            ]
        ]
    ]
    ,
    results
];

If[ MemberQ[flags, "--profile"],
    Scan[
        Function[result,
            If[ AssociationQ[Lookup[result, "Profile"]],
                Print[];
                Print["profile of ", result["Case"], " (", result["Profiled"], " s profiled): calls, exclusive seconds, seconds in outermost calls"];
                KeyValueMap[
                    Function[{function, entry},
                        Print["  ", StringPadRight[function, 30], StringPadLeft[ToString[entry[[1]]], 12], StringPadLeft[ToString[entry[[2]]], 10], StringPadLeft[ToString[entry[[3]]], 10]]
                    ]
                    ,
                    ReverseSortBy[result["Profile"], #[[2]]&]
                ]
            ]
        ]
        ,
        results
    ]
];

If[KeyExistsQ[optionValues, "--out"], Put[results, optionValues["--out"]]];

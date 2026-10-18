#!/usr/bin/env wolframscript
(* Measure how much of a Lean library TypeTheory checks: every constant of the given modules, with
   every constant it depends on, is imported in dependency order into one TypeTheory environment, as
   LeanToTypeTheory imports them. A constant that fails is recorded with its failure; a constant that
   depends on one that did not check is blocked and not tried. It uses the bridge's internals, so it
   is a development tool and runs against this checkout of LeanLink.

       wl -f typetheory_coverage.wls [module ...] [--project-dir dir] [--time-limit seconds]
           [--typetheory dir] [--out file]

   The modules default to Init.Prelude. The project directory, a built Lake project such as Mathlib,
   defaults to ~/src/mathlib4; the time limit for each constant to 300 seconds. TypeTheory loads from
   --typetheory, by default the checkout next to this one when there is one, and otherwise as
   installed. --out saves the status of every constant to a file, <|name -> "OK" | {"Failed", tag,
   message} | {"Blocked", dependency}|>, which Get reads back. *)

$RecursionLimit = 20000;

$rootDirectory = DirectoryName[$InputFileName];

arguments = Rest[Replace[$ScriptCommandLine, {} -> {$InputFileName}]];

optionNames = {"--project-dir", "--time-limit", "--typetheory", "--out"};
optionValues = Association[Cases[Partition[arguments, 2, 1], {name_String, value_String} /; MemberQ[optionNames, name] :> (name -> value)]];
optionPositions = Flatten[Function[position, {{position}, {position + 1}}] /@ Flatten[Position[arguments, Alternatives @@ optionNames, {1}]], 1];

$modules = Replace[Delete[arguments, optionPositions], {} -> {"Init.Prelude"}];
$projectDirectory = Lookup[optionValues, "--project-dir", FileNameJoin[{$HomeDirectory, "src", "mathlib4"}]];
$timeLimit = ToExpression[Lookup[optionValues, "--time-limit", "300"]];
$typeTheoryDirectory = Lookup[optionValues, "--typetheory", FileNameJoin[{ParentDirectory[$rootDirectory], "TypeTheory", "TypeTheory"}]];
$statusFile = Lookup[optionValues, "--out", None];

If[ DirectoryQ[$typeTheoryDirectory], PacletDirectoryLoad[$typeTheoryDirectory]];
PacletDirectoryLoad[FileNameJoin[{$rootDirectory, "LeanLink"}]];
Needs["Wolfram`LeanLink`"];

lean = LeanImport["ProjectDir" -> $projectDirectory, "Imports" -> $modules];
If[ FailureQ[lean],
	Print["The modules did not load: ", lean];
	Exit[1]
];
Print["LeanLink ", PacletFind["Wolfram/LeanLink"][[1]]["Version"], ", TypeTheory ", PacletFind["WolframInstitute/TypeTheory"][[1]]["Version"], " from ",
	PacletFind["WolframInstitute/TypeTheory"][[1]]["Location"]];
Wolfram`LeanLink`Private`loadTypeTheoryBridge[];

Begin["Wolfram`LeanLink`Private`"];

(* the dependency cone of the roots, in dependency order; a constant the walk cannot follow fails *)
coverageVisit[name_String] := With[{primary = Replace[Catch[primaryName[name], $bridgeTag], Except[_String] -> name]},
	If[ ! KeyExistsQ[$seen, primary],
		$seen[primary] = True;
		With[{dependencies = Catch[DeleteDuplicates[primaryName /@ DeleteCases[constantDependencies[primary], Alternatives @@ ownNames[primary]]], $bridgeTag]},
			If[ ListQ[dependencies],
				$dependencies[primary] = dependencies;
				Scan[coverageVisit, dependencies],
				$dependencies[primary] = {};
				$walkFailures[primary] = dependencies
			]
		];
		Sow[primary, $coneTag]
	]
]

failureStatus[failure_] := {
	"Failed",
	If[FailureQ[failure], First[failure], "Other"],
	StringTake[ToString[If[FailureQ[failure], failure["Message"], Short[failure]]], UpTo[400]]
}

coverageStatus[name_String, environment_] := Which[
	KeyExistsQ[$walkFailures, name],
		{failureStatus[$walkFailures[name]], environment},
	AnyTrue[$dependencies[name], Function[dependency, Lookup[$status, dependency, "OK"] =!= "OK"]],
		{{"Blocked", SelectFirst[$dependencies[name], Function[dependency, Lookup[$status, dependency, "OK"] =!= "OK"]]}, environment},
	True,
		With[
			{
				result = TimeConstrained[
					Catch[
						With[{extended = TypeTheoryEnvironment[environment, importedDeclarations[environment, name]]},
							If[ ! FailureQ[extended] && constantKind[name] === "inductive", checkRecursor[extended, name]];
							extended
						],
						$bridgeTag
					],
					$timeLimit,
					Failure["Timeout", <|"MessageTemplate" -> "It did not check within `1` seconds.", "MessageParameters" -> {$timeLimit}|>]
				]
			},
			If[MatchQ[result, _TypeTheoryEnvironment], {"OK", result}, {failureStatus[result], environment}]
		]
]

coverage[handle_, rootGroups_List] := Block[
	{$kinds = <||>, $universes = <||>, $inductives = <||>, $handle = handle, $seen = <||>, $dependencies = <||>, $walkFailures = <||>, $status = <||>},
	Module[{environment = TypeTheoryEnvironment[quotientRules[]], start = AbsoluteTime[]},
		Scan[
			Function[group,
				Scan[
					Function[name,
						With[{outcome = coverageStatus[name, environment]},
							$status[name] = First[outcome];
							environment = Last[outcome]
						];
						If[ Mod[Length[$status], 200] == 0,
							Print[Length[$status], " constants, ", Count[$status, "OK"], " check, ", Round[AbsoluteTime[] - start], " s"]
						]
					],
					Flatten[Last[Reap[Scan[coverageVisit, group], $coneTag]]]
				];
				Print["roots of a module done: ", Length[$status], " constants, ", Count[$status, "OK"], " check, ", Round[AbsoluteTime[] - start], " s"]
			],
			rootGroups
		];
		(* a constructor or recursor is checked with its inductive type *)
		{$status, AssociationMap[Function[name, Replace[Catch[primaryName[name], $bridgeTag], Except[_String] -> name]], Flatten[rootGroups]]}
	]
]

End[];

moduleOf = AssociationMap[Function[name, Quiet[lean[name]["Module"]]], Keys[lean]];
roots = Function[module, Select[Keys[lean], Function[name, moduleOf[name] === module]]] /@ $modules;
Print["modules: ", AssociationThread[$modules, Length /@ roots]];

{status, primaryOf} = Wolfram`LeanLink`Private`coverage[Wolfram`LeanLink`Private`extractHandle[lean], roots];
If[ StringQ[$statusFile], Put[status, $statusFile]];

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
Print["\nper module, its own constants:"];
Scan[
	Function[{pair}, Print["  ", First[pair], ": ", Length[Last[pair]], " constants, ",
		Counts[Function[name, Replace[Lookup[status, primaryOf[name], "NotWalked"], {{kind_, ___} :> kind}]] /@ Last[pair]]]],
	Transpose[{$modules, roots}]
];

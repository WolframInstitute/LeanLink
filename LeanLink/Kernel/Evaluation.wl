(* ::Package:: *)

BeginPackage["Wolfram`LeanLink`"]

LeanEvaluate::usage = "LeanEvaluate[environment, expression] evaluates a Lean expression using an imported environment. LeanEvaluate[term, args] applies an imported declaration to Wolfram values. LeanEvaluate[expression] evaluates in a separate process."

LeanImportString::usage = "LeanImportString[source] compiles Lean source into a LeanEnvironment. LeanImportString[environment, source] also imports the modules of environment."

LeanFreeEnvironment::usage = "LeanFreeEnvironment[environment] or LeanFreeEnvironment[handle] releases an imported environment and stops its evaluator."

LeanVerify::usage = "LeanVerify[term] checks a theorem in Lean's kernel and rejects dependencies on admitted proofs or additional axioms."

Begin["`Private`"]

$evaluationWorkers = <||>
$leanImportSearchPath = ""

evaluationFailure[tag_String, message_String, data_Association : <||>] := Failure[tag, Join[<|"MessageTemplate" -> message|>, data]]

environmentHandle[LeanEnvironment[data_Association]] := Lookup[data, "_Handle", None]
environmentHandle[LeanTerm[data_Association]] := Lookup[data, "_Handle", None]

environmentHandles[LeanEnvironment[data_Association]] := Select[Lookup[data, "_Handles", {Lookup[data, "_Handle", None]}], IntegerQ]

liveEnvironmentQ[handle_] := IntegerQ[handle] && KeyExistsQ[$handleSource, handle]

environmentDirectories[handle_Integer] := Select[Flatten[{handleInfo[handle, "TemporaryDirectory"], handleInfo[handle, "RetainedDirectories"]}], StringQ]

stopEvaluator[handle_] := With[{worker = Lookup[$evaluationWorkers, handle, None]},
    If[AssociationQ[worker], Quiet[KillProcess[worker["Process"]]]];
    KeyDropFrom[$evaluationWorkers, handle];
    Null
]

readEvaluatorStream[process_, name_String] := Replace[Quiet[ReadString[ProcessConnection[process, name], EndOfBuffer]], Except[_String] -> ""]

(* Both pipes are drained while waiting, including when the result exceeds a pipe
   buffer. The JSON envelope keeps diagnostics separate from the returned value. *)
evaluatorResponse[process_, id_String, deadline_] := Block[{out = "", err = "", lines, response, status},
    While[True,
        out = out <> readEvaluatorStream[process, "StandardOutput"];
        err = StringTake[err <> readEvaluatorStream[process, "StandardError"], UpTo[4096]];
        lines = StringSplit[out, "\n", All];
        out = Last[lines];
        Do[
            If[StringStartsQ[line, "LEANLINK_RESPONSE "],
                response = Quiet[ImportString[StringDrop[line, StringLength["LEANLINK_RESPONSE "]], "RawJSON"]];
                If[AssociationQ[response] && Lookup[response, "id", None] === id, Return[response, Block]]
            ],
            {line, Most[lines]}
        ];
        status = Quiet[ProcessStatus[process]];
        If[status =!= "Running", Return[evaluationFailure["LeanEvaluateFailed", "The Lean evaluator stopped.", <|"Output" -> err <> out|>], Block]];
        If[AbsoluteTime[] >= deadline, Return[evaluationFailure["TimedOut", "Lean evaluation exceeded the time limit."], Block]];
        Pause[0.001]
    ]
]

sendEvaluatorRequest[process_, request_Association, deadline_] := Block[{json},
    json = ExportString[request, "RawJSON", "Compact" -> True];
    WriteString[process, json <> "\n"];
    evaluatorResponse[process, request["id"], deadline]
]

startEvaluator[handle_Integer, deadline_] := Block[{tc, bin, process, response, request, environment},
    tc = leanToolchainDir[];
    If[tc === $Failed, Return[evaluationFailure["ToolchainNotInstalled", "Install LeanLink's pinned Lean toolchain before evaluating."]]];
    bin = FileNameJoin[{tc, "bin"}];
    environment = Association[GetEnvironment[],
        "LEAN_PATH" -> handleInfo[handle, "SearchPath"],
        "PATH" -> StringRiffle[{bin, Replace[Environment["PATH"], Except[_String] -> ""]}, $searchPathSeparator]
    ];
    process = Quiet[StartProcess[{leanProgram[bin, "lean"], "--run", FileNameJoin[{$PacletRoot, "Assets", "Evaluator.lean"}]}, ProcessEnvironment -> environment]];
    If[! MatchQ[process, _ProcessObject], Return[evaluationFailure["LeanEvaluateFailed", "Could not start the Lean evaluator."]]];
    $evaluationWorkers[handle] = <|"Process" -> process|>;
    request = <|"id" -> CreateUUID[], "imports" -> handleInfo[handle, "Imports"]|>;
    response = sendEvaluatorRequest[process, request, deadline];
    If[FailureQ[response] || ! TrueQ[response["ok"]],
        stopEvaluator[handle];
        Return[If[FailureQ[response], response, evaluationFailure["LeanEvaluateFailed", Lookup[response, "error", "Lean could not import the environment."]]]]
    ];
    process
]

evaluateInEnvironment[handle_Integer, expression_String, source_String, opens_List, limit_] := Block[{worker, process, response, deadline = AbsoluteTime[] + limit},
    If[! liveEnvironmentQ[handle], Return[evaluationFailure["InvalidEnvironment", "The Lean environment has been released or is not available in this kernel."]]];
    CheckAbort[
        worker = Lookup[$evaluationWorkers, handle, <||>];
        process = Lookup[worker, "Process", None];
        If[! MatchQ[process, _ProcessObject] || Quiet[ProcessStatus[process]] =!= "Running", process = startEvaluator[handle, deadline]];
        If[FailureQ[process], Return[process, Block]];
        response = sendEvaluatorRequest[process, <|"id" -> CreateUUID[], "expression" -> expression, "source" -> source, "open" -> opens|>, deadline];
        If[FailureQ[response], stopEvaluator[handle]; Return[response, Block]];
        If[! TrueQ[response["ok"]], Return[evaluationFailure["LeanEvaluateFailed", response["error"], <|"Output" -> response["error"]|>], Block]];
        If[! MatchQ[response["value"], {_}], stopEvaluator[handle]; Return[evaluationFailure["LeanEvaluateFailed", "The Lean evaluator returned an invalid value."], Block]];
        withFloats[First[response["value"]]],
        stopEvaluator[handle]; Abort[]
    ]
]

LeanEvaluate[environment_LeanEnvironment, expression_String, opts : OptionsPattern[]] := Block[{limit = OptionValue["TimeLimit"], source = OptionValue["Source"], opens, handle},
    If[Length[environmentHandles[environment]] > 1, Return[evaluationFailure["SeparateEnvironments", "Import the required modules together with LeanImport's Imports option, or evaluate a term from this collection."]]];
    handle = environmentHandle[environment];
    If[! liveEnvironmentQ[handle], Return[evaluationFailure["InvalidEnvironment", "Use an imported Lean environment that has not been released."]]];
    If[! (limit === Infinity || NumberQ[limit] && TrueQ[limit > 0]) || ! StringQ[source], Return[evaluationFailure["InvalidOption", "Use a positive TimeLimit and a string Source."]]];
    opens = Flatten[{OptionValue["Open"]}];
    If[! MatchQ[opens, {___String}], Return[evaluationFailure["InvalidOption", "Open must contain namespace names."]]];
    If[OptionValue["ProjectDir"] =!= None || OptionValue["Imports"] =!= {}, Return[evaluationFailure["InvalidOption", "Select the project and modules with LeanImport before evaluating in an environment."]]];
    evaluateInEnvironment[handle, expression, source, opens, limit]
]

leanArgument[_, n_Integer] := "(" <> If[n < 0, "-", ""] <> IntegerString[Abs[n]] <> ")"
leanArgument[handle_, n_Rational] := "(" <> leanArgument[handle, Numerator[n]] <> " / " <> IntegerString[Denominator[n]] <> " : Rat)"
leanArgument[_, True] := "true"
leanArgument[_, False] := "false"
leanArgument[_, value_String] := "\"" <> StringJoin[Map[
    Switch[#, 34, "\\\"", 92, "\\\\", 10, "\\n", 13, "\\r", 9, "\\t", _, If[# < 32 || # === 127, "\\u" <> IntegerString[#, 16, 4], FromCharacterCode[#]]]&,
    ToCharacterCode[value]
]] <> "\""
leanArgument[handle_, values_List] := With[{encoded = leanArgument[handle, #]& /@ values},
    If[AnyTrue[encoded, FailureQ], SelectFirst[encoded, FailureQ], "[" <> StringRiffle[encoded, ", "] <> "]"]
]
leanArgument[handle_, term_LeanTerm] := If[environmentHandle[term] === handle, quotedLeanName[term["Name"]], evaluationFailure["InvalidEnvironment", "Use term arguments from the same environment."]]
leanArgument[_, _] := evaluationFailure["UnsupportedArgument", "Use exact integers, rationals, booleans, strings, lists or terms from the same environment."]

withFloats[value_Association /; Keys[value] === {"LeanLinkRational"}] := With[{fraction = value["LeanLinkRational"]},
    If[MatchQ[fraction, {_Integer, _Integer ? Positive}], First[fraction] / Last[fraction], evaluationFailure["InvalidValue", "Lean returned an invalid rational number."]]
]

quotedLeanName[name_String] := If[StringContainsQ[name, "\:00ab" | "\:00bb" | "\n" | "\r"],
    evaluationFailure["UnsupportedName", "This declaration's name cannot be used in Lean source."],
    StringRiffle[("\:00ab" <> # <> "\:00bb"&) /@ StringSplit[name, ".", All], "."]
]

LeanEvaluate[term_LeanTerm, arguments : Longest[Except[_Rule | _RuleDelayed]...], opts : OptionsPattern[]] := Block[{handle = environmentHandle[term], encoded},
    If[! liveEnvironmentQ[handle], Return[evaluationFailure["InvalidEnvironment", "The term must belong to an imported environment that has not been released."]]];
    encoded = Prepend[leanArgument[handle, #]& /@ {arguments}, quotedLeanName[term["Name"]]];
    If[AnyTrue[encoded, FailureQ], Return[SelectFirst[encoded, FailureQ]]];
    LeanEvaluate[LeanEnvironment[<|"_Handle" -> handle|>], StringRiffle[encoded, " "], opts]
]

(* A compiled snippet inherits the existing module path, including earlier
   snippets, without changing LEAN_PATH in the Wolfram process. *)
LeanImportString[environment_LeanEnvironment, source_String, opts : OptionsPattern[LeanImport]] := Block[{handle = environmentHandle[environment], project, imports, result},
    If[Length[environmentHandles[environment]] > 1, Return[evaluationFailure["SeparateEnvironments", "Import the required modules together with LeanImport's Imports option before adding declarations."]]];
    If[! liveEnvironmentQ[handle], Return[evaluationFailure["InvalidEnvironment", "Use an imported Lean environment that has not been released."]]];
    project = Replace[handleInfo[handle, "ProjectDir"], None -> Automatic];
    imports = StringRiffle[("import " <> #&) /@ handleInfo[handle, "Imports"], "\n"];
    result = Block[{$leanImportSearchPath = handleInfo[handle, "SearchPath"]}, LeanImportString[imports <> "\n" <> source, opts, "ProjectDir" -> project]];
    If[MatchQ[result, _LeanEnvironment], $handleSource[environmentHandle[result], "RetainedDirectories"] = environmentDirectories[handle]];
    result
]

LeanFreeEnvironment[environment_LeanEnvironment, opts : OptionsPattern[]] := Scan[LeanFreeEnvironment[#, opts]&, environmentHandles[environment]]

Options[LeanVerify] = {"TimeLimit" -> 600}

LeanVerify[term_LeanTerm, OptionsPattern[]] := Block[{axioms, checked, kinds, limit = OptionValue["TimeLimit"]},
    If[! liveEnvironmentQ[environmentHandle[term]], Return[evaluationFailure["InvalidEnvironment", "The theorem's environment is not available."]]];
    If[! StringQ[term["Name"]], Return[evaluationFailure["NotATheorem", "Select a named theorem declaration to verify."]]];
    kinds = Quiet[decodeWXF[$listConstantKindsFn[environmentHandle[term], term["Name"]]]];
    If[! AssociationQ[kinds] || Lookup[kinds, term["Name"], None] =!= "theorem", Return[evaluationFailure["NotATheorem", "Select a theorem declaration to verify."]]];
    If[! (limit === Infinity || NumberQ[limit] && TrueQ[limit > 0]), Return[evaluationFailure["InvalidOption", "TimeLimit must be positive or Infinity."]]];
    TimeConstrained[
        axioms = term["Axioms"];
        If[! MatchQ[axioms, {___String}] || Complement[axioms, {"propext", "Quot.sound", "Classical.choice"}] =!= {},
            Return[evaluationFailure["UntrustedProof", "The theorem depends on an admitted proof or an additional axiom.", <|"Axioms" -> axioms|>], Block]
        ];
        checked = term["KernelCheck"];
        If[MatchQ[checked, _Success], Success["Verified", <|"MessageTemplate" -> "Lean's kernel accepts the theorem with standard axioms.", "Axioms" -> axioms, "KernelCheck" -> checked|>],
            evaluationFailure["KernelRejected", "Lean's kernel did not accept the theorem's module.", <|"Result" -> checked|>]
        ],
        limit, evaluationFailure["TimedOut", "Proof checking exceeded the time limit."]
    ]
]

End[]
EndPackage[]

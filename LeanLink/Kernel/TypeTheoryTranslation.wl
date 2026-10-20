(* ::Package:: *)

(* TypeTheoryTranslation.wl -- translating between Lean and the WolframInstitute/TypeTheory proof engine.

   From Lean: LeanToTypeTheory collects a constant's dependency cone through the native environment,
   orders it so each constant comes after the ones it mentions, and writes each constant as a TypeTheory
   declaration whose terms are TypeTheory's core terms, which share their subterms as Lean's do. With a
   TypeTheory before 0.11, the terms are exact surface syntax instead: every application is
   Construct[f, arguments...], so TypeTheory fills in no implicit argument, and every universe level is
   given with Subscript. Lean names stay strings; the recursor X.rec is TypeTheory's
   InductiveRecursor["X"], which TypeTheory generates itself and the bridge then compares with Lean's.
   TypeTheory's kernel checks every declaration again.

   To Lean: TypeTheoryToLean reads declarations back from a TypeTheory environment exactly (Normal) and
   prints them as Lean source with every application explicit (@f a b). Constants that came from Lean
   keep their names, the constants of TypeTheory's prelude that Lean has in Init are written as Lean's,
   and every other constant is declared under the namespace TypeTheory.

   LeanLink's records do not carry a constant's universe parameters, so they are read from Lean: the
   constant is type-checked at placeholder levels until the number of levels is right, and
   where the placeholders occur in the result names the parameters in order. *)

BeginPackage["Wolfram`LeanLink`", {"WolframInstitute`TypeTheory`"}];

Begin["`Private`"];

Clear[LeanToTypeTheory, TypeTheoryToLean]

(* === Failures === *)

bridgeFailure[tag_String, template_String, parameters_List] := Throw[
    Failure[tag, <|"MessageTemplate" -> template, "MessageParameters" -> parameters|>],
    $bridgeTag
]

SetAttributes[catchBridgeFailure, HoldFirst]

catchBridgeFailure[expr_] := Catch[expr, $bridgeTag]

(* ============================================================================ *)

(* From Lean                                                                    *)

(* ============================================================================ *)

Options[LeanToTypeTheory] = {"Environment" -> Automatic}

LeanToTypeTheory[term : LeanTerm[data_Association], opts : OptionsPattern[]] := Block[{handle = Lookup[data, "_Handle", None]},
    If[ IntegerQ[handle],
        importConstants[handle, {data["Name"]}, OptionValue["Environment"]],
        Failure["NoHandle", <|"MessageTemplate" -> "`1` was not imported from a Lean environment.", "MessageParameters" -> {data["Name"]}|>]
    ]
]

LeanToTypeTheory[env_LeanEnvironment, name_String, opts : OptionsPattern[]] := LeanToTypeTheory[env, {name}, opts]

LeanToTypeTheory[env_LeanEnvironment, names : {__String}, opts : OptionsPattern[]] := Block[{handle = extractHandle[env]},
    If[ IntegerQ[handle],
        importConstants[handle, names, OptionValue["Environment"]],
        Failure["NoHandle", <|"MessageTemplate" -> "The environment has no native Lean environment.", "MessageParameters" -> {}|>]
    ]
]

(* The cone in dependency order, each constant as TypeTheory declarations, checked in one batch. When the
   batch fails, the declarations are added one at a time to name the constant TypeTheory rejects. A cone
   with Lean's quotient types is imported, by default, under rules that allow their computation rule. *)

importConstants[handle_Integer, roots_List, base_] := catchBridgeFailure @ Block[
    {$kinds = <||>, $universes = <||>, $inductives = <||>, $coreTerms = <||>, $handle = handle, cone, order, baseEnvironment, declarations, environment},
    cone = coneOrder[roots];
    baseEnvironment = Replace[base, Automatic :> If[AnyTrue[cone, quotientConstantQ], TypeTheoryEnvironment[quotientRules[]], TypeTheoryEnvironment[]]];
    order = Select[cone, Function[name, ! KeyExistsQ[baseEnvironment, constantName[name]]]];
    declarations = Catenate[Function[name, importedDeclarations[baseEnvironment, name]] /@ order];
    environment = TypeTheoryEnvironment[baseEnvironment, declarations];
    If[FailureQ[environment], locateFailure[baseEnvironment, order, environment]];
    Scan[Function[name, checkRecursor[environment, name]], Select[order, Function[name, constantKind[name] === "inductive"]]];
    environment
]

importedDeclarations[environment_, name_String] := Join[leanDeclarations[name], quotientComputation[environment, name]]

(* TypeTheory's own failure, introduced by the Lean constant it rejects *)

rejection[name_String, Failure[tag_, data_Association], quotientsQ_] := Failure["RejectedByTypeTheory", Join[data, <|
    "MessageTemplate" -> StringJoin[
        "TypeTheory rejects the Lean constant ", name, ": ", Lookup[data, "MessageTemplate", tag],
        If[quotientsQ, " It depends on Lean's quotient types, whose computation rule needs an environment whose rules allow rewrite rules.", ""]
    ],
    "Constant" -> name,
    "TypeTheoryFailure" -> tag
|>]]

locateFailure[baseEnvironment_, order_List, failure_] := Block[{environment = baseEnvironment},
    Scan[
        Function[name,
            environment = TypeTheoryEnvironment[environment, importedDeclarations[environment, name]];
            If[ FailureQ[environment],
                Throw[rejection[name, environment, AnyTrue[order, quotientConstantQ] && ! rewriteRulesAllowedQ[baseEnvironment]], $bridgeTag]
            ]
        ],
        order
    ];
    Throw[failure, $bridgeTag]
]

(* === Quotients === *)

(* Lean's kernel reduces Quot.lift and Quot.ind applied to Quot.mk, a computation rule it has built in. Under
   rules that allow rewrite rules, TypeTheory has the same rule as two rewrite rules, added after the
   constants they compute with; the names are not Lean names, so they cannot clash with a constant. *)

$quotientRuleNames = {"Quot.lift computes", "Quot.ind computes"}

quotientRules[] := TypeTheoryRules["CalculusOfInductiveConstructions", "RewriteRules" -> True]

quotientConstantQ[name_String] := constantKind[name] === "quot"

rewriteRulesAllowedQ[environment_] := TrueQ[Information[environment, "Rules"]["RewriteRules"]]

quotientComputation[environment_, "Quot.lift"] /; rewriteRulesAllowedQ[environment] := {
    TypeTheoryRewriteRule["Quot.lift computes", ForAll[
        {
            Typed["α", TypeUniverse["u"]], Typed["r", TypeSpecifier[{"α", "α"} -> TypeUniverse[0]]], Typed["β", TypeUniverse["v"]], Typed["f", TypeSpecifier[{"α"} -> "β"]],
            Typed["h", ForAll[{Typed["a", "α"], Typed["b", "α"]}, Implies["r"["a", "b"], Construct[Subscript["Eq", "v"], "β", "f"["a"], "f"["b"]]]]], Typed["a", "α"]
        },
        Construct[Subscript["Quot.lift", "u", "v"], "α", "r", "β", "f", "h", Construct[Subscript["Quot.mk", "u"], "α", "r", "a"]] -> "f"["a"]
    ], "UniverseParameters" -> {"u", "v"}]
}

quotientComputation[environment_, "Quot.ind"] /; rewriteRulesAllowedQ[environment] := {
    TypeTheoryRewriteRule["Quot.ind computes", ForAll[
        {
            Typed["α", TypeUniverse["u"]], Typed["r", TypeSpecifier[{"α", "α"} -> TypeUniverse[0]]], Typed["β", TypeSpecifier[{Construct[Subscript["Quot", "u"], "α", "r"]} -> TypeUniverse[0]]],
            Typed["mk", ForAll[{Typed["a", "α"]}, "β"[Construct[Subscript["Quot.mk", "u"], "α", "r", "a"]]]], Typed["a", "α"]
        },
        Construct[Subscript["Quot.ind", "u"], "α", "r", "β", "mk", Construct[Subscript["Quot.mk", "u"], "α", "r", "a"]] -> "mk"["a"]
    ], "UniverseParameters" -> {"u"}]
}

quotientComputation[_, _String] := {}

(* === The cone === *)

(* Constructors and recursors come with their inductive type; the others come after what they mention.
   The walk is depth first with a stack of its own, since a cone in Mathlib is deeper than the recursion
   limit: an entry {name, False} visits name, and {primary, True} follows its dependencies. *)

coneOrder[roots_List] := Block[{visited = <||>, stack = CreateDataStructure["Stack"], order = CreateDataStructure["DynamicArray"]},
    Scan[Function[root, stack["Push", {root, False}]], Reverse[roots]];
    While[ ! stack["EmptyQ"],
        Replace[stack["Pop"], {
            {primary_, True} :> order["Append", primary],
            {name_, False} :> With[{primary = primaryName[name]},
                If[ ! KeyExistsQ[visited, primary],
                    visited[primary] = True;
                    stack["Push", {primary, True}];
                    Scan[Function[dependency, stack["Push", {dependency, False}]], Reverse[DeleteCases[constantDependencies[primary], Alternatives @@ ownNames[primary]]]]
                ]
            ]
        }]
    ];
    Normal[order]
]

(* the types of a block come with its first type, as their constructors and recursors do *)
primaryName[name_String] := Switch[constantKind[name],
    "constructor", First[inductiveInformation[constructorInductive[name]]["Block"]],
    "recursor", First[inductiveInformation[recursorInductive[name]]["Block"]],
    "inductive", First[inductiveInformation[name]["Block"]],
    _, name
]

(* X.rec, and X.rec_k on the k-th type nested in X's block *)
recursorInductive[name_String] := StringReplace[name, RegularExpression["\\.rec(_\\d+)?$"] -> ""]

(* an inductive type mentions what its constructors mention; Quot.lift and Quot.ind compute on Quot.mk, so
   they come after it, with their computation rule; a string literal is written with the constants that
   Lean's kernel reads it as *)

constantDependencies[name_String] := DeleteDuplicates @ Join[
    If[ constantKind[name] === "inductive",
        Catenate[usedConstants /@ blockMembers[name]],
        usedConstants[name]
    ],
    If[MemberQ[{"Quot.lift", "Quot.ind"}, name], {"Quot.mk"}, {}],
    If[stringLiteralQ[name], $stringLiteralConstants, {}]
]

$stringLiteralConstants = {"String.ofList", "List.cons", "List.nil", "Char.ofNat", "Char"}

(* Lean reports whether a constant has a string literal with the constants it mentions, so a proof of
   millions of nodes is not read just to look; a shim from before LeanLink 1.1.7 does not, and then the
   expressions are read *)
stringLiteralQ[name_String] := AnyTrue[
    If[constantKind[name] === "inductive", blockMembers[name], {name}],
    Function[member, Replace[Lookup[usedInformation[member], "stringLiterals", None], None :> stringLiteralReadQ[member]]]
]

stringLiteralReadQ[name_String] := ! FreeQ[
    Switch[constantKind[name],
        "def" | "theorem", {leanExpression[name, "Type"], leanExpression[name, "Term"]},
        _, {leanExpression[name, "Type"]}
    ],
    _LeanLitStr
]

ownNames[name_String] := If[ constantKind[name] === "inductive",
    Join[blockMembers[name], blockRecursors[name]],
    {name}
]

(* the types declared with an inductive type, and all their constructors *)
blockMembers[name_String] := Join[inductiveInformation[name]["Block"], inductiveInformation[name]["BlockConstructors"]]

(* the recursor of each type of the block, then X.rec_k on each container a type is nested in *)
blockRecursors[name_String] := With[{block = inductiveInformation[name]["Block"]},
    Join[Function[type, type <> ".rec"] /@ block, Table[First[block] <> ".rec_" <> ToString[index], {index, inductiveInformation[name]["Nested"]}]]
]

usedConstants[name_String] := With[{used = usedInformation[name]}, Join[Lookup[used, "type", {}], Lookup[used, "value", {}]]]

usedInformation[name_String] := Replace[Quiet[decodeWXF[$getUsedConstantsFn[$handle, name]]], Except[_Association] -> <||>]

constantKind[name_String] := Lookup[$kinds, name, $kinds[name] = Replace[Quiet[decodeWXF[$getConstantFn[$handle, name]]], {
    LeanConstant[_, kind_String, ___] :> kind,
    _ :> bridgeFailure["UnknownConstant", "Lean has no constant `1`.", {name}]
}]]

$bridgeDepth = 1000000

leanExpression[name_String, field : "Type" | "Term"] := Block[
    {result = Quiet[decodeWXF[If[field === "Type", $getTypeFn, $getValueFn][$handle, name, $bridgeDepth]]]},
    If[ isFFIError[result] || ! FreeQ[result, _LeanTruncated],
        bridgeFailure["LeanExpression", "The `2` of `1` could not be read from Lean.", {name, ToLowerCase[field]}],
        result
    ]
]

constructorInductive[name_String] := Replace[First[leanSpine[Last[forallTelescope[leanExpression[name, "Type"]]]]], {
    LeanConst[inductive_String, _] :> inductive,
    _ :> bridgeFailure["Constructor", "The type of the constructor `1` does not end in its inductive type.", {name}]
}]

(* === Inductive types === *)

(* Lean's recursor X.rec takes the parameters, a motive for each type of X's block, a minor premise for
   each constructor of all of them, the indices and the major premise. It ends in X's motive, and the
   motives come right after the parameters: first those of the types declared together, each taking a term
   of its type applied to exactly the parameters, then those of the containers a type of the block is
   nested in. The minor premises name the constructors in order. *)

inductiveInformation[name_String] := Lookup[$inductives, name, $inductives[name] = readInductiveInformation[name]]

readInductiveInformation[name_String] := Block[
    {typeBinders, recursorBinders, conclusion, motivePosition, numberOfParameters, motiveTypes, block, numberOfMinors, constructors},
    typeBinders = First[forallTelescope[leanExpression[name, "Type"]]];
    {recursorBinders, conclusion} = forallTelescope[leanExpression[name <> ".rec", "Type"]];
    motivePosition = Replace[First[leanSpine[conclusion]], {
        LeanBVar[index_Integer] :> Length[recursorBinders] - index,
        _ :> bridgeFailure["Recursor", "The recursor of `1` does not end in a motive.", {name}]
    }];
    (* the parameters are as many as the motive of X takes X applied to; fewer would fit too *)
    numberOfParameters = Replace[
        SelectFirst[Range[motivePosition - 1, 0, -1], Function[count, blockTypeOfMotive[Last[recursorBinders[[motivePosition]]], count, motivePosition - count] === {name}], None],
        None :> bridgeFailure["Recursor", "The parameters of `1` could not be read from its recursor.", {name}]
    ];
    motiveTypes = Last /@ TakeWhile[Drop[recursorBinders, numberOfParameters], Function[binder, MatchQ[Last[forallTelescope[Last[binder]]], _LeanSort]]];
    block = Catenate[MapIndexed[Function[{motiveType, position}, blockTypeOfMotive[motiveType, numberOfParameters, First[position]]], motiveTypes]];
    numberOfMinors = Length[recursorBinders] - Length[motiveTypes] - Length[typeBinders] - 1;
    constructors = minorConstructor /@ Take[recursorBinders, {numberOfParameters + Length[motiveTypes] + 1, numberOfParameters + Length[motiveTypes] + numberOfMinors}];
    <|
        "Parameters" -> numberOfParameters,
        "Block" -> block,
        "Nested" -> Length[motiveTypes] - Length[block],
        "BlockConstructors" -> Select[constructors, Function[constructor, MemberQ[block, constructorInductive[constructor]]]],
        "Constructors" -> Select[constructors, Function[constructor, constructorInductive[constructor] === name]]
    |>
]

(* {type} when the motive at that position takes a term of a type of the block: one applied to exactly the
   parameters, bound outside the motive and the motives before it, and then the motive's own indices; {}
   for a container, whose parameters mention the block *)
blockTypeOfMotive[motiveType_, numberOfParameters_Integer, position_Integer] := With[
    {binders = First[forallTelescope[motiveType]], numberOfIndices = Length[First[forallTelescope[motiveType]]] - 1},
    Replace[leanSpine[Last[Last[binders]]], {
        {LeanConst[type_String, _], arguments_} /; arguments === Join[
            Table[LeanBVar[numberOfParameters - parameter + position - 1 + numberOfIndices], {parameter, numberOfParameters}],
            Table[LeanBVar[numberOfIndices - index], {index, numberOfIndices}]
        ] :> {type},
        _ :> {}
    }]
]

minorConstructor[{_, minorType_}] := Replace[First[leanSpine[Last[Last[leanSpine[Last[forallTelescope[minorType]]]]]]], {
    LeanConst[constructor_String, _] :> constructor,
    _ :> bridgeFailure["Recursor", "A minor premise of a recursor does not name its constructor.", {}]
}]

forallTelescope[LeanForall[binderName_, type_, body_, _]] := Block[{rest = forallTelescope[body]},
    {Prepend[First[rest], {binderName, type}], Last[rest]}
]

forallTelescope[expression_] := {{}, expression}

leanSpine[LeanApp[function_, argument_]] := Block[{spine = leanSpine[function]}, {First[spine], Append[Last[spine], argument]}]

leanSpine[expression_] := {expression, {}}

(* === Universe parameters === *)

(* Lean reports a constant's universe parameters with the constants it mentions; a shim before LeanLink 1.1.7
   does not, and then they are read off the constant's type, which misses one that does not occur in it *)
universeParameters[name_String] := Lookup[$universes, name, $universes[name] = Replace[Lookup[usedInformation[name], "levelParams", None], None :> readUniverseParameters[name]]]

readUniverseParameters[name_String] := Block[{count, raw, instantiated, pairs, mapping},
    count = SelectFirst[Range[0, 8], Function[n, AssociationQ[typeCheck[LeanConst[name, placeholderLevels[n]], $handle]]], None];
    raw = Cases[fetchField[$handle, name, "Type"], LeanLevelParam[parameter_] :> parameter, Infinity];
    (* a shim before LeanLink 1.1.6 cannot type-check a constant whose type Lean fails to print, such as
       Fin.isLt; a single parameter, or none, is then the one in the type *)
    If[ count === None && Length[DeleteDuplicates[raw]] <= 1,
        Return[DeleteDuplicates[raw], Block]
    ];
    If[ count === None,
        bridgeFailure["UniverseParameters", "The universe parameters of `1` could not be read from Lean: `2`", {name, typeCheckError[LeanConst[name, placeholderLevels[Length[DeleteDuplicates[raw]]]]]}]
    ];
    If[ count === 0,
        {},
        instantiated = Cases[typeCheck[LeanConst[name, placeholderLevels[count]], $handle]["Type"], LeanLevelParam[parameter_] :> parameter, Infinity];
        If[Length[raw] =!= Length[instantiated], bridgeFailure["UniverseParameters", "The universe parameters of `1` could not be matched up.", {name}]];
        mapping = Association[Function[pair, Last[pair] -> First[pair]] /@ DeleteDuplicates[Transpose[{raw, instantiated}]]];
        Function[placeholder,
            Lookup[mapping, placeholder, bridgeFailure["UniverseParameters", "A universe parameter of `1` does not occur in its type.", {name}]]
        ] /@ placeholderNames[count]
    ]
]

(* what Lean's type check says when it does not give a type *)
typeCheckError[expression_] := Replace[Quiet[decodeWXF[$typeCheckFn[$handle, Normal[BinarySerialize[expression]]]]], {message_String :> message, other_ :> ToString[Short[other]]}]

(* placeholders must be Lean names, and distinct, or Lean merges them *)

placeholderNames[n_Integer] := Table["typeTheoryLevel" <> ToString[i], {i, 0, n - 1}]

placeholderLevels[n_Integer] := LeanLevelParam /@ placeholderNames[n]

(* === Declarations === *)

constantName[name_String] := If[constantKind[name] === "recursor", recursorConstantName[name], name]

recursorConstantName[name_String] := Replace[StringCases[name, RegularExpression["^(.*)\\.rec_(\\d+)$"] :> {"$1", "$2"}], {
    {{type_, index_}} :> InductiveRecursor[type, ToExpression[index]],
    _ :> InductiveRecursor[StringDrop[name, -4]]
}]

leanDeclarations[name_String] := Block[{$currentConstant = name, universes = universeParameters[name]},
    Switch[constantKind[name],
        "inductive",
            inductiveDeclarations[name, universes],
        "def",
            With[{value = declarationTerm[leanExpression[name, "Term"]], type = declarationTerm[leanExpression[name, "Type"]], levels = universes},
                Prepend[natOperationRegistration[name], TypeTheoryDefinition[name, Typed[value, type], "UniverseParameters" -> levels]]
            ],
        "theorem",
            With[{statement = declarationTerm[leanExpression[name, "Type"]], proof = declarationTerm[leanExpression[name, "Term"]], levels = universes},
                {TypeTheoryTheorem[name, statement, proof, "UniverseParameters" -> levels]}
            ],
        (* an opaque constant's value never unfolds, and a quotient's computation rule is not in TypeTheory yet *)
        "axiom" | "opaque" | "quot",
            With[{type = declarationTerm[leanExpression[name, "Type"]], levels = universes}, {TypeTheoryAxiom[name, type, "UniverseParameters" -> levels]}],
        _,
            bridgeFailure["UnsupportedConstant", "`1` is a `2`, which the bridge cannot translate.", {name, constantKind[name]}]
    ]
]

(* the natural numbers of Lean become TypeTheory's natural numbers, so literals mean the same *)

inductiveDeclarations[name_String, universes_List] := Block[{information = inductiveInformation[name]},
    With[
        {
            types = Function[type, type -> declarationTerm[leanExpression[type, "Type"]]] /@ information["Block"],
            constructors = Function[constructor, constructor -> declarationTerm[leanExpression[constructor, "Type"]]] /@ information["BlockConstructors"],
            parameters = information["Parameters"]
        },
        Join[
            (* a type nested in a container is declared alone: TypeTheory finds the nesting as Lean's kernel does *)
            If[ Length[types] == 1,
                With[{type = Last[First[types]]}, {TypeTheoryInductiveType[name, type, constructors, "Parameters" -> parameters, "UniverseParameters" -> universes]}],
                {TypeTheoryInductiveType[types, constructors, "Parameters" -> parameters, "UniverseParameters" -> universes]}
            ],
            If[name === "Nat" && information["BlockConstructors"] === {"Nat.zero", "Nat.succ"}, {TypeTheoryNaturalNumbers["Nat", "Nat.zero", "Nat.succ"]}, {}]
        ]
    ]
]

(* Lean's kernel computes these operations on literals with GMP. Registered right after its definition,
   each computes on literals in TypeTheory too, with integers, from TypeTheory 0.10 on. *)

$leanNatOperations = <|
    "Nat.add" -> "Addition",
    "Nat.sub" -> "Subtraction",
    "Nat.mul" -> "Multiplication",
    "Nat.pow" -> "Power",
    "Nat.div" -> "Quotient",
    "Nat.mod" -> "Remainder",
    "Nat.gcd" -> "GCD",
    "Nat.log2" -> "Log2",
    "Nat.land" -> "BitAnd",
    "Nat.lor" -> "BitOr",
    "Nat.xor" -> "BitXor",
    "Nat.shiftLeft" -> "ShiftLeft",
    "Nat.shiftRight" -> "ShiftRight",
    "Nat.beq" -> "Equal",
    "Nat.ble" -> "LessEqual"
|>

natOperationRegistration[name_String] := If[ KeyExistsQ[$leanNatOperations, name] && natOperationsQ[],
    With[{role = $leanNatOperations[name]}, {TypeTheoryNaturalNumbers["Nat", "Nat.zero", "Nat.succ", Association[role -> name]]}],
    {}
]

natOperationsQ[] := natOperationsQ[] = MatchQ[Information[TypeTheoryEnvironment["Prelude"], "NaturalNumbers"], KeyValuePattern["Operations" -> _Association]]

(* the recursor TypeTheory generated must have Lean's type, compared at the same placeholder levels *)

checkRecursor[environment_, name_String] := Scan[Function[recursor, checkRecursorType[environment, name, recursor]], blockRecursors[name]]

checkRecursorType[environment_, name_String, recursor_String] := Block[
    {levels, leanType},
    levels = placeholderLevels[Length[universeParameters[recursor]]];
    leanType = Replace[typeCheck[LeanConst[recursor, levels], $handle], {
        result_Association :> result["Type"],
        _ :> bridgeFailure["Recursor", "Lean's type check of `1` failed: `2`", {recursor, typeCheckError[LeanConst[recursor, levels]]}]
    }];
    With[
        {
            ours = TypeTheoryTerm @@ Append[heldSurface[surfaceConstruct[constantSurface[LeanConst[recursor, levels]]]], environment],
            theirs = TypeTheoryTerm @@ heldSurface[leanSurface[leanType, {}]]
        },
        (* TypeTheory 0.8 gives a Success where earlier versions gave True *)
        If[ ! MatchQ[TypeTheoryCheck[ours, theirs], True | _Success],
            bridgeFailure["RecursorMismatch", "The recursor TypeTheory generates for `1` does not have the type of Lean's `2`.", {name, recursor}]
        ]
    ]
]

(* === Terms === *)

(* A Lean expression as a TypeTheory term, built with inert stand-ins for the built-in heads, which would
   evaluate, and turned into the real heads inside HoldComplete. Bound variables get their Lean names,
   cleaned of hygiene and made distinct from the names in scope and from the constants. *)

leanTerm[expression_] := TypeTheoryTerm @@ heldSurface[leanSurface[expression, {}]]

(* === Core terms === *)

(* Lean's terms and TypeTheory's core terms both number bound variables from the innermost binder, so a
   Lean term goes into a declaration as a core term, with no names to choose and each distinct subterm
   translated once: a proof that a tactic writes shares its subterms thousands of times over, and the core
   term shares them as Lean's does. TypeTheory 0.11 takes a core term in a declaration as it is, and its
   kernel checks the declaration; with an earlier TypeTheory, the declaration gets the term's surface
   syntax. *)

declarationTerm[expression_] := If[coreTermsQ[], leanCore[expression], leanTerm[expression]]

coreTermsQ[] := coreTermsQ[] = With[{type = coreHead["universeSort"][1]},
    ! FailureQ[Quiet[TypeTheoryEnvironment[TypeTheoryEnvironment[], {TypeTheoryAxiom["coreTermsProbe", type]}]]]
]

coreHead[name_String] := coreHead[name] = Symbol["WolframInstitute`TypeTheory`PackageScope`" <> name]

(* each distinct subterm once, for the length of an import *)
leanCore[expression_] := If[ AssociationQ[$coreTerms],
    Lookup[$coreTerms, Key[expression], $coreTerms[expression] = leanCoreNode[expression]],
    Block[{$coreTerms = <||>}, leanCore[expression]]
]

$coreTerms = None

leanCoreNode[LeanBVar[index_Integer]] := coreHead["boundVariable"][index]

leanCoreNode[LeanSort[level_]] := coreHead["universeSort"][coreLevel[level]]

leanCoreNode[LeanConst[name_String, levels_List]] := coreHead["constantReference"][HoldComplete @@ {constantName[name]}, coreLevel /@ levels]

leanCoreNode[LeanApp[function_, argument_]] := coreHead["application"][leanCore[function], leanCore[argument]]

leanCoreNode[LeanLam[binderName_String, type_, body_, binder_String]] := coreHead["lambdaAbstraction"][HoldComplete @@ {cleanBinderName[binderName]}, leanCore[type], leanCore[body], coreBinder[binder]]

leanCoreNode[LeanForall[binderName_String, type_, body_, binder_String]] := coreHead["dependentFunctionType"][HoldComplete @@ {cleanBinderName[binderName]}, leanCore[type], leanCore[body], coreBinder[binder]]

leanCoreNode[LeanLet[binderName_String, type_, value_, body_]] := coreHead["localDefinition"][HoldComplete @@ {cleanBinderName[binderName]}, leanCore[type], leanCore[value], leanCore[body]]

leanCoreNode[LeanLitNat[n_Integer]] := coreHead["naturalLiteral"][n]

leanCoreNode[LeanProj[structure_String, index_Integer, term_]] := coreHead["projection"][HoldComplete @@ {constantName[structure]}, index, leanCore[term]]

(* a string literal is String.ofList of its characters, as in the surface syntax below *)
leanCoreNode[LeanLitStr[string_String]] := With[{application = coreHead["application"], char = coreConstant["Char"]},
    application[coreConstant["String.ofList"], Fold[
        Function[{list, code}, application[application[application[coreHead["constantReference"][HoldComplete["List.cons"], {0}], char], application[coreConstant["Char.ofNat"], coreHead["naturalLiteral"][code]]], list]],
        application[coreHead["constantReference"][HoldComplete["List.nil"], {0}], char],
        Reverse[ToCharacterCode[string]]
    ]]
]

leanCoreNode[other_] := bridgeFailure["UnsupportedExpression", "`1` contains `2`, which the bridge cannot translate.", {$currentConstant, Short[other]}]

coreConstant[name_String] := coreHead["constantReference"][HoldComplete[name], {}]

coreBinder[binder_String] := Replace[binder, {"default" -> "Explicit", "implicit" -> "Implicit", "instImplicit" -> "InstanceImplicit", "strictImplicit" -> "StrictImplicit", _ -> "Implicit"}]

coreLevel[LeanLevelZero[]] := 0

coreLevel[LeanLevelSucc[level_]] := coreHead["normalizeLevel"][coreHead["levelSuccessor"][coreLevel[level], 1]]

coreLevel[LeanLevelMax[first_, second_]] := coreHead["normalizeLevel"][coreHead["levelMaximum"][coreLevel[first], coreLevel[second]]]

coreLevel[LeanLevelIMax[first_, second_]] := coreHead["normalizeLevel"][coreHead["levelImpredicativeMaximum"][coreLevel[first], coreLevel[second]]]

coreLevel[LeanLevelParam[name_String]] := coreHead["levelParameter"][HoldComplete[name]]

heldSurface[surface_] := ReplaceAll[HoldComplete @@ {surface}, $surfaceHeads]

$surfaceHeads = {
    surfaceForAll -> ForAll,
    surfaceFunction -> Function,
    surfaceTyped -> Typed,
    surfaceAnnotation -> Annotation,
    surfaceConstruct -> Construct,
    surfaceSubscript -> Subscript,
    surfaceUniverse -> TypeUniverse,
    surfacePlus -> Plus,
    surfaceMax -> Max,
    surfaceImpredicativeMaximum -> ImpredicativeMaximum,
    surfaceWith -> With,
    surfaceSet -> Set,
    surfacePart -> Part
}

leanSurface[LeanBVar[index_Integer], scope_List] := First[Drop[scope, index]]

leanSurface[LeanSort[level_], _] := surfaceUniverse[levelSurface[level]]

leanSurface[constant : LeanConst[_, _], _] := surfaceConstruct[constantSurface[constant]]

leanSurface[application : LeanApp[_, _], scope_List] := Block[{spine = leanSpine[application]},
    surfaceConstruct @@ Prepend[Function[argument, leanSurface[argument, scope]] /@ Last[spine], headSurface[First[spine], scope]]
]

leanSurface[LeanLam[binderName_String, type_, body_, binder_String], scope_List] := Block[{name = freshBinderName[binderName, scope]},
    surfaceFunction[{binderSurface[name, leanSurface[type, scope], binder]}, leanSurface[body, Prepend[scope, name]]]
]

leanSurface[LeanForall[binderName_String, type_, body_, binder_String], scope_List] := Block[{name = freshBinderName[binderName, scope]},
    surfaceForAll[{binderSurface[name, leanSurface[type, scope], binder]}, leanSurface[body, Prepend[scope, name]]]
]

leanSurface[LeanLet[binderName_String, type_, value_, body_], scope_List] := Block[{name = freshBinderName[binderName, scope]},
    surfaceWith[{surfaceSet[name, surfaceTyped[leanSurface[value, scope], leanSurface[type, scope]]]}, leanSurface[body, Prepend[scope, name]]]
]

leanSurface[LeanLitNat[n_Integer], _] := n

leanSurface[LeanProj[_, index_Integer, structure_], scope_List] := surfacePart[leanSurface[structure, scope], index + 1]

(* Lean's kernel reads a string literal as String.ofList applied to the list of its characters, each
   Char.ofNat of its code point, so it is written that way; the list is built from its end *)
leanSurface[LeanLitStr[string_String], _] := surfaceConstruct["String.ofList", Fold[
    Function[{list, code}, surfaceConstruct[surfaceSubscript["List.cons", 0], "Char", surfaceConstruct["Char.ofNat", code], list]],
    surfaceConstruct[surfaceSubscript["List.nil", 0], "Char"],
    Reverse[ToCharacterCode[string]]
]]

leanSurface[other_, _] := bridgeFailure["UnsupportedExpression", "`1` contains `2`, which the bridge cannot translate.", {$currentConstant, Short[other]}]

headSurface[constant : LeanConst[_, _], _] := constantSurface[constant]

headSurface[other_, scope_List] := leanSurface[other, scope]

constantSurface[LeanConst[name_String, {}]] := constantName[name]

constantSurface[LeanConst[name_String, levels_List]] := surfaceSubscript @@ Prepend[levelSurface /@ levels, constantName[name]]

binderSurface[name_String, type_, "default"] := surfaceTyped[name, type]

binderSurface[name_String, type_, binder_String] := surfaceAnnotation[surfaceTyped[name, type], Replace[binder, {"implicit" -> "Implicit", "instImplicit" -> "InstanceImplicit", "strictImplicit" -> "StrictImplicit", _ -> "Implicit"}]]

levelSurface[LeanLevelZero[]] := 0

levelSurface[LeanLevelSucc[level_]] := Replace[levelSurface[level], {n_Integer :> n + 1, other_ :> surfacePlus[other, 1]}]

levelSurface[LeanLevelMax[first_, second_]] := surfaceMax[levelSurface[first], levelSurface[second]]

levelSurface[LeanLevelIMax[first_, second_]] := surfaceImpredicativeMaximum[levelSurface[first], levelSurface[second]]

levelSurface[LeanLevelParam[name_String]] := name

freshBinderName[binderName_String, scope_List] := Block[{base = cleanBinderName[binderName]},
    If[ freeBinderNameQ[base, scope],
        base,
        First[Select[Table[base <> ToString[i], {i, 1, Length[scope] + 2}], Function[candidate, freeBinderNameQ[candidate, scope]]]]
    ]
]

freeBinderNameQ[name_String, scope_List] := ! MemberQ[scope, name] && ! KeyExistsQ[$kinds, name]

cleanBinderName[binderName_String] := Replace[First[StringSplit[binderName, "._@."], binderName], "" | "_" -> "x"]

(* ============================================================================ *)

(* To Lean                                                                      *)

(* ============================================================================ *)

(* TypeTheory's prelude constants that Lean has in Init, with the same definitions, except Plus, which
   becomes Nat.add: they compute the same on constructors, so a proof that does not depend on how Plus
   is defined checks in Lean too. The prelude's axioms are Lean's, with the same types; Lean proves
   funext from quotients. *)

$preludeLeanNames = <|
    HoldComplete[True] -> "True",
    HoldComplete[TrueIntroduction] -> "True.intro",
    HoldComplete[InductiveRecursor[True]] -> "True.rec",
    HoldComplete[False] -> "False",
    HoldComplete[InductiveRecursor[False]] -> "False.rec",
    HoldComplete[Not] -> "Not",
    HoldComplete[And] -> "And",
    HoldComplete[AndIntroduction] -> "And.intro",
    HoldComplete[InductiveRecursor[And]] -> "And.rec",
    HoldComplete[Or] -> "Or",
    HoldComplete[OrIntroductionLeft] -> "Or.inl",
    HoldComplete[OrIntroductionRight] -> "Or.inr",
    HoldComplete[InductiveRecursor[Or]] -> "Or.rec",
    HoldComplete[Equivalent] -> "Iff",
    HoldComplete[EquivalentIntroduction] -> "Iff.intro",
    HoldComplete[InductiveRecursor[Equivalent]] -> "Iff.rec",
    HoldComplete[Equal] -> "Eq",
    HoldComplete[EqualityReflexivity] -> "Eq.refl",
    HoldComplete[InductiveRecursor[Equal]] -> "Eq.rec",
    HoldComplete[Exists] -> "Exists",
    HoldComplete[ExistsIntroduction] -> "Exists.intro",
    HoldComplete[InductiveRecursor[Exists]] -> "Exists.rec",
    HoldComplete[NonNegativeIntegers] -> "Nat",
    HoldComplete[NaturalNumberZero] -> "Nat.zero",
    HoldComplete[NaturalNumberSuccessor] -> "Nat.succ",
    HoldComplete[InductiveRecursor[NonNegativeIntegers]] -> "Nat.rec",
    HoldComplete[Plus] -> "Nat.add",
    HoldComplete[Booleans] -> "Bool",
    HoldComplete["false"] -> "Bool.false",
    HoldComplete["true"] -> "Bool.true",
    HoldComplete[InductiveRecursor[Booleans]] -> "Bool.rec",
    HoldComplete["not"] -> "Bool.not",
    HoldComplete["and"] -> "Bool.and",
    HoldComplete["or"] -> "Bool.or",
    (* the names the Booleans' constants had before TypeTheory 0.9 *)
    HoldComplete[BooleanFalse] -> "Bool.false",
    HoldComplete[BooleanTrue] -> "Bool.true",
    HoldComplete[BooleanNot] -> "Bool.not",
    HoldComplete[BooleanAnd] -> "Bool.and",
    HoldComplete[BooleanOr] -> "Bool.or",
    HoldComplete[Nonempty] -> "Nonempty",
    HoldComplete[NonemptyIntroduction] -> "Nonempty.intro",
    HoldComplete[InductiveRecursor[Nonempty]] -> "Nonempty.rec",
    HoldComplete[Subtype] -> "Subtype",
    HoldComplete[SubtypeIntroduction] -> "Subtype.mk",
    HoldComplete[InductiveRecursor[Subtype]] -> "Subtype.rec",
    HoldComplete[PropositionalExtensionality] -> "propext",
    HoldComplete[FunctionExtensionality] -> "funext",
    HoldComplete[Choice] -> "Classical.choice"
|>

$leanKeywords = {
    "fun", "let", "have", "show", "from", "at", "by", "do", "then", "else", "if", "match", "with", "Type", "Prop", "Sort",
    "theorem", "def", "axiom", "inductive", "where", "in", "end", "namespace", "open", "forall", "exists", "structure",
    "class", "instance", "variable", "universe", "section", "mutual", "deriving", "calc", "suffices", "this"
}

TypeTheoryToLean[environment_TypeTheoryEnvironment, name : Except[_List], opts : OptionsPattern[]] := TypeTheoryToLean[environment, {name}, opts]

TypeTheoryToLean[environment_TypeTheoryEnvironment, names_List, opts : OptionsPattern[]] := catchBridgeFailure @ Block[
    {declarations = Normal[environment], prelude = TypeTheoryEnvironment["Prelude"], $environment = environment, $declarationIndex, $constructorOwners, $blockOwners, needed},
    checkLeanRules[environment];
    If[FailureQ[declarations], Throw[declarations, $bridgeTag]];
    $declarationIndex = Association[Function[declaration, declarationKey[declaration] -> declaration] /@ declarations];
    $constructorOwners = Association[Catenate[constructorOwners /@ declarations]];
    $blockOwners = Association[Catenate[blockOwners /@ declarations]];
    Scan[Function[name, If[! KeyExistsQ[environment, name], bridgeFailure["UnknownConstant", "`1` is not declared in the environment.", {name}]]], names];
    needed = exportOrder[Function[name, ownerKey[HoldComplete[name]]] /@ names];
    (* a prelude constant is written as Lean's only if it is the prelude's own *)
    Scan[
        Function[key, If[ environment @@ key =!= prelude @@ key, bridgeFailure["PreludeChanged", "`1` is not the prelude's, so it cannot be written as Lean's.", {HoldForm @@ key}]]],
        Select[DeleteDuplicates[Catenate[Function[key, mentionedConstants[$declarationIndex[key]]] /@ needed]], Function[key, KeyExistsQ[$preludeLeanNames, ownerKey[key]] && FreeQ[key, InductiveRecursor]]]
    ];
    StringRiffle[
        Join[
            {"-- Generated by LeanLink's TypeTheoryToLean: TypeTheory declarations, for Lean's kernel to check."},
            Function[key, declarationText[$declarationIndex[key]]] /@ needed
        ],
        "\n\n"
    ] <> "\n"
]

(* Lean's kernel follows the calculus of inductive constructions, TypeTheory's rules with Prop. Without Prop
   a recursor eliminates a universe above Lean's and a theorem may state a type, and Lean has no rewrite
   rules, so the computation an environment's rewrite rules give would be lost; only the quotient rules the
   import adds are Lean's own. *)

checkLeanRules[environment_TypeTheoryEnvironment] := Block[
    {rules = Information[environment, "Rules"], rewriteRules = DeleteCases[Information[environment, "RewriteRules"], Alternatives @@ $quotientRuleNames]},
    If[ rules["Prop"] === False, bridgeFailure["UnsupportedRules", "The environment follows the rules `1`, which have no Prop, and Lean's kernel follows the calculus of inductive constructions.", {rules["Name"]}]];
    If[ MatchQ[rewriteRules, {__}], bridgeFailure["UnsupportedRules", "The environment has the rewrite rules `1`, which Lean's kernel does not have.", {rewriteRules}]]
]

(* the name a declaration introduces, held, the first type's for a block of mutually inductive types; an
   inductive type's constructors and recursors belong to it, and the other types of its block to the first *)

declarationKey[declaration_] := Replace[declaration, {
    TypeTheoryInductiveType[{(Rule | RuleDelayed)[first_, _], ___}, _List, ___] :> HoldComplete[first],
    (TypeTheoryAxiom | TypeTheoryDefinition | TypeTheoryTheorem | TypeTheoryInductiveType)[name_, ___] :> HoldComplete[name]
}]

declarationKey[declaration_TypeTheoryNaturalNumbers] := None

constructorOwners[TypeTheoryInductiveType[types : {(_Rule | _RuleDelayed) ..}, {constructors___}, ___]] := With[
    {names = Cases[HoldComplete @@ {types}, (Rule | RuleDelayed)[name_, _] :> HoldComplete[name], {2}]},
    Join[
        Cases[HoldComplete[constructors], (Rule | RuleDelayed)[constructor_, constructorType_] :> (HoldComplete[constructor] -> resultHead[HoldComplete[constructorType]])],
        Function[name, Replace[name, HoldComplete[type_] :> (HoldComplete[InductiveRecursor[type]] -> name)]] /@ names
    ]
]

constructorOwners[TypeTheoryInductiveType[name_, _, {constructors___}, ___]] := Join[
    Cases[HoldComplete[constructors], (Rule | RuleDelayed)[constructor_, _] :> (HoldComplete[constructor] -> HoldComplete[name])],
    {HoldComplete[InductiveRecursor[name]] -> HoldComplete[name]}
]

constructorOwners[_] := {}

blockOwners[TypeTheoryInductiveType[types : {(_Rule | _RuleDelayed) ..}, _List, ___]] := With[
    {names = Cases[HoldComplete @@ {types}, (Rule | RuleDelayed)[name_, _] :> HoldComplete[name], {2}]},
    Function[name, name -> First[names]] /@ Rest[names]
]

blockOwners[_] := {}

(* the type a constructor's type ends in *)
resultHead[HoldComplete[(ForAll | Function)[_, body_]]] := resultHead[HoldComplete[body]]
resultHead[HoldComplete[Implies[_, codomain_]]] := resultHead[HoldComplete[codomain]]
resultHead[HoldComplete[TypeSpecifier[_ -> codomain_]]] := resultHead[HoldComplete[codomain]]
resultHead[HoldComplete[Construct[head_, ___]]] := resultHead[HoldComplete[head]]
resultHead[HoldComplete[Subscript[head_, ___]]] := HoldComplete[head]
resultHead[HoldComplete[head_[___]]] := HoldComplete[head]
resultHead[HoldComplete[head_]] := HoldComplete[head]

(* the recursor on a type nested in X's block, InductiveRecursor[X, k], belongs where X's does *)
ownerKey[key_HoldComplete] := With[
    {owner = Lookup[$constructorOwners, Replace[key, HoldComplete[InductiveRecursor[type_, _Integer]] :> HoldComplete[InductiveRecursor[type]]], key]},
    Lookup[$blockOwners, owner, owner]
]

(* a constant is Lean's own when it came from Lean, as a string name, or is a prelude constant Lean has *)

leanSideQ[key_HoldComplete] := MatchQ[key, HoldComplete[_String] | HoldComplete[InductiveRecursor[_String] | InductiveRecursor[_String, _Integer]]] || KeyExistsQ[$preludeLeanNames, key]

exportOrder[roots_List] := Block[{$visited = <||>},
    Flatten[Last[Reap[Scan[visitDeclaration, roots], $exportTag]]]
]

visitDeclaration[key_HoldComplete] := Block[{owner = ownerKey[key]},
    If[ ! leanSideQ[owner] && ! KeyExistsQ[$visited, owner] && KeyExistsQ[$declarationIndex, owner],
        $visited[owner] = True;
        Scan[visitDeclaration, DeleteCases[mentionedConstants[$declarationIndex[owner]], owner]];
        Sow[owner, $exportTag]
    ]
]

mentionedConstants[declaration_] := DeleteDuplicates[Cases[
    declaration,
    name : (_Symbol | _String | InductiveRecursor[_] | InductiveRecursor[_, _Integer]) /; KeyExistsQ[$environment, name] :> ownerKey[HoldComplete[name]],
    {0, Infinity},
    Heads -> True
]]

(* === Lean names === *)

leanName[key_HoldComplete] := Which[
    KeyExistsQ[$preludeLeanNames, key],
        $preludeLeanNames[key],
    MatchQ[key, HoldComplete[_String]],
        First[key],
    MatchQ[key, HoldComplete[InductiveRecursor[_]]],
        leanName[Replace[key, HoldComplete[InductiveRecursor[inductive_]] :> HoldComplete[inductive]]] <> ".rec",
    MatchQ[key, HoldComplete[InductiveRecursor[_, _Integer]]],
        Replace[key, HoldComplete[InductiveRecursor[inductive_, index_]] :> leanName[HoldComplete[inductive]] <> ".rec_" <> ToString[index]],
    KeyExistsQ[$constructorOwners, key],
        leanName[$constructorOwners[key]] <> "." <> identifierBase[key],
    True,
        "TypeTheory." <> identifierBase[key]
]

$formalLetters = Association[Join[
    Table[ToExpression["HoldComplete[\\[Formal" <> letter <> "]]"] -> ToLowerCase[letter], {letter, CharacterRange["A", "Z"]}],
    Table[ToExpression["HoldComplete[\\[FormalCapital" <> letter <> "]]"] -> letter, {letter, CharacterRange["A", "Z"]}],
    Table[ToExpression["HoldComplete[\\[Formal" <> greek <> "]]"] -> ToLowerCase[ToExpression["\"\\[" <> greek <> "]\""]], {greek, {"Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Lambda", "Mu", "Sigma", "Tau", "Phi", "Psi", "Omega"}}]
]]

identifierBase[key_HoldComplete] := Block[{text = Replace[key, {held_ /; KeyExistsQ[$formalLetters, held] :> $formalLetters[held], HoldComplete[symbol_Symbol] :> SymbolName[Unevaluated[symbol]], HoldComplete[name_String] :> name, _ :> "x"}]},
    Replace[StringReplace[text, Except[WordCharacter | "_" | "'" | "."] -> "_"], {"" -> "x", word_ /; DigitQ[StringTake[word, 1]] :> "x" <> word}]
]

(* a binder's identifier: its own name, unless the scope or Lean's keywords already have it *)

freshIdentifier[key_HoldComplete, scope_Association] := Block[{base = StringReplace[identifierBase[key], "." -> "_"]},
    First[Select[Prepend[Table[base <> ToString[i], {i, 1, Length[scope] + 2}], base], Function[candidate, ! MemberQ[Values[scope], candidate] && ! MemberQ[$leanKeywords, candidate]]]]
]

(* === Declarations as Lean source === *)

declarationText[TypeTheoryAxiom[name_, type_, options___]] := Block[{$universeNames = universeNames[HoldComplete[options]]},
    "axiom " <> leanName[HoldComplete[name]] <> universeSuffix[] <> " : " <> leanText[type, <||>]
]

declarationText[TypeTheoryDefinition[name_, Typed[value_, type_], options___]] := Block[{$universeNames = universeNames[HoldComplete[options]]},
    "noncomputable def " <> leanName[HoldComplete[name]] <> universeSuffix[] <> " : " <> leanText[type, <||>] <> " :=\n  " <> leanText[value, <||>]
]

declarationText[TypeTheoryTheorem[name_, statement_, proof_, options___]] := Block[{$universeNames = universeNames[HoldComplete[options]]},
    "theorem " <> leanName[HoldComplete[name]] <> universeSuffix[] <> " : " <> leanText[statement, <||>] <> " :=\n  " <> leanText[proof, <||>]
]

(* in its constructors' types the inductive type is a local of Lean's, named without universe levels, as
   every type of a mutual block is in all of its constructors *)

declarationText[TypeTheoryInductiveType[types : {(_Rule | _RuleDelayed) ..}, {constructors___}, options___]] := Block[
    {
        $universeNames = universeNames[HoldComplete[options]],
        $declaredInductive = Cases[HoldComplete @@ {types}, (Rule | RuleDelayed)[name_, _] :> HoldComplete[name], {2}],
        owned = Cases[HoldComplete[constructors], (Rule | RuleDelayed)[constructor_, constructorType_] :> {HoldComplete[constructor], HoldComplete[constructorType]}]
    },
    "mutual\n" <> StringRiffle[
        Cases[HoldComplete @@ {types}, (Rule | RuleDelayed)[name_, type_] :> inductiveText[
            HoldComplete[name],
            HoldComplete[type],
            Select[owned, Function[constructor, resultHead[Last[constructor]] === HoldComplete[name]]]
        ], {2}],
        "\n"
    ] <> "\nend"
]

declarationText[TypeTheoryInductiveType[name_, type_, {constructors___}, options___]] := Block[
    {$universeNames = universeNames[HoldComplete[options]], $declaredInductive = {HoldComplete[name]}},
    inductiveText[
        HoldComplete[name],
        HoldComplete[type],
        Cases[HoldComplete[constructors], (Rule | RuleDelayed)[constructor_, constructorType_] :> {HoldComplete[constructor], HoldComplete[constructorType]}]
    ]
]

inductiveText[name_HoldComplete, type_HoldComplete, constructors_List] :=
    "inductive " <> leanName[name] <> universeSuffix[] <> " : " <> heldLeanText[type, <||>] <> " where" <> StringJoin[
        Function[constructor, "\n  | " <> identifierBase[First[constructor]] <> " : " <> heldLeanText[Last[constructor], <||>]] /@ constructors
    ]

declarationText[other_] := bridgeFailure["UnsupportedDeclaration", "`1` cannot be written as Lean source.", {Short[other]}]

universeNames[HoldComplete[options___]] := Association[Function[parameter, parameter -> identifierBase[parameter]] /@ Catenate[Cases[
    HoldComplete[options],
    (Rule | RuleDelayed)["UniverseParameters", {parameters___}] :> (HoldComplete /@ Unevaluated[{parameters}])
]]]

universeSuffix[] := If[Length[$universeNames] === 0, "", ".{" <> StringRiffle[Values[$universeNames], ", "] <> "}"]

(* === Terms as Lean source === *)

(* Every application is written with @, so Lean fills in no argument, whatever its binders are. *)

SetAttributes[leanText, HoldFirst]

leanText[ForAll[{binders___}, body_], scope_Association] := binderChain[HoldComplete /@ Unevaluated[{binders}], HoldComplete[body], scope, " -> ", "", "->"]

(* @fun, so that Lean does not put implicit lambdas in front of it: a recursor Lean makes for an inductive
   type written here takes the binders of its constructors, implicit ones included, where TypeTheory's takes
   them explicit, and the two differ only in what Lean's elaborator, not its kernel, reads *)

leanText[Function[{binders___}, body_], scope_Association] := binderChain[HoldComplete /@ Unevaluated[{binders}], HoldComplete[body], scope, " ", "@fun ", "=>"]

leanText[Implies[domain_, codomain_], scope_Association] := "(" <> leanText[domain, scope] <> " -> " <> leanText[codomain, scope] <> ")"

leanText[TypeSpecifier[{domains___} -> codomain_], scope_Association] := "(" <> StringJoin[Function[domain, heldLeanText[domain, scope] <> " -> "] /@ (HoldComplete /@ Unevaluated[{domains}])] <> leanText[codomain, scope] <> ")"

leanText[Typed[term_, type_], scope_Association] := "(" <> leanText[term, scope] <> " : " <> leanText[type, scope] <> ")"

leanText[With[{Set[name_, value_]}, body_], scope_Association] := Block[{identifier = freshIdentifier[HoldComplete[name], scope]},
    "(let " <> identifier <> " := " <> leanText[value, scope] <> "; " <> leanText[body, Append[scope, HoldComplete[name] -> identifier]] <> ")"
]

leanText[Part[structure_, index_Integer], scope_Association] := "(" <> leanText[structure, scope] <> ")." <> ToString[index]

leanText[TypeUniverse[level_], scope_Association] := Replace[levelText[level], {"0" -> "Prop", "1" -> "Type", other_ :> "Sort (" <> other <> ")"}]

leanText[n_Integer, scope_Association] := "(" <> ToString[n] <> " : Nat)"

leanText[Construct[head_, arguments___], scope_Association] := applicationText[HoldComplete[head], HoldComplete /@ Unevaluated[{arguments}], scope]

leanText[Subscript[constant_, levels___], scope_Association] := "@" <> leanName[HoldComplete[constant]] <> constantLevelSuffix[HoldComplete[constant], HoldComplete /@ Unevaluated[{levels}]]

leanText[InductiveRecursor[inductive_], scope_Association] := "@" <> leanName[HoldComplete[InductiveRecursor[inductive]]]

leanText[name : (_Symbol | _String), scope_Association] := Lookup[scope, HoldComplete[name], "@" <> leanName[HoldComplete[name]]]

leanText[head_[arguments___], scope_Association] := applicationText[HoldComplete[head], HoldComplete /@ Unevaluated[{arguments}], scope]

leanText[other_, scope_Association] := bridgeFailure["UnsupportedTerm", "`1` cannot be written as Lean source.", {HoldForm[other]}]

heldLeanText[HoldComplete[term_], scope_Association] := leanText[term, scope]

(* a constant or a variable takes @; any other head is parenthesized *)

applicationText[head_HoldComplete, arguments_List, scope_Association] := "(" <> headText[head, scope] <> StringJoin[Function[argument, " " <> heldLeanText[argument, scope]] /@ arguments] <> ")"

headText[HoldComplete[Subscript[constant_, levels___]], scope_Association] := "@" <> leanName[HoldComplete[constant]] <> constantLevelSuffix[HoldComplete[constant], HoldComplete /@ Unevaluated[{levels}]]

headText[HoldComplete[name : (_Symbol | _String | InductiveRecursor[_])], scope_Association] := Lookup[scope, HoldComplete[name], "@" <> leanName[HoldComplete[name]]]

headText[head_HoldComplete, scope_Association] := "(" <> heldLeanText[head, scope] <> ")"

(* (x : A) -> (y : B) -> body, or fun (x : A) (y : B) => body, with each binder named in turn *)

binderChain[binders_List, body_HoldComplete, scope_Association, separator_String, opener_String, arrow_String] := Block[
    {folded = Fold[addBinderText, {{}, scope}, binders]},
    "(" <> opener <> StringRiffle[First[folded], separator] <> " " <> arrow <> " " <> heldLeanText[body, Last[folded]] <> ")"
]

addBinderText[{texts_List, scope_Association}, binder_HoldComplete] := Block[{parts = binderParts[binder], identifier},
    identifier = freshIdentifier[parts["Name"], scope];
    {Append[texts, bracketed[parts["Kind"], identifier <> " : " <> heldLeanText[parts["Type"], scope]]], Append[scope, parts["Name"] -> identifier]}
]

binderParts[HoldComplete[Typed[name_, type_]]] := <|"Name" -> HoldComplete[name], "Type" -> HoldComplete[type], "Kind" -> "Explicit"|>

binderParts[HoldComplete[Annotation[Typed[name_, type_], kind_String]]] := <|"Name" -> HoldComplete[name], "Type" -> HoldComplete[type], "Kind" -> kind|>

(* TypeTheory 0.8 reads implicit binders back as TypedImplicit *)
binderParts[HoldComplete[TypedImplicit[name_, type_]]] := <|"Name" -> HoldComplete[name], "Type" -> HoldComplete[type], "Kind" -> "Implicit"|>

binderParts[HoldComplete[other_]] := bridgeFailure["UnsupportedBinder", "`1` cannot be written as a Lean binder.", {HoldForm[other]}]

bracketed["Explicit", text_String] := "(" <> text <> ")"

bracketed["Implicit", text_String] := "{" <> text <> "}"

bracketed["InstanceImplicit", text_String] := "[" <> text <> "]"

bracketed["StrictImplicit", text_String] := "{{" <> text <> "}}"

(* === Universe levels as Lean source === *)

levelSuffix[levels_List] := ".{" <> StringRiffle[Function[level, heldLevelText[level]] /@ levels, ", "] <> "}"

constantLevelSuffix[constant_HoldComplete, levels_List] := If[MemberQ[$declaredInductive, constant], "", levelSuffix[levels]]

$declaredInductive = {}

SetAttributes[levelText, HoldFirst]

levelText[n_Integer] := ToString[n]

levelText[Plus[level_, k_Integer]] := "(" <> levelText[level] <> "+" <> ToString[k] <> ")"

levelText[Max[first_, rest__]] := "(max " <> levelText[first] <> " " <> levelText[Max[rest]] <> ")"

levelText[Max[level_]] := levelText[level]

levelText[ImpredicativeMaximum[first_, second_]] := "(imax " <> levelText[first] <> " " <> levelText[second] <> ")"

levelText[name : (_Symbol | _String)] := Lookup[$universeNames, HoldComplete[name], bridgeFailure["UnsupportedLevel", "The universe level `1` is not a parameter of the declaration.", {HoldForm[name]}]]

levelText[other_] := bridgeFailure["UnsupportedLevel", "`1` cannot be written as a Lean universe level.", {HoldForm[other]}]

heldLevelText[HoldComplete[level_]] := levelText[level]

End[];

EndPackage[];

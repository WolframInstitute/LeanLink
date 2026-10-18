(* ::Package:: *)

(* TypeTheoryTranslation.wl -- translating between Lean and the WolframInstitute/TypeTheory proof engine.

   From Lean: LeanToTypeTheory collects a constant's dependency cone through the native environment,
   orders it so each constant comes after the ones it mentions, and writes each constant as a TypeTheory
   declaration whose terms are exact: every application is Construct[f, arguments...], so TypeTheory
   fills in no implicit argument, and every universe level is given with Subscript. Lean names stay
   strings; the recursor X.rec is TypeTheory's InductiveRecursor["X"], which TypeTheory generates itself
   and the bridge then compares with Lean's. TypeTheory's kernel checks every declaration again.

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
    {$kinds = <||>, $universes = <||>, $inductives = <||>, $handle = handle, cone, order, baseEnvironment, declarations, environment},
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

primaryName[name_String] := Switch[constantKind[name],
    "constructor", constructorInductive[name],
    "recursor", StringDrop[name, -4],
    _, name
]

(* an inductive type mentions what its constructors mention; Quot.lift and Quot.ind compute on Quot.mk, so
   they come after it, with their computation rule *)

constantDependencies[name_String] := DeleteDuplicates @ Join[
    If[ constantKind[name] === "inductive",
        Catenate[usedConstants /@ Prepend[inductiveInformation[name]["Constructors"], name]],
        usedConstants[name]
    ],
    If[MemberQ[{"Quot.lift", "Quot.ind"}, name], {"Quot.mk"}, {}]
]

ownNames[name_String] := If[ constantKind[name] === "inductive",
    Join[{name, name <> ".rec"}, inductiveInformation[name]["Constructors"]],
    {name}
]

usedConstants[name_String] := Block[{used = Quiet[decodeWXF[$getUsedConstantsFn[$handle, name]]]},
    If[AssociationQ[used], Join[Lookup[used, "type", {}], Lookup[used, "value", {}]], {}]
]

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

(* Lean's recursor X.rec takes the parameters, the motive, one minor premise per constructor, the indices
   and the major premise; its minor premises name the constructors in order. A motive is the binder whose
   type ends in a universe and takes a term of an inductive type: a parameter cannot mention X, so the
   first such binder ends the parameters, and more than one means a mutual or nested family. *)

inductiveInformation[name_String] := Lookup[$inductives, name, $inductives[name] = readInductiveInformation[name]]

readInductiveInformation[name_String] := Block[{typeBinders, recursorBinders, numberOfParameters, numberOfIndices, motives},
    typeBinders = First[forallTelescope[leanExpression[name, "Type"]]];
    recursorBinders = First[forallTelescope[leanExpression[name <> ".rec", "Type"]]];
    motives = Position[recursorBinders, {_, type_ /; motiveTypeQ[type, name]}, {1}, Heads -> False];
    If[ Length[motives] =!= 1,
        bridgeFailure["MutualInductive", "`1` is a mutual or nested inductive type, which TypeTheory does not have yet.", {name}]
    ];
    numberOfParameters = First[First[motives]] - 1;
    numberOfIndices = Length[typeBinders] - numberOfParameters;
    <|
        "Parameters" -> numberOfParameters,
        "Constructors" -> Map[minorConstructor, Take[recursorBinders, {numberOfParameters + 2, Length[recursorBinders] - numberOfIndices - 1}]]
    |>
]

motiveTypeQ[type_, name_String] := MatchQ[Last[forallTelescope[type]], _LeanSort] && ! FreeQ[First[forallTelescope[type]], LeanConst[name, _]]

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

universeParameters[name_String] := Lookup[$universes, name, $universes[name] = readUniverseParameters[name]]

readUniverseParameters[name_String] := Block[{count, raw, instantiated, pairs, mapping},
    count = SelectFirst[Range[0, 8], Function[n, AssociationQ[typeCheck[LeanConst[name, placeholderLevels[n]], $handle]]], None];
    If[count === None, bridgeFailure["UniverseParameters", "The universe parameters of `1` could not be read from Lean.", {name}]];
    If[ count === 0,
        {},
        raw = Cases[fetchField[$handle, name, "Type"], LeanLevelParam[parameter_] :> parameter, Infinity];
        instantiated = Cases[typeCheck[LeanConst[name, placeholderLevels[count]], $handle]["Type"], LeanLevelParam[parameter_] :> parameter, Infinity];
        If[Length[raw] =!= Length[instantiated], bridgeFailure["UniverseParameters", "The universe parameters of `1` could not be matched up.", {name}]];
        mapping = Association[Function[pair, Last[pair] -> First[pair]] /@ DeleteDuplicates[Transpose[{raw, instantiated}]]];
        Function[placeholder,
            Lookup[mapping, placeholder, bridgeFailure["UniverseParameters", "A universe parameter of `1` does not occur in its type.", {name}]]
        ] /@ placeholderNames[count]
    ]
]

(* placeholders must be Lean names, and distinct, or Lean merges them *)

placeholderNames[n_Integer] := Table["typeTheoryLevel" <> ToString[i], {i, 0, n - 1}]

placeholderLevels[n_Integer] := LeanLevelParam /@ placeholderNames[n]

(* === Declarations === *)

constantName[name_String] := If[constantKind[name] === "recursor", InductiveRecursor[StringDrop[name, -4]], name]

leanDeclarations[name_String] := Block[{$currentConstant = name, universes = universeParameters[name]},
    Switch[constantKind[name],
        "inductive",
            inductiveDeclarations[name, universes],
        "def",
            With[{value = leanTerm[leanExpression[name, "Term"]], type = leanTerm[leanExpression[name, "Type"]], levels = universes},
                {TypeTheoryDefinition[name, Typed[value, type], "UniverseParameters" -> levels]}
            ],
        "theorem",
            With[{statement = leanTerm[leanExpression[name, "Type"]], proof = leanTerm[leanExpression[name, "Term"]], levels = universes},
                {TypeTheoryTheorem[name, statement, proof, "UniverseParameters" -> levels]}
            ],
        (* an opaque constant's value never unfolds, and a quotient's computation rule is not in TypeTheory yet *)
        "axiom" | "opaque" | "quot",
            With[{type = leanTerm[leanExpression[name, "Type"]], levels = universes}, {TypeTheoryAxiom[name, type, "UniverseParameters" -> levels]}],
        _,
            bridgeFailure["UnsupportedConstant", "`1` is a `2`, which the bridge cannot translate.", {name, constantKind[name]}]
    ]
]

(* the natural numbers of Lean become TypeTheory's natural numbers, so literals mean the same *)

inductiveDeclarations[name_String, universes_List] := Block[{information = inductiveInformation[name]},
    With[
        {
            type = leanTerm[leanExpression[name, "Type"]],
            constructors = Function[constructor, constructor -> leanTerm[leanExpression[constructor, "Type"]]] /@ information["Constructors"],
            parameters = information["Parameters"]
        },
        Join[
            {TypeTheoryInductiveType[name, type, constructors, "Parameters" -> parameters, "UniverseParameters" -> universes]},
            If[name === "Nat" && information["Constructors"] === {"Nat.zero", "Nat.succ"}, {TypeTheoryNaturalNumbers["Nat", "Nat.zero", "Nat.succ"]}, {}]
        ]
    ]
]

(* the recursor TypeTheory generated must have Lean's type, compared at the same placeholder levels *)

checkRecursor[environment_, name_String] := Block[
    {recursor = name <> ".rec", levels, leanType},
    levels = placeholderLevels[Length[universeParameters[recursor]]];
    leanType = typeCheck[LeanConst[recursor, levels], $handle]["Type"];
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

leanSurface[LeanLitStr[_], _] := bridgeFailure["StringLiteral", "`1` uses a string literal, which TypeTheory does not have.", {$currentConstant}]

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
    HoldComplete[BooleanFalse] -> "Bool.false",
    HoldComplete[BooleanTrue] -> "Bool.true",
    HoldComplete[InductiveRecursor[Booleans]] -> "Bool.rec",
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
    {declarations = Normal[environment], prelude = TypeTheoryEnvironment["Prelude"], $environment = environment, $declarationIndex, $constructorOwners, needed},
    checkLeanRules[environment];
    If[FailureQ[declarations], Throw[declarations, $bridgeTag]];
    $declarationIndex = Association[Function[declaration, declarationKey[declaration] -> declaration] /@ declarations];
    $constructorOwners = Association[Catenate[constructorOwners /@ declarations]];
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

(* the name a declaration introduces, held; an inductive type's constructors and recursor belong to it *)

declarationKey[declaration_] := Replace[declaration, (TypeTheoryAxiom | TypeTheoryDefinition | TypeTheoryTheorem | TypeTheoryInductiveType)[name_, ___] :> HoldComplete[name]]

declarationKey[declaration_TypeTheoryNaturalNumbers] := None

constructorOwners[TypeTheoryInductiveType[name_, _, {constructors___}, ___]] := Join[
    Cases[HoldComplete[constructors], (Rule | RuleDelayed)[constructor_, _] :> (HoldComplete[constructor] -> HoldComplete[name])],
    {HoldComplete[InductiveRecursor[name]] -> HoldComplete[name]}
]

constructorOwners[_] := {}

ownerKey[key_HoldComplete] := Lookup[$constructorOwners, key, key]

(* a constant is Lean's own when it came from Lean, as a string name, or is a prelude constant Lean has *)

leanSideQ[key_HoldComplete] := MatchQ[key, HoldComplete[_String] | HoldComplete[InductiveRecursor[_String]]] || KeyExistsQ[$preludeLeanNames, key]

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
    name : (_Symbol | _String | InductiveRecursor[_]) /; KeyExistsQ[$environment, name] :> ownerKey[HoldComplete[name]],
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

(* in its constructors' types the inductive type is a local of Lean's, named without universe levels *)

declarationText[TypeTheoryInductiveType[name_, type_, {constructors___}, options___]] := Block[{$universeNames = universeNames[HoldComplete[options]]},
    "inductive " <> leanName[HoldComplete[name]] <> universeSuffix[] <> " : " <> leanText[type, <||>] <> " where" <> Block[{$declaredInductive = HoldComplete[name]},
        StringJoin[
            Cases[HoldComplete[constructors], (Rule | RuleDelayed)[constructor_, constructorType_] :> "\n  | " <> identifierBase[HoldComplete[constructor]] <> " : " <> leanText[constructorType, <||>]]
        ]
    ]
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

leanText[Function[{binders___}, body_], scope_Association] := binderChain[HoldComplete /@ Unevaluated[{binders}], HoldComplete[body], scope, " ", "fun ", "=>"]

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

constantLevelSuffix[constant_HoldComplete, levels_List] := If[constant === $declaredInductive, "", levelSuffix[levels]]

$declaredInductive = None

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

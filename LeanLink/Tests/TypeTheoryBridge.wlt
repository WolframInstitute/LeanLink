(* TypeTheoryBridge.wlt -- LeanToTypeTheory and TypeTheoryToLean, the bridge to WolframInstitute/TypeTheory *)

(* Requires: Wolfram`LeanLink` and WolframInstitute/TypeTheory, as run_tests.wls sets up *)

BeginTestSection["TypeTheoryBridge"]

Needs["WolframInstitute`TypeTheory`"]

$lean = LeanImportString["theorem bridgeProbe (n : Nat) : 0 + n = n := Nat.zero_add n"]

(* ================================================================ *)
(* From Lean                                                         *)
(* ================================================================ *)

(* the table of shared subterms of a constant's type or value decodes to the term the full export writes out *)
sharedExportSameQ[handle_, name_String, field_String] := SameQ[
    Wolfram`LeanLink`Private`sharedExpression[Wolfram`LeanLink`Private`decodeWXF[If[field === "Type", Wolfram`LeanLink`Private`$getTypeSharedFn, Wolfram`LeanLink`Private`$getValueSharedFn][handle, name]]],
    Wolfram`LeanLink`Private`decodeWXF[If[field === "Type", Wolfram`LeanLink`Private`$getTypeFn, Wolfram`LeanLink`Private`$getValueFn][handle, name, 1000000]]
]

(* each subterm Lean shares sent once, as the bridge reads terms: the table decodes to the very term the
   full export writes out *)
VerificationTest[
    With[{handle = Wolfram`LeanLink`Private`extractHandle[$lean]},
        Function[{name, field}, sharedExportSameQ[handle, name, field]] @@@ {{"Nat.zero_add", "Type"}, {"Nat.zero_add", "Term"}, {"bridgeProbe", "Term"}, {"List.foldl", "Term"}, {"Nat.rec", "Type"}}
    ]
    ,
    {True, True, True, True, True}
    ,
    TestID -> "Shared-export-is-the-full-term"
]

VerificationTest[Keys[LeanToTypeTheory[$lean, "Eq.symm"]], {"Eq", "Eq.refl", InductiveRecursor["Eq"], "rfl", "Eq.symm"}, TestID -> "LeanToTypeTheory-Eq-symm-cone"]

(* the shim walks the cone in Lean, in the order coneOrder gives, with the kinds, universe parameters and inductive types'
   information the bridge would otherwise read *)
VerificationTest[
    With[{handle = Wolfram`LeanLink`Private`extractHandle[$lean]},
        Block[
            {
                Wolfram`LeanLink`Private`$kinds = <||>, Wolfram`LeanLink`Private`$universes = <||>, Wolfram`LeanLink`Private`$inductives = <||>,
                Wolfram`LeanLink`Private`$primaries = <||>, Wolfram`LeanLink`Private`$owners = <||>, Wolfram`LeanLink`Private`$used = <||>,
                Wolfram`LeanLink`Private`$handle = handle, Wolfram`LeanLink`Private`$environmentTerms = First[$lean], shim, inductives, walked
            },
            shim = Wolfram`LeanLink`Private`bridgeCone[{"Nat.zero_add", "List.foldl"}];
            inductives = Wolfram`LeanLink`Private`$inductives;
            Wolfram`LeanLink`Private`$kinds = <||>; Wolfram`LeanLink`Private`$universes = <||>; Wolfram`LeanLink`Private`$inductives = <||>;
            walked = Wolfram`LeanLink`Private`coneOrder[{"Nat.zero_add", "List.foldl"}];
            {shim === walked, AllTrue[Keys[inductives], Function[name, inductives[name] === Wolfram`LeanLink`Private`readInductiveInformation[name]]]}
        ]
    ]
    ,
    {True, True}
    ,
    TestID -> "Shim-cone-walk-is-coneOrder"
]

(* the fields of a cone read as one table give the records that reading each field gives *)
VerificationTest[
    With[{table = LeanToTypeTheory[$lean, "List.foldl_cons"]},
        Block[{Wolfram`LeanLink`Private`fieldsTableQ, Wolfram`LeanLink`Private`bridgeConeQ},
            Wolfram`LeanLink`Private`fieldsTableQ[] = False;
            Wolfram`LeanLink`Private`bridgeConeQ[] = False;
            With[{fields = LeanToTypeTheory[$lean, "List.foldl_cons"]}, {Keys[table] === Keys[fields], First[table]["Records"] === First[fields]["Records"]}]
        ]
    ]
    ,
    {True, True}
    ,
    TestID -> "Fields-table-gives-the-records-each-field-gives"
]

VerificationTest[
    With[{env = LeanToTypeTheory[$lean, "And.comm"]},
        {Head[env], KeyExistsQ[env, InductiveRecursor["And"]], MatchQ[TypeTheoryCheck[env], True | _Success]}
    ]
    ,
    {TypeTheoryEnvironment, True, True}
    ,
    TestID -> "LeanToTypeTheory-And-comm-replays"
]

VerificationTest[
    $zeroAdd = LeanToTypeTheory[$lean, "Nat.zero_add"];
    {Length[$zeroAdd], Information[$zeroAdd, "NaturalNumbers"]["Type"], MatchQ[TypeTheoryCheck[$zeroAdd], True | _Success]}
    ,
    {43, "Nat", True}
    ,
    TestID -> "LeanToTypeTheory-Nat-zero_add-cone-with-structures"
]

VerificationTest[
    MatchQ[
        TypeTheoryCheck[
            TypeTheoryTerm[Construct["Nat.zero_add", 5], $zeroAdd],
            TypeTheoryTerm[Construct[Subscript["Eq", 1], "Nat", Construct[Subscript["HAdd.hAdd", 0, 0, 0], "Nat", "Nat", "Nat", Construct[Subscript["instHAdd", 0], "Nat", "instAddNat"], 0, 5], 5]]
        ]
        ,
        True | _Success
    ]
    ,
    True
    ,
    TestID -> "LeanToTypeTheory-imported-theorem-is-usable"
]

VerificationTest[
    With[{rebuilt = TypeTheoryEnvironment[TypeTheoryEnvironment[Information[$zeroAdd, "Rules"]], Normal[$zeroAdd]]},
        {Sort[Keys[rebuilt]] === Sort[Keys[$zeroAdd]], AllTrue[Keys[$zeroAdd], rebuilt[#] === $zeroAdd[#]&]}
    ]
    ,
    {True, True}
    ,
    TestID -> "LeanToTypeTheory-an-imported-environment-rebuilds-from-Normal"
]

VerificationTest[Last[Keys[LeanToTypeTheory[$lean["bridgeProbe"]]]], "bridgeProbe", TestID -> "LeanToTypeTheory-LeanTerm"]

VerificationTest[
    With[{environment = LeanToTypeTheory[LeanImportString["def greeting : String := \"hi\""], "greeting"]},
        {KeyExistsQ[environment, "greeting"], KeyExistsQ[environment, "String.ofList"], KeyExistsQ[environment, "Char.ofNat"]}
    ]
    ,
    {True, True, True}
    ,
    TestID -> "LeanToTypeTheory-a-string-literal-is-written-as-Lean-reads-it"
]

(* a universe parameter that occurs in a field but not in the type, as Lean.ToLevel's *)
VerificationTest[
    With[{environment = LeanToTypeTheory[LeanImportString["structure FieldLevel.{u} : Type where\n  level : Nat\n  proof : Sort u → True"], "FieldLevel"]},
        {KeyExistsQ[environment, "FieldLevel"], KeyExistsQ[environment, "FieldLevel.mk"]}
    ]
    ,
    {True, True}
    ,
    TestID -> "LeanToTypeTheory-a-universe-parameter-only-a-field-mentions"
]

(* a definition a macro makes has a hygienic name, x._@.M.3._hygCtx._hyg.8, which String.toName cannot parse *)
VerificationTest[
    With[{environment = LeanToTypeTheory[LeanImportString["macro \"hygienic\" : command => `(def hidden : Nat := 1\ndef $(Lean.mkIdent `visible) : Nat := hidden + 1)\nhygienic"], "visible"]},
        {KeyExistsQ[environment, "visible"], AnyTrue[Keys[environment], StringQ[#] && StringStartsQ[#, "hidden._@."]&]}
    ]
    ,
    {True, True}
    ,
    TestID -> "LeanToTypeTheory-a-hygienic-name-imports"
]

VerificationTest[
    With[{environment = LeanToTypeTheory[LeanImportString["theorem belowPower : 2 ^ 64 - 1 < 2 ^ 64 := by decide"], "belowPower"]},
        {KeyExistsQ[environment, "belowPower"], Information[environment, "NaturalNumbers"]["Operations"][["LessEqual"]]}
    ]
    ,
    {True, "Nat.ble"}
    ,
    TestID -> "LeanToTypeTheory-Lean-arithmetic-computes-on-literals"
]

(* an opaque constant is an opaque definition since TypeTheory 0.14, whose value its kernel checks; before,
   it is an axiom *)
$opaqueDefinitions = KeyExistsQ[Association[Options[TypeTheoryDefinition]], "Opaque"]

VerificationTest[
    With[{environment = LeanToTypeTheory[LeanImportString[{"opaque secret : Nat := 42", "opaque hidden : Nat", "theorem secretSelf : secret = secret := rfl"}], {"secretSelf", "hidden"}]},
        {
            Lookup[Information[environment, "Kinds"], "Opaque", 0],
            Sort[Information[environment, "Axioms"]],
            DefinitionallyEqualQ[TypeTheoryTerm["secret", environment], TypeTheoryTerm[42, environment]],
            MatchQ[TypeTheoryCheck[environment], _Success]
        }
    ]
    ,
    If[$opaqueDefinitions, {2, {}, False, True}, {0, {"hidden", "secret"}, False, True}]
    ,
    TestID -> "LeanToTypeTheory-an-opaque-is-checked-and-never-unfolds"
]

VerificationTest[
    With[{
        environment = LeanToTypeTheory[
            LeanImportString[
                "mutual\ninductive Even : Nat → Prop\n  | zero : Even 0\n  | succ {n : Nat} : Odd n → Even (n + 1)\ninductive Odd : Nat → Prop\n  | succ {n : Nat} : Even n → Odd (n + 1)\nend\ninductive Rose where\n  | node : Nat → List Rose → Rose"
            ]
            ,
            {"Even", "Rose"}
        ]
    },
        {Select[Keys[environment], Function[key, ! FreeQ[key, "Even" | "Odd" | "Rose"]]], MatchQ[TypeTheoryCheck[environment], _Success]}
    ]
    ,
    {{"Even", "Odd", InductiveRecursor["Even"], InductiveRecursor["Odd"], "Rose", InductiveRecursor["Rose"], InductiveRecursor["Rose", 1]}, True}
    ,
    TestID -> "LeanToTypeTheory-mutual-and-nested-types-import-with-Lean's-recursors"
]

VerificationTest[
    With[{
        source = TypeTheoryToLean[
            TypeTheoryEnvironment[
                TypeTheoryEnvironment["Prelude"]
                ,
                {
                    TypeTheoryInductiveType[
                        {Even -> TypeSpecifier[{NonNegativeIntegers} -> TypeUniverse[0]], Odd -> TypeSpecifier[{NonNegativeIntegers} -> TypeUniverse[0]]}
                        ,
                        {
                            EvenZero -> Even[0],
                            EvenSuccessor -> ForAll[{TypedImplicit[n, NonNegativeIntegers], Typed[h, Odd[n]]}, Even[n + 1]],
                            OddSuccessor -> ForAll[{TypedImplicit[n, NonNegativeIntegers], Typed[h, Even[n]]}, Odd[n + 1]]
                        }
                    ]
                    ,
                    TypeTheoryTheorem[TwoEven, Even[2], EvenSuccessor[OddSuccessor[EvenZero]]]
                }
            ]
            ,
            TwoEven
        ]
    },
        {StringContainsQ[source, "mutual\ninductive TypeTheory.Even"], FailureQ[LeanImportString[source]]}
    ]
    ,
    {True, False}
    ,
    TestID -> "TypeTheoryToLean-a-mutual-block-is-written-as-Lean's-mutual-block"
]

$funext = LeanToTypeTheory[$lean, "funext"]

(* Lean's quotient types are TypeTheory's own, declared at once with Lean's names, since TypeTheory 0.13;
   before, they compute by rewrite rules *)
$nativeQuotients = TrueQ[TypeTheoryRules["CalculusOfInductiveConstructions"]["Quotients"]]

VerificationTest[
    {Information[$funext, "RewriteRules"], Lookup[Information[$funext, "Kinds"], "Quotient", 0], MatchQ[TypeTheoryCheck[$funext], True | _Success], StringQ[TypeTheoryToLean[$funext, "funext"]]},
    If[$nativeQuotients, {{}, 4, True, True}, {{"Quot.lift computes", "Quot.ind computes"}, 0, True, True}],
    TestID -> "LeanToTypeTheory-quotients-are-TypeTheory's-own"
]

(* under rules without quotients they are axioms, computing by rewrite rules where the rules allow those *)
VerificationTest[
    With[{
        withoutQuotients = If[$nativeQuotients, TypeTheoryRules["CalculusOfInductiveConstructions", "Quotients" -> False], TypeTheoryRules["CalculusOfInductiveConstructions"]],
        rewriting = If[$nativeQuotients, TypeTheoryRules["CalculusOfInductiveConstructions", "Quotients" -> False, "RewriteRules" -> True], TypeTheoryRules["CalculusOfInductiveConstructions", "RewriteRules" -> True]]
    },
        {
            Information[LeanToTypeTheory[$lean, "funext", "Environment" -> TypeTheoryEnvironment[rewriting]], "RewriteRules"],
            StringContainsQ[LeanToTypeTheory[$lean, "funext", "Environment" -> TypeTheoryEnvironment[withoutQuotients]]["Message"], "whose rules have quotients"]
        }
    ]
    ,
    {{"Quot.lift computes", "Quot.ind computes"}, True}
    ,
    TestID -> "LeanToTypeTheory-quotients-without-the-rules-for-them"
]

(* ================================================================ *)
(* To Lean                                                           *)
(* ================================================================ *)

$prelude = TypeTheoryEnvironment["Prelude"]

$proof = TypeTheoryProof[
    ForAll[{Typed[n, NonNegativeIntegers]}, 0 + n == n]
    ,
    $prelude
    ,
    {
        TypeTheoryTactic["Introduce", n],
        TypeTheoryTactic["Induction", n],
        TypeTheoryTactic["Reflexivity"],
        TypeTheoryTactic["Introduce", k, ih],
        TypeTheoryTactic["Exact", "equalityCongruence"["successor", ih]]
    }
]

$proved = Append[$prelude, TypeTheoryTheorem[ZeroLeftIdentity, $proof]]

VerificationTest[
    StringContainsQ[TypeTheoryToLean[$proved, ZeroLeftIdentity], {"theorem TypeTheory.equalityCongruence.{u, v}", "theorem TypeTheory.ZeroLeftIdentity"}, IgnoreCase -> False],
    True,
    TestID -> "TypeTheoryToLean-writes-the-theorem-and-its-dependencies"
]

VerificationTest[
    With[{compiled = LeanImportString[TypeTheoryToLean[$proved, ZeroLeftIdentity]]},
        compiled["TypeTheory.ZeroLeftIdentity"]["TypeForm"]
    ]
    ,
    "\[ForAll] (n : Nat), Nat.add 0 n = n"
    ,
    TestID -> "TypeTheoryToLean-Lean-kernel-checks-the-proof"
]

$wrapped = TypeTheoryEnvironment[
    $prelude
    ,
    {
        TypeTheoryInductiveType[
            Wrapper,
            ForAll[{Typed[A, TypeUniverse[u]]}, TypeUniverse[Max[1, u]]],
            {WrapperIntroduction -> ForAll[{Annotation[Typed[A, TypeUniverse[u]], "Implicit"], Typed[x, A]}, Wrapper[A]]}
        ]
        ,
        TypeTheoryDefinition[
            Unwrap,
            Function[{Annotation[Typed[A, TypeUniverse[u]], "Implicit"], Typed[w, Wrapper[A]]}, InductiveRecursor[Wrapper][Function[{Typed[t, Wrapper[A]]}, A], Function[{Typed[x, A]}, x], w]]
        ]
    }
]

VerificationTest[
    With[{compiled = LeanImportString[TypeTheoryToLean[$wrapped, Unwrap]]},
        compiled["TypeTheory.Unwrap"]["TypeForm"]
    ]
    ,
    "{A : Sort u} \[RightArrow] TypeTheory.Wrapper A \[RightArrow] A"
    ,
    TestID -> "TypeTheoryToLean-universe-polymorphic-inductive-type"
]

VerificationTest[
    With[{
        sorts = TypeTheoryEnvironment[
            $prelude
            ,
            {
                TypeTheoryDefinition[PlainIdentity, Function[{TypedImplicit[A, TypeUniverse[u]], Typed[x, A]}, x], "UniverseParameters" -> {u}]
                ,
                TypeTheoryDefinition[
                    SortIdentity,
                    Typed[Function[{Typed[x, TypeUniverse[u]]}, Construct[Subscript[PlainIdentity, u + 1], TypeUniverse[u], x]], ForAll[{Typed[x, TypeUniverse[u]]}, TypeUniverse[u]]],
                    "UniverseParameters" -> {u}
                ]
            }
        ]
    },
        LeanImportString[TypeTheoryToLean[sorts, SortIdentity]]["TypeTheory.SortIdentity"]["TypeForm"]
    ]
    ,
    "Sort u \[RightArrow] Sort u"
    ,
    TestID -> "TypeTheoryToLean-a-sort-given-as-an-argument-is-parenthesized"
]

VerificationTest[
    With[{source = TypeTheoryToLean[$prelude, "excludedMiddle"]},
        {
            StringFreeQ[source, "axiom "],
            AllTrue[{"@propext", "@funext", "@Classical.choice"}, Function[name, StringContainsQ[source, name]]],
            LeanImportString[source]["TypeTheory.excludedMiddle"]["TypeForm"]
        }
    ]
    ,
    {True, True, "\[ForAll] (p : Prop), p \[Or] \[Not]p"}
    ,
    TestID -> "TypeTheoryToLean-the-prelude-axioms-are-Lean-axioms"
]

$booleans = Append[
    $prelude
    ,
    TypeTheoryTheorem[
        NegationTwice,
        ForAll[{Typed[b, Booleans]}, Not[Not[b]] == b],
        Function[{Typed[b, Booleans]}, InductiveRecursor[Booleans][Function[{Typed[t, Booleans]}, Not[Not[t]] == t], "equalityReflexivity"[False], "equalityReflexivity"[True], b]]
    ]
]

VerificationTest[
    With[{source = TypeTheoryToLean[$booleans, NegationTwice]},
        {StringFreeQ[source, "inductive "], LeanImportString[source]["TypeTheory.NegationTwice"]["TypeForm"]}
    ]
    ,
    {True, "\[ForAll] (b : Bool), (!!b) = b"}
    ,
    TestID -> "TypeTheoryToLean-the-Booleans-are-Lean-Bool"
]

(* TypeTheory 0.24's lists, {A} with {} and Prepend, are Lean's List: none is declared, and a proof by the recursor of
   lists checks in Lean's kernel *)

VerificationTest[
    With[{
        source = TypeTheoryToLean[
            Append[
                $prelude
                ,
                TypeTheoryTheorem[
                    ListSelf,
                    ForAll[{Typed[l, {NonNegativeIntegers}]}, l == l],
                    Function[{Typed[l, {NonNegativeIntegers}]},
                        InductiveRecursor[List][
                            Function[{Typed[k, {NonNegativeIntegers}]}, k == k],
                            "equalityReflexivity"[Typed[{}, {NonNegativeIntegers}]],
                            Function[{Typed[x, NonNegativeIntegers], Typed[t, {NonNegativeIntegers}], Typed[ih, t == t]}, "equalityReflexivity"[Prepend[x][t]]],
                            l
                        ]
                    ]
                ]
            ],
            ListSelf
        ]
    },
        {StringFreeQ[source, "inductive "], AllTrue[{"@List.rec", "@List.nil", "@List.cons"}, StringContainsQ[source, #]&], First[LeanImportString[source]["TypeTheory.ListSelf"]["KernelCheck"]]}
    ]
    ,
    {True, True, "KernelChecked"}
    ,
    TestID -> "TypeTheoryToLean-lists-are-Lean-lists"
]

(* a string name that one of TypeTheory's library environments declares is TypeTheory's, not Lean's: the
   WolframLanguage environment's "sequenceOf" (TypeTheory 0.27) and the Integers' theorems are declared *)

VerificationTest[
    If[ KeyExistsQ[TypeTheoryEnvironment["WolframLanguage"], "sequenceOf"],
        With[{sequences = TypeTheoryToLean[TypeTheoryEnvironment["WolframLanguage"], "sequenceOfPrepend"], integers = TypeTheoryToLean[TypeTheoryEnvironment["Integers"], "integerAdditionCommutativity"]},
            {
                StringContainsQ[sequences, "inductive TypeTheory.sequenceOf"],
                MatchQ[LeanImportString[sequences], _LeanEnvironment],
                First[LeanImportString[integers]["TypeTheory.integerAdditionCommutativity"]["KernelCheck"]]
            }
        ],
        {True, True, "KernelChecked"}
    ]
    ,
    {True, True, "KernelChecked"}
    ,
    TestID -> "TypeTheoryToLean-library-string-names-are-TypeTheory's"
]

VerificationTest[
    If[ $opaqueDefinitions,
        With[{
            source = TypeTheoryToLean[
                TypeTheoryEnvironment[
                    $prelude,
                    {TypeTheoryDefinition[Secret, Typed[42, NonNegativeIntegers], "Opaque" -> True], TypeTheoryTheorem[SecretSelf, Secret == Secret, "equalityReflexivity"[Secret]]}
                ],
                SecretSelf
            ]
        },
            {StringContainsQ[source, "noncomputable opaque TypeTheory.Secret : @Nat"], LeanImportString[source]["TypeTheory.Secret"]["Kind"]}
        ]
        ,
        {True, "opaque"}
    ]
    ,
    {True, "opaque"}
    ,
    TestID -> "TypeTheoryToLean-an-opaque-definition-is-Lean's-opaque"
]

VerificationTest[First @ TypeTheoryToLean[$prelude, NotAConstant], "UnknownConstant", TestID -> "TypeTheoryToLean-unknown-constant"]

$rewriting = TypeTheoryRules["CalculusOfInductiveConstructions", "RewriteRules" -> True]

$bits = {TypeTheoryInductiveType[Bit, TypeUniverse[1], {BitZero -> Bit, BitOne -> Bit}], TypeTheoryAxiom[Flip, TypeSpecifier[{Bit} -> Bit]]}

VerificationTest[
    {
        First @ TypeTheoryToLean[TypeTheoryEnvironment["HomotopyTypeTheory"], "universeNotSet"],
        First @ TypeTheoryToLean[TypeTheoryEnvironment[$rewriting, Append[$bits, TypeTheoryRewriteRule[FlipZero, Flip[BitZero] -> BitOne]]], Flip],
        StringContainsQ[TypeTheoryToLean[TypeTheoryEnvironment[$rewriting, $bits], Flip], "axiom TypeTheory.Flip"]
    }
    ,
    {"UnsupportedRules", "UnsupportedRules", True}
    ,
    TestID -> "TypeTheoryToLean-refuses-rules-Lean-does-not-have"
]

(* the recursor Lean makes for an inductive type written here takes its constructors' implicit binders, so a
   minor premise written as a plain fun would get implicit lambdas from Lean's elaborator *)

VerificationTest[Head[LeanImportString[TypeTheoryToLean[$prelude, Keys[$prelude]]]], LeanEnvironment, TestID -> "TypeTheoryToLean-the-whole-prelude-compiles"]

(* the prelude names its internal constants by strings, as "equal", which are its own and not Lean's; a type
   with instances is a class, and an instance-implicit binder of a type Lean has as no class is implicit;
   the prelude has instances since TypeTheory 0.13 *)

VerificationTest[
    If[ KeyExistsQ[$prelude, "trueDecidable"],
        With[{source = TypeTheoryToLean[$prelude, {"decideSoundness", "naturalNumberEqualityDecidable"}]},
            {
                StringContainsQ[source, "class inductive TypeTheory.Decidable"]
                ,
                StringContainsQ[source, "@[instance] noncomputable def TypeTheory.naturalNumberEqualityDecidable"]
                ,
                StringContainsQ[source, "noncomputable def TypeTheory.equal :"]
                ,
                StringContainsQ[source, "[d : (@TypeTheory.Decidable p)]"]
                ,
                StringContainsQ[
                    TypeTheoryToLean[
                        TypeTheoryEnvironment[$prelude, {TypeTheoryAxiom[Reflexive, ForAll[{TypedImplicit[n, NonNegativeIntegers], Annotation[Typed[h, n == n], "InstanceImplicit"]}, True]]}],
                        Reflexive
                    ],
                    "{h : (@Eq.{1} @Nat n n)}"
                ]
            }
        ]
        ,
        {True, True, True, True, True}
    ]
    ,
    {True, True, True, True, True}
    ,
    TestID -> "TypeTheoryToLean-writes-the-prelude's-string-names-classes-and-instances"
]

EndTestSection[]

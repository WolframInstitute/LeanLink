(* TypeTheoryBridge.wlt -- LeanToTypeTheory and TypeTheoryToLean, the bridge to WolframInstitute/TypeTheory *)

(* Requires: Wolfram`LeanLink` and WolframInstitute/TypeTheory, as run_tests.wls sets up *)

BeginTestSection["TypeTheoryBridge"]

Needs["WolframInstitute`TypeTheory`"]

$lean = LeanImportString["theorem bridgeProbe (n : Nat) : 0 + n = n := Nat.zero_add n"]

(* ================================================================ *)

(* From Lean                                                         *)

(* ================================================================ *)

VerificationTest[
    Keys[LeanToTypeTheory[$lean, "Eq.symm"]],
    {"Eq", "Eq.refl", InductiveRecursor["Eq"], "rfl", "Eq.symm"},
    TestID -> "LeanToTypeTheory-Eq-symm-cone"
]

VerificationTest[
    With[{env = LeanToTypeTheory[$lean, "And.comm"]}, {Head[env], KeyExistsQ[env, InductiveRecursor["And"]], MatchQ[TypeTheoryCheck[env], True | _Success]}],
    {TypeTheoryEnvironment, True, True},
    TestID -> "LeanToTypeTheory-And-comm-replays"
]

VerificationTest[
    $zeroAdd = LeanToTypeTheory[$lean, "Nat.zero_add"];
    {Length[$zeroAdd], Information[$zeroAdd, "NaturalNumbers"]["Type"], MatchQ[TypeTheoryCheck[$zeroAdd], True | _Success]},
    {43, "Nat", True},
    TestID -> "LeanToTypeTheory-Nat-zero_add-cone-with-structures"
]

VerificationTest[
    MatchQ[
        TypeTheoryCheck[
            TypeTheoryTerm[Construct["Nat.zero_add", 5], $zeroAdd],
            TypeTheoryTerm[Construct[Subscript["Eq", 1], "Nat", Construct[Subscript["HAdd.hAdd", 0, 0, 0], "Nat", "Nat", "Nat", Construct[Subscript["instHAdd", 0], "Nat", "instAddNat"], 0, 5], 5]]
        ],
        True | _Success
    ],
    True,
    TestID -> "LeanToTypeTheory-imported-theorem-is-usable"
]

VerificationTest[
    Last[Keys[LeanToTypeTheory[$lean["bridgeProbe"]]]],
    "bridgeProbe",
    TestID -> "LeanToTypeTheory-LeanTerm"
]

VerificationTest[
    First @ LeanToTypeTheory[LeanImportString["def greeting : String := \"hi\""], "greeting"],
    "StringLiteral",
    TestID -> "LeanToTypeTheory-string-literals-are-reported"
]

VerificationTest[
    With[{environment = LeanToTypeTheory[LeanImportString["theorem belowPower : 2 ^ 64 - 1 < 2 ^ 64 := by decide"], "belowPower"]},
        {KeyExistsQ[environment, "belowPower"], Information[environment, "NaturalNumbers"]["Operations"][["LessEqual"]]}
    ],
    {True, "Nat.ble"},
    TestID -> "LeanToTypeTheory-Lean-arithmetic-computes-on-literals"
]

$funext = LeanToTypeTheory[$lean, "funext"]

VerificationTest[
    {Information[$funext, "Rules"]["RewriteRules"], Information[$funext, "RewriteRules"], MatchQ[TypeTheoryCheck[$funext], True | _Success]},
    {True, {"Quot.lift computes"}, True},
    TestID -> "LeanToTypeTheory-quotients-compute-by-a-rewrite-rule"
]

VerificationTest[
    {
        StringQ[TypeTheoryToLean[$funext, "funext"]],
        StringContainsQ[LeanToTypeTheory[$lean, "funext", "Environment" -> TypeTheoryEnvironment[]]["Message"], "whose rules allow rewrite rules"]
    },
    {True, True},
    TestID -> "LeanToTypeTheory-quotients-need-rules-that-allow-rewrite-rules"
]

(* ================================================================ *)

(* To Lean                                                           *)

(* ================================================================ *)

$prelude = TypeTheoryEnvironment["Prelude"]

$proof = TypeTheoryProof[ForAll[{Typed[n, NonNegativeIntegers]}, 0 + n == n], $prelude, {
    TypeTheoryTactic["Introduce", n],
    TypeTheoryTactic["Induction", n],
    TypeTheoryTactic["Reflexivity"],
    TypeTheoryTactic["Introduce", k, ih],
    TypeTheoryTactic["Exact", EqualityCongruence[NaturalNumberSuccessor, ih]]
}]

$proved = Append[$prelude, TypeTheoryTheorem[ZeroLeftIdentity, $proof]]

VerificationTest[
    StringContainsQ[TypeTheoryToLean[$proved, ZeroLeftIdentity], {"theorem TypeTheory.EqualityCongruence.{u, v}", "theorem TypeTheory.ZeroLeftIdentity"}, IgnoreCase -> False],
    True,
    TestID -> "TypeTheoryToLean-writes-the-theorem-and-its-dependencies"
]

VerificationTest[
    With[{compiled = LeanImportString[TypeTheoryToLean[$proved, ZeroLeftIdentity]]}, compiled["TypeTheory.ZeroLeftIdentity"]["TypeForm"]],
    "\[ForAll] (n : Nat), Nat.add 0 n = n",
    TestID -> "TypeTheoryToLean-Lean-kernel-checks-the-proof"
]

$wrapped = TypeTheoryEnvironment[$prelude, {
    TypeTheoryInductiveType[Wrapper, ForAll[{Typed[A, TypeUniverse[u]]}, TypeUniverse[Max[1, u]]], {WrapperIntroduction -> ForAll[{Annotation[Typed[A, TypeUniverse[u]], "Implicit"], Typed[x, A]}, Wrapper[A]]}],
    TypeTheoryDefinition[Unwrap, Function[{Annotation[Typed[A, TypeUniverse[u]], "Implicit"], Typed[w, Wrapper[A]]}, InductiveRecursor[Wrapper][Function[{Typed[t, Wrapper[A]]}, A], Function[{Typed[x, A]}, x], w]]]
}]

VerificationTest[
    With[{compiled = LeanImportString[TypeTheoryToLean[$wrapped, Unwrap]]}, compiled["TypeTheory.Unwrap"]["TypeForm"]],
    "{A : Sort u} \[RightArrow] TypeTheory.Wrapper A \[RightArrow] A",
    TestID -> "TypeTheoryToLean-universe-polymorphic-inductive-type"
]

VerificationTest[
    With[{source = TypeTheoryToLean[$prelude, ExcludedMiddle]},
        {
            StringFreeQ[source, "axiom "],
            AllTrue[{"@propext", "@funext", "@Classical.choice"}, Function[name, StringContainsQ[source, name]]],
            LeanImportString[source]["TypeTheory.ExcludedMiddle"]["TypeForm"]
        }
    ],
    {True, True, "\[ForAll] (p : Prop), p \[Or] \[Not]p"},
    TestID -> "TypeTheoryToLean-the-prelude-axioms-are-Lean-axioms"
]

$booleans = Append[$prelude, TypeTheoryTheorem[
    NegationTwice,
    ForAll[{Typed[b, Booleans]}, Not[Not[b]] == b],
    Function[{Typed[b, Booleans]}, InductiveRecursor[Booleans][Function[{Typed[t, Booleans]}, Not[Not[t]] == t], EqualityReflexivity[False], EqualityReflexivity[True], b]]
]]

VerificationTest[
    With[{source = TypeTheoryToLean[$booleans, NegationTwice]},
        {StringFreeQ[source, "inductive "], LeanImportString[source]["TypeTheory.NegationTwice"]["TypeForm"]}
    ],
    {True, "\[ForAll] (b : Bool), (!!b) = b"},
    TestID -> "TypeTheoryToLean-the-Booleans-are-Lean-Bool"
]

VerificationTest[
    First @ TypeTheoryToLean[$prelude, NotAConstant],
    "UnknownConstant",
    TestID -> "TypeTheoryToLean-unknown-constant"
]

$rewriting = TypeTheoryRules["CalculusOfInductiveConstructions", "RewriteRules" -> True]

$bits = {
    TypeTheoryInductiveType[Bit, TypeUniverse[1], {BitZero -> Bit, BitOne -> Bit}],
    TypeTheoryAxiom[Flip, TypeSpecifier[{Bit} -> Bit]]
}

VerificationTest[
    {
        First @ TypeTheoryToLean[TypeTheoryEnvironment["HomotopyTypeTheory"], UniverseNotSet],
        First @ TypeTheoryToLean[TypeTheoryEnvironment[$rewriting, Append[$bits, TypeTheoryRewriteRule[FlipZero, Flip[BitZero] -> BitOne]]], Flip],
        StringContainsQ[TypeTheoryToLean[TypeTheoryEnvironment[$rewriting, $bits], Flip], "axiom TypeTheory.Flip"]
    },
    {"UnsupportedRules", "UnsupportedRules", True},
    TestID -> "TypeTheoryToLean-refuses-rules-Lean-does-not-have"
]

EndTestSection[]

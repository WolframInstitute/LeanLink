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
    With[{env = LeanToTypeTheory[$lean, "And.comm"]}, {Head[env], KeyExistsQ[env, InductiveRecursor["And"]], TypeTheoryCheck[env]}],
    {TypeTheoryEnvironment, True, True},
    TestID -> "LeanToTypeTheory-And-comm-replays"
]

VerificationTest[
    $zeroAdd = LeanToTypeTheory[$lean, "Nat.zero_add"];
    {Length[$zeroAdd], Information[$zeroAdd, "NaturalNumbers"]["Type"], TypeTheoryCheck[$zeroAdd]},
    {43, "Nat", True},
    TestID -> "LeanToTypeTheory-Nat-zero_add-cone-with-structures"
]

VerificationTest[
    TypeTheoryCheck[
        TypeTheoryTerm[Construct["Nat.zero_add", 5], $zeroAdd],
        TypeTheoryTerm[Construct[Subscript["Eq", 1], "Nat", Construct[Subscript["HAdd.hAdd", 0, 0, 0], "Nat", "Nat", "Nat", Construct[Subscript["instHAdd", 0], "Nat", "instAddNat"], 0, 5], 5]]
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

VerificationTest[
    First @ TypeTheoryToLean[$prelude, NotAConstant],
    "UnknownConstant",
    TestID -> "TypeTheoryToLean-unknown-constant"
]

EndTestSection[]

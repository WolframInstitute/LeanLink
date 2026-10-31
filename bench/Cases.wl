(* ::Package:: *)

(* The cases of typetheory_benchmark.wls, and of bench/save_cones.wls: constants of Mathlib, each imported into
   TypeTheory with every constant it depends on, its cone. *)

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

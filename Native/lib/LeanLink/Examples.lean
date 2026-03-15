/-
  LeanLink/Examples.lean -- Test fixtures mirroring Assets/Examples.lean.
  Provides simple theorems for WXF pipeline verification.
-/

namespace LeanLink.Examples

-- Natural number arithmetic
theorem add_zero : forall n : Nat, n + 0 = n := fun _ => rfl
theorem add_succ : forall m n : Nat, m + Nat.succ n = Nat.succ (m + n) := fun _ _ => rfl
theorem add_comm : forall m n : Nat, m + n = n + m := Nat.add_comm

-- Propositional logic
theorem modus_ponens : forall (P Q : Prop), P -> (P -> Q) -> Q :=
  fun _ _ hp hpq => hpq hp
theorem and_comm : forall (P Q : Prop), P /\ Q -> Q /\ P :=
  fun _ _ h => And.intro h.2 h.1
theorem contrapositive : forall (P Q : Prop), (P -> Q) -> (Not Q -> Not P) :=
  fun _ _ hpq hnq hp => hnq (hpq hp)
theorem identity : forall (P : Prop), P -> P := fun _ hp => hp

-- Dependent types
inductive Vec (a : Type) : Nat -> Type where
  | nil  : Vec a 0
  | cons : {n : Nat} -> a -> Vec a n -> Vec a (n + 1)

def Vec.head {a : Type} {n : Nat} : Vec a (n + 1) -> a
  | .cons x _ => x

def Vec.map {a b : Type} {n : Nat} (f : a -> b) : Vec a n -> Vec b n
  | .nil => .nil
  | .cons x xs => .cons (f x) (Vec.map f xs)

end LeanLink.Examples

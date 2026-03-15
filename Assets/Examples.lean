/-
  Examples.lean — Simple textbook theorems for expression graph visualization.
  Covers: naturals, booleans, logic, and lists.
-/

-- ============================================================================
-- Natural number arithmetic
-- ============================================================================

/-- n + 0 = n (definitional) -/
theorem add_zero_term : ∀ n : Nat, n + 0 = n :=
  fun _ => rfl

/-- Successor distributes: m + succ(n) = succ(m + n) (definitional) -/
theorem add_succ_term : ∀ m n : Nat, m + Nat.succ n = Nat.succ (m + n) :=
  fun _ _ => rfl

/-- 0 + n = n by induction -/
theorem zero_add_proof : ∀ n : Nat, 0 + n = n := by
  intro n; induction n with
  | zero => rfl
  | succ k ih => rw [Nat.add_succ]; rw [ih]

/-- Commutativity of addition -/
theorem add_comm_proof : ∀ m n : Nat, m + n = n + m := Nat.add_comm

/-- Associativity of addition -/
theorem add_assoc_proof : ∀ a b c : Nat, (a + b) + c = a + (b + c) := Nat.add_assoc

-- ============================================================================
-- Boolean logic
-- ============================================================================

/-- true && b = b -/
theorem band_true : ∀ b : Bool, true && b = b :=
  fun b => by cases b <;> rfl

/-- false || b = b -/
theorem bor_false : ∀ b : Bool, false || b = b :=
  fun b => by cases b <;> rfl

/-- Double negation: !!b = b -/
theorem bnot_bnot : ∀ b : Bool, (!!b) = b :=
  fun b => by cases b <;> rfl

-- ============================================================================
-- Propositional logic (term-mode proofs — small expr trees)
-- ============================================================================

/-- Modus ponens -/
theorem modus_ponens : ∀ (P Q : Prop), P → (P → Q) → Q :=
  fun _ _ hp hpq => hpq hp

/-- And commutativity -/
theorem and_comm_proof : ∀ (P Q : Prop), P ∧ Q → Q ∧ P :=
  fun _ _ ⟨hp, hq⟩ => ⟨hq, hp⟩

/-- Or commutativity -/
theorem or_comm_proof : ∀ (P Q : Prop), P ∨ Q → Q ∨ P :=
  fun _ _ h => h.elim Or.inr Or.inl

/-- Contrapositive -/
theorem contrapositive : ∀ (P Q : Prop), (P → Q) → (¬Q → ¬P) :=
  fun _ _ hpq hnq hp => hnq (hpq hp)

/-- Identity function -/
theorem id_proof : ∀ (P : Prop), P → P :=
  fun _ hp => hp

/-- Composition -/
theorem comp_proof : ∀ (P Q R : Prop), (P → Q) → (Q → R) → (P → R) :=
  fun _ _ _ hpq hqr hp => hqr (hpq hp)

-- ============================================================================
-- List basics (tactic proofs)
-- ============================================================================

/-- Reverse of reverse -/
theorem reverse_reverse : ∀ (α : Type) (xs : List α),
    xs.reverse.reverse = xs := by
  intro α xs; simp

-- ============================================================================
-- Dependent types
-- ============================================================================

/-- Length-indexed vector -/
inductive Vec (α : Type) : Nat → Type where
  | nil  : Vec α 0
  | cons : {n : Nat} → α → Vec α n → Vec α (n + 1)

/-- Head of a non-empty vector (dependent: n+1 guarantees non-empty) -/
def Vec.head {α : Type} {n : Nat} : Vec α (n + 1) → α
  | .cons a _ => a

/-- Tail of a non-empty vector -/
def Vec.tail {α : Type} {n : Nat} : Vec α (n + 1) → Vec α n
  | .cons _ as => as

/-- Map over a vector preserves length (dependent types in action) -/
def Vec.map {α β : Type} {n : Nat} (f : α → β) : Vec α n → Vec β n
  | .nil => .nil
  | .cons a as => .cons (f a) (Vec.map f as)



/-- Dependent pair: existential witness -/
theorem exists_succ : ∃ n : Nat, n > 0 :=
  ⟨1, by omega⟩

/-- Transport across equality (subst) -/
theorem eq_transport : ∀ (α : Type) (P : α → Prop) (a b : α),
    a = b → P a → P b :=
  fun _ _ _ _ hab ha => hab ▸ ha

/-- Sigma type: dependent pair (explicit length) -/
def sigma_example : (n : Nat) × Fin n.succ :=
  ⟨3, ⟨2, by omega⟩⟩

/-- Fin: bounded natural number -/
def fin_example : Fin 5 := ⟨3, by omega⟩

/-- Subtype proof -/
def even_two : { n : Nat // n % 2 = 0 } := ⟨2, rfl⟩

/-- Decidable equality gives us if-then-else on proofs -/
theorem nat_eq_decide : ∀ (n : Nat), n = n := fun _ => rfl


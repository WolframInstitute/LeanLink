# Dependent Types with LeanLink

## Setup

```wolfram
PacletDirectoryLoad[FileNameJoin[{NotebookDirectory[] // ParentDirectory, "LeanLink"}]];
Get["Wolfram`LeanLink`"];
```

## Arrow Types and Currying

In Lean, all functions are curried by default. A multi-argument function `f : A → B → C` can be partially applied as `f a : B → C`. LeanLink brings this to compiled Wolfram Language:

```
-- Lean
def add (x y : Int) : Int := x + y
-- add : Int → Int → Int
-- add 5 : Int → Int
```

```wolfram
add = FunctionCompile[
  Function[{Typed[x, "MachineInteger"], Typed[y, "MachineInteger"]}, x + y]
];
add[3, 4]
```

Partial application — `add 5 : Int → Int`:

```wolfram
add5 = add[5];
{add5[[1]]["Signature"], add5[3]}
```

```wolfram
Map[add[10], Range[5]]
```

### Triple arrow: `Int → Int → Int → Int`

```
-- Lean
def tripleOp (a b c : Int) : Int := a * b + c
-- tripleOp 2 : Int → Int → Int
-- tripleOp 2 3 4 = 10
```

```wolfram
tripleOp = FunctionCompile[
  Function[{Typed[a, "MachineInteger"], Typed[b, "MachineInteger"],
            Typed[c, "MachineInteger"]}, a * b + c]
];
{tripleOp[2, 3, 4], tripleOp[2, 3][4], tripleOp[2][3][4]}
```

## Pi Types: $\Pi(n:A).\; B(n)$

In Lean, `(n : Nat) → Vector Int n → Int` is a dependent function type: the type of the second argument mentions `n`. The `TypePi` annotation brings this to `FunctionCompile`. Unlike simple arrows, Pi types substitute the concrete value into the codomain type on partial application.

### replicate

```
-- Lean
def replicate (n : Nat) (val : Int) : Vector Int n := Vector.replicate n val
-- replicate   : (n : Nat) → Int → Vector Int n
-- replicate 3 : Int → Vector Int 3
```

```wolfram
cfReplicate = FunctionCompile[
  Function[{
    Typed[n, TypeSpecifier[TypePi["n", "Nat",
      {"Int"} -> "Vector"["Int", "n"]]]],
    Typed[val, "MachineInteger"]},
    Table[val, n]]
]
```

The signature carries the Pi binder — compare with Lean's `(n : Nat) → Int → Vector Int n`:

```wolfram
cfReplicate[[1]]["Signature"]
```

Curry `n = 3` — the Pi binder is eliminated and `n` is substituted with `3`, giving `Int → Vector Int 3`:

```wolfram
rep3 = cfReplicate[3];
rep3[[1]]["Signature"]
```

```wolfram
{rep3[42], rep3[0], rep3[7]}
```

### dot

```
-- Lean
def dot (n : Nat) (xs ys : Vector Int n) : Int :=
  (Vector.zipWith (· * ·) xs ys).toList.sum
-- dot   : (n : Nat) → Vector Int n → Vector Int n → Int
-- dot 3 : Vector Int 3 → Vector Int 3 → Int
```

```wolfram
cfDot = FunctionCompile[
  Function[{
    Typed[n, TypeSpecifier[TypePi["n", "Nat",
      {"Vector"["Int", "n"], "Vector"["Int", "n"]} -> "Int"]]],
    Typed[xs, TypeSpecifier["PackedArray"["MachineInteger", 1]]],
    Typed[ys, TypeSpecifier["PackedArray"["MachineInteger", 1]]]},
    Total[xs * ys]]
]
```

```wolfram
cfDot[[1]]["Signature"]
```

Curry the dimension — substitutes `n = 3` into the codomain:

```wolfram
dot3 = cfDot[3];
dot3[[1]]["Signature"]
```

```wolfram
dot3[{1, 2, 3}, {4, 5, 6}]
```

Curry further — fix the first vector:

```wolfram
dotWith = dot3[{1, 2, 3}];
{dotWith[[1]]["Signature"], dotWith[{4, 5, 6}]}
```

### head

```
-- Lean
def head (n : Nat) (xs : Vector α (n + 1)) : α := xs[0]
-- head   : (n : Nat) → Vector α (n + 1) → α
-- head 4 : Vector α 5 → α
```

```wolfram
cfHead = FunctionCompile[
  Function[{
    Typed[n, TypeSpecifier[TypePi["n", "Nat",
      {"Vector"["Int", "n"]} -> "Int"]]],
    Typed[xs, TypeSpecifier["PackedArray"["MachineInteger", 1]]]},
    xs[[1]]]
];
head5 = cfHead[5];
{head5[[1]]["Signature"], head5[{10, 20, 30, 40, 50}]}
```

## Auto-Registered Lean Types

LeanLink automatically registers parameterized Lean types so they work with `LeanCompile` and `LeanToFunction` without manual setup.

### Supported parameterized types

| Lean Type | WL Compiled Type | Notes |
|-----------|-----------------|-------|
| `Array α` | `"PackedArray"[elemTy, 1]` | 1-D packed array |
| `List α` | `"PackedArray"[elemTy, 1]` | 1-D packed array |
| `Vector α n` | `"Vector"[elemTy, n]` | Dependent — size tracked in TypePi |
| `Option α` | `"MaybeValue"[elemTy]` | Maybe/Option |

### Automatic dependent type detection

When `LeanCompile` encounters a term whose type has dependent forall binders (where the bound variable appears in the body), it automatically uses `LeanCompileTyped` to generate TypePi annotations:

```wolfram
(* Import a Lean file with Vector-typed functions *)
env = LeanImport["Proofs/Vectors.lean"];
term = env["replicate"];

(* LeanCompile detects the dependent type and uses TypePi *)
cf = LeanCompile[term];
cf[[1]]["Signature"]
(* → TypePi["n", LeanInductive[Nat, ...], {"Int"} → "Vector"["Int", "n"]] *)
```

No manual `$TypePiKnownTypes` registration needed — the built-in Lean types are pre-registered at package load time.

### Type validation

The `$TypePiKnownTypes` registry validates that TypePi annotations match compiled signatures. For example, `"Vector"[elemTy, n]` is checked against `"PackedArray"[elemTy, 1]`:

```wolfram
$TypePiKnownTypes
(* <|"Vector" → Function[...], "Array" → Function[...], ...| *)
```

## Type Correspondence

| Lean | Wolfram TypePi | Curried (n = 3) |
|------|---------------|-----------------| 
| `(n : Nat) → Int → Vector Int n` | `TypePi["n", Nat, {"Int"} → "Vector"["Int", "n"]]` | `{"Int"} → "Vector"["Int", 3]` |
| `(n : Nat) → Vector Int n → Int` | `TypePi["n", Nat, {"Vector"["Int","n"]} → "Int"]` | `{"Vector"["Int", 3]} → "Int"` |
| `Int → Int → Int` | `{Int, Int} → Int` | `{Int} → Int` |

The `TypePi` domain and codomain use Lean names (`Nat`, `Vector`, `Int`). The `$leanTypeCompile` mapping translates display names to compiler types (e.g. `Nat → MachineInteger`) automatically. The value `n` is substituted into the codomain type on partial application.

## Lean Type Translation

`LeanExprToType` translates Lean CIC expressions into TypeFramework type objects:

### $\text{Nat.add} : \mathbb{N} \to \mathbb{N} \to \mathbb{N}$

```
-- Lean: #check @Nat.add
-- Nat.add : Nat → Nat → Nat
```

```wolfram
natAddTy = LeanExprToType[
  LeanForall["a", LeanConst["Nat", {}],
    LeanForall["b", LeanConst["Nat", {}],
      LeanConst["Nat", {}], "default"], "default"]];
natAddTy["toString"]
```

### $\text{id} : \forall (A : \text{Type}),\; A \to A$

```
-- Lean: #check @id
-- id : {α : Sort u} → α → α
```

```wolfram
idTy = LeanExprToType[
  LeanForall["A", LeanSort[LeanLevelSucc[LeanLevelZero[]]],
    LeanForall["x", LeanBVar[0],
      LeanBVar[1], "default"], "default"]];
idTy["toString"]
```

## Type Unification

Pi types unify structurally — binding variable, domain, and codomain must all unify:

```wolfram
tyEnv = CreateCompileTypeEnvironment[];
pi1 = CreateTypePi[CreateTypeVariable["a"], CreateTypeVariable["D1"], CreateTypeVariable["C1"]];
pi2 = CreateTypePi[CreateTypeVariable["b"], CreateTypeVariable["D2"], CreateTypeVariable["C2"]];
sub = TypeUnify[tyEnv, pi1, pi2];
sub["toString"]
```

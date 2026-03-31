(* ::Package:: *)
(* Compiler.wl — Dependent type system for the Wolfram Compiler.
   Registers TypePi, TypeSort, TypeLet dynamically and provides
   leanExprToType to translate LeanLink expressions into TypeFramework objects.
   Also hooks FunctionCompile so that TypePi annotations appear
   in the resulting CompiledCodeFunction.
*)

BeginPackage["Wolfram`LeanLink`"];

(* Public symbols *)
LeanExprToType::usage =
  "LeanExprToType[expr] translates a LeanLink expression (LeanForall, LeanApp, etc.) \
into a TypeFramework type object.";

LeanCompileTyped::usage =
  "LeanCompileTyped[term] compiles a LeanTerm via FunctionCompile and annotates the \
result with its dependent type (TypePi).";

EndPackage[];


(* ============================================================================ *)
(* After EndPackage: $ContextPath is fully restored.                            *)
(* Now bootstrap the compiler and load TypeFramework.                           *)
(* ============================================================================ *)

(* Bootstrap: run FunctionCompile to force-load the installed compiler,
   then Get our forked API files to override specific functions.
   Block $Messages to guarantee zero output during package load. *)
Block[{$Messages = {}},
  FunctionCompile[Function[Typed[x, "MachineInteger"], x]]
];
(* Override specific compiler functions with our forked versions *)
With[{compDir = FileNameJoin[{DirectoryName[$InputFileName, 3], "compiler", "Compile"}]},
  Unprotect[FunctionCompile, CompiledCodeFunction];
  (* Load forked TypeObjects (including TypePi) before API files that reference it *)
  Get[FileNameJoin[{compDir, "TypeFramework", "TypeObjects", "TypePi.m"}]];
  Get[FileNameJoin[{compDir, "TypeFramework", "TypeObjects", "TypeSort.m"}]];
  Get[FileNameJoin[{compDir, "TypeFramework", "TypeObjects", "TypeLet.m"}]];
  Get[FileNameJoin[{compDir, "Compile", "API", "FunctionCompile.m"}]];
  Get[FileNameJoin[{compDir, "Compile", "API", "Utilities.m"}]];
  Get[FileNameJoin[{compDir, "Compile", "Core", "IR", "CompiledProgram.m"}]];
  Get[FileNameJoin[{compDir, "CompileUtilities", "Format", "CompiledCodeFunction.wl"}]];
  Protect[FunctionCompile];
];

(* Needs for leanExprToType *)
Needs["CompileUtilities`ClassSystem`"];
Needs["TypeFramework`"];
Needs["TypeFramework`TypeObjects`TypeVariable`"];
Needs["TypeFramework`TypeObjects`TypeArrow`"];
Needs["TypeFramework`TypeObjects`TypeConstructor`"];
Needs["TypeFramework`TypeObjects`TypeApplication`"];
Needs["TypeFramework`TypeObjects`TypeClosure`"];
Needs["TypeFramework`TypeObjects`LiteralType`"];
Needs["TypeFramework`TypeObjects`TypeProjection`"];


(* ---- Lean inductive type representation ---- *)
(* Faithful representation of Lean types with constructor structure *)
$leanTypes = <|
  "Nat" -> LeanInductive["Nat", {
    "zero" -> "Nat",
    "succ" -> {"Nat"} -> "Nat"}],
  "Int" -> LeanInductive["Int", {
    "ofNat" -> {"Nat"} -> "Int",
    "negSucc" -> {"Nat"} -> "Int"}],
  "Bool" -> LeanInductive["Bool", {
    "false" -> "Bool",
    "true" -> "Bool"}]
|>;

(* Compile-type for each Lean type (runtime erasure) *)
leanCompileType["Nat"] = "MachineInteger";
leanCompileType["Int"] = "MachineInteger";
leanCompileType["Bool"] = "Boolean";
leanCompileType["Float"] = "Real64";
leanCompileType["String"] = "String";
leanCompileType[LeanInductive[n_, _]] := leanCompileType[n];
leanCompileType[t_] := t;

(* Display type: resolve to LeanInductive if registered *)
leanDisplayType[t_String] := Lookup[$leanTypes, t, t];
leanDisplayType[t_] := t;

(* Register Lean type resolvers with the compiler's TypePi hooks *)
Compile`API`FunctionCompile`$TypePiCompileType = leanCompileType;
Compile`API`FunctionCompile`$TypePiDisplayType = leanDisplayType;

(* TypePi handling is native in the compiler:                                  *)
(*   FunctionCompile.m: extractTypePi + annotateWithPi                         *)

(* Partial application (currying) is native in the compiler:                   *)
(*   FunctionCompile.m: ccfArity, mkPartialCCF, CompiledCodeFunction UpValue   *)


(* ---- Auto-register Lean types in $TypePiKnownTypes ---- *)
(* This allows TypePi validation to check parameterized Lean types
   against their compiled representations. *)

(* Vector[elemTy, n] -- compiled as "PackedArray"[elemTy, 1] *)
$TypePiKnownTypes["Vector"] =
  Function[{piArgs, compiled},
    MatchQ[compiled, "PackedArray"[_, _]]];

(* Array[elemTy] -- compiled as "PackedArray"[elemTy, 1] *)
$TypePiKnownTypes["Array"] =
  Function[{piArgs, compiled},
    MatchQ[compiled, "PackedArray"[_, _]]];

(* List[elemTy] -- compiled as "PackedArray"[elemTy, 1] *)
$TypePiKnownTypes["List"] =
  Function[{piArgs, compiled},
    MatchQ[compiled, "PackedArray"[_, _]]];

(* Option[elemTy] -- compiled as "MaybeValue"[elemTy] *)
$TypePiKnownTypes["Option"] =
  Function[{piArgs, compiled},
    MatchQ[compiled, "MaybeValue"[_]]];


(* ============================================================================ *)
(* leanExprToType — Translate LeanLink expressions to TypeFramework              *)
(* ============================================================================ *)

leanExprToType[LeanSort[LeanLevelZero[]], ctx_List] := CreateTypeSort[0];
leanExprToType[LeanSort[LeanLevelSucc[l_]], ctx_List] :=
  CreateTypeSort[1 + leanExprToType[LeanSort[l], ctx]["level"]];
leanExprToType[LeanSort[_], ctx_List] := CreateTypeSort[1];

leanExprToType[LeanConst[name_String, _], ctx_List] :=
  CreateTypeConstructor[TypeConstructor[name, 0, <||>]];

leanExprToType[LeanBVar[i_Integer], ctx_List] :=
  If[i < Length[ctx], CreateTypeVariable[ctx[[-1 - i]]],
    CreateTypeVariable["#" <> ToString[i]]];

leanExprToType[LeanForall[name_String, domain_, body_, _], ctx_List] :=
  With[{domTy = leanExprToType[domain, ctx],
        varTy = CreateTypeVariable[name]},
    CreateTypePi[varTy, domTy, leanExprToType[body, Append[ctx, name]]]];

leanExprToType[LeanApp[fn_, arg_], ctx_List] :=
  CreateTypeApplication[leanExprToType[fn, ctx],
    {leanExprToType[arg, ctx]}];

leanExprToType[LeanLam[name_String, type_, body_, _], ctx_List] :=
  With[{argTy = leanExprToType[type, ctx]},
    CreateTypeClosure[{argTy},
      leanExprToType[body, Append[ctx, name]]]];

leanExprToType[LeanLet[name_String, type_, value_, body_], ctx_List] :=
  CreateTypeLet[CreateTypeVariable[name],
    leanExprToType[type, ctx], leanExprToType[value, ctx],
    leanExprToType[body, Append[ctx, name]]];

leanExprToType[LeanLitNat[n_Integer], ctx_List] :=
  CreateLiteralType[n, "MachineInteger"];
leanExprToType[LeanLitStr[s_String], ctx_List] :=
  CreateLiteralType[s, "String"];

leanExprToType[LeanProj[typeName_String, fieldIndex_Integer, struct_],
    ctx_List] :=
  CreateTypeProjection[leanExprToType[struct, ctx],
    CreateLiteralType[fieldIndex, "MachineInteger"]];

leanExprToType[LeanMData[_, expr_], ctx_List] :=
  leanExprToType[expr, ctx];

leanExprToType[expr_] := leanExprToType[expr, {}];


(* ---- Public API ---- *)

LeanExprToType[expr_] := leanExprToType[expr, {}];

LeanExprToType[term_LeanTerm] :=
  With[{expr = term[[1]]["_Expr"]},
    If[MissingQ[expr], $Failed, leanExprToType[expr, {}]]];

LeanCompileTyped[term_LeanTerm] := Module[
  {fn, cf, typeExpr, tyObj},
  fn = LeanToFunction[term];
  If[FailureQ[fn], Return[$Failed]];
  cf = FunctionCompile[fn];
  If[Head[cf] =!= CompiledCodeFunction, Return[cf]];
  (* Try to extract and attach the dependent type *)
  typeExpr = term[[1]]["_Expr"];
  If[!MissingQ[typeExpr],
    tyObj = Quiet[leanExprToType[typeExpr, {}]];
    If[TypeObjectQ[tyObj],
      With[{newMeta = cf[[1]]},
        newMeta["Signature"] = TypeSpecifier[tyObj["unresolve"]];
        Return[ReplacePart[cf,
          {1 -> newMeta, 6 -> tyObj["unresolve"]}]]]]];
  cf];

(* test_lazy_import.wls -- Tests for lazy LeanImport *)
(* Run: wolframscript -f test_lazy_import.wls *)

PacletDirectoryLoad[DirectoryName[DirectoryName[$InputFileName]]];
Needs["LeanLink`"];

nativeDir = FileNameJoin[{PacletObject["LeanLink"]["Location"], "Native"}];
pass = 0; fail = 0;

check[label_String, test_, expected_] := Module[{result},
  result = test;
  If[MatchQ[result, expected],
    pass++; Print["\[Checkmark] ", label],
    fail++; Print["\[Cross] ", label, " — got: ", Short[result, 1], " expected: ", Short[expected, 1]]]];

checkTrue[label_String, test_] := Module[{result},
  result = test;
  If[TrueQ[result],
    pass++; Print["\[Checkmark] ", label],
    fail++; Print["\[Cross] ", label, " — got: ", Short[result, 1]]]];

(* =============================== *)
(* Import tests                     *)
(* =============================== *)

Print["\n=== LeanImport ==="];

{importTime, env} = AbsoluteTiming[
  LeanImport["LeanLink.Examples", "ProjectDir" -> nativeDir, "Imports" -> {"LeanLink"}]];
Print["Import time: ", importTime, "s (", Length[env], " constants)"];

checkTrue["Import returns Association", AssociationQ[env]];
checkTrue["Import time < 2s", importTime < 2];

(* Filtered import *)
filtered = LeanImport["LeanLink.Examples", "ProjectDir" -> nativeDir,
  "Imports" -> {"LeanLink"}, "Filter" -> "Examples"];

checkTrue["Filtered returns Association", AssociationQ[filtered]];
check["Filtered count", Length[filtered], 12];
checkTrue["modus_ponens in filtered", KeyExistsQ[filtered, "LeanLink.Examples.modus_ponens"]];
checkTrue["Vec.head in filtered", KeyExistsQ[filtered, "LeanLink.Examples.Vec.head"]];

(* =============================== *)
(* LeanTerm lazy properties         *)
(* =============================== *)

Print["\n=== LeanTerm Properties ==="];

mp = filtered["LeanLink.Examples.modus_ponens"];

check["Kind", mp["Kind"], "theorem"];
check["Name", mp["Name"], "LeanLink.Examples.modus_ponens"];
check["Type head", Head[mp["Type"]], LeanForall];
check["Term head", Head[mp["Term"]], LeanLam];
check["Properties list", mp["Properties"],
  {"Name", "Kind", "Type", "Term", "TypeRefs", "TermRefs", "ExprGraph", "CallGraph"}];

(* Vec.head has richer refs *)
vh = filtered["LeanLink.Examples.Vec.head"];
check["Vec.head Kind", vh["Kind"], "def"];
checkTrue["Vec.head Type is LeanForall", MatchQ[vh["Type"], _LeanForall]];
checkTrue["Vec.head TypeRefs non-empty", Length[vh["TypeRefs"]] > 0];
checkTrue["Vec.head TermRefs non-empty", Length[vh["TermRefs"]] > 0];
checkTrue["Nat in TypeRefs", MemberQ[vh["TypeRefs"], "Nat"]];

(* Axiom constants *)
addz = filtered["LeanLink.Examples.add_zero"];
check["add_zero Kind", addz["Kind"], "theorem"];
checkTrue["add_zero Type is LeanForall", MatchQ[addz["Type"], _LeanForall]];

(* =============================== *)
(* Error handling                   *)
(* =============================== *)

Print["\n=== Error Handling ==="];

(* Non-existent constant queried via a fabricated LeanTerm *)
bogus = LeanTerm[<|"Name" -> "Nonexistent.bogus", "Kind" -> "def",
  "_Handle" -> Lookup[mp[[1]], "_Handle"]|>];
check["Bogus Type -> $Failed", bogus["Type"], $Failed];
check["Bogus Term -> $Failed", bogus["Term"], $Failed];
check["Bogus TypeRefs -> {}", bogus["TypeRefs"], {}];

(* Private fields *)
checkTrue["_Handle blocked", MatchQ[mp["_Handle"], _Missing]];

(* =============================== *)
(* CallGraph                        *)
(* =============================== *)

Print["\n=== CallGraph ==="];

cg = vh["CallGraph"];
checkTrue["CallGraph is Graph", MatchQ[cg, _Graph]];
checkTrue["CallGraph has nodes", VertexCount[cg] > 1];
checkTrue["CallGraph has edges", EdgeCount[cg] > 0];

(* ExprGraph *)
eg = vh["ExprGraph"];
checkTrue["ExprGraph is Graph", MatchQ[eg, _Graph]];
checkTrue["ExprGraph has nodes", VertexCount[eg] > 1];

(* =============================== *)
(* Cache behavior                   *)
(* =============================== *)

Print["\n=== Cache (second fetch faster) ==="];

{t1, r1} = AbsoluteTiming[mp["Type"]];
{t2, r2} = AbsoluteTiming[mp["Type"]];
Print["First Type: ", t1, "s, Second: ", t2, "s"];
checkTrue["Cached fetch faster (or same)", t2 <= t1 + 0.001];

(* =============================== *)
(* Summary                          *)
(* =============================== *)

Print["\n=== Results: ", pass, " passed, ", fail, " failed ==="];
If[fail > 0, Exit[1]];

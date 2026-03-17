(* ::Package:: *)
(* Lean.wl -- Native Lean integration via LibraryLink *)

BeginPackage["LeanLink`"];

(* ============================================================================ *)
(* Expression heads                                                             *)
(* ============================================================================ *)

LeanApp::usage = "LeanApp[fn, arg] represents Lean function application (fn arg).";
LeanLam::usage = "LeanLam[name, type, body, binder] represents a Lean \[Lambda]-abstraction. \
binder is \"default\" (explicit), \"implicit\" ({x}), \"instImplicit\" ([x]), or \"strictImplicit\" (\[LeftDoubleBracket]x\[RightDoubleBracket]).";
LeanForall::usage = "LeanForall[name, domain, body, binder] represents a Lean \[ForAll]/\[Rule] type. \
A non-dependent forall (arrow type) has name \"_\".";
LeanLet::usage = "LeanLet[name, type, value, body] represents a let-binding (let name : type := value; body).";
LeanConst::usage = "LeanConst[name, universes] represents a reference to a declared constant at given universe levels.";
LeanBVar::usage = "LeanBVar[index] represents a bound variable by de Bruijn index (0 = innermost binder).";
LeanFVar::usage = "LeanFVar[id] represents a free variable (local hypothesis or function parameter).";
LeanMVar::usage = "LeanMVar[id] represents a metavariable (unresolved placeholder in elaboration).";
LeanSort::usage = "LeanSort[level] represents a universe. LeanSort[LeanLevelZero[]] is Prop, LeanSort[LeanLevelSucc[LeanLevelZero[]]] is Type.";
LeanLitNat::usage = "LeanLitNat[n] represents a Lean natural number literal.";
LeanLitStr::usage = "LeanLitStr[s] represents a Lean string literal.";
LeanProj::usage = "LeanProj[typeName, fieldIndex, struct] represents a structure field projection.";
LeanTruncated::usage = "LeanTruncated[info] indicates the expression was truncated at the depth limit. \
Increase \"Depth\" to see deeper.";
LeanNoValue::usage = "LeanNoValue[] indicates a constant with no definition body (axioms, opaques).";

(* Level heads *)
LeanLevelZero::usage = "LeanLevelZero[] is universe level 0 (the level of Prop).";
LeanLevelSucc::usage = "LeanLevelSucc[level] is the successor of a universe level.";
LeanLevelMax::usage = "LeanLevelMax[a, b] is the maximum of two universe levels.";
LeanLevelIMax::usage = "LeanLevelIMax[a, b] is the impredicative max (collapses to 0 when b is 0).";
LeanLevelParam::usage = "LeanLevelParam[name] is a named universe parameter (e.g. u, v).";
LeanLevelMVar::usage = "LeanLevelMVar[id] is a universe metavariable.";

(* Raw constant *)
LeanConstant::usage = "LeanConstant[name, kind, type, term] is raw constant info from the native shim.";

(* Unified typed constant *)
LeanTerm::usage = "LeanTerm[\[LeftAssociation]\"Name\"\[Rule]..., \"Kind\"\[Rule]..., \"Type\"\[Rule]..., \"Term\"\[Rule]...\[RightAssociation]] \
represents a Lean constant. Access properties via term[\"prop\"]. \
Properties: \"Name\", \"Kind\", \"Type\", \"Term\", \"ExprGraph\", \"CallGraph\".";

(* Public API *)
LeanEnvironment::usage = "LeanEnvironment[<|name \[Rule] LeanTerm[...], ...|>] holds a collection of Lean constants.";
LeanImport::usage = "LeanImport[module, opts] imports constants from a Lean module. Returns LeanEnvironment[...].";
LeanExpr::usage = "LeanExpr[name, opts] returns the type of a Lean constant as a symbolic expression tree.";
LeanValue::usage = "LeanValue[name, opts] returns the proof/definition body of a Lean constant.";
LeanConstantInfo::usage = "LeanConstantInfo[name, opts] returns full constant info as LeanConstant[name, kind, type, term].";
LeanListConstants::usage = "LeanListConstants[opts] lists all constants as \[LeftAssociation]name \[Rule] LeanConstant[...], ...\[RightAssociation].";
LeanLoadEnvironment::usage = "LeanLoadEnvironment[{\"Module1\", ...}, searchPath] loads a Lean environment handle for repeated queries.";
LeanFreeEnvironment::usage = "LeanFreeEnvironment[handle] frees a loaded Lean environment and releases memory.";

(* Interactive proof objects *)
LeanState::usage = "LeanState[term] opens a proof goal. LeanState[<|...|>] holds proof state. Properties: \"Goals\", \"Complete\", \"GoalCount\".";
LeanTactic::usage = "LeanTactic[tacStr] represents a tactic. Apply via LeanTactic[tac][state] \[Rule] new LeanState.";
LeanGoal::usage = "LeanGoal[<|...|>] represents a single proof goal with target and context.";

(* Source conversion *)
LeanExportString::usage = "LeanExportString[env] converts a LeanEnvironment to a Lean 4 source code string.";
LeanExport::usage = "LeanExport[file, env] exports a LeanEnvironment to a .lean file.";
LeanImportString::usage = "LeanImportString[src] compiles a Lean 4 source string and returns LeanEnvironment[...].";
ProofToLean::usage = "ProofToLean[proof] transpiles a ProofObject to a LeanEnvironment.";

(* Compilation *)
LeanToFunction::usage = "LeanToFunction[term] converts a Lean definition (LeanTerm of kind \"def\") to a Function with Typed arguments suitable for FunctionCompile.";
LeanCompile::usage = "LeanCompile[term] compiles a Lean definition to native code via FunctionCompile. LeanCompile[env] compiles all eligible definitions in a LeanEnvironment.";

Begin["`Private`"];

(* ============================================================================ *)
(* Shim library                                                                 *)
(* ============================================================================ *)

$ShimLib := $ShimLib = Module[{loc, pacletDir, devDir, libName, sysDir},
  (* Platform-specific library name and directory *)
  libName = Switch[$SystemID,
    "MacOSX-ARM64" | "MacOSX-x86-64", "libLeanLinkShim.dylib",
    "Windows-x86-64", "LeanLinkShim.dll",
    _, "libLeanLinkShim.so"];
  sysDir = $SystemID;
  (* Standard paclet location: LibraryResources inside paclet *)
  pacletDir = Quiet[PacletObject["LeanLink"]["Location"]];
  If[StringQ[pacletDir],
    loc = FileNameJoin[{pacletDir, "LibraryResources", sysDir, libName}];
    If[FileExistsQ[loc], Return[loc, Module]]];
  (* Dev fallback: Native/ is sibling of the LeanLink/ paclet dir *)
  devDir = DirectoryName[DirectoryName[$InputFileName]];
  loc = FileNameJoin[{DirectoryName[devDir],
    "Native", ".lake", "build", "lib", libName}];
  If[FileExistsQ[loc], loc, $Failed]];

(* Dev project root: set only when Native/ exists as sibling (dev mode) *)
$DevProjectRoot = With[{candidate = DirectoryName[DirectoryName[DirectoryName[$InputFileName]]]},
  If[DirectoryQ[FileNameJoin[{candidate, "Native"}]], candidate, None]];

LeanLink::nolib = "Shim library not found. Run 'lake build' in the Native/ directory first.";
LeanLink::err = "Lean error: `1`";
LeanLink::abort = "Native call aborted: `1`";

$loadEnvFn := $loadEnvFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_load_env", {"UTF8String", "UTF8String"}, Integer];
$freeEnvFn := $freeEnvFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_free_env", {Integer}, "Void"];
$listTheoremsFn := $listTheoremsFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_list_theorems", {Integer, "UTF8String"}, {Integer, 1}];
$getTypeFn := $getTypeFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_get_type", {Integer, "UTF8String", Integer}, {Integer, 1}];
$getValueFn := $getValueFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_get_value", {Integer, "UTF8String", Integer}, {Integer, 1}];
$getConstantFn := $getConstantFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_get_constant", {Integer, "UTF8String"}, {Integer, 1}];
$getUsedConstantsFn := $getUsedConstantsFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_get_used_constants", {Integer, "UTF8String"}, {Integer, 1}];
$listConstantNamesFn := $listConstantNamesFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_list_constant_names", {Integer, "UTF8String"}, {Integer, 1}];
$listConstantKindsFn := $listConstantKindsFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_list_constant_kinds", {Integer, "UTF8String"}, {Integer, 1}];
$getTypeUnfoldedFn := $getTypeUnfoldedFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_get_type_unfolded", {Integer, "UTF8String", Integer}, {Integer, 1}];
$getValueUnfoldedFn := $getValueUnfoldedFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_get_value_unfolded", {Integer, "UTF8String", Integer}, {Integer, 1}];
$ppTypeFn := $ppTypeFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_pp_type", {Integer, "UTF8String", Integer}, {Integer, 1}];
$ppValueFn := $ppValueFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_pp_value", {Integer, "UTF8String", Integer}, {Integer, 1}];
$typeCheckFn := $typeCheckFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_type_check", {Integer, {Integer, 1}}, {Integer, 1}];
$openGoalFn := $openGoalFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_open_goal", {Integer, "UTF8String"}, {Integer, 1}];
$applyTacticFn := $applyTacticFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_apply_tactic", {Integer, "UTF8String"}, {Integer, 1}];
$openGoalExprFn := $openGoalExprFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_open_goal_expr", {Integer, {Integer, 1}}, {Integer, 1}];
$ppExprFn := $ppExprFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_pp_expr", {Integer, {Integer, 1}}, {Integer, 1}];

decodeWXF[tensor_] := BinaryDeserialize[ByteArray[Flatten[tensor]]];

(* ============================================================================ *)
(* Utilities                                                                    *)
(* ============================================================================ *)

cleanName[s_String] := StringReplace[s, RegularExpression["\\._@\\..*"] -> ""];
cleanName[other_] := other;

(* Match code.lean shortConstName: strip ._@. and ._hyg. suffixes, keep full name *)
shortName[s_String] := StringReplace[s, {
  RegularExpression["\\._@\\..*"] -> "",
  RegularExpression["\\._hyg\\..*"] -> ""}];

(* ============================================================================ *)
(* Environment management                                                       *)
(* ============================================================================ *)

resolveSearchPath[projDir_String] := Module[{buildLib, leanLib, pkgDirs, paths},
  (* Lake v5 puts oleans under .lake/build/lib/lean/ ; Lake v4 uses .lake/build/lib/ *)
  buildLib = With[{v5 = FileNameJoin[{projDir, ".lake", "build", "lib", "lean"}],
                   v4 = FileNameJoin[{projDir, ".lake", "build", "lib"}]},
    If[DirectoryQ[v5], v5, v4]];
  (* Discover lake package build directories -- prefer lib/lean/ (v5), fallback lib/ (v4) *)
  pkgDirs = Module[{pkgsRoot = FileNameJoin[{projDir, ".lake", "packages"}]},
    If[DirectoryQ[pkgsRoot],
      Select[
        (With[{v5 = FileNameJoin[{#, ".lake", "build", "lib", "lean"}],
               v4 = FileNameJoin[{#, ".lake", "build", "lib"}]},
          If[DirectoryQ[v5], v5, v4]] & /@ FileNames["*", pkgsRoot]),
        DirectoryQ],
      {}]];
  leanLib = Module[{dir = projDir, tc, version, toolchainDir},
    While[StringLength[dir] > 1,
      tc = FileNameJoin[{dir, "lean-toolchain"}];
      If[FileExistsQ[tc],
        version = StringTrim[Import[tc, "Text"]];
        toolchainDir = StringReplace[version, {"/" -> "--", ":" -> "---"}];
        Return[FileNameJoin[{$HomeDirectory, ".elan", "toolchains",
          toolchainDir, "lib", "lean"}], Module]];
      dir = DirectoryName[dir]];
    Nothing];
  paths = Select[Join[{buildLib}, pkgDirs, {leanLib}], StringQ[#] && DirectoryQ[#] &];
  StringRiffle[paths, ":"]];

$envCache = <||>;

getOrLoadEnv[projDir_String, imports_List] := Module[{key, searchPath, handle},
  key = {projDir, imports};
  If[KeyExistsQ[$envCache, key], Return[$envCache[key]]];
  searchPath = resolveSearchPath[projDir];
  handle = $loadEnvFn[StringRiffle[imports, ","], searchPath];
  If[handle === 0 || !IntegerQ[handle],
    Message[LeanLink::err, "Failed to load environment"]; Return[$Failed]];
  $envCache[key] = handle; handle];

callNative[fn_, args_List, projDir_, imports_] := Module[{handle, result},
  If[$ShimLib === $Failed, Message[LeanLink::nolib]; Return[$Failed]];
  handle = getOrLoadEnv[projDir, imports];
  If[handle === $Failed, Return[$Failed]];
  result = fn @@ Prepend[args, handle];
  decodeWXF[result]];

resolveProjDir[pd_] := Replace[pd, {
  Automatic -> Directory[],
  s_String /; StringStartsQ[s, "~/"] :> FileNameJoin[{$HomeDirectory, StringDrop[s, 2]}]
}];

(* ============================================================================ *)
(* LeanTerm                                                                     *)
(* ============================================================================ *)

(* Colors for LeanTerm summary icon *)
$kindColor = <|
  "theorem" -> RGBColor[0.25, 0.45, 0.85],
  "def" -> RGBColor[0.2, 0.65, 0.35],
  "axiom" -> RGBColor[0.85, 0.25, 0.2],
  "inductive" -> RGBColor[0.55, 0.3, 0.75],
  "constructor" -> RGBColor[0.85, 0.5, 0.15],
  "recursor" -> GrayLevel[0.45],
  "opaque" -> GrayLevel[0.45],
  "quot" -> GrayLevel[0.45]
|>;

(* Call graph node colors -- match code.lean DOT output *)
$callNodeColor = <|
  "theorem" -> RGBColor @@ ({200, 230, 201} / 255.),   (* #c8e6c9 *)
  "def" -> RGBColor @@ ({187, 222, 251} / 255.),       (* #bbdefb *)
  "structure" -> RGBColor @@ ({255, 249, 196} / 255.), (* #fff9c4 *)
  "inductive" -> RGBColor @@ ({255, 249, 196} / 255.),
  "constructor" -> RGBColor @@ ({225, 190, 231} / 255.), (* #e1bee7 *)
  "axiom" -> RGBColor @@ ({255, 205, 210} / 255.),     (* #ffcdd2 *)
  "recursor" -> RGBColor @@ ({255, 224, 178} / 255.),  (* #ffe0b2 *)
  "opaque" -> GrayLevel[0.88],
  "quot" -> GrayLevel[0.88]
|>;

$callEdgeColor = <|
  "term" -> RGBColor @@ ({51, 51, 51} / 255.),
  "type" -> RGBColor @@ ({153, 153, 153} / 255.),
  "term+type" -> RGBColor @@ ({21, 101, 192} / 255.),
  "ref" -> RGBColor @@ ({102, 102, 102} / 255.)
|>;

(* --- Lazy fetch cache: keyed by {handle, name, field} --- *)
$termCache = <||>;

isFFIError[r_] := StringQ[r] && StringStartsQ[r, "ERROR"];

fetchField[handle_Integer, name_String, "Type"] :=
  Lookup[$termCache, Key[{handle, name, "Type"}],
    $termCache[{handle, name, "Type"}] =
      With[{r = Quiet[decodeWXF[$getTypeFn[handle, name, 100]]]},
        If[isFFIError[r], $Failed, r]]];

fetchField[handle_Integer, name_String, "Term"] :=
  Lookup[$termCache, Key[{handle, name, "Term"}],
    $termCache[{handle, name, "Term"}] =
      With[{r = Quiet[decodeWXF[$getValueFn[handle, name, 100]]]},
        If[isFFIError[r], $Failed,
          If[StringQ[r] && StringStartsQ[r, "No value"], LeanNoValue[], r]]]];

fetchField[handle_Integer, name_String, "TypeRefs"] :=
  Lookup[$termCache, Key[{handle, name, "TypeRefs"}],
    Module[{uc},
      uc = Quiet[decodeWXF[$getUsedConstantsFn[handle, name]]];
      $termCache[{handle, name, "TypeRefs"}] =
        If[AssociationQ[uc], Lookup[uc, "type", {}], {}];
      $termCache[{handle, name, "TermRefs"}] =
        If[AssociationQ[uc], Lookup[uc, "value", {}], {}];
      $termCache[{handle, name, "TypeRefs"}]]];

fetchField[handle_Integer, name_String, "TermRefs"] :=
  Lookup[$termCache, Key[{handle, name, "TermRefs"}],
    (* Fetching TypeRefs also populates TermRefs *)
    fetchField[handle, name, "TypeRefs"];
    Lookup[$termCache, Key[{handle, name, "TermRefs"}], {}]];

(* Unfold-level fetch -- not cached (level-dependent) *)
fetchUnfolded[handle_Integer, name_String, "Type", level_Integer] :=
  With[{r = Quiet[decodeWXF[$getTypeUnfoldedFn[handle, name, level]]]},
    If[isFFIError[r], $Failed, r]];

fetchUnfolded[handle_Integer, name_String, "Term", level_Integer] :=
  With[{r = Quiet[decodeWXF[$getValueUnfoldedFn[handle, name, level]]]},
    If[isFFIError[r], $Failed,
      If[StringQ[r] && StringStartsQ[r, "No value"], LeanNoValue[], r]]];

(* ============================================================================ *)
(* Constructable LeanTerm -- build from WL expression heads                      *)
(* ============================================================================ *)

(* Wrap a bare expression into a LeanTerm *)
LeanTerm[expr : _LeanApp | _LeanConst | _LeanForall | _LeanLam | _LeanBVar |
                _LeanSort | _LeanLitNat | _LeanLitStr | _LeanLet | _LeanProj] :=
  LeanTerm[<|"Name" -> "user_expr", "Kind" -> "expr", "_Expr" -> expr|>];



(* Constructor with env -- binds handle for type-checking *)
LeanTerm[expr : _LeanApp | _LeanConst | _LeanForall | _LeanLam | _LeanBVar |
                _LeanSort | _LeanLitNat | _LeanLitStr | _LeanLet | _LeanProj,
          env_LeanEnvironment] :=
  With[{h = extractHandle[env]},
    If[IntegerQ[h],
      LeanTerm[<|"Name" -> "user_expr", "Kind" -> "expr", "_Expr" -> expr, "_Handle" -> h|>],
      LeanTerm[<|"Name" -> "user_expr", "Kind" -> "expr", "_Expr" -> expr|>]]];

(* Also accept bare Association for backward compat *)
LeanTerm[expr : _LeanApp | _LeanConst | _LeanForall | _LeanLam | _LeanBVar |
                _LeanSort | _LeanLitNat | _LeanLitStr | _LeanLet | _LeanProj,
          env_Association] :=
  With[{h = Lookup[Values[env][[1]][[1]], "_Handle", None]},
    If[IntegerQ[h],
      LeanTerm[<|"Name" -> "user_expr", "Kind" -> "expr", "_Expr" -> expr, "_Handle" -> h|>],
      LeanTerm[<|"Name" -> "user_expr", "Kind" -> "expr", "_Expr" -> expr|>]]];

(* Extract handle from a LeanEnvironment *)
extractHandle[env_LeanEnvironment] := Lookup[env[[1]], "_Handle", None];
extractHandle[env_Association] := Lookup[env, "_Handle", None];

(* Internal type-check helper *)
typeCheck[expr_, handle_Integer] :=
  Module[{wxfBytes, result},
    wxfBytes = Normal[BinarySerialize[expr]];
    result = Quiet[decodeWXF[$typeCheckFn[handle, wxfBytes]]];
    If[AssociationQ[result], result, $Failed]];

(* Peel nested LeanForall chain into parameter list *)
binderKindName["default"] = "explicit";
binderKindName["implicit"] = "implicit";
binderKindName["strictImplicit"] = "implicit";
binderKindName["instImplicit"] = "instance";
binderKindName[_] = "explicit";

peelForalls[expr_] := peelForalls[expr, "Params"];
peelForalls[LeanForall[name_, type_, body_, binder_], "Params"] :=
  Prepend[peelForalls[body, "Params"],
    <|"Name" -> name, "Type" -> type, "TypeForm" -> leanPP[type],
      "Binder" -> binderKindName[binder]|>];
peelForalls[_, "Params"] := {};
peelForalls[LeanForall[_, _, body_, _], "Body"] := peelForalls[body, "Body"];
peelForalls[body_, "Body"] := body;

(* Property access -- lazy fetch from handle *)
(* Second arg: integer unfold level for Type/Term/TypeForm/TermForm, or Rule opts *)
(* Level 0 = no unfolding (default). Level N = unfold definitions N times. *)
LeanTerm /: LeanTerm[data_Association][prop_String, args___] :=
  Module[{handle = Lookup[data, "_Handle", None], name = Lookup[data, "Name", ""],
          level = Replace[First[{args}, 0], Except[_Integer] -> 0],
          opts = Cases[{args}, _Rule],
          expr = Lookup[data, "_Expr", None]},
    (* For constructed expressions, handle Type/TypeForm specially *)
    If[expr =!= None && IntegerQ[handle] && MatchQ[prop, "Type" | "TypeForm"],
      With[{tc = typeCheck[expr, handle]},
        If[AssociationQ[tc],
          If[prop === "Type", tc["Type"], tc["TypeForm"]],
          $Failed]],
    (* Normal property dispatch for imported terms *)
    Switch[prop,
      "Properties", {"Name", "Kind", "Type", "Term", "TypeForm", "TermForm",
        "TypeRefs", "TermRefs", "ExprGraph", "CallGraph", "Parameters", "Body"},
      "Parameters", peelForalls[LeanTerm[data]["Type"]],
      "Body", peelForalls[LeanTerm[data]["Type"], "Body"],
      "Name", data["Name"],
      "Kind", data["Kind"],
      "Type",
        If[KeyExistsQ[data, "Type"] && level === 0, data["Type"],
          If[IntegerQ[handle],
            If[level > 0,
              fetchUnfolded[handle, name, "Type", level],
              fetchField[handle, name, "Type"]],
            (* Fallback to _TypeExpr for ProofToLean terms *)
            If[KeyExistsQ[data, "_TypeExpr"], data["_TypeExpr"],
              Missing["NoHandle"]]]],
      "Term",
        If[KeyExistsQ[data, "Term"] && level === 0, data["Term"],
          If[IntegerQ[handle],
            If[level > 0,
              fetchUnfolded[handle, name, "Term", level],
              fetchField[handle, name, "Term"]],
            (* Fallback to _Tactic for ProofToLean terms *)
            If[KeyExistsQ[data, "_Tactic"], data["_Tactic"],
              Missing["NoHandle"]]]],
      "TypeForm",
        With[{typeExpr = LeanTerm[data]["Type", level]},
          If[MatchQ[typeExpr, _Missing | $Failed], Missing["NoHandle"], leanPP[typeExpr]]],
      "TermForm",
        If[IntegerQ[handle],
          With[{r = Quiet[decodeWXF[$ppValueFn[handle, name, level]]]},
            If[StringQ[r], r, leanPP[LeanTerm[data]["Term", level]]]],
          (* Fallback: use tacticSource for _Tactic *)
          With[{tactic = If[KeyExistsQ[data, "_Tactic"], data["_Tactic"],
                  LeanTerm[data]["Term", level]]},
            If[Head[tactic] === LeanTactic, tacticSource[tactic],
              If[MatchQ[tactic, _Missing], Missing["NoHandle"], leanPP[tactic]]]]],
      "TypeRefs",
        If[KeyExistsQ[data, "TypeRefs"], data["TypeRefs"],
          If[IntegerQ[handle], fetchField[handle, name, "TypeRefs"], {}]],
      "TermRefs",
        If[KeyExistsQ[data, "TermRefs"], data["TermRefs"],
          If[IntegerQ[handle], fetchField[handle, name, "TermRefs"], {}]],
      "ExprGraph", exprToGraph[
        With[{term = LeanTerm[data]["Term"]},
          Replace[term, LeanNoValue[] -> LeanTerm[data]["Type"]]]],
      "CallGraph", callGraph[data, Sequence @@ opts],
      _, If[StringStartsQ[prop, "_"], Missing["Private", prop], data[prop]]]]];


(* ============================================================================ *)
(* Expression Graph                                                             *)
(* ============================================================================ *)

(* Expr graph node background colors -- match code.lean exprKindColor exactly *)
$headColor = <|
  LeanApp     -> RGBColor @@ ({225, 190, 231} / 255.),  (* #e1bee7 *)
  LeanLam     -> RGBColor @@ ({255, 249, 196} / 255.),  (* #fff9c4 *)
  LeanForall  -> RGBColor @@ ({255, 224, 178} / 255.),  (* #ffe0b2 *)
  LeanLet     -> RGBColor @@ ({178, 223, 219} / 255.),  (* #b2dfdb *)
  LeanConst   -> RGBColor @@ ({187, 222, 251} / 255.),  (* #bbdefb *)
  LeanBVar    -> RGBColor @@ ({245, 245, 245} / 255.),  (* #f5f5f5 *)
  LeanSort    -> RGBColor @@ ({215, 204, 200} / 255.),  (* #d7ccc8 *)
  LeanLitNat  -> RGBColor @@ ({200, 230, 201} / 255.),  (* #c8e6c9 *)
  LeanLitStr  -> RGBColor @@ ({200, 230, 201} / 255.),  (* #c8e6c9 *)
  LeanProj    -> RGBColor @@ ({179, 229, 252} / 255.),  (* #b3e5fc *)
  LeanTruncated -> RGBColor @@ ({224, 224, 224} / 255.),(* #e0e0e0 *)
  LeanNoValue -> RGBColor @@ ({224, 224, 224} / 255.)   (* #e0e0e0 *)
|>;

exprToGraph[expr_] := Module[{id = 0, verts = {}, edges = {}, lbls = <||>, cols = <||>, kinds = <||>, walk},
  walk[e_] := Module[{myId, label, col, children, edgeLbls},
    myId = ++id;
    {label, col, children, edgeLbls} = exprNodeInfo[e];
    AppendTo[verts, myId];
    AssociateTo[lbls, myId -> label];
    AssociateTo[cols, myId -> col];
    AssociateTo[kinds, myId -> Replace[Head[e], {LeanForall -> "forall", LeanLam -> "lam", LeanApp -> "app",
      LeanConst -> "const", LeanBVar -> "bvar", LeanSort -> "sort", LeanLet -> "let",
      LeanLitNat -> "litNat", LeanLitStr -> "litStr", LeanProj -> "proj", _ -> "?"}]];
    MapThread[Function[{child, elbl}, Module[{childId = walk[child]},
      AppendTo[edges, DirectedEdge[myId, childId, elbl]]]],
      {children, edgeLbls}];
    myId];
  walk[expr];
  If[Length[verts] == 0, Return[Graph[{}]]];
  Graph[verts, edges,
    VertexShapeFunction -> Map[
      With[{bg = cols[#], lbl = lbls[#], kind = kinds[#]},
        # -> Function[
          Inset[Framed[
            Style[Tooltip[lbl, kind], "Text", FontSize -> 7,
              LightDarkSwitched[
                If[ColorDistance[bg, White] > 0.4, White, Black],
                If[ColorDistance[bg, Black] > 0.4, White, GrayLevel[0.9]]],
              Bold],
            Background -> LightDarkSwitched[bg],
            RoundingRadius -> 3,
            FrameStyle -> LightDarkSwitched[GrayLevel[0.4], GrayLevel[0.6]],
            FrameMargins -> {{3, 3}, {1, 1}}], #1, #3]]
      ] &, verts],
    GraphLayout -> {"LayeredDigraphEmbedding", "Orientation" -> Top},
    VertexSize -> If[Length[verts] <= 10, 0.3, 0.05],
    EdgeStyle -> Directive[GrayLevel[0.5], Arrowheads[0.02]],
    EdgeLabels -> (# -> Style[#[[3]], FontSize -> 5, FontFamily -> "Menlo",
      LightDarkSwitched[GrayLevel[0.3], GrayLevel[0.7]]] & /@ edges),
    ImageSize -> Max[300, Min[1200, 40 * Length[verts]]],
    AspectRatio -> 1/2,
    PerformanceGoal -> "Quality"]];

exprNodeInfo[LeanForall[n_, dom_, body_, bi_]] :=
  {"\[ForAll] " <> cleanName[n], $headColor[LeanForall], {dom, body}, {"type", "body"}};
exprNodeInfo[LeanLam[n_, type_, body_, _]] :=
  {"\[Lambda] " <> cleanName[n], $headColor[LeanLam], {type, body}, {"type", "body"}};
exprNodeInfo[LeanApp[fn_, arg_]] :=
  {"app", $headColor[LeanApp], {fn, arg}, {"fn", "arg"}};
exprNodeInfo[LeanConst[n_, _]] :=
  {shortName[n], $headColor[LeanConst], {}, {}};
exprNodeInfo[LeanBVar[i_]] :=
  {"bvar " <> ToString[i], $headColor[LeanBVar], {}, {}};
(* Sort always shows level subtree, matching DOT walkExpr *)
exprNodeInfo[LeanSort[l_]] := {"Sort", $headColor[LeanSort], {l}, {"level"}};
(* Level nodes *)
exprNodeInfo[LeanLevelZero[]] := {"zero", RGBColor @@ ({215, 204, 200} / 255.), {}, {}};
exprNodeInfo[LeanLevelSucc[l_]] := {"succ", RGBColor @@ ({215, 204, 200} / 255.), {l}, {"level"}};
exprNodeInfo[LeanLevelMax[a_, b_]] := {"max", RGBColor @@ ({215, 204, 200} / 255.), {a, b}, {"left", "right"}};
exprNodeInfo[LeanLevelIMax[a_, b_]] := {"imax", RGBColor @@ ({215, 204, 200} / 255.), {a, b}, {"left", "right"}};
exprNodeInfo[LeanLevelParam[n_]] := {n, RGBColor @@ ({215, 204, 200} / 255.), {}, {}};
exprNodeInfo[LeanLet[n_, type_, val_, body_]] :=
  {"let " <> cleanName[n], $headColor[LeanLet], {type, val, body}, {"type", "val", "body"}};
exprNodeInfo[LeanLitNat[n_]] := {ToString[n], $headColor[LeanLitNat], {}, {}};
exprNodeInfo[LeanLitStr[s_]] := {"\"" <> s <> "\"", $headColor[LeanLitStr], {}, {}};
exprNodeInfo[LeanProj[t_, i_, struct_]] :=
  {shortName[t] <> "." <> ToString[i], $headColor[LeanProj], {struct}, {"struct"}};
exprNodeInfo[LeanTruncated[_]] := {"\[Ellipsis]", $headColor[LeanTruncated], {}, {}};
exprNodeInfo[LeanNoValue[]] := {"\[Dash]", $headColor[LeanNoValue], {}, {}};
exprNodeInfo[other_] := {ToString[Short[other]], GrayLevel[0.6], {}, {}};

(* ============================================================================ *)
(* Call Graph                                                                   *)
(* ============================================================================ *)

collectConsts[e_] := Union[Cases[e, LeanConst[n_String, _] :> n, Infinity]];

Options[callGraph] = {"Depth" -> 10};
callGraph[data_Association, opts___Rule] := Module[
  {name, handle,
   nodes, edgeList, frontier, visited,
   typeRefs, termRefs, allRefs, maxDepth, depth = 0,
   verts, edges, vertColors, fullNames, edgeStyles, edgeLabels,
   getKind, getVertColor, classifyEdge,
   kindCache, refsCache, getRefsFor},

  maxDepth = Lookup[{opts}, "Depth", 10];

  name = data["Name"];
  handle = Lookup[data, "_Handle", None];

  (* Cache for kinds and refs discovered during BFS *)
  kindCache = <|name -> Lookup[data, "Kind", "def"]|>;
  refsCache = <|name -> {
    If[KeyExistsQ[data, "TypeRefs"], data["TypeRefs"],
      If[IntegerQ[handle], fetchField[handle, name, "TypeRefs"], {}]],
    If[KeyExistsQ[data, "TermRefs"], data["TermRefs"],
      If[IntegerQ[handle], fetchField[handle, name, "TermRefs"], {}]]}|>;

  (* Query FFI for a constant's kind and refs, caching results *)
  getRefsFor[n_String] := If[KeyExistsQ[refsCache, n],
    refsCache[n],
    Module[{tRefs = {}, vRefs = {}, kind = "def"},
      If[IntegerQ[handle] && handle > 0,
        Quiet @ With[{r = decodeWXF[$getConstantFn[handle, n]]},
          If[MatchQ[r, LeanConstant[_, _String, __]],
            kind = r[[2]]]];
        Quiet @ With[{uc = decodeWXF[$getUsedConstantsFn[handle, n]]},
          If[AssociationQ[uc],
            tRefs = Lookup[uc, "type", {}];
            vRefs = Lookup[uc, "value", {}]]]];
      AssociateTo[kindCache, n -> kind];
      AssociateTo[refsCache, n -> {tRefs, vRefs}];
      {tRefs, vRefs}]];

  (* BFS from root *)
  nodes = <|name -> True|>;
  edgeList = {};
  frontier = {name};
  While[frontier =!= {} && depth < maxDepth,
    depth++;
    Module[{newFrontier = {}},
      Do[
        {typeRefs, termRefs} = getRefsFor[src];
        allRefs = Union[typeRefs, termRefs];
        (* Match code.lean isInternalName *)
        allRefs = Select[DeleteCases[allRefs, src],
          !StringContainsQ[#, "._" | ".match_" | ".proof_" | "._uniq" |
            ".brecOn" | ".below" | ".casesOn" | ".noConfusion"] &];
        Do[
          classifyEdge = Which[
            MemberQ[termRefs, ref] && MemberQ[typeRefs, ref], "term+type",
            MemberQ[termRefs, ref], "term",
            True, "type"];
          AppendTo[edgeList, {src, ref, classifyEdge}];
          If[!KeyExistsQ[nodes, ref],
            AssociateTo[nodes, ref -> True];
            getRefsFor[ref]; (* pre-cache kind *)
            AppendTo[newFrontier, ref]],
          {ref, allRefs}],
        {src, frontier}];
      frontier = newFrontier]];

  (* Kind lookup from cache, fall back to heuristic *)
  getKind[n_String] := Module[{k = Lookup[kindCache, n, None]},
    If[k =!= None, k,
      Which[
        StringEndsQ[n, ".rec"] || StringEndsQ[n, ".recOn"] ||
          StringEndsQ[n, ".casesOn"], "recursor",
        StringEndsQ[n, ".mk"] || StringContainsQ[n, ".mk."], "constructor",
        StringMatchQ[n, LetterCharacter ~~ ___] &&
          UpperCaseQ[StringTake[n, 1]], "structure",
        True, "def"]]];

  (* Colors matching code.lean *)
  getVertColor[n_String] :=
    Lookup[$callNodeColor, getKind[n], GrayLevel[0.88]];

  verts = shortName /@ Keys[nodes];
  edges = DeleteDuplicates[
    DirectedEdge[shortName[#[[1]]], shortName[#[[2]]], #[[3]]] & /@ edgeList];

  (* Per-vertex colors *)
  vertColors = Association[
    (shortName[#] -> getVertColor[#]) & /@ Keys[nodes]];

  (* Full name lookup for tooltips *)
  fullNames = Association[(shortName[#] -> #) & /@ Keys[nodes]];

  (* Edge styles matching code.lean *)
  edgeStyles = Table[
    With[{label = e[[3]],
          col = Lookup[$callEdgeColor, e[[3]], GrayLevel[0.33]],
          pw = Switch[e[[3]], "term", 1.5, "type", 0.8, "term+type", 1.5, _, 1.2]},
      e -> Directive[
        LightDarkSwitched[col, Lighter[col, 0.4]],
        AbsoluteThickness[pw],
        Arrowheads[0.01],
        If[label === "type", Dashing[{Small, Small}], Sequence @@ {}]]],
    {e, edges}];

  (* Edge labels *)
  edgeLabels = Table[
    With[{label = e[[3]],
          col = Lookup[$callEdgeColor, e[[3]], GrayLevel[0.4]]},
      e -> Style[label, FontSize -> 5, FontFamily -> "Menlo",
        LightDarkSwitched[col, GrayLevel[0.7]]]],
    {e, edges}];

  Graph[verts, edges,
    VertexShapeFunction -> Map[
      With[{bg = Lookup[vertColors, #, GrayLevel[0.88]], lbl = #,
            fullName = Lookup[fullNames, #, #],
            kind = getKind[Lookup[fullNames, #, #]]},
        # -> Function[
          Inset[Framed[
            Style[Tooltip[lbl, fullName <> " (" <> ToString[kind] <> ")"], "Text", FontSize -> 7,
              LightDarkSwitched[
                If[ColorDistance[bg, White] > 0.4, White, Black],
                If[ColorDistance[bg, Black] > 0.4, White, GrayLevel[0.9]]],
              Bold],
            Background -> LightDarkSwitched[bg],
            RoundingRadius -> 3,
            FrameStyle -> LightDarkSwitched[GrayLevel[0.4], GrayLevel[0.6]],
            FrameMargins -> {{3, 3}, {1, 1}}], #1, #3]]
      ] &, verts],
    GraphLayout -> {"LayeredDigraphEmbedding", "Orientation" -> Top},
    EdgeStyle -> edgeStyles,
    EdgeLabels -> edgeLabels,
    VertexSize -> If[Length[verts] <= 10, 0.3, 0.05],
    ImageSize -> Max[300, Min[1200, 40 * Length[verts]]],
    AspectRatio -> 1/2,
    PerformanceGoal -> "Quality"]];

(* ============================================================================ *)
(* LeanTerm SummaryBox                                                          *)
(* ============================================================================ *)

LeanTerm /: MakeBoxes[obj : LeanTerm[data_Association], StandardForm] := Module[
  {name, kind, typePP, termPP, col, icon, sn, nTypeRefs, nTermRefs},
  name = Lookup[data, "Name", "?"];
  kind = Lookup[data, "Kind", "?"];
  (* Use Lean's native pretty-printer for display *)
  typePP = Quiet[obj["TypeForm"]];
  termPP = Quiet[obj["TermForm"]];
  nTypeRefs = Length[obj["TypeRefs"]];
  nTermRefs = Length[obj["TermRefs"]];
  col = Lookup[$kindColor, kind, GrayLevel[0.5]];
  icon = Graphics[{col, Disk[]}, ImageSize -> 12];
  sn = shortName[name];

  BoxForm`ArrangeSummaryBox[LeanTerm, obj, icon,
    {
      BoxForm`SummaryItem[{"Kind: ", Style[kind, Bold, col]}],
      BoxForm`SummaryItem[{"Name: ", Style[sn, Bold]}]
    },
    {
      If[name =!= sn, BoxForm`SummaryItem[{"Full name: ", name}], Nothing],
      BoxForm`SummaryItem[{"Type: ",
        If[StringQ[typePP], Style[typePP, "Input"], "--"]}],
      If[StringQ[termPP] && termPP =!= "<pp error>",
        BoxForm`SummaryItem[{"Term: ", Style[Short[termPP, 1], "Input"]}],
        Nothing],
      If[nTypeRefs + nTermRefs > 0,
        BoxForm`SummaryItem[{"Refs: ",
          ToString[nTypeRefs] <> " type, " <> ToString[nTermRefs] <> " term"}],
        Nothing]
    },
    StandardForm,
    "Interpretable" -> Automatic]];

(* ============================================================================ *)
(* InterpretationBox helper                                                     *)
(* ============================================================================ *)

(* iBox evaluates displayBoxes FIRST, then wraps in InterpretationBox.
   This avoids the HoldAllComplete issue where With can't substitute
   inside raw InterpretationBox calls. *)
iBox[expr_, displayBoxes_] :=
  InterpretationBox[displayBoxes, expr];

(* ============================================================================ *)
(* Lean-style pretty-printer (string form)                                      *)
(* leanPP -- fallback pretty-printer for expressions without a handle.          *)
(* Lean's native PrettyPrinter.ppExpr is used when a handle is available.      *)

(* Proper de Bruijn substitution: replace BVar[cutoff] with FreeVar[name],
   shift down higher indices, tracking depth through binders *)
substBVar[expr_, name_String, cutoff_Integer] :=
  Switch[Head[expr],
    LeanBVar, Which[
      expr[[1]] === cutoff, LeanFreeVar[name],
      expr[[1]] > cutoff, LeanBVar[expr[[1]] - 1],
      True, expr],
    LeanForall, LeanForall[expr[[1]],
      substBVar[expr[[2]], name, cutoff],
      substBVar[expr[[3]], name, cutoff + 1],
      expr[[4]]],
    LeanLam, LeanLam[expr[[1]],
      substBVar[expr[[2]], name, cutoff],
      substBVar[expr[[3]], name, cutoff + 1],
      expr[[4]]],
    LeanLet, LeanLet[expr[[1]],
      substBVar[expr[[2]], name, cutoff],
      substBVar[expr[[3]], name, cutoff],
      substBVar[expr[[4]], name, cutoff + 1]],
    LeanApp, LeanApp[
      substBVar[expr[[1]], name, cutoff],
      substBVar[expr[[2]], name, cutoff]],
    LeanMData, LeanMData[expr[[1]], substBVar[expr[[2]], name, cutoff]],
    LeanProj, LeanProj[expr[[1]], expr[[2]], substBVar[expr[[3]], name, cutoff]],
    _, expr];
substBVar0[body_, name_String] := substBVar[body, name, 0];

leanPP[expr_] := leanPP[expr, 6];
leanPP[e_, 0] := Switch[Head[e],
  LeanConst, shortName[e[[1]]],
  LeanApp, leanPP[e[[1]], 0],
  LeanBVar, "#" <> ToString[e[[1]]],
  LeanFreeVar, cleanName[e[[1]]],
  LeanLitNat, ToString[e[[1]]],
  LeanLitStr, "\"" <> e[[1]] <> "\"",
  LeanSort, leanPP[e, 1],
  LeanForall, "\[ForAll]",
  LeanLam, "\[Lambda]",
  LeanLet, "let",
  LeanMData, leanPP[e[[2]], 0],
  _, ToString[Head[e]]];

leanPP[LeanConst[name_String, _List], _Integer] := shortName[name];

leanPP[LeanSort[LeanLevelZero[]], _] := "Prop";
leanPP[LeanSort[LeanLevelSucc[LeanLevelZero[]]], _] := "Type";
leanPP[LeanSort[LeanLevelSucc[l_]], _] := "Type " <> leanPPLevel[l];
leanPP[LeanSort[l_], _] := "Sort " <> leanPPLevel[l];

leanPPLevel[LeanLevelZero[]] := "0";
leanPPLevel[LeanLevelSucc[l_]] := ToString[levelToNat[l] + 1];
leanPPLevel[LeanLevelParam[name_String]] := name;
leanPPLevel[LeanLevelMax[a_, b_]] := "max " <> leanPPLevel[a] <> " " <> leanPPLevel[b];
leanPPLevel[LeanLevelIMax[a_, b_]] := "imax " <> leanPPLevel[a] <> " " <> leanPPLevel[b];
leanPPLevel[_] := "?";

levelToNat[LeanLevelZero[]] := 0;
levelToNat[LeanLevelSucc[l_]] := levelToNat[l] + 1;
levelToNat[_] := 0;

leanPP[LeanBVar[n_Integer], _] := "#" <> ToString[n];
leanPP[LeanFreeVar[name_String], _] := cleanName[name];
leanPP[LeanFVar[_], _] := "_fvar";
leanPP[LeanMVar[_], _] := "?_";
leanPP[LeanLitNat[n_Integer], _] := ToString[n];
leanPP[LeanLitStr[s_String], _] := "\"" <> s <> "\"";

(* Forall / Pi -- collect consecutive binders *)
leanPP[e : LeanForall[_, _, _, _], d_Integer] := Module[
  {binders = {}, body = e, name, dom, bi, nm},
  While[MatchQ[body, LeanForall[_, _, _, _]] && d - Length[binders] > 0,
    {name, dom, body, bi} = List @@ body;
    nm = cleanName[name];
    body = substBVar0[body, name];
    AppendTo[binders,
      Switch[bi,
        "implicit", "{" <> nm <> " : " <> leanPP[dom, d - 1] <> "}",
        "strictImplicit", "\[LeftDoubleBracket]" <> nm <> " : " <> leanPP[dom, d - 1] <> "\[RightDoubleBracket]",
        "instImplicit", "[" <> nm <> " : " <> leanPP[dom, d - 1] <> "]",
        _,
          If[nm === "" || StringMatchQ[nm, "_" ~~ ___],
            leanPP[dom, d - 1],
            "(" <> nm <> " : " <> leanPP[dom, d - 1] <> ")"]]]];
  If[AllTrue[binders, !StringStartsQ[#, "("] && !StringStartsQ[#, "{"] && !StringStartsQ[#, "["] && !StringStartsQ[#, "\[LeftDoubleBracket]"] &],
    StringRiffle[Append[binders, leanPP[body, d - 1]], " \[RightArrow] "],
    "\[ForAll] " <> StringRiffle[binders, " "] <> ", " <> leanPP[body, d - 1]]];

(* Lambda *)
leanPP[e : LeanLam[_, _, _, _], d_Integer] := Module[
  {binders = {}, body = e, name, dom, bi, nm},
  While[MatchQ[body, LeanLam[_, _, _, _]] && d - Length[binders] > 0,
    {name, dom, body, bi} = List @@ body;
    nm = cleanName[name];
    body = substBVar0[body, name];
    AppendTo[binders,
      Switch[bi,
        "implicit", "{" <> nm <> " : " <> leanPP[dom, d - 1] <> "}",
        "instImplicit", "[" <> nm <> " : " <> leanPP[dom, d - 1] <> "]",
        _,
          "(" <> nm <> " : " <> leanPP[dom, d - 1] <> ")"]]];
  "\[Lambda] " <> StringRiffle[binders, " "] <> " \[DoubleLongRightArrow] " <> leanPP[body, d - 1]];

leanPP[LeanLet[name_String, type_, val_, body_], d_Integer] :=
  "let " <> cleanName[name] <> " : " <> leanPP[type, d - 1] <>
  " := " <> leanPP[val, d - 1] <> "; " <> leanPP[body, d - 1];

(* Application -- notation-aware rules then generic fallback *)

(* Flatten app chain: LeanApp[LeanApp[f,a],b] -> {f, a, b} *)
flattenApp[e_LeanApp] := Module[{fn = e, args = {}},
  While[MatchQ[fn, LeanApp[_, _]],
    PrependTo[args, fn[[2]]]; fn = fn[[1]]];
  {fn, args}];

(* Extract head constant name *)
appHeadName[e_LeanApp] := With[{fa = flattenApp[e]},
  If[MatchQ[fa[[1]], LeanConst[_String, _]], fa[[1, 1]], None]];
appHeadName[_] := None;

(* Infix helper -- last 2 args *)
leanPPInfix[e_LeanApp, d_Integer, op_String] :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 2,
      leanPP[args[[-2]], d - 1] <> " " <> op <> " " <> leanPP[args[[-1]], d - 1],
      leanPP[flattenApp[e][[1]], d - 1] <> " " <> StringRiffle[leanPP[#, d - 1] & /@ args, " "]]];

(* Eq *)
leanPP[e_LeanApp, d_Integer] /;
  appHeadName[e] === "Eq" && Length[flattenApp[e][[2]]] >= 3 :=
  With[{args = flattenApp[e][[2]]},
    leanPP[args[[-2]], d - 1] <> " = " <> leanPP[args[[-1]], d - 1]];

(* Ne *)
leanPP[e_LeanApp, d_Integer] /;
  appHeadName[e] === "Ne" && Length[flattenApp[e][[2]]] >= 3 :=
  With[{args = flattenApp[e][[2]]},
    leanPP[args[[-2]], d - 1] <> " \[NotEqual] " <> leanPP[args[[-1]], d - 1]];

(* Neg.neg / HNeg.hNeg -- unary prefix *)
leanPP[e_LeanApp, d_Integer] /;
  MatchQ[appHeadName[e], "Neg.neg" | "HNeg.hNeg" | "instHNeg.hNeg"] :=
  "-" <> leanPP[Last[flattenApp[e][[2]]], d - 1];

(* Arithmetic infix *)
leanPP[e_LeanApp, d_Integer] /; MatchQ[appHeadName[e], "HMul.hMul" | "instHMul.hMul"] := leanPPInfix[e, d, "*"];
leanPP[e_LeanApp, d_Integer] /; MatchQ[appHeadName[e], "HAdd.hAdd" | "instHAdd.hAdd"] := leanPPInfix[e, d, "+"];
leanPP[e_LeanApp, d_Integer] /; MatchQ[appHeadName[e], "HSub.hSub" | "instHSub.hSub"] := leanPPInfix[e, d, "-"];
leanPP[e_LeanApp, d_Integer] /; MatchQ[appHeadName[e], "HDiv.hDiv" | "instHDiv.hDiv"] := leanPPInfix[e, d, "/"];
leanPP[e_LeanApp, d_Integer] /; MatchQ[appHeadName[e], "HPow.hPow" | "instHPow.hPow"] := leanPPInfix[e, d, "^"];
leanPP[e_LeanApp, d_Integer] /; MatchQ[appHeadName[e], "HSMul.hSMul" | "instHSMul.hSMul"] := leanPPInfix[e, d, "\[CenterDot]"];

(* Comparisons *)
leanPP[e_LeanApp, d_Integer] /; StringEndsQ[Replace[appHeadName[e], None -> ""], ".le"] := leanPPInfix[e, d, "\[LessEqual]"];
leanPP[e_LeanApp, d_Integer] /; StringEndsQ[Replace[appHeadName[e], None -> ""], ".lt"] := leanPPInfix[e, d, "<"];

(* Logic *)
leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Iff" && Length[flattenApp[e][[2]]] == 2 := leanPPInfix[e, d, "\[DoubleLeftRightArrow]"];
leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "And" && Length[flattenApp[e][[2]]] == 2 := leanPPInfix[e, d, "\[And]"];
leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Or" && Length[flattenApp[e][[2]]] == 2 := leanPPInfix[e, d, "\[Or]"];
leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Not" && Length[flattenApp[e][[2]]] == 1 :=
  "\[Not]" <> leanPP[flattenApp[e][[2, 1]], d - 1];

(* Exists *)
leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Exists" :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 1 && MatchQ[Last[args], LeanLam[_, _, _, _]],
      "\[Exists] " <> cleanName[Last[args][[1]]] <> ", " <> leanPP[Last[args][[3]], d - 1],
      "Exists " <> StringRiffle[leanPP[#, d - 1] & /@ args, " "]]];

(* OfNat.ofNat -- render as literal number *)
leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "OfNat.ofNat" :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 2, leanPP[args[[2]], d - 1],
      "OfNat " <> StringRiffle[leanPP[#, d - 1] & /@ args, " "]]];

(* Function.Injective / Bijective *)
leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Function.Injective" :=
  "Injective " <> leanPP[Last[flattenApp[e][[2]]], d - 1];
leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Function.Bijective" :=
  "Bijective " <> leanPP[Last[flattenApp[e][[2]]], d - 1];

(* Generic fallback *)
leanPP[e_LeanApp, d_Integer] := Module[
  {fn = e, args = {}, a},
  While[MatchQ[fn, LeanApp[_, _]],
    a = fn[[2]]; fn = fn[[1]];
    PrependTo[args, leanPP[a, d - 1]]];
  leanPP[fn, d - 1] <> " " <> StringRiffle[args, " "]];

leanPP[LeanProj[struct_String, idx_Integer, expr_], d_Integer] :=
  leanPP[expr, d - 1] <> "." <> ToString[idx];

leanPP[LeanMData[_, expr_], d_Integer] := leanPP[expr, d];
leanPP[LeanNoValue[], _] := "(no value)";

(* Fallback *)
leanPP[$Failed, _] := "(failed)";
leanPP[other_, _] := ToString[Short[other, 1]];

(* ============================================================================ *)
(* leanSource -- Lean 4 source-safe pretty-printer                               *)
(* Unlike leanPP (display), this produces valid Lean 4 ASCII/Unicode syntax.   *)
(* ============================================================================ *)


(* ppExprFFI -- pretty-print via Lean's PrettyPrinter when handle available *)
ppExprFFI[handle_Integer, expr_] := Quiet[Module[{wxf, res},
  wxf = BinarySerialize[expr, PerformanceGoal -> "Speed"];
  res = $ppExprFn[handle, Normal[wxf]];
  If[ListQ[res], decodeWXF[res], $Failed]
], {LibraryFunction::cfsa}];
ppExprFFI[_, _] := $Failed;

(* LeanExportString -- export LeanEnvironment to source string *)
(* Proof environment with _DeclOrder -- serialize declarations *)
LeanExportString[env_LeanEnvironment] /; KeyExistsQ[env[[1]], "_DeclOrder"] :=
  Module[{data = env[[1]], preamble, decls, lines = {}},
    preamble = Lookup[data, "_Preamble", <||>];
    decls = Lookup[data, "_DeclOrder", {}];
    (* Preamble *)
    If[KeyExistsQ[preamble, "Imports"],
      Do[AppendTo[lines, "import " <> imp], {imp, preamble["Imports"]}];
      AppendTo[lines, ""]];
    (* Type axiom *)
    If[KeyExistsQ[preamble, "TypeAxiom"],
      AppendTo[lines, "axiom " <> preamble["TypeAxiom"] <> " : Type"];
      AppendTo[lines, ""]];
    (* Operators *)
    If[KeyExistsQ[preamble, "Operators"],
      KeyValueMap[
        AppendTo[lines,
          "axiom " <> #1 <> " : " <> StringJoin[Table["U " <> FromCharacterCode[8594] <> " ", {#2}]] <> "U"] &,
        preamble["Operators"]]];
    If[TrueQ[preamble["CenterDot"]],
      AppendTo[lines, "axiom cdot : U " <> FromCharacterCode[8594] <> " U " <> FromCharacterCode[8594] <> " U"];
      AppendTo[lines, "infixl:70 \" " <> FromCharacterCode[11037] <> " \" => cdot"]];
    (* Shared constants *)
    If[KeyExistsQ[preamble, "SharedConstants"],
      Do[AppendTo[lines, "axiom " <> c <> " : U"], {c, preamble["SharedConstants"]}]];
    If[Length[lines] > 0, AppendTo[lines, ""]];
    (* Declarations *)
    Do[
      With[{term = data[name]},
        If[Head[term] =!= LeanTerm, Continue[]];
        With[{kind = Lookup[term[[1]], "Kind", "theorem"],
              typeExpr = Lookup[term[[1]], "_TypeExpr", None],
              tactic = Lookup[term[[1]], "_Tactic", None]},
          If[typeExpr === None, Continue[]];
          Switch[kind,
            "axiom",
              AppendTo[lines, "axiom " <> name <> " : " <> leanSource[typeExpr]],
            _,
              With[{tacStr = Which[
                  Head[tactic] === LeanTactic, tacticSource[tactic],
                  StringQ[tactic], tactic,
                  True, None]},
                If[StringQ[tacStr],
                  AppendTo[lines, "theorem " <> name <> " : " <> leanSource[typeExpr] <> " := by\n" <> tacStr <> "\n"],
                  AppendTo[lines, "theorem " <> name <> " : " <> leanSource[typeExpr] <> " := sorry\n"]]]]]],
      {name, decls}];
    StringRiffle[lines, "\n"]];

(* Environment with stashed source *)
LeanExportString[env_LeanEnvironment] /; StringQ[Lookup[env[[1]], "_Source", None]] :=
  env[[1]]["_Source"];

(* Generic environment -- generate theorems *)
LeanExportString[env_LeanEnvironment] := Module[
  {terms, lines = {}},
  terms = Select[Normal[env[[1]]], Head[#[[2]]] === LeanTerm &];
  Do[
    With[{name = kv[[1]], term = kv[[2]]},
      AppendTo[lines, StringTemplate["theorem `1` : `2` := sorry"][
        name, leanSource[term["Type"]]]]],
    {kv, terms}];
  StringRiffle[lines, "\n\n"]];

LeanExportString[term_LeanTerm] := leanSource[term["Type"]];
LeanExportString[expr_] := leanSource[expr];

(* LeanExport -- write to file *)
LeanExport[file_String, env_LeanEnvironment] :=
  Export[file, LeanExportString[env], "Text", CharacterEncoding -> "UTF-8"];

leanSource[expr_] := leanSource[expr, 20];
leanSource[e_, 0] := "_";

(* Sugar: LeanConst["name"] <-> LeanConst["name", {}] *)
LeanConst[name_String] := LeanConst[name, {}];

leanSource[LeanConst[name_String, _List], _Integer] := name;

leanSource[LeanSort[LeanLevelZero[]], _] := "Prop";
leanSource[LeanSort[LeanLevelSucc[LeanLevelZero[]]], _] := "Type";
leanSource[LeanSort[LeanLevelSucc[l_]], _] := "Type " <> leanPPLevel[l];
leanSource[LeanSort[l_], _] := "Sort " <> leanPPLevel[l];

leanSource[LeanBVar[n_Integer], _] := "#" <> ToString[n];
leanSource[LeanFVar[_], _] := "_fvar";
leanSource[LeanMVar[_], _] := "_";
leanSource[LeanLitNat[n_Integer], _] := ToString[n];
leanSource[LeanLitStr[s_String], _] := "\"" <> s <> "\"";

(* Forall/Pi *)
leanSource[e : LeanForall[_, _, _, _], d_Integer] := Module[
  {binders = {}, body = e, name, dom, bi, nm},
  While[MatchQ[body, LeanForall[_, _, _, _]] && d - Length[binders] > 0,
    {name, dom, body, bi} = List @@ body;
    nm = cleanName[name];
    AppendTo[binders,
      Switch[bi,
        "implicit", "{" <> nm <> " : " <> leanSource[dom, d - 1] <> "}",
        "strictImplicit", "\[LeftDoubleBracket]" <> nm <> " : " <> leanSource[dom, d - 1] <> "\[RightDoubleBracket]",
        "instImplicit", "[" <> nm <> " : " <> leanSource[dom, d - 1] <> "]",
        _,
          If[nm === "" || StringMatchQ[nm, "_" ~~ ___],
            leanSource[dom, d - 1],
            "(" <> nm <> " : " <> leanSource[dom, d - 1] <> ")"]]]];  
  If[AllTrue[binders, !StringStartsQ[#, "("] && !StringStartsQ[#, "{"] && !StringStartsQ[#, "["] && !StringStartsQ[#, "\[LeftDoubleBracket]"] &],
    StringRiffle[Append[binders, leanSource[body, d - 1]], " " <> FromCharacterCode[8594] <> " "],
    FromCharacterCode[8704] <> " " <> StringRiffle[binders, " "] <> ", " <> leanSource[body, d - 1]]];

(* Lambda *)
leanSource[e : LeanLam[_, _, _, _], d_Integer] := Module[
  {binders = {}, body = e, name, dom, bi, nm},
  While[MatchQ[body, LeanLam[_, _, _, _]] && d - Length[binders] > 0,
    {name, dom, body, bi} = List @@ body;
    nm = cleanName[name];
    AppendTo[binders,
      Switch[bi,
        "implicit", "{" <> nm <> " : " <> leanSource[dom, d - 1] <> "}",
        "instImplicit", "[" <> nm <> " : " <> leanSource[dom, d - 1] <> "]",
        _,
          "(" <> nm <> " : " <> leanSource[dom, d - 1] <> ")"]]];
  "fun " <> StringRiffle[binders, " "] <> " => " <> leanSource[body, d - 1]];

leanSource[LeanLet[name_String, type_, val_, body_], d_Integer] :=
  "let " <> cleanName[name] <> " : " <> leanSource[type, d - 1] <>
  " := " <> leanSource[val, d - 1] <> "; " <> leanSource[body, d - 1];

(* Eq infix: @Eq a lhs rhs -> lhs = rhs *)
leanSource[LeanApp[LeanApp[LeanApp[LeanConst["Eq", _], _], lhs_], rhs_], d_Integer] :=
  leanSource[lhs, d - 1] <> " = " <> leanSource[rhs, d - 1];

(* Application *)
leanSource[e_LeanApp, d_Integer] := Module[
  {fn = e, args = {}, a},
  While[MatchQ[fn, LeanApp[_, _]],
    a = fn[[2]]; fn = fn[[1]];
    PrependTo[args, leanSource[a, d - 1]]];
  "(" <> leanSource[fn, d - 1] <> " " <> StringRiffle[args, " "] <> ")"];

leanSource[LeanProj[struct_String, idx_Integer, expr_], d_Integer] :=
  leanSource[expr, d - 1] <> "." <> ToString[idx];

leanSource[LeanMData[_, expr_], d_Integer] := leanSource[expr, d];
leanSource[LeanNoValue[], _] := "sorry";
leanSource[$Failed, _] := "sorry";
leanSource[other_, _] := "sorry /- " <> ToString[Short[other, 1]] <> " -/";

(* ============================================================================ *)
(* LeanImportString -- compile source string to env                              *)
(* ============================================================================ *)

LeanImportString[src_String] := Module[
  {tmpFile, modName, result},
  modName = "LeanLinkTmp" <> ToString[$SessionID] <> "x" <> ToString[RandomInteger[10^6]];
  tmpFile = FileNameJoin[{$TemporaryDirectory, modName <> ".lean"}];
  Export[tmpFile, src, "Text", CharacterEncoding -> "UTF-8"];
  result = LeanImport[tmpFile];
  (* Cleanup the .lean source -- olean kept for lazy queries *)
  If[FileExistsQ[tmpFile], DeleteFile[tmpFile]];
  result];

(* ============================================================================ *)
(* Expression head formatting                                                   *)
(* ============================================================================ *)

LeanConst /: MakeBoxes[expr : LeanConst[name_String, levels_List], StandardForm] :=
  iBox[expr,
    TooltipBox[
      StyleBox[shortName[name], FontColor -> RGBColor[0.15, 0.35, 0.6], FontWeight -> Bold],
      RowBox[{MakeBoxes[name], " ", MakeBoxes[levels, StandardForm]}]]];

LeanForall /: MakeBoxes[expr : LeanForall[name_String, dom_, body_, bi_String], StandardForm] :=
  With[{nm = cleanName[name]},
    iBox[expr,
      RowBox[{
        Switch[bi,
          "implicit",
            RowBox[{"{", StyleBox[nm, FontSlant -> Italic],
              " : ", MakeBoxes[dom, StandardForm], "}"}],
          "strictImplicit",
            RowBox[{"\[LeftDoubleBracket]", StyleBox[nm, FontSlant -> Italic],
              " : ", MakeBoxes[dom, StandardForm], "\[RightDoubleBracket]"}],
          "instImplicit",
            RowBox[{"[", StyleBox[nm, FontSlant -> Italic],
              " : ", MakeBoxes[dom, StandardForm], "]"}],
          _,
            If[nm === "" || StringMatchQ[nm, "_" ~~ ___],
              MakeBoxes[dom, StandardForm],
              RowBox[{"(", StyleBox[nm, FontSlant -> Italic],
                " : ", MakeBoxes[dom, StandardForm], ")"}]]],
        StyleBox[" \[Implies] ", FontColor -> GrayLevel[0.4]],
        MakeBoxes[body, StandardForm]}]]];

LeanApp /: MakeBoxes[expr : LeanApp[fn_, arg_], StandardForm] :=
  iBox[expr,
    RowBox[{MakeBoxes[fn, StandardForm], " ", MakeBoxes[arg, StandardForm]}]];

LeanLam /: MakeBoxes[expr : LeanLam[name_String, type_, body_, bi_String], StandardForm] :=
  With[{nm = cleanName[name]},
    iBox[expr,
      RowBox[{
        StyleBox["fun ", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold],
        Switch[bi,
          "implicit",
            RowBox[{"{", StyleBox[nm, FontSlant -> Italic],
              " : ", MakeBoxes[type, StandardForm], "}"}],
          "instImplicit",
            RowBox[{"[", StyleBox[nm, FontSlant -> Italic],
              " : ", MakeBoxes[type, StandardForm], "]"}],
          _,
            RowBox[{"(", StyleBox[nm, FontSlant -> Italic],
              " : ", MakeBoxes[type, StandardForm], ")"}]],
        StyleBox[" \[Implies] ", FontColor -> GrayLevel[0.4]],
        MakeBoxes[body, StandardForm]}]]];

LeanBVar /: MakeBoxes[expr : LeanBVar[idx_Integer], StandardForm] :=
  iBox[expr,
    TooltipBox[
      StyleBox["#" <> ToString[idx], FontColor -> GrayLevel[0.5]],
      RowBox[{"bound var ", MakeBoxes[idx]}]]];

LeanSort /: MakeBoxes[expr : LeanSort[LeanLevelZero[]], StandardForm] :=
  iBox[expr, StyleBox["Prop", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold]];
LeanSort /: MakeBoxes[expr : LeanSort[LeanLevelSucc[LeanLevelZero[]]], StandardForm] :=
  iBox[expr, StyleBox["Type", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold]];
LeanSort /: MakeBoxes[expr : LeanSort[level_], StandardForm] :=
  iBox[expr,
    RowBox[{StyleBox["Sort", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold],
      " ", MakeBoxes[level, StandardForm]}]];

LeanLitNat /: MakeBoxes[expr : LeanLitNat[n_Integer], StandardForm] :=
  iBox[expr, StyleBox[ToString[n], FontColor -> RGBColor[0.1, 0.5, 0.1]]];
LeanLitStr /: MakeBoxes[expr : LeanLitStr[s_String], StandardForm] :=
  iBox[expr, StyleBox["\"" <> s <> "\"", FontColor -> RGBColor[0.7, 0.3, 0.1]]];

LeanLet /: MakeBoxes[expr : LeanLet[name_String, type_, val_, body_], StandardForm] :=
  With[{nm = cleanName[name]},
    iBox[expr,
      RowBox[{StyleBox["let ", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold],
        StyleBox[nm, FontSlant -> Italic, Bold],
        " : ", MakeBoxes[type, StandardForm],
        " := ", MakeBoxes[val, StandardForm],
        "; ", MakeBoxes[body, StandardForm]}]]];

LeanNoValue /: MakeBoxes[expr : LeanNoValue[], StandardForm] :=
  iBox[expr, StyleBox["\[Dash]", FontColor -> GrayLevel[0.6]]];

LeanTruncated /: MakeBoxes[expr : LeanTruncated[info_], StandardForm] :=
  iBox[expr,
    TooltipBox[StyleBox["\[Ellipsis]", FontColor -> GrayLevel[0.5]],
      MakeBoxes[info, StandardForm]]];

LeanProj /: MakeBoxes[expr : LeanProj[typeName_, idx_Integer, struct_], StandardForm] :=
  iBox[expr,
    RowBox[{MakeBoxes[struct, StandardForm], ".",
      StyleBox[ToString[idx], FontColor -> GrayLevel[0.5]]}]];

LeanFVar /: MakeBoxes[expr : LeanFVar[name_], StandardForm] :=
  iBox[expr,
    StyleBox[cleanName[ToString[name]],
      FontColor -> RGBColor[0.4, 0.4, 0.7], FontSlant -> Italic]];
LeanMVar /: MakeBoxes[expr : LeanMVar[name_], StandardForm] :=
  iBox[expr,
    StyleBox["?" <> cleanName[ToString[name]],
      FontColor -> RGBColor[0.7, 0.4, 0.4], FontSlant -> Italic]];

(* ============================================================================ *)
(* Level formatting                                                             *)
(* ============================================================================ *)

LeanLevelZero /: MakeBoxes[expr : LeanLevelZero[], StandardForm] :=
  iBox[expr, StyleBox["0", FontColor -> GrayLevel[0.5], FontSize -> 9]];

LeanLevelSucc /: MakeBoxes[expr : LeanLevelSucc[l_], StandardForm] :=
  iBox[expr,
    RowBox[{MakeBoxes[l, StandardForm],
      StyleBox["+1", FontColor -> GrayLevel[0.5], FontSize -> 9]}]];

LeanLevelMax /: MakeBoxes[expr : LeanLevelMax[a_, b_], StandardForm] :=
  iBox[expr,
    RowBox[{StyleBox["max", FontColor -> GrayLevel[0.5], FontSize -> 9],
      "(", MakeBoxes[a, StandardForm], ", ", MakeBoxes[b, StandardForm], ")"}]];

LeanLevelIMax /: MakeBoxes[expr : LeanLevelIMax[a_, b_], StandardForm] :=
  iBox[expr,
    RowBox[{StyleBox["imax", FontColor -> GrayLevel[0.5], FontSize -> 9],
      "(", MakeBoxes[a, StandardForm], ", ", MakeBoxes[b, StandardForm], ")"}]];

LeanLevelParam /: MakeBoxes[expr : LeanLevelParam[name_String], StandardForm] :=
  iBox[expr,
    StyleBox[name, FontColor -> RGBColor[0.4, 0.55, 0.4],
      FontSlant -> Italic, FontSize -> 9]];

LeanLevelMVar /: MakeBoxes[expr : LeanLevelMVar[name_], StandardForm] :=
  iBox[expr,
    StyleBox["?" <> ToString[name], FontColor -> GrayLevel[0.6],
      FontSlant -> Italic, FontSize -> 9]];

(* ============================================================================ *)
(* Public API                                                                   *)
(* ============================================================================ *)

LeanLoadEnvironment[imports_List, searchPath_String] :=
  $loadEnvFn[StringRiffle[imports, ","], searchPath];

LeanFreeEnvironment[handle_Integer] := ($freeEnvFn[handle]; Null);

(* --- LeanImport --- *)

Options[LeanImport] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Filter" -> "", "IncludeInternal" -> False};

(* Internal name patterns to filter out *)
$internalPatterns = "_cstage1" | "_cstage2" | "_rarg" | "_sunfold" |
  "_unsafe_rec" | ".match_" | ".rec" | ".recOn" | ".casesOn" |
  ".brecOn" | ".binductionOn" | ".below" | ".ibelow" |
  ".noConfusion" | ".noConfusionType" | "._sizeOf" | ".sizeOf_spec" |
  ".inj" | ".injEq";

isInternalName[name_String] :=
  StringContainsQ[name, $internalPatterns];

(* LeanImport[module, opts] -- shorthand for Imports -> {module} *)
(* If module is a directory of sub-modules (no top-level .olean), auto-discover sub-modules *)
LeanImport[module_String, opts : OptionsPattern[]] /;
  !StringContainsQ[module, "/" | "\\"] && !StringEndsQ[module, ".lean"] :=
  Module[{projDir, buildLib, srcDir, oleans, subModules, results = <||>, filter,
          srcFiles, allNames, grouped},
    projDir = resolveProjDir[OptionValue["ProjectDir"]];
    (* Lake v5 puts oleans in lib/lean/, v4 uses lib/ *)
    buildLib = With[{v5 = FileNameJoin[{projDir, ".lake", "build", "lib", "lean"}],
                     v4 = FileNameJoin[{projDir, ".lake", "build", "lib"}]},
      If[DirectoryQ[v5], v5, v4]];
    filter = OptionValue["Filter"];
    (* Check if module is a directory of sub-modules *)
    If[DirectoryQ[buildLib] &&
       !FileExistsQ[FileNameJoin[{buildLib, module <> ".olean"}]] &&
       DirectoryQ[FileNameJoin[{buildLib, module}]],
      (* Auto-discover sub-modules from .olean files *)
      oleans = FileNames["*.olean", FileNameJoin[{buildLib, module}], Infinity];
      subModules = StringReplace[
        FileNameDrop[#, FileNameDepth[buildLib]] & /@ oleans,
        {".olean" -> "", "/" -> "."}];
      If[subModules =!= {},
        (* For directory-based modules, use first available sub-module's env *)
        Module[{h, kinds},
          h = Quiet[getOrLoadEnv[projDir, Take[subModules, 1]]];
          If[IntegerQ[h] && h > 0,
            kinds = Quiet[decodeWXF[$listConstantKindsFn[h, filter]]];
            If[AssociationQ[kinds],
              If[!TrueQ[OptionValue["IncludeInternal"]],
                kinds = KeySelect[kinds, !isInternalName[#] &]];
              results = LeanEnvironment[Append[Association @ KeyValueMap[
                Function[{n, k},
                  n -> LeanTerm[<|"Name" -> n, "Kind" -> k, "_Handle" -> h|>]],
                kinds], "_Handle" -> h]]]]];
        Return[results, Module]]];
    LeanImport["Imports" -> {module}, opts]];

(* LeanImport[file, opts] -- standalone .lean file: compile via lean CLI *)
LeanImport[file_String, opts : OptionsPattern[]] /;
  FileExistsQ[file] && StringEndsQ[file, ".lean"] :=
  Module[{absFile, projDir, modName, tmpDir, oleanFile, result, searchPath,
          tcFile, tcName, leanBin, leanLibDir, content, names},
    absFile = ExpandFileName[file];
    projDir = OptionValue["ProjectDir"];
    (* If within a lake project, delegate to module-based import *)
    If[projDir =!= Automatic && StringStartsQ[absFile, ExpandFileName[projDir]],
      modName = StringReplace[
        StringTrim[StringDrop[absFile, StringLength[ExpandFileName[projDir]]], "/" | "\\"],
        {".lean" -> "", "/" -> ".", "\\" -> "."}];
      Return[LeanImport["Imports" -> {modName},
        "ProjectDir" -> projDir,
        "Filter" -> If[OptionValue["Filter"] === "", modName, OptionValue["Filter"]],
        opts], Module]];
    (* Resolve the correct lean binary from the LeanLink project toolchain *)
    If[StringQ[$DevProjectRoot],
      tcFile = FileNameJoin[{$DevProjectRoot, "Native", "lean-toolchain"}],
      tcFile = None];
    If[FileExistsQ[tcFile],
      tcName = StringTrim[Import[tcFile, "Text"]];
      tcName = StringReplace[tcName, {"/" -> "--", ":" -> "---"}];
      leanBin = FileNameJoin[{$HomeDirectory, ".elan", "toolchains", tcName, "bin", "lean"}];
      leanLibDir = FileNameJoin[{$HomeDirectory, ".elan", "toolchains", tcName, "lib", "lean"}],
      leanBin = "lean";
      leanLibDir = StringTrim[RunProcess[{"lean", "--print-libdir"}, "StandardOutput"]]];
    (* Standalone file: compile via lean CLI subprocess *)
    modName = FileBaseName[absFile];
    tmpDir = FileNameJoin[{$TemporaryDirectory,
      "leanlink_" <> modName <> "_" <> ToString[$SessionID]}];
    If[DirectoryQ[tmpDir], DeleteDirectory[tmpDir, DeleteContents -> True]];
    tmpDir = CreateDirectory[tmpDir];
    oleanFile = FileNameJoin[{tmpDir, modName <> ".olean"}];
    result = RunProcess[{leanBin, "-o", oleanFile, "-R", DirectoryName[absFile], absFile}];
    If[result["ExitCode"] =!= 0,
      Message[LeanLink::err, "lean compilation failed: " <> result["StandardError"]];
      DeleteDirectory[tmpDir, DeleteContents -> True];
      Return[$Failed, Module]];
    (* Load via lazy pattern *)
    searchPath = tmpDir <> ":" <> leanLibDir;
    Block[{handle, kinds, srcNames, res},
      handle = $loadEnvFn[modName, searchPath];
      If[handle === 0 || !IntegerQ[handle],
        Message[LeanLink::err, "Failed to load compiled file"];
        DeleteDirectory[tmpDir, DeleteContents -> True];
        Return[$Failed, Module]];
      (* Extract names from source for filtering -- these are unqualified *)
      content = Import[absFile, "Text"];
      srcNames = StringCases[content,
        RegularExpression["(?m)^(?:noncomputable\\s+)?(?:def|theorem|lemma|inductive|structure|class|instance|abbrev)\\s+([a-zA-Z_][a-zA-Z0-9_.]*)"] :> "$1"];
      (* Get actual Lean names from env, filter to source-defined ones *)
      kinds = decodeWXF[$listConstantKindsFn[handle, ""]];
      If[!AssociationQ[kinds], Return[$Failed, Module]];
      kinds = KeySelect[kinds,
        (TrueQ[OptionValue["IncludeInternal"]] || !isInternalName[#]) && MemberQ[srcNames, #] &];
      (* Build lazy LeanTerms *)
      res = LeanEnvironment[Append[Association @ KeyValueMap[
        Function[{name, kind},
          name -> LeanTerm[<|"Name" -> name, "Kind" -> kind, "_Handle" -> handle|>]],
        kinds], "_Handle" -> handle]];
      (* Don't delete tmpDir -- olean needed for lazy queries *)
      res]];

(* LeanImport[opts] -- base form: instant lazy loading *)
LeanImport[opts : OptionsPattern[]] := Module[{handle, kinds},
  If[$ShimLib === $Failed, Message[LeanLink::nolib]; Return[$Failed]];
  handle = getOrLoadEnv[resolveProjDir[OptionValue["ProjectDir"]], OptionValue["Imports"]];
  If[handle === $Failed, Return[$Failed]];
  kinds = decodeWXF[$listConstantKindsFn[handle, OptionValue["Filter"]]];
  If[!AssociationQ[kinds], Return[$Failed]];
  (* Filter out internal/generated names *)
  If[!TrueQ[OptionValue["IncludeInternal"]],
    kinds = KeySelect[kinds, !isInternalName[#] &]];
  (* Build lazy LeanTerms: only Name + Kind + _Handle, no Type/Term yet *)
  LeanEnvironment[Append[Association @ KeyValueMap[
    Function[{name, kind},
      name -> LeanTerm[<|"Name" -> name, "Kind" -> kind, "_Handle" -> handle|>]],
    kinds], "_Handle" -> handle]]];

(* --- Type / Value / ConstantInfo / ListConstants --- *)

Options[LeanExpr] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Depth" -> 100};
LeanExpr[name_String, opts : OptionsPattern[]] :=
  callNative[$getTypeFn,
    {name, OptionValue["Depth"]},
    resolveProjDir[OptionValue["ProjectDir"]],
    OptionValue["Imports"]];

Options[LeanValue] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Depth" -> 100};
LeanValue[name_String, opts : OptionsPattern[]] :=
  callNative[$getValueFn,
    {name, OptionValue["Depth"]},
    resolveProjDir[OptionValue["ProjectDir"]],
    OptionValue["Imports"]];

Options[LeanConstantInfo] = {"ProjectDir" -> Automatic, "Imports" -> {}};
LeanConstantInfo[name_String, opts : OptionsPattern[]] :=
  callNative[$getConstantFn,
    {name},
    resolveProjDir[OptionValue["ProjectDir"]],
    OptionValue["Imports"]];

Options[LeanListConstants] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Filter" -> ""};
LeanListConstants[opts : OptionsPattern[]] :=
  callNative[$listTheoremsFn,
    {OptionValue["Filter"]},
    resolveProjDir[OptionValue["ProjectDir"]],
    OptionValue["Imports"]];

(* ============================================================================ *)
(* LeanEnvironment -- typed collection of LeanTerms                              *)
(* ============================================================================ *)

(* Property/key access -- env[key] returns LeanTerm with env handle injected *)
LeanEnvironment /: LeanEnvironment[data_Association][key_String] :=
  Module[{val = data[key], handle},
    If[Head[val] === LeanTerm,
      handle = Lookup[data, "_Handle", None];
      If[IntegerQ[handle],
        LeanTerm[Append[val[[1]], "_Handle" -> handle]],
        val],
      val]];
LeanEnvironment /: Keys[LeanEnvironment[data_Association]] :=
  Select[Keys[data], !StringStartsQ[#, "_"] &];
LeanEnvironment /: Values[LeanEnvironment[data_Association]] :=
  Values[KeySelect[data, !StringStartsQ[#, "_"] &]];
LeanEnvironment /: Length[LeanEnvironment[data_Association]] :=
  Length[Select[Keys[data], !StringStartsQ[#, "_"] &]];
LeanEnvironment /: KeyExistsQ[LeanEnvironment[data_Association], key_] := KeyExistsQ[data, key];
LeanEnvironment /: Normal[LeanEnvironment[data_Association]] := data;

(* Information protocol -- no collision with term names *)
$leanEnvProperties = {"Constants", "Kinds", "Handle", "Source", "DeclOrder", "Preamble"};

LeanEnvironment /: Information[env : LeanEnvironment[data_Association], "Properties"] :=
  $leanEnvProperties;

LeanEnvironment /: Information[env : LeanEnvironment[data_Association], prop_String] :=
  Switch[prop,
    "Constants", Select[Keys[data], !StringStartsQ[#, "_"] &],
    "Kinds", Counts[Lookup[#[[1]], "Kind", "?"] & /@ Select[Values[data], Head[#] === LeanTerm &]],
    "Handle", Lookup[data, "_Handle", None],
    "Source", Lookup[data, "_Source", None],
    "DeclOrder", Lookup[data, "_DeclOrder", None],
    "Preamble", Lookup[data, "_Preamble", None],
    _, Missing["UnknownProperty", prop]];


(* MakeBoxes for LeanEnvironment -- summary box *)
LeanEnvironment /: MakeBoxes[obj : LeanEnvironment[data_Association], StandardForm] :=
  Module[{n, kinds, handle, hasSource, icon},
    n = Length[Select[data, Head[#] === LeanTerm &]];
    kinds = Counts[Lookup[#[[1]], "Kind", "?"] & /@ Select[Values[data], Head[#] === LeanTerm &]];
    handle = Lookup[data, "_Handle", None];
    hasSource = StringQ[Lookup[data, "_Source", None]];
    icon = Graphics[{Hue[0.6, 0.5, 0.8], Disk[]}, ImageSize -> 12];
    BoxForm`ArrangeSummaryBox[LeanEnvironment, obj, icon,
      {
        BoxForm`SummaryItem[{"Constants: ", n}],
        If[Length[kinds] > 0,
          BoxForm`SummaryItem[{"Kinds: ",
            Row[KeyValueMap[Row[{#2, " ", Style[#1, Gray]}] &, kinds], "  "]}],
          Nothing]
      },
      {
        BoxForm`SummaryItem[{"Handle: ",
          If[IntegerQ[handle], Style[handle, Bold], Style["none", Gray]]}],
        If[hasSource,
          BoxForm`SummaryItem[{"Source: ", Style["available", Darker[Green]]}],
          Nothing],
        If[KeyExistsQ[data, "_DeclOrder"],
          BoxForm`SummaryItem[{"Declarations: ", Length[data["_DeclOrder"]]}],
          Nothing]
      },
      StandardForm,
      "Interpretable" -> Automatic]];

(* ============================================================================ *)
(* LeanState -- interactive proof state                                          *)
(* ============================================================================ *)

(* Constructor: LeanState[term_LeanTerm] opens a proof goal *)
LeanState[term_LeanTerm] :=
  Module[{data = term[[1]], handle, name, result, state, tactic, typeExpr},
    handle = Lookup[data, "_Handle", None];
    name = Lookup[data, "Name", ""];
    If[IntegerQ[handle],
      (* Native path: use Lean runtime *)
      result = Quiet[decodeWXF[$openGoalFn[handle, name]]];
      If[!AssociationQ[result], Return[$Failed]];
      state = LeanState[<|
        "stateId" -> result["stateId"],
        "goals" -> (LeanGoal /@ result["goals"]),
        "goalCount" -> result["goalCount"],
        "_Handle" -> handle|>];
      (* Auto-apply existing tactic if term has one *)
      tactic = Lookup[data, "_Tactic", None];
      If[Head[tactic] === LeanTactic,
        state = tactic[state]];
      state,
      (* Pure symbolic path: build state from _TypeExpr *)
      typeExpr = Lookup[data, "_TypeExpr", None];
      tactic = Lookup[data, "_Tactic", None];
      If[typeExpr === None, Return[$Failed]];
      state = LeanState[<|
        "stateId" -> 0,
        "goals" -> {LeanGoal[<|"target" -> leanSource[typeExpr], "context" -> {}|>]},
        "goalCount" -> 1,
        "_Symbolic" -> True|>];
      (* If tactic exists, the proof is known -- mark complete *)
      If[Head[tactic] === LeanTactic,
        state = LeanState[<|
          "stateId" -> 0,
          "goals" -> {},
          "goalCount" -> 0,
          "_Symbolic" -> True,
          "_Tactic" -> tactic|>]];
      state]];

(* Constructor: LeanState[env, name] opens a proof goal from env by name *)
LeanState[env_LeanEnvironment, name_String] :=
  Module[{data = env[[1]], handle, compiled, src, term},
    handle = Lookup[data, "_Handle", None];
    If[!IntegerQ[handle],
      (* Uncompiled env: auto-compile via string roundtrip *)
      src = Lookup[data, "_Source", None];
      If[!StringQ[src], src = LeanExportString[env]];
      compiled = Quiet[LeanImportString[src]];
      If[Head[compiled] =!= LeanEnvironment, Return[$Failed]];
      handle = compiled[[1]]["_Handle"]];
    term = <|"_Handle" -> handle, "Name" -> name|>;
    LeanState[LeanTerm[term]]];

(* LeanState property access *)
LeanState /: LeanState[data_Association][prop_String] :=
  Switch[prop,
    "Goals", Lookup[data, "goals", {}],
    "GoalCount", Lookup[data, "goalCount", 0],
    "Complete", Lookup[data, "goalCount", 0] === 0,
    "StateId", Lookup[data, "stateId", None],
    _, data[prop]];

(* LeanGoal property access *)
LeanGoal /: LeanGoal[data_Association][prop_String] :=
  Switch[prop,
    "Target", Lookup[data, "target", "?"],
    "TargetExpr", Lookup[data, "targetExpr", None],
    "Context", Lookup[data, "context", {}],
    _, data[prop]];

(* Helper: pretty-print a goal target using leanPP when expression available *)
ppGoalTarget[g_Association] :=
  If[KeyExistsQ[g, "targetExpr"] && !MatchQ[g["targetExpr"], _String | _Missing],
    leanPP[g["targetExpr"]], Lookup[g, "target", "?"]];

(* Helper: pretty-print a context entry type *)
ppCtxType[entry_Association] :=
  If[KeyExistsQ[entry, "typeExpr"] && !MatchQ[entry["typeExpr"], _String | _Missing],
    leanPP[entry["typeExpr"]], Lookup[entry, "type", "?"]];

(* MakeBoxes for LeanState *)
LeanState /: MakeBoxes[LeanState[data_Association], StandardForm] :=
  Module[{n = Lookup[data, "goalCount", 0], goals = Lookup[data, "goals", {}]},
    With[{display =
      If[n === 0,
        Style["\[Checkmark] No goals", Darker[Green], Bold],
        Column[
          Join[
            {Style[ToString[n] <> If[n === 1, " goal", " goals"], Gray, Italic]},
            MapIndexed[
              Module[{g = #1[[1]], idx = #2[[1]], ctx, target},
                ctx = Lookup[g, "context", {}];
                target = ppGoalTarget[g];
                Column[{
                  If[Length[ctx] > 0,
                    Column[
                      (Style[#["name"] <> " : " <> ppCtxType[#], "Input"] & /@ ctx),
                      Spacings -> 0.3],
                    Nothing],
                  Style["\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]", Gray],
                  Style["\[RightTriangle] " <> target, Bold, "Input"]
                }, Spacings -> 0.2]] &, goals]],
          Spacings -> 0.8]]},
      ToBoxes[Interpretation[display, LeanState[data]]]]];

(* MakeBoxes for LeanGoal *)
LeanGoal /: MakeBoxes[LeanGoal[data_Association], StandardForm] :=
  Module[{ctx = Lookup[data, "context", {}], target = ppGoalTarget[data]},
    With[{display =
      Column[{
        If[Length[ctx] > 0,
          Column[
            (Style[#["name"] <> " : " <> ppCtxType[#], "Input"] & /@ ctx),
            Spacings -> 0.3],
          Nothing],
        Style["\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]", Gray],
        Style["\[RightTriangle] " <> target, Bold, "Input"]
      }, Spacings -> 0.2]},
      ToBoxes[Interpretation[display, LeanGoal[data]]]]];

(* ============================================================================ *)
(* LeanTactic -- structured tactic objects                                        *)
(* ============================================================================ *)

(* ---- tacticSource: serialize structured LeanTactic -> string ---- *)

tacticSource[LeanTactic["exact", term_]] := "  exact " <> leanSource[term];
tacticSource[LeanTactic["have", name_String, term_]] := "  have " <> name <> " := " <> leanSource[term];
tacticSource[LeanTactic["rw", rules_List]] := "  rw [" <> StringRiffle[rwRuleSource /@ rules, ", "] <> "]";
tacticSource[LeanTactic["rw", rules_List, hyp_String]] := "  rw [" <> StringRiffle[rwRuleSource /@ rules, ", "] <> "] at " <> hyp;
tacticSource[LeanTactic["simp", rules_List, None]] := "  simp only [" <> StringRiffle[rwRuleSource /@ rules, ", "] <> "]";
tacticSource[LeanTactic["simp", rules_List, hyp_String]] := "  simp only [" <> StringRiffle[rwRuleSource /@ rules, ", "] <> "] at " <> hyp;
tacticSource[LeanTactic["nth_rewrite", n_Integer, rules_List, hyp_String]] :=
  "  nth_rewrite " <> ToString[n] <> " [" <> StringRiffle[leanSource /@ rules, ", "] <> "] at " <> hyp;
tacticSource[LeanTactic["conv", hyp_String, path_List, subtac_]] :=
  "  conv at " <> hyp <> " => " <> StringRiffle[path, "; "] <> "; " <> tacticSourceInline[subtac];
tacticSource[LeanTactic["intro", names_List]] := "  intro " <> StringRiffle[names, " "];
tacticSource[LeanTactic["symm", hyp_String]] := "  symm at " <> hyp;
tacticSource[LeanTactic["sorry"]] := "  sorry";

(* Inline tactic (no leading whitespace, for conv body) *)
tacticSourceInline[LeanTactic["rw", rules_List]] := "rw [" <> StringRiffle[rwRuleSource /@ rules, ", "] <> "]";
tacticSourceInline[LeanTactic["simp", rules_List]] := "simp only [" <> StringRiffle[rwRuleSource /@ rules, ", "] <> "]";
tacticSourceInline[t_LeanTactic] := StringTrim[tacticSource[t]];

(* Rewrite rule source -- detect Eq.symm wrapping and emit <- *)
rwRuleSource[LeanApp[LeanConst["Eq.symm", _], rule_]] := "\[LeftArrow] " <> leanSource[rule];
rwRuleSource[rule_] := leanSource[rule];

(* Sequence of tactics *)
tacticSource[LeanTactic[tactics_List]] := StringRiffle[tacticSource /@ tactics, "\n"];

(* Fallback: bare string *)
tacticSource[LeanTactic[s_String]] := "  " <> s;
tacticSource[s_String] := "  " <> s;

(* ---- LeanExportString for structured tactics ---- *)
LeanExportString[tac_LeanTactic] := tacticSource[tac];

(* ---- Apply tactic to state ---- *)
(* String form: LeanTactic["intro P"][state] *)
LeanTactic /: LeanTactic[tac_String][state_LeanState] :=
  applyTacticStr[tac, state];

(* Structured form: LeanTactic["exact", term][state] -- serialize first *)
LeanTactic /: LeanTactic[tag_String, args___][state_LeanState] :=
  applyTacticStr[StringTrim[tacticSource[LeanTactic[tag, args]]], state];

(* Sequence form: LeanTactic[{t1, t2, ...}][state] *)
LeanTactic /: LeanTactic[tactics_List][state_LeanState] :=
  Fold[
    If[MatchQ[#1, _LeanState], applyTacticLT[#2, #1], #1] &,
    state,
    tactics];

(* Internal: apply a single tactic (string or structured) to state *)
$LeanTacticTimeout = 30;  (* seconds; override to Infinity to disable *)
applyTacticStr[tac_String, state_LeanState] :=
  Module[{data = state[[1]], stateId, handle, result},
    stateId = Lookup[data, "stateId", None];
    handle = Lookup[data, "_Handle", None];
    If[!IntegerQ[stateId], Return[$Failed]];
    result = TimeConstrained[
      Quiet[decodeWXF[$applyTacticFn[stateId, tac]]],
      $LeanTacticTimeout, $Aborted];
    If[result === $Aborted,
      Message[LeanLink::abort, "Tactic timed out: " <> tac]; Return[$Failed]];
    If[!AssociationQ[result], $Failed,
      LeanState[<|
        "stateId" -> result["stateId"],
        "goals" -> (LeanGoal /@ result["goals"]),
        "goalCount" -> result["goalCount"],
        "_Handle" -> handle|>]]];

applyTacticLT[tac_LeanTactic, state_LeanState] :=
  applyTacticStr[StringTrim[tacticSource[tac]], state];
applyTacticLT[tac_String, state_LeanState] :=
  applyTacticStr[tac, state];

(* ---- MakeBoxes ---- *)
LeanTactic /: MakeBoxes[LeanTactic[tac_String], StandardForm] :=
  With[{display = Style[tac, "Input"]},
    ToBoxes[Interpretation[display, LeanTactic[tac]]]];

LeanTactic /: MakeBoxes[t:LeanTactic[tag_String, ___], StandardForm] :=
  With[{display = Style[StringTrim[tacticSource[t]], "Input"]},
    ToBoxes[Interpretation[display, t]]];

LeanTactic /: MakeBoxes[t:LeanTactic[tactics_List], StandardForm] :=
  With[{display = Column[
    Style[StringTrim[#], "Input"] & /@ (tacticSource /@ tactics),
    Spacings -> 0.2]},
    ToBoxes[Interpretation[display, t]]];

(* ============================================================================ *)
(* LeanToFunction / LeanCompile -- Lean defs -> FunctionCompile                   *)
(* ============================================================================ *)

LeanToFunction::notdef = "LeanToFunction requires a definition (kind \"def\"), got kind \"`1`\".";
LeanToFunction::notype = "Cannot map Lean type `1` to a compiled WL type.";
LeanToFunction::noterm = "Definition has no term body.";
LeanToFunction::badexpr = "Cannot translate Lean expression to WL: `1`.";

(* ---- Type mapping: Lean type expr -> WL TypeSpecifier string ---- *)

leanTypeToWL[LeanConst["Nat", _List]] := "MachineInteger";
leanTypeToWL[LeanConst["Nat", _List], "Literal"] := "MachineInteger";
leanTypeToWL[LeanConst["Int", _List]] := "Integer64";
leanTypeToWL[LeanConst["Float", _List]] := "Real64";
leanTypeToWL[LeanConst["Bool", _List]] := "Boolean";
leanTypeToWL[LeanConst["String", _List]] := "String";
leanTypeToWL[LeanConst["UInt8", _List]] := "UnsignedInteger8";
leanTypeToWL[LeanConst["UInt16", _List]] := "UnsignedInteger16";
leanTypeToWL[LeanConst["UInt32", _List]] := "UnsignedInteger32";
leanTypeToWL[LeanConst["UInt64", _List]] := "UnsignedInteger64";

(* Arrow type: forall _ : A, B  (non-dependent) -> {A'} -> B' *)
leanTypeToWL[LeanForall[name_, dom_, body_, "default"]] :=
  Module[{domTy, bodyTy},
    domTy = leanTypeToWL[dom];
    bodyTy = leanTypeToWL[body];
    If[FailureQ[domTy] || FailureQ[bodyTy], $Failed,
      {domTy} -> bodyTy]];

(* Fallback *)
leanTypeToWL[other_] := $Failed;

(* Collect all explicit parameter types and return type from a forall chain *)
collectFunctionSignature[type_] := Module[
  {params = {}, body = type, name, dom, bi, domTy},
  While[MatchQ[body, LeanForall[_, _, _, _]],
    {name, dom, body, bi} = List @@ body;
    (* Only collect explicit ("default") binders as function params *)
    If[bi === "default",
      domTy = leanTypeToWL[dom];
      If[FailureQ[domTy], Return[$Failed, Module]];
      AppendTo[params, {cleanName[name], domTy}],
      (* Skip implicit/instance binders -- these are type-level, not runtime *)
      Continue[]]];
  With[{retTy = leanTypeToWL[body]},
    If[FailureQ[retTy], $Failed,
      <|"Params" -> params, "ReturnType" -> retTy|>]]];

(* ---- Expression translation: Lean term -> WL expression ---- *)
(* ctx is a List of variable names, index 0 = last element *)

(* de Bruijn variable lookup -- ctx contains actual symbols *)
leanExprToWL[LeanBVar[i_Integer], ctx_List] :=
  If[i < Length[ctx], ctx[[Length[ctx] - i]], $Failed];

(* Literals *)
leanExprToWL[LeanLitNat[n_Integer], _List] := n;
leanExprToWL[LeanLitStr[s_String], _List] := s;

(* Named constants -- value-level *)
leanExprToWL[LeanConst["Nat.zero", _], _List] := 0;
leanExprToWL[LeanConst["Bool.true", _], _List] := True;
leanExprToWL[LeanConst["Bool.false", _], _List] := False;

(* Nat.succ n -> n + 1 *)
leanExprToWL[LeanApp[LeanConst["Nat.succ", _], arg_], ctx_List] :=
  With[{a = leanExprToWL[arg, ctx]}, If[FailureQ[a], $Failed, a + 1]];

(* OfNat.ofNat -- extract the literal *)
leanExprToWL[e_LeanApp, ctx_List] /;
  appHeadName[e] === "OfNat.ofNat" && Length[flattenApp[e][[2]]] >= 2 :=
  leanExprToWL[flattenApp[e][[2, 2]], ctx];

(* Arithmetic: HAdd.hAdd _ _ _ _ a b -> a + b (last 2 args) *)
leanExprToWL[e_LeanApp, ctx_List] /;
  MatchQ[appHeadName[e], "HAdd.hAdd" | "instHAdd.hAdd"] :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 2,
      With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
        If[FailureQ[a] || FailureQ[b], $Failed, a + b]],
      $Failed]];

leanExprToWL[e_LeanApp, ctx_List] /;
  MatchQ[appHeadName[e], "HSub.hSub" | "instHSub.hSub"] :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 2,
      With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
        If[FailureQ[a] || FailureQ[b], $Failed, a - b]],
      $Failed]];

leanExprToWL[e_LeanApp, ctx_List] /;
  MatchQ[appHeadName[e], "HMul.hMul" | "instHMul.hMul"] :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 2,
      With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
        If[FailureQ[a] || FailureQ[b], $Failed, a * b]],
      $Failed]];

leanExprToWL[e_LeanApp, ctx_List] /;
  MatchQ[appHeadName[e], "HDiv.hDiv" | "instHDiv.hDiv"] :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 2,
      With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
        If[FailureQ[a] || FailureQ[b], $Failed, Quotient[a, b]]],
      $Failed]];

leanExprToWL[e_LeanApp, ctx_List] /;
  MatchQ[appHeadName[e], "HMod.hMod" | "instHMod.hMod"] :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 2,
      With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
        If[FailureQ[a] || FailureQ[b], $Failed, Mod[a, b]]],
      $Failed]];

(* Negation *)
leanExprToWL[e_LeanApp, ctx_List] /;
  MatchQ[appHeadName[e], "Neg.neg" | "HNeg.hNeg" | "instHNeg.hNeg"] :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 1,
      With[{a = leanExprToWL[Last[args], ctx]},
        If[FailureQ[a], $Failed, -a]],
      $Failed]];

(* Comparisons: last 2 args *)
leanExprToWL[e_LeanApp, ctx_List] /;
  MatchQ[appHeadName[e], "BEq.beq" | "instBEq.beq" | "Nat.beq" | "instBEqNat.beq"] :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 2,
      With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
        If[FailureQ[a] || FailureQ[b], $Failed, Equal[a, b]]],
      $Failed]];

leanExprToWL[e_LeanApp, ctx_List] /;
  StringEndsQ[Replace[appHeadName[e], None -> ""], ".le" | ".ble"] :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 2,
      With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
        If[FailureQ[a] || FailureQ[b], $Failed, LessEqual[a, b]]],
      $Failed]];

leanExprToWL[e_LeanApp, ctx_List] /;
  StringEndsQ[Replace[appHeadName[e], None -> ""], ".lt" | ".blt"] :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 2,
      With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
        If[FailureQ[a] || FailureQ[b], $Failed, Less[a, b]]],
      $Failed]];

(* decide / Decidable.decide -- just pass through to the predicate comparison *)
leanExprToWL[e_LeanApp, ctx_List] /;
  MatchQ[appHeadName[e], "decide" | "Decidable.decide"] :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 1,
      leanExprToWL[args[[1]], ctx],
      $Failed]];

(* GT.gt -- a > b: last 2 args *)
leanExprToWL[e_LeanApp, ctx_List] /;
  MatchQ[appHeadName[e], "GT.gt" | "instGT.gt" | "Nat.blt"] :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 2,
      With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
        If[FailureQ[a] || FailureQ[b], $Failed, Greater[a, b]]],
      $Failed]];

leanExprToWL[e_LeanApp, ctx_List] /;
  MatchQ[appHeadName[e], "GE.ge" | "instGE.ge"] :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 2,
      With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
        If[FailureQ[a] || FailureQ[b], $Failed, GreaterEqual[a, b]]],
      $Failed]];

(* if-then-else: ite _ cond _ thenBranch elseBranch *)
leanExprToWL[e_LeanApp, ctx_List] /;
  MatchQ[appHeadName[e], "ite" | "instDecidableIte" | "Bool.bne"] :=
  With[{args = flattenApp[e][[2]]},
    (* ite has args: type, cond, decidableInst, thenBranch, elseBranch *)
    If[Length[args] >= 5,
      With[{c = leanExprToWL[args[[2]], ctx],
            t = leanExprToWL[args[[4]], ctx],
            f = leanExprToWL[args[[5]], ctx]},
        If[FailureQ[c] || FailureQ[t] || FailureQ[f], $Failed,
          If[c, t, f]]],
      (* Bool if -- 4 args *)
      If[Length[args] >= 4,
        With[{c = leanExprToWL[args[[1]], ctx],
              t = leanExprToWL[args[[3]], ctx],
              f = leanExprToWL[args[[4]], ctx]},
          If[FailureQ[c] || FailureQ[t] || FailureQ[f], $Failed,
            If[c, t, f]]],
        $Failed]]];

(* dite -- decidable if-then-else (dependent): dite type cond inst thenLam elseLam *)
leanExprToWL[e_LeanApp, ctx_List] /;
  appHeadName[e] === "dite" :=
  With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 5,
      With[{c = leanExprToWL[args[[2]], ctx]},
        Module[{thenBody, elseBody},
          (* thenLam/elseLam are lambdas -- extract body, push dummy name *)
          thenBody = If[MatchQ[args[[4]], LeanLam[_, _, _, _]],
            leanExprToWL[args[[4, 3]], Append[ctx, "_h"]], 
            leanExprToWL[args[[4]], ctx]];
          elseBody = If[MatchQ[args[[5]], LeanLam[_, _, _, _]],
            leanExprToWL[args[[5, 3]], Append[ctx, "_h"]],
            leanExprToWL[args[[5]], ctx]];
          If[FailureQ[c] || FailureQ[thenBody] || FailureQ[elseBody], $Failed,
            If[c, thenBody, elseBody]]]],
      $Failed]];

(* Let binding *)
leanExprToWL[LeanLet[name_String, _, val_, body_], ctx_List] :=
  Module[{sym = Unique[cleanName[name]], v, b},
    v = leanExprToWL[val, ctx];
    b = leanExprToWL[body, Append[ctx, sym]];
    If[FailureQ[v] || FailureQ[b], $Failed,
      (* Build: With[{sym = v}, b] using injection *)
      With[{s = sym, val0 = v, body0 = b},
        Hold[With][Hold[{s = val0}], Hold[body0]] // ReleaseHold]]];

(* Lambda in body -- nested function *)
leanExprToWL[LeanLam[name_, type_, body_, _], ctx_List] :=
  Module[{sym = Unique[cleanName[name]], tyWL, b},
    tyWL = leanTypeToWL[type];
    b = leanExprToWL[body, Append[ctx, sym]];
    If[FailureQ[tyWL] || FailureQ[b], $Failed,
      With[{s = sym, t = tyWL, bd = b},
        Function[Typed[s, t], bd]]]];

(* MData wrapper -- pass through *)
leanExprToWL[LeanMData[_, expr_], ctx_List] := leanExprToWL[expr, ctx];

(* Generic application fallback -- try to translate head + args *)
leanExprToWL[e_LeanApp, ctx_List] :=
  Module[{head, args, headWL, argsWL},
    {head, args} = flattenApp[e];
    headWL = leanExprToWL[head, ctx];
    argsWL = leanExprToWL[#, ctx] & /@ args;
    If[FailureQ[headWL] || AnyTrue[argsWL, FailureQ],
      $Failed,
      headWL @@ argsWL]];

(* Named constant fallback -- return as-is; won't be compilable but captures structure *)
leanExprToWL[LeanConst[name_String, _], _List] := 
  With[{sn = shortName[name]}, Symbol[sn]];

(* Fallbacks *)
leanExprToWL[LeanNoValue[], _] := $Failed;
leanExprToWL[_, _] := $Failed;

(* ---- Peel lambda binders from term body, collecting explicit params ---- *)
(* Returns {paramList, body} where paramList = {{sym, wlType}, ...} *)
(* sym is a unique WL symbol created for each param *)
peelLambdas[term_, paramTypes_List] := Module[
  {params = {}, body = term, name, type, bi, remaining = paramTypes, sym},
  While[MatchQ[body, LeanLam[_, _, _, _]] && Length[remaining] > 0,
    {name, type, body, bi} = {body[[1]], body[[2]], body[[3]], body[[4]]};
    If[bi === "default",
      sym = Unique[cleanName[name]];
      AppendTo[params, {sym, First[remaining][[2]]}];
      remaining = Rest[remaining],
      (* implicit binder -- skip, don't consume from paramTypes *)
      Null];
    ];
  {params, body}];

(* ---- Main API: LeanToFunction ---- *)

LeanToFunction[term_LeanTerm] := Module[
  {data = term[[1]], kind, typeExpr, termExpr, sig, params, lambdaParams,
   body, ctx, bodyWL, argSpecs, handle, name},
  kind = Lookup[data, "Kind", "?"];
  If[kind =!= "def",
    Message[LeanToFunction::notdef, kind]; Return[$Failed]];
  (* Get type and term *)
  handle = Lookup[data, "_Handle", None];
  name = Lookup[data, "Name", ""];
  typeExpr = term["Type"];
  termExpr = term["Term"];
  If[MatchQ[typeExpr, _Missing | $Failed],
    Message[LeanToFunction::notype, "(unavailable)"]; Return[$Failed]];
  If[MatchQ[termExpr, _Missing | $Failed | LeanNoValue[]],
    Message[LeanToFunction::noterm]; Return[$Failed]];
  (* Extract function signature from type *)
  sig = collectFunctionSignature[typeExpr];
  If[FailureQ[sig],
    Message[LeanToFunction::notype, Short[typeExpr]]; Return[$Failed]];
  params = sig["Params"];
  (* Peel lambda binders from term body -- creates unique symbols *)
  {lambdaParams, body} = peelLambdas[termExpr, params];
  (* Build variable context: list of actual symbols for de Bruijn resolution *)
  ctx = lambdaParams[[All, 1]];
  (* Translate body *)
  bodyWL = leanExprToWL[body, ctx];
  If[FailureQ[bodyWL],
    Message[LeanToFunction::badexpr, Short[body]]; Return[$Failed]];
  (* Build Function[{Typed[sym, "Type"], ...}, body] *)
  argSpecs = Typed[#[[1]], #[[2]]] & /@ lambdaParams;
  If[Length[argSpecs] === 1,
    Function @@ {argSpecs[[1]], bodyWL},
    Function @@ {argSpecs, bodyWL}]];

(* ---- LeanCompile: convenience for FunctionCompile ---- *)

LeanCompile[term_LeanTerm] := Module[{fn = LeanToFunction[term]},
  If[FailureQ[fn], $Failed, FunctionCompile[fn]]];

LeanCompile[env_LeanEnvironment] := Module[
  {data = env[[1]], names, results = <||>},
  names = Select[Keys[data], !StringStartsQ[#, "_"] &];
  Do[
    With[{term = env[name]},
      If[Head[term] === LeanTerm && Lookup[term[[1]], "Kind", ""] === "def",
        With[{cf = Quiet[LeanCompile[term]]},
          If[Head[cf] === CompiledCodeFunction,
            AssociateTo[results, name -> cf]]]]],
    {name, names}];
  results];

End[];
EndPackage[];

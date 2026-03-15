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
LeanImport::usage = "LeanImport[module, opts] imports constants from a Lean module. \
Returns \[LeftAssociation]name \[Rule] LeanTerm[...], ...\[RightAssociation]. \
Options: \"ProjectDir\", \"Imports\", \"Filter\".";
LeanExpr::usage = "LeanExpr[name, opts] returns the type of a Lean constant as a symbolic expression tree.";
LeanValue::usage = "LeanValue[name, opts] returns the proof/definition body of a Lean constant.";
LeanConstantInfo::usage = "LeanConstantInfo[name, opts] returns full constant info as LeanConstant[name, kind, type, term].";
LeanListConstants::usage = "LeanListConstants[opts] lists all constants as \[LeftAssociation]name \[Rule] LeanConstant[...], ...\[RightAssociation].";
LeanLoadEnvironment::usage = "LeanLoadEnvironment[{\"Module1\", ...}, searchPath] loads a Lean environment handle for repeated queries.";
LeanFreeEnvironment::usage = "LeanFreeEnvironment[handle] frees a loaded Lean environment and releases memory.";

Begin["`Private`"];

(* ============================================================================ *)
(* Shim library                                                                 *)
(* ============================================================================ *)

$ShimLib := $ShimLib = Module[{loc},
  loc = FileNameJoin[{PacletObject["LeanLink"]["Location"],
    "Native", ".lake", "build", "lib", "libLeanLinkShim.dylib"}];
  If[FileExistsQ[loc], loc,
    loc = FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]],
      "Native", ".lake", "build", "lib", "libLeanLinkShim.dylib"}];
    If[FileExistsQ[loc], loc, $Failed]]];

(* Cache paclet root dir at load time (before $InputFileName becomes unset) *)
$PacletRoot = DirectoryName[DirectoryName[$InputFileName]];

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

resolveSearchPath[projDir_String] := Module[{buildLib, leanLib, paths},
  buildLib = FileNameJoin[{projDir, ".lake", "build", "lib"}];
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
  paths = Select[{buildLib, leanLib}, StringQ[#] && DirectoryQ[#] &];
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

resolveProjDir[pd_] := Replace[pd, Automatic -> Directory[]];

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

(* Call graph node colors — match code.lean DOT output *)
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

toLeanObject[LeanConstant[name_String, kind_String, type_, value_]] :=
  LeanTerm[<|"Name" -> name, "Kind" -> kind, "Type" -> type, "Term" -> value|>];
toLeanObject[other_] := other;

(* Attach environment kind lookup and call graph adjacency to all LeanTerms *)
(* When handle is provided, does BFS to collect types/terms of referenced constants *)
attachEnvKinds[env_Association, handle_ : None] := Module[
  {result, typeRefs, termRefs, frontier, visited, maxDepth = 10, depth = 0},

  (* Start with imported constants, adding per-constant refs *)
  result = env;

  (* Attach TypeRefs/TermRefs to each imported constant *)
  If[IntegerQ[handle] && handle > 0,
    (* Use FFI getUsedConstants (matches DOT getUsedConstantsAsSet) *)
    Do[
      Quiet @ With[{uc = decodeWXF[$getUsedConstantsFn[handle, name]]},
        If[AssociationQ[uc],
          result = MapAt[
            Replace[LeanTerm[d_Association] :>
              LeanTerm[Append[d, {"TypeRefs" -> Lookup[uc, "type", {}],
                                  "TermRefs" -> Lookup[uc, "value", {}]}]]],
            result, Key[name]]]],
      {name, Keys[env]}],
    (* Fallback: walk decoded expressions *)
    result = Association @ KeyValueMap[
      Function[{k, v},
        k -> Replace[v, LeanTerm[d_Association] :>
          LeanTerm[Append[d,
            {"TypeRefs" -> collectConsts[Lookup[d, "Type", LeanNoValue[]]],
             "TermRefs" -> collectConsts[Lookup[d, "Term", LeanNoValue[]]]}]]]],
      env]];

  (* BFS to discover referenced constants not in the original import *)
  If[IntegerQ[handle] && handle > 0,
    visited = Keys[result] // Association[# -> True & /@ #] &;
    frontier = Complement[
      Union @ Flatten @ Join[
        Cases[Values[result], LeanTerm[d_] :> Lookup[d, "TypeRefs", {}]],
        Cases[Values[result], LeanTerm[d_] :> Lookup[d, "TermRefs", {}]]],
      Keys[visited]];
    While[frontier =!= {} && depth < maxDepth,
      depth++;
      Do[
        Module[{kind = "def", tRefs = {}, vRefs = {}},
          (* Get kind *)
          Quiet @ With[{r = decodeWXF[$getConstantFn[handle, name]]},
            If[MatchQ[r, LeanConstant[_, _String, __]],
              kind = r[[2]]]];
          (* Get used constants *)
          Quiet @ With[{uc = decodeWXF[$getUsedConstantsFn[handle, name]]},
            If[AssociationQ[uc],
              tRefs = Lookup[uc, "type", {}];
              vRefs = Lookup[uc, "value", {}]]];
          (* Add as new LeanTerm entry *)
          AssociateTo[result, name ->
            LeanTerm[<|"Name" -> name, "Kind" -> kind,
                       "TypeRefs" -> tRefs, "TermRefs" -> vRefs|>]]];
        AssociateTo[visited, name -> True],
        {name, frontier}];
      frontier = Complement[
        Union @ Flatten @ KeyValueMap[
          Function[{k, v},
            Replace[v, {LeanTerm[d_] :> Join[Lookup[d, "TypeRefs", {}], Lookup[d, "TermRefs", {}]],
                        _ -> {}}]],
          KeyTake[result, frontier]],
        Keys[visited]]]];

  (* Store only the handle integer in each LeanTerm for callGraph BFS *)
  If[IntegerQ[handle] && handle > 0,
    Association @ KeyValueMap[
      Function[{k, v},
        k -> Replace[v, LeanTerm[d_Association] :>
          LeanTerm[Append[d, "_Handle" -> handle]]]],
      result],
    result]];

(* Property access *)
LeanTerm /: LeanTerm[data_Association][prop_String, opts___Rule] :=
  Switch[prop,
    "Properties", {"Name", "Kind", "Type", "Term", "TypeRefs", "TermRefs", "ExprGraph", "CallGraph"},
    "ExprGraph", exprToGraph[
      Replace[Lookup[data, "Term", LeanNoValue[]], LeanNoValue[] -> Lookup[data, "Type", LeanNoValue[]]]],
    "CallGraph", callGraph[data, opts],
    _, If[StringStartsQ[prop, "_"], Missing["Private", prop], data[prop]]];

(* ============================================================================ *)
(* Expression Graph                                                             *)
(* ============================================================================ *)

(* Expr graph node background colors — match code.lean exprKindColor exactly *)
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
  refsCache = <|name -> {Lookup[data, "TypeRefs", {}], Lookup[data, "TermRefs", {}]}|>;

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
  {name, kind, typeExpr, termExpr, col, icon, sn, nTypeRefs, nTermRefs},
  name = Lookup[data, "Name", "?"];
  kind = Lookup[data, "Kind", "?"];
  typeExpr = Lookup[data, "Type", None];
  termExpr = Lookup[data, "Term", LeanNoValue[]];
  nTypeRefs = Length[Lookup[data, "TypeRefs", {}]];
  nTermRefs = Length[Lookup[data, "TermRefs", {}]];
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
        If[typeExpr =!= None, Short[typeExpr, 1], "—"]}],
      If[termExpr =!= LeanNoValue[],
        BoxForm`SummaryItem[{"Term: ", Short[termExpr, 1]}],
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

Options[LeanImport] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Filter" -> ""};

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
    buildLib = FileNameJoin[{projDir, ".lake", "build", "lib"}];
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
        (* Extract definition names from source .lean files *)
        srcDir = FileNameJoin[{projDir, Sequence @@ StringSplit[module, "."]}];
        srcFiles = If[DirectoryQ[srcDir],
          FileNames["*.lean", srcDir, Infinity], {}];
        allNames = Flatten[Function[{file},
          With[{content = Import[file, "Text"],
                modPrefix = StringReplace[
                  StringDrop[file, StringLength[projDir] + 1],
                  {".lean" -> "", "/" -> "."}] <> "."},
            StringCases[content,
              RegularExpression[
                "(?m)^(?:noncomputable\\s+)?(?:def|theorem|lemma|inductive|structure|class|instance|abbrev)\\s+([a-zA-Z_][a-zA-Z0-9_.']*)"
              ] :> modPrefix <> "$1"]]] /@ srcFiles];
        (* Apply user filter *)
        If[filter =!= "",
          allNames = Select[allNames, StringContainsQ[#, filter] &]];
        allNames = Select[allNames, !isInternalName[#] &];
        (* Group names by sub-module *)
        grouped = GroupBy[allNames,
          StringJoin[Riffle[Most[StringSplit[#, "."]], "."]] &];
        (* For each sub-module, load env and query matching constants *)
        KeyValueMap[
          Function[{sub, names},
            If[MemberQ[subModules, sub],
              Module[{h, raw = <||>},
                h = Quiet[getOrLoadEnv[projDir, {sub}]];
                If[IntegerQ[h] && h > 0,
                  Do[
                    With[{c = Quiet[decodeWXF[$getConstantFn[h, nm]]]},
                      If[MatchQ[c, _LeanConstant],
                        AssociateTo[raw, nm -> c]]],
                    {nm, names}];
                  If[Length[raw] > 0,
                    results = Join[results,
                      attachEnvKinds[toLeanObject /@ raw, h]]]]]]],
          grouped];
        Return[results, Module]]];
    LeanImport["Imports" -> {module}, opts]];

(* LeanImport[file, opts] -- standalone .lean file: compile via lean CLI *)
LeanImport[file_String, opts : OptionsPattern[]] /;
  FileExistsQ[file] && StringEndsQ[file, ".lean"] :=
  Module[{absFile, projDir, modName, tmpDir, oleanFile, result, searchPath,
          pacletNativeDir, tcFile, tcName, leanBin, leanLibDir, content, names},
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
    pacletNativeDir = FileNameJoin[{$PacletRoot, "Native"}];
    tcFile = FileNameJoin[{pacletNativeDir, "lean-toolchain"}];
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
    (* Extract definition names from source file *)
    content = Import[absFile, "Text"];
    names = StringCases[content,
      RegularExpression["(?m)^(?:noncomputable\\s+)?(?:def|theorem|lemma|inductive|structure|class|instance|abbrev)\\s+([a-zA-Z_][a-zA-Z0-9_.]*)"] :> "$1"];
    If[names === {}, names = {modName}];
    (* Import the olean via existing loadEnv mechanism *)
    searchPath = tmpDir <> ":" <> leanLibDir;
    Block[{handle, raw, res},
      handle = $loadEnvFn[modName, searchPath];
      If[handle === 0 || !IntegerQ[handle],
        Message[LeanLink::err, "Failed to load compiled file"];
        DeleteDirectory[tmpDir, DeleteContents -> True];
        Return[$Failed, Module]];
      (* Query each name individually *)
      raw = Association[];
      Do[
        With[{r = Quiet[decodeWXF[$getConstantFn[handle, name]]]},
          If[MatchQ[r, _LeanConstant],
            AssociateTo[raw, name -> r]]],
        {name, names}];
      res = attachEnvKinds[toLeanObject /@ raw, handle];
      DeleteDirectory[tmpDir, DeleteContents -> True];
      res]];

(* LeanImport[opts] -- base form *)
LeanImport[opts : OptionsPattern[]] := Module[{handle, raw, result},
  If[$ShimLib === $Failed, Message[LeanLink::nolib]; Return[$Failed]];
  handle = getOrLoadEnv[resolveProjDir[OptionValue["ProjectDir"]], OptionValue["Imports"]];
  If[handle === $Failed, Return[$Failed]];
  raw = decodeWXF[$listTheoremsFn[handle, OptionValue["Filter"]]];
  If[!AssociationQ[raw], Return[$Failed]];
  (* Filter out internal/generated names *)
  raw = KeySelect[raw, !isInternalName[#] &];
  attachEnvKinds[toLeanObject /@ raw, handle]];

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

End[];
EndPackage[];

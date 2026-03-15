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

decodeWXF[tensor_] := BinaryDeserialize[ByteArray[Flatten[tensor]]];

(* ============================================================================ *)
(* Utilities                                                                    *)
(* ============================================================================ *)

cleanName[s_String] := StringReplace[s, RegularExpression["\\._@\\..*"] -> ""];
cleanName[other_] := other;

shortName[s_String] := Last[StringSplit[s, "."], s];

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

toLeanObject[LeanConstant[name_String, kind_String, type_, value_]] :=
  LeanTerm[<|"Name" -> name, "Kind" -> kind, "Type" -> type, "Term" -> value|>];
toLeanObject[other_] := other;

(* Property access *)
LeanTerm /: LeanTerm[data_Association][prop_String] :=
  Switch[prop,
    "Properties", {"Name", "Kind", "Type", "Term", "ExprGraph", "CallGraph"},
    "ExprGraph", exprToGraph[Lookup[data, "Type", LeanNoValue[]]],
    "CallGraph", callGraph[data],
    _, data[prop]];

(* ============================================================================ *)
(* Expression Graph                                                             *)
(* ============================================================================ *)

$headColor = <|
  LeanForall -> RGBColor[0.25, 0.5, 0.85],
  LeanLam -> RGBColor[0.6, 0.25, 0.65],
  LeanApp -> GrayLevel[0.35],
  LeanConst -> RGBColor[0.15, 0.55, 0.35],
  LeanBVar -> RGBColor[0.5, 0.5, 0.5],
  LeanSort -> RGBColor[0.6, 0.2, 0.6],
  LeanLet -> RGBColor[0.75, 0.55, 0.15],
  LeanLitNat -> RGBColor[0.15, 0.55, 0.2],
  LeanLitStr -> RGBColor[0.75, 0.35, 0.1],
  LeanProj -> GrayLevel[0.45],
  LeanTruncated -> GrayLevel[0.6],
  LeanNoValue -> GrayLevel[0.65]
|>;

exprToGraph[expr_] := Module[{id = 0, verts = {}, edges = {}, lbls = <||>, cols = <||>, walk},
  walk[e_] := Module[{myId, label, col, children},
    myId = ++id;
    {label, col, children} = exprNodeInfo[e];
    AppendTo[verts, myId];
    AssociateTo[lbls, myId -> label];
    AssociateTo[cols, myId -> col];
    Do[Module[{childId = walk[child]},
      AppendTo[edges, DirectedEdge[myId, childId]]],
      {child, children}];
    myId];
  walk[expr];
  If[Length[verts] == 0, Return[Graph[{}]]];
  Graph[verts, edges,
    VertexShapeFunction -> Map[
      With[{bg = cols[#], lbl = lbls[#]},
        # -> Function[
          Inset[Framed[
            Style[Tooltip[lbl, #2], "Text", FontSize -> 7,
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
    ImageSize -> Max[300, Min[1200, 40 * Length[verts]]],
    AspectRatio -> 1/2,
    PerformanceGoal -> "Quality"]];

exprNodeInfo[LeanForall[n_, dom_, body_, bi_]] :=
  {"\[ForAll]" <> cleanName[n], $headColor[LeanForall], {dom, body}};
exprNodeInfo[LeanLam[n_, type_, body_, _]] :=
  {"\[Lambda]" <> cleanName[n], $headColor[LeanLam], {type, body}};
exprNodeInfo[LeanApp[fn_, arg_]] :=
  {"App", $headColor[LeanApp], {fn, arg}};
exprNodeInfo[LeanConst[n_, _]] :=
  {shortName[n], $headColor[LeanConst], {}};
exprNodeInfo[LeanBVar[i_]] :=
  {"#" <> ToString[i], $headColor[LeanBVar], {}};
exprNodeInfo[LeanSort[LeanLevelZero[]]] := {"Prop", $headColor[LeanSort], {}};
exprNodeInfo[LeanSort[LeanLevelSucc[LeanLevelZero[]]]] := {"Type", $headColor[LeanSort], {}};
exprNodeInfo[LeanSort[_]] := {"Sort", $headColor[LeanSort], {}};
exprNodeInfo[LeanLet[n_, type_, val_, body_]] :=
  {"let " <> cleanName[n], $headColor[LeanLet], {type, val, body}};
exprNodeInfo[LeanLitNat[n_]] := {ToString[n], $headColor[LeanLitNat], {}};
exprNodeInfo[LeanLitStr[s_]] := {"\"" <> s <> "\"", $headColor[LeanLitStr], {}};
exprNodeInfo[LeanProj[t_, i_, struct_]] :=
  {shortName[t] <> "." <> ToString[i], $headColor[LeanProj], {struct}};
exprNodeInfo[LeanTruncated[_]] := {"\[Ellipsis]", $headColor[LeanTruncated], {}};
exprNodeInfo[LeanNoValue[]] := {"\[Dash]", $headColor[LeanNoValue], {}};
exprNodeInfo[other_] := {ToString[Short[other]], GrayLevel[0.6], {}};

(* ============================================================================ *)
(* Call Graph                                                                   *)
(* ============================================================================ *)

collectConsts[e_] := Union[Cases[e, LeanConst[n_String, _] :> n, Infinity]];

callGraph[data_Association] := Module[{name, typeExpr, termExpr, refs, edges, verts, rootShort, rootCol},
  name = data["Name"];
  typeExpr = Lookup[data, "Type", LeanNoValue[]];
  termExpr = Lookup[data, "Term", LeanNoValue[]];
  refs = Union[collectConsts[typeExpr], collectConsts[termExpr]];
  refs = DeleteCases[refs, name];
  rootShort = shortName[name];
  rootCol = Lookup[$kindColor, Lookup[data, "Kind", "def"], GrayLevel[0.5]];
  verts = Union[Prepend[shortName /@ refs, rootShort]];
  edges = DirectedEdge[rootShort, shortName[#]] & /@ refs;
  Graph[verts, edges,
    VertexShapeFunction -> Map[
      With[{bg = If[# === rootShort, rootCol, GrayLevel[0.55]], lbl = #},
        # -> Function[
          Inset[Framed[
            Style[Tooltip[lbl, #2], "Text", FontSize -> 7,
              LightDarkSwitched[
                If[ColorDistance[bg, White] > 0.4, White, Black],
                If[ColorDistance[bg, Black] > 0.4, White, GrayLevel[0.9]]],
              Bold],
            Background -> LightDarkSwitched[bg],
            RoundingRadius -> 3,
            FrameStyle -> LightDarkSwitched[GrayLevel[0.4], GrayLevel[0.6]],
            FrameMargins -> {{3, 3}, {1, 1}}], #1, #3]]
      ] &, verts],
    GraphLayout -> {"LayeredDigraphEmbedding", "Orientation" -> Left},
    VertexSize -> If[Length[verts] <= 10, 0.3, 0.05],
    EdgeStyle -> Directive[GrayLevel[0.5], Arrowheads[0.02]],
    ImageSize -> Max[300, Min[900, 40 * Length[verts]]],
    AspectRatio -> 1/2,
    PerformanceGoal -> "Quality"]];

(* ============================================================================ *)
(* LeanTerm SummaryBox                                                          *)
(* ============================================================================ *)

LeanTerm /: MakeBoxes[obj : LeanTerm[data_Association], StandardForm] := Module[
  {name, kind, typeExpr, termExpr, col, icon, sn},
  name = Lookup[data, "Name", "?"];
  kind = Lookup[data, "Kind", "?"];
  typeExpr = Lookup[data, "Type", None];
  termExpr = Lookup[data, "Term", LeanNoValue[]];
  col = Lookup[$kindColor, kind, GrayLevel[0.5]];
  icon = Graphics[{col, Disk[]}, ImageSize -> 12];
  sn = shortName[name];

  BoxForm`ArrangeSummaryBox[LeanTerm, obj, icon,
    {
      BoxForm`SummaryItem[{"Kind: ", Style[kind, Bold, col]}],
      BoxForm`SummaryItem[{"Name: ", Style[sn, Bold]}]
    },
    {
      BoxForm`SummaryItem[{"Full name: ", name}],
      BoxForm`SummaryItem[{"Type: ",
        RawBoxes[MakeBoxes[typeExpr, StandardForm]]}],
      If[termExpr =!= LeanNoValue[],
        BoxForm`SummaryItem[{"Term: ",
          RawBoxes[MakeBoxes[termExpr, StandardForm]]}],
        Nothing]
    },
    StandardForm,
    "Interpretable" -> Automatic]];

(* ============================================================================ *)
(* Expression head formatting                                                   *)
(* ============================================================================ *)

LeanConst /: MakeBoxes[expr : LeanConst[name_String, levels_List], StandardForm] :=
  With[{short = shortName[name], full = name},
    InterpretationBox[
      TooltipBox[
        StyleBox[short, FontColor -> RGBColor[0.15, 0.35, 0.6], FontWeight -> Bold],
        full],
      expr]];

LeanForall /: MakeBoxes[expr : LeanForall[name_String, dom_, body_, bi_String], StandardForm] :=
  With[{nm = cleanName[name]},
    InterpretationBox[
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
        StyleBox[" \[Rule] ", FontColor -> GrayLevel[0.4]],
        MakeBoxes[body, StandardForm]}],
      expr]];

LeanApp /: MakeBoxes[expr : LeanApp[fn_, arg_], StandardForm] :=
  InterpretationBox[
    RowBox[{MakeBoxes[fn, StandardForm], " ", MakeBoxes[arg, StandardForm]}],
    expr];

LeanLam /: MakeBoxes[expr : LeanLam[name_String, type_, body_, bi_String], StandardForm] :=
  With[{nm = cleanName[name]},
    InterpretationBox[
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
        StyleBox[" => ", FontColor -> GrayLevel[0.4]],
        MakeBoxes[body, StandardForm]}],
      expr]];

(* LeanBVar: pre-evaluate the string with With *)
LeanBVar /: MakeBoxes[expr : LeanBVar[idx_Integer], StandardForm] :=
  With[{label = "#" <> ToString[idx], tip = "bound var " <> ToString[idx]},
    InterpretationBox[
      TooltipBox[StyleBox[label, FontColor -> GrayLevel[0.5]], tip],
      expr]];

LeanSort /: MakeBoxes[expr : LeanSort[LeanLevelZero[]], StandardForm] :=
  InterpretationBox[StyleBox["Prop", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold], expr];
LeanSort /: MakeBoxes[expr : LeanSort[LeanLevelSucc[LeanLevelZero[]]], StandardForm] :=
  InterpretationBox[StyleBox["Type", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold], expr];
LeanSort /: MakeBoxes[expr : LeanSort[level_], StandardForm] :=
  InterpretationBox[
    RowBox[{StyleBox["Sort", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold],
      " ", MakeBoxes[level, StandardForm]}],
    expr];

LeanLitNat /: MakeBoxes[expr : LeanLitNat[n_Integer], StandardForm] :=
  With[{s = ToString[n]},
    InterpretationBox[StyleBox[s, FontColor -> RGBColor[0.1, 0.5, 0.1]], expr]];
LeanLitStr /: MakeBoxes[expr : LeanLitStr[s_String], StandardForm] :=
  With[{display = "\"" <> s <> "\""},
    InterpretationBox[StyleBox[display, FontColor -> RGBColor[0.7, 0.3, 0.1]], expr]];

LeanLet /: MakeBoxes[expr : LeanLet[name_String, type_, val_, body_], StandardForm] :=
  With[{nm = cleanName[name]},
    InterpretationBox[
      RowBox[{StyleBox["let ", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold],
        StyleBox[nm, FontSlant -> Italic, Bold],
        " : ", MakeBoxes[type, StandardForm],
        " := ", MakeBoxes[val, StandardForm],
        "; ", MakeBoxes[body, StandardForm]}],
      expr]];

LeanNoValue /: MakeBoxes[expr : LeanNoValue[], StandardForm] :=
  InterpretationBox[StyleBox["\[Dash]", FontColor -> GrayLevel[0.6]], expr];

LeanTruncated /: MakeBoxes[expr : LeanTruncated[info_], StandardForm] :=
  InterpretationBox[
    TooltipBox[StyleBox["\[Ellipsis]", FontColor -> GrayLevel[0.5]],
      MakeBoxes[info, StandardForm]],
    expr];

LeanProj /: MakeBoxes[expr : LeanProj[typeName_, idx_Integer, struct_], StandardForm] :=
  With[{field = ToString[idx]},
    InterpretationBox[
      RowBox[{MakeBoxes[struct, StandardForm], ".",
        StyleBox[field, FontColor -> GrayLevel[0.5]]}],
      expr]];

LeanFVar /: MakeBoxes[expr : LeanFVar[name_], StandardForm] :=
  With[{display = cleanName[ToString[name]]},
    InterpretationBox[
      StyleBox[display, FontColor -> RGBColor[0.4, 0.4, 0.7], FontSlant -> Italic],
      expr]];
LeanMVar /: MakeBoxes[expr : LeanMVar[name_], StandardForm] :=
  With[{display = "?" <> cleanName[ToString[name]]},
    InterpretationBox[
      StyleBox[display, FontColor -> RGBColor[0.7, 0.4, 0.4], FontSlant -> Italic],
      expr]];

(* ============================================================================ *)
(* Level formatting                                                             *)
(* ============================================================================ *)

LeanLevelZero /: MakeBoxes[expr : LeanLevelZero[], StandardForm] :=
  InterpretationBox[StyleBox["0", FontColor -> GrayLevel[0.5], FontSize -> 9], expr];

LeanLevelSucc /: MakeBoxes[expr : LeanLevelSucc[l_], StandardForm] :=
  InterpretationBox[
    RowBox[{MakeBoxes[l, StandardForm],
      StyleBox["+1", FontColor -> GrayLevel[0.5], FontSize -> 9]}],
    expr];

LeanLevelMax /: MakeBoxes[expr : LeanLevelMax[a_, b_], StandardForm] :=
  InterpretationBox[
    RowBox[{StyleBox["max", FontColor -> GrayLevel[0.5], FontSize -> 9],
      "(", MakeBoxes[a, StandardForm], ", ", MakeBoxes[b, StandardForm], ")"}],
    expr];

LeanLevelIMax /: MakeBoxes[expr : LeanLevelIMax[a_, b_], StandardForm] :=
  InterpretationBox[
    RowBox[{StyleBox["imax", FontColor -> GrayLevel[0.5], FontSize -> 9],
      "(", MakeBoxes[a, StandardForm], ", ", MakeBoxes[b, StandardForm], ")"}],
    expr];

LeanLevelParam /: MakeBoxes[expr : LeanLevelParam[name_String], StandardForm] :=
  InterpretationBox[
    StyleBox[name, FontColor -> RGBColor[0.4, 0.55, 0.4],
      FontSlant -> Italic, FontSize -> 9],
    expr];

LeanLevelMVar /: MakeBoxes[expr : LeanLevelMVar[name_], StandardForm] :=
  With[{display = "?" <> ToString[name]},
    InterpretationBox[
      StyleBox[display, FontColor -> GrayLevel[0.6],
        FontSlant -> Italic, FontSize -> 9],
      expr]];

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
LeanImport[module_String, opts : OptionsPattern[]] /;
  !StringContainsQ[module, "/" | "\\"] && !StringEndsQ[module, ".lean"] :=
  LeanImport["Imports" -> {module}, opts];

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
      DeleteDirectory[tmpDir, DeleteContents -> True];
      toLeanObject /@ raw]];

(* LeanImport[opts] -- base form *)
LeanImport[opts : OptionsPattern[]] := Module[{raw},
  raw = callNative[$listTheoremsFn,
    {OptionValue["Filter"]},
    resolveProjDir[OptionValue["ProjectDir"]],
    OptionValue["Imports"]];
  If[!AssociationQ[raw], Return[$Failed]];
  (* Filter out internal/generated names *)
  raw = KeySelect[raw, !isInternalName[#] &];
  toLeanObject /@ raw];

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

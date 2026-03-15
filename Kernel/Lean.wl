(* ::Package:: *)
(* Lean.wl -- Native Lean integration via LibraryLink *)

BeginPackage["LeanLink`"];

(* ============================================================================ *)
(* Expression heads                                                             *)
(* ============================================================================ *)

LeanApp::usage = "LeanApp[fn, arg] represents function application.";
LeanLam::usage = "LeanLam[name, type, body, binder] represents a lambda. binder: \"default\"|\"implicit\"|\"strictImplicit\"|\"instImplicit\".";
LeanForall::usage = "LeanForall[name, type, body, binder] represents a dependent function type (\[ForAll]/\[Rule]).";
LeanLet::usage = "LeanLet[name, type, val, body] represents a let binding.";
LeanConst::usage = "LeanConst[name, levels] represents a reference to a named constant.";
LeanBVar::usage = "LeanBVar[index] represents a bound variable (de Bruijn index).";
LeanFVar::usage = "LeanFVar[name] represents a free variable.";
LeanMVar::usage = "LeanMVar[name] represents a metavariable.";
LeanSort::usage = "LeanSort[level] represents a universe (Prop, Type, Sort).";
LeanLitNat::usage = "LeanLitNat[n] represents a natural number literal.";
LeanLitStr::usage = "LeanLitStr[s] represents a string literal.";
LeanProj::usage = "LeanProj[type, index, struct] represents a structure field projection.";
LeanTruncated::usage = "LeanTruncated[info] represents an expression truncated at the depth limit.";
LeanNoValue::usage = "LeanNoValue[] indicates a constant with no definition (axiom, opaque).";

LeanLevelZero::usage = "LeanLevelZero[] represents universe level 0 (Prop).";
LeanLevelSucc::usage = "LeanLevelSucc[level] represents the successor of a universe level.";
LeanLevelMax::usage = "LeanLevelMax[a, b] represents max of two universe levels.";
LeanLevelIMax::usage = "LeanLevelIMax[a, b] represents impredicative max.";
LeanLevelParam::usage = "LeanLevelParam[name] represents a named universe parameter.";
LeanLevelMVar::usage = "LeanLevelMVar[name] represents a universe metavariable.";

LeanConstant::usage = "LeanConstant[name, kind, type, term] is raw constant info from the native API.";

LeanTerm::usage = "LeanTerm[\[LeftAssociation]\"Name\"\[Rule]..., \"Kind\"\[Rule]..., \"Type\"\[Rule]..., \"Term\"\[Rule]...\[RightAssociation]] represents a Lean constant. Properties: \"Name\", \"Kind\", \"Type\", \"Term\", \"ExprGraph\", \"CallGraph\", \"Properties\".";

LeanImport::usage = "LeanImport[opts] imports a Lean module, returning \[LeftAssociation]name \[Rule] LeanTerm[...], ...\[RightAssociation].";
LeanExpr::usage = "LeanExpr[name, opts] returns the type of a constant as a symbolic expression tree.";
LeanValue::usage = "LeanValue[name, opts] returns the value/proof term of a constant.";
LeanConstantInfo::usage = "LeanConstantInfo[name, opts] returns full constant info as LeanConstant.";
LeanListConstants::usage = "LeanListConstants[opts] returns \[LeftAssociation]name \[Rule] LeanConstant[...], ...\[RightAssociation].";
LeanLoadEnvironment::usage = "LeanLoadEnvironment[imports, searchPath] loads a Lean environment handle.";
LeanFreeEnvironment::usage = "LeanFreeEnvironment[handle] frees a loaded Lean environment.";

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

LeanLink::nolib = "Shim library not found. Build it first.";
LeanLink::err = "Lean error: `1`";

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

(* Property access -- including computed graph properties *)
LeanTerm /: LeanTerm[data_Association][prop_String] :=
  Switch[prop,
    "Properties", {"Name", "Kind", "Type", "Term", "ExprGraph", "CallGraph"},
    "ExprGraph", exprToGraph[Lookup[data, "Type", LeanNoValue[]]],
    "CallGraph", callGraph[data],
    _, data[prop]];

(* ============================================================================ *)
(* Expression Graph — build a Graph from the expression tree                    *)
(* ============================================================================ *)

(* Color map for expression heads *)
$headColor = <|
  LeanForall -> RGBColor[0.25, 0.45, 0.85],
  LeanLam -> RGBColor[0.6, 0.2, 0.6],
  LeanApp -> GrayLevel[0.4],
  LeanConst -> RGBColor[0.15, 0.5, 0.3],
  LeanBVar -> GrayLevel[0.5],
  LeanSort -> RGBColor[0.6, 0.2, 0.6],
  LeanLet -> RGBColor[0.7, 0.5, 0.1],
  LeanLitNat -> RGBColor[0.1, 0.5, 0.1],
  LeanLitStr -> RGBColor[0.7, 0.3, 0.1],
  LeanProj -> GrayLevel[0.45],
  LeanTruncated -> GrayLevel[0.6],
  LeanNoValue -> GrayLevel[0.6]
|>;

(* Assign unique IDs and collect vertices/edges by traversing the tree *)
exprToGraph[expr_] := Module[{id = 0, verts = {}, edges = {}, labels = {}, colors = {},
    walk},
  walk[e_] := Module[{myId, label, col, children},
    myId = ++id;
    {label, col, children} = exprNodeInfo[e];
    AppendTo[verts, myId];
    AppendTo[labels, myId -> Placed[label, Center]];
    AppendTo[colors, myId -> col];
    Do[
      Module[{childId},
        childId = walk[child];
        AppendTo[edges, DirectedEdge[myId, childId]]],
      {child, children}];
    myId];
  walk[expr];
  If[Length[verts] == 0, Return[Graph[{}]]];
  Graph[verts, edges,
    VertexLabels -> labels,
    VertexStyle -> colors,
    VertexSize -> 0.6,
    VertexShapeFunction -> (
      Inset[Framed[
        Style[Lookup[Association @@ labels, #2, ""], "Text", FontSize -> 8,
          White, Bold],
        Background -> Lookup[Association @@ colors, #2, GrayLevel[0.5]],
        RoundingRadius -> 4,
        FrameStyle -> None,
        FrameMargins -> {{4, 4}, {2, 2}}], #1, Center, #3] &),
    GraphLayout -> {"LayeredDigraphEmbedding", "Orientation" -> Top},
    EdgeStyle -> Directive[GrayLevel[0.5], Arrowheads[0.02]],
    ImageSize -> Medium]];

(* Extract label, color, children for each expression node *)
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
exprNodeInfo[LeanSort[LeanLevelZero[]]] :=
  {"Prop", $headColor[LeanSort], {}};
exprNodeInfo[LeanSort[LeanLevelSucc[LeanLevelZero[]]]] :=
  {"Type", $headColor[LeanSort], {}};
exprNodeInfo[LeanSort[l_]] :=
  {"Sort", $headColor[LeanSort], {}};
exprNodeInfo[LeanLet[n_, type_, val_, body_]] :=
  {"let " <> cleanName[n], $headColor[LeanLet], {type, val, body}};
exprNodeInfo[LeanLitNat[n_]] :=
  {ToString[n], $headColor[LeanLitNat], {}};
exprNodeInfo[LeanLitStr[s_]] :=
  {"\"" <> s <> "\"", $headColor[LeanLitStr], {}};
exprNodeInfo[LeanProj[t_, i_, struct_]] :=
  {shortName[t] <> "." <> ToString[i], $headColor[LeanProj], {struct}};
exprNodeInfo[LeanTruncated[_]] :=
  {"\[Ellipsis]", $headColor[LeanTruncated], {}};
exprNodeInfo[LeanNoValue[]] :=
  {"\[Dash]", $headColor[LeanNoValue], {}};
exprNodeInfo[other_] :=
  {ToString[Short[other]], GrayLevel[0.6], {}};

(* ============================================================================ *)
(* Call Graph — collect constant references as edges                            *)
(* ============================================================================ *)

(* Collect all LeanConst names referenced in an expression *)
collectConsts[e_] := Union[Cases[e, LeanConst[n_String, _] :> n, Infinity]];

callGraph[data_Association] := Module[{name, typeExpr, termExpr, refs, edges, verts},
  name = data["Name"];
  typeExpr = Lookup[data, "Type", LeanNoValue[]];
  termExpr = Lookup[data, "Term", LeanNoValue[]];
  refs = Union[collectConsts[typeExpr], collectConsts[termExpr]];
  refs = DeleteCases[refs, name]; (* remove self-references *)
  edges = DirectedEdge[shortName[name], shortName[#]] & /@ refs;
  verts = Union[Prepend[shortName /@ refs, shortName[name]]];
  Graph[verts, edges,
    VertexLabels -> "Name",
    VertexStyle -> (shortName[name] -> $kindColor[Lookup[data, "Kind", "def"]]),
    VertexSize -> 0.4,
    GraphLayout -> {"LayeredDigraphEmbedding", "Orientation" -> Left},
    EdgeStyle -> Directive[GrayLevel[0.5], Arrowheads[0.03]],
    ImageSize -> Medium]];

(* ============================================================================ *)
(* LeanTerm SummaryBox — using Interpretable -> Automatic                       *)
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
  With[{short = shortName[name]},
    InterpretationBox[
      TooltipBox[
        StyleBox[short, FontColor -> RGBColor[0.15, 0.35, 0.6], FontWeight -> Bold],
        RowBox[{MakeBoxes[name], " ", MakeBoxes[levels, StandardForm]}]],
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

LeanBVar /: MakeBoxes[expr : LeanBVar[idx_Integer], StandardForm] :=
  InterpretationBox[
    TooltipBox[
      StyleBox["#" <> ToString[idx], FontColor -> GrayLevel[0.5]],
      RowBox[{"bound var ", MakeBoxes[idx]}]],
    expr];

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
  InterpretationBox[StyleBox[ToString[n], FontColor -> RGBColor[0.1, 0.5, 0.1]], expr];
LeanLitStr /: MakeBoxes[expr : LeanLitStr[s_String], StandardForm] :=
  InterpretationBox[StyleBox["\"" <> s <> "\"", FontColor -> RGBColor[0.7, 0.3, 0.1]], expr];

LeanLet /: MakeBoxes[expr : LeanLet[name_String, type_, val_, body_], StandardForm] :=
  InterpretationBox[
    RowBox[{StyleBox["let ", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold],
      StyleBox[cleanName[name], FontSlant -> Italic, Bold],
      " : ", MakeBoxes[type, StandardForm],
      " := ", MakeBoxes[val, StandardForm],
      "; ", MakeBoxes[body, StandardForm]}],
    expr];

LeanNoValue /: MakeBoxes[expr : LeanNoValue[], StandardForm] :=
  InterpretationBox[StyleBox["\[Dash]", FontColor -> GrayLevel[0.6]], expr];

LeanTruncated /: MakeBoxes[expr : LeanTruncated[info_], StandardForm] :=
  InterpretationBox[
    TooltipBox[StyleBox["\[Ellipsis]", FontColor -> GrayLevel[0.5]],
      MakeBoxes[info, StandardForm]],
    expr];

LeanProj /: MakeBoxes[expr : LeanProj[typeName_, idx_Integer, struct_], StandardForm] :=
  InterpretationBox[
    RowBox[{MakeBoxes[struct, StandardForm], ".",
      StyleBox[ToString[idx], FontColor -> GrayLevel[0.5]]}],
    expr];

LeanFVar /: MakeBoxes[expr : LeanFVar[name_], StandardForm] :=
  InterpretationBox[
    StyleBox[cleanName[ToString[name]],
      FontColor -> RGBColor[0.4, 0.4, 0.7], FontSlant -> Italic],
    expr];
LeanMVar /: MakeBoxes[expr : LeanMVar[name_], StandardForm] :=
  InterpretationBox[
    StyleBox["?" <> cleanName[ToString[name]],
      FontColor -> RGBColor[0.7, 0.4, 0.4], FontSlant -> Italic],
    expr];

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
  InterpretationBox[
    StyleBox["?" <> ToString[name], FontColor -> GrayLevel[0.6],
      FontSlant -> Italic, FontSize -> 9],
    expr];

(* ============================================================================ *)
(* Public API                                                                   *)
(* ============================================================================ *)

LeanLoadEnvironment[imports_List, searchPath_String] :=
  $loadEnvFn[StringRiffle[imports, ","], searchPath];

LeanFreeEnvironment[handle_Integer] := ($freeEnvFn[handle]; Null);

Options[LeanImport] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Filter" -> ""};
LeanImport[opts : OptionsPattern[]] := Module[{raw},
  raw = callNative[$listTheoremsFn,
    {OptionValue["Filter"]},
    resolveProjDir[OptionValue["ProjectDir"]],
    OptionValue["Imports"]];
  If[!AssociationQ[raw], Return[$Failed]];
  toLeanObject /@ raw];
LeanImport[module_String, opts : OptionsPattern[]] :=
  LeanImport["Imports" -> {module}, opts];

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

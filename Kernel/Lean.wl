(* ::Package:: *)
(* Lean.wl -- Native Lean integration via LibraryLink *)

BeginPackage["LeanLink`"];

(* ============================================================================ *)
(* Expression heads                                                             *)
(* ============================================================================ *)

LeanApp::usage = "LeanApp[fn, arg] represents function application.";
LeanLam::usage = "LeanLam[name, type, body, binder] represents a lambda (\[Lambda]). binder is \"default\"|\"implicit\"|\"strictImplicit\"|\"instImplicit\".";
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

(* Level heads *)
LeanLevelZero::usage = "LeanLevelZero[] represents universe level 0 (Prop).";
LeanLevelSucc::usage = "LeanLevelSucc[level] represents the successor of a universe level.";
LeanLevelMax::usage = "LeanLevelMax[a, b] represents max of two universe levels.";
LeanLevelIMax::usage = "LeanLevelIMax[a, b] represents impredicative max (collapses to 0 if b is 0).";
LeanLevelParam::usage = "LeanLevelParam[name] represents a named universe parameter.";
LeanLevelMVar::usage = "LeanLevelMVar[name] represents a universe metavariable.";

(* Raw constant wrapper *)
LeanConstant::usage = "LeanConstant[name, kind, type, term] is the raw constant info returned by the native API.";

(* Unified typed constant *)
LeanTerm::usage = "LeanTerm[\[LeftAssociation]\"Name\"\[Rule]..., \"Kind\"\[Rule]..., \"Type\"\[Rule]..., \"Term\"\[Rule]...\[RightAssociation]] represents a Lean constant. Kind is \"theorem\"|\"def\"|\"axiom\"|\"inductive\"|\"constructor\"|\"recursor\"|\"opaque\"|\"quot\".";

(* Public API *)
LeanImport::usage = "LeanImport[opts] imports a Lean module, returning \[LeftAssociation]name \[Rule] LeanTerm[...], ...\[RightAssociation].";
LeanExpr::usage = "LeanExpr[name, opts] returns the type of a Lean constant as a symbolic expression tree.";
LeanValue::usage = "LeanValue[name, opts] returns the value/proof term of a Lean constant.";
LeanConstantInfo::usage = "LeanConstantInfo[name, opts] returns full constant info as LeanConstant[...].";
LeanListConstants::usage = "LeanListConstants[opts] returns \[LeftAssociation]name \[Rule] LeanConstant[...], ...\[RightAssociation].";
LeanLoadEnvironment::usage = "LeanLoadEnvironment[imports, searchPath] loads a Lean environment, returning a handle.";
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

(* Strip Lean hygiene: "a._@.Mod._hyg.42" -> "a" *)
cleanName[s_String] := StringReplace[s, RegularExpression["\\._@\\..*"] -> ""];
cleanName[other_] := other;

(* Short name: "Foo.Bar.baz" -> "baz" *)
shortName[s_String] := Last[StringSplit[s, "."], s];

(* ============================================================================ *)
(* Search path & environment                                                    *)
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
(* LeanTerm: unified typed constant                                             *)
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

(* Convert LeanConstant[name, kind, type, value] -> LeanTerm *)
toLeanObject[LeanConstant[name_String, kind_String, type_, value_]] :=
  LeanTerm[<|"Name" -> name, "Kind" -> kind, "Type" -> type, "Term" -> value|>];
toLeanObject[other_] := other;

(* Property access *)
LeanTerm /: LeanTerm[data_Association][prop_String] :=
  If[prop === "Properties", Keys[data], data[prop]];

(* ============================================================================ *)
(* InterpretationBox helper                                                     *)
(* ============================================================================ *)

(* Wrap display boxes in InterpretationBox so Copy gives back the expression *)
iBox[expr_, displayBoxes_] :=
  InterpretationBox[displayBoxes, expr];

(* Wrap display boxes in InterpretationBox + Tooltip showing InputForm *)
iBoxTip[expr_, displayBoxes_] :=
  InterpretationBox[
    TooltipBox[displayBoxes, MakeBoxes[Short[expr, 3], StandardForm]],
    expr];

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

  iBox[obj,
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
      StandardForm]]];

(* ============================================================================ *)
(* Expression head formatting                                                   *)
(* ============================================================================ *)

(* -- LeanConst: short name in blue, tooltip shows full name + levels -- *)
LeanConst /: MakeBoxes[expr : LeanConst[name_String, levels_List], StandardForm] :=
  iBox[expr,
    TooltipBox[
      StyleBox[shortName[name],
        FontColor -> RGBColor[0.15, 0.35, 0.6], FontWeight -> Bold],
      RowBox[{MakeBoxes[name], " ", MakeBoxes[levels, StandardForm]}]]];

(* -- LeanForall: (n : dom) -> body, {n : dom} -> body, [n : dom] -> body -- *)
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
        StyleBox[" \[Rule] ", FontColor -> GrayLevel[0.4]],
        MakeBoxes[body, StandardForm]}]]];

(* -- LeanApp: fn arg -- *)
LeanApp /: MakeBoxes[expr : LeanApp[fn_, arg_], StandardForm] :=
  iBox[expr,
    RowBox[{MakeBoxes[fn, StandardForm], " ", MakeBoxes[arg, StandardForm]}]];

(* -- LeanLam: fun (name : type) => body -- *)
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
        StyleBox[" => ", FontColor -> GrayLevel[0.4]],
        MakeBoxes[body, StandardForm]}]]];

(* -- LeanBVar: #idx -- *)
LeanBVar /: MakeBoxes[expr : LeanBVar[idx_Integer], StandardForm] :=
  iBox[expr,
    TooltipBox[
      StyleBox["#" <> ToString[idx], FontColor -> GrayLevel[0.5]],
      RowBox[{"bound var ", MakeBoxes[idx]}]]];

(* -- LeanSort -- *)
LeanSort /: MakeBoxes[expr : LeanSort[LeanLevelZero[]], StandardForm] :=
  iBox[expr, StyleBox["Prop", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold]];
LeanSort /: MakeBoxes[expr : LeanSort[LeanLevelSucc[LeanLevelZero[]]], StandardForm] :=
  iBox[expr, StyleBox["Type", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold]];
LeanSort /: MakeBoxes[expr : LeanSort[level_], StandardForm] :=
  iBox[expr,
    RowBox[{StyleBox["Sort", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold],
      " ", MakeBoxes[level, StandardForm]}]];

(* -- LeanLitNat / LeanLitStr -- *)
LeanLitNat /: MakeBoxes[expr : LeanLitNat[n_Integer], StandardForm] :=
  iBox[expr, StyleBox[ToString[n], FontColor -> RGBColor[0.1, 0.5, 0.1]]];
LeanLitStr /: MakeBoxes[expr : LeanLitStr[s_String], StandardForm] :=
  iBox[expr, StyleBox["\"" <> s <> "\"", FontColor -> RGBColor[0.7, 0.3, 0.1]]];

(* -- LeanLet -- *)
LeanLet /: MakeBoxes[expr : LeanLet[name_String, type_, val_, body_], StandardForm] :=
  iBox[expr,
    RowBox[{
      StyleBox["let ", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold],
      StyleBox[cleanName[name], FontSlant -> Italic, Bold],
      " : ", MakeBoxes[type, StandardForm],
      " := ", MakeBoxes[val, StandardForm],
      "; ", MakeBoxes[body, StandardForm]}]];

(* -- LeanNoValue -- *)
LeanNoValue /: MakeBoxes[expr : LeanNoValue[], StandardForm] :=
  iBox[expr, StyleBox["\[Dash]", FontColor -> GrayLevel[0.6]]];

(* -- LeanTruncated -- *)
LeanTruncated /: MakeBoxes[expr : LeanTruncated[info_], StandardForm] :=
  iBox[expr,
    TooltipBox[StyleBox["\[Ellipsis]", FontColor -> GrayLevel[0.5]],
      MakeBoxes[info, StandardForm]]];

(* -- LeanProj -- *)
LeanProj /: MakeBoxes[expr : LeanProj[typeName_, idx_Integer, struct_], StandardForm] :=
  iBox[expr,
    RowBox[{MakeBoxes[struct, StandardForm], ".",
      StyleBox[ToString[idx], FontColor -> GrayLevel[0.5]]}]];

(* -- LeanFVar / LeanMVar -- *)
LeanFVar /: MakeBoxes[expr : LeanFVar[name_], StandardForm] :=
  iBox[expr,
    StyleBox[cleanName[ToString[name]],
      FontColor -> RGBColor[0.4, 0.4, 0.7], FontSlant -> Italic]];
LeanMVar /: MakeBoxes[expr : LeanMVar[name_], StandardForm] :=
  iBox[expr,
    StyleBox["?" <> cleanName[ToString[name]],
      FontColor -> RGBColor[0.7, 0.4, 0.4], FontSlant -> Italic]];

(* ============================================================================ *)
(* Level head formatting                                                        *)
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
      "(", MakeBoxes[a, StandardForm], ", ",
      MakeBoxes[b, StandardForm], ")"}]];

LeanLevelIMax /: MakeBoxes[expr : LeanLevelIMax[a_, b_], StandardForm] :=
  iBox[expr,
    RowBox[{StyleBox["imax", FontColor -> GrayLevel[0.5], FontSize -> 9],
      "(", MakeBoxes[a, StandardForm], ", ",
      MakeBoxes[b, StandardForm], ")"}]];

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
LeanImport[opts : OptionsPattern[]] := Module[{raw},
  raw = callNative[$listTheoremsFn,
    {OptionValue["Filter"]},
    resolveProjDir[OptionValue["ProjectDir"]],
    OptionValue["Imports"]];
  If[!AssociationQ[raw], Return[$Failed]];
  toLeanObject /@ raw];

LeanImport[module_String, opts : OptionsPattern[]] :=
  LeanImport["Imports" -> {module}, opts];

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

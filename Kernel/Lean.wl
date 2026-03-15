(* ::Package:: *)
(* Lean.wl -- Native Lean integration via LibraryLink *)

BeginPackage["LeanLink`"];

(* Lean expression heads *)
LeanApp::usage = "LeanApp[fn, arg] represents a Lean function application.";
LeanLam::usage = "LeanLam[name, type, body, binder] represents a Lean lambda abstraction.";
LeanForall::usage = "LeanForall[name, type, body, binder] represents a Lean dependent function type (\[ForAll]).";
LeanLet::usage = "LeanLet[name, type, val, body] represents a Lean let binding.";
LeanConst::usage = "LeanConst[name, levels] represents a reference to a Lean constant.";
LeanBVar::usage = "LeanBVar[index] represents a Lean bound variable (de Bruijn index).";
LeanFVar::usage = "LeanFVar[name] represents a Lean free variable.";
LeanMVar::usage = "LeanMVar[name] represents a Lean metavariable.";
LeanSort::usage = "LeanSort[level] represents a Lean Sort (Prop, Type, etc.).";
LeanLitNat::usage = "LeanLitNat[n] represents a Lean natural number literal.";
LeanLitStr::usage = "LeanLitStr[s] represents a Lean string literal.";
LeanProj::usage = "LeanProj[type, index, struct] represents a Lean structure projection.";
LeanTruncated::usage = "LeanTruncated[info] represents a truncated expression (depth limit reached).";
LeanNoValue::usage = "LeanNoValue[] indicates a constant with no value (e.g. axiom).";

(* Level heads *)
LeanLevelZero::usage = "LeanLevelZero[] represents universe level 0.";
LeanLevelSucc::usage = "LeanLevelSucc[level] represents successor of a universe level.";
LeanLevelMax::usage = "LeanLevelMax[l1, l2] represents the max of two universe levels.";
LeanLevelIMax::usage = "LeanLevelIMax[l1, l2] represents the impredicative max of two levels.";
LeanLevelParam::usage = "LeanLevelParam[name] represents a named universe parameter.";
LeanLevelMVar::usage = "LeanLevelMVar[name] represents a universe metavariable.";

(* Raw constant info *)
LeanConstant::usage = "LeanConstant[name, kind, type, value] represents raw constant info from Lean.";

(* Rich typed heads *)
LeanTheorem::usage = "LeanTheorem[\[LeftAssociation]...\[RightAssociation]] represents a Lean theorem with properties \"Name\", \"Kind\", \"Type\", \"Value\".";
LeanDefinition::usage = "LeanDefinition[\[LeftAssociation]...\[RightAssociation]] represents a Lean definition with properties \"Name\", \"Kind\", \"Type\", \"Value\".";
LeanAxiom::usage = "LeanAxiom[\[LeftAssociation]...\[RightAssociation]] represents a Lean axiom with properties \"Name\", \"Kind\", \"Type\".";
LeanInductive::usage = "LeanInductive[\[LeftAssociation]...\[RightAssociation]] represents a Lean inductive type with properties \"Name\", \"Kind\", \"Type\".";
LeanConstructor::usage = "LeanConstructor[\[LeftAssociation]...\[RightAssociation]] represents a Lean constructor with properties \"Name\", \"Kind\", \"Type\".";
LeanRecursor::usage = "LeanRecursor[\[LeftAssociation]...\[RightAssociation]] represents a Lean recursor with properties \"Name\", \"Kind\", \"Type\".";
LeanOpaque::usage = "LeanOpaque[\[LeftAssociation]...\[RightAssociation]] represents a Lean opaque definition.";
LeanQuot::usage = "LeanQuot[\[LeftAssociation]...\[RightAssociation]] represents a Lean quotient type constructor.";

(* Native API *)
LeanImport::usage = "LeanImport[opts] imports a Lean module, returning an Association of name \[Rule] typed object.";
LeanExpr::usage = "LeanExpr[name, opts] returns the type of a Lean constant as a symbolic expression tree.";
LeanValue::usage = "LeanValue[name, opts] returns the value/proof of a Lean constant.";
LeanConstantInfo::usage = "LeanConstantInfo[name, opts] returns full constant info as LeanConstant.";
LeanListConstants::usage = "LeanListConstants[opts] returns an Association of name \[Rule] LeanConstant.";
LeanLoadEnvironment::usage = "LeanLoadEnvironment[imports, searchPath] loads a Lean environment handle.";
LeanFreeEnvironment::usage = "LeanFreeEnvironment[handle] frees a loaded Lean environment.";

Begin["`Private`"];

(* ============================================================================ *)
(* Shim library loading                                                         *)
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

(* LibraryFunctionLoad wrappers -- loaded lazily *)
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

(* Decode WXF bytes from MTensor result *)
decodeWXF[tensor_] := BinaryDeserialize[ByteArray[Flatten[tensor]]];

(* ============================================================================ *)
(* Hygiene name cleaning                                                        *)
(* ============================================================================ *)

(* Strip Lean hygiene suffixes: "a._@.Module._hyg.123" -> "a" *)
cleanName[s_String] := StringReplace[s, RegularExpression["\\._@\\..*"] -> ""];
cleanName[other_] := other;

(* ============================================================================ *)
(* Search path & environment management                                         *)
(* ============================================================================ *)

resolveSearchPath[projDir_String] := Module[{buildLib, leanLib, paths},
  buildLib = FileNameJoin[{projDir, ".lake", "build", "lib"}];
  leanLib = Module[{dir = projDir, tc, version, toolchainDir},
    While[StringLength[dir] > 1,
      tc = FileNameJoin[{dir, "lean-toolchain"}];
      If[FileExistsQ[tc],
        version = StringTrim[Import[tc, "Text"]];
        toolchainDir = StringReplace[version, {"/" -> "--", ":" -> "---"}];
        Return[FileNameJoin[{$HomeDirectory, ".elan", "toolchains", toolchainDir, "lib", "lean"}], Module]];
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
  $envCache[key] = handle;
  handle];

(* ============================================================================ *)
(* Centralized native call helper                                               *)
(* ============================================================================ *)

callNative[fn_, args_List, projDir_, imports_] := Module[{handle, result},
  If[$ShimLib === $Failed, Message[LeanLink::nolib]; Return[$Failed]];
  handle = getOrLoadEnv[projDir, imports];
  If[handle === $Failed, Return[$Failed]];
  result = fn @@ Prepend[args, handle];
  decodeWXF[result]];

resolveProjDir[pd_] := Replace[pd, Automatic -> Directory[]];

(* ============================================================================ *)
(* Lean object types                                                            *)
(* ============================================================================ *)

$kindToHead = <|
  "theorem" -> LeanTheorem,
  "def" -> LeanDefinition,
  "axiom" -> LeanAxiom,
  "inductive" -> LeanInductive,
  "constructor" -> LeanConstructor,
  "recursor" -> LeanRecursor,
  "opaque" -> LeanOpaque,
  "quot" -> LeanQuot
|>;

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

$kindIcon = <|
  "theorem" -> "\[ScriptCapitalT]",
  "def" -> "\[ScriptCapitalD]",
  "axiom" -> "\[ScriptCapitalA]",
  "inductive" -> "\[ScriptCapitalI]",
  "constructor" -> "\[ScriptCapitalC]",
  "recursor" -> "\[ScriptCapitalR]",
  "opaque" -> "\[FilledSmallSquare]",
  "quot" -> "\[FilledSmallSquare]"
|>;

(* Convert LeanConstant -> typed head *)
toLeanObject[LeanConstant[name_String, kind_String, type_, value_]] :=
  Lookup[$kindToHead, kind, LeanDefinition][
    <|"Name" -> name, "Kind" -> kind, "Type" -> type, "Value" -> value|>];
toLeanObject[other_] := other;

(* Property access -- defined per head via TagSetDelayed *)
Do[
  With[{h = head},
    h /: h[data_Association][prop_String] :=
      If[prop === "Properties", Keys[data], data[prop]]],
  {head, Values[$kindToHead]}];

(* ============================================================================ *)
(* Pretty-printing: expression to string                                        *)
(* ============================================================================ *)

(* Render a Lean expression as a clean short string for display *)
exprToString[e_, depth_Integer : 3] := If[depth <= 0, "\[Ellipsis]",
  Replace[e, {
    LeanForall[n_, dom_, body_, bi_] :> With[
      {nm = cleanName[n], bd = exprToString[body, depth - 1],
       dm = exprToString[dom, depth - 1]},
      If[bi === "implicit" || bi === "instImplicit",
        "{" <> nm <> " : " <> dm <> "} \[Rule] " <> bd,
        If[nm === "" || StringMatchQ[nm, "_" ~~ ___],
          dm <> " \[Rule] " <> bd,
          "(" <> nm <> " : " <> dm <> ") \[Rule] " <> bd]]],
    LeanApp[fn_, arg_] :> exprToString[fn, depth - 1] <> " " <> exprToString[arg, depth - 1],
    LeanLam[n_, _, body_, _] :> "\[Lambda]" <> cleanName[n] <> ". " <> exprToString[body, depth - 1],
    LeanConst[n_, _] :> Last[StringSplit[n, "."], n],
    LeanBVar[i_] :> "#" <> ToString[i],
    LeanSort[LeanLevelZero[]] :> "Prop",
    LeanSort[LeanLevelSucc[LeanLevelZero[]]] :> "Type",
    LeanSort[_] :> "Sort",
    LeanLitNat[n_] :> ToString[n],
    LeanLitStr[s_] :> "\"" <> s <> "\"",
    LeanNoValue[] :> "\[Dash]",
    LeanTruncated[_] :> "\[Ellipsis]",
    LeanLet[n_, _, v_, body_] :> "let " <> cleanName[n] <> " := " <> exprToString[v, depth - 1] <> "; " <> exprToString[body, depth - 1],
    LeanProj[t_, i_, _] :> Last[StringSplit[t, "."], t] <> "." <> ToString[i],
    _ :> "\[Ellipsis]"
  }]];

(* ============================================================================ *)
(* SummaryBox formatting for typed objects                                       *)
(* ============================================================================ *)

Do[
  With[{h = head},
    h /: MakeBoxes[obj : h[data_Association], StandardForm] := Module[
      {name, kind, typeExpr, valueExpr, col, icon, shortName, typeStr},
      name = Lookup[data, "Name", "?"];
      kind = Lookup[data, "Kind", "?"];
      typeExpr = Lookup[data, "Type", None];
      valueExpr = Lookup[data, "Value", LeanNoValue[]];
      col = Lookup[$kindColor, kind, GrayLevel[0.5]];
      icon = Graphics[{col, Disk[]}, ImageSize -> 12];
      shortName = Last[StringSplit[name, "."], name];
      typeStr = If[typeExpr === None, "\[Dash]", exprToString[typeExpr, 3]];

      BoxForm`ArrangeSummaryBox[h, obj, icon,
        (* always-visible row *)
        {
          BoxForm`SummaryItem[{"Kind: ", Style[kind, Bold, col]}],
          BoxForm`SummaryItem[{"Name: ", Style[shortName, Bold]}]
        },
        (* expandable rows *)
        {
          BoxForm`SummaryItem[{"Full name: ", name}],
          BoxForm`SummaryItem[{"Type: ", Style[typeStr, FontFamily -> "Source Code Pro", FontSize -> 11]}],
          If[valueExpr =!= LeanNoValue[],
            BoxForm`SummaryItem[{"Value: ", Style[exprToString[valueExpr, 2], FontFamily -> "Source Code Pro", FontSize -> 11]}],
            Nothing]
        },
        StandardForm]]],
  {head, Values[$kindToHead]}];

(* ============================================================================ *)
(* Formatting for expression heads                                              *)
(* ============================================================================ *)

(* LeanConst: show just the short name *)
LeanConst /: MakeBoxes[LeanConst[name_String, levels_List], StandardForm] :=
  With[{short = Last[StringSplit[name, "."], name]},
    StyleBox[short, FontColor -> RGBColor[0.15, 0.35, 0.6], FontWeight -> Bold]];

(* LeanForall: ∀(name : domain) → body *)
LeanForall /: MakeBoxes[LeanForall[name_String, dom_, body_, bi_String], StandardForm] :=
  With[{nm = cleanName[name]},
    RowBox[{
      If[bi === "implicit" || bi === "instImplicit",
        RowBox[{"{", StyleBox[nm, FontSlant -> Italic], " : ", MakeBoxes[dom, StandardForm], "}"}],
        If[nm === "" || StringMatchQ[nm, "_" ~~ ___],
          MakeBoxes[dom, StandardForm],
          RowBox[{"(", StyleBox[nm, FontSlant -> Italic], " : ", MakeBoxes[dom, StandardForm], ")"}]]],
      " \[Rule] ",
      MakeBoxes[body, StandardForm]}]];

(* LeanApp: fn(arg) - flatten nested apps *)
LeanApp /: MakeBoxes[LeanApp[fn_, arg_], StandardForm] :=
  RowBox[{MakeBoxes[fn, StandardForm], " ", MakeBoxes[arg, StandardForm]}];

(* LeanLam: λname. body *)
LeanLam /: MakeBoxes[LeanLam[name_String, type_, body_, _String], StandardForm] :=
  RowBox[{"\[Lambda]", StyleBox[cleanName[name], FontSlant -> Italic], ". ", MakeBoxes[body, StandardForm]}];

(* LeanBVar: #index *)
LeanBVar /: MakeBoxes[LeanBVar[idx_Integer], StandardForm] :=
  StyleBox["#" <> ToString[idx], FontColor -> GrayLevel[0.5]];

(* LeanSort *)
LeanSort /: MakeBoxes[LeanSort[LeanLevelZero[]], StandardForm] :=
  StyleBox["Prop", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold];
LeanSort /: MakeBoxes[LeanSort[LeanLevelSucc[LeanLevelZero[]]], StandardForm] :=
  StyleBox["Type", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold];
LeanSort /: MakeBoxes[LeanSort[level_], StandardForm] :=
  RowBox[{StyleBox["Sort", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold], " ", MakeBoxes[level, StandardForm]}];

(* LeanLitNat / LeanLitStr *)
LeanLitNat /: MakeBoxes[LeanLitNat[n_Integer], StandardForm] :=
  StyleBox[ToString[n], FontColor -> RGBColor[0.1, 0.5, 0.1]];
LeanLitStr /: MakeBoxes[LeanLitStr[s_String], StandardForm] :=
  StyleBox["\"" <> s <> "\"", FontColor -> RGBColor[0.7, 0.3, 0.1]];

(* LeanLet *)
LeanLet /: MakeBoxes[LeanLet[name_String, type_, val_, body_], StandardForm] :=
  RowBox[{"let ", StyleBox[cleanName[name], FontSlant -> Italic, Bold],
    " : ", MakeBoxes[type, StandardForm],
    " := ", MakeBoxes[val, StandardForm], "; ",
    MakeBoxes[body, StandardForm]}];

(* LeanNoValue *)
LeanNoValue /: MakeBoxes[LeanNoValue[], StandardForm] :=
  StyleBox["\[Dash]", FontColor -> GrayLevel[0.6]];

(* LeanTruncated *)
LeanTruncated /: MakeBoxes[LeanTruncated[info_], StandardForm] :=
  TooltipBox[StyleBox["\[Ellipsis]", FontColor -> GrayLevel[0.5]], MakeBoxes[info, StandardForm]];

(* LeanProj *)
LeanProj /: MakeBoxes[LeanProj[typeName_, idx_Integer, struct_], StandardForm] :=
  RowBox[{MakeBoxes[struct, StandardForm], ".",
    StyleBox[ToString[idx], FontColor -> GrayLevel[0.5]]}];

(* Level heads -- minimal display *)
LeanLevelZero /: MakeBoxes[LeanLevelZero[], StandardForm] :=
  StyleBox["0", FontColor -> GrayLevel[0.5], FontSize -> 9];
LeanLevelSucc /: MakeBoxes[LeanLevelSucc[l_], StandardForm] :=
  RowBox[{MakeBoxes[l, StandardForm], StyleBox["+1", FontColor -> GrayLevel[0.5], FontSize -> 9]}];

(* FVar / MVar -- rare, simple display *)
LeanFVar /: MakeBoxes[LeanFVar[name_], StandardForm] :=
  StyleBox[cleanName[ToString[name]], FontColor -> RGBColor[0.4, 0.4, 0.7], FontSlant -> Italic];
LeanMVar /: MakeBoxes[LeanMVar[name_], StandardForm] :=
  StyleBox["?" <> cleanName[ToString[name]], FontColor -> RGBColor[0.7, 0.4, 0.4], FontSlant -> Italic];

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

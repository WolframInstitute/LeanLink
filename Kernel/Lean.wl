(* ::Package:: *)
(* Lean.wl -- Native Lean integration via LibraryLink *)

BeginPackage["LeanLink`"];

(* Lean expression heads *)
LeanApp; LeanLam; LeanForall; LeanLet; LeanConst; LeanBVar; LeanFVar;
LeanMVar; LeanSort; LeanLitNat; LeanLitStr; LeanProj; LeanTruncated; LeanNoValue;
LeanLevelZero; LeanLevelSucc; LeanLevelMax; LeanLevelIMax; LeanLevelParam; LeanLevelMVar;
LeanConstant;

(* Rich typed heads *)
LeanTheorem; LeanDefinition; LeanAxiom; LeanInductive; LeanConstructor;
LeanRecursor; LeanOpaque; LeanQuot;

(* Native API *)
LeanImport::usage = "LeanImport[opts] imports a Lean module, returning an Association of name \[Rule] typed object.";
LeanExpr::usage = "LeanExpr[name, opts] returns the type of a Lean constant as a symbolic expression.";
LeanValue::usage = "LeanValue[name, opts] returns the value/proof of a Lean constant.";
LeanConstantInfo::usage = "LeanConstantInfo[name, opts] returns full constant info.";
LeanListConstants::usage = "LeanListConstants[opts] returns an Association of constants.";
LeanLoadEnvironment::usage = "LeanLoadEnvironment[imports, searchPath] loads a Lean environment.";
LeanFreeEnvironment::usage = "LeanFreeEnvironment[handle] frees a loaded environment.";

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

(* callNative[fn, {extra args...}, projDir, imports] -- eliminates boilerplate *)
callNative[fn_, args_List, projDir_, imports_] := Module[{handle, result},
  If[$ShimLib === $Failed, Message[LeanLink::nolib]; Return[$Failed]];
  handle = getOrLoadEnv[projDir, imports];
  If[handle === $Failed, Return[$Failed]];
  result = fn @@ Prepend[args, handle];
  decodeWXF[result]];

resolveProjDir[pd_] := Replace[pd, Automatic -> Directory[]];

(* ============================================================================ *)
(* Lean object types with properties and formatting                             *)
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
  "theorem" -> RGBColor[0.2, 0.4, 0.8],
  "def" -> RGBColor[0.2, 0.65, 0.3],
  "axiom" -> RGBColor[0.8, 0.2, 0.2],
  "inductive" -> RGBColor[0.55, 0.25, 0.7],
  "constructor" -> RGBColor[0.85, 0.5, 0.15],
  "recursor" -> GrayLevel[0.45],
  "opaque" -> GrayLevel[0.45],
  "quot" -> GrayLevel[0.45]
|>;

(* Convert LeanConstant[name, kind, type, value] -> typed head *)
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

(* Summary box formatting *)
Do[
  With[{h = head},
    MakeBoxes[obj : h[data_Association], StandardForm] ^:= Module[
      {name, kind, typeExpr, col, shortType, icon},
      name = Lookup[data, "Name", "?"];
      kind = Lookup[data, "Kind", "?"];
      typeExpr = Lookup[data, "Type", None];
      col = Lookup[$kindColor, kind, GrayLevel[0.5]];
      shortType = If[typeExpr === None || typeExpr === LeanNoValue[], "\[Dash]",
        Replace[typeExpr, {
          LeanForall[n_, _, body_, _] :> "\[ForAll]" <> n <> ". ...",
          LeanApp[LeanConst[n_, _], __] :> n <> "[...]",
          LeanConst[n_, _] :> n,
          LeanSort[_] :> "Sort",
          _ :> "\[Ellipsis]"
        }]];
      icon = Replace[kind, {
        "theorem" -> "\[DoubleStruckCapitalT]",
        "def" -> "\[DoubleStruckCapitalD]",
        "axiom" -> "\[DoubleStruckCapitalA]",
        "inductive" -> "\[DoubleStruckCapitalI]",
        "constructor" -> "\[DoubleStruckCapitalC]",
        "recursor" -> "\[DoubleStruckCapitalR]",
        _ -> "\[FilledSmallSquare]"
      }];
      RowBox[{
        StyleBox[icon, FontColor -> col, FontWeight -> Bold, FontSize -> 14],
        "\[ThinSpace]",
        TagBox[
          RowBox[{
            StyleBox[RowBox[{MakeBoxes[kind]}], FontColor -> col, FontSize -> 10, FontSlant -> Italic],
            "\[ThinSpace]",
            StyleBox[RowBox[{MakeBoxes[name]}], FontWeight -> Bold, FontSize -> 11],
            StyleBox[RowBox[{" : ", MakeBoxes[shortType]}], FontColor -> GrayLevel[0.5], FontSize -> 10]
          }],
          "SummaryItem"]}]]],
  {head, Values[$kindToHead]}];

(* ============================================================================ *)
(* Public API                                                                   *)
(* ============================================================================ *)

LeanLoadEnvironment[imports_List, searchPath_String] :=
  $loadEnvFn[StringRiffle[imports, ","], searchPath];

LeanFreeEnvironment[handle_Integer] := ($freeEnvFn[handle]; Null);

(* --- LeanImport: one-shot module import returning typed objects --- *)

Options[LeanImport] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Filter" -> ""};
LeanImport[opts : OptionsPattern[]] := Module[{raw},
  raw = callNative[$listTheoremsFn,
    {OptionValue["Filter"]},
    resolveProjDir[OptionValue["ProjectDir"]],
    OptionValue["Imports"]];
  If[!AssociationQ[raw], Return[$Failed]];
  toLeanObject /@ raw];

(* Allow: LeanImport["LeanLink", opts] as shorthand for Imports->{"LeanLink"} *)
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

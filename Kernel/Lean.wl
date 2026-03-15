(* ::Package:: *)
(* Lean.wl -- Native Lean integration via LibraryLink *)

BeginPackage["LeanLink`"];

(* Lean expression heads *)
LeanApp; LeanLam; LeanForall; LeanLet; LeanConst; LeanBVar; LeanFVar;
LeanMVar; LeanSort; LeanLitNat; LeanLitStr; LeanProj; LeanTruncated; LeanNoValue;
LeanLevelZero; LeanLevelSucc; LeanLevelMax; LeanLevelIMax; LeanLevelParam; LeanLevelMVar;
LeanConstant;

(* Native API *)
LeanLoadEnvironment::usage = "LeanLoadEnvironment[imports, searchPath] loads a Lean environment.";
LeanFreeEnvironment::usage = "LeanFreeEnvironment[handle] frees a loaded environment.";
LeanExpr::usage = "LeanExpr[name, opts] returns the type of a Lean constant.";
LeanValue::usage = "LeanValue[name, opts] returns the value/proof of a Lean constant.";
LeanConstantInfo::usage = "LeanConstantInfo[name, opts] returns full constant info.";
LeanListConstants::usage = "LeanListConstants[opts] returns Association of constants.";

Begin["`Private`"];

(* Load the C shim library *)
$ShimLib := $ShimLib = Module[{loc},
  loc = FileNameJoin[{PacletObject["LeanLink"]["Location"],
    "Native", ".lake", "build", "lib", "libLeanLinkShim.dylib"}];
  If[FileExistsQ[loc], loc,
    loc = FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]],
      "Native", ".lake", "build", "lib", "libLeanLinkShim.dylib"}];
    If[FileExistsQ[loc], loc, $Failed]]];

LeanExpr::nolib = "Shim library not found. Build it first.";
LeanExpr::err = "Lean error: `1`";

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

$getConstantFn := $getConstFn = LibraryFunctionLoad[$ShimLib,
  "leanlink_wl_get_constant", {Integer, "UTF8String"}, {Integer, 1}];

(* Decode WXF bytes from MTensor result *)
decodeWXF[tensor_] := BinaryDeserialize[ByteArray[Flatten[tensor]]];

(* Resolve search path from project dir *)
resolveSearchPath[projDir_String] := Module[{p},
  p = FileNameJoin[{projDir, ".lake", "build", "lib"}];
  If[DirectoryQ[p], p,
    p = FileNameJoin[{projDir, ".lake", "build", "lib", "lean"}];
    If[DirectoryQ[p], p, projDir]]];

(* Environment cache: projDir+imports -> handle *)
$envCache = <||>;

getOrLoadEnv[projDir_String, imports_List] := Module[{key, searchPath, handle},
  key = {projDir, imports};
  If[KeyExistsQ[$envCache, key], Return[$envCache[key]]];
  searchPath = resolveSearchPath[projDir];
  handle = $loadEnvFn[StringRiffle[imports, ","], searchPath];
  If[handle === 0 || !IntegerQ[handle],
    Message[LeanExpr::err, "Failed to load environment"]; Return[$Failed]];
  $envCache[key] = handle;
  handle];

(* Public API *)

LeanLoadEnvironment[imports_List, searchPath_String] :=
  $loadEnvFn[StringRiffle[imports, ","], searchPath];

LeanFreeEnvironment[handle_Integer] := ($freeEnvFn[handle]; Null);

Options[LeanExpr] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Depth" -> 100};
LeanExpr[name_String, opts : OptionsPattern[]] := Module[
  {projDir, handle, result},
  If[$ShimLib === $Failed, Message[LeanExpr::nolib]; Return[$Failed]];
  projDir = Replace[OptionValue["ProjectDir"], Automatic -> Directory[]];
  handle = getOrLoadEnv[projDir, OptionValue["Imports"]];
  If[handle === $Failed, Return[$Failed]];
  result = $getTypeFn[handle, name, OptionValue["Depth"]];
  decodeWXF[result]];

Options[LeanValue] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Depth" -> 100};
LeanValue[name_String, opts : OptionsPattern[]] := Module[
  {projDir, handle, result},
  If[$ShimLib === $Failed, Message[LeanExpr::nolib]; Return[$Failed]];
  projDir = Replace[OptionValue["ProjectDir"], Automatic -> Directory[]];
  handle = getOrLoadEnv[projDir, OptionValue["Imports"]];
  If[handle === $Failed, Return[$Failed]];
  result = $getValueFn[handle, name, OptionValue["Depth"]];
  decodeWXF[result]];

Options[LeanConstantInfo] = {"ProjectDir" -> Automatic, "Imports" -> {}};
LeanConstantInfo[name_String, opts : OptionsPattern[]] := Module[
  {projDir, handle, result},
  If[$ShimLib === $Failed, Message[LeanExpr::nolib]; Return[$Failed]];
  projDir = Replace[OptionValue["ProjectDir"], Automatic -> Directory[]];
  handle = getOrLoadEnv[projDir, OptionValue["Imports"]];
  If[handle === $Failed, Return[$Failed]];
  result = $getConstantFn[handle, name];
  decodeWXF[result]];

Options[LeanListConstants] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Filter" -> ""};
LeanListConstants[opts : OptionsPattern[]] := Module[
  {projDir, handle, result},
  If[$ShimLib === $Failed, Message[LeanExpr::nolib]; Return[$Failed]];
  projDir = Replace[OptionValue["ProjectDir"], Automatic -> Directory[]];
  handle = getOrLoadEnv[projDir, OptionValue["Imports"]];
  If[handle === $Failed, Return[$Failed]];
  result = $listTheoremsFn[handle, OptionValue["Filter"]];
  decodeWXF[result]];

End[];
EndPackage[];

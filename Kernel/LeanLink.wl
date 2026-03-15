(* ::Package:: *)
(* LeanLink.wl -- Main entry point: subprocess graph API + native integration *)

BeginPackage["LeanLink`"];

(* Subprocess graph API *)
LeanExprGraph::usage = "LeanExprGraph[root, opts] generates an expression graph for a Lean constant via subprocess. Options: \"Files\", \"Imports\", \"ProjectDir\", \"ConstDepth\", etc.";
LeanCallGraph::usage = "LeanCallGraph[root, opts] generates a call/dependency graph for a Lean constant via subprocess. Options: \"Files\", \"Imports\", \"ProjectDir\", \"Depth\".";
LeanListTheorems::usage = "LeanListTheorems[opts] lists theorems via subprocess. Options: \"Files\", \"Imports\", \"ProjectDir\", \"Filter\".";

Begin["`Private`"];


(* ============================================================================ *)
(* Lean runtime helpers                                                         *)
(* ============================================================================ *)

$ElanBin = FileNameJoin[{$HomeDirectory, ".elan", "bin"}];
$LakeBin = FileNameJoin[{$ElanBin, "lake"}];
$LeanBin = FileNameJoin[{$ElanBin, "lean"}];
$CodeLean = PacletObject["LeanLink"]["AssetLocation", "CodeLean"];

(* RunProcess reads stdout as Latin-1; re-encode to UTF-8 *)
decodeUTF8[s_String] := FromCharacterCode[ToCharacterCode[s, "ISO8859-1"], "UTF-8"];

isLakeProject[dir_String] := AnyTrue[
  {"lakefile.lean", "lakefile.toml", "lean-toolchain"},
  FileExistsQ[FileNameJoin[{dir, #}]] &];

runLean[projDir_String, args_List] := Module[{cmd, res},
  If[!FileExistsQ[$CodeLean],
    Return[<|"ExitCode" -> 1, "StandardOutput" -> "",
      "StandardError" -> "code.lean not found at: " <> ToString[$CodeLean]|>]];
  cmd = If[isLakeProject[projDir],
    {$LakeBin, "env", "lean", "--run", $CodeLean, Sequence @@ args},
    {$LeanBin, "--run", $CodeLean, Sequence @@ args}];
  If[!FileExistsQ[First[cmd]],
    Return[<|"ExitCode" -> 1, "StandardOutput" -> "",
      "StandardError" -> "Binary not found: " <> First[cmd]|>]];
  res = RunProcess[cmd, ProcessDirectory -> projDir];
  If[!AssociationQ[res],
    <|"ExitCode" -> 1, "StandardOutput" -> "",
      "StandardError" -> "RunProcess failed for: " <> StringRiffle[cmd, " "]|>,
    res]];

dotToGraph[dotStr_String, graphOpts___] := Module[{tmpFile, g},
  tmpFile = FileNameJoin[{$TemporaryDirectory, CreateUUID[] <> ".dot"}];
  With[{s = OpenWrite[tmpFile, CharacterEncoding -> "UTF-8"]},
    WriteString[s, dotStr]; Close[s]];
  g = ImportDOT[tmpFile, graphOpts];
  DeleteFile[tmpFile];
  g];

(* Lean may emit warnings to stdout before the actual output; strip them *)
extractDOT[s_String] := Module[{pos},
  pos = StringPosition[s, "digraph"];
  If[pos === {}, s, StringDrop[s, pos[[1, 1]] - 1]]];

extractListing[s_String] := Module[{lines},
  lines = StringSplit[s, "\n"];
  (* Keep only tab-separated kind\tname lines *)
  Select[lines, StringContainsQ[#, "\t"] &]];

resolveFiles[files_List, projDir_String] := If[files =!= {},
  files,
  FileNames["*.lean", projDir]];

leanFileArgs[files_List] := ("+file=" <> # &) /@ files;
leanImportArgs[imports_List] := ("+import=" <> # &) /@ imports;

(* ============================================================================ *)
(* LeanExprGraph                                                                *)
(* ============================================================================ *)

Options[LeanExprGraph] = Join[{
  "ConstDepth" -> 1,
  "Depth" -> 10000,
  "MaxNodes" -> 200000,
  "ShowLevels" -> True,
  "ProjectDir" -> Automatic,
  "Files" -> {},
  "Imports" -> {},
  "RawDOT" -> False
}, Options[Graph]];

LeanExprGraph[file_String, root_String, opts : OptionsPattern[]] :=
  LeanExprGraph[root, "Files" -> {file}, opts];

LeanExprGraph[root_String, opts : OptionsPattern[]] := Module[
  {projDir, files, args, res, dotStr},
  files = OptionValue["Files"];
  projDir = Replace[OptionValue["ProjectDir"],
    Automatic :> If[files =!= {}, DirectoryName[First[files]], Directory[]]];
  args = Join[{"expr",
    "+constdepth=" <> ToString[OptionValue["ConstDepth"]],
    "+depth=" <> ToString[OptionValue["Depth"]],
    "+maxnodes=" <> ToString[OptionValue["MaxNodes"]]},
    If[TrueQ[OptionValue["ShowLevels"]], {"+showlevels"}, {"-showlevels"}],
    leanFileArgs[files], leanImportArgs[OptionValue["Imports"]], {root}];
  res = runLean[projDir, args];
  If[res["ExitCode"] =!= 0 && StringLength[res["StandardOutput"]] == 0,
    Message[LeanExprGraph::err, res["StandardError"]]; Return[$Failed]];
  dotStr = decodeUTF8[extractDOT[res["StandardOutput"]]];
  If[TrueQ[OptionValue["RawDOT"]], dotStr,
    dotToGraph[dotStr, FilterRules[{opts}, Options[Graph]]]]
];
LeanExprGraph::err = "Lean error: `1`";

(* ============================================================================ *)
(* LeanCallGraph                                                                *)
(* ============================================================================ *)

Options[LeanCallGraph] = Join[{
  "Depth" -> 0,
  "ProjectDir" -> Automatic,
  "Files" -> {},
  "Imports" -> {},
  "RawDOT" -> False
}, Options[Graph]];

LeanCallGraph[file_String, root_String, opts : OptionsPattern[]] :=
  LeanCallGraph[root, "Files" -> {file}, opts];

LeanCallGraph[root_String, opts : OptionsPattern[]] := Module[
  {projDir, files, args, res, dotStr},
  files = OptionValue["Files"];
  projDir = Replace[OptionValue["ProjectDir"],
    Automatic :> If[files =!= {}, DirectoryName[First[files]], Directory[]]];
  args = Join[{
    "call",
    "+depth=" <> ToString[OptionValue["Depth"]]},
    leanFileArgs[files], leanImportArgs[OptionValue["Imports"]], {root}];
  res = runLean[projDir, args];
  If[res["ExitCode"] =!= 0 && StringLength[res["StandardOutput"]] == 0,
    Message[LeanCallGraph::err, res["StandardError"]]; Return[$Failed]];
  dotStr = decodeUTF8[extractDOT[res["StandardOutput"]]];
  If[TrueQ[OptionValue["RawDOT"]], dotStr,
    dotToGraph[dotStr, FilterRules[{opts}, Options[Graph]]]]
];
LeanCallGraph::err = "Lean error: `1`";

(* ============================================================================ *)
(* LeanListTheorems                                                             *)
(* ============================================================================ *)

Options[LeanListTheorems] = {
  "ProjectDir" -> Automatic,
  "Files" -> {},
  "Imports" -> {},
  "Filter" -> ""
};

LeanListTheorems[file_String, opts : OptionsPattern[]] :=
  LeanListTheorems["Files" -> {file}, opts];

LeanListTheorems[opts : OptionsPattern[]] := Module[
  {projDir, files, args, res, lines},
  files = OptionValue["Files"];
  projDir = Replace[OptionValue["ProjectDir"],
    Automatic :> If[files =!= {}, DirectoryName[First[files]], Directory[]]];
  args = Join[{"list"},
    If[OptionValue["Filter"] =!= "", {"+filter=" <> OptionValue["Filter"]}, {}],
    leanFileArgs[files], leanImportArgs[OptionValue["Imports"]]];
  res = runLean[projDir, args];
  If[res["ExitCode"] =!= 0 && StringLength[res["StandardOutput"]] == 0,
    Message[LeanListTheorems::err, res["StandardError"]]; Return[$Failed]];
  lines = extractListing[decodeUTF8[res["StandardOutput"]]];
  Dataset[Association @@@ (StringSplit[#, "\t"] & /@ lines /. {k_, n_} :> {"Kind" -> k, "Name" -> n})]
];
LeanListTheorems::err = "Lean error: `1`";

End[];
EndPackage[];

(* Load Utilities (ImportDOT) and native WXF-based Lean integration *)
Get[FileNameJoin[{PacletObject["LeanLink"]["Location"], "Kernel", "Utilities.wl"}]];
Get[FileNameJoin[{PacletObject["LeanLink"]["Location"], "Kernel", "Lean.wl"}]];

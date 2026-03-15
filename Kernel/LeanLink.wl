(* ::Package:: *)

BeginPackage["LeanLink`"];

ImportDOT::usage = "ImportDOT[\"file.dot\"] imports a DOT digraph file as a Graph object with colors, labels, and edge styles.";
LeanExprGraph::usage = "LeanExprGraph[\"file.lean\", \"theorem\"] or LeanExprGraph[\"theorem\", opts] builds an expression tree graph for a Lean theorem.";
LeanCallGraph::usage = "LeanCallGraph[\"file.lean\", \"theorem\"] or LeanCallGraph[\"theorem\", opts] builds a call graph for a Lean theorem.";
LeanListTheorems::usage = "LeanListTheorems[\"file.lean\"] or LeanListTheorems[opts] lists available theorems and definitions.";

Begin["`Private`"];

(* ============================================================================ *)
(* ImportDOT — General DOT digraph importer                                     *)
(* ============================================================================ *)

Options[ImportDOT] = Options[Graph];

ImportDOT[file_String, opts : OptionsPattern[]] := Module[
  {raw, lines, nodeLines, edgeLines,
   parseAttrs, parseNode, parseEdge,
   nodes, edges, hexToRGB,
   vNames, edgeObjs, eStyles, eLabels, allNames, edgeNodes,
   nodeAttrs, getColor, getLabel, getType},

  raw = Import[file, "Text"];
  lines = StringSplit[raw, "\n"];
  hexToRGB[hex_String] := RGBColor @@ (IntegerDigits[FromDigits[StringDrop[hex, 1], 16], 256, 3] / 255.);

  parseAttrs[attrStr_String] := Association[Rule @@@ StringCases[attrStr,
    RegularExpression["(\\w+)\\s*=\\s*(?:\"([^\"]*)\"|([^,\\]\\s]+))"] :>
      {"$1", If["$2" =!= "", "$2", "$3"]}]];

  nodeLines = Select[lines,
    StringMatchQ[#, Whitespace... ~~ "\"" ~~ __ ~~ "\"" ~~ Whitespace... ~~
      "[" ~~ __ ~~ "]" ~~ ___] && !StringContainsQ[#, "->"] &];
  edgeLines = Select[lines, StringContainsQ[#, "->"] &];

  parseNode[line_String] := Module[{name, attrStr},
    name = First[StringCases[line,
      "\"" ~~ n : Shortest[__] ~~ "\"" ~~ Whitespace... ~~ "[" :> n], ""];
    attrStr = First[StringCases[line, "[" ~~ a : Shortest[__] ~~ "]" :> a], ""];
    <|"name" -> name, "attrs" -> parseAttrs[attrStr]|>];

  parseEdge[line_String] := Module[{parts, attrStr},
    parts = First[StringCases[line,
      "\"" ~~ s : Shortest[__] ~~ "\"" ~~ Whitespace... ~~ "->" ~~
        Whitespace... ~~ "\"" ~~ t : Shortest[__] ~~ "\"" :> {s, t}], {"?", "?"}];
    attrStr = First[StringCases[line, "[" ~~ a : Shortest[__] ~~ "]" :> a], ""];
    <|"src" -> parts[[1]], "tgt" -> parts[[2]], "attrs" -> parseAttrs[attrStr]|>];

  nodes = parseNode /@ nodeLines;
  edges = parseEdge /@ edgeLines;

  allNames = #["name"] & /@ nodes;
  edgeNodes = Union[#["src"] & /@ edges, #["tgt"] & /@ edges];
  nodes = Join[nodes,
    <|"name" -> #, "attrs" -> <|"fillcolor" -> "#e0e0e0", "label" -> #|>|> & /@
      Complement[edgeNodes, allNames]];

  nodeAttrs = Association[#["name"] -> #["attrs"] & /@ nodes];

  getColor[n_] := Module[{fc = Lookup[Lookup[nodeAttrs, n, <||>], "fillcolor", ""]},
    If[StringQ[fc] && StringMatchQ[fc, "#" ~~ __], hexToRGB[fc], GrayLevel[0.55]]];

  getLabel[n_] := Module[{lbl = Lookup[Lookup[nodeAttrs, n, <||>], "label", n]},
    If[StringQ[lbl], StringReplace[lbl, "\\n" -> "\n"], n]];

  getType[n_] := Lookup[Lookup[nodeAttrs, n, <||>], "type", None];
  vNames = #["name"] & /@ nodes;
  edgeObjs = DirectedEdge[#["src"], #["tgt"], Lookup[#["attrs"], "tactic", None]] & /@ edges // Union;

  eStyles = Table[Module[{style, color, tag, pw, rgb},
    style = Lookup[e["attrs"], "style", "solid"];
    color = Lookup[e["attrs"], "color", "#333333"];
    tag = Lookup[e["attrs"], "tactic", None];
    pw = Interpreter["Number"][Lookup[e["attrs"], "penwidth", "1"]];
    rgb = hexToRGB[color];
    DirectedEdge[e["src"], e["tgt"], tag] -> Directive[
      LightDarkSwitched[rgb, Lighter[rgb, 0.4]],
      AbsoluteThickness[pw],
      Arrowheads[0.01],
      If[style === "dashed", Dashing[{Small, Small}], Sequence @@ {}]]
  ], {e, edges}];

  eLabels = Table[Module[{lbl, color, tag},
    lbl = Lookup[e["attrs"], "label", ""];
    color = Lookup[e["attrs"], "fontcolor", Lookup[e["attrs"], "color", "#666666"]];
    tag = Lookup[e["attrs"], "tactic", None];
    If[StringQ[lbl] && lbl =!= "",
      DirectedEdge[e["src"], e["tgt"], tag] ->
        Style[lbl, FontSize -> 5, FontFamily -> "Menlo",
          LightDarkSwitched[
            If[StringMatchQ[color, "#" ~~ __], hexToRGB[color], GrayLevel[0.4]],
            GrayLevel[0.7]]],
      Nothing]
  ], {e, edges}];

  Graph[vNames, edgeObjs, opts,
    VertexShapeFunction -> Map[
      With[{bg = getColor[#], lbl = getLabel[#], tp = getType[#]},
        # -> Function[
            Inset[Framed[
              Style[Tooltip[lbl, tp], "Text", FontSize -> 7,
                  LightDarkSwitched[
                    If[ColorDistance[bg, White] > 0.4, White, Black],
                    If[ColorDistance[bg, Black] > 0.4, White, GrayLevel[0.9]]],
                  Bold],
              Background -> LightDarkSwitched[bg],
              RoundingRadius -> 3,
              FrameStyle -> LightDarkSwitched[GrayLevel[0.4], GrayLevel[0.6]],
              FrameMargins -> {{3, 3}, {1, 1}}], #1, #3]
          ]
        ] &, vNames],
    GraphLayout -> {"LayeredDigraphEmbedding", "Orientation" -> Top},
    EdgeStyle -> eStyles,
    EdgeLabels -> eLabels,
    VertexSize -> If[Length[vNames] <= 10, 0.3, 0.05],
    ImageSize -> Max[300, Min[1200, 40 * Length[vNames]]],
    AspectRatio -> 1 / 2,
    PerformanceGoal -> "Quality"]
];

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
(* LeanExprGraph                                                                     *)
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
(* LeanCallGraph                                                                     *)
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
(* LeanListTheorems                                                                  *)
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

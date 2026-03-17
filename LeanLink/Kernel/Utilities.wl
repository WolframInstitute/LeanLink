(* ::Package:: *)
(* Utilities.wl -- General-purpose helpers (ImportDOT, etc.)      *)
(* Kept for reference -- not loaded by default in LeanLink 0.2+   *)

BeginPackage["LeanLink`"];

ImportDOT::usage = "ImportDOT[\"file.dot\"] imports a DOT digraph file as a Graph with colors, labels, and edge styles.";

Begin["`Private`"];

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

End[];
EndPackage[];

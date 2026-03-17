#!/usr/bin/env wolframscript

(* publish_notebooks.wls — Convert .md, evaluate cells, upload to cloud *)

root = DirectoryName[$ScriptCommandLine[[1]]];
nbDir = FileNameJoin[{root, "Notebooks"}];
pacletDir = FileNameJoin[{root, "LeanLink"}];

(* Load paclet so notebook cells can use LeanLink *)
PacletDirectoryLoad[pacletDir];

mdFiles = FileNames["*.md", nbDir];

If[mdFiles === {},
  Print["No .md files found in ", nbDir];
  Exit[1]];

Print["LeanLink Notebook Publisher"];
Print["=========================="];

(* Evaluate all Input cells in a notebook, inserting Output cells after each.
   Uses MakeExpression to properly parse boxes, evaluates sequentially so
   cells can depend on earlier ones (e.g. Get then LeanImport). *)
evaluateNotebook[nbFile_String] := Module[
  {nb, cells, evaluatedCells, nbOut},
  nb = Import[nbFile, "Notebook"];
  cells = First[nb];
  evaluatedCells = Flatten[Map[
    Function[cell,
      If[MatchQ[cell, Cell[_BoxData, "Input", ___]],
        Module[{held, result, outCell},
          held = Quiet[MakeExpression[cell[[1]], StandardForm]];
          result = Quiet[Check[ReleaseHold[held], $Failed]];
          If[result === Null || result === $Failed,
            {cell},
            outCell = Cell[BoxData[ToBoxes[result, StandardForm]], "Output"];
            {cell, outCell}]],
        {cell}]],
    cells], 1];
  nbOut = Notebook[evaluatedCells];
  Export[nbFile, nbOut]];

results = {};

Do[
  baseName = FileBaseName[mdFile];
  nbFile = FileNameJoin[{nbDir, baseName <> ".nb"}];

  (* Step 1: Convert .md -> .nb *)
  Print["[", baseName, "] Converting .md -> .nb"];
  Export[nbFile,
    ImportString[Import[mdFile, "Text"], {"Markdown", "Notebook"}]];

  (* Step 2: Evaluate all Input cells *)
  Print["[", baseName, "] Evaluating cells..."];
  evaluateNotebook[nbFile];
  Print["[", baseName, "] Done: ", FileSize[nbFile]];

  (* Step 3: Upload to cloud *)
  Print["[", baseName, "] Uploading..."];
  cloudObj = CloudObject["LeanLink/" <> baseName <> ".nb", Permissions -> "Public"];
  CopyFile[nbFile, cloudObj, OverwriteTarget -> True];
  Print["[", baseName, "] Published: ", First[cloudObj]];
  Print[""];

  AppendTo[results, baseName -> ToString[First[cloudObj]]],
  {mdFile, mdFiles}];

Print["=========================="];
Do[Print["  ", r[[1]], ": ", r[[2]]], {r, results}];

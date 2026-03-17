#!/usr/bin/env wolframscript

(* publish_notebooks.wls — Convert .md, evaluate cells, upload to cloud *)

root = DirectoryName[$ScriptCommandLine[[1]]];
nbDir = FileNameJoin[{root, "Notebooks"}];
pacletDir = FileNameJoin[{root, "LeanLink"}];

PacletDirectoryLoad[pacletDir];

mdFiles = FileNames["*.md", nbDir];

If[mdFiles === {},
  Print["No .md files found in ", nbDir];
  Exit[1]];

Print["LeanLink Notebook Publisher"];
Print["=========================="];

(* Kernel-only evaluation: parse Input cells, evaluate, insert Output cells *)
evaluateNotebook[nbFile_String] := Module[
  {nb, cells, evaluatedCells, nbOut},
  nb = Import[nbFile, "Notebook"];
  cells = First[nb];
  evaluatedCells = Flatten[Map[
    Function[cell,
      If[MatchQ[cell, Cell[_, "Input", ___]],
        Module[{boxContent, exprStr, result, outputCell},
          boxContent = First[cell];
          exprStr = ToString[ToExpression[boxContent, StandardForm, HoldForm], InputForm];
          result = Check[ToExpression[exprStr], $Failed];
          If[result === Null || result === $Failed,
            {cell},
            outputCell = Cell[BoxData[ToBoxes[result]], "Output"];
            {cell, outputCell}]],
        {cell}]],
    cells]];
  nbOut = Notebook[evaluatedCells, Sequence @@ Rest[List @@ nb]];
  Export[nbFile, nbOut]];

results = {};

Do[
  baseName = FileBaseName[mdFile];
  nbFile = FileNameJoin[{nbDir, baseName <> ".nb"}];

  (* Step 1: Convert .md -> .nb *)
  Print["[", baseName, "] Converting .md -> .nb"];
  nb = ImportString[Import[mdFile, "Text"], {"Markdown", "Notebook"}];
  Export[nbFile, nb];

  (* Step 2: Evaluate all Input cells *)
  Print["[", baseName, "] Evaluating cells..."];
  evaluateNotebook[nbFile];
  Print["[", baseName, "] Done: ", FileSize[nbFile]];

  (* Step 3: Upload to cloud *)
  Print["[", baseName, "] Uploading to Wolfram Cloud..."];
  cloudObj = CloudObject["LeanLink/" <> baseName <> ".nb", Permissions -> "Public"];
  CopyFile[nbFile, cloudObj, OverwriteTarget -> True];
  url = First[cloudObj];
  Print["[", baseName, "] Published: ", url];
  Print[""];

  AppendTo[results, baseName -> url],
  {mdFile, mdFiles}];

Print["=========================="];
Print["Published notebooks:"];
Do[Print["  ", r[[1]], ": ", r[[2]]], {r, results}];

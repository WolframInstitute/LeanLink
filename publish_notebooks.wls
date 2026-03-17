#!/usr/bin/env wolframscript

(* publish_notebooks.wls — Evaluate notebooks and upload to cloud *)

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

Needs["JLink`"];

results = {};

Do[
  baseName = FileBaseName[mdFile];
  nbFile = FileNameJoin[{nbDir, baseName <> ".nb"}];

  (* Convert .md -> .nb *)
  Print["[", baseName, "] Converting .md -> .nb"];
  Export[nbFile,
    ImportString[Import[mdFile, "Text"], {"Markdown", "Notebook"}]];

  (* Evaluate via headless frontend *)
  Print["[", baseName, "] Evaluating..."];
  UseFrontEnd[
    nb = NotebookOpen[nbFile, Visible -> False];
    FrontEndTokenExecute[nb, "EvaluateNotebook"];
    (* Poll until output count stabilizes *)
    prev = -1;
    Do[Pause[2];
      count = Length[Cases[NotebookGet[nb], Cell[_, "Output", ___], Infinity]];
      If[count > 0 && count == prev, Break[]];
      prev = count,
      {120}];  (* up to 4 min *)
    NotebookSave[nb];
    NotebookClose[nb]];
  Print["[", baseName, "] Done: ", FileSize[nbFile]];

  (* Upload to cloud *)
  Print["[", baseName, "] Uploading..."];
  cloudObj = CloudObject["LeanLink/" <> baseName <> ".nb", Permissions -> "Public"];
  CopyFile[nbFile, cloudObj, OverwriteTarget -> True];
  Print["[", baseName, "] Published: ", First[cloudObj]];
  Print[""];

  AppendTo[results, baseName -> ToString[First[cloudObj]]],
  {mdFile, mdFiles}];

Print["=========================="];
Do[Print["  ", r[[1]], ": ", r[[2]]], {r, results}];

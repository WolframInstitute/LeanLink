#!/usr/bin/env wolframscript

(* publish_notebooks.wls — Evaluate notebooks and upload to cloud.
   Uses JLink`UseFrontEnd to launch a headless MathematicaServer
   so NotebookEvaluate can insert results without a visible desktop. *)

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

  (* Evaluate all cells via headless frontend *)
  Print["[", baseName, "] Evaluating..."];
  UseFrontEnd[
    NotebookEvaluate[nbFile, InsertResults -> True]];
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

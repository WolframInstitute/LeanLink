#!/usr/bin/env wolframscript

(* publish_notebooks.wls — Convert .md notebooks and upload to cloud *)

root = DirectoryName[$ScriptCommandLine[[1]]];
nbDir = FileNameJoin[{root, "Notebooks"}];

mdFiles = FileNames["*.md", nbDir];

If[mdFiles === {},
  Print["No .md files found in ", nbDir];
  Exit[1]];

Print["LeanLink Notebook Publisher"];
Print["=========================="];

results = {};

Do[
  baseName = FileBaseName[mdFile];
  nbFile = FileNameJoin[{nbDir, baseName <> ".nb"}];

  (* Convert .md -> .nb *)
  Print["[", baseName, "] Converting .md -> .nb"];
  Export[nbFile,
    ImportString[Import[mdFile, "Text"], {"Markdown", "Notebook"}]];
  Print["[", baseName, "] Size: ", FileSize[nbFile]];

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

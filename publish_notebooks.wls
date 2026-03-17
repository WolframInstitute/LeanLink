#!/usr/bin/env wolframscript

(* publish_notebooks.wls — Upload .nb notebooks to Wolfram Cloud *)

root = DirectoryName[$ScriptCommandLine[[1]]];
nbDir = FileNameJoin[{root, "Notebooks"}];

nbFiles = FileNames["*.nb", nbDir];

If[nbFiles === {},
  Print["No .nb files found in ", nbDir];
  Exit[1]];

Print["LeanLink Notebook Publisher"];
Print["=========================="];

results = {};

Do[
  baseName = FileBaseName[nbFile];
  Print["[", baseName, "] Uploading..."];
  cloudObj = CloudObject["LeanLink/" <> baseName <> ".nb", Permissions -> "Public"];
  CopyFile[nbFile, cloudObj, OverwriteTarget -> True];
  Print["[", baseName, "] Published: ", First[cloudObj]];
  Print[""];
  AppendTo[results, baseName -> ToString[First[cloudObj]]],
  {nbFile, nbFiles}];

Print["=========================="];
Do[Print["  ", r[[1]], ": ", r[[2]]], {r, results}];

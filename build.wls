#!/usr/bin/env wolframscript

name = "LeanLink"

PacletDirectoryLoad["."]
paclet = PacletObject[name]

pacletFile = CreatePacletArchive["."]

Echo[StringTemplate["Paclet `` has size ``"][pacletFile, FileSize[pacletFile]]]

PacletDirectoryUnload["."]

PacletInstall[pacletFile, ForceVersionInstall -> True]

(* CopyFile[pacletFile, Echo @ CloudObject[name <> ".paclet", Permissions -> "Public"], OverwriteTarget -> True] *)

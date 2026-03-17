#!/usr/bin/env wolframscript

name = "LeanLink"
pacletDir = FileNameJoin[{Directory[], name}]

PacletDirectoryLoad[pacletDir]
paclet = PacletObject[name]

pacletFile = CreatePacletArchive[pacletDir]

Echo[StringTemplate["Paclet `` has size ``"][pacletFile, FileSize[pacletFile]]]

PacletDirectoryUnload[pacletDir]

PacletInstall[pacletFile, ForceVersionInstall -> True]

CopyFile[pacletFile, Echo @ CloudObject[name <> ".paclet", Permissions -> "Public"], OverwriteTarget -> True]

(* ::Package:: *)
(* LeanLink.wl -- Main entry point for the LeanLink paclet *)

(* Load the native API (LibraryLink-based) *)
Get[FileNameJoin[{PacletObject["LeanLink"]["Location"], "Kernel", "Lean.wl"}]];

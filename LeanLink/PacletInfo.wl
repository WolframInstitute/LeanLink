(* ::Package:: *)

PacletObject[
  <|
    "Name" -> "Wolfram/LeanLink",
    "Description" -> "Native link between Wolfram Language and Lean 4",
    "Creator" -> "Nik Murzin",
    "License" -> "MIT",
    "PublisherID" -> "Wolfram",
    "Version" -> "1.0.2",
    "WolframVersion" -> "14.0+",
    "PrimaryContext" -> "Wolfram`LeanLink`",
    "Extensions" -> {
      {
        "Kernel",
        "Root" -> "Kernel",
        "Context" -> {"Wolfram`LeanLink`"}
      },
      {
        "Asset",
        "Root" -> "Assets",
        "Assets" -> {
          {"CodeLean", "code.lean"},
          {"Examples", "Examples.lean"}
        }
      }
    }
  |>
]

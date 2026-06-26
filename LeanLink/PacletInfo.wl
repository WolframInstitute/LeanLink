(* ::Package:: *)

PacletObject[
  <|
    "Name" -> "Wolfram/LeanLink",
    "Description" -> "Native link between Wolfram Language and Lean 4",
    "Creator" -> "Nik Murzin",
    "License" -> "MIT",
    "PublisherID" -> "Wolfram",
    "Version" -> "1.0.5",
    "WolframVersion" -> "14.0+",
    "PrimaryContext" -> "Wolfram`LeanLink`",
    "Categories" -> {"Mathematics", "Logic"},
    "Extensions" -> {
      {
        "Kernel",
        "Root" -> "Kernel",
        "Context" -> {"Wolfram`LeanLink`"},
        "Symbols" -> {
          "Wolfram`LeanLink`ImportDOT",
          "Wolfram`LeanLink`LeanApp",
          "Wolfram`LeanLink`LeanBVar",
          "Wolfram`LeanLink`LeanCallGraph",
          "Wolfram`LeanLink`LeanCompile",
          "Wolfram`LeanLink`LeanCompileTyped",
          "Wolfram`LeanLink`LeanConst",
          "Wolfram`LeanLink`LeanConstant",
          "Wolfram`LeanLink`LeanConstantInfo",
          "Wolfram`LeanLink`LeanEnvironment",
          "Wolfram`LeanLink`LeanExport",
          "Wolfram`LeanLink`LeanExportString",
          "Wolfram`LeanLink`LeanExpr",
          "Wolfram`LeanLink`LeanExprGraph",
          "Wolfram`LeanLink`LeanExprToType",
          "Wolfram`LeanLink`LeanFVar",
          "Wolfram`LeanLink`LeanForall",
          "Wolfram`LeanLink`LeanFreeEnvironment",
          "Wolfram`LeanLink`LeanGoal",
          "Wolfram`LeanLink`LeanImport",
          "Wolfram`LeanLink`LeanImportString",
          "Wolfram`LeanLink`LeanLam",
          "Wolfram`LeanLink`LeanLet",
          "Wolfram`LeanLink`LeanLevelIMax",
          "Wolfram`LeanLink`LeanLevelMVar",
          "Wolfram`LeanLink`LeanLevelMax",
          "Wolfram`LeanLink`LeanLevelParam",
          "Wolfram`LeanLink`LeanLevelSucc",
          "Wolfram`LeanLink`LeanLevelZero",
          "Wolfram`LeanLink`LeanListConstants",
          "Wolfram`LeanLink`LeanListTheorems",
          "Wolfram`LeanLink`LeanLitNat",
          "Wolfram`LeanLink`LeanLitStr",
          "Wolfram`LeanLink`LeanLoadEnvironment",
          "Wolfram`LeanLink`LeanMVar",
          "Wolfram`LeanLink`LeanNoValue",
          "Wolfram`LeanLink`LeanProj",
          "Wolfram`LeanLink`LeanSort",
          "Wolfram`LeanLink`LeanState",
          "Wolfram`LeanLink`LeanTactic",
          "Wolfram`LeanLink`LeanTerm",
          "Wolfram`LeanLink`LeanToFunction",
          "Wolfram`LeanLink`LeanTruncated",
          "Wolfram`LeanLink`LeanValue",
          "Wolfram`LeanLink`ProofToLean"
        }
      },
      {
        "Asset",
        "Root" -> "Assets",
        "Assets" -> {
          {"CodeLean", "code.lean"},
          {"Examples", "Examples.lean"}
        }
      },
      {
        "Documentation",
        "Language" -> "English",
        "MainPage" -> "Guides/LeanLink"
      }
    },
    "Keywords" -> {
      "Lean",
      "Lean 4",
      "theorem prover",
      "proof assistant",
      "dependent types",
      "type theory",
      "formal verification",
      "Mathlib"
    }
  |>
]

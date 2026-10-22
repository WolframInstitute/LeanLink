(* ::Package:: *)

(* TypeTheoryBridge.wl -- the entry points of the bridge between Lean and the WolframInstitute/TypeTheory
   proof engine, a Calculus of Inductive Constructions kernel written in the Wolfram Language.

   LeanLink loads this file with the rest of the package, but the bridge itself, TypeTheoryTranslation.wl,
   is read on the first call of LeanToTypeTheory or TypeTheoryToLean, together with TypeTheory, so that
   loading LeanLink neither needs TypeTheory nor pays for building its prelude. *)

BeginPackage["Wolfram`LeanLink`"];

LeanToTypeTheory::usage = "LeanToTypeTheory[env, name] imports the Lean constant name from the LeanEnvironment env, with every constant it depends on, into a TypeTheoryEnvironment, where TypeTheory's kernel checks each declaration again.\nLeanToTypeTheory[env, {name1, name2, ...}] imports several constants.\nLeanToTypeTheory[term] imports the constant of the LeanTerm term."

TypeTheoryToLean::usage = "TypeTheoryToLean[env, name] gives Lean source declaring the constant name of the TypeTheoryEnvironment env, with every constant it depends on that Lean does not have, for LeanImportString to compile and Lean's kernel to check.\nTypeTheoryToLean[env, {name1, name2, ...}] gives the source for several constants."

Begin["`Private`"];

$typeTheoryTranslationFile = FileNameJoin[{DirectoryName[$InputFileName], "TypeTheoryTranslation.wl"}]

LeanToTypeTheory[arguments___] := withTypeTheoryBridge[LeanToTypeTheory[arguments]]

TypeTheoryToLean[arguments___] := withTypeTheoryBridge[TypeTheoryToLean[arguments]]

(* The translation file replaces the two definitions above, so the call is made again once it is read. *)

SetAttributes[withTypeTheoryBridge, HoldFirst]

withTypeTheoryBridge[call_] := If[ TrueQ[loadTypeTheoryBridge[]],
    call
    ,
    Failure[
        "TypeTheoryMissing"
        ,
        <|
            "MessageTemplate" -> "The bridge needs the paclet WolframInstitute/TypeTheory. Install it with `1`.",
            "MessageParameters" -> {"PacletInstall[ResourceObject[\"https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/TypeTheory\"]]"}
        |>
    ]
]

(* TypeTheory goes on $ContextPath, since the bridge's results are TypeTheory objects *)

loadTypeTheoryBridge[] := If[ PacletFind["WolframInstitute/TypeTheory"] === {},
    False
    ,
    Needs["WolframInstitute`TypeTheory`"];
    Get[$typeTheoryTranslationFile];
    True
]

End[];

EndPackage[];

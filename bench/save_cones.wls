#!/usr/bin/env wolframscript
(* Save cones of Mathlib as TypeTheory environments, for kernels to check. Each case's constant is imported into
   TypeTheory with every constant it depends on, as LeanToTypeTheory imports it and typetheory_benchmark.wls times
   it, and written with Export as a saved environment, which TypeTheoryEnvironment[File[file], "Check" -> True] reads
   back and replays declaration by declaration, on any kernel.

       wl -f bench/save_cones.wls [case ...] [--project-dir dir] [--typetheory dir] [--out dir]

   The cases are those of bench/Cases.wl, binaryRec, omega and balanceL by default, and the files go to bench/cones.
   The project directory, built Mathlib, defaults to ~/src/mathlib4, TypeTheory to the checkout next to this one. *)

$rootDirectory = ParentDirectory[DirectoryName[$InputFileName]]

Get[FileNameJoin[{$rootDirectory, "bench", "Cases.wl"}]]

arguments = Rest[$ScriptCommandLine]

optionNames = {"--project-dir", "--typetheory", "--out"}

optionValues = Association[Cases[Partition[arguments, 2, 1], {name_String, value_String} /; MemberQ[optionNames, name] :> (name -> value)]]

caseNames = Replace[
    Delete[arguments, Flatten[Function[position, {{position}, {position + 1}}] /@ Flatten[Position[arguments, Alternatives @@ optionNames, {1}]], 1]],
    {} -> {"binaryRec", "omega", "balanceL"}
]

projectDirectory = Lookup[optionValues, "--project-dir", FileNameJoin[{$HomeDirectory, "src", "mathlib4"}]]

typeTheoryDirectory = Lookup[optionValues, "--typetheory", FileNameJoin[{ParentDirectory[$rootDirectory], "TypeTheory", "TypeTheory"}]]

outputDirectory = Lookup[optionValues, "--out", FileNameJoin[{$rootDirectory, "bench", "cones"}]]

If[DirectoryQ[typeTheoryDirectory], PacletDirectoryLoad[typeTheoryDirectory]]

PacletDirectoryLoad[FileNameJoin[{$rootDirectory, "LeanLink"}]]

Needs["Wolfram`LeanLink`"]

Scan[
    Function[name, Block[{module, constant, environment, file},
        {module, constant} = $cases[name];
        environment = LeanToTypeTheory[LeanImport["ProjectDir" -> projectDirectory, "Imports" -> {module}], constant];
        file = FileNameJoin[{outputDirectory, name <> ".wxf"}];
        If[ FailureQ[environment],
            Print[name, ": ", environment["Message"]],
            Export[file, environment];
            Print[name, ": ", Length[environment], " constants, ", FileByteCount[file], " bytes, ", file]
        ]
    ]],
    caseNames
]

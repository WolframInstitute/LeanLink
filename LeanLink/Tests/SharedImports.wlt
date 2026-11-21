BeginTestSection["SharedImports"]

(* An import starts from the modules already read into the kernel (importShared in EnvStore.lean), since Lean copies
   an .olean it has already mapped into memory that is never freed. These tests compare what such an import gives
   with Lean's own import of the same modules, read afresh: the numbers of constants and modules, a hash of every
   constant's name and type, and the sizes of the instance, simp and syntax extensions. *)

$fingerprint = LibraryFunctionLoad[Wolfram`LeanLink`Private`$ShimLib, "leanlink_wl_fingerprint", {Integer}, {Integer, 1}]

$freshFingerprint = LibraryFunctionLoad[Wolfram`LeanLink`Private`$ShimLib, "leanlink_wl_fresh_fingerprint", {"UTF8String", "UTF8String"}, {Integer, 1}]

sharedAndFresh[environment_] := With[{handle = Information[environment, "Handle"]},
    {
        Wolfram`LeanLink`Private`decodeWXF[$fingerprint[handle]],
        Wolfram`LeanLink`Private`decodeWXF[
            $freshFingerprint[StringRiffle[Wolfram`LeanLink`Private`handleInfo[handle, "Imports"], ","], Wolfram`LeanLink`Private`handleInfo[handle, "SearchPath"]]
        ]
    }
]

sameAsFreshQ[environment_] := With[{both = sharedAndFresh[environment]}, AssociationQ[First[both]] && First[both]["Constants"] > 1000 && SameQ @@ both]

VerificationTest[
    $sharedInit = LeanImport["Init", "ProjectDir" -> $LeanLinkTestProjectDir];
    sameAsFreshQ[$sharedInit],
    True, TestID -> "SharedImports-Init-equals-a-fresh-import"
]

(* a strict subset of what the kernel has read gets no module more than its own *)
VerificationTest[
    $sharedPrelude = LeanImport["Init.Prelude", "ProjectDir" -> $LeanLinkTestProjectDir];
    {sameAsFreshQ[$sharedPrelude], First[sharedAndFresh[$sharedPrelude]]["Modules"]},
    {True, 1}, TestID -> "SharedImports-a-subset-has-only-its-own-modules"
]

(* a source string's module is read on top of Init's, already read *)
VerificationTest[
    $sharedSource = LeanImportString["def sharedDouble (n : Nat) : Nat := n * 2\ntheorem sharedDoubleTwo : sharedDouble 2 = 4 := rfl"];
    {sameAsFreshQ[$sharedSource], $sharedSource["sharedDoubleTwo"]["TypeForm"], First[$sharedSource["sharedDoubleTwo"]["KernelCheck"]], LeanEvaluate[$sharedSource["sharedDouble"], 21]},
    {True, "sharedDouble 2 = 4", "KernelChecked", 42}, TestID -> "SharedImports-a-source-string-equals-a-fresh-import"
]

(* a second source string does not see the first one's declarations *)
VerificationTest[
    $sharedSecond = LeanImportString["def sharedTriple (n : Nat) : Nat := n * 3"];
    {KeyExistsQ[$sharedSecond, "sharedTriple"], KeyExistsQ[$sharedSecond, "sharedDouble"], LeanEvaluate[$sharedSecond, "sharedDouble 1"]["Tag"]},
    {True, False, "LeanEvaluateFailed"}, TestID -> "SharedImports-source-strings-stay-apart"
]

(* a module built again is read again: the state kept for Top's imports names Base's .olean by its size and the
   time it was written *)
VerificationTest[
    Module[{dir = CreateDirectory[], first, second},
        Export[FileNameJoin[{dir, "lakefile.toml"}], "name = \"shared\"\ndefaultTargets = [\"Top\"]\n[[lean_lib]]\nname = \"Base\"\n[[lean_lib]]\nname = \"Top\"\n", "Text"];
        Export[FileNameJoin[{dir, "lean-toolchain"}], "leanprover/lean4:v4.36.0", "Text"];
        Export[FileNameJoin[{dir, "Base.lean"}], "def Base.value : Nat := 1\n", "Text"];
        Export[FileNameJoin[{dir, "Top.lean"}], "import Base\ndef Top.value : Nat := Base.value + 1\n", "Text"];
        LeanBuild[dir];
        first = LeanImport["Top", "ProjectDir" -> dir];
        WithCleanup[
            {
                LeanEvaluate[first, "Top.value"],
                LeanFreeEnvironment[first];
                Export[FileNameJoin[{dir, "Base.lean"}], "def Base.value : Nat := 7\n", "Text"];
                LeanBuild[dir];
                second = LeanImport["Top", "ProjectDir" -> dir];
                LeanEvaluate[second, "Top.value"]
            },
            Quiet[LeanFreeEnvironment[second]]
        ]
    ]
    ,
    {2, 8}
    ,
    TestID -> "SharedImports-a-module-built-again-is-read-again"
]

Scan[LeanFreeEnvironment, {$sharedInit, $sharedPrelude, $sharedSource, $sharedSecond}]

EndTestSection[]

(* ::Package:: *)

(* Lean.wl -- Native Lean integration via LibraryLink *)

BeginPackage["Wolfram`LeanLink`"];

(* ============================================================================ *)

(* Expression heads                                                             *)

(* ============================================================================ *)

LeanApp::usage = "LeanApp[fn, arg] represents Lean function application (fn arg)."

LeanLam::usage = "LeanLam[name, type, body, binder] represents a Lean \[Lambda]-abstraction. binder is \"default\" (explicit), \"implicit\" ({x}), \"instImplicit\" ([x]), or \"strictImplicit\" (\[LeftDoubleBracket]x\[RightDoubleBracket])."

LeanForall::usage = "LeanForall[name, domain, body, binder] represents a Lean \[ForAll]/\[Rule] type. A non-dependent forall (arrow type) has name \"_\"."

LeanLet::usage = "LeanLet[name, type, value, body] represents a let-binding (let name : type := value; body)."

LeanConst::usage = "LeanConst[name, universes] represents a reference to a declared constant at given universe levels."

LeanBVar::usage = "LeanBVar[index] represents a bound variable by de Bruijn index (0 = innermost binder)."

LeanFVar::usage = "LeanFVar[id] represents a free variable (local hypothesis or function parameter)."

LeanMVar::usage = "LeanMVar[id] represents a metavariable (unresolved placeholder in elaboration)."

LeanSort::usage = "LeanSort[level] represents a universe. LeanSort[LeanLevelZero[]] is Prop, LeanSort[LeanLevelSucc[LeanLevelZero[]]] is Type."

LeanLitNat::usage = "LeanLitNat[n] represents a Lean natural number literal."

LeanLitStr::usage = "LeanLitStr[s] represents a Lean string literal."

LeanProj::usage = "LeanProj[typeName, fieldIndex, struct] represents a structure field projection."

LeanTruncated::usage = "LeanTruncated[info] indicates the expression was truncated at the depth limit. Increase \"Depth\" to see deeper."

LeanNoValue::usage = "LeanNoValue[] indicates a constant with no definition body (axioms, opaques)."

(* Level heads *)

LeanLevelZero::usage = "LeanLevelZero[] is universe level 0 (the level of Prop)."

LeanLevelSucc::usage = "LeanLevelSucc[level] is the successor of a universe level."

LeanLevelMax::usage = "LeanLevelMax[a, b] is the maximum of two universe levels."

LeanLevelIMax::usage = "LeanLevelIMax[a, b] is the impredicative max (collapses to 0 when b is 0)."

LeanLevelParam::usage = "LeanLevelParam[name] is a named universe parameter (e.g. u, v)."

LeanLevelMVar::usage = "LeanLevelMVar[id] is a universe metavariable."

(* Raw constant *)

LeanConstant::usage = "LeanConstant[name, kind, type, term] is raw constant info from the native shim."

(* Unified typed constant *)

LeanTerm::usage = "LeanTerm[\[LeftAssociation]\"Name\"\[Rule]..., \"Kind\"\[Rule]..., \"Type\"\[Rule]..., \"Term\"\[Rule]...\[RightAssociation]] represents a Lean constant. Access properties via term[\"prop\"]. Properties: \"Name\", \"Kind\", \"Type\", \"Term\", \"ExprGraph\", \"CallGraph\"."

(* Public API *)

LeanEnvironment::usage = "LeanEnvironment[<|name \[Rule] LeanTerm[...], ...|>] holds a collection of Lean constants."

LeanImport::usage = "LeanImport[module, opts] imports constants from a Lean module. Returns LeanEnvironment[...]."

LeanExpr::usage = "LeanExpr[name, opts] returns the type of a Lean constant as a symbolic expression tree."

LeanValue::usage = "LeanValue[name, opts] returns the proof/definition body of a Lean constant."

LeanConstantInfo::usage = "LeanConstantInfo[name, opts] returns full constant info as LeanConstant[name, kind, type, term]."

LeanListConstants::usage = "LeanListConstants[opts] lists all constants as \[LeftAssociation]name \[Rule] LeanConstant[...], ...\[RightAssociation]."

LeanLoadEnvironment::usage = "LeanLoadEnvironment[{\"Module1\", ...}, searchPath] loads a Lean environment handle for repeated queries."

LeanFreeEnvironment::usage = "LeanFreeEnvironment[handle] frees a loaded Lean environment and releases memory."

(* Interactive proof objects *)

LeanState::usage = "LeanState[term] opens a proof goal. LeanState[<|...|>] holds proof state. Properties: \"Goals\", \"Complete\", \"GoalCount\"."

LeanTactic::usage = "LeanTactic[tacStr] represents a tactic. Apply via LeanTactic[tac][state] \[Rule] new LeanState."

LeanGoal::usage = "LeanGoal[<|...|>] represents a single proof goal with target and context."

(* Source conversion *)

LeanExportString::usage = "LeanExportString[env] converts a LeanEnvironment to a Lean 4 source code string."

LeanExport::usage = "LeanExport[file, env] exports a LeanEnvironment to a .lean file."

LeanBuild::usage = "LeanBuild[dir, {\"Module1\", ...}] builds those modules of the Lake project in dir with the lake of the toolchain its lean-toolchain file pins, and returns Success or a Failure carrying lake's output. LeanBuild[dir] builds the project's default targets."

LeanBuild::version = "The project pins `1` but LeanLink's runtime is `2`: LeanImport cannot load what this builds."

LeanEvaluate::usage = "LeanEvaluate[expr] evaluates the Lean expression expr (a string) with #eval and returns its value as a Wolfram Language expression, through JSON: Nat and Int give integers, Bool gives True or False, String gives strings, List and Array give lists. \"ProjectDir\" and \"Imports\" make a built project's modules available, \"Source\" adds declarations (definitions, opens) the expression uses, \"Open\" opens namespaces, \"TimeLimit\" bounds the run in seconds. The value is computed by Lean's interpreter, not checked by its kernel."

LeanImportString::usage = "LeanImportString[src] compiles a Lean 4 source string and returns LeanEnvironment[...]. LeanImportString[{src1, src2, ...}] compiles the sources joined with newlines. With \"ProjectDir\" -> dir the source can import that built Lake project's modules."

ProofToLean::usage = "ProofToLean[proof] transpiles a ProofObject to a LeanEnvironment."

(* Compilation *)

LeanToFunction::usage = "LeanToFunction[term] converts a LeanTerm with compilable types to a Function with Typed arguments suitable for FunctionCompile."

LeanCompile::usage = "LeanCompile[term] compiles a LeanTerm to native code via FunctionCompile. LeanCompile[env] compiles all eligible terms in a LeanEnvironment."

Begin["`Private`"];

(* ============================================================================ *)

(* Shim library                                                                 *)

(* ============================================================================ *)

$ShimLib := $ShimLib = Block[
    {loc, pacletDir, devDir, libName, sysDir}
    ,
    (* Platform-specific library name and directory *)
    libName = Switch[ $SystemID,
        "MacOSX-ARM64" | "MacOSX-x86-64",
            "libLeanLinkShim.dylib"
        ,
        "Windows-x86-64",
            "libLeanLinkShim.dll"
        ,
        _,
            "libLeanLinkShim.so"
    ];
    sysDir = $SystemID;
    (* Standard paclet location: LibraryResources inside paclet *)
    pacletDir = Quiet[PacletObject["Wolfram/LeanLink"]["Location"]];
    If[ StringQ[pacletDir],
        loc = FileNameJoin[{pacletDir, "LibraryResources", sysDir, libName}];
        If[FileExistsQ[loc], Return[runnableShim[loc], Block]]
    ];
(* Dev fallback: Native/ is sibling of the LeanLink/ paclet dir
    *)
    devDir = DirectoryName[DirectoryName[$InputFileName]];
    loc = FileNameJoin[{DirectoryName[devDir], "Native", ".lake", "build", "lib", libName}];
    If[FileExistsQ[loc] && provisionLeanRuntime[loc], loc, $Failed]
]

(* --- Lean runtime provisioning --------------------------------------------- *)

(* The shim references libleanshared via @loader_path (macOS), its soname
   (Linux), or by name (Windows), so the ~190 MB Lean runtime is NOT bundled in
   the paclet. At load we link (or copy, on Windows) the runtime libraries from
   the user's installed Lean toolchain next to the shim: a copy of the shim in the
   user's cache, not the paclet's own folder. This keeps the paclet small but
   requires the toolchain the shim was built against to be installed via elan. *)

$LeanToolchainVersion = "v4.35.0";(* must match Native/lean-toolchain *)

(* elan's root: ELAN_HOME when set, else ~/.elan. Containers commonly relocate
   it (ELAN_HOME=/opt/elan with no ~/.elan at all), so every path built from the
   elan tree must go through this rather than assuming $HomeDirectory. *)

elanHome[] := Replace[Environment["ELAN_HOME"], Except[_String] :> FileNameJoin[{$HomeDirectory, ".elan"}]]

(* A toolchain's programs, such as bin/lean and bin/lake, are lean.exe and lake.exe on Windows *)

leanProgram[dir_String, name_String] := FileNameJoin[{dir, name <> If[$OperatingSystem === "Windows", ".exe", ""]}]

(* Lean separates the directories of a search path (LEAN_PATH) with ";" on
   Windows, whose paths have ":" after the drive letter, and with ":" elsewhere. *)

$searchPathSeparator = If[$OperatingSystem === "Windows", ";", ":"]

leanToolchainDir[] := With[
    {
        dir = FileNameJoin[
            {
                elanHome[],
                "toolchains",
                "leanprover--lean4---" <> $LeanToolchainVersion
            }
        ]
    },
    If[DirectoryQ[dir], dir, $Failed]
]

(* {runtime library filenames, toolchain subdirectory that holds them} *)

leanRuntimeLibs[] := Switch[ $SystemID,
    "Windows-x86-64",
        {{"libleanshared.dll", "libleanshared_1.dll", "libleanshared_2.dll", "libInit_shared.dll", "libLake_shared.dll"}, {"bin"}}
    ,
    "MacOSX-ARM64" | "MacOSX-x86-64",
        {{"libleanshared.dylib", "libleanshared_1.dylib", "libleanshared_2.dylib", "libInit_shared.dylib", "libLake_shared.dylib"}, {"lib", "lean"}}
    ,
    _,
        {{"libleanshared.so", "libleanshared_1.so", "libleanshared_2.so", "libInit_shared.so", "libLake_shared.so"}, {"lib", "lean"}}
]

(* Why the shim could not be loaded, for the ::nolib message *)

$shimFailure = "install the Lean toolchain it was built against (leanprover/lean4:" <> $LeanToolchainVersion <> ") with elan, or run 'lake build' in the Native/ directory for a development build."

(* The shim runs where the Lean runtime is next to it: in place when the runtime
   is there already, as in a development build, else from a copy in the user's
   cache, a folder for each build of the shim, next to links to the runtime of the
   installed toolchain. The paclet's own folder may be read-only, shared by other
   users, or in a container image, so nothing is written into it. *)

runnableShim[shim_String] := Block[{dir, copy},
    If[ FileExistsQ[FileNameJoin[{DirectoryName[shim], First[First[leanRuntimeLibs[]]]}]],
        Return[If[provisionLeanRuntime[shim], shim, $Failed], Block]
    ];
    dir = FileNameJoin[{cacheBase[], "LeanLink", $LeanToolchainVersion, $SystemID, StringTake[IntegerString[FileHash[shim, "SHA256"], 16, 64], 16]}];
    copy = FileNameJoin[{dir, FileNameTake[shim]}];
    If[ ! FileExistsQ[copy],
        If[! DirectoryQ[dir], Quiet[CreateDirectory[dir, CreateIntermediateDirectories -> True]]];
        (* copied under a name of its own, then renamed: a kernel loading at the same time never reads half a file *)
        With[{part = copy <> "." <> CreateUUID[]},
            Quiet[CopyFile[shim, part]];
            Quiet[RenameFile[part, copy, OverwriteTarget -> True]]
        ]
    ];
    If[ ! FileExistsQ[copy],
        $shimFailure = "the shim could not be copied into " <> dir <> ".";
        Return[$Failed, Block]
    ];
    If[provisionLeanRuntime[copy], copy, $Failed]
]

(* The user's cache, for files LeanLink makes and can make again *)

cacheBase[] := If[StringQ[$CacheBaseDirectory], $CacheBaseDirectory, $UserBaseDirectory]

provisionLeanRuntime[shimPath_String] := Module[
    {libDir = DirectoryName[shimPath], libs, sub, tc, srcDir, primary}
    ,
    {libs, sub} = leanRuntimeLibs[];
    primary = FileNameJoin[{libDir, First[libs]}];
(* On Windows the runtime's own DLLs need more of the toolchain (libc++.dll),
   so its bin directory goes on PATH as well. *)
    If[ $OperatingSystem === "Windows" && leanToolchainDir[] =!= $Failed,
        addRuntimeSearchPath[FileNameJoin[Prepend[sub, leanToolchainDir[]]]]
    ];
(* Already provisioned (or a self-contained build): just expose the directory. *)
    If[ FileExistsQ[primary],
        addRuntimeSearchPath[libDir];
        Return[True]
    ];
    tc = leanToolchainDir[];
    If[tc === $Failed, Return[False]];
    srcDir = FileNameJoin[Prepend[sub, tc]];
    Scan[
        With[{src = FileNameJoin[{srcDir, #}], dst = FileNameJoin[{libDir, #}]},
            If[ FileExistsQ[src] && ! FileExistsQ[dst],
                If[ $OperatingSystem === "Windows",
                    Quiet[CopyFile[src, dst]]
                    ,
                    Quiet[RunProcess[{"ln", "-sf", src, dst}]]
                ]
            ]
        ]&
        ,
        libs
    ];
    addRuntimeSearchPath[libDir];
    If[! FileExistsQ[primary], $shimFailure = "the Lean runtime of " <> tc <> " could not be linked into " <> libDir <> "."];
    FileExistsQ[primary]
]

(* macOS resolves the runtime via @loader_path and Linux via the shim's RPATH
   $ORIGIN, both next to the shim. Windows needs its directory on PATH. Linux's
   loader reads LD_LIBRARY_PATH only when a process starts, so setting it here
   would not reach the shim, only the processes the kernel starts later. *)

addRuntimeSearchPath[libDir_String] := Module[{var, sep, cur},
    {var, sep} = Switch[ $OperatingSystem,
        "Windows",
            {"PATH", ";"}
        ,
        _,
            {None, None}
    ];
    If[var === None, Return[]];
    cur = Environment[var];
    If[ ! StringQ[cur] || ! StringContainsQ[cur, libDir],
        SetEnvironment[var -> libDir <> If[StringQ[cur] && cur =!= "", sep <> cur, ""]]
    ]
]

(* Dev project root: set only when Native/ exists as sibling (dev mode) *)

$DevProjectRoot = With[{candidate = DirectoryName[DirectoryName[DirectoryName[$InputFileName]]]},
    If[DirectoryQ[FileNameJoin[{candidate, "Native"}]], candidate, None]
]

(* Paclet root: the directory containing PacletInfo.wl, cached at load time *)

$PacletRoot = DirectoryName[DirectoryName[$InputFileName]]

(* Define the package error messages on each public entry point, so a failure is
   reported under the symbol the user actually called (LeanImport::err,
   LeanTactic::abort, ...) rather than a private placeholder. The native helpers
   below (callNative, getOrLoadEnv, applyTacticStr) take the calling head. *)

Scan[
    Function[sym,
        sym::nolib = "Lean shim could not be loaded: `1`";
        sym::err = "Lean error: `1`";
        sym::abort = "Native call aborted: `1`"
    ]
    ,
    {LeanImport, LeanExpr, LeanValue, LeanConstantInfo, LeanListConstants, LeanTactic, LeanTerm}
]

$loadEnvFn := $loadEnvFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_load_env", {"UTF8String", "UTF8String"}, Integer]

$freeEnvFn := $freeEnvFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_free_env", {Integer}, "Void"]

$listTheoremsFn := $listTheoremsFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_list_theorems", {Integer, "UTF8String"}, {Integer, 1}]

$getTypeFn := $getTypeFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_get_type", {Integer, "UTF8String", Integer}, {Integer, 1}]

$getValueFn := $getValueFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_get_value", {Integer, "UTF8String", Integer}, {Integer, 1}]

$getConstantFn := $getConstantFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_get_constant", {Integer, "UTF8String"}, {Integer, 1}]

(* a type or a value as the table of its distinct subterms; $Failed with a shim older than 1.2.2 *)
$getTypeSharedFn := $getTypeSharedFn = Quiet[LibraryFunctionLoad[$ShimLib, "leanlink_wl_get_type_shared", {Integer, "UTF8String"}, {Integer, 1}]]

$getValueSharedFn := $getValueSharedFn = Quiet[LibraryFunctionLoad[$ShimLib, "leanlink_wl_get_value_shared", {Integer, "UTF8String"}, {Integer, 1}]]

$getUsedConstantsFn := $getUsedConstantsFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_get_used_constants", {Integer, "UTF8String"}, {Integer, 1}]

$collectAxiomsFn := $collectAxiomsFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_collect_axioms", {Integer, "UTF8String"}, {Integer, 1}]

$kernelCheckFn := $kernelCheckFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_kernel_check", {Integer, "UTF8String"}, {Integer, 1}]

$moduleConstantKindsFn := $moduleConstantKindsFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_module_constant_kinds", {Integer, "UTF8String"}, {Integer, 1}]

$constantModuleFn := $constantModuleFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_constant_module", {Integer, "UTF8String"}, {Integer, 1}]

$declRangeFn := $declRangeFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_decl_range", {Integer, "UTF8String"}, {Integer, 1}]

$listConstantNamesFn := $listConstantNamesFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_list_constant_names", {Integer, "UTF8String"}, {Integer, 1}]

$listConstantKindsFn := $listConstantKindsFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_list_constant_kinds", {Integer, "UTF8String"}, {Integer, 1}]

$getTypeUnfoldedFn := $getTypeUnfoldedFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_get_type_unfolded", {Integer, "UTF8String", Integer}, {Integer, 1}]

$getValueUnfoldedFn := $getValueUnfoldedFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_get_value_unfolded", {Integer, "UTF8String", Integer}, {Integer, 1}]

$ppTypeFn := $ppTypeFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_pp_type", {Integer, "UTF8String", Integer, "UTF8String"}, {Integer, 1}]

$ppValueFn := $ppValueFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_pp_value", {Integer, "UTF8String", Integer, "UTF8String"}, {Integer, 1}]

$typeCheckFn := $typeCheckFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_type_check", {Integer, {Integer, 1}}, {Integer, 1}]

$openGoalFn := $openGoalFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_open_goal", {Integer, "UTF8String"}, {Integer, 1}]

$applyTacticFn := $applyTacticFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_apply_tactic", {Integer, "UTF8String"}, {Integer, 1}]

$openGoalExprFn := $openGoalExprFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_open_goal_expr", {Integer, {Integer, 1}}, {Integer, 1}]

$ppExprFn := $ppExprFn = LibraryFunctionLoad[$ShimLib, "leanlink_wl_pp_expr", {Integer, {Integer, 1}}, {Integer, 1}]

decodeWXF[tensor_] := BinaryDeserialize[ByteArray[Flatten[tensor]]]

(* A term as the table of its distinct subterms, LeanShared[{node, ...}] (the shim's exprToSharedWXF): each
   node after its children, which it names by their positions, and the last node the whole term. It is
   rebuilt with each subterm one expression however often it occurs, so a proof that shares a few thousand
   subterms millions of times over, as omega's do, stays the size of its distinct subterms. *)
sharedExpression[LeanShared[nodes_List]] := Module[{built = ConstantArray[Null, Length[nodes]]},
    Do[
        built[[position]] = Replace[nodes[[position]], {
            LeanSharedApp[function_Integer, argument_Integer] :> LeanApp[built[[function]], built[[argument]]],
            LeanSharedLam[name_, type_Integer, body_Integer, binder_] :> LeanLam[name, built[[type]], built[[body]], binder],
            LeanSharedForall[name_, type_Integer, body_Integer, binder_] :> LeanForall[name, built[[type]], built[[body]], binder],
            LeanSharedLet[name_, type_Integer, value_Integer, body_Integer] :> LeanLet[name, built[[type]], built[[value]], built[[body]]],
            LeanSharedProj[structure_, index_Integer, term_Integer] :> LeanProj[structure, index, built[[term]]]
        }],
        {position, Length[nodes]}
    ];
    Last[built]
]

sharedExpression[other_] := other

sharedFetchQ[] := MatchQ[{$getTypeSharedFn, $getValueSharedFn}, {_LibraryFunction, _LibraryFunction}]

(* ============================================================================ *)

(* Utilities                                                                    *)

(* ============================================================================ *)

cleanName[s_String] := StringReplace[s, RegularExpression["\\._@\\..*"] -> ""]

cleanName[other_] := other

(* Match code.lean shortConstName: strip ._@. and ._hyg. suffixes, keep full name *)

shortName[s_String] := StringReplace[s, {RegularExpression["\\._@\\..*"] -> "", RegularExpression["\\._hyg\\..*"] -> ""}]

(* ============================================================================ *)

(* Environment management                                                       *)

(* ============================================================================ *)

(* A package's build directory: Lake v5 puts oleans under .lake/build/lib/lean/, v4 under
   .lake/build/lib/. *)

lakeBuildLib[dir_String] := With[{v5 = FileNameJoin[{dir, ".lake", "build", "lib", "lean"}]}, If[DirectoryQ[v5], v5, FileNameJoin[{dir, ".lake", "build", "lib"}]]]

(* Lake builds a path dependency (`path = "../x"` in the lakefile) where it lives, not under
   .lake/packages. A package's lake-manifest.json lists each one as "type": "path", with its
   "dir" relative to that package, and each one's own manifest lists its path dependencies. *)

manifestPathDependencies[dir_String] := With[{manifest = Quiet[Import[FileNameJoin[{dir, "lake-manifest.json"}], "RawJSON"]]},
    If[ AssociationQ[manifest],
        Select[Cases[Lookup[manifest, "packages", {}], KeyValuePattern[{"type" -> "path", "dir" -> d_String}] :> ExpandFileName[FileNameJoin[{dir, d}]]], DirectoryQ],
        {}
    ]
]

(* every path dependency of a project, direct or through other path dependencies, each once *)

lakePathDependencies[projDir_String] := Rest @ FixedPoint[DeleteDuplicates[Join[#, Flatten[manifestPathDependencies /@ #]]] &, {ExpandFileName[projDir]}]

(* The search path for a project: its own build, its packages under .lake/packages (git
   dependencies), its path dependencies wherever they live, then its toolchain's library. *)

resolveSearchPath[projDir_String] := Block[{pkgsRoot = FileNameJoin[{projDir, ".lake", "packages"}], leanLib},
    leanLib = Block[{dir = projDir, tc, version, toolchainDir},
        While[
            StringLength[dir] > 1
            ,
            tc = FileNameJoin[{dir, "lean-toolchain"}];
            If[ FileExistsQ[tc],
                version = StringTrim[Import[tc, "Text"]];
                toolchainDir = StringReplace[version, {"/" -> "--", ":" -> "---"}];
                Return[FileNameJoin[{elanHome[], "toolchains", toolchainDir, "lib", "lean"}], Block]
            ];
            dir = DirectoryName[dir]
        ];
        (* no lean-toolchain above it: Lean's own library of the toolchain the shim is built against *)
        Replace[leanToolchainDir[], {tc_String :> FileNameJoin[{tc, "lib", "lean"}], _ -> Nothing}]
    ];
    StringRiffle[Select[Join[{lakeBuildLib[projDir]}, lakeBuildLib /@ If[DirectoryQ[pkgsRoot], FileNames["*", pkgsRoot], {}], lakeBuildLib /@ lakePathDependencies[projDir], {leanLib}], StringQ[#] && DirectoryQ[#] &], $searchPathSeparator]
]

$envCache = <||>

(* Lean's loader names a module it cannot find only on standard error, so the message names the imports
   for which no directory of the search path has an .olean file *)

loadFailureText[imports_List, searchPath_String] := Replace[
    Select[imports, Function[module, NoneTrue[StringSplit[searchPath, $searchPathSeparator], Function[dir, FileExistsQ[FileNameJoin[Prepend[StringSplit[module, "."], dir]] <> ".olean"]]]]],
    {
        {} -> "Failed to load environment",
        missing_ :> "Failed to load environment: no directory of the search path has the module " <> StringRiffle[missing, ", "]
    }
]

(* Lean reads LEAN_PATH while it imports modules, so the shim sets it for the whole
   kernel process when it loads an environment, and KernelCheck, which imports the
   module's imports again, needs it too. The kernel's own value is put back after
   each: processes the kernel starts later would otherwise inherit the search path
   of whichever environment was loaded last. *)

SetAttributes[withLeanPath, HoldRest]
withLeanPath[searchPath_, body_] := With[{saved = Environment["LEAN_PATH"]},
    If[StringQ[searchPath], SetEnvironment["LEAN_PATH" -> searchPath]];
    With[{result = body},
        SetEnvironment["LEAN_PATH" -> If[StringQ[saved], saved, None]];
        result
    ]
]

loadEnvironment[imports_String, searchPath_String] := withLeanPath[searchPath, $loadEnvFn[imports, searchPath]]

getOrLoadEnv[projDir_String, imports_List, head_ : LeanImport] := Block[{key, searchPath, handle},
    key = {projDir, imports};
    If[KeyExistsQ[$envCache, key], Return[$envCache[key]]];
    searchPath = resolveSearchPath[projDir];
    handle = loadEnvironment[StringRiffle[imports, ","], searchPath];
    If[ handle === 0 || ! IntegerQ[handle],
        Message[head::err, loadFailureText[imports, searchPath]];
        Return[$Failed]
    ];
    $envCache[key] = handle;
    registerHandle[handle, imports, searchPath];
    handle
]

callNative[fn_, args_List, projDir_, imports_, head_ : LeanImport] := Block[{handle, result},
    If[ $ShimLib === $Failed,
        Message[head::nolib, $shimFailure];
        Return[$Failed]
    ];
    handle = getOrLoadEnv[projDir, imports, head];
    If[handle === $Failed, Return[$Failed]];
    result = fn @@ Prepend[args, handle];
    decodeWXF[result]
]

resolveProjDir[pd_] := Replace[
    pd
    ,
    {
        Automatic -> Directory[],
        s_String /; StringStartsQ[s, "~/"] :> FileNameJoin[{$HomeDirectory, StringDrop[s, 2]}]
    }
]

(* ============================================================================ *)

(* LeanTerm                                                                     *)

(* ============================================================================ *)

(* Canonical metamathematics palette, from
   Language`EquationalProofDump`MetamathematicsStyleData: theorem (teal), axiom
   (green), hypothesis (olive), substitution (amber), bisubstitution (salmon),
   and equationalized axiom / hypothesis (magenta / purple). *)

$mmTheorem = Hue[0.49, 0.45, 0.87]

$mmAxiom = Hue[0.26, 0.45, 0.87]

$mmHypothesis = Hue[0.19, 0.87, 0.7]

$mmSubstitution = RGBColor[1., 0.722, 0.22]

$mmBisubstitution = RGBColor[0.922, 0.494, 0.431]

$mmEqAxiom = RGBColor[1., 0.4, 1.]

$mmEqHypothesis = RGBColor[0.698, 0.4, 1.]

(* Foreground (summary icon + kind label): the role colour darkened for legible
   text on white. Background (graph nodes): the role colour lightened so the
   auto-contrast dark text stays readable. *)

mmFg[c_] := Darker[c, 0.35]

mmBg[c_] := Lighter[c, 0.6]

(* Colors for LeanTerm summary icon *)

$kindColor = <|
    "theorem" -> mmFg[$mmTheorem],
    "def" -> mmFg[$mmSubstitution],
    "axiom" -> mmFg[$mmAxiom],
    "inductive" -> mmFg[$mmEqHypothesis],
    "constructor" -> mmFg[$mmBisubstitution],
    "recursor" -> GrayLevel[0.45],
    "opaque" -> GrayLevel[0.45],
    "quot" -> GrayLevel[0.45]
|>

(* Call graph node backgrounds, by constant kind *)

$callNodeColor = <|
    "theorem" -> mmBg[$mmTheorem],
    "def" -> mmBg[$mmSubstitution],
    "structure" -> mmBg[$mmHypothesis],
    "inductive" -> mmBg[$mmEqHypothesis],
    "constructor" -> mmBg[$mmBisubstitution],
    "axiom" -> mmBg[$mmAxiom],
    "recursor" -> GrayLevel[0.92],
    "opaque" -> GrayLevel[0.92],
    "quot" -> GrayLevel[0.92]
|>

$callEdgeColor = <|
    "term" -> GrayLevel[0.25],
    "type" -> GrayLevel[0.6],
    "term+type" -> mmFg[$mmTheorem],
    "ref" -> GrayLevel[0.45]
|>

(* --- Lazy fetch cache: keyed by {handle, name, field} --- *)

$termCache = <||>

isFFIError[r_] := StringQ[r] && StringStartsQ[r, "ERROR"]

(* "Open" -> {"A.B", ...} (or one string): namespaces Lean's printer treats as
   open, sent to the shim comma-separated. *)

openNamespaces[opts_List] := StringRiffle[Select[Flatten[{Lookup[opts, "Open", {}]}], StringQ], ","]

(* ---- term["Source"] ----
   A module's source file is found from the olean directories its handle was
   loaded from. For a Lake build directory, the module's trace records the exact
   compile command and so the source path, whatever the library's srcDir; else
   the default layout, then one level of srcDir (lib/, src/, ...). A toolchain's
   lib/lean maps to its src/lean. *)

$lakeBuildSuffixes = {FileNameJoin[{".lake", "build", "lib", "lean"}], FileNameJoin[{".lake", "build", "lib"}]};

traceSource[traceFile_String] := If[ FileExistsQ[traceFile],
    Flatten @ StringCases[
        Cases[Quiet[ImportString[ReadString[traceFile], "RawJSON"]], KeyValuePattern["message" -> m_String] :> m, Infinity],
        RegularExpression["[/\\\\]bin[/\\\\]lean(?:\\.exe)? (.+?\\.lean) -o "] :> "$1"
    ],
    {}
]

sourceCandidates[dir_String, parts_List, rel_String] := With[
    {suffix = SelectFirst[$lakeBuildSuffixes, StringEndsQ[dir, #]&, None]},
    Which[
        suffix =!= None,
            With[{root = StringDrop[dir, -StringLength[suffix]]},
                Join[
                    traceSource[FileNameJoin[Join[{dir}, Most[parts], {Last[parts] <> ".trace"}]]],
                    {FileNameJoin[{root, rel}]},
                    FileNameJoin[{#, rel}]& /@ Select[FileNames["*", root], DirectoryQ[#] && ! StringStartsQ[FileNameTake[#], "."]&]
                ]
            ],
        StringEndsQ[dir, FileNameJoin[{"lib", "lean"}]],
            {FileNameJoin[{FileNameDrop[dir, -2], "src", "lean", rel}]},
        True,
            {}
    ]
]

(* a module compiled from a file outside the search path, as LeanImport[file] does, names its file *)

moduleSourceFile[h_Integer, module_String] /; FileExistsQ[Lookup[Lookup[Lookup[$handleSource, h, <||>], "Files", <||>], module, None]] :=
    $handleSource[h, "Files", module]

moduleSourceFile[h_Integer, module_String] := With[
    {parts = StringSplit[module, "."]},
    SelectFirst[
        Flatten[sourceCandidates[#, parts, FileNameJoin[parts] <> ".lean"]& /@
            StringSplit[Lookup[Lookup[$handleSource, h, <||>], "SearchPath", ""], $searchPathSeparator]],
        FileExistsQ,
        Missing["NotAvailable"]
    ]
]

(* The declaration's text: its range (1-based lines, 0-based codepoint columns)
   from the olean, sliced out of the module's source file. *)

declarationSource[h_Integer, name_String] := Module[{range, module, file, lines},
    range = Quiet[decodeWXF[$declRangeFn[h, name]]];
    If[ ! AssociationQ[range], Return[Missing["NotAvailable"], Module]];
    module = Quiet[decodeWXF[$constantModuleFn[h, name]]];
    If[ ! StringQ[module] || StringStartsQ[module, "ERROR: "], Return[Missing["NotAvailable"], Module]];
    (* the text of a module compiled from a string, whose file is gone, is kept *)
    file = Lookup[Lookup[Lookup[$handleSource, h, <||>], "Texts", <||>], module, moduleSourceFile[h, module]];
    If[ MissingQ[file], Return[file, Module]];
    lines = StringSplit[If[KeyExistsQ[Lookup[Lookup[$handleSource, h, <||>], "Texts", <||>], module], file, Import[file, "Text", CharacterEncoding -> "UTF-8"]], "\n", All];
    If[ range["EndLine"] > Length[lines], Return[Missing["NotAvailable"], Module]];
    lines = lines[[range["StartLine"] ;; range["EndLine"]]];
(* trim the end before the start: on a one-line range they are the same line *)
    lines[[-1]] = StringTake[lines[[-1]], UpTo[range["EndColumn"]]];
    lines[[1]] = StringDrop[lines[[1]], Min[range["StartColumn"], StringLength[lines[[1]]]]];
    StringRiffle[lines, "\n"]
]

(* ---- LeanEvaluate ----
   #eval in a lean process (the pinned toolchain), value returned through JSON.
   The process is polled rather than run with RunProcess, for a time limit, and
   its output is read while it runs: a large value would otherwise fill the
   pipe and deadlock the wait. *)

runLeanProcess[cmd_List, env_Association, limit_] := Module[
    {p, out = "", err = "", t0 = AbsoluteTime[], read}
    ,
    read[stream_] := Replace[ReadString[stream, EndOfBuffer], Except[_String] -> ""];
    p = StartProcess[cmd, ProcessEnvironment -> env];
    While[ ProcessStatus[p] === "Running",
        out = out <> read[ProcessConnection[p, "StandardOutput"]];
        err = err <> read[ProcessConnection[p, "StandardError"]];
        If[ AbsoluteTime[] - t0 > limit, KillProcess[p]; Return[$TimedOut, Module]];
        Pause[0.02]
    ];
    out = out <> Replace[ReadString[ProcessConnection[p, "StandardOutput"]], Except[_String] -> ""];
    err = err <> Replace[ReadString[ProcessConnection[p, "StandardError"]], Except[_String] -> ""];
    <|"ExitCode" -> ProcessInformation[p, "ExitCode"], "StandardOutput" -> out, "StandardError" -> err|>
]

Options[LeanEvaluate] = {"ProjectDir" -> None, "Imports" -> {}, "Open" -> {}, "Source" -> "", "TimeLimit" -> 600};

LeanEvaluate[expr_String, opts : OptionsPattern[]] := Module[
    {tc, projDir, searchPath, opens, srcLines, srcImports, srcBody, script, file, res, json, diag}
    ,
    tc = leanToolchainDir[];
    If[ tc === $Failed,
        Return[Failure["ToolchainNotInstalled", <|
            "MessageTemplate" -> "LeanLink's toolchain leanprover/lean4:`1` is not installed.",
            "MessageParameters" -> {$LeanToolchainVersion}|>], Module]
    ];
    projDir = OptionValue["ProjectDir"];
    searchPath = StringRiffle[
        DeleteCases[{If[StringQ[projDir], resolveSearchPath[resolveProjDir[projDir]], ""], FileNameJoin[{tc, "lib", "lean"}]}, ""],
        $searchPathSeparator
    ];
    opens = Select[Flatten[{OptionValue["Open"]}], StringQ];
(* "Source": declarations the expression uses (definitions, opens), placed
   after the imports. Any import lines in it move to the header, the only
   place Lean accepts them. *)
    srcLines = StringSplit[Replace[OptionValue["Source"], Except[_String] -> ""], "\n", All];
    srcImports = StringTrim /@ Select[srcLines, StringStartsQ[StringTrim[#], "import "]&];
    srcBody = StringRiffle[Select[srcLines, ! StringStartsQ[StringTrim[#], "import "]&], "\n"];
    script = StringRiffle[
        Join[
            {"import Lean.Data.Json"},
            ("import " <> #&) /@ OptionValue["Imports"],
            srcImports,
            (* Lean writes a Float to JSON through its six-digit text; its bits are exact *)
            {"instance (priority := high) : Lean.ToJson Float where toJson x := Lean.Json.mkObj [(\"LeanLinkFloat\", Lean.toJson x.toBits.toNat)]"},
            If[StringTrim[srcBody] === "", {}, {srcBody}],
            If[opens === {}, {}, {"open " <> StringRiffle[opens, " "] <> " in"}],
            {"#eval IO.println (\"LEANLINK_EVAL_JSON \" ++ (Lean.Json.arr #[Lean.toJson (" <> expr <> ")]).compress)"}
        ],
        "\n"
    ];
    file = FileNameJoin[{$TemporaryDirectory, "LeanLinkEval" <> ToString[$SessionID] <> "x" <> ToString[RandomInteger[10^9]] <> ".lean"}];
    Export[file, script, "Text", CharacterEncoding -> "UTF-8"];
    res = runLeanProcess[
        {leanProgram[FileNameJoin[{tc, "bin"}], "lean"], file},
        Association[GetEnvironment[], "LEAN_PATH" -> searchPath],
        OptionValue["TimeLimit"]
    ];
    Quiet[DeleteFile[file]];
    If[ res === $TimedOut,
        Return[Failure["TimedOut", <|
            "MessageTemplate" -> "Evaluation exceeded the time limit of `1` s.",
            "MessageParameters" -> {OptionValue["TimeLimit"]}|>], Module]
    ];
(* The JSON is found in the raw output: ImportString decodes the UTF-8 itself. *)
    json = SelectFirst[StringSplit[res["StandardOutput"], "\n"], StringStartsQ[#, "LEANLINK_EVAL_JSON "]&, None];
    If[ json =!= None,
        With[{v = Quiet[ImportString[StringDrop[json, StringLength["LEANLINK_EVAL_JSON "]], "RawJSON"]]},
            If[ListQ[v] && Length[v] === 1, Return[withFloats[First[v]], Module]]
        ]
    ];
    diag = StringTrim @ Quiet @ Check[
        FromCharacterCode[ToCharacterCode[res["StandardOutput"] <> "\n" <> res["StandardError"], "ISO8859-1"], "UTF-8"],
        res["StandardOutput"] <> "\n" <> res["StandardError"]
    ];
    Failure["LeanEvaluateFailed", <|
        "MessageTemplate" -> "Lean could not evaluate the expression: `1`",
        "MessageParameters" -> {StringTake[diag, UpTo[500]]},
        "Output" -> diag, "ExitCode" -> res["ExitCode"]
    |>]
]

(* a Float from its IEEE 754 bits: a machine real, Infinity, -Infinity or Indeterminate *)

floatFromBits[bits_Integer] := First[ImportByteArray[ByteArray[IntegerDigits[bits, 256, 8]], "Real64", ByteOrdering -> 1]]

withFloats[float_Association /; Keys[float] === {"LeanLinkFloat"}] := floatFromBits[float["LeanLinkFloat"]]

withFloats[value : (_Association | _List)] := withFloats /@ value

withFloats[value_] := value

(* ---- LeanBuild ----
   Builds with the lake of the toolchain the project pins, called directly: the
   elan proxy would download a missing toolchain, and a build must never do that. *)

projectToolchain[dir_String] := Module[{tcFile = FileNameJoin[{dir, "lean-toolchain"}], pin},
    pin = If[FileExistsQ[tcFile], StringTrim[Import[tcFile, "Text"]], "leanprover/lean4:" <> $LeanToolchainVersion];
    <|"Pin" -> pin, "Dir" -> FileNameJoin[{elanHome[], "toolchains", StringReplace[pin, {"/" -> "--", ":" -> "---"}]}]|>
]

LeanBuild[dir_String, module_String] := LeanBuild[dir, {module}]

LeanBuild[dir_String, modules : {___String} : {}] := Module[
    {root = ExpandFileName[dir], tc, lake, res, out}
    ,
    If[ ! DirectoryQ[root],
        Return[Failure["NoProject", <|"MessageTemplate" -> "No such directory: `1`", "MessageParameters" -> {root}|>], Module]
    ];
    tc = projectToolchain[root];
    lake = leanProgram[FileNameJoin[{tc["Dir"], "bin"}], "lake"];
    If[ ! FileExistsQ[lake],
        Return[
            Failure["ToolchainNotInstalled", <|
                "MessageTemplate" -> "The project pins `1`, which is not installed. Install it with: elan toolchain install `1`",
                "MessageParameters" -> {tc["Pin"]},
                "Toolchain" -> tc["Pin"]
            |>],
            Module
        ]
    ];
    If[ StringReplace[tc["Pin"], StartOfString ~~ ___ ~~ ":" -> ""] =!= $LeanToolchainVersion,
        Message[LeanBuild::version, tc["Pin"], "leanprover/lean4:" <> $LeanToolchainVersion]
    ];
    res = RunProcess[{lake, "build", Sequence @@ ("+" <> #& /@ modules)}, ProcessDirectory -> root];
    out = StringTrim @ Quiet @ Check[
        FromCharacterCode[ToCharacterCode[res["StandardOutput"] <> "\n" <> res["StandardError"], "ISO8859-1"], "UTF-8"],
        res["StandardOutput"] <> "\n" <> res["StandardError"]
    ];
(* A build replaces the project's oleans: drop its cached environments so the
   next LeanImport loads the new ones instead of returning stale constants. *)
    $envCache = KeySelect[$envCache, ! (StringQ[First[#]] && ExpandFileName[First[#]] === root)&];
    If[ res["ExitCode"] === 0,
        Success["Built", <|
            "MessageTemplate" -> "Built `1` in `2`",
            "MessageParameters" -> {If[modules === {}, "the default targets", StringRiffle[modules, ", "]], root},
            "ProjectDir" -> root, "Modules" -> modules, "Output" -> out
        |>]
        ,
        Failure["LeanBuildFailed", <|
            "MessageTemplate" -> "lake build failed with exit code `1`",
            "MessageParameters" -> {res["ExitCode"]},
            "ExitCode" -> res["ExitCode"], "ProjectDir" -> root, "Modules" -> modules, "Output" -> out
        |>]
    ]
]

(* ---- #check-style TypeForm from the lean frontend ----
   The embedded runtime imports an environment without its extensions: building
   them needs initializer execution, which crashes inside a host process. So the
   in-process printer knows no notation. The lean frontend loads extensions
   properly; one lean process pretty-prints a batch of types with ppExpr - the
   delaborator #check uses - and the result is cached per handle and opens. *)

$handleSource = <||>;

$typeFormCache = <||>;

(* A file inside a folder: /a/kit/A.lean is inside /a/kit, /a/kit2/A.lean is not.
   Windows paths compare without case. *)

insideDirectoryQ[file_String, dir_String] := With[
    {parts = FileNameSplit[file], dirParts = FileNameSplit[dir], fold = If[$OperatingSystem === "Windows", ToLowerCase, Identity]},
    Length[parts] > Length[dirParts] && fold[Take[parts, Length[dirParts]]] === fold[dirParts]
]

(* The module an olean under a build directory holds: Mathlib/Logic/Basic.olean is
   Mathlib.Logic.Basic, whichever separator the paths use *)

oleanModule[olean_String, buildLib_String] := StringRiffle[
    FileNameSplit[StringDrop[FileNameDrop[olean, FileNameDepth[buildLib]], -StringLength[".olean"]]],
    "."
]

(* What a handle was loaded from, so a lean process can import the same thing. *)

registerHandle[h_Integer, imports_List, searchPath_String] := If[ h > 0,
    $handleSource[h] = <|"Imports" -> imports, "SearchPath" -> searchPath,
        "Names" -> Lookup[Lookup[$handleSource, h, <||>], "Names", {}]|>
]

handleInfo[h_Integer, key_String] := Lookup[Lookup[$handleSource, h, <||>], key, None]

registerHandleNames[h_Integer, names_List] := If[ KeyExistsQ[$handleSource, h],
    $handleSource[h, "Names"] = Union[$handleSource[h, "Names"], names]
]

leanStringLiteral[s_String] := "\"" <> StringReplace[s, {"\\" -> "\\\\", "\"" -> "\\\""}] <> "\""

frontendTypeForms[h_Integer, names_List, opens_String] := Module[
    {info, tc, script, file, namesFile, res, out, json}
    ,
    info = Lookup[$handleSource, h, None];
    tc = leanToolchainDir[];
    If[ info === None || tc === $Failed || names === {}, Return[$Failed, Module]];
    namesFile = FileNameJoin[{$TemporaryDirectory, "LeanLinkPPNames" <> ToString[$SessionID] <> "x" <> ToString[RandomInteger[10^9]] <> ".txt"}];
    Export[namesFile, StringRiffle[names, "\n"], "Text", CharacterEncoding -> "UTF-8"];
    script = StringRiffle[
        Join[
            {"import Lean"},
            ("import " <> #&) /@ info["Imports"],
(* Open nothing but the requested namespaces, and fully qualify the script's
   own names: `open Lean Meta` would bring Lean.Term and Lean.Meta.State into
   scope, and the delaborator then prints a project's own Term or State in full
   because the short name is ambiguous - unlike #check in a project file. *)
            If[opens === "", {}, {"open " <> StringRiffle[StringSplit[opens, ","], " "] <> " in"}],
            {
                "#eval show Lean.Meta.MetaM Unit from do",
                "  let mut out : Array (String \[Times] Lean.Json) := #[]",
(* names come from a file: an array literal of thousands overflows the code generator *)
                "  for n in (\[LeftArrow] IO.FS.lines " <> leanStringLiteral[namesFile] <> ") do",
                "    if let some ci := (\[LeftArrow] Lean.getEnv).find? n.toName then",
                "      try out := out.push (n, Lean.Json.str (toString (\[LeftArrow] Lean.Meta.ppExpr ci.type))) catch _ => pure ()",
                "  IO.println (\"LEANLINK_PP_JSON \" ++ (Lean.Json.mkObj out.toList).compress)"
            }
        ],
        "\n"
    ];
    file = FileNameJoin[{$TemporaryDirectory, "LeanLinkPP" <> ToString[$SessionID] <> "x" <> ToString[RandomInteger[10^9]] <> ".lean"}];
    Export[file, script, "Text", CharacterEncoding -> "UTF-8"];
    res = RunProcess[
        {leanProgram[FileNameJoin[{tc, "bin"}], "lean"], file},
        ProcessEnvironment -> Association[GetEnvironment[], "LEAN_PATH" -> info["SearchPath"]]
    ];
    Quiet[DeleteFile[{file, namesFile}]];
    out = Quiet @ Check[
        FromCharacterCode[ToCharacterCode[res["StandardOutput"], "ISO8859-1"], "UTF-8"],
        res["StandardOutput"]
    ];
(* Find the JSON in the raw output: ImportString reads its argument as bytes
   and decodes the UTF-8 itself, so it must not be pre-decoded. *)
    json = SelectFirst[StringSplit[res["StandardOutput"], "\n"], StringStartsQ[#, "LEANLINK_PP_JSON "]&, None];
    If[ json === None,
        Message[LeanTerm::err, "lean could not pretty-print the type: " <> StringTake[StringTrim[out <> "\n" <> res["StandardError"]], UpTo[2000]]];
        Return[$Failed, Module]
    ];
    Replace[Quiet[ImportString[StringDrop[json, StringLength["LEANLINK_PP_JSON "]], "RawJSON"]], Except[_Association] -> $Failed]
]

(* The whole environment's names go in one batch (one lean process; about 3 s
   for 4000 names), up to 10000; a name outside it, or in a larger environment,
   is printed alone.
   A failed batch is cached too, so a missing toolchain costs one attempt. *)

typeFormFor[h_Integer, name_String, opens_String] := Module[
    {key = {h, opens}, cache, names, res}
    ,
    cache = Lookup[$typeFormCache, Key[key], Missing[]];
    If[ cache === $Failed, Return[Missing["NotAvailable"], Module]];
    If[ ! AssociationQ[cache] || ! KeyExistsQ[cache, name],
        names = Lookup[Lookup[$handleSource, h, <||>], "Names", {}];
        names = If[MemberQ[names, name] && Length[names] <= 10000 && ! AssociationQ[cache], names, {name}];
        res = frontendTypeForms[h, names, opens];
        $typeFormCache[key] = Which[
            AssociationQ[res], Join[Replace[cache, Except[_Association] -> <||>], res],
            AssociationQ[cache], cache,
            True, $Failed
        ]
    ];
    Lookup[Replace[$typeFormCache[key], Except[_Association] -> <||>], name, Missing["NotAvailable"]]
]

fetchField[handle_Integer, name_String, "Type"] := Lookup[
    $termCache
    ,
    Key[{handle, name, "Type"}]
    ,
    $termCache[{handle, name, "Type"}] = With[{r = Quiet[decodeWXF[$getTypeFn[handle, name, 100]]]},
        If[isFFIError[r], $Failed, r]
    ]
]

fetchField[handle_Integer, name_String, "Term"] := Lookup[
    $termCache
    ,
    Key[{handle, name, "Term"}]
    ,
    $termCache[{handle, name, "Term"}] = With[{r = Quiet[decodeWXF[$getValueFn[handle, name, 100]]]},
        If[isFFIError[r], $Failed, If[StringQ[r] && StringStartsQ[r, "No value"], LeanNoValue[], r]]
    ]
]

fetchField[handle_Integer, name_String, "TypeRefs"] := Lookup[
    $termCache
    ,
    Key[{handle, name, "TypeRefs"}]
    ,
    Block[{uc},
        uc = Quiet[decodeWXF[$getUsedConstantsFn[handle, name]]];
        $termCache[{handle, name, "TypeRefs"}] = If[AssociationQ[uc], Lookup[uc, "type", {}], {}];
        $termCache[{handle, name, "TermRefs"}] = If[AssociationQ[uc], Lookup[uc, "value", {}], {}];
        $termCache[{handle, name, "TypeRefs"}]
    ]
]

fetchField[handle_Integer, name_String, "TermRefs"] := Lookup[
    $termCache
    ,
    Key[{handle, name, "TermRefs"}]
    ,
    (* Fetching TypeRefs also populates TermRefs *)
    fetchField[handle, name, "TypeRefs"];
    Lookup[$termCache, Key[{handle, name, "TermRefs"}], {}]
]

(* Unfold-level fetch -- not cached (level-dependent) *)

fetchUnfolded[handle_Integer, name_String, "Type", level_Integer] := With[{r = Quiet[decodeWXF[$getTypeUnfoldedFn[handle, name, level]]]},
    If[isFFIError[r], $Failed, r]
]

fetchUnfolded[handle_Integer, name_String, "Term", level_Integer] := With[{r = Quiet[decodeWXF[$getValueUnfoldedFn[handle, name, level]]]},
    If[isFFIError[r], $Failed, If[StringQ[r] && StringStartsQ[r, "No value"], LeanNoValue[], r]]
]

(* ============================================================================ *)

(* Constructable LeanTerm -- build from WL expression heads                      *)

(* ============================================================================ *)

(* Wrap a bare expression into a LeanTerm *)

LeanTerm[
    expr :
        _LeanApp
        |
        _LeanConst
        |
        _LeanForall
        |
        _LeanLam
        |
        _LeanBVar
        |
        _LeanSort
        |
        _LeanLitNat
        |
        _LeanLitStr
        |
        _LeanLet
        |
        _LeanProj
] := LeanTerm[<|"Name" -> "user_expr", "Kind" -> "expr", "_Expr" -> expr|>]

(* Constructor with env -- binds handle for type-checking *)

LeanTerm[
    expr :
        _LeanApp
        |
        _LeanConst
        |
        _LeanForall
        |
        _LeanLam
        |
        _LeanBVar
        |
        _LeanSort
        |
        _LeanLitNat
        |
        _LeanLitStr
        |
        _LeanLet
        |
        _LeanProj
    ,
    env_LeanEnvironment
] := With[{h = extractHandle[env]},
    If[ IntegerQ[h],
        LeanTerm[<|"Name" -> "user_expr", "Kind" -> "expr", "_Expr" -> expr, "_Handle" -> h|>]
        ,
        LeanTerm[<|"Name" -> "user_expr", "Kind" -> "expr", "_Expr" -> expr|>]
    ]
]

(* Also accept bare Association for backward compat *)

LeanTerm[
    expr :
        _LeanApp
        |
        _LeanConst
        |
        _LeanForall
        |
        _LeanLam
        |
        _LeanBVar
        |
        _LeanSort
        |
        _LeanLitNat
        |
        _LeanLitStr
        |
        _LeanLet
        |
        _LeanProj
    ,
    env_Association
] := With[{h = Lookup[Values[env][[1]][[1]], "_Handle", None]},
    If[ IntegerQ[h],
        LeanTerm[<|"Name" -> "user_expr", "Kind" -> "expr", "_Expr" -> expr, "_Handle" -> h|>]
        ,
        LeanTerm[<|"Name" -> "user_expr", "Kind" -> "expr", "_Expr" -> expr|>]
    ]
]

(* Extract handle from a LeanEnvironment *)

extractHandle[env_LeanEnvironment] := Lookup[env[[1]], "_Handle", None]

extractHandle[env_Association] := Lookup[env, "_Handle", None]

(* Internal type-check helper *)

typeCheck[expr_, handle_Integer] := Block[{wxfBytes, result},
    wxfBytes = Normal[BinarySerialize[expr]];
    result = Quiet[decodeWXF[$typeCheckFn[handle, wxfBytes]]];
    If[AssociationQ[result], result, $Failed]
]

(* Peel nested LeanForall chain into parameter list *)

binderKindName["default"] = "explicit"

binderKindName["implicit"] = "implicit"

binderKindName["strictImplicit"] = "implicit"

binderKindName["instImplicit"] = "instance"

binderKindName[_] = "explicit"

peelForalls[expr_] := peelForalls[expr, "Params"]

peelForalls[LeanForall[name_, type_, body_, binder_], "Params"] := Prepend[
    peelForalls[body, "Params"],
    <|"Name" -> name, "Type" -> type, "TypeForm" -> leanPP[type], "Binder" -> binderKindName[binder]|>
]

peelForalls[_, "Params"] := {}

peelForalls[LeanForall[_, _, body_, _], "Body"] := peelForalls[body, "Body"]

peelForalls[body_, "Body"] := body

(* Property access -- lazy fetch from handle *)

(* Second arg: integer unfold level for Type/Term/TypeForm/TermForm, or Rule opts *)

(* Level 0 = no unfolding (default). Level N = unfold definitions N times. *)

LeanTerm /: LeanTerm[data_Association][prop_String, args___] := Block[
    {
        handle = Lookup[data, "_Handle", None],
        name = Lookup[data, "Name", ""],
        level = Replace[First[{args}, 0], Except[_Integer] -> 0],
        opts = Cases[{args}, _Rule],
        expr = Lookup[data, "_Expr", None]
    }
    ,
(* For constructed expressions, handle Type/TypeForm specially 
    *)
    If[ expr =!= None && IntegerQ[handle] && MatchQ[prop, "Type" | "TypeForm"],
        With[{tc = typeCheck[expr, handle]},
            If[AssociationQ[tc], If[prop === "Type", tc["Type"], tc["TypeForm"]], $Failed]
        ]
        ,
        (* Normal property dispatch for imported terms *)
        Switch[ prop,
            "Properties",
                {
                    "Name",
                    "Kind",
                    "Type",
                    "Term",
                    "TypeForm",
                    "TermForm",
                    "TypeRefs",
                    "TermRefs",
                    "Axioms",
                    "KernelCheck",
                    "Module",
                    "Source",
                    "ExprGraph",
                    "CallGraph",
                    "Parameters",
                    "Body"
                }
            ,
            "Parameters",
                peelForalls[LeanTerm[data]["Type"]]
            ,
            "Body",
                peelForalls[LeanTerm[data]["Type"], "Body"]
            ,
            "Name",
                data["Name"]
            ,
            "Kind",
                data["Kind"]
            ,
            "Type",
                If[ KeyExistsQ[data, "Type"] && level === 0,
                    data["Type"]
                    ,
                    If[ IntegerQ[handle],
                        If[level > 0, fetchUnfolded[handle, name, "Type", level], fetchField[handle, name, "Type"]]
                        ,
(* Fallback to _TypeExpr for ProofToLean terms 
    *)
                        If[KeyExistsQ[data, "_TypeExpr"], data["_TypeExpr"], Missing["NoHandle"]]
                    ]
                ]
            ,
            "Term",
                If[ KeyExistsQ[data, "Term"] && level === 0,
                    data["Term"]
                    ,
                    If[ IntegerQ[handle],
                        If[level > 0, fetchUnfolded[handle, name, "Term", level], fetchField[handle, name, "Term"]]
                        ,
(* Fallback to _Tactic for ProofToLean terms 
    *)
                        If[KeyExistsQ[data, "_Tactic"], data["_Tactic"], Missing["NoHandle"]]
                    ]
                ]
            ,
(* As #check prints it: Lean's own delaborator, run by the lean frontend
   (typeFormFor), with notation, coercions and field notation; "Open" -> {ns}
   prints names under those namespaces unqualified. LeanLink's WL printer is
   the fallback - no handle, an unfolded type, or no toolchain. *)
            "TypeForm",
                With[{r = If[IntegerQ[handle] && level === 0, typeFormFor[handle, name, openNamespaces[opts]], None]},
                    If[ StringQ[r],
                        r
                        ,
                        With[{typeExpr = LeanTerm[data]["Type", level]},
                            If[MatchQ[typeExpr, _Missing | $Failed], Missing["NoHandle"], leanPP[typeExpr]]
                        ]
                    ]
                ]
            ,
            "TermForm",
                If[ IntegerQ[handle],
                    With[{r = Quiet[decodeWXF[$ppValueFn[handle, name, level, openNamespaces[opts]]]]},
                        If[StringQ[r], r, leanPP[LeanTerm[data]["Term", level]]]
                    ]
                    ,
                    (* Fallback: use tacticSource for _Tactic *)
                    With[{tactic = If[KeyExistsQ[data, "_Tactic"], data["_Tactic"], LeanTerm[data]["Term", level]]},
                        If[ MatchQ[tactic, _LeanTactic],
                            tacticSource[tactic]
                            ,
                            If[MatchQ[tactic, _Missing], Missing["NoHandle"], leanPP[tactic]]
                        ]
                    ]
                ]
            ,
            "TypeRefs",
                If[ KeyExistsQ[data, "TypeRefs"],
                    data["TypeRefs"]
                    ,
                    If[IntegerQ[handle], fetchField[handle, name, "TypeRefs"], {}]
                ]
            ,
            "TermRefs",
                If[ KeyExistsQ[data, "TermRefs"],
                    data["TermRefs"]
                    ,
                    If[IntegerQ[handle], fetchField[handle, name, "TermRefs"], {}]
                ]
            ,
            "Source",
                If[IntegerQ[handle], declarationSource[handle, name], Missing["NoHandle"]]
            ,
            "Module",
                If[ IntegerQ[handle],
                    With[{r = Quiet[decodeWXF[$constantModuleFn[handle, name]]]},
                        Which[
                            StringQ[r] && ! StringStartsQ[r, "ERROR: "], r,
                            StringQ[r], Message[LeanTerm::err, StringDelete[r, StartOfString ~~ "ERROR: "]]; $Failed,
                            True, $Failed
                        ]
                    ]
                    ,
                    Missing["NoHandle"]
                ]
            ,
(* Exact axiom audit: Lean.collectAxioms, the traversal behind #print axioms.
   Unlike "CallGraph" (a display graph that filters auxiliary lemmas and caps
   depth), this follows every dependency. Like #print axioms it trusts that each
   declaration passed the kernel when its module was built, which a module can
   skip (debug.skipKernelTC, or a direct addDecl): a forged proof then shows no
   axioms. Verifying an untrusted proof takes a kernel replay of its module, as
   leanchecker does. *)
            "Axioms",
                If[ IntegerQ[handle],
                    With[{r = Quiet[decodeWXF[$collectAxiomsFn[handle, name]]]},
                        Which[
                            ListQ[r], r,
                            StringQ[r], Message[LeanTerm::err, StringDelete[r, StartOfString ~~ "ERROR: "]]; $Failed,
                            True, $Failed
                        ]
                    ]
                    ,
                    Missing["NoHandle"]
                ]
            ,
(* Kernel replay of the declaring module, as leanchecker does: it catches a
   declaration that never passed the kernel, which "Axioms" cannot see. A
   rejection is a result, a Failure, not an error. *)
            "KernelCheck",
                If[ IntegerQ[handle],
                    With[{r = Quiet[decodeWXF[withLeanPath[handleInfo[handle, "SearchPath"], $kernelCheckFn[handle, name]]]]},
                        Which[
                            AssociationQ[r], Success["KernelChecked", <|"MessageTemplate" -> "The kernel accepts all `1` declarations of `2`.", "MessageParameters" -> {r["Declarations"], r["Module"]}, "Module" -> r["Module"], "Declarations" -> r["Declarations"]|>],
                            StringQ[r] && StringStartsQ[r, "REJECTED: "], Failure["KernelRejected", <|"MessageTemplate" -> "`1`", "MessageParameters" -> {StringDelete[r, StartOfString ~~ "REJECTED: "]}|>],
                            StringQ[r], Message[LeanTerm::err, StringDelete[r, StartOfString ~~ "ERROR: "]]; $Failed,
                            True, $Failed
                        ]
                    ]
                    ,
                    Missing["NoHandle"]
                ]
            ,
            "ExprGraph",
                exprToGraph[
                    With[{term = LeanTerm[data]["Term"]},
                        Replace[term, LeanNoValue[] -> LeanTerm[data]["Type"]]
                    ]
                ]
            ,
            "CallGraph",
                callGraph[data, Sequence @@ opts]
            ,
            _,
                If[StringStartsQ[prop, "_"], Missing["Private", prop], data[prop]]
        ]
    ]
]

(* ============================================================================ *)

(* Expression Graph                                                             *)

(* ============================================================================ *)

(* Expr graph node backgrounds, by Lean expression head *)

$headColor = <|
    LeanApp -> mmBg[$mmEqHypothesis],
    LeanLam -> mmBg[$mmHypothesis],
    LeanForall -> mmBg[$mmSubstitution],
    LeanLet -> mmBg[$mmTheorem],
    LeanConst -> mmBg[$mmAxiom],
    LeanBVar -> GrayLevel[0.95],
    LeanSort -> mmBg[$mmEqAxiom],
    LeanLitNat -> mmBg[$mmBisubstitution],
    LeanLitStr -> mmBg[$mmBisubstitution],
    LeanProj -> mmBg[$mmAxiom],
    LeanTruncated -> GrayLevel[0.9],
    LeanNoValue -> GrayLevel[0.9]
|>

exprToGraph[expr_] := Block[{id = 0, verts, edges, lbls = <||>, cols = <||>, kinds = <||>, walk, reaped},
    walk[e_] := Block[{myId, label, col, children, edgeLbls},
        myId = ++id;
        {label, col, children, edgeLbls} = exprNodeInfo[e];
        Sow[myId, "vert"];
        AssociateTo[lbls, myId -> label];
        AssociateTo[cols, myId -> col];
        AssociateTo[
            kinds
            ,
            myId ->
                Replace[
                    Head[e]
                    ,
                    {
                        LeanForall -> "forall",
                        LeanLam -> "lam",
                        LeanApp -> "app",
                        LeanConst -> "const",
                        LeanBVar -> "bvar",
                        LeanSort -> "sort",
                        LeanLet -> "let",
                        LeanLitNat -> "litNat",
                        LeanLitStr -> "litStr",
                        LeanProj -> "proj",
                        _ -> "?"
                    }
                ]
        ];
        MapThread[
            Function[{child, elbl},
                Block[{childId = walk[child]},
                    Sow[DirectedEdge[myId, childId, elbl], "edge"]
                ]
            ]
            ,
            {children, edgeLbls}
        ];
        myId
    ];
    reaped = Reap[walk[expr], {"vert", "edge"}][[2]];
    verts = First[reaped[[1]], {}];
    edges = First[reaped[[2]], {}];
    If[Length[verts] == 0, Return[Graph[{}]]];
    Graph[
        verts
        ,
        edges
        ,
        VertexShapeFunction ->
            Map[
                With[{bg = cols[#], lbl = lbls[#], kind = kinds[#]},
                    # ->
                        Function[
                            Inset[
                                Framed[
                                    Style[
                                        Tooltip[lbl, kind]
                                        ,
                                        "Text"
                                        ,
                                        FontSize -> 7
                                        ,
                                        LightDarkSwitched[
                                            If[ColorDistance[bg, White] > 0.4, White, Black],
                                            If[ColorDistance[bg, Black] > 0.4, White, GrayLevel[0.9]]
                                        ]
                                        ,
                                        Bold
                                    ]
                                    ,
                                    Background -> LightDarkSwitched[bg]
                                    ,
                                    RoundingRadius -> 3
                                    ,
                                    FrameStyle -> LightDarkSwitched[GrayLevel[0.4], GrayLevel[0.6]]
                                    ,
                                    FrameMargins -> {{3, 3}, {1, 1}}
                                ]
                                ,
                                #1
                                ,
                                #3
                            ]
                        ]
                ]&
                ,
                verts
            ]
        ,
        GraphLayout -> {"LayeredDigraphEmbedding", "Orientation" -> Top}
        ,
        VertexSize -> If[Length[verts] <= 10, 0.3, 0.05]
        ,
        EdgeStyle -> Directive[GrayLevel[0.5], Arrowheads[0.02]]
        ,
        EdgeLabels
        ->
        (
            #
            ->
            Style[#[[3]], FontSize -> 5, FontFamily -> "Menlo", LightDarkSwitched[GrayLevel[0.3], GrayLevel[0.7]]]&
            /@
            edges
        )
        ,
        ImageSize -> Max[300, Min[1200, 40 * Length[verts]]]
        ,
        AspectRatio -> 1/2
        ,
        PerformanceGoal -> "Quality"
    ]
]

exprNodeInfo[LeanForall[n_, dom_, body_, bi_]] := {"\[ForAll] " <> cleanName[n], $headColor[LeanForall], {dom, body}, {"type", "body"}}

exprNodeInfo[LeanLam[n_, type_, body_, _]] := {"\[Lambda] " <> cleanName[n], $headColor[LeanLam], {type, body}, {"type", "body"}}

exprNodeInfo[LeanApp[fn_, arg_]] := {"app", $headColor[LeanApp], {fn, arg}, {"fn", "arg"}}

exprNodeInfo[LeanConst[n_, _]] := {shortName[n], $headColor[LeanConst], {}, {}}

exprNodeInfo[LeanBVar[i_]] := {"bvar " <> ToString[i], $headColor[LeanBVar], {}, {}}

(* Sort always shows level subtree, matching DOT walkExpr *)

exprNodeInfo[LeanSort[l_]] := {"Sort", $headColor[LeanSort], {l}, {"level"}}

(* Level nodes *)

exprNodeInfo[LeanLevelZero[]] := {"zero", $headColor[LeanSort], {}, {}}

exprNodeInfo[LeanLevelSucc[l_]] := {"succ", $headColor[LeanSort], {l}, {"level"}}

exprNodeInfo[LeanLevelMax[a_, b_]] := {"max", $headColor[LeanSort], {a, b}, {"left", "right"}}

exprNodeInfo[LeanLevelIMax[a_, b_]] := {"imax", $headColor[LeanSort], {a, b}, {"left", "right"}}

exprNodeInfo[LeanLevelParam[n_]] := {n, $headColor[LeanSort], {}, {}}

exprNodeInfo[LeanLet[n_, type_, val_, body_]] := {"let " <> cleanName[n], $headColor[LeanLet], {type, val, body}, {"type", "val", "body"}}

exprNodeInfo[LeanLitNat[n_]] := {ToString[n], $headColor[LeanLitNat], {}, {}}

exprNodeInfo[LeanLitStr[s_]] := {"\"" <> s <> "\"", $headColor[LeanLitStr], {}, {}}

exprNodeInfo[LeanProj[t_, i_, struct_]] := {shortName[t] <> "." <> ToString[i], $headColor[LeanProj], {struct}, {"struct"}}

exprNodeInfo[LeanTruncated[_]] := {"\[Ellipsis]", $headColor[LeanTruncated], {}, {}}

exprNodeInfo[LeanNoValue[]] := {"\[Dash]", $headColor[LeanNoValue], {}, {}}

exprNodeInfo[other_] := {ToString[Short[other]], GrayLevel[0.6], {}, {}}

(* ============================================================================ *)

(* Call Graph                                                                   *)

(* ============================================================================ *)

collectConsts[e_] := Union[Cases[e, LeanConst[n_String, _] :> n, Infinity]]

Options[callGraph] = {"Depth" -> 10}

callGraph[data_Association, opts___Rule] := Block[{
    name,
    handle,
    nodes,
    edgeList,
    frontier,
    visited,
    typeRefs,
    termRefs,
    allRefs,
    maxDepth,
    depth = 0,
    verts,
    edges,
    vertColors,
    fullNames,
    edgeStyles,
    edgeLabels,
    getKind,
    getVertColor,
    classifyEdge,
    kindCache,
    refsCache,
    getRefsFor
},
    maxDepth = Lookup[{opts}, "Depth", 10];
    name = data["Name"];
    handle = Lookup[data, "_Handle", None];
    (* Cache for kinds and refs discovered during BFS *)
    kindCache = <|name -> Lookup[data, "Kind", "def"]|>;
    refsCache = <|
        name ->
            {
                If[ KeyExistsQ[data, "TypeRefs"],
                    data["TypeRefs"]
                    ,
                    If[IntegerQ[handle], fetchField[handle, name, "TypeRefs"], {}]
                ]
                ,
                If[ KeyExistsQ[data, "TermRefs"],
                    data["TermRefs"]
                    ,
                    If[IntegerQ[handle], fetchField[handle, name, "TermRefs"], {}]
                ]
            }
    |>;
(* Query FFI for a constant's kind and refs, caching results 
    *)
    getRefsFor[n_String] := If[ KeyExistsQ[refsCache, n],
        refsCache[n]
        ,
        Block[{tRefs = {}, vRefs = {}, kind = "def"},
            If[ IntegerQ[handle] && handle > 0,
                Quiet @
                    With[{r = decodeWXF[$getConstantFn[handle, n]]},
                        If[MatchQ[r, LeanConstant[_, _String, __]], kind = r[[2]]]
                    ];
                Quiet @
                    With[{uc = decodeWXF[$getUsedConstantsFn[handle, n]]},
                        If[ AssociationQ[uc],
                            tRefs = Lookup[uc, "type", {}];
                            vRefs = Lookup[uc, "value", {}]
                        ]
                    ]
            ];
            AssociateTo[kindCache, n -> kind];
            AssociateTo[refsCache, n -> {tRefs, vRefs}];
            {tRefs, vRefs}
        ]
    ];
    (* BFS from root *)
    nodes = <|name -> True|>;
    edgeList = {};
    frontier = {name};
    While[
        frontier =!= {} && depth < maxDepth
        ,
        depth++;
        Block[{newFrontier = {}},
            Do[
                {typeRefs, termRefs} = getRefsFor[src];
                allRefs = Union[typeRefs, termRefs];
                (* Match code.lean isInternalName *)
                allRefs = Select[
                    DeleteCases[allRefs, src],
                    ! StringContainsQ[#, "._" | ".match_" | ".proof_" | "._uniq" | ".brecOn" | ".below" | ".casesOn" | ".noConfusion"]&
                ];
                Do[
                    classifyEdge = Which[ 
                        MemberQ[termRefs, ref] && MemberQ[typeRefs, ref],
                            "term+type"
                        ,
                        MemberQ[termRefs, ref],
                            "term"
                        ,
                        True,
                            "type"
                    ];
                    AppendTo[edgeList, {src, ref, classifyEdge}];
                    If[ ! KeyExistsQ[nodes, ref],
                        AssociateTo[nodes, ref -> True];
                        getRefsFor[ref];(* pre-cache kind *)
                        AppendTo[newFrontier, ref]
                    ]
                    ,
                    {ref, allRefs}
                ]
                ,
                {src, frontier}
            ];
            frontier = newFrontier
        ]
    ];
    (* Kind lookup from cache, fall back to heuristic *)
    getKind[n_String] := Block[{k = Lookup[kindCache, n, None]},
        If[ k =!= None,
            k
            ,
            Which[ 
                StringEndsQ[n, ".rec"] || StringEndsQ[n, ".recOn"] || StringEndsQ[n, ".casesOn"],
                    "recursor"
                ,
                StringEndsQ[n, ".mk"] || StringContainsQ[n, ".mk."],
                    "constructor"
                ,
                StringMatchQ[n, LetterCharacter ~~ ___] && UpperCaseQ[StringTake[n, 1]],
                    "structure"
                ,
                True,
                    "def"
            ]
        ]
    ];
    (* Colors matching code.lean *)
    getVertColor[n_String] := Lookup[$callNodeColor, getKind[n], GrayLevel[0.88]];
    verts = shortName /@ Keys[nodes];
    edges = DeleteDuplicates[DirectedEdge[shortName[#[[1]]], shortName[#[[2]]], #[[3]]]& /@ edgeList];
    (* Per-vertex colors *)
    vertColors = Association[(shortName[#] -> getVertColor[#])& /@ Keys[nodes]];
    (* Full name lookup for tooltips *)
    fullNames = Association[(shortName[#] -> #)& /@ Keys[nodes]];
    (* Edge styles matching code.lean *)
    edgeStyles = Table[
        With[{
            label = e[[3]]
            ,
            col = Lookup[$callEdgeColor, e[[3]], GrayLevel[0.33]]
            ,
            pw = Switch[ e[[3]],
                "term",
                    1.5
                ,
                "type",
                    0.8
                ,
                "term+type",
                    1.5
                ,
                _,
                    1.2
            ]
        },
            e ->
                Directive[
                    LightDarkSwitched[col, Lighter[col, 0.4]],
                    AbsoluteThickness[pw],
                    Arrowheads[0.01],
                    If[label === "type", Dashing[{Small, Small}], Sequence @@ {}]
                ]
        ]
        ,
        {e, edges}
    ];
    (* Edge labels *)
    edgeLabels = Table[
        With[{label = e[[3]], col = Lookup[$callEdgeColor, e[[3]], GrayLevel[0.4]]},
            e -> Style[label, FontSize -> 5, FontFamily -> "Menlo", LightDarkSwitched[col, GrayLevel[0.7]]]
        ]
        ,
        {e, edges}
    ];
    Graph[
        verts
        ,
        edges
        ,
        VertexShapeFunction ->
            Map[
                With[{
                    bg = Lookup[vertColors, #, GrayLevel[0.88]],
                    lbl = #,
                    fullName = Lookup[fullNames, #, #],
                    kind = getKind[Lookup[fullNames, #, #]]
                },
                    # ->
                        Function[
                            Inset[
                                Framed[
                                    Style[
                                        Tooltip[lbl, fullName <> " (" <> ToString[kind] <> ")"]
                                        ,
                                        "Text"
                                        ,
                                        FontSize -> 7
                                        ,
                                        LightDarkSwitched[
                                            If[ColorDistance[bg, White] > 0.4, White, Black],
                                            If[ColorDistance[bg, Black] > 0.4, White, GrayLevel[0.9]]
                                        ]
                                        ,
                                        Bold
                                    ]
                                    ,
                                    Background -> LightDarkSwitched[bg]
                                    ,
                                    RoundingRadius -> 3
                                    ,
                                    FrameStyle -> LightDarkSwitched[GrayLevel[0.4], GrayLevel[0.6]]
                                    ,
                                    FrameMargins -> {{3, 3}, {1, 1}}
                                ]
                                ,
                                #1
                                ,
                                #3
                            ]
                        ]
                ]&
                ,
                verts
            ]
        ,
        GraphLayout -> {"LayeredDigraphEmbedding", "Orientation" -> Top}
        ,
        EdgeStyle -> edgeStyles
        ,
        EdgeLabels -> edgeLabels
        ,
        VertexSize -> If[Length[verts] <= 10, 0.3, 0.05]
        ,
        ImageSize -> Max[300, Min[1200, 40 * Length[verts]]]
        ,
        AspectRatio -> 1/2
        ,
        PerformanceGoal -> "Quality"
    ]
]

(* ============================================================================ *)

(* LeanTerm SummaryBox                                                          *)

(* ============================================================================ *)

LeanTerm /: MakeBoxes[obj : LeanTerm[data_Association], StandardForm] := Block[{name, kind, typePP, termPP, col, icon, sn, nTypeRefs, nTermRefs},
    name = Lookup[data, "Name", "?"];
    kind = Lookup[data, "Kind", "?"];
    (* Use Lean's native pretty-printer for display *)
    typePP = Quiet[obj["TypeForm"]];
    termPP = Quiet[obj["TermForm"]];
    nTypeRefs = Length[obj["TypeRefs"]];
    nTermRefs = Length[obj["TermRefs"]];
    col = Lookup[$kindColor, kind, GrayLevel[0.5]];
    icon = Graphics[{col, Disk[]}, ImageSize -> 12];
    sn = shortName[name];
    BoxForm`ArrangeSummaryBox[
        LeanTerm
        ,
        obj
        ,
        icon
        ,
        {
            BoxForm`SummaryItem[{"Kind: ", Style[kind, Bold, col]}],
            BoxForm`SummaryItem[{"Name: ", Style[sn, Bold]}]
        }
        ,
        {
            If[name =!= sn, BoxForm`SummaryItem[{"Full name: ", name}], Nothing]
            ,
            BoxForm`SummaryItem[{"Type: ", If[StringQ[typePP], Style[typePP, "Input"], "--"]}]
            ,
            If[ StringQ[termPP] && termPP =!= "<pp error>",
                BoxForm`SummaryItem[{"Term: ", Style[Short[termPP, 1], "Input"]}]
                ,
                Nothing
            ]
            ,
            If[ nTypeRefs + nTermRefs > 0,
                BoxForm`SummaryItem[{"Refs: ", ToString[nTypeRefs] <> " type, " <> ToString[nTermRefs] <> " term"}]
                ,
                Nothing
            ]
        }
        ,
        StandardForm
        ,
        "Interpretable" -> Automatic
    ]
]

(* ============================================================================ *)

(* InterpretationBox helper                                                     *)

(* ============================================================================ *)

(* iBox evaluates displayBoxes FIRST, then wraps in InterpretationBox.
   This avoids the HoldAllComplete issue where With can't substitute
   inside raw InterpretationBox calls. *)

iBox[expr_, displayBoxes_] := InterpretationBox[displayBoxes, expr]

(* ============================================================================ *)

(* Lean-style pretty-printer (string form)                                      *)

(* leanPP -- fallback pretty-printer for expressions without a handle.          *)

(* Lean's native PrettyPrinter.ppExpr is used when a handle is available.      *)

(* Proper de Bruijn substitution: replace BVar[cutoff] with FreeVar[name],
   shift down higher indices, tracking depth through binders *)

substBVar[expr_, name_String, cutoff_Integer] := Switch[ Head[expr],
    LeanBVar,
        Which[ 
            expr[[1]] === cutoff,
                LeanFreeVar[name]
            ,
            expr[[1]] > cutoff,
                LeanBVar[expr[[1]] - 1]
            ,
            True,
                expr
        ]
    ,
    LeanForall,
        If[ Length[expr] >= 4,
            LeanForall[expr[[1]], substBVar[expr[[2]], name, cutoff], substBVar[expr[[3]], name, cutoff + 1], expr[[4]]]
            ,
            expr
        ]
    ,
    LeanLam,
        LeanLam[expr[[1]], substBVar[expr[[2]], name, cutoff], substBVar[expr[[3]], name, cutoff + 1], expr[[4]]]
    ,
    LeanLet,
        LeanLet[
            expr[[1]],
            substBVar[expr[[2]], name, cutoff],
            substBVar[expr[[3]], name, cutoff],
            substBVar[expr[[4]], name, cutoff + 1]
        ]
    ,
    LeanApp,
        LeanApp[substBVar[expr[[1]], name, cutoff], substBVar[expr[[2]], name, cutoff]]
    ,
    LeanMData,
        LeanMData[expr[[1]], substBVar[expr[[2]], name, cutoff]]
    ,
    LeanProj,
        LeanProj[expr[[1]], expr[[2]], substBVar[expr[[3]], name, cutoff]]
    ,
    _,
        expr
]

substBVar0[body_, name_String] := substBVar[body, name, 0]

leanPP[expr_] := leanPP[expr, 6]

leanPP[e_, 0] := Switch[ Head[e],
    LeanConst,
        shortName[e[[1]]]
    ,
    LeanApp,
        leanPP[e[[1]], 0]
    ,
    LeanBVar,
        "#" <> ToString[e[[1]]]
    ,
    LeanFreeVar,
        cleanName[e[[1]]]
    ,
    LeanLitNat,
        ToString[e[[1]]]
    ,
    LeanLitStr,
        "\"" <> e[[1]] <> "\""
    ,
    LeanSort,
        leanPP[e, 1]
    ,
    LeanForall,
        "\[ForAll]"
    ,
    LeanLam,
        "\[Lambda]"
    ,
    LeanLet,
        "let"
    ,
    LeanMData,
        leanPP[e[[2]], 0]
    ,
    _,
        ToString[Head[e]]
]

leanPP[LeanConst[name_String, _List], _Integer] := shortName[name]

(* sorts and levels read as in Lean, as the source printer writes them: Type (u + 1), Sort (max u v) *)

leanPP[LeanSort[level_], _] := sortSource[level]

leanPP[LeanBVar[n_Integer], _] := "#" <> ToString[n]

leanPP[LeanFreeVar[name_String], _] := cleanName[name]

leanPP[LeanFVar[_], _] := "_fvar"

leanPP[LeanMVar[_], _] := "?_"

leanPP[LeanLitNat[n_Integer], _] := ToString[n]

leanPP[LeanLitStr[s_String], _] := "\"" <> s <> "\""

(* Forall / Pi -- collect consecutive binders *)

leanPP[e : LeanForall[_, _, _, _], d_Integer] := Block[{binders, body = e, name, dom, bi, nm, nBinders = 0},
    binders = First[
        Last[
            Reap[
                While[
                    MatchQ[body, LeanForall[_, _, _, _]] && d - nBinders > 0
                    ,
                    {name, dom, body, bi} = List @@ body;
                    nm = cleanName[name];
                    body = substBVar0[body, name];
                    nBinders++;
                    Sow[
                        Switch[ bi,
                            "implicit",
                                "{" <> nm <> " : " <> leanPP[dom, d - 1] <> "}"
                            ,
                            "strictImplicit",
                                "\[LeftDoubleBracket]" <> nm <> " : " <> leanPP[dom, d - 1] <> "\[RightDoubleBracket]"
                            ,
                            "instImplicit",
                                "[" <> nm <> " : " <> leanPP[dom, d - 1] <> "]"
                            ,
                            _,
                                If[ nm === "" || StringMatchQ[nm, "_" ~~ ___],
                                    leanPP[dom, d - 1]
                                    ,
                                    "(" <> nm <> " : " <> leanPP[dom, d - 1] <> ")"
                                ]
                        ]
                    ]
                ]
            ]
        ]
        ,
        {}
    ];
    If[ AllTrue[
        binders
        ,
        ! StringStartsQ[#, "("]
        &&
        ! StringStartsQ[#, "{"]
        &&
        ! StringStartsQ[#, "["]
        &&
        ! StringStartsQ[#, "\[LeftDoubleBracket]"]&
    ],
        StringRiffle[Append[binders, leanPP[body, d - 1]], " \[RightArrow] "]
        ,
        "\[ForAll] " <> StringRiffle[binders, " "] <> ", " <> leanPP[body, d - 1]
    ]
]

(* Lambda *)

leanPP[e : LeanLam[_, _, _, _], d_Integer] := Block[{binders, body = e, name, dom, bi, nm, nBinders = 0},
    binders = First[
        Last[
            Reap[
                While[
                    MatchQ[body, LeanLam[_, _, _, _]] && d - nBinders > 0
                    ,
                    {name, dom, body, bi} = List @@ body;
                    nm = cleanName[name];
                    body = substBVar0[body, name];
                    nBinders++;
                    Sow[
                        Switch[ bi,
                            "implicit",
                                "{" <> nm <> " : " <> leanPP[dom, d - 1] <> "}"
                            ,
                            "instImplicit",
                                "[" <> nm <> " : " <> leanPP[dom, d - 1] <> "]"
                            ,
                            _,
                                "(" <> nm <> " : " <> leanPP[dom, d - 1] <> ")"
                        ]
                    ]
                ]
            ]
        ]
        ,
        {}
    ];
    "\[Lambda] " <> StringRiffle[binders, " "] <> " \[DoubleLongRightArrow] " <> leanPP[body, d - 1]
]

leanPP[LeanLet[name_String, type_, val_, body_], d_Integer] := "let " <> cleanName[name] <> " : " <> leanPP[type, d - 1] <> " := " <> leanPP[val, d - 1] <> "; " <> leanPP[body, d - 1]

(* Application -- notation-aware rules then generic fallback *)

(* Flatten app chain: LeanApp[LeanApp[f,a],b] -> {f, a, b} *)

flattenApp[e_LeanApp] := Block[{fn = e, args},
    args = Reverse @
        First[
            Last[
                Reap[
                    While[
                        MatchQ[fn, LeanApp[_, _]]
                        ,
                        Sow[fn[[2]]];
                        fn = fn[[1]]
                    ]
                ]
            ]
            ,
            {}
        ];
    {fn, args}
]

(* Extract head constant name *)

appHeadName[e_LeanApp] := With[{fa = flattenApp[e]},
    If[MatchQ[fa[[1]], LeanConst[_String, _]], fa[[1, 1]], None]
]

appHeadName[_] := None

(* Infix helper -- last 2 args *)

leanPPInfix[e_LeanApp, d_Integer, op_String] := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 2,
        leanPP[args[[-2]], d - 1] <> " " <> op <> " " <> leanPP[args[[-1]], d - 1]
        ,
        leanPP[flattenApp[e][[1]], d - 1] <> " " <> StringRiffle[leanPP[#, d - 1]& /@ args, " "]
    ]
]

(* Eq *)

leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Eq" && Length[flattenApp[e][[2]]] >= 3 := With[{args = flattenApp[e][[2]]},
    leanPP[args[[-2]], d - 1] <> " = " <> leanPP[args[[-1]], d - 1]
]

(* Ne *)

leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Ne" && Length[flattenApp[e][[2]]] >= 3 := With[{args = flattenApp[e][[2]]},
    leanPP[args[[-2]], d - 1] <> " \[NotEqual] " <> leanPP[args[[-1]], d - 1]
]

(* Neg.neg / HNeg.hNeg -- unary prefix *)

leanPP[e_LeanApp, d_Integer] /; MatchQ[appHeadName[e], "Neg.neg" | "HNeg.hNeg" | "instHNeg.hNeg"] := "-" <> leanPP[Last[flattenApp[e][[2]]], d - 1]

(* Arithmetic infix *)

leanPP[e_LeanApp, d_Integer] /; MatchQ[appHeadName[e], "HMul.hMul" | "instHMul.hMul"] := leanPPInfix[e, d, "*"]

leanPP[e_LeanApp, d_Integer] /; MatchQ[appHeadName[e], "HAdd.hAdd" | "instHAdd.hAdd"] := leanPPInfix[e, d, "+"]

leanPP[e_LeanApp, d_Integer] /; MatchQ[appHeadName[e], "HSub.hSub" | "instHSub.hSub"] := leanPPInfix[e, d, "-"]

leanPP[e_LeanApp, d_Integer] /; MatchQ[appHeadName[e], "HDiv.hDiv" | "instHDiv.hDiv"] := leanPPInfix[e, d, "/"]

leanPP[e_LeanApp, d_Integer] /; MatchQ[appHeadName[e], "HPow.hPow" | "instHPow.hPow"] := leanPPInfix[e, d, "^"]

leanPP[e_LeanApp, d_Integer] /; MatchQ[appHeadName[e], "HSMul.hSMul" | "instHSMul.hSMul"] := leanPPInfix[e, d, "\[CenterDot]"]

(* Comparisons *)

leanPP[e_LeanApp, d_Integer] /; StringEndsQ[Replace[appHeadName[e], None -> ""], ".le"] := leanPPInfix[e, d, "\[LessEqual]"]

leanPP[e_LeanApp, d_Integer] /; StringEndsQ[Replace[appHeadName[e], None -> ""], ".lt"] := leanPPInfix[e, d, "<"]

(* Logic *)

leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Iff" && Length[flattenApp[e][[2]]] == 2 := leanPPInfix[e, d, "\[DoubleLeftRightArrow]"]

leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "And" && Length[flattenApp[e][[2]]] == 2 := leanPPInfix[e, d, "\[And]"]

leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Or" && Length[flattenApp[e][[2]]] == 2 := leanPPInfix[e, d, "\[Or]"]

leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Not" && Length[flattenApp[e][[2]]] == 1 := "\[Not]" <> leanPP[flattenApp[e][[2, 1]], d - 1]

(* Exists *)

leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Exists" := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 1 && MatchQ[Last[args], LeanLam[_, _, _, _]],
(* Substitute the binder name into the body, as the forall/lambda printers do;
   without it the bound variable renders as its de Bruijn index (#0). *)
        "\[Exists] " <> cleanName[Last[args][[1]]] <> ", " <> leanPP[substBVar0[Last[args][[3]], Last[args][[1]]], d - 1]
        ,
        "Exists " <> StringRiffle[leanPP[#, d - 1]& /@ args, " "]
    ]
]

(* OfNat.ofNat -- render as literal number *)

leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "OfNat.ofNat" := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 2,
        leanPP[args[[2]], d - 1]
        ,
        "OfNat " <> StringRiffle[leanPP[#, d - 1]& /@ args, " "]
    ]
]

(* Function.Injective / Bijective *)

leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Function.Injective" := "Injective " <> leanPP[Last[flattenApp[e][[2]]], d - 1]

leanPP[e_LeanApp, d_Integer] /; appHeadName[e] === "Function.Bijective" := "Bijective " <> leanPP[Last[flattenApp[e][[2]]], d - 1]

(* Generic fallback *)

leanPP[e_LeanApp, d_Integer] := Block[{fn = e, args, a},
    args = Reverse @
        First[
            Last[
                Reap[
                    While[
                        MatchQ[fn, LeanApp[_, _]]
                        ,
                        a = fn[[2]];
                        fn = fn[[1]];
                        Sow[leanPP[a, d - 1]]
                    ]
                ]
            ]
            ,
            {}
        ];
    leanPP[fn, d - 1] <> " " <> StringRiffle[args, " "]
]

(* Lean numbers the fields of a structure from 1 *)

leanPP[LeanProj[struct_String, idx_Integer, expr_], d_Integer] := leanPP[expr, d - 1] <> "." <> ToString[idx + 1]

leanPP[LeanMData[_, expr_], d_Integer] := leanPP[expr, d]

leanPP[LeanNoValue[], _] := "(no value)"

(* Fallback *)

leanPP[$Failed, _] := "(failed)"

leanPP[other_, _] := ToString[Short[other, 1]]

(* ============================================================================ *)

(* leanSource -- Lean 4 source-safe pretty-printer                               *)

(* Unlike leanPP (display), this produces valid Lean 4 ASCII/Unicode syntax.   *)

(* ============================================================================ *)

(* ppExprFFI -- pretty-print via Lean's PrettyPrinter when handle available *)

ppExprFFI[handle_Integer, expr_] := Quiet[
    Block[{wxf, res},
        wxf = BinarySerialize[expr, PerformanceGoal -> "Speed"];
        res = $ppExprFn[handle, Normal[wxf]];
        If[ListQ[res], decodeWXF[res], $Failed]
    ]
    ,
    {LibraryFunction::cfsa}
]

ppExprFFI[_, _] := $Failed

(* LeanExportString -- export LeanEnvironment to source string *)

(* Proof environment with _DeclOrder -- serialize declarations *)

LeanExportString[env_LeanEnvironment] /; KeyExistsQ[env[[1]], "_DeclOrder"] := Block[{data = env[[1]], preamble, decls, preambleLines, declLines},
    preamble = Lookup[data, "_Preamble", <||>];
    decls = Lookup[data, "_DeclOrder", {}];
    (* Preamble *)
    preambleLines = First[
        Last[
            Reap[
                If[ Lookup[preamble, "Imports", {}] =!= {},
                    Do[Sow["import " <> imp], {imp, preamble["Imports"]}];
                    Sow[""]
                ];
                (* Type axiom *)
                If[ KeyExistsQ[preamble, "TypeAxiom"],
                    Sow["axiom " <> preamble["TypeAxiom"] <> " : Type"];
                    Sow[""]
                ];
                (* Operators *)
                If[ KeyExistsQ[preamble, "Operators"],
                    KeyValueMap[
                        Sow["axiom " <> #1 <> " : " <> StringJoin[Table["U " <> FromCharacterCode[8594] <> " ", {#2}]] <> "U"]&,
                        preamble["Operators"]
                    ]
                ];
                If[ TrueQ[preamble["CenterDot"]],
                    Sow["axiom cdot : U " <> FromCharacterCode[8594] <> " U " <> FromCharacterCode[8594] <> " U"];
                    Sow["infixl:70 \" " <> FromCharacterCode[11037] <> " \" => cdot"]
                ];
                (* Shared constants *)
                If[ KeyExistsQ[preamble, "SharedConstants"],
                    Do[Sow["axiom " <> c <> " : U"], {c, preamble["SharedConstants"]}]
                ];
            ]
        ]
        ,
        {}
    ];
    (* Declarations *)
    declLines = First[
        Last[
            Reap[
                Do[
                    With[{term = data[name]},
                        If[! MatchQ[term, _LeanTerm], Continue[]];
                        With[{
                            kind = Lookup[term[[1]], "Kind", "theorem"],
                            typeExpr = Lookup[term[[1]], "_TypeExpr", None],
                            tactic = Lookup[term[[1]], "_Tactic", None]
                        },
                            If[typeExpr === None, Continue[]];
                            Switch[ kind,
                                "axiom",
                                    Sow["axiom " <> name <> " : " <> leanSource[typeExpr]]
                                ,
                                _,
                                    With[{
                                        tacStr = Which[ 
                                            MatchQ[tactic, _LeanTactic],
                                                tacticSource[tactic]
                                            ,
                                            StringQ[tactic],
                                                tactic
                                            ,
                                            True,
                                                None
                                        ]
                                    },
                                        If[ StringQ[tacStr],
                                            Sow["theorem " <> name <> " : " <> leanSource[typeExpr] <> " := by\n" <> tacStr <> "\n"]
                                            ,
                                            Sow["theorem " <> name <> " : " <> leanSource[typeExpr] <> " := sorry\n"]
                                        ]
                                    ]
                            ]
                        ]
                    ]
                    ,
                    {name, decls}
                ];
            ]
        ]
        ,
        {}
    ];
    (* one blank line between the preamble and the declarations *)
    StringRiffle[Join[preambleLines, If[MatchQ[preambleLines, {___, Except[""]}], {""}, {}], declLines], "\n"]
]

(* Environment with stashed source *)

LeanExportString[env_LeanEnvironment] /; StringQ[Lookup[env[[1]], "_Source", None]] := env[[1]]["_Source"]

(* Generic environment: each constant declared with its type, a theorem as a theorem, an axiom as an
   axiom, and any other constant as a definition, whose body is not reconstructed *)

LeanExportString[env_LeanEnvironment] := With[{constants = environmentConstants[env[[1]]]},
    StringRiffle[
        Join[
            (* a class is declared as a definition here, so an instance binder of one needs this *)
            If[FreeQ[#["Type"]& /@ Values[constants], LeanForall[_, _, _, "instImplicit"] | LeanLam[_, _, _, "instImplicit"]], {}, {"set_option checkBinderAnnotations false"}],
            KeyValueMap[exportedDeclarationSource, KeyTake[constants, declarationOrder[constants]]]
        ],
        "\n\n"
    ]
]

(* the constants in an order where each comes after the constants its type names *)

declarationOrder[constants_Association] := Block[{visited = <||>, order = {}, visit, $RecursionLimit = Max[$RecursionLimit, 4 Length[constants] + 256]},
    visit[name_] := If[ ! KeyExistsQ[visited, name],
        visited[name] = True;
        Scan[visit, Intersection[constantNamesOf[constants[name]["Type"]], Keys[constants]]];
        AppendTo[order, name]
    ];
    Scan[visit, Keys[constants]];
    order
]

exportedDeclarationSource[name_String, term_LeanTerm] := With[{type = leanSource[term["Type"], "Explicit"]},
    Switch[ term["Kind"],
        "theorem",
            "theorem " <> name <> " : " <> type <> " := sorry"
        ,
        "axiom",
            "axiom " <> name <> " : " <> type
        ,
        _,
            "def " <> name <> " : " <> type <> " := sorry"
    ]
]

LeanExportString[term_LeanTerm] := leanSource[term["Type"], "Explicit"]

LeanExportString[expr_] := leanSource[expr]

(* LeanExport -- write to file *)

LeanExport[file_String, env_LeanEnvironment] := Export[file, LeanExportString[env], "Text", CharacterEncoding -> "UTF-8"]

(* Sugar: LeanConst["name"] <-> LeanConst["name", {}] *)

LeanConst[name_String] := LeanConst[name, {}]

(* ---- Lean source ---- *)

(* leanSource[expr] writes an expression as Lean source, each application as it is given, for terms
   built without their implicit arguments, as ProofToLean builds them. leanSource[expr, "Explicit"] writes
   each constant applied with @, for terms imported from Lean, which carry every argument. A bound
   variable is written as the name of its binder, renamed where that name is already taken: by a binder
   around it, by a constant the expression names (a binder Nat would make Nat.succ a field of it), or by
   a keyword. *)

leanSource[expr_] := leanSource[expr, "Surface"]

leanSource[expr_, mode : "Surface" | "Explicit"] := Block[{$sourceMode = mode, $takenNames = If[mode === "Explicit", constantNamesOf[expr], {}]},
    sourceOf[expr, {}]
]

constantNamesOf[expr_] := Union[Flatten[Cases[expr, LeanConst[name_String, _] :> {name, First[StringSplit[name, "."], name]}, {0, Infinity}]]]

$leanKeywords = {
    "at", "by", "calc", "class", "def", "deriving", "do", "else", "end", "example", "fun", "forall", "from",
    "have", "if", "import", "in", "inductive", "instance", "let", "match", "mutual", "namespace", "open", "Prop",
    "return", "section", "show", "Sort", "structure", "suffices", "then", "theorem", "Type", "universe",
    "variable", "where", "with"
}

(* the scope lists the names of the bound variables, innermost first *)

sourceOf[LeanConst[name_String, _List], _] := name

sourceOf[LeanSort[level_], _] := sortSource[level]

sourceOf[LeanBVar[index_Integer], scope_List] := If[index < Length[scope], scope[[index + 1]], "#" <> ToString[index]]

sourceOf[LeanFVar[_], _] := "_fvar"

sourceOf[LeanMVar[_], _] := "_"

(* a kernel term's literal is raw: in source, 0 alone would be OfNat.ofNat 0 again *)

sourceOf[LeanLitNat[n_Integer], _] := If[$sourceMode === "Explicit", "(nat_lit " <> ToString[n] <> ")", ToString[n]]

sourceOf[LeanLitStr[text_String], _] := "\"" <> StringReplace[text, {"\\" -> "\\\\", "\"" -> "\\\"", "\n" -> "\\n", "\t" -> "\\t", "\r" -> "\\r"}] <> "\""

sourceOf[LeanMData[_, expr_], scope_] := sourceOf[expr, scope]

(* Lean numbers the fields of a structure from 1 *)

sourceOf[LeanProj[_, index_Integer, expr_], scope_] := atomSource[expr, scope] <> "." <> ToString[index + 1]

(* @Eq a lhs rhs -> lhs = rhs: the type of lhs gives a *)

sourceOf[LeanApp[LeanApp[LeanApp[LeanConst["Eq", _], _], lhs_], rhs_], scope_] := atomSource[lhs, scope] <> " = " <> atomSource[rhs, scope]

sourceOf[expr_LeanApp, scope_] := Block[{head = expr, arguments = {}},
    While[MatchQ[head, LeanApp[_, _]], PrependTo[arguments, head[[2]]]; head = head[[1]]];
    StringRiffle[Prepend[atomSource[#, scope]& /@ arguments, headSource[head, scope]], " "]
]

(* An arrow is a binder of the default kind that is not needed: in a kernel term, one whose variable the
   body does not use; in a term built by name, one with no name. Other binders are gathered into one ∀. *)

sourceOf[expr : LeanForall[_, _, _, _], scope_] := Block[{binders = {}, body = expr, inner = scope, name, domain, binder, bound},
    While[
        MatchQ[body, LeanForall[_, _, _, _]] && ! arrowBinderQ[body[[1]], body[[3]], body[[4]]]
        ,
        {name, domain, body, binder} = List @@ body;
        bound = binderName[name, inner, body];
        AppendTo[binders, binderSource[bound, sourceOf[domain, inner], binder]];
        inner = Prepend[inner, bound]
    ];
    If[ binders =!= {},
        FromCharacterCode[8704] <> " " <> StringRiffle[binders, " "] <> ", " <> sourceOf[body, inner]
        ,
        arrowDomainSource[body[[2]], inner] <> " " <> FromCharacterCode[8594] <> " " <> sourceOf[body[[3]], Prepend[inner, binderName[body[[1]], inner, body[[3]]]]]
    ]
]

sourceOf[expr : LeanLam[_, _, _, _], scope_] := Block[{binders = {}, body = expr, inner = scope, name, domain, binder, bound},
    While[
        MatchQ[body, LeanLam[_, _, _, _]]
        ,
        {name, domain, body, binder} = List @@ body;
        bound = binderName[name, inner, body];
        AppendTo[binders, binderSource[bound, sourceOf[domain, inner], binder]];
        inner = Prepend[inner, bound]
    ];
    "fun " <> StringRiffle[binders, " "] <> " => " <> sourceOf[body, inner]
]

sourceOf[LeanLet[name_, type_, value_, body_, ___], scope_] := With[{bound = binderName[name, scope, body]},
    "let " <> bound <> " : " <> sourceOf[type, scope] <> " := " <> sourceOf[value, scope] <> "; " <> sourceOf[body, Prepend[scope, bound]]
]

sourceOf[LeanNoValue[], _] := "sorry"

sourceOf[$Failed, _] := "sorry"

sourceOf[other_, _] := "sorry /- " <> ToString[Short[other, 1]] <> " -/"

headSource[head : LeanConst[name_String, _List], scope_] := If[$sourceMode === "Explicit", "@" <> name, name]

headSource[head_, scope_] := atomSource[head, scope]

atomSource[expr_, scope_] := With[{source = sourceOf[expr, scope]}, If[atomicExprQ[expr], source, "(" <> source <> ")"]]

atomicExprQ[LeanMData[_, expr_]] := atomicExprQ[expr]

atomicExprQ[LeanSort[level_]] := MatchQ[level, LeanLevelZero[] | LeanLevelSucc[LeanLevelZero[]]]

atomicExprQ[expr_] := MatchQ[expr, _LeanConst | _LeanBVar | _LeanFVar | _LeanMVar | _LeanLitNat | _LeanLitStr | _LeanProj]

(* an arrow binds less tightly than an application, so only a binder or a let needs parentheses *)

arrowDomainSource[domain_, scope_] := With[{source = sourceOf[domain, scope]},
    If[MatchQ[domain //. LeanMData[_, inner_] :> inner, _LeanForall | _LeanLam | _LeanLet], "(" <> source <> ")", source]
]

binderSource[bound_String, domain_String, "implicit"] := "{" <> bound <> " : " <> domain <> "}"

binderSource[bound_String, domain_String, "strictImplicit"] := FromCharacterCode[10627] <> bound <> " : " <> domain <> FromCharacterCode[10628]

binderSource[bound_String, domain_String, "instImplicit"] := "[" <> bound <> " : " <> domain <> "]"

binderSource[bound_String, domain_String, _] := "(" <> bound <> " : " <> domain <> ")"

(* A term built by name, as ProofToLean builds one, refers to a binder by its name, so a binder that names
   a variable is kept even where no bound variable refers to it, and a binder's name only changes where it
   would hide another binder that a bound variable refers to. In a kernel term every variable is a bound
   variable, and a binder's name also changes where it would hide a constant. *)

binderName[name_, scope_, body_] := freshBinderName[name, scope, body]

arrowBinderQ[name_, body_, binder_] := binder === "default" && ! looseBVarQ[body, 0] && ($sourceMode === "Explicit" || MatchQ[cleanName[name], "" | _?(StringStartsQ["_"])])

(* A name taken by a binder around is only renamed when the body uses that binder's variable, which the
   new name would hide. In body, the variable at position p of the scope has the index p. *)

freshBinderName[name_, scope_List, body_] := Block[{base = binderBaseName[name], candidate, index = 0},
    candidate = base;
    While[
        AnyTrue[Flatten[Position[scope, candidate, {1}]], looseBVarQ[body, #]&] || MemberQ[$takenNames, candidate]
        ,
        index++;
        candidate = base <> "_" <> ToString[index]
    ];
    candidate
]

(* a kernel term's binder name may be hygienic or anonymous; a term built by name keeps its names *)

binderBaseName[name_String] := With[{clean = cleanName[name]},
    If[ $sourceMode =!= "Explicit" && clean =!= "" || StringMatchQ[clean, RegularExpression["[\\p{L}][\\p{L}\\p{N}_'!?\\x{2080}-\\x{209C}]*"]] && ! MemberQ[$leanKeywords, clean],
        clean
        ,
        "x"
    ]
]

binderBaseName[_] := "x"

(* whether expr has the bound variable index, counting the binders inside expr *)

looseBVarQ[LeanBVar[j_Integer], index_] := j === index

looseBVarQ[(LeanForall | LeanLam)[_, domain_, body_, _], index_] := looseBVarQ[domain, index] || looseBVarQ[body, index + 1]

looseBVarQ[LeanLet[_, type_, value_, body_, ___], index_] := looseBVarQ[type, index] || looseBVarQ[value, index] || looseBVarQ[body, index + 1]

looseBVarQ[LeanApp[function_, argument_], index_] := looseBVarQ[function, index] || looseBVarQ[argument, index]

looseBVarQ[(LeanProj | LeanMData)[___, expr_], index_] := looseBVarQ[expr, index]

looseBVarQ[_, _] := False

(* Sort 0 is Prop, Sort (l + 1) is Type l *)

sortSource[LeanLevelZero[]] := "Prop"

sortSource[LeanLevelSucc[LeanLevelZero[]]] := "Type"

sortSource[LeanLevelSucc[level_]] := "Type " <> levelAtomSource[level]

sortSource[level_] := "Sort " <> levelAtomSource[level]

levelSource[LeanLevelZero[]] := "0"

levelSource[level_LeanLevelSucc] := Block[{base = level, steps = 0},
    While[MatchQ[base, _LeanLevelSucc], base = base[[1]]; steps++];
    If[base === LeanLevelZero[], ToString[steps], levelAtomSource[base] <> " + " <> ToString[steps]]
]

levelSource[LeanLevelParam[name_String]] := name

levelSource[LeanLevelMax[a_, b_]] := "max " <> levelAtomSource[a] <> " " <> levelAtomSource[b]

levelSource[LeanLevelIMax[a_, b_]] := "imax " <> levelAtomSource[a] <> " " <> levelAtomSource[b]

levelSource[_] := "_"

levelAtomSource[level_] := With[{source = levelSource[level]}, If[StringContainsQ[source, " "], "(" <> source <> ")", source]]

(* ============================================================================ *)

(* LeanImportString -- compile source string to env                              *)

(* ============================================================================ *)

(* The source's lines end with LF: a Windows editor or checkout gives them
   CRLF, which would reach the stored text and the "Source" of declarations *)

LeanImportString[src_String, opts : OptionsPattern[LeanImport]] /; StringContainsQ[src, "\r"] :=
    LeanImportString[StringReplace[src, {"\r\n" -> "\n", "\r" -> "\n"}], opts]

LeanImportString[src_String, opts : OptionsPattern[LeanImport]] := Block[{tmpFile, modName, result},
    modName = "LeanLinkTmp" <> ToString[$SessionID] <> "x" <> ToString[RandomInteger[10^6]];
    tmpFile = FileNameJoin[{$TemporaryDirectory, modName <> ".lean"}];
    Export[tmpFile, src, "Text", CharacterEncoding -> "UTF-8"];
    result = LeanImport[tmpFile, opts];
    (* Cleanup the .lean source -- olean kept for lazy queries; its text stays for "Source" *)
    If[FileExistsQ[tmpFile], DeleteFile[tmpFile]];
    With[{handle = If[MatchQ[result, _LeanEnvironment], Lookup[result[[1]], "_Handle", None], None]},
        If[IntegerQ[handle] && KeyExistsQ[$handleSource, handle], $handleSource[handle, "Texts"] = <|modName -> src|>]
    ];
    result
]

(* A list of sources is one source, the sources joined with newlines *)

LeanImportString[sources : {___String}, opts : OptionsPattern[LeanImport]] := LeanImportString[StringRiffle[sources, "\n"], opts]

(* --- Local imports of a source file --- *)

(* The folder that a URL import downloads a repository's files into, the root of
   their module names, while it imports one of them *)

$leanImportRoot = None

(* The root of a source file's module name: the nearest folder above it with a
   lakefile, or else its own folder *)

leanFileRoot[absFile_String] := Block[{dir = DirectoryName[absFile]},
    While[
        dir =!= DirectoryName[dir]
        ,
        If[AnyTrue[{"lakefile.lean", "lakefile.toml"}, FileExistsQ[FileNameJoin[{dir, #}]]&], Return[dir, Block]];
        dir = DirectoryName[dir]
    ];
    DirectoryName[absFile]
]

(* A source compiled to an olean, with module names relative to the root and the
   search path pinned. A lean that cannot run fails as a compile does. *)

leanCompile[leanBin_String, olean_String, rootDir_String, source_String, leanPath_String] := Replace[
    RunProcess[{leanBin, "-o", olean, "-R", rootDir, source}, ProcessEnvironment -> Association[GetEnvironment[], "LEAN_PATH" -> leanPath]],
    Except[_Association] :> <|"ExitCode" -> -1, "StandardOutput" -> "", "StandardError" -> "lean could not be run: " <> leanBin|>
]

(* The modules a source imports, as Lean's own parser reads its header, public
   and meta imports included *)

sourceImports[leanBin_String, file_String] := Replace[
    Quiet[ImportString[RunProcess[{leanBin, "--deps-json", file}, "StandardOutput"], "RawJSON"]],
    {
        KeyValuePattern["imports" -> {KeyValuePattern["result" -> KeyValuePattern["imports" -> imports_List]], ___}] :> DeleteDuplicates[Lookup[imports, "module"]],
        _ -> {}
    }
]

(* The .lean file of a module under a root: Foo.Bar is root/Foo/Bar.lean *)

moduleSource[rootDir_String, module_String] := FileNameJoin[Join[{rootDir}, StringSplit[module, "."]]] <> ".lean"

(* The modules with .lean files under the root that a source imports, and those
   they import in turn, each after the ones it imports: {{module, file}, ...}.
   The state is {files seen, modules in order}. *)

localImports[leanBin_String, rootDir_String, file_String] := Last[localImportsFrom[leanBin, rootDir, file, {{file}, {}}]]

localImportsFrom[leanBin_String, rootDir_String, file_String, state_List] := Fold[
    Function[{seen, module},
        With[{source = moduleSource[rootDir, module]},
            If[ ! FileExistsQ[source] || MemberQ[First[seen], source],
                seen
                ,
                With[{after = localImportsFrom[leanBin, rootDir, source, {Append[First[seen], source], Last[seen]}]},
                    {First[after], Append[Last[after], {module, source}]}
                ]
            ]
        ]
    ],
    state,
    sourceImports[leanBin, file]
]

(* Each module of the root that the source imports compiles, after the ones it
   imports, into the folder of the import, so that "import B" finds B.lean next
   to the source. Gives the result of the first compile that fails, with its file,
   or None. *)

failedLocalCompile[leanBin_String, rootDir_String, absFile_String, tmpDir_String, leanPath_String] := Catch[
    Scan[
        Function[{pair},
            With[{olean = FileNameJoin[Join[{tmpDir}, StringSplit[First[pair], "."]]] <> ".olean"},
                If[! DirectoryQ[DirectoryName[olean]], CreateDirectory[DirectoryName[olean]]];
                With[{res = leanCompile[leanBin, olean, rootDir, Last[pair], leanPath]},
                    If[res["ExitCode"] =!= 0, Throw[Append[res, "File" -> Last[pair]], failedLocalCompile]]
                ]
            ]
        ],
        localImports[leanBin, rootDir, absFile]
    ];
    None,
    failedLocalCompile
]

(* --- LeanImport URL support --- *)

(* Convert GitHub blob URL to raw URL *)

githubRawURL[url_String] := StringReplace[url, {"github.com" -> "raw.githubusercontent.com", "/blob/" -> "/"}]

(* Extract the repo base URL and relative path from a GitHub blob URL *)

githubParts[url_String] := Block[{parts},
    parts = StringCases[
        url,
        RegularExpression["https://github\\.com/([^/]+/[^/]+)/blob/([^/]+)/(.+)"] :> {"$1", "$2", "$3"}
    ];
    If[Length[parts] > 0, parts[[1]], None]
]

(* Parse import statements from Lean source, return module names *)

parseImports[src_String] := Flatten @ StringCases[
    src,
    RegularExpression["(?m)^\\s*(?:public\\s+)?(?:meta\\s+)?import\\s+(?:all\\s+)?([^\\n]*?)\\s*(?:--.*)?$"] :> StringCases["$1", RegularExpression["[A-Za-z_][A-Za-z0-9_.']*"]]
]

(* LeanImport[url] -- import from a GitHub URL pointing to a .lean file *)

LeanImport[url_String, opts : OptionsPattern[]] /; StringStartsQ[url, "http://" | "https://"] && StringEndsQ[url, ".lean"] := Block[{
    parts,
    repo,
    branch,
    relPath,
    baseRaw,
    tmpDir,
    downloaded = <||>,
    queue,
    modName,
    content,
    rawURL,
    imports,
    modPath,
    localPath,
    targetFile
},
    parts = githubParts[url];
    If[ parts === None,
        (* Non-GitHub URL: simple download *)
        content = Quiet[Import[githubRawURL[url], "Text"]];
        If[ ! StringQ[content],
            Message[LeanImport::err, "Failed to download: " <> url];
            Return[$Failed, Block]
        ];
        Return[LeanImportString[content], Block]
    ];
    {repo, branch, relPath} = parts;
    baseRaw = "https://raw.githubusercontent.com/" <> repo <> "/" <> branch <> "/";
    (* Create temp project directory *)
    tmpDir = FileNameJoin[
        {
            $TemporaryDirectory,
            "leanlink_url_" <> ToString[$SessionID] <> "_" <> ToString[RandomInteger[10^6]]
        }
    ];
    CreateDirectory[tmpDir];
    (* BFS: download target file and all its imports *)
    queue = {relPath};
    While[
        Length[queue] > 0
        ,
        modPath = First[queue];
        queue = Rest[queue];
        If[KeyExistsQ[downloaded, modPath], Continue[]];
        rawURL = baseRaw <> modPath;
        content = Quiet[Import[rawURL, "Text"]];
        If[! StringQ[content], Continue[]];
        AssociateTo[downloaded, modPath -> content];
        localPath = FileNameJoin[{tmpDir, modPath}];
        With[{dir = DirectoryName[localPath]},
            If[! DirectoryQ[dir], CreateDirectory[dir]]
        ];
        Export[localPath, content, "Text", CharacterEncoding -> "UTF-8"];
        (* Parse imports and queue them *)
        imports = parseImports[content];
        Do[
            With[{impPath = StringReplace[imp, "." -> "/"] <> ".lean"},
                If[! KeyExistsQ[downloaded, impPath], AppendTo[queue, impPath]]
            ]
            ,
            {imp, imports}
        ]
    ];
    (* Compile the target file *)
    targetFile = FileNameJoin[{tmpDir, relPath}];
    If[ ! FileExistsQ[targetFile],
        Message[LeanImport::err, "Failed to download: " <> url];
        Return[$Failed, Block]
    ];
    (* the download folder is the root of the module names; the files the target imports compile first *)
    Block[{$leanImportRoot = tmpDir}, LeanImport[targetFile]]
]

(* ============================================================================ *)

(* Expression head formatting                                                   *)

(* ============================================================================ *)

LeanConst /: MakeBoxes[expr : LeanConst[name_String, levels_List], StandardForm] := iBox[
    expr
    ,
    TooltipBox[
        StyleBox[shortName[name], FontColor -> RGBColor[0.15, 0.35, 0.6], FontWeight -> Bold],
        RowBox[{MakeBoxes[name], " ", MakeBoxes[levels, StandardForm]}]
    ]
]

LeanForall /: MakeBoxes[expr : LeanForall[name_String, dom_, body_, bi_String], StandardForm] := With[{nm = cleanName[name]},
    iBox[
        expr
        ,
        RowBox[
            {
                Switch[ bi,
                    "implicit",
                        RowBox[{"{", StyleBox[nm, FontSlant -> Italic], " : ", MakeBoxes[dom, StandardForm], "}"}]
                    ,
                    "strictImplicit",
                        RowBox[
                            {
                                "\[LeftDoubleBracket]",
                                StyleBox[nm, FontSlant -> Italic],
                                " : ",
                                MakeBoxes[dom, StandardForm],
                                "\[RightDoubleBracket]"
                            }
                        ]
                    ,
                    "instImplicit",
                        RowBox[{"[", StyleBox[nm, FontSlant -> Italic], " : ", MakeBoxes[dom, StandardForm], "]"}]
                    ,
                    _,
                        If[ nm === "" || StringMatchQ[nm, "_" ~~ ___],
                            MakeBoxes[dom, StandardForm]
                            ,
                            RowBox[{"(", StyleBox[nm, FontSlant -> Italic], " : ", MakeBoxes[dom, StandardForm], ")"}]
                        ]
                ]
                ,
                StyleBox[" \[Implies] ", FontColor -> GrayLevel[0.4]]
                ,
                MakeBoxes[body, StandardForm]
            }
        ]
    ]
]

LeanApp /: MakeBoxes[expr : LeanApp[fn_, arg_], StandardForm] := iBox[expr, RowBox[{MakeBoxes[fn, StandardForm], " ", MakeBoxes[arg, StandardForm]}]]

LeanLam /: MakeBoxes[expr : LeanLam[name_String, type_, body_, bi_String], StandardForm] := With[{nm = cleanName[name]},
    iBox[
        expr
        ,
        RowBox[
            {
                StyleBox["fun ", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold]
                ,
                Switch[ bi,
                    "implicit",
                        RowBox[{"{", StyleBox[nm, FontSlant -> Italic], " : ", MakeBoxes[type, StandardForm], "}"}]
                    ,
                    "instImplicit",
                        RowBox[{"[", StyleBox[nm, FontSlant -> Italic], " : ", MakeBoxes[type, StandardForm], "]"}]
                    ,
                    _,
                        RowBox[{"(", StyleBox[nm, FontSlant -> Italic], " : ", MakeBoxes[type, StandardForm], ")"}]
                ]
                ,
                StyleBox[" \[Implies] ", FontColor -> GrayLevel[0.4]]
                ,
                MakeBoxes[body, StandardForm]
            }
        ]
    ]
]

LeanBVar /: MakeBoxes[expr : LeanBVar[idx_Integer], StandardForm] := iBox[
    expr
    ,
    TooltipBox[
        StyleBox["#" <> ToString[idx], FontColor -> GrayLevel[0.5]], RowBox[{"bound var ", MakeBoxes[idx]}]
    ]
]

LeanSort /: MakeBoxes[expr : LeanSort[LeanLevelZero[]], StandardForm] := iBox[expr, StyleBox["Prop", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold]]

LeanSort /: MakeBoxes[expr : LeanSort[LeanLevelSucc[LeanLevelZero[]]], StandardForm] := iBox[expr, StyleBox["Type", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold]]

LeanSort /: MakeBoxes[expr : LeanSort[level_], StandardForm] := iBox[
    expr
    ,
    RowBox[
        {StyleBox["Sort", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold], " ", MakeBoxes[level, StandardForm]}
    ]
]

LeanLitNat /: MakeBoxes[expr : LeanLitNat[n_Integer], StandardForm] := iBox[expr, StyleBox[ToString[n], FontColor -> RGBColor[0.1, 0.5, 0.1]]]

LeanLitStr /: MakeBoxes[expr : LeanLitStr[s_String], StandardForm] := iBox[expr, StyleBox["\"" <> s <> "\"", FontColor -> RGBColor[0.7, 0.3, 0.1]]]

LeanLet /: MakeBoxes[expr : LeanLet[name_String, type_, val_, body_], StandardForm] := With[{nm = cleanName[name]},
    iBox[
        expr
        ,
        RowBox[
            {
                StyleBox["let ", FontColor -> RGBColor[0.6, 0.2, 0.6], Bold],
                StyleBox[nm, FontSlant -> Italic, Bold],
                " : ",
                MakeBoxes[type, StandardForm],
                " := ",
                MakeBoxes[val, StandardForm],
                "; ",
                MakeBoxes[body, StandardForm]
            }
        ]
    ]
]

LeanNoValue /: MakeBoxes[expr : LeanNoValue[], StandardForm] := iBox[expr, StyleBox["\[Dash]", FontColor -> GrayLevel[0.6]]]

LeanTruncated /: MakeBoxes[expr : LeanTruncated[info_], StandardForm] := iBox[
    expr,
    TooltipBox[StyleBox["\[Ellipsis]", FontColor -> GrayLevel[0.5]], MakeBoxes[info, StandardForm]]
]

LeanProj /: MakeBoxes[expr : LeanProj[typeName_, idx_Integer, struct_], StandardForm] := iBox[
    expr,
    RowBox[{MakeBoxes[struct, StandardForm], ".", StyleBox[ToString[idx], FontColor -> GrayLevel[0.5]]}]
]

LeanFVar /: MakeBoxes[expr : LeanFVar[name_], StandardForm] := iBox[
    expr,
    StyleBox[cleanName[ToString[name]], FontColor -> RGBColor[0.4, 0.4, 0.7], FontSlant -> Italic]
]

LeanMVar /: MakeBoxes[expr : LeanMVar[name_], StandardForm] := iBox[
    expr,
    StyleBox["?" <> cleanName[ToString[name]], FontColor -> RGBColor[0.7, 0.4, 0.4], FontSlant -> Italic]
]

(* ============================================================================ *)

(* Level formatting                                                             *)

(* ============================================================================ *)

LeanLevelZero /: MakeBoxes[expr : LeanLevelZero[], StandardForm] := iBox[expr, StyleBox["0", FontColor -> GrayLevel[0.5], FontSize -> 9]]

LeanLevelSucc /: MakeBoxes[expr : LeanLevelSucc[l_], StandardForm] := iBox[
    expr,
    RowBox[{MakeBoxes[l, StandardForm], StyleBox["+1", FontColor -> GrayLevel[0.5], FontSize -> 9]}]
]

LeanLevelMax /: MakeBoxes[expr : LeanLevelMax[a_, b_], StandardForm] := iBox[
    expr
    ,
    RowBox[
        {
            StyleBox["max", FontColor -> GrayLevel[0.5], FontSize -> 9],
            "(",
            MakeBoxes[a, StandardForm],
            ", ",
            MakeBoxes[b, StandardForm],
            ")"
        }
    ]
]

LeanLevelIMax /: MakeBoxes[expr : LeanLevelIMax[a_, b_], StandardForm] := iBox[
    expr
    ,
    RowBox[
        {
            StyleBox["imax", FontColor -> GrayLevel[0.5], FontSize -> 9],
            "(",
            MakeBoxes[a, StandardForm],
            ", ",
            MakeBoxes[b, StandardForm],
            ")"
        }
    ]
]

LeanLevelParam /: MakeBoxes[expr : LeanLevelParam[name_String], StandardForm] := iBox[expr, StyleBox[name, FontColor -> RGBColor[0.4, 0.55, 0.4], FontSlant -> Italic, FontSize -> 9]]

LeanLevelMVar /: MakeBoxes[expr : LeanLevelMVar[name_], StandardForm] := iBox[
    expr,
    StyleBox["?" <> ToString[name], FontColor -> GrayLevel[0.6], FontSlant -> Italic, FontSize -> 9]
]

(* ============================================================================ *)

(* Public API                                                                   *)

(* ============================================================================ *)

LeanLoadEnvironment[imports_List, searchPath_String] := With[{h = loadEnvironment[StringRiffle[imports, ","], searchPath]},
    If[IntegerQ[h], registerHandle[h, imports, searchPath]];
    h
]

(* The olean that an import of a file compiled, in a temporary folder, is deleted
   with its environment *)

LeanFreeEnvironment[handle_Integer] := With[{tmpDir = handleInfo[handle, "TemporaryDirectory"]},
    $freeEnvFn[handle];
    KeyDropFrom[$handleSource, handle];
    $typeFormCache = KeySelect[$typeFormCache, First[#] =!= handle&];
    If[StringQ[tmpDir] && DirectoryQ[tmpDir], Quiet[DeleteDirectory[tmpDir, DeleteContents -> True]]];
    Null
]

(* --- LeanImport --- *)

Options[LeanImport] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Filter" -> "", "IncludeInternal" -> False}

(* Internal name patterns to filter out *)

(* "._@." marks a name with macro scopes, made by hygiene; such a name is not found again from its string *)
$internalPatterns = "_cstage1" | "_cstage2" | "_rarg" | "_sunfold" | "_unsafe_rec" | ".match_" | ".rec" | ".recOn" | ".casesOn" | ".brecOn" | ".binductionOn" | ".below" | ".ibelow" | ".noConfusion" | ".noConfusionType" | "._sizeOf" | ".sizeOf_spec" | ".inj" | ".injEq" | "._@."

isInternalName[name_String] := StringContainsQ[name, $internalPatterns]

(* LeanImport[module, opts] -- shorthand for Imports -> {module} *)

(* If module is a directory of sub-modules (no top-level .olean), auto-discover sub-modules *)

LeanImport[module_String, opts : OptionsPattern[]] /; ! StringContainsQ[module, "/" | "\\"] && ! StringEndsQ[module, ".lean"] := Block[{
    projDir, buildLib, srcDir, oleans, subModules, results = <||>, filter, srcFiles, allNames, grouped
},
    projDir = resolveProjDir[OptionValue["ProjectDir"]];
    (* Lake v5 puts oleans in lib/lean/, v4 uses lib/ *)
    buildLib = With[{
        v5 = FileNameJoin[{projDir, ".lake", "build", "lib", "lean"}],
        v4 = FileNameJoin[{projDir, ".lake", "build", "lib"}]
    },
        If[DirectoryQ[v5], v5, v4]
    ];
    filter = OptionValue["Filter"];
    (* Check if module is a directory of sub-modules *)
    If[ DirectoryQ[buildLib]
    &&
    ! FileExistsQ[FileNameJoin[{buildLib, module <> ".olean"}]]
    &&
    DirectoryQ[FileNameJoin[{buildLib, module}]],
        (* Auto-discover sub-modules from .olean files *)
        oleans = FileNames["*.olean", FileNameJoin[{buildLib, module}], Infinity];
        subModules = oleanModule[#, buildLib]& /@ oleans;
        If[ subModules =!= {},
(* Load ALL discovered sub-modules so the full environment is available.
    
    
    
   Load them individually to avoid module clash failures. *)
            Block[{envAssoc = <||>, handles, kinds},
                handles = First[
                    Last[
                        Reap[
                            Do[
                                With[{h = Quiet[getOrLoadEnv[projDir, {imp}]]},
                                    If[ IntegerQ[h] && h > 0,
                                        Sow[h];
                                        kinds = Quiet[decodeWXF[$listConstantKindsFn[h, filter]]];
                                        If[ AssociationQ[kinds],
                                            If[! TrueQ[OptionValue["IncludeInternal"]], kinds = KeySelect[kinds, ! isInternalName[#]&]];
                                            AssociateTo[
                                                envAssoc
                                                ,
                                                Association @
                                                    KeyValueMap[
                                                        Function[{n, k},
                                                            n -> LeanTerm[<|"Name" -> n, "Kind" -> k, "_Handle" -> h|>]
                                                        ]
                                                        ,
                                                        kinds
                                                    ]
                                            ];
                                        ];
                                    ];
                                ]
                                ,
                                {imp, subModules}
                            ]
                        ]
                    ]
                    ,
                    {}
                ];
                If[Length[envAssoc] === 0, Return[$Failed, Block]];
                results = LeanEnvironment[Append[envAssoc, "_Handle" -> Last[handles]]];
            ];
            Return[results, Block]
        ]
    ];
    LeanImport["Imports" -> {module}, opts]
]

(* LeanImport[file, opts] -- standalone .lean file: compile via lean CLI *)

LeanImport[file_String, opts : OptionsPattern[]] /; FileExistsQ[file] && StringEndsQ[file, ".lean"] := Block[{
    absFile,
    projDir,
    modName,
    tmpDir,
    oleanFile,
    result,
    searchPath,
    tcFile,
    tcName,
    leanBin,
    leanLibDir,
    content,
    names,
    projSearch,
    rootDir,
    leanPath
},
    absFile = ExpandFileName[file];
    projDir = OptionValue["ProjectDir"];
(* If within a lake project, delegate to module-based import 
    *)
    If[ projDir =!= Automatic && insideDirectoryQ[absFile, ExpandFileName[projDir]],
        modName = StringReplace[
            StringTrim[StringDrop[absFile, StringLength[ExpandFileName[projDir]]], "/" | "\\"],
            {".lean" -> "", "/" -> ".", "\\" -> "."}
        ];
        Return[
            LeanImport[
                "Imports" -> {modName},
                "ProjectDir" -> projDir,
                "Filter" -> If[OptionValue["Filter"] === "", modName, OptionValue["Filter"]],
                opts
            ]
            ,
            Module
        ]
    ];
(* A source file outside the project (e.g. a LeanImportString snippet) can still
   import the project's modules: its oleans go on LEAN_PATH for the compile and
   on the search path for the load. Only an explicit ProjectDir does this. *)
    projSearch = If[StringQ[projDir], resolveSearchPath[resolveProjDir[projDir]], ""];
(* Resolve the correct lean binary from the LeanLink project toolchain 
    
    
    *)
(* Try: 1) dev mode Native/lean-toolchain, 2) paclet-bundled lean-toolchain 
    
    
    *)
(* The pinned toolchain the shim was built against comes first: the olean this
   compile writes must match the runtime that loads it. The paclet ships no
   lean-toolchain file, so the fallbacks below reached elan's default
   toolchain, which need not be the pinned one ("incompatible header"). *)
    With[{tc = leanToolchainDir[]},
        If[ tc =!= $Failed,
            leanBin = leanProgram[FileNameJoin[{tc, "bin"}], "lean"];
            leanLibDir = FileNameJoin[{tc, "lib", "lean"}]
            ,
        tcFile = None;
        If[StringQ[$DevProjectRoot], tcFile = FileNameJoin[{$DevProjectRoot, "Native", "lean-toolchain"}]];
        If[ ! FileExistsQ[tcFile],
    (* Paclet-bundled lean-toolchain: in paclet root, cached at load time 
    
    
        *)
            tcFile = FileNameJoin[{$PacletRoot, "lean-toolchain"}]
        ];
        If[ FileExistsQ[tcFile],
            tcName = StringTrim[Import[tcFile, "Text"]];
            tcName = StringReplace[tcName, {"/" -> "--", ":" -> "---"}];
            leanBin = leanProgram[FileNameJoin[{elanHome[], "toolchains", tcName, "bin"}], "lean"];
            leanLibDir = FileNameJoin[{elanHome[], "toolchains", tcName, "lib", "lean"}]
            ,
    (* No toolchain file at all: try elan default, then bare lean 
        *)
            leanBin = leanProgram[FileNameJoin[{elanHome[], "bin"}], "lean"];
            If[! FileExistsQ[leanBin], leanBin = "lean"];
            leanLibDir = Quiet[StringTrim[RunProcess[{leanBin, "--print-libdir"}, "StandardOutput"]]];
            If[ ! StringQ[leanLibDir] || ! DirectoryQ[leanLibDir],
                leanLibDir = FileNameJoin[{DirectoryName[DirectoryName[leanBin]], "lib", "lean"}]
            ]
        ];
        ]
    ];
    (* Standalone file: compile via lean CLI subprocess *)
    modName = FileBaseName[absFile];
    (* a folder of its own: an environment loaded earlier from the same file may still read its olean *)
    tmpDir = CreateDirectory[FileNameJoin[{$TemporaryDirectory, "leanlink_" <> modName <> "_" <> ToString[$SessionID] <> "_" <> CreateUUID[]}]];
    oleanFile = FileNameJoin[{tmpDir, modName <> ".olean"}];
(* Module names are relative to the root: the Lake project around the file, the
   folder a URL import downloads into, or else the file's own folder. *)
    rootDir = If[StringQ[$leanImportRoot], $leanImportRoot, leanFileRoot[absFile]];
(* Pin LEAN_PATH for the compile. The shim sets it process-wide on every
   environment load, so inheriting it would make what this source can import
   depend on whichever environment happened to be loaded last. The folder of the
   import comes first: the .lean files of the root that the source imports compile
   into it before the source does. *)
    leanPath = StringRiffle[DeleteCases[{tmpDir, projSearch, leanLibDir}, ""], $searchPathSeparator];
    result = Replace[
        failedLocalCompile[leanBin, rootDir, absFile, tmpDir, leanPath],
        None :> leanCompile[leanBin, oleanFile, rootDir, absFile, leanPath]
    ];
    If[ result["ExitCode"] =!= 0,
(* lean writes diagnostics to stdout, not stderr; RunProcess decodes them as
   Latin-1, so re-decode as UTF-8 to keep the goal/type text readable. *)
        Message[
            LeanImport::err,
            "lean compilation failed" <> If[KeyExistsQ[result, "File"], " for " <> result["File"], ""] <> ": " <> StringTrim[
                Quiet @ Check[
                    FromCharacterCode[ToCharacterCode[result["StandardOutput"] <> "\n" <> result["StandardError"], "ISO8859-1"], "UTF-8"],
                    result["StandardOutput"] <> "\n" <> result["StandardError"]
                ]
            ]
        ];
        DeleteDirectory[tmpDir, DeleteContents -> True];
        Return[$Failed, Block]
    ];
    (* Load via lazy pattern *)
    searchPath = StringRiffle[DeleteCases[{tmpDir, projSearch, leanLibDir}, ""], $searchPathSeparator];
    Block[{handle, kinds, res},
        handle = loadEnvironment[modName, searchPath];
        If[ handle === 0 || ! IntegerQ[handle],
            Message[LeanImport::err, "Failed to load compiled file"];
            DeleteDirectory[tmpDir, DeleteContents -> True];
            Return[$Failed, Block]
        ];
(* Keep exactly the constants this module declares, read from its own olean
   data. Matching names scraped from the source text missed everything inside
   a namespace (environment names are qualified, the scraped ones were not),
   and anything made by a macro, `private`, or an attribute on the same line. *)
        kinds = decodeWXF[$moduleConstantKindsFn[handle, modName]];
        If[! AssociationQ[kinds], Return[$Failed, Block]];
        If[ ! TrueQ[OptionValue["IncludeInternal"]],
            kinds = KeySelect[kinds, ! isInternalName[#] && ! StringContainsQ[#, "._"]&]
        ];
        (* "Filter" keeps the names that contain it, as for a module *)
        If[ OptionValue["Filter"] =!= "",
            kinds = KeySelect[kinds, StringContainsQ[#, OptionValue["Filter"]]&]
        ];
        registerHandle[handle, {modName}, searchPath];
        $handleSource[handle, "Files"] = <|modName -> absFile|>;
        $handleSource[handle, "TemporaryDirectory"] = tmpDir;
        registerHandleNames[handle, Keys[kinds]];
        (* Build lazy LeanTerms *)
        res = LeanEnvironment[
            Append[
                Association @
                    KeyValueMap[
                        Function[{name, kind},
                            name -> LeanTerm[<|"Name" -> name, "Kind" -> kind, "_Handle" -> handle|>]
                        ]
                        ,
                        kinds
                    ]
                ,
                "_Handle" -> handle
            ]
        ];
        (* Don't delete tmpDir -- olean needed for lazy queries *)
        res
    ]
]

(* a .lean file that is not there *)

LeanImport::nofile = "There is no file `1`."

LeanImport[file_String, OptionsPattern[]] /; StringEndsQ[file, ".lean"] && ! StringStartsQ[file, "http://" | "https://"] && ! FileExistsQ[file] := (
    Message[LeanImport::nofile, file];
    $Failed
)

(* LeanImport[opts] -- base form: instant lazy loading *)

(* When Imports is empty, auto-discover all project modules (like LeanImport[""] would) *)

LeanImport[opts : OptionsPattern[]] := Block[{handle, kinds, imports, projDir},
    If[ $ShimLib === $Failed,
        Message[LeanImport::nolib, $shimFailure];
        Return[$Failed]
    ];
    imports = OptionValue["Imports"];
    projDir = resolveProjDir[OptionValue["ProjectDir"]];
(* Auto-discover all project modules when no imports specified 
    *)
    If[ imports === {},
        Block[{buildLib, oleans, subModules},
            buildLib = With[{
                v5 = FileNameJoin[{projDir, ".lake", "build", "lib", "lean"}],
                v4 = FileNameJoin[{projDir, ".lake", "build", "lib"}]
            },
                If[DirectoryQ[v5], v5, v4]
            ];
            If[ DirectoryQ[buildLib],
                oleans = FileNames["*.olean", buildLib, Infinity];
                subModules = oleanModule[#, buildLib]& /@ oleans;
                If[subModules =!= {}, imports = subModules]
            ]
        ]
    ];
(* If user requested a list of imports, load them together.
   If we auto-discovered them, load them individually to prevent Lean module clash failures 
    
    
    *)
    Block[{
        loadBatches = If[OptionValue["Imports"] === {}, List /@ imports, {imports}],
        envAssoc = <||>,
        handles = {}
    },
        Do[
            With[{h = Quiet[getOrLoadEnv[projDir, batch]]},
                If[ IntegerQ[h] && h > 0,
                    AppendTo[handles, h];
                    kinds = Quiet[decodeWXF[$listConstantKindsFn[h, OptionValue["Filter"]]]];
                    If[ AssociationQ[kinds],
                        If[! TrueQ[OptionValue["IncludeInternal"]], kinds = KeySelect[kinds, ! isInternalName[#]&]];
                        registerHandleNames[h, Keys[kinds]];
(* Build lazy LeanTerms: Name + Kind + _Handle. Each symbol remembers its specific handle! 
    
    
    *)
                        AssociateTo[
                            envAssoc
                            ,
                            Association @
                                KeyValueMap[
                                    Function[{name, kind},
                                        name -> LeanTerm[<|"Name" -> name, "Kind" -> kind, "_Handle" -> h|>]
                                    ]
                                    ,
                                    kinds
                                ]
                        ];
                    ];
                ];
            ]
            ,
            {batch, loadBatches}
        ];
        If[ Length[envAssoc] === 0,
            Message[LeanImport::err, loadFailureText[imports, resolveSearchPath[projDir]]];
            Return[$Failed]
        ];
        LeanEnvironment[Append[envAssoc, "_Handle" -> Last[handles]]]
    ]
]

(* --- Type / Value / ConstantInfo / ListConstants --- *)

Options[LeanExpr] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Depth" -> 100}

LeanExpr[name_String, opts : OptionsPattern[]] := callNative[
    $getTypeFn,
    {name, OptionValue["Depth"]},
    resolveProjDir[OptionValue["ProjectDir"]],
    OptionValue["Imports"],
    LeanExpr
]

Options[LeanValue] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Depth" -> 100}

LeanValue[name_String, opts : OptionsPattern[]] := callNative[
    $getValueFn,
    {name, OptionValue["Depth"]},
    resolveProjDir[OptionValue["ProjectDir"]],
    OptionValue["Imports"],
    LeanValue
]

Options[LeanConstantInfo] = {"ProjectDir" -> Automatic, "Imports" -> {}}

LeanConstantInfo[name_String, opts : OptionsPattern[]] := callNative[$getConstantFn, {name}, resolveProjDir[OptionValue["ProjectDir"]], OptionValue["Imports"], LeanConstantInfo]

Options[LeanListConstants] = {"ProjectDir" -> Automatic, "Imports" -> {}, "Filter" -> ""}

LeanListConstants[opts : OptionsPattern[]] := callNative[
    $listTheoremsFn,
    {OptionValue["Filter"]},
    resolveProjDir[OptionValue["ProjectDir"]],
    OptionValue["Imports"],
    LeanListConstants
]

(* ============================================================================ *)

(* LeanEnvironment -- typed collection of LeanTerms                              *)

(* ============================================================================ *)

(* Property/key access -- env[key] returns LeanTerm with env handle injected *)

LeanEnvironment /: LeanEnvironment[data_Association][key_String] := Block[{val = data[key], handle},
    If[ MatchQ[val, _LeanTerm],
        handle = Lookup[data, "_Handle", None];
        If[IntegerQ[handle], LeanTerm[Append[val[[1]], "_Handle" -> handle]], val]
        ,
        val
    ]
]

(* An environment's constants are its LeanTerm values. Its other keys, such as "_Handle" and "_Source", describe
   it; a constant's own name can start with "_" too, as Lean's private names do. *)

environmentConstants[data_Association] := Select[data, MatchQ[#, _LeanTerm]&]

LeanEnvironment /: Keys[LeanEnvironment[data_Association]] := Keys[environmentConstants[data]]

LeanEnvironment /: Values[LeanEnvironment[data_Association]] := Values[environmentConstants[data]]

LeanEnvironment /: Length[LeanEnvironment[data_Association]] := Length[environmentConstants[data]]

LeanEnvironment /: KeyExistsQ[LeanEnvironment[data_Association], key_] := KeyExistsQ[data, key]

LeanEnvironment /: Normal[LeanEnvironment[data_Association]] := data

(* Information protocol -- no collision with term names *)

$leanEnvProperties = {"Constants", "Kinds", "Handle", "Source", "DeclOrder", "Preamble"}

LeanEnvironment /: Information[env : LeanEnvironment[data_Association], "Properties"] := $leanEnvProperties

LeanEnvironment /: Information[env : LeanEnvironment[data_Association], prop_String] := Switch[ prop,
    "Constants",
        Keys[environmentConstants[data]]
    ,
    "Kinds",
        Counts[Lookup[#[[1]], "Kind", "?"]& /@ Values[environmentConstants[data]]]
    ,
    "Handle",
        Lookup[data, "_Handle", None]
    ,
    "Source",
        Lookup[data, "_Source", None]
    ,
    "DeclOrder",
        Lookup[data, "_DeclOrder", None]
    ,
    "Preamble",
        Lookup[data, "_Preamble", None]
    ,
    _,
        Missing["UnknownProperty", prop]
]

(* MakeBoxes for LeanEnvironment -- summary box *)

LeanEnvironment /: MakeBoxes[obj : LeanEnvironment[data_Association], StandardForm] := Block[{n, kinds, handle, hasSource, icon},
    n = Length[environmentConstants[data]];
    kinds = Counts[Lookup[#[[1]], "Kind", "?"]& /@ Values[environmentConstants[data]]];
    handle = Lookup[data, "_Handle", None];
    hasSource = StringQ[Lookup[data, "_Source", None]];
    icon = Graphics[{Hue[0.6, 0.5, 0.8], Disk[]}, ImageSize -> 12];
    BoxForm`ArrangeSummaryBox[
        LeanEnvironment
        ,
        obj
        ,
        icon
        ,
        {
            BoxForm`SummaryItem[{"Constants: ", n}]
            ,
            If[ Length[kinds] > 0,
                BoxForm`SummaryItem[{"Kinds: ", Row[KeyValueMap[Row[{#2, " ", Style[#1, Gray]}]&, kinds], "  "]}]
                ,
                Nothing
            ]
        }
        ,
        {
            BoxForm`SummaryItem[{"Handle: ", If[IntegerQ[handle], Style[handle, Bold], Style["none", Gray]]}]
            ,
            If[hasSource, BoxForm`SummaryItem[{"Source: ", Style["available", Darker[Green]]}], Nothing]
            ,
            If[ KeyExistsQ[data, "_DeclOrder"],
                BoxForm`SummaryItem[{"Declarations: ", Length[data["_DeclOrder"]]}]
                ,
                Nothing
            ]
        }
        ,
        StandardForm
        ,
        "Interpretable" -> Automatic
    ]
]

(* ============================================================================ *)

(* LeanState -- interactive proof state                                          *)

(* ============================================================================ *)

(* Constructor: LeanState[term_LeanTerm] opens a proof goal *)

LeanState[term_LeanTerm] := Block[{data = term[[1]], handle, name, result, state, tactic, typeExpr},
    handle = Lookup[data, "_Handle", None];
    name = Lookup[data, "Name", ""];
    If[ IntegerQ[handle],
        (* Native path: use Lean runtime *)
        result = Quiet[decodeWXF[$openGoalFn[handle, name]]];
        If[! AssociationQ[result], Return[$Failed]];
        state = LeanState[
            <|
                "stateId" -> result["stateId"],
                "goals" -> (LeanGoal /@ result["goals"]),
                "goalCount" -> result["goalCount"],
                "_Handle" -> handle
            |>
        ];
        (* Auto-apply existing tactic if term has one *)
        tactic = Lookup[data, "_Tactic", None];
        If[MatchQ[tactic, _LeanTactic], state = tactic[state]];
        state
        ,
        (* Pure symbolic path: build state from _TypeExpr *)
        typeExpr = Lookup[data, "_TypeExpr", None];
        tactic = Lookup[data, "_Tactic", None];
        If[typeExpr === None, Return[$Failed]];
        state = LeanState[
            <|
                "stateId" -> 0,
                "goals" -> {LeanGoal[<|"target" -> leanSource[typeExpr], "context" -> {}|>]},
                "goalCount" -> 1,
                "_Symbolic" -> True
            |>
        ];
(* If tactic exists, the proof is known -- mark complete 
    *)
        If[ MatchQ[tactic, _LeanTactic],
            state = LeanState[<|"stateId" -> 0, "goals" -> {}, "goalCount" -> 0, "_Symbolic" -> True, "_Tactic" -> tactic|>]
        ];
        state
    ]
]

(* Constructor: LeanState[env, name] opens a proof goal from env by name *)

LeanState[env_LeanEnvironment, name_String] := Block[{data = env[[1]], handle, compiled, src, term},
    handle = Lookup[data, "_Handle", None];
    If[ ! IntegerQ[handle],
        (* Uncompiled env: auto-compile via string roundtrip *)
        src = Lookup[data, "_Source", None];
        If[! StringQ[src], src = LeanExportString[env]];
        compiled = Quiet[LeanImportString[src]];
        If[! MatchQ[compiled, _LeanEnvironment], Return[$Failed]];
        handle = compiled[[1]]["_Handle"]
    ];
    term = <|"_Handle" -> handle, "Name" -> name|>;
    LeanState[LeanTerm[term]]
]

(* LeanState property access *)

LeanState /: LeanState[data_Association][prop_String] := Switch[ prop,
    "Goals",
        Lookup[data, "goals", {}]
    ,
    "GoalCount",
        Lookup[data, "goalCount", 0]
    ,
    "Complete",
        Lookup[data, "goalCount", 0] === 0
    ,
    "StateId",
        Lookup[data, "stateId", None]
    ,
    _,
        data[prop]
]

(* LeanGoal property access *)

LeanGoal /: LeanGoal[data_Association][prop_String] := Switch[ prop,
    "Target",
        Lookup[data, "target", "?"]
    ,
    "TargetExpr",
        Lookup[data, "targetExpr", None]
    ,
    "Context",
        Lookup[data, "context", {}]
    ,
    _,
        data[prop]
]

(* Helper: a goal target as Lean prints it in the goal's context, which names its free variables;
   leanPP, which cannot, only when the expression is all there is *)

ppGoalTarget[g_Association] := Which[
    StringQ[Lookup[g, "target", None]], g["target"],
    KeyExistsQ[g, "targetExpr"] && ! MatchQ[g["targetExpr"], _String | _Missing], leanPP[g["targetExpr"]],
    True, "?"
]

(* Helper: a context entry type, the same way *)

ppCtxType[entry_Association] := Which[
    StringQ[Lookup[entry, "type", None]], entry["type"],
    KeyExistsQ[entry, "typeExpr"] && ! MatchQ[entry["typeExpr"], _String | _Missing], leanPP[entry["typeExpr"]],
    True, "?"
]

(* MakeBoxes for LeanState *)

LeanState /: MakeBoxes[LeanState[data_Association], StandardForm] := Block[{n = Lookup[data, "goalCount", 0], goals = Lookup[data, "goals", {}]},
    With[{
        display = If[ n === 0,
            Style["\[Checkmark] No goals", Darker[Green], Bold]
            ,
            Column[
                Join[
                    {Style[ToString[n] <> If[n === 1, " goal", " goals"], Gray, Italic]}
                    ,
                    MapIndexed[
                        Block[{g = #1[[1]], idx = #2[[1]], ctx, target},
                            ctx = Lookup[g, "context", {}];
                            target = ppGoalTarget[g];
                            Column[
                                {
                                    If[ Length[ctx] > 0,
                                        Column[(Style[#["name"] <> " : " <> ppCtxType[#], "Input"]& /@ ctx), Spacings -> 0.3]
                                        ,
                                        Nothing
                                    ]
                                    ,
                                    Style[
                                        "\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]",
                                        Gray
                                    ]
                                    ,
                                    Style["\[RightTriangle] " <> target, Bold, "Input"]
                                }
                                ,
                                Spacings -> 0.2
                            ]
                        ]&
                        ,
                        goals
                    ]
                ]
                ,
                Spacings -> 0.8
            ]
        ]
    },
        ToBoxes[Interpretation[display, LeanState[data]]]
    ]
]

(* MakeBoxes for LeanGoal *)

LeanGoal /: MakeBoxes[LeanGoal[data_Association], StandardForm] := Block[{ctx = Lookup[data, "context", {}], target = ppGoalTarget[data]},
    With[{
        display = Column[
            {
                If[ Length[ctx] > 0,
                    Column[(Style[#["name"] <> " : " <> ppCtxType[#], "Input"]& /@ ctx), Spacings -> 0.3]
                    ,
                    Nothing
                ]
                ,
                Style[
                    "\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]\[LongDash]",
                    Gray
                ]
                ,
                Style["\[RightTriangle] " <> target, Bold, "Input"]
            }
            ,
            Spacings -> 0.2
        ]
    },
        ToBoxes[Interpretation[display, LeanGoal[data]]]
    ]
]

(* ============================================================================ *)

(* LeanTactic -- structured tactic objects                                        *)

(* ============================================================================ *)

(* ---- tacticSource: serialize structured LeanTactic -> string ---- *)

tacticSource[LeanTactic["exact", term_]] := "  exact " <> leanSource[term]

tacticSource[LeanTactic["have", name_String, term_]] := "  have " <> name <> " := " <> leanSource[term]

tacticSource[LeanTactic["rw", rules_List]] := "  rw [" <> StringRiffle[rwRuleSource /@ rules, ", "] <> "]"

tacticSource[LeanTactic["rw", rules_List, hyp_String]] := "  rw [" <> StringRiffle[rwRuleSource /@ rules, ", "] <> "] at " <> hyp

tacticSource[LeanTactic["simp", rules_List, None]] := "  simp only [" <> StringRiffle[rwRuleSource /@ rules, ", "] <> "]"

tacticSource[LeanTactic["simp", rules_List, hyp_String]] := "  simp only [" <> StringRiffle[rwRuleSource /@ rules, ", "] <> "] at " <> hyp

tacticSource[LeanTactic["nth_rewrite", n_Integer, rules_List, hyp_String]] := "  nth_rewrite " <> ToString[n] <> " [" <> StringRiffle[leanSource /@ rules, ", "] <> "] at " <> hyp

tacticSource[LeanTactic["conv", hyp_String, path_List, subtac_]] := "  conv at " <> hyp <> " => " <> StringRiffle[path, "; "] <> "; " <> tacticSourceInline[subtac]

tacticSource[LeanTactic["intro", names_List]] := "  intro " <> StringRiffle[names, " "]

tacticSource[LeanTactic["symm", hyp_String]] := "  symm at " <> hyp

tacticSource[LeanTactic["sorry"]] := "  sorry"

(* Inline tactic (no leading whitespace, for conv body) *)

tacticSourceInline[LeanTactic["rw", rules_List]] := "rw [" <> StringRiffle[rwRuleSource /@ rules, ", "] <> "]"

tacticSourceInline[LeanTactic["simp", rules_List]] := "simp only [" <> StringRiffle[rwRuleSource /@ rules, ", "] <> "]"

tacticSourceInline[t_LeanTactic] := StringTrim[tacticSource[t]]

(* Rewrite rule source -- detect Eq.symm wrapping and emit <- *)

rwRuleSource[LeanApp[LeanConst["Eq.symm", _], rule_]] := "\[LeftArrow] " <> leanSource[rule]

rwRuleSource[rule_] := leanSource[rule]

(* Sequence of tactics *)

tacticSource[LeanTactic[tactics_List]] := StringRiffle[tacticSource /@ tactics, "\n"]

(* Fallback: bare string *)

tacticSource[LeanTactic[s_String]] := "  " <> s

tacticSource[s_String] := "  " <> s

(* ---- LeanExportString for structured tactics ---- *)

LeanExportString[tac_LeanTactic] := tacticSource[tac]

(* ---- Apply tactic to state ---- *)

(* String form: LeanTactic["intro P"][state] *)

LeanTactic /: LeanTactic[tac_String][state_LeanState] := applyTacticStr[tac, state]

(* Structured form: LeanTactic["exact", term][state] -- serialize first *)

LeanTactic /: LeanTactic[tag_String, args___][state_LeanState] := applyTacticStr[StringTrim[tacticSource[LeanTactic[tag, args]]], state]

(* Sequence form: LeanTactic[{t1, t2, ...}][state] *)

LeanTactic /: LeanTactic[tactics_List][state_LeanState] := Fold[If[MatchQ[#1, _LeanState], applyTacticLT[#2, #1], #1]&, state, tactics]

(* Internal: apply a single tactic (string or structured) to state *)

$LeanTacticTimeout = 30;(* seconds; override to Infinity to disable *)

applyTacticStr[tac_String, state_LeanState, head_ : LeanTactic] := Block[{data = state[[1]], stateId, handle, result},
    stateId = Lookup[data, "stateId", None];
    handle = Lookup[data, "_Handle", None];
    If[! IntegerQ[stateId], Return[$Failed]];
    result = TimeConstrained[Quiet[decodeWXF[$applyTacticFn[stateId, tac]]], $LeanTacticTimeout, $Aborted];
    If[ result === $Aborted,
        Message[head::abort, "Tactic timed out: " <> tac];
        Return[$Failed]
    ];
    If[ ! AssociationQ[result],
(* The shim reports a failed tactic as an error string ("unsupported tactic: ...",
   a Lean elaboration error). Surface it instead of returning a bare $Failed. *)
        If[StringQ[result], Message[head::err, StringDelete[result, StartOfString ~~ "ERROR: "]]];
        $Failed
        ,
        LeanState[
            <|
                "stateId" -> result["stateId"],
                "goals" -> (LeanGoal /@ result["goals"]),
                "goalCount" -> result["goalCount"],
                "_Handle" -> handle
            |>
        ]
    ]
]

applyTacticLT[tac_LeanTactic, state_LeanState] := applyTacticStr[StringTrim[tacticSource[tac]], state]

applyTacticLT[tac_String, state_LeanState] := applyTacticStr[tac, state]

(* ---- MakeBoxes ---- *)

LeanTactic /: MakeBoxes[LeanTactic[tac_String], StandardForm] := With[{display = Style[tac, "Input"]},
    ToBoxes[Interpretation[display, LeanTactic[tac]]]
]

LeanTactic /: MakeBoxes[t : LeanTactic[tag_String, ___], StandardForm] := With[{display = Style[StringTrim[tacticSource[t]], "Input"]},
    ToBoxes[Interpretation[display, t]]
]

LeanTactic /: MakeBoxes[t : LeanTactic[tactics_List], StandardForm] := With[
    {display = Column[Style[StringTrim[#], "Input"]& /@ (tacticSource /@ tactics), Spacings -> 0.2]},
    ToBoxes[Interpretation[display, t]]
]

(* ============================================================================ *)

(* LeanToFunction / LeanCompile -- Lean defs -> FunctionCompile                   *)

(* ============================================================================ *)

LeanToFunction::notype = "Cannot map Lean type `1` to a compiled WL type."

LeanToFunction::noterm = "Term has no definition body."

LeanToFunction::badexpr = "Cannot translate Lean expression to WL: `1`."

(* ---- Type mapping: Lean type expr -> WL TypeSpecifier string ---- *)

leanTypeToWL[LeanConst["Nat", _List]] := "MachineInteger"

leanTypeToWL[LeanConst["Nat", _List], "Literal"] := "MachineInteger"

leanTypeToWL[LeanConst["Int", _List]] := "Integer64"

leanTypeToWL[LeanConst["Float", _List]] := "Real64"

leanTypeToWL[LeanConst["Bool", _List]] := "Boolean"

leanTypeToWL[LeanConst["String", _List]] := "String"

leanTypeToWL[LeanConst["UInt8", _List]] := "UnsignedInteger8"

leanTypeToWL[LeanConst["UInt16", _List]] := "UnsignedInteger16"

leanTypeToWL[LeanConst["UInt32", _List]] := "UnsignedInteger32"

leanTypeToWL[LeanConst["UInt64", _List]] := "UnsignedInteger64"

(* Parameterized types: Array α, List α → PackedArray *)

leanTypeToWL[LeanApp[LeanConst["Array" | "List", _], elemType_]] := With[{et = leanTypeToWL[elemType]},
    If[FailureQ[et], $Failed, "PackedArray"[et, 1]]
]

(* Vector α n → "Vector"[elemType, size] (dependent) *)

leanTypeToWL[LeanApp[LeanApp[LeanConst["Vector", _], elemType_], sizeExpr_]] := With[{et = leanTypeToWL[elemType]},
    If[ FailureQ[et],
        $Failed
        ,
        With[{sz = leanTypeToWLSize[sizeExpr]},
            "Vector"[et, sz]
        ]
    ]
]

(* Option α → MaybeValue *)

leanTypeToWL[LeanApp[LeanConst["Option", _], elemType_]] := With[{et = leanTypeToWL[elemType]},
    If[FailureQ[et], $Failed, "MaybeValue"[et]]
]

(* Size expression helper: extract literal or variable name from Lean size expr *)

leanTypeToWLSize[LeanLitNat[n_Integer]] := n

leanTypeToWLSize[LeanBVar[i_Integer]] := "n" <> ToString[i]; (* placeholder *)

leanTypeToWLSize[LeanConst[name_String, _]] := name

leanTypeToWLSize[_] := "?"

(* Arrow type: forall _ : A, B  (non-dependent) -> {A'} -> B' *)

leanTypeToWL[LeanForall[name_, dom_, body_, "default"]] := Block[{domTy, bodyTy},
    domTy = leanTypeToWL[dom];
    bodyTy = leanTypeToWL[body];
    If[FailureQ[domTy] || FailureQ[bodyTy], $Failed, {domTy} -> bodyTy]
]

(* Fallback *)

leanTypeToWL[other_] := $Failed

(* Collect all explicit parameter types and return type from a forall chain *)

collectFunctionSignature[type_] := Block[{params, body = type, name, dom, bi, domTy},
    params = First[
        Last[
            Reap[
                While[
                    MatchQ[body, LeanForall[_, _, _, _]]
                    ,
                    {name, dom, body, bi} = List @@ body;
(* Only collect explicit ("default") binders as function params
    *)
                    If[ bi === "default",
                        domTy = leanTypeToWL[dom];
                        If[FailureQ[domTy], Return[$Failed, Block]];
                        Sow[{cleanName[name], domTy}]
                        ,
(* Skip implicit/instance binders -- these are type-level, not runtime 
    
    
    *)
                        Continue[]
                    ]
                ]
            ]
        ]
        ,
        {}
    ];
    With[{retTy = leanTypeToWL[body]},
        If[FailureQ[retTy], $Failed, <|"Params" -> params, "ReturnType" -> retTy|>]
    ]
]

(* ---- Expression translation: Lean term -> WL expression ---- *)

(* a fresh symbol named after a Lean variable, or x for a name that is no symbol name, such as _ *)

freshSymbol[name_] := Unique[Replace[cleanName[name], other : Except[_String ? symbolNameQ] :> "x"]]

symbolNameQ[name_String] := StringMatchQ[name, (LetterCharacter | "$") ~~ (LetterCharacter | DigitCharacter | "$") ...]

(* the last n arguments of an application, translated, or $Failed *)

lastArguments[e_LeanApp, n_Integer, ctx_List] := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= n,
        Replace[leanExprToWL[#, ctx]& /@ Take[args, -n], translated_ /; AnyTrue[translated, FailureQ] -> $Failed]
        ,
        $Failed
    ]
]

(* ctx is a List of variable names, index 0 = last element *)

(* de Bruijn variable lookup -- ctx contains actual symbols *)

leanExprToWL[LeanBVar[i_Integer], ctx_List] := If[i < Length[ctx], ctx[[Length[ctx] - i]], $Failed]

(* Literals *)

leanExprToWL[LeanLitNat[n_Integer], _List] := n

leanExprToWL[LeanLitStr[s_String], _List] := s

(* Named constants -- value-level *)

leanExprToWL[LeanConst["Nat.zero", _], _List] := 0

leanExprToWL[LeanConst["Bool.true", _], _List] := True

leanExprToWL[LeanConst["Bool.false", _], _List] := False

(* Nat.succ n -> n + 1 *)

leanExprToWL[LeanApp[LeanConst["Nat.succ", _], arg_], ctx_List] := With[{a = leanExprToWL[arg, ctx]},
    If[FailureQ[a], $Failed, a + 1]
]

(* OfNat.ofNat -- extract the literal *)

leanExprToWL[e_LeanApp, ctx_List] /; appHeadName[e] === "OfNat.ofNat" && Length[flattenApp[e][[2]]] >= 2 := leanExprToWL[flattenApp[e][[2, 2]], ctx]

(* a decimal literal, mantissa * 10 ^ -exponent or mantissa * 10 ^ exponent: the nearest Float, 0 when it is too
   small for one *)

leanExprToWL[e_LeanApp, ctx_List] /; appHeadName[e] === "Float.ofScientific" || (appHeadName[e] === "OfScientific.ofScientific" && arithmeticType[e] === "Float") :=
    Replace[lastArguments[e, 3, ctx], {
        {mantissa_Integer, negative : True | False, exponent_Integer} :> Quiet[N[mantissa * 10 ^ If[negative, -exponent, exponent]], General::munfl],
        _ -> $Failed
    }]

(* conversions that keep the number: from Nat to Int, and to Float *)

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "Nat.cast" | "NatCast.natCast" | "Int.cast" | "IntCast.intCast"] && MatchQ[arithmeticType[e], "Nat" | "Int"] :=
    Replace[lastArguments[e, 1, ctx], {a_} :> a]

leanExprToWL[e_LeanApp, ctx_List] /; appHeadName[e] === "Int.ofNat" := Replace[lastArguments[e, 1, ctx], {a_} :> a]

(* 1. * a, not N[a], which leaves a variable an integer *)

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "Nat.toFloat" | "Float.ofNat" | "Float.ofInt"] := Replace[lastArguments[e, 1, ctx], {a_} :> 1. * a]

(* Int.negSucc n is -(n + 1); natAbs and toNat give a Nat, toNat 0 for a negative number; pred 0 is 0 *)

leanExprToWL[e_LeanApp, ctx_List] /; appHeadName[e] === "Int.negSucc" := Replace[lastArguments[e, 1, ctx], {a_} :> -a - 1]

leanExprToWL[e_LeanApp, ctx_List] /; appHeadName[e] === "Int.natAbs" := Replace[lastArguments[e, 1, ctx], {a_} :> Abs[a]]

leanExprToWL[e_LeanApp, ctx_List] /; appHeadName[e] === "Int.toNat" := Replace[lastArguments[e, 1, ctx], {a_} :> Max[a, 0]]

leanExprToWL[e_LeanApp, ctx_List] /; appHeadName[e] === "Nat.pred" := Replace[lastArguments[e, 1, ctx], {a_} :> Max[a - 1, 0]]

(* Arithmetic: HAdd.hAdd _ _ _ _ a b -> a + b (last 2 args) *)

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "HAdd.hAdd" | "instHAdd.hAdd"] := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 2,
        With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
            If[FailureQ[a] || FailureQ[b], $Failed, a + b]
        ]
        ,
        $Failed
    ]
]

(* Subtraction, division and remainder compute as Lean's do in the type of the operation, its first argument
   (@HDiv.hDiv Nat Nat Nat inst a b): on Nat, a - b stops at 0; on Nat and Int, dividing by 0 gives 0 and
   the remainder by 0 is a; on Int, / and % are Euclidean, the remainder never negative *)

arithmeticType[e_LeanApp] := Replace[First[flattenApp[e][[2]], None], {LeanConst[name_String, _] :> name, _ -> None}]

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "HSub.hSub" | "instHSub.hSub"] := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 2,
        With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
            If[FailureQ[a] || FailureQ[b], $Failed, If[arithmeticType[e] === "Nat", Max[a - b, 0], a - b]]
        ]
        ,
        $Failed
    ]
]

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "HMul.hMul" | "instHMul.hMul"] := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 2,
        With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
            If[FailureQ[a] || FailureQ[b], $Failed, a * b]
        ]
        ,
        $Failed
    ]
]

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "HDiv.hDiv" | "instHDiv.hDiv"] := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 2,
        With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
            If[ FailureQ[a] || FailureQ[b],
                $Failed
                ,
                Switch[ arithmeticType[e],
                    "Nat",
                        If[b == 0, 0, Quotient[a, b]]
                    ,
                    "Int",
                        If[b == 0, 0, Sign[b] Quotient[a, Abs[b]]]
                    ,
                    "Float",
                        a / b
                    ,
                    _,
                        $Failed
                ]
            ]
        ]
        ,
        $Failed
    ]
]

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "HMod.hMod" | "instHMod.hMod"] := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 2,
        With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
            If[ FailureQ[a] || FailureQ[b],
                $Failed
                ,
                Switch[ arithmeticType[e],
                    "Nat",
                        If[b == 0, a, Mod[a, b]]
                    ,
                    "Int",
                        If[b == 0, a, Mod[a, Abs[b]]]
                    ,
                    _,
                        $Failed
                ]
            ]
        ]
        ,
        $Failed
    ]
]

(* Powers: x ^ 0 is 1, 0 ^ 0 included, as in Lean *)

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "HPow.hPow" | "instHPow.hPow"] := Replace[lastArguments[e, 2, ctx], {
    {a_, b_} :> Replace[arithmeticType[e], {
        "Nat" | "Int" :> If[b == 0, 1, a ^ b],
        "Float" :> If[b == 0, 1., a ^ b],
        _ -> $Failed
    }]
}]

leanExprToWL[e_LeanApp, ctx_List] /; appHeadName[e] === "Max.max" := Replace[lastArguments[e, 2, ctx], {a_, b_} :> Max[a, b]]

leanExprToWL[e_LeanApp, ctx_List] /; appHeadName[e] === "Min.min" := Replace[lastArguments[e, 2, ctx], {a_, b_} :> Min[a, b]]

(* Negation *)

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "Neg.neg" | "HNeg.hNeg" | "instHNeg.hNeg"] := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 1,
        With[{a = leanExprToWL[Last[args], ctx]},
            If[FailureQ[a], $Failed, -a]
        ]
        ,
        $Failed
    ]
]

(* Comparisons: last 2 args *)

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "BEq.beq" | "instBEq.beq" | "Nat.beq" | "instBEqNat.beq"] := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 2,
        With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
            If[FailureQ[a] || FailureQ[b], $Failed, Equal[a, b]]
        ]
        ,
        $Failed
    ]
]

(* a != b, and the proposition a \[NotEqual] b *)

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "bne" | "Ne"] := Replace[lastArguments[e, 2, ctx], {a_, b_} :> Unequal[a, b]]

(* the proposition a = b, as the condition of an if: c = true is c *)

leanExprToWL[e_LeanApp, ctx_List] /; appHeadName[e] === "Eq" := Replace[lastArguments[e, 2, ctx], {
    {a_, True} :> a,
    {a_, False} :> ! a,
    {a_, b_} :> Equal[a, b]
}]

(* the connectives of Bool, and of decidable propositions *)

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "Bool.and" | "and" | "And"] := Replace[lastArguments[e, 2, ctx], {a_, b_} :> a && b]

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "Bool.or" | "or" | "Or"] := Replace[lastArguments[e, 2, ctx], {a_, b_} :> a || b]

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "Bool.xor" | "xor"] := Replace[lastArguments[e, 2, ctx], {a_, b_} :> Xor[a, b]]

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "Bool.not" | "not" | "Not"] := Replace[lastArguments[e, 1, ctx], {a_} :> ! a]

leanExprToWL[e_LeanApp, ctx_List] /; StringEndsQ[Replace[appHeadName[e], None -> ""], ".le" | ".ble"] := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 2,
        With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
            If[FailureQ[a] || FailureQ[b], $Failed, LessEqual[a, b]]
        ]
        ,
        $Failed
    ]
]

leanExprToWL[e_LeanApp, ctx_List] /; StringEndsQ[Replace[appHeadName[e], None -> ""], ".lt" | ".blt"] := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 2,
        With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
            If[FailureQ[a] || FailureQ[b], $Failed, Less[a, b]]
        ]
        ,
        $Failed
    ]
]

(* decide / Decidable.decide -- just pass through to the predicate comparison *)

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "decide" | "Decidable.decide"] := With[{args = flattenApp[e][[2]]},
    If[Length[args] >= 1, leanExprToWL[args[[1]], ctx], $Failed]
]

(* GT.gt -- a > b: last 2 args *)

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "GT.gt" | "instGT.gt"] := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 2,
        With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
            If[FailureQ[a] || FailureQ[b], $Failed, Greater[a, b]]
        ]
        ,
        $Failed
    ]
]

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "GE.ge" | "instGE.ge"] := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 2,
        With[{a = leanExprToWL[args[[-2]], ctx], b = leanExprToWL[args[[-1]], ctx]},
            If[FailureQ[a] || FailureQ[b], $Failed, GreaterEqual[a, b]]
        ]
        ,
        $Failed
    ]
]

(* if-then-else: ite _ cond _ thenBranch elseBranch *)

leanExprToWL[e_LeanApp, ctx_List] /; MatchQ[appHeadName[e], "ite" | "instDecidableIte"] := With[
    {args = flattenApp[e][[2]]}
    ,
(* ite has args: type, cond, decidableInst, thenBranch, elseBranch 
    *)
    If[ Length[args] >= 5,
        With[{
            c = leanExprToWL[args[[2]], ctx],
            t = leanExprToWL[args[[4]], ctx],
            f = leanExprToWL[args[[5]], ctx]
        },
            If[FailureQ[c] || FailureQ[t] || FailureQ[f], $Failed, If[c, t, f]]
        ]
        ,
        $Failed
    ]
]

(* bif c then t else e: cond _ c t e *)

leanExprToWL[e_LeanApp, ctx_List] /; appHeadName[e] === "cond" := Replace[flattenApp[e][[2]], {
    {_, c_, t_, f_} :> Replace[leanExprToWL[#, ctx]& /@ {c, t, f}, {
        translated_ /; AnyTrue[translated, FailureQ] -> $Failed,
        {cWL_, tWL_, fWL_} :> If[cWL, tWL, fWL]
    }],
    _ -> $Failed
}]

(* dite -- decidable if-then-else (dependent): dite type cond inst thenLam elseLam *)

leanExprToWL[e_LeanApp, ctx_List] /; appHeadName[e] === "dite" := With[{args = flattenApp[e][[2]]},
    If[ Length[args] >= 5,
        With[{c = leanExprToWL[args[[2]], ctx]},
            Block[
                {thenBody, elseBody}
                ,
(* thenLam/elseLam are lambdas -- extract body, push dummy name 
    *)
                thenBody = If[ MatchQ[args[[4]], LeanLam[_, _, _, _]],
                    leanExprToWL[args[[4, 3]], Append[ctx, "_h"]]
                    ,
                    leanExprToWL[args[[4]], ctx]
                ];
                elseBody = If[ MatchQ[args[[5]], LeanLam[_, _, _, _]],
                    leanExprToWL[args[[5, 3]], Append[ctx, "_h"]]
                    ,
                    leanExprToWL[args[[5]], ctx]
                ];
                If[FailureQ[c] || FailureQ[thenBody] || FailureQ[elseBody], $Failed, If[c, thenBody, elseBody]]
            ]
        ]
        ,
        $Failed
    ]
]

(* Let binding *)

leanExprToWL[LeanLet[name_String, _, val_, body_], ctx_List] := Block[{sym = freshSymbol[name], v, b},
    v = leanExprToWL[val, ctx];
    b = leanExprToWL[body, Append[ctx, sym]];
    If[ FailureQ[v] || FailureQ[b],
        $Failed
        ,
        (* Build: With[{sym = v}, b] using injection *)
        With[{s = sym, val0 = v, body0 = b},
            Hold[With][Hold[{s = val0}], Hold[body0]] // ReleaseHold
        ]
    ]
]

(* Lambda in body -- nested function *)

leanExprToWL[LeanLam[name_, type_, body_, _], ctx_List] := Block[{sym = freshSymbol[name], tyWL, b},
    tyWL = leanTypeToWL[type];
    b = leanExprToWL[body, Append[ctx, sym]];
    If[FailureQ[tyWL] || FailureQ[b], $Failed, Function @@ {Typed[sym, tyWL], b}]
]

(* MData wrapper -- pass through *)

leanExprToWL[LeanMData[_, expr_], ctx_List] := leanExprToWL[expr, ctx]

(* Generic application fallback -- try to translate head + args *)

leanExprToWL[e_LeanApp, ctx_List] := Block[{head, args, headWL, argsWL},
    {head, args} = flattenApp[e];
    headWL = leanExprToWL[head, ctx];
    argsWL = leanExprToWL[#, ctx]& /@ args;
    If[FailureQ[headWL] || AnyTrue[argsWL, FailureQ], $Failed, headWL @@ argsWL]
]

(* Named constant fallback -- a name that is a symbol name becomes that symbol, any other stays the Lean
   constant; neither compiles, but the structure is kept *)

leanExprToWL[constant : LeanConst[name_String, _], _List] := With[{sn = shortName[name]},
    If[symbolNameQ[sn], Symbol[sn], constant]
]

(* Fallbacks *)

leanExprToWL[LeanNoValue[], _] := $Failed

leanExprToWL[_, _] := $Failed

(* ---- Peel lambda binders from term body, collecting explicit params ---- *)

(* Returns {paramList, body} where paramList = {{sym, wlType}, ...} *)

(* sym is a unique WL symbol created for each param *)

peelLambdas[term_, paramTypes_List] := Block[{params, body = term, name, type, bi, remaining = paramTypes, sym},
    params = First[
        Last[
            Reap[
                While[
                    MatchQ[body, LeanLam[_, _, _, _]] && Length[remaining] > 0
                    ,
                    {name, type, body, bi} = {body[[1]], body[[2]], body[[3]], body[[4]]};
                    If[ bi === "default",
                        sym = freshSymbol[name];
                        Sow[{sym, First[remaining][[2]]}];
                        remaining = Rest[remaining]
                        ,
(* implicit binder -- skip, don't consume from paramTypes
    *)
                        Null
                    ];
                ]
            ]
        ]
        ,
        {}
    ];
    {params, body}
]

(* ---- Main API: LeanToFunction ---- *)

LeanToFunction[term_LeanTerm] := Block[
    {
        data = term[[1]],
        kind,
        typeExpr,
        termExpr,
        sig,
        params,
        lambdaParams,
        body,
        ctx,
        bodyWL,
        argSpecs,
        handle,
        name
    }
    ,
    (* Get type and term *)
    handle = Lookup[data, "_Handle", None];
    name = Lookup[data, "Name", ""];
    typeExpr = term["Type"];
    termExpr = term["Term"];
    If[ MatchQ[typeExpr, _Missing | $Failed],
        Message[LeanToFunction::notype, "(unavailable)"];
        Return[$Failed]
    ];
    If[ MatchQ[termExpr, _Missing | $Failed | LeanNoValue[]],
        Message[LeanToFunction::noterm];
        Return[$Failed]
    ];
    (* Extract function signature from type *)
    sig = collectFunctionSignature[typeExpr];
    If[ FailureQ[sig],
        Message[LeanToFunction::notype, Short[typeExpr]];
        Return[$Failed]
    ];
    params = sig["Params"];
(* Peel lambda binders from term body -- creates unique symbols 
    *)
    {lambdaParams, body} = peelLambdas[termExpr, params];
(* Build variable context: list of actual symbols for de Bruijn resolution 
    
    
    *)
    ctx = lambdaParams[[All, 1]];
    (* Translate body *)
    bodyWL = leanExprToWL[body, ctx];
    If[ FailureQ[bodyWL],
        Message[LeanToFunction::badexpr, Short[body]];
        Return[$Failed]
    ];
    (* Build Function[{Typed[sym, "Type"], ...}, body] *)
    argSpecs = Typed[#[[1]], #[[2]]]& /@ lambdaParams;
    If[Length[argSpecs] === 1, Function @@ {argSpecs[[1]], bodyWL}, Function @@ {argSpecs, bodyWL}]
]

(* ---- LeanCompile: convenience for FunctionCompile ---- *)

LeanCompile[term_LeanTerm] := Block[{fn = LeanToFunction[term]},
    If[FailureQ[fn], $Failed, FunctionCompile[fn]]
]

LeanCompile[env_LeanEnvironment] := Block[{data = env[[1]], names, results = <||>},
    names = Keys[environmentConstants[data]];
    Do[
        With[{term = env[name]},
            If[ MatchQ[term, _LeanTerm],
                With[{cf = Quiet[LeanCompile[term]]},
                    If[MatchQ[cf, _CompiledCodeFunction], AssociateTo[results, name -> cf]]
                ]
            ]
        ]
        ,
        {name, names}
    ];
    results
]

End[];

EndPackage[];
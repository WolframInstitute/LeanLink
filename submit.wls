#!/usr/bin/env wolframscript
(* Submit the Wolfram/LeanLink paclet to the Wolfram Paclet Repository.

   The submission artifact is LeanLink/ResourceDefinition.nb, generated from
   docs/ResourceDefinition.md by build_docs.wls - edit the markdown and
   rebuild before submitting, never the notebook.

   LeanLink is a LibraryLink paclet: the kernel loads
   LibraryResources/$SystemID/libLeanLinkShim from the installed paclet, so a
   submission missing those binaries installs cleanly and then fails at the
   first Lean call. They are build artifacts (gitignored), so a clean checkout
   has none - build them with ./build.sh before submitting. This script refuses
   to submit without them, and warns when one is older than the shim source.

   Run with:

       wolframscript -f submit.wls
*)

repoDir = DirectoryName[$InputFileName]

nbFile = FileNameJoin[{repoDir, "LeanLink", "ResourceDefinition.nb"}]

If[ ! FileExistsQ[nbFile],
    Print["FATAL: ", nbFile, " does not exist; run build_docs.wls first."];
    Exit[1]
]

(* ---- native libraries: present, and newer than the source they were built from ---- *)

shimSource = FileNameJoin[{repoDir, "Native", "shim", "leanlink_shim.c"}]

libs = FileNames["libLeanLinkShim.*",
    FileNameJoin[{repoDir, "LeanLink", "LibraryResources"}], 2]

If[ libs === {},
    Print["FATAL: no LibraryResources/*/libLeanLinkShim.* found; run ./build.sh first."];
    Exit[1]
]

Print["native libraries:"]
Scan[
    Print["  ", FileNameTake[DirectoryName[#]], "  ",
        DateString[FileDate[#], {"ISODate", " ", "Hour", ":", "Minute"}]] &,
    Sort[libs]
]

stale = If[FileExistsQ[shimSource], Select[libs, FileDate[#] < FileDate[shimSource] &], {}]

If[ stale =!= {},
    Print["WARNING: built before the current shim source, so they carry whatever bug it fixed:"];
    Scan[Print["  ", FileNameTake[DirectoryName[#]]] &, Sort[stale]];
    Print["  rebuild with ./build.sh (cross-compiles every platform) to ship the fix."]
]

(* ---- never ship the provisioned Lean runtime ----
   Loading the dev paclet (tests, doc builds) links libleanshared and its
   siblings from the local elan toolchain next to each shim. They are symlinks
   into ~/.elan, and the submission packs them dereferenced: that is how 1.0.9
   shipped a 155 MB Mac ARM64 runtime to every platform. The runtime is
   provisioned on the user's machine at load, so strip it here, before the file
   tree below is refreshed - that tree is what gets packed. *)

runtime = FileNames[{"libleanshared*", "libInit_shared*", "libLake_shared*"},
    FileNameJoin[{repoDir, "LeanLink", "LibraryResources"}], 2]

If[ runtime =!= {},
    Print["stripping the provisioned Lean runtime from LibraryResources (", Length[runtime], " files)"];
    Scan[DeleteFile, runtime]
]

Needs["DefinitionNotebookClient`"]

(* ---- repair the paclet file tree before validating ----
   MarkdownToNotebook writes the file-manager tree with CellID -> 0 on every
   cell, and the repository scraper keys file entries by CellID, so the whole
   tree collapses to one entry and the check fails with NoPacletInfoFileCell.
   The entries also store paths relative to the notebook, resolved through
   NotebookDirectory, which needs a saved notebook. So: turn on CreateCellID
   so regenerated cells get real ids, save, rebuild the tree from the paclet
   directory, and save again. The repair lands in the .nb on disk, so the
   check and submission below (which each reopen the file) see valid cells. *)

Needs["PacletResource`DefinitionNotebook`"]

UsingFrontEnd @ Block[{nb},
    nb = NotebookOpen[nbFile, Visible -> False];
    SetOptions[nb, CreateCellID -> True];
    NotebookSave[nb];
    PacletResource`DefinitionNotebook`RefreshNotebookPacletFiles[nb];
    NotebookSave[nb];
    NotebookClose[nb]
]

(* Submit as an account authorized for this paclet's PublisherID - the repository
   rejects anyone else ("You are not authorized to use the given PublisherID"),
   and a kernel carrying a cached connection from other work will happily try as
   the wrong identity. WOLFRAM_ID / WOLFRAM_PASSWORD override it explicitly. *)
With[{id = Environment["WOLFRAM_ID"], pw = Environment["WOLFRAM_PASSWORD"]},
    If[ StringQ[id] && id =!= $WolframID, CloudDisconnect[]];
    If[ ! TrueQ[$CloudConnected],
        If[ StringQ[id] && StringQ[pw], CloudConnect[id, pw],
            If[StringQ[id], CloudConnect[id], CloudConnect[]]]]
]

If[ ! TrueQ[$CloudConnected],
    Print["FATAL: not cloud connected."];
    Exit[1]
]

Print["submitting as ", $WolframID,
    " (publisher ", Lookup[PacletObject[File[FileNameJoin[{repoDir, "LeanLink"}]]]["PacletInfo"], "PublisherID", "?"], ")"]

(* The pre-submission check first: a submission with outstanding errors is
   rejected by the repository anyway, so failing here is strictly cheaper.
   Suggestions (such as PacletFilesChanged after a rebuild) do not block. *)

check = UsingFrontEnd @ Block[{nb, r},
    nb = NotebookOpen[nbFile, Visible -> False];
    r = DefinitionNotebookClient`CheckDefinitionNotebook[nb];
    NotebookClose[nb];
    r
]

issues = Normal[check]

Scan[Print["  [", #Level, "] ", #Tag] &, issues]

If[ MemberQ[issues[[All, "Level"]], "Error"],
    Print["FATAL: the definition notebook has errors; fix them before submitting."];
    Exit[1]
]

result = UsingFrontEnd @ Block[{nb, r, DefinitionNotebookClient`ConfirmIssuesDialog = (True &)},
    nb = NotebookOpen[nbFile, Visible -> False];
    r = DefinitionNotebookClient`SubmitRepository[nb];
    NotebookClose[nb];
    r
]

submission = FirstCase[result, _Success, Missing["NotFound"], Infinity]

If[ MatchQ[submission, _Success],
    Print["submitted:"];
    KeyValueMap[Print["  ", #1, ": ", #2] &, KeyDrop[Last[submission], "Message"]],
    Print["SUBMISSION DID NOT SUCCEED:"];
    Print[result];
    Exit[1]
]

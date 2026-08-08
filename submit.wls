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

Needs["DefinitionNotebookClient`"]

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

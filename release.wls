#!/usr/bin/env wolframscript
(* Publish LeanLink's documentation site with PacletPage, in one run: build the
   documentation (as build_docs.wls does), build the paclet archive without the
   Lean runtime and check that it loads alone in a fresh kernel, deploy the paclet
   resource, publish the site around it with its feedback form, and check the site
   as an anonymous reader sees it:

       https://www.wolframcloud.com/obj/wolframinstitute/LeanLink

   Publishing needs a kernel connected as $siteAccount (see pacletpage.wl).
   WOLFRAM_ID / WOLFRAM_PASSWORD connect it explicitly, as for submit.wls;
   otherwise the cached login is used, and the script stops before building
   anything if that is another account. A dry run deploys nothing and runs under
   any login, or none; as $siteAccount it also reports what the release checks
   would say. The documentation is built and checked
   first, as build_docs.wls does, so a page that would render unevaluated is
   never deployed. The Paclet Repository submission is separate: submit.wls.

       wl -f release.wls [--no-cache]   build, deploy and publish
       wl -f release.wls --dry-run      build and check the documentation and the
                                        archive; deploy nothing
       wl -f release.wls --republish    replace the deployed release of this same
                                        version, which PacletPage otherwise refuses
                                        once it was published from another commit,
                                        as after a documentation-only fix
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "pacletpage.wl"}]]

dryRun = MemberQ[$ScriptCommandLine, "--dry-run"]

With[{id = Environment["WOLFRAM_ID"], pw = Environment["WOLFRAM_PASSWORD"]},
    If[StringQ[id] && id =!= $WolframID, CloudDisconnect[]];
    If[! TrueQ[$CloudConnected] && (StringQ[id] || ! dryRun), If[StringQ[id] && StringQ[pw], CloudConnect[id, pw], If[StringQ[id], CloudConnect[id], CloudConnect[]]]]
]

Print["PacletPage ", loadPacletPage[], If[dryRun, ", dry run", ", publishing as " <> ToString[$WolframID]]]

If[ ! dryRun && $WolframID =!= $siteAccount,
    Print["FATAL: publishing needs a kernel connected as ", $siteAccount, " (WOLFRAM_ID / WOLFRAM_PASSWORD); this one is connected as ", $WolframID, ". Nothing was built or published."];
    Exit[1]
]

buildDocumentation[]

result = PublishPacletPage[
    $leanlinkDir,
    "LeanLink",
    "Build" -> False,
    "DryRun" -> dryRun,
    "Account" -> $siteAccount,
    "ResourceOptions" -> If[MemberQ[$ScriptCommandLine, "--republish"], Append[$resourceOptions, "Republish" -> True], $resourceOptions],
    "SiteOptions" -> $siteOptions
]

If[ ! AssociationQ[result],
    Print["FATAL: PublishPacletPage failed", If[FailureQ[result], ": " <> result["Message"], ""]];
    Exit[1]
]

With[{res = result["Resource"]},
    Print["archive: ", res["Archive"], " (", res["ArchiveSize"], "), loads alone: ", TrueQ[res["Load", "OK"]]];
    Print["resource: ", res["Resource"], If[dryRun, " (dry run: not deployed)", ""]];
    If[! TrueQ[res["Load", "OK"]], Exit[1]]
]

If[AssociationQ[result["Site"]], Print["site: ", result["Site", "Site"]]]

If[ AssociationQ[result["Check"]],
    Print["check: ", If[TrueQ[result["Check", "OK"]], "OK", "FAILED " <> ToString[Lookup[result["Check"], "Failed", {}], InputForm]]];
    If[! TrueQ[result["Check", "OK"]], Exit[1]]
]

Print["done"]

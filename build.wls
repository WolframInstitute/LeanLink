#!/usr/bin/env wolframscript
(* ::Package:: *)

(* Build the LeanLink paclet, install it locally, and deploy its resource page
   publicly to the Wolfram Cloud - the scripted equivalent of the
   "Deploy -> Publicly in the cloud" button in LeanLink/ResourceDefinition.nb.

   Prerequisites: a Wolfram Cloud connection and a built ResourceDefinition.nb
   (run build_docs.wls first). Prints the public resource-page URL on success.

   Usage: wl -f build.wls *)

root = DirectoryName[$InputFileName]

name = "LeanLink"

pacletDir = FileNameJoin[{root, name}]

defNb = FileNameJoin[{pacletDir, "ResourceDefinition.nb"}]

(* Register the dev paclet so PacletObject["Wolfram/LeanLink"] resolves (by name
   for the archive, and relative to the definition notebook for the scrape). *)

PacletDirectoryLoad[pacletDir]

pacletFile = CreatePacletArchive[pacletDir]

Print[StringTemplate["Paclet `` has size ``"][pacletFile, FileSize[pacletFile]]]

PacletInstall[pacletFile, ForceVersionInstall -> True]

If[ ! FileExistsQ[defNb],
    Print["ResourceDefinition.nb not found - run build_docs.wls first."];
    Exit[1]
]

If[ ! $CloudConnected,
    With[{user = Environment["WOLFRAM_CLOUD_USER"], pass = Environment["WOLFRAM_CLOUD_PASSWORD"]},
        If[StringQ[user] && StringQ[pass], CloudConnect[user, pass], CloudConnect[]]
    ]
]

If[ ! $CloudConnected,
    Print[
        "Wolfram Cloud connection failed - set WOLFRAM_CLOUD_USER and WOLFRAM_CLOUD_PASSWORD for non-interactive (CI) use."
    ];
    Exit[1]
]

Needs["DefinitionNotebookClient`"]

Needs["PacletResource`DefinitionNotebook`"]

(* Headless equivalent of the "Deploy -> Publicly in the cloud" button: scrape
   the definition notebook with Interactive -> False (the default Interactive ->
   True pops a confirmation dialog, which returns $Canceled under wolframscript)
   and CloudDeploy the resource publicly to the location the button computes,
   <account>/DeployedResources/Paclet/<url-encoded resource name>.

   Open the notebook in place with NotebookOpen, NOT OpenTemporaryNotebook or
   File[defNb]: the definition notebook references the paclet relative to its own
   directory, so it must stay next to the paclet for that reference to resolve. *)

result = UsingFrontEnd @
    TimeConstrained[
        Enclose
        @
        Module[{nbo},
            nbo = ConfirmMatch[NotebookOpen[defNb, Visible -> False], _NotebookObject, "Opening the definition notebook failed."];
(* Warm up paclet resolution before scraping; on a freshly opened
   notebook the lookup misses until PacletObject and ScrapePacletDirectory
   have each run once. *)
            PacletObject["Wolfram/" <> name];
            Quiet[PacletResource`DefinitionNotebook`ScrapePacletDirectory[nbo]];
            WithCleanup[
                Module[{res, co},
                    res = ConfirmMatch[
                        DefinitionNotebookClient`ScrapeResource["Paclet", nbo, Interactive -> False, "FailureCondition" -> "Error"],
                        _ResourceObject,
                        "Scraping the resource from the definition notebook failed."
                    ];
                    co = CloudObject["DeployedResources/Paclet/" <> URLEncode[res["Name"]]];
                    With[{obj = CloudDeploy[res, co, Permissions -> "Public"]},
                        ResourceRegister[res, "Cloud", "StoreContent" -> False];
                        obj
                    ]
                ]
                ,
                NotebookClose[nbo]
            ]
        ]
        ,
        420
        ,
        $TimedOut
    ]

url = FirstCase[{result}, c_CloudObject :> First[c], Missing[], Infinity]

If[ MissingQ[url],
    url = FirstCase[{result}, s_String /; StringContainsQ[s, "wolframcloud.com"], Missing[], Infinity]
]

If[ MissingQ[url],
    If[ FailureQ[result],
        Print["Deploy failed: ", result["Message"]]
        ,
        Print["Deploy did not return a URL. Result: ", result]
    ];
    Exit[1]
    ,
    Print["published: ", url];
    Exit[0]
]
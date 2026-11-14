# LeanLink's tests by kernel

Each test file in a kernel process of its own, by `coverage/kernel_column.sh`, which prints these rows:

```
coverage/kernel_column.sh "wolframscript -file"
coverage/kernel_column.sh "$HOME/Library/Wolfram/ApplicationData/WolframKernel/bin/wl -f"
```

Run on macOS ARM64 under a 2 GB cap on the process tree, with LeanLink 1.2.14, TypeTheory 0.46.0 and Lean v4.35.0.
`Evaluation.wlt`, `NativeAPI.wlt` and `SharedImports.wlt` need more than 2 GB (2.4 GB, 5.0 GB and over 2 GB on
Wolfram 15.0) and are not in the default list.

| Kernel | File | Passed | Time | Peak memory |
|---|---|---|---|---|
| Wolfram 15.0.0 (May 19, 2026) | TypeTheoryBridge.wlt | 37/37 | 37 s | 1.22 GB |
| Wolfram 15.0.0 (May 19, 2026) | EvaluationStartup.wlt | 13/13 | 9 s | 1.79 GB |
| Wolfram 15.0.0 (May 19, 2026) | EvaluationTransport.wlt | 8/8 | 4 s | 0.27 GB |
| WolframKernel 0.0.6 9302d155 (November 14, 2026) | TypeTheoryBridge.wlt | 37/37 | 58 s | 1.68 GB to over 2 GB |
| WolframKernel 0.0.6 9302d155 (November 14, 2026) | EvaluationStartup.wlt | 13/13 | 7 s | 1.72 GB to over 2 GB |
| WolframKernel 0.0.6 9302d155 (November 14, 2026) | EvaluationTransport.wlt | 7/8 | 73 s | 0.61 GB |

Notes on WolframKernel 0.0.6 9302d155:

- `EvaluationTransport-FragmentedUnicodeReply` fails: `ImportString[string, "RawJSON"]` does not decode a string of
  UTF-8 bytes, as Wolfram 15.0 does, so `ImportString["[\"" <> FromCharacterCode[{206, 177}] <> "\"]", "RawJSON"]`
  gives the two bytes for `{"α"}`.
- `EvaluationTransport-ReplyLargerThanPipeBuffer` takes 70 s of the file's 73: `ImportString` of a JSON list of
  50,000 integers takes 4.4 s, against 0.006 s, and grows with the square of the length.
- Its peak varies from run to run: the bridge suite reached 1.68 GB, 1.88 GB and the 2 GB cap in three runs, and
  `EvaluationStartup.wlt` 1.72 GB, 1.78 GB and the cap.

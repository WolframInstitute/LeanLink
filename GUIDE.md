# LeanLink WL style guide

Conventions for the LeanLink paclet sources: kernel packages
(`LeanLink/Kernel/*.wl`), runner / build scripts (`*.wls`), test specs
(`LeanLink/Tests/*.wlt`), and the LibraryLink C bridge
(`Native/shim/*.c`). Adapted from the THVM WL guide. The rules at the top
are non-negotiable; the rest are conventions that keep code readable and
consistent with the IDE auto-formatter. For the documentation sources
under `docs/`, see [docs/DOC_GUIDE.md](docs/DOC_GUIDE.md).

## Formatting

This style is produced mechanically by `CodeFormatter`CodeFormat` with a set of
compact-multiline options. Format a source file with:

```wl
Needs["CodeFormatter`"]

CodeFormat[Import["LeanLink/Kernel/Lean.wl", "Text"],
    "BreakLinesMethod" -> "LineBreakerV2",
    "LineWidth" -> 100,
    "KeepBindingsInline" -> True,
    "SpaceAfterControlOpener" -> True,
    "GlueAssignmentRHS" -> True,
    "TrailingCommas" -> True,
    "InlineShortControl" -> True,
    "SpaceAfterPrefixNot" -> True,
    "SpaceAroundPatternOperators" -> True
]
```

`LineBreakerV2` breaks a group all-or-nothing (one element per line, never a
mid-expression wrap). The options keep a scoping binding list / control
condition on the opener line when only the body is wide; add the `If[ ` space;
keep an assignment RHS on the operator line (`f := Block[{`); keep the comma at
the end of a single-line element; leave a short control structure inline
(`If[a, b, c]`); space a prefix Not (`! cond`); and space the pattern operators
(`x_ ? NumericQ`). The rest of this guide describes the resulting conventions so
they can be followed (and reviewed) by hand.

These options are not in the released CodeFormatter; they come from
[WolframResearch/codeformatter#7](https://github.com/WolframResearch/codeformatter/pull/7).
A patched build is installed locally as **CodeFormatter 1.14** (with CodeParser
bumped to 1.14 so the version-match check passes), so a plain
`Needs["CodeFormatter`"]` picks it up. To reinstall it after a Wolfram update,
copy the bundled paclet, overlay `Kernel/CodeFormatter.wl` and
`Kernel/Indent.wl` from that branch, bump `Version` in `PacletInfo.wl`, then
`CreatePacletArchive` + `PacletInstall` (do the same version bump for
CodeParser).

## Rules the user has explicitly called out

These are non-negotiable. Strip on sight.

### No em dashes (`-`, U+2014)

Don't write em dashes in source files, docs, comments, or commit
messages. Use a plain hyphen (`-`), a colon, or a sentence break.

### No Unicode box-drawing characters

Don't use box-drawing chars (the U+2500 family) as visual section
banners in comments. Use plain ASCII:

```c
// === lifecycle ===     // good
// --- lifecycle ---     // good
```

Same applies in `.wl` (`(* === lifecycle === *)`) and `.md`
(`## Lifecycle`).

### No decorative Unicode arrows in source

Use `->` (or `>` in shell prompt strings) instead of decorative
`\[Rule]`-glyph arrows, `\[LeftArrow]`, etc. in comments and ordinary
code. ASCII-only in source files unless the character carries meaning.

**LeanLink exception - Lean-notation Unicode is semantic.** LeanLink's
pretty-printer and `MakeBoxes` deliberately emit Lean's surface syntax -
`\[ForAll]`, `\[Lambda]`, the Lean arrow, `\[And]`, `\[Or]`, `\[Not]`,
`\[TurnstileLeft]`, Greek type variables - in the `"TypeForm"` /
`"TermForm"` output strings and in the displayed boxes of [LeanForall](),
[LeanLam](), [LeanSort](), and the rest. Those glyphs *are* the Lean
notation; they carry meaning and must NOT be ASCII-ified. The arrow rule
above is about decorative arrows in comments and control flow, not the
Lean output the package is designed to produce.

### Dark mode + Standard colors

Always design WL output (the expression / call graphs) for both light and
dark Wolfram themes from the start.

- Use **Standard color names** (`StandardBlue`, `StandardRed`,
  `StandardGreen`, `StandardOrange`, `StandardYellow`, `StandardPurple`,
  `StandardGray`) instead of `RGBColor[...]` or `Darker[Blue, 0.4]`. They
  read correctly on light and dark backgrounds.
- Use `LightDarkSwitched[lightValue, darkValue]` when a value (color,
  opacity, thickness) genuinely needs to differ between modes. Avoid
  hard-coded `White`/`Black` for `Background`, `FaceForm`, etc.
- Don't unconditionally pin `Background -> White` on a `Graph` or
  `Graphics`. If a static PNG export needs an explicit background, set it
  on the `Export` call, not on the graph. ([ImportDOT]() already routes
  its node and edge colors through `LightDarkSwitched`; new graph code
  should match.)

## Indentation and spacing

- 4-space indentation. Never 2.
- Spaces around infix operators and pattern tests: `t_ ? NumericQ`,
  not `t_?NumericQ`.
- Prefer structural indentation over column alignment.
- One semantic unit per line in long forms (`Which`, `Switch`,
  `Association`, `Table`, option lists).
- For multi-line `If`, put a space after the opening bracket so the
  test argument lines up with the branches:

  ```wolfram
  If[ Length[dirs] === 0,
      Print["no examples to run"];
      Exit[1]
  ]
  ```

  Single-line `If[cond, then, else]` does not need the leading space.

### Never split a binary operator's operands across lines

Operators (`+`, `-`, `*`, `/`, `.`, `&&`, `||`, etc.) must have both
operands on the same line. The Wolfram IDE flags split operands as
`DifferentLine`. Keep the whole arithmetic chain on one line, or factor
an intermediate into a named binding first.

### Optional arguments

For functions that take Wolfram-style options, use
`opts : OptionsPattern[]`, not `opts___ ? OptionQ`. The former integrates
with `Options[fn]` declarations and `OptionValue[fn, key]`, the canonical
pattern (and the one [LeanImport](), [LeanExprGraph](), and the rest of
the option-taking API already use).

```wolfram
Options[myFn] = {"ProjectDir" -> Automatic};

myFn[args___, opts : OptionsPattern[]] :=
    With[{dir = OptionValue["ProjectDir"]},
        ...
    ]
```

### Boolean options: `TrueQ[OptionValue[...]]`

Wrap boolean options in `TrueQ` so non-`True` values (unbound symbols,
typos, `Automatic`) collapse to `False` instead of propagating into `If`
as an unevaluated test.

```wolfram
(* GOOD *)
If[ TrueQ[OptionValue["IncludeInternal"]], ..., ...]
```

### First option wins - forced overrides go FIRST

When a wrapper forces certain options on the inner call but lets the user
pass extras through, put the forced overrides FIRST and the user's
filtered options LATER. Wolfram functions take the FIRST setting on
collision. Don't `/. (Key -> _) -> Nothing` to scrub user options - just
place the forced override first.

## Definitions

Prefer `Block` for local workspaces unless `Module`'s unique-symbol
guarantee is actually required. Don't add a trailing `;` to a top-level
assignment - `SetDelayed` (`:=`) AND `Set` (`=`). Each definition is a
complete expression; line breaks separate them.

The `Block`/`Module` variable list opens on the same line as the head
(`Block[{`), bindings are indented one level deeper, and `}`, body, and
the closing `]` return to the column where the line that opens `Block[`
starts.

## Control flow

### No `For` loops

Don't write `For[i = 1, i <= n, i++, ...]`. Use `Do[body, {i, n}]` for
side effects with a counter, `Table[expr, {i, n}]` to build a list, or
`Nest` / `Fold` / `FoldList` when threading iterative state.

### `Replace` over `Switch` for value-to-value mapping

When the cases are simple value patterns mapping to values (no structural
tests, no side effects), `Replace` with a rule list reads as data, not
control flow. Use `Switch` / `Which` when branches have side effects,
dispatch on richer patterns, or need a fallthrough `_`.

### Comma-on-own-line between multi-line branches

When the branches of `If` (or args of `Block`, `Switch`, `With`) are each
multi-line, put the separating commas on their own line at the head's
indent column, so the comma reads as a branch boundary. Short branches
keep commas inline.

### No `Head[expr] === Foo` - use `MatchQ`

`Head[x] === Foo` is a structural test that doesn't compose with
patterns. `MatchQ[x, _Foo]` (or `MatchQ[x, Foo[args...]]` for a shape
check) is the canonical form. This matters across the CIC heads -
`MatchQ[e, _LeanForall]` over `Head[e] === LeanForall`.

```wolfram
(* BAD *)
If[ Head[e] === LeanApp, ...]

(* GOOD *)
If[ MatchQ[e, _LeanApp], ...]
```

## Mutation

### No `AppendTo` (or other list-growing mutation)

Don't grow a list with `AppendTo`/`PrependTo` inside a loop -
`AppendTo[xs, y]` copies on every step. Build the result with `Table`,
`Map`, or `Fold` so the final list is allocated once. The same goes for
incrementally building an `Association`: use `AssociationMap`,
`Association[Table[...]]`, or `Fold[Append, <||>, kvPairs]` rather than
`assoc[k] = v` inside a `Do`.

### Bracket alignment

A closing `]` (or `}`, `|>`, `)`) is in exactly one of two places:

1. **On the same line** as its content, when the whole call fits on one
   line (and there is no line-length limit forcing a break - see below), or
2. **On its own line**, indented to the column of the *first letter* of the
   opening head - under the `f` of `func[`, not under the `[`.

Never end a multi-line form with `...]` dangling on the last expression's
line, and never put a closing `]` at some other random indent.

```wolfram
(* GOOD: fits, so the ]s close on the same line *)
res["ExitCode"] =!= 0 && StringLength[res["StandardOutput"]] > 0

(* GOOD: multi-line, each ] under the head's first letter *)
Module[{x, y},
    body1;
    body2
]

(* BAD: width-wrapped mid-expression, ] floating *)
res["ExitCode"] =!= 0 && StringLength[res["StandardOutput"
    ]]
```

### No line-length limit

Do not break an expression across lines to satisfy a character budget -
there is no column limit. A line breaks only for a *structural* reason
(one statement per line in a `CompoundExpression`, one branch/case per line
in `If` / `Switch` / `Which`, one binding per line in a long option or
`Association` list), never merely because it grew wide. The IDE formatter is
configured with `"LineWidth" -> Infinity` for this paclet; keep that whole
expressions stay on one line and only structure introduces newlines.

## Composition

### `@` chain for unary right-application

For chains of unary calls, prefer `f @ g @ h[x]` over `f[g[h[x]]]`. Use
`[]` only where you need multiple args.

### `Lookup` is vectorized; prefer it over `Map[Lookup, ...]`

`Lookup[assoc, listOfKeys, default]` returns a list of values in key
order. Use it directly when feeding a list-shaped slot.

### Don't name single-use intermediates

If a value is read exactly once, inline it. Exception: name it when the
expression is long enough that the named form reads better, or when the
name carries domain meaning the inline expression doesn't.

## Naming

- Public symbols: `CamelCase` (e.g. `LeanImport`, `LeanForall`,
  `LeanState`).
- Internal helpers: `lowerCamelCase` (e.g. `runLean`, `decodeUTF8`,
  `extractDOT`).
- Don't prefix internal helpers with `i...`.

## Tests

Use `VerificationTest` from the standard testing framework. Test specs
live in `LeanLink/Tests/*.wlt`; the runner is `run_tests.wls`.

```wolfram
VerificationTest[
    expression,
    expectedOutput,
    TestID -> "human-readable id"
]
```

Don't put `Print` inside test bodies. The runner reports outcomes via
`TestReport`.

## File structure

When practical, organize a `.wl` file in this order:

1. Short file comment if needed.
2. `BeginPackage` declarations and public `::usage` strings.
3. `Begin["`Private`"]`.
4. Small general helpers.
5. Domain-specific helpers.
6. Main entry-point definitions near the end.
7. `End[]; EndPackage[];`

`LeanLink/Kernel/LeanLink.wl` is the entry point (the context
`Wolfram``LeanLink``` resolves to it); it `Get`s `Utilities.wl`,
`Lean.wl`, `ProofToLean.wl`, and `Compiler.wl` in dependency order.

## Comments

- Comment non-obvious behavior, quirks, or external-format constraints
  (LibraryLink calling conventions, the WXF wire format, paclet layout,
  de Bruijn index handling, native handle lifetimes).
- Don't narrate obvious code.
- Prefer one short section comment over many tiny inline comments.

## Native handles

A [LeanEnvironment](), [LeanState](), and [LeanGoal]() each carry a native
handle (an integer `_Handle` / `stateId`) into the Lean runtime held open
by the shim. Handles are valid for the life of the kernel session.
Document any function that allocates a handle ([LeanLoadEnvironment]()) or
frees one ([LeanFreeEnvironment]()), and pair allocation with release.

## CSource (LibraryLink bridge)

The `Native/shim/*.c` bridge exposes the embedded Lean runtime to the
kernel through LibraryLink. It exchanges structured data (environments,
expression trees, goal states) as **WXF byte buffers** rather than a
field-per-argument C surface: the Lean side (`Native/lib/LeanLink/`)
serializes to WXF, the shim hands the buffer across the LibraryLink
boundary, and the kernel deserializes. Keep the C surface small - a
handful of exported `EXTERN_C DLLEXPORT int <name>(...)` entry points that
move buffers and integer handles - and synthesize the higher-level,
name-binding constructors on the WL side. This keeps the bridge testable
and the wire format in one place.

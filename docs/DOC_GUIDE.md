# LeanLink documentation guide

How to write the LeanLink documentation sources under `docs/` - the
`Template: Symbol` reference pages, the `Template: Guide` guide, and the
`Template: TechNote` tutorials. They are literate-markdown files that
[`build_docs.wls`](../build_docs.wls) turns into evaluated Wolfram notebooks via
`MarkdownToNotebook` (MTN), landing under `LeanLink/Documentation/English/`.
This is the house style. It is adapted from the WolframParser doc guide and
overrides the upstream
[wolfram-symbol-page skill](https://github.com/sw1sh/MarkdownToNotebook/blob/main/skills/wolfram-symbol-page/SKILL.md)
where they disagree (noted inline).

## Build and inspect, always

Every page is a *twin*: the `.md` source and the evaluated `.nb` that MTN
builds from it. A page is not done until you have **built it and read back
every output cell**. Run the build with the `wl` CLI (not `wolframscript` -
its init can wedge kernels):

```
wl -f build_docs.wls
```

`build_docs.wls` auto-discovers every `docs/**/*.md`, so a new file builds with
no wiring. It uses the **deployed** MarkdownToNotebook cloud resource
(`ResourceFunction["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]`),
not a local copy - so the build needs cloud access. The `<!-- => ... -->` hint
after a cell is **author-facing only** - MTN strips HTML comments before
evaluating, so a hint is never checked against the real output. That is exactly
why you must read the built `.nb` back: the hint records what you *expect*, the
build produces what is *real*. Probe each example against the live paclet first
and paste the real result into the hint - a wrong hint is worse than none. To
iterate on one page without rebuilding the whole set, bind
`mtn = ResourceFunction["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]`
and call `mtn[src, out, "EvaluateSeparator" -> None]` on it directly.

## The native bridge must be live

Unlike a pure-kernel paclet, almost every LeanLink example calls into the Lean
runtime through a compiled LibraryLink shim. The build only works where:

- the platform dylib is present under
  `LeanLink/LibraryResources/<platform>/` (built by `build.sh`), and
- `elan` / `lake` are on `PATH` for any example that shells out to Lean
  ([LeanImport]() with a `"ProjectDir"`, [LeanExprGraph](), [LeanCallGraph]()).

[LeanImportString]() and the bundled `Examples.lean` environment work from the
dylib alone; the Mathlib pages additionally need a **built** mathlib4 checkout
(see *Gate the heavy examples*). If the shim is missing the build will fail loudly
rather than emit blank cells - that is intended.

## State threads across sections - `EvaluateSeparator -> None`

This is the one rule that **inverts** the upstream skill. `build_docs.wls`
builds every page with `"EvaluateSeparator" -> None`, so the per-heading context
reset is **off**: a [LeanEnvironment]() imported in `## Part 1` is still bound in
`## Part 5`. Pages may - and the tutorials do - carry one environment across
sections. Import an environment once near the top, then query it section by
section. Do not redundantly re-import in each section, and do not reuse a name
for two different environments across sections (the later binding wins for the
whole notebook).

A practical consequence: a native [LeanEnvironment]() handle stays valid for the
life of one kernel, and importing a *second* environment does not invalidate the
first - so a tutorial that imports `env`, then later imports `mathlibEnv`, then
refers back to `env`, is fine.

## Symbols are autolinked, never bare backticks

Every symbol - **built-in ([FunctionCompile](), [Graph](), [Dataset](),
[Association](), [Failure]()) and paclet ([LeanImport](), [LeanState](),
[LeanTactic](), [LeanForall]())** - is a link, never a backticked code word.

- A bare mention is the inferred-link form `[LeanState]()` (empty parens; the
  converter resolves it to the ref page). Built-ins take the same form:
  `[FunctionCompile]()`, `[Dataset]()`.
- An inline *call* is code-styled **and** autolinked: write
  <code>[LeanTactic]()[*tac*][*state*]</code>, not `` `LeanTactic[tac][state]` ``
  and not plain `[LeanTactic]()`. Markdown forbids nested formatting inside a
  backtick span but processes markdown inside an inline `<code>` element, so the
  link renders inside the code style.
- Backticks are only for things that are *not* symbols: a **constant / theorem
  name** (`"mul_comm"`, `"id_proof"`, `"Nat.succ"`), a **binder kind**
  (`"explicit"`, `"implicit"`, `"instance"`), an **option value**
  (`"ProjectDir"`, `"Filter"`), a **tactic string** (`"intro P"`,
  `"exact h"`), a **Lean source fragment** (`∀ (P : Prop), P → P`), or a **path**
  (`LeanLink/Assets/`).
- If you link a paclet symbol that has no `docs/Symbols/<Name>.md` page,
  **create the page** in the same pass, so the link resolves.

## Argument names are italics, not math

In a `## Usage` signature and in prose, write argument names in *italics*:
<code>[LeanImport]()[*module*]</code>, <code>[LeanTerm]()[*assoc*]</code>. **Do
not** use the `$x$` math form - it renders as ugly inline LaTeX. (This overrides
the skill, which uses `$x_i$`.) Genuine mathematics in prose - a proposition
like $\forall P : \mathrm{Prop},\; P \to P$ in a tutorial heading - stays in
`$...$`; that is math, not an argument name.

## Cells: no ceremony, one output each

- **No `Needs`.** MTN loads the package from the frontmatter `Context:`
  (`Context: Wolfram``LeanLink```) before it evaluates the cells, so an example
  never needs <code>Needs["Wolfram``LeanLink```"]</code>.
- **One output per cell.** Never show `{t["TypeForm"], t["TermForm"]}` to save a
  cell - split into two, each with its own caption.
- **Show the summary box, not its guts.** [LeanTerm](), [LeanEnvironment](),
  [LeanState](), and [LeanGoal]() each render as a summary box (icon + key
  fields). Display the object itself where the box aids the reader; do not reach
  into `term[[1]]` to pull out the raw [Association]().
- **Lean AST renders as Lean.** The expression heads ([LeanForall](),
  [LeanApp](), [LeanConst](), [LeanSort](), ...) carry box formatting, so
  `env["id_proof"]["Type"]` displays in Lean-source notation
  (`∀ (P : Prop), P → P`), not as raw `LeanForall[...]`. Show the expression; let
  the formatting do the work.

## Output that round-trips

- **Strings** - the `"TypeForm"` / `"TermForm"` pretty-prints, tactic strings,
  exported source - and **numbers**, **lists**, **[Failure]() objects**, the
  **Lean AST heads**, and the **summary boxes** all serialize and render in the
  `.nb`.
- A **bare [Association]()** (`<|...|>`) does *not* render cleanly; project it
  with [Dataset]() (the natural display for `["Parameters"]`) or [Normal]() /
  [Keys]() when you only need the shape.
- **Unicode is expected.** Lean output is full of `∀ λ → ↦ α ℕ ⊢ ¬ ∧ ∨`. These
  round-trip fine and are correct - do not "ASCII-ify" them in a hint or caption.
  (This is Lean's surface syntax, distinct from the WL *source* rule below.)
- **de Bruijn fallbacks.** A type shown in isolation - a single row of
  `["Parameters"]`, or [LeanExportString]() of a bare term - can print an
  unresolved bound variable as `#0` / `#1`. The full-theorem `"TypeForm"` resolves
  names cleanly, so prefer it when you want a readable type.

## WL source style inside cells

The code in a `wl` cell is real source and follows the
[Wolfram style guide](https://github.com/sw1sh/MarkdownToNotebook/blob/main/GUIDE.md):
no em dashes or `--` in comments, no decorative Unicode arrows (`->`, not `→`) in
WL code, and Standard color names / `LightDarkSwitched` for any graphics so an
output reads on both themes. The graph-producing examples ([ExprGraph](),
[CallGraph](), [LeanCallGraph]()) must not pin `Background -> White`.

## Headless rasterization caveat

A headless `wl` session **cannot rasterize** typeset boxes - `Rasterize` of a
`RawBoxes` / `Style` expression comes back all white. `build_docs.wls` pins the
front end to Light so the graph outputs that *do* rasterize (the Lean expression
and call graphs) are not inverted. If a page needs to show a typeset rendering,
verify it by exporting a PDF and converting with `sips`, not by `Rasterize`.

## Gate the heavy examples

Some examples need resources that may be absent on a given machine. Gate them so
the build degrades to an explanatory string instead of an error:

- **Mathlib** pages need a built mathlib4 checkout. Guard on the build dir and
  fall back to a one-line "run `lake exe cache get && lake build ...`" message,
  the pattern the [Exploring Mathlib](Tutorials/ExploringMathlib.md) tutorial
  uses. Never hardcode an absolute home path in a way that errors when it is
  missing.
- **Slow scans** (the [Import Graph](Tutorials/ImportGraph.md) tutorial walks
  ~5000 files) are fine in a tutorial but keep them out of `## Basic Examples`
  on a Symbol page.

## Deferred: the compiler-backed pages

[LeanCompile](), [LeanToFunction](), and [LeanCompileTyped]() lower a Lean term
to a [FunctionCompile]() function. The **dependent-type** path (`TypePi`,
Vector-sized signatures) needs a *forked* Wolfram compiler (`TypePi.m`,
`TypeSort.m`, ...) reached through the `compiler` symlink. Where that fork is
absent the dependent path cannot be verified, so:

- The non-dependent examples *are* verifiable - `LeanCompile` of a
  `Nat -> Nat -> Nat` definition compiles and runs - and belong on those Symbol
  pages now.
- The **Dependent Types** and **Turing Machine** tutorials are **deferred** until
  the fork is present on the build machine; do not ship unverified output for
  them. (If you have the fork, build them and drop this note.)

## Page shape

- **Frontmatter**: `Template`, `Name`, `Context`, `Paclet`, `URI` (the `ref/`,
  `guide/`, or `tutorial/` path; the basename must match the URI tail),
  `Keywords`, and - for a Symbol page - `SeeAlso` and `RelatedGuides`.
- **Symbol page** (`Template: Symbol`): `## Usage` (the signature, one statement
  per paragraph), `## Details & Options` (bullets become Notes), then
  `## Basic Examples` / `## Scope` / `## Properties and Relations` /
  `## Possible Issues` / `## Neat Examples` as warranted. Model a primary-API
  page on [Symbols/LeanImport.md](Symbols/LeanImport.md) or
  [Symbols/LeanTactic.md](Symbols/LeanTactic.md); a one-line AST constructor on
  [Symbols/LeanApp.md](Symbols/LeanApp.md).
- **Guide** (`Template: Guide`): an `## Abstract`, then `## Functions` as a list
  of `[Symbol]() one-line description` items under `### Subheadings`. Keep it
  curated, not exhaustive. Model on [Guides/LeanLink.md](Guides/LeanLink.md).
- **Tutorial** (`Template: TechNote`): one running environment carried deep
  across sections with real prose, like
  [Tutorials/LeanLinkIntro.md](Tutorials/LeanLinkIntro.md). Because state
  threads, import the environment once near the top and query it section by
  section.

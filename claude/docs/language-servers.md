# Language-server (LSP) tooling

Captures what's known so far about using Language Server Protocol servers in the
Claude Code harness, and the per-language decisions and open questions. The goal
that prompted this: **richer code comprehension for the agent** (resolve symbols
precisely instead of reading whole files or grepping). It also records how the
Python static-analysis stack (the mypy type gate and ruff lint) divides the
work, since those decisions are entangled with the LSP question. Written from
research in mid-2026; version-sensitive claims are flagged and should be
re-checked.

## Two distinct jobs — don't conflate them

An LSP could do either of two unrelated jobs; keeping them separate is what
makes the tooling choices clear:

- **The gate (diagnostics):** _is this changeset correct?_ Today this is mypy on
  a Stop hook (batch run, output piped to the agent). It works and is staying as
  the sole authority. Ruff covers lint/format on its own hooks.
- **Navigation (comprehension):** _where is this defined / used, what's its type
  here?_ — go-to-definition, find-references, hover, symbol search. This is the
  only reason to add an LSP; mypy was never doing this job.

**The overlap to manage:** a checker-style LSP (pyright) _also_ emits
diagnostics, which would duplicate the mypy gate. The fix lives at the
**server-config layer**, not the harness: either use a server that isn't a type
checker (jedi emits no type diagnostics by nature) or configure the checker to
emit none (pyright `typeCheckingMode: "off"` keeps navigation, drops
diagnostics). mypy stays the gate either way. (Verify the navigation-only
behavior when wiring; see TODOs.)

## The static-analysis stack: ruff lint vs. the type gate

The gate is two complementary tools occupying different domains, so they don't
fight:

- **mypy** owns the type system (types match, None-safety, signatures). No lint.
- **ruff lint** (`ruff check`) owns everything else — bug patterns, dead code,
  style, import order, syntax modernization. It does no type checking; ruff
  defers types to mypy/pyright by design.

Both run on the Stop hook (`ruff-format.sh` → `quiet-ruff.sh` runs
`ruff check --fix` _and_ `ruff format`; mypy runs separately). So ruff lint is
already enabled — ruff is a linter as much as a formatter. The rule set lives in
`~/.config/ruff/pyproject.toml` (source of truth). The only overlaps with mypy
(F821 undefined-name, F401 unused-import) _agree_ — no conflict. The genuine
"two tools fighting" risk is running mypy _and_ a second type checker (pyright);
ruff + mypy is the canonical non-conflicting pair.

The specific rule selection — and the rationale for each enabled rule and each
ignore — is documented inline in `~/.config/ruff/pyproject.toml`.

## Claude Code's LSP integration (harness mechanics)

- **Navigation IS model-accessible.** The `LSP` tool exposes go-to-definition,
  find-references, type-at-point (hover), list/search symbols, find-
  implementations, and call-hierarchy as operations the model can call. So the
  comprehension goal is reachable — not hypothetical. GA (per research, since
  the v2.0.x line; treat the exact version/date as directional).
- **The model decides when to use it** — there is no user-facing knob to force
  LSP over grep, and the invocation API isn't publicly documented. Realized
  benefit therefore depends on the model actually reaching for it (grep is the
  default reflex), and may run below the theoretical benefit.
- **Diagnostics are auto-pushed.** When a server is configured, Claude Code
  surfaces its diagnostics after each edit, automatically. There is no
  documented harness-level switch to disable them — hence managing overlap at
  the server layer (above).
- **Configuration is plugin-scoped via `.lsp.json`.** Official plugins (pyright,
  typescript-lsp, rust-analyzer-lsp, gopls, …) install via `/plugin install` and
  are already cached locally. Other servers need a custom `.lsp.json` at a
  plugin root pointing at a locally-installed binary. There is no standalone
  global `~/.claude/.lsp.json`; per-project setup means a project-level plugin.

## Is it worth it? (scale assessment)

LSP-navigation payoff scales with codebase size and import/type interconnection
— the community evidence is about 50k+ line codebases. Measured against two
representative projects:

- **crosswords** — ~7.9k lines across 39 Python files (largest 777). At this
  size grep suffices ~80%+ of the time; names are mostly unique and files are
  well-named. The genuine LSP win is narrow: **find-references before a
  refactor** of a widely-used symbol (grep can't enumerate call sites with
  confidence), plus occasional name disambiguation and call-chain tracing.
- **google-photos-deduper** — **1** Python file, but **87 TS/TSX files**. This
  is where navigation actually pays: heavy cross-file imports and types, where
  grep gets noisy.

**Conclusion:** for Python at this scale the payoff is marginal — not worth a
tooling migration. The real navigation case in the portfolio is **TypeScript**,
and (later) Rust. Frame any LSP-navigation investment as a general/polyglot
capability with TS as the first real proving ground, not as a Python fix.

## Per-language status

### Python

- **Gate:** mypy on the Stop hook — keep as the sole authority. Decision: **do
  not migrate to pyright** (the earlier "migrate mypy → pyright" framing was a
  gate swap chasing a navigation goal mypy never owned).
- **Navigation (if/when added):** in preference order for this use case —
  - **jedi-language-server** — pure Python, no Node, navigation-only by nature
    (no diagnostics to suppress, no mypy overlap). Cleanest fit;
    inference-based, so slightly less precise than pyright on hard cases.
  - **basedpyright** with `typeCheckingMode: off` — PyPI-native (no Node),
    Pylance-grade navigation. The precision upgrade if jedi proves too loose.
  - **pyright** (official plugin) — easiest install but needs Node and must have
    diagnostics suppressed via config to avoid duplicating mypy.
- **Verdict:** marginal at current scale; defer until a Python project grows or
  TS/Rust navigation is being set up anyway.

#### mypy-vs-pyright context (durable, from prior research)

**What the conformance numbers mean.** The typing-conformance suite measures
fidelity to the typing _specification_ (generics, protocols, overloads,
narrowing, newer PEPs) — not how many real bugs a checker catches. mypy's lower
score (~60% vs pyright ~97%) is dominated by advanced/edge features; on everyday
fully-annotated code both catch what matters (wrong arg types, None-safety, bad
returns). Crucially, mypy is _not_ the spec authority — it's the original and
most-established checker, but the spec (Typing Council) is the authority and
pyright tracks it more closely. So a low score reads as "less spec-faithful and
slower," not "poor at finding your bugs." The differences that do show in
practice: pyright has stronger flow narrowing (catches some bugs mypy misses)
and is much faster, with a different false-positive profile.

Why mypy was a defensible starting choice and isn't strictly worse:

- mypy: the original, most-established checker (not the spec authority),
  behaviorally stable (infrequent, announced changes), pure-Python/no-Node,
  plugin system (Django, SQLAlchemy), most-documented error codes; `dmypy`
  daemon exists if speed ever matters.
- pyright downsides beyond the usual three (Node dep / stricter default / no
  plugins): stricter inference yields real false positives mypy never emits;
  weekly releases occasionally regress (a checker's verdict can change on
  unchanged code between versions); the open-source server is a thinner LSP than
  the closed Pylance everyone praises; the PyPI `pyright` wrapper fetches Node
  at runtime via `nodeenv` (flaky in CI/sandboxes); typeshed stubs are tuned to
  mypy, so dynamic frameworks throw more pyright false positives with no plugin
  escape hatch.
- For in-turn diagnostics specifically: mypy has a viable path (`pylsp-mypy`
  over `dmypy`, or `dmypy-ls`) at on-save granularity — so "I want in-turn
  feedback" would not by itself justify switching checkers.
- New Rust-based Python checkers on the radar (maturity as of mid-2026): pyrefly
  (Meta, stable 1.0, fast, ships a mypy-config migration preset — the most
  mature), ty (Astral — same family as ruff/uv, beta, diagnostics still
  unstable), zuban (mypy-compatible, high conformance, newer). Conformance
  scores vary by source and move fast — directional only.

### JavaScript / TypeScript

- `typescript-lsp` official plugin is cached locally.
- **The strongest navigation case in the portfolio** (deduper: 87 TS/TSX files).
- This is the recommended first proving ground for agent-navigation LSP, before
  investing in Python or Rust.
- Not yet researched in depth (see TODOs).

### Rust

- `rust-analyzer-lsp` official plugin is cached locally; watch its memory use on
  larger projects.
- No Rust project exists yet (the first is expected before long); revisit when
  it starts. Note: a separate `rules/rust.md` style-rules task is tracked
  independently of LSP setup.
- Not yet researched in depth (see TODOs).

## Open TODOs (context needed before deciding on TS / Rust / ruff-LSP)

- **TS:** `tsserver` is Node-based (TS is JavaScript), so Node is effectively
  unavoidable for TS navigation — unlike Python. Confirm. Also: does enabling
  `typescript-lsp` duplicate the deduper's existing `tsc`/eslint/vitest
  diagnostics, and can it run navigation-only? Is the plugin's tsserver version
  pinnable?
- **Rust:** rust-analyzer's memory footprint on real projects; whether it
  duplicates `cargo check` diagnostics; the setup story when the first Rust
  project lands.
- **ruff as a lint LSP (was a separate tracked idea):** configuring
  `ruff server` as an LSP would auto-surface lint diagnostics in-turn (per the
  auto-push behavior above), which could let the ruff Stop hook slim to
  formatting only. Open: whether in-turn lint is wanted given the "confirm, not
  discover" philosophy, whether ruff's lint duplicates pyright/mypy findings,
  and whether the wiring is a standalone `.lsp.json` vs. a plugin wrapper.
- **General (measure before committing):** does the model empirically reach for
  LSP navigation when it's available, and is the token cost of LSP responses
  worth it? Best answered on a real TS session.
- **Diagnostics-only-off:** confirm that server-side config (jedi by nature, or
  pyright `typeCheckingMode: off`) cleanly yields navigation without Claude Code
  still surfacing diagnostics.

## Sources

- Claude Code LSP tool behavior:
  https://code.claude.com/docs/en/tools-reference.md#lsp-tool-behavior
- Claude Code plugins (LSP servers):
  https://code.claude.com/docs/en/plugins.md#add-lsp-servers-to-your-plugin
- pyright vs mypy differences:
  https://github.com/microsoft/pyright/blob/main/docs/mypy-comparison.md
- basedpyright (Pylance features, no-Node packaging):
  https://docs.basedpyright.com/dev/benefits-over-pyright/pylance-features/
- pyright PyPI Node-fetch issue:
  https://github.com/RobertCraigie/pyright-python/issues/231
- mypy LSP path (pylsp-mypy / dmypy-ls):
  https://github.com/python-lsp/pylsp-mypy
- pyrefly 1.0:
  https://pydevtools.com/blog/pyrefly-1-0-is-the-obvious-mypy-upgrade/

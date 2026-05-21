---
paths:
  - "**/CLAUDE.md"
  - "**/.claude/rules/*.md"
---

# Claude rules style guide

Rules in CLAUDE.md and rules/ files are always read by Claude Code, not a human.
The goal is rules that fire at the right moment — precise enough that Claude
recognizes when they apply. Keep them brief: rules compete with other context
for attention, and their token cost accumulates across a session. Optimize for
utility first, brevity second. This guide is itself a rules file — its own rules
apply when editing it.

## When writing a rule

Users typically state a goal; Claude formulates the rule text. Apply these
checks first — if the rule fails one, surface the issue to the user rather than
writing a rule that won't fire or won't help:

**Ground it in a real case**: Name a specific past or plausible situation where
this rule would have applied. If none comes to mind, the rule is likely too
abstract.

**Recognizability check**: Read the trigger alongside the grounded scenario
named above. Is it obvious the trigger applies — matching directly, without
requiring interpretation? If the connection requires a reasoning step, sharpen
the trigger language to be closer to the concrete situation.

**Scope check**: Consider other cases where the trigger might also fire. Is the
directive correct in those cases too? If not, narrow the trigger or add an
exception.

**Necessity check**: Without this rule, would Claude have gone wrong in the
grounded scenario named above? If not, the rule may document existing behavior
rather than shape it.

Once the rule passes, write it with these properties:

**Lead with the directive**: Open with the action-directing element first —
when/before/after for trigger-based rules, "never" for constraints, "prefer" for
preferences, numbered steps for procedures. "Before calling `Write` on an
existing file" fires when it should; "for existing files, use `Edit`" is
concept-first and doesn't fire.

**Anchor to transitions, not ambient conditions**: Prefer triggers that fire at
clear seams — before or after an atomic action — over mid-stream conditions.
"Before creating a new file" fires at an unmissable moment; "when writing
complex code" fires while attention is already divided.

**Imperative mood**: "Use X", not "X should be used" or "consider X".

**Explicit strength**: Use `always`, `prefer`, `avoid`, `never` deliberately —
they carry different obligations. Quantifiers like `every` and `never` are
equivalent to `always` and are fine where they read more naturally.

**Inline rationale**: Include a brief "why" when the rule is unintuitive, when
violating it is tempting, or when knowing the reason would clarify an ambiguous
case. Keep to at most one clause inline, e.g. "prefer `Edit` over `Write` —
sends only the diff". Not: "…because `Write` re-sends the entire file content,
increasing token usage and making diffs harder to review." If the rationale
can't fit in one clause, surface the rule to the user for scoping rather than
expanding inline.

**Specificity floor**: Give every rule a concrete, detectable trigger — the
primary way to pass the checks above. "Write clear names" doesn't fire. "When
naming a boolean, prefix with `is_`, `has_`, or `can_`" does.

**Synonyms**: Include synonyms for tool names, concepts, or actions so the rule
fires whether Claude encounters one term or another. Typically 1–2; add one only
when a specific alternate term comes to mind — if none does, don't add a
placeholder.

**Terminology**: Avoid "I", "you", and "a reader" — ambiguous or impersonal. Use
"the user" for the human and "Claude" for Claude Code itself.

**Be self-contained**: Avoid references to concepts defined elsewhere that may
not be in context. "Follow the DAMP pattern" is opaque without the testing guide
loaded — either define the concept inline or include enough that the rule is
actionable on its own.

**No historical commentary**: Describe what is, not what changed. History
belongs in git.

**Before finalizing rule text**: Scan for common slip patterns: prohibited
pronouns ('I', 'you', 'a reader'); passive constructions ('should be used', 'is
preferred'); historical commentary ('previously', 'used to be').

## When structuring a rules file

**Prefer specific section headers**: headers should be specific enough that
Claude can self-select without reading the body. For transition-triggered
groups, action-named headers ("Before creating a new file") are clearest. For
thematic groups, a specific topic label ("Testing", "Exceptions") works equally
well. Avoid vague labels ("Preferences", "Miscellaneous") that don't narrow
applicability.

**Bold trigger keywords**: In lists, bold the trigger at the start. Claude's
attention falls on bold text first.

**Strategic redundancy**: Before repeating a rule, consider whether reaching one
section implies reaching the other — if so, one occurrence is enough. Repeat
only when the two trigger contexts are genuinely disjoint — token cost
accumulates.

## When deciding where a rule belongs

**What goes where**: Put rules that only apply when editing a file type in
rules/; put cross-language and always-applicable rules in CLAUDE.md.

**Before adding a rule**: Scan the file for existing rules covering the same
trigger. Consolidate rather than accumulate.

**When a genuine conflict exists**: State the priority explicitly at one of the
sites — don't rely on the more-specific-wins default (rules/ overrides CLAUDE.md
for the matched path) alone.

**When a rule contradicts observed practice**: If a rule appears to conflict
with patterns Claude observes in the current project, surface it to the user as
a candidate for revision rather than silently ignoring or following it.

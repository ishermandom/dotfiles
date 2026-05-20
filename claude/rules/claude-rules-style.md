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
utility first, brevity second.

## Writing individual rules

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
they carry different obligations.

**Inline rationale**: Include a brief "why" when the rule is unintuitive or when
violating it is tempting, e.g. "prefer `Edit` over `Write` (sends only the
diff)". Omit when self-evident.

**Specificity floor**: Give every rule a concrete, detectable trigger — the
primary way to pass the gut-check below. "Write clear names" doesn't fire. "When
naming a boolean, prefix with `is_`, `has_`, or `can_`" does.

**Gut-check before adding or editing**: Without this rule in mind, would Claude
encounter the situation and think to look for guidance? If not, sharpen the
trigger (see specificity floor above) or drop the rule.

**Ground it in a real case**: Before adding a rule, name a specific past or
plausible situation where it would have applied. If you can't, the rule is
likely too abstract.

**Necessity check**: Would Claude have violated this rule without knowing it? If
not, the rule may not address a real gap.

**Synonyms**: Include synonyms for tool names, concepts, or actions so the rule
fires whether Claude encounters one term or another. Don't overdo it — enough to
catch the relevant moment, not more.

**Terminology**: Avoid "I" and "you" — ambiguous whether they mean the user or
Claude. Use "the user" for the human and "Claude" for Claude Code itself.

**Be self-contained**: Avoid references to concepts defined elsewhere that may
not be in context. "Follow the DAMP pattern" is opaque without the testing guide
loaded — either define the concept inline or include enough that the rule is
actionable on its own.

**No historical commentary**: Describe what is, not what changed. History
belongs in git.

## Organizing a rules file

**Action-named headers**: Name sections after the trigger or action, not the
concept. "Before creating a new file" over "File creation preferences" — Claude
scans headers before body text.

**Bold trigger keywords**: In lists, bold the trigger at the start. Claude's
attention falls on bold text first.

**Strategic redundancy**: Repeat a rule only when trigger contexts are distinct
enough that reaching one section doesn't imply reaching the other. Token cost is
real — the bar is higher than in human docs.

## Deciding where a rule belongs

**What goes where**: Put rules that only apply when editing a file type in
rules/; put cross-language and always-applicable rules in CLAUDE.md.

**Before adding a rule**: Scan the file for existing rules covering the same
trigger. Consolidate rather than accumulate.

**When a genuine conflict exists**: State the priority explicitly at one of the
sites — don't rely on the more-specific-wins default (rules/ overrides CLAUDE.md
for the matched path) alone.

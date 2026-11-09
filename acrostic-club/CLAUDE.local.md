# Working on the acrostic-club fork

This checkout is a fork: changes reach the original repository (the `upstream`
remote) as pull requests opened from branches on the fork (the `origin` remote).
The rules below override the global CLAUDE.md and the rules files, such as
`rust.md`, where they conflict.

## Git

- **Never commit to `main` or `git land` onto it**: local `main` tracks
  `upstream/main` and only fast-forwards to match it. A commit on `main`
  diverges it from upstream, and undoing the divergence means rewriting `main`'s
  history.
- **Base each pull request branch on `upstream/main`**: the fork's `main` on
  `origin` may lag behind, since Claude never pushes to it.
- **Before pushing a branch to `origin`**: push only a branch meant to become a
  pull request, and only after the user has reviewed its changes. Never push any
  other branch.
- **Commit messages**: open with a short sentence ending in a period, as
  upstream's history does ("Updated clues."). Always add a body explaining the
  change and its reasons; upstream's commits have none, but the user wants them.
- **`tasks.md` is tracked upstream**: the upstream owner agreed to it, so it
  belongs in pull requests like any other file. Queue follow-ups and tidy-ups
  there.

## Code style

- **Follow upstream's conventions where they apply**:
  - never add a license header; the repository's `LICENSE` covers its files
  - wrap Rust near 100 columns, rustfmt's default width, rather than 80
  - write plain `//` comments, never `///` doc comments
- **In new code, follow the user's preferences over upstream's habits**:
  - `.expect("…")` with a message stating the invariant that should hold, never
    a bare `.unwrap()`
  - inline named format arguments such as `{elapsed:?}`, never positional `{}`;
    bind an expression to a descriptive local first
  - full-word names
- **Put tests for new code in the crate's `tests/` directory**, which reaches
  the generator through its library target. Leave upstream's existing inline
  `#[test]` functions where they are.
- **Leave existing code outside the change as it is**: don't reformat or tidy it
  in passing. `tasks.md` queues the codebase-wide tidy-ups.
- **Never run rustfmt over existing files**: the code resembles rustfmt's
  default style but isn't formatted by it, so rustfmt would rewrite most files.
  Write new code in rustfmt's default style by hand.

## Building and testing

- **After entering a worktree, or starting a session in one**: run the command
  below. The generator reads its data from the worktree's `submodules/` folders,
  which start out empty; the command fills them with copy-on-write clones of the
  main checkout's files. A plain `git worktree add` runs a `post-checkout` hook
  that does the same, but Claude Code creates worktrees with git hooks switched
  off. The command skips any folder that already holds files, so running it
  again is harmless.

  ```bash
  /Users/Shared/code/acrostic-club/.git/hooks/post-checkout \
    0000000000000000000000000000000000000000
  ```

  The all-zeros argument marks the worktree as new; without it, the command does
  nothing. When the generator can't read `quotes.csv.br` or another file under
  `submodules/`, the worktree has missed this step.

- **Build and test with `RUSTC_BOOTSTRAP=1`**, as in
  `RUSTC_BOOTSTRAP=1 cargo build`: the code enables unstable features, and the
  installed compiler is Homebrew's stable Rust.
- **When a build can't find `safe-once`, `safe-once-async`, or
  `safe-once-map`**: the generator's manifest takes them as path dependencies in
  the directory that holds the checkout. The main checkout finds them in
  `/Users/Shared/code/`, and a worktree finds copies in `.claude/worktrees/`.
- **Run only the tests the change touches**, by target or name, as in
  `RUSTC_BOOTSTRAP=1 cargo test -p acrostic-generator --test quote`. Many of
  upstream's tests are exploratory runs that print results and assert nothing,
  and some may need data or local services a checkout lacks.

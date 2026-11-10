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
- **When a branch is ready for the user's review**: if it doesn't have its own
  worktree already, give the user the command below to run from their own
  terminal, since running it through `!` in a session failed. The user then
  opens the worktree in Zed with `wt <branch>`.

  ```bash
  git -C /Users/Shared/code/acrostic-club worktree add \
    .claude/worktrees/<branch> <branch>
  ```

  To make review fixes, switch into that worktree with `EnterWorktree`, passing
  its path. When git refuses a branch as already checked out in the main
  checkout, which happens when Zed switches the main checkout to it, ask the
  user to switch the main checkout back to `main`: a branch can be checked out
  in only one place.

- **Commit messages**: open with a short sentence ending in a period, as
  upstream's history does ("Updated clues."). Always add a body explaining the
  change and its reasons; upstream's commits have none, but the user wants them.
- **`tasks.md` is tracked upstream**: the upstream owner agreed to it, so it
  belongs in pull requests like any other file. Queue follow-ups and tidy-ups
  there.
- **When fanning out a task from `tasks.md`**: never add a `Worktree:` line to
  `tasks.md`, though the fanout skill's tracker step asks for one. Recording it
  would mean committing to `main` and pushing unreviewed work, both of which the
  rules above forbid. Write the task's text into the lane's launch prompt
  instead, since the prompt has no tracker line to point at.

## When opening a pull request

The user opens every pull request (PR) from their main account, so never run
`gh pr create`. Instead, prepare the pull request and hand it over:

1. Push the branch to `origin` under a name that describes the change, without
   the `worktree-` prefix that local branches carry.
2. Write the description to `.claude/pr-description.md` in the branch's
   worktree, where the user can review the description before posting. The main
   account can open files under `/Users/Shared/code`, but not Claude's home
   folder, which holds the scratchpad and `$CLAUDE_JOB_DIR/tmp`. Git ignores
   `.claude/` through `.git/info/exclude`.

   Write each paragraph of the description on a single line rather than wrapping
   at 80 columns: GitHub shows every newline in a pull request description as a
   line break, unlike in a Markdown file. Note that Prettier does not run in
   this repo.

3. Hand the user a command to run from the main account:

   ```bash
   gh pr create --repo nathdobson/acrostic-club --base main \
     --head ishermandom:<branch> --title '<title>' \
     --body-file <absolute path to pr-description.md>
   ```

Target `main` even when the branch is stacked on another pull request's branch:
GitHub can't base a pull request from a fork on a fork branch. Instead, list the
pull requests the branch includes in the description, and say which commits are
new.

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
- **Format Rust according to `rustfmt.toml`**:
  - Run `~/.claude/scripts/quiet-rustfmt.sh`. The end-of-turn formatter skips
    this fork as someone else's project, so nothing else formats the code.

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

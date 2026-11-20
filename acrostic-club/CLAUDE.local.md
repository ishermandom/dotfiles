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
- **When the user asks to sync `main`** {#sync-main}, in words such as "sync" or
  "re-sync": bring both local `main` and the fork's `main` on `origin` up to
  `upstream/main`. Run `git fetch upstream`, then
  `git merge --ff-only upstream/main` in the main checkout with `main` checked
  out, then `git push origin main`. Push `main` rather than `upstream/main`,
  which another session's fetch can move between the merge and the push.
- **Base each pull request branch on `upstream/main`**: the fork's `main` on
  `origin` moves only when the user asks for a sync, so it may lag behind.
- **Before pushing a branch to `origin`**: push only a branch meant to become a
  pull request, and only after the user has reviewed its changes. Never push any
  other branch, except `main` when the user asks for a sync.
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

- **Commit messages**: open with a short imperative sentence ending in a period,
  such as "Update the clues." Always add a body explaining the change and its
  reasons; upstream's commits have none, but the user wants them.
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

   Before pushing, give the message of each commit new to this pull request a
   prose.md pass (inline, no subagents): the fork's ruleset blocks force pushes,
   so it's worth getting each message into a great state before pushing.

2. Write the description to `.claude/pr-description.md` in the branch's
   worktree, where the user can review the description before posting. The main
   account can open files under `/Users/Shared/code`, but not Claude's home
   folder, which holds the scratchpad and `$CLAUDE_JOB_DIR/tmp`. Git ignores
   `.claude/` through `.git/info/exclude`.

   Keep the description to the main change: what it does and why, usually in a
   paragraph or two. The pull request shows its commits alongside, so leave
   everything else to their messages, even ideas that are true and relevant.

   Before keeping an idea in the description, ask whether upstream's reviewer
   needs it to grasp the main change. Ideas that usually fail this test include
   where the tests live, side effects unlikely to matter, and tidy-ups or
   follow-up tasks riding along on the branch. When shortening a draft, cut the
   ideas that fail rather than just rewording the ones that pass: rewording
   saves words but still leaves the reviewer every idea to read.

   Write each paragraph of the description on a single line rather than wrapping
   at 80 columns: GitHub shows every newline in a pull request description as a
   line break, unlike in a Markdown file. Note that Prettier does not run in
   this repo.

   End the description at its `🤖 Generated with [Claude Code]` line, leaving
   out the session link that Claude Code's attribution reminder places after
   that line. In the PR description, the session link is more noise than signal.
   Commit messages keep their `Claude-Session:` trailer.

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

## When tearing down a lane with `fanout-teardown`

In this fork, a lane lands when upstream merges its pull request, not through
`git land`. Adapt the skill's steps as follows:

- **Before the skill's first step, confirm the merge**: run
  `git fetch upstream`, then `git cherry -v upstream/main <branch>`. Every
  commit should show a leading `-`, meaning `upstream/main` holds the same
  change; stop and report any commit marked `+`. Compare changes rather than
  hashes: GitHub's rebase merge gives each commit a new hash, so an ancestry
  check reports a merged branch as unmerged. For the same reason, delete the
  local branch at cleanup with `git branch -D`, since `git branch -d` refuses a
  branch that git sees as unmerged.
- **Then confirm the pushed branch is gone**: run
  `git ls-remote --heads origin <pushed name>`, which should print nothing,
  since the branch is deleted automatically before teardown. If the branch still
  exists, report it to the user rather than deleting it.
- **Skip the rebase onto `main` and the `git land`**: the merge was the landing,
  and local `main` only fast-forwards to match `upstream/main`.
- **Skip the tracker commit**: `tasks.md` reaches `main` only through a pull
  request. If the lane's task still appears in `upstream/main`'s `tasks.md`,
  report it to the user instead.
- **After cleaning up the worktree, sync `main`** (#sync-main): invoking the
  skill counts as the user asking for the sync.

## Code style

In this section, upstream's code means code that the upstream owner wrote. Code
from the user's earlier pull requests, written with Claude, stays the user's own
even after upstream merges it. To tell the two apart, run `git blame -e`: the
user's lines carry `git config user.email` as their author.

- **Follow upstream's conventions where they apply**:
  - never add a license header; the repository's `LICENSE` covers its files
  - write plain `//` comments, never `///` doc comments
  - avoid lifetime parameters on structs, since too many make the borrow checker
    hard to satisfy: clone values into the struct instead, wrapping a value too
    costly to clone in `Rc` or `Arc`
- **In new code, follow the user's preferences over upstream's habits**:
  - `.expect("…")` with a message stating the invariant that should hold, never
    a bare `.unwrap()`
  - inline named format arguments such as `{elapsed:?}` for plain variables, and
    a positional `{}` for a short expression such as `e.message`, mixing the two
    in one string where needed: `println!("{answer}: {}", entry.clue)`. Bind an
    expression to a local only when the local's name says something the
    expression doesn't, never just to inline it
  - full-word names
- **Put tests for new code in the crate's `tests/` directory**, which reaches
  the crate through its library target.
- **Leave upstream's code outside the change as it is**: don't reformat or tidy
  it in passing. `tasks.md` queues the codebase-wide tidy-ups. The user's own
  code may be improved in passing.
- **Format Rust by running `~/.claude/scripts/quiet-rustfmt.sh`** from the
  repository root. The end-of-turn formatter skips this fork as someone else's
  project, so nothing else formats the code. rustfmt leaves comments alone, so
  wrap them by hand at `rustfmt.toml`'s 100 columns, not `rust.md`'s 80.

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

- **When removing a worktree reports uncommitted changes inside `submodules/`**,
  as `ExitWorktree` does: the changes are the data clones from the step above.
  Run the command below from the worktree; it compares the clones with the main
  checkout's copies, skipping the `.git` link file that only the main checkout's
  copies carry. When it prints nothing, discard the clones without asking the
  user. When it prints a difference, ask the user first: the branch may have
  changed the data.

  ```bash
  diff -rq --exclude=.git submodules /Users/Shared/code/acrostic-club/submodules
  ```

- **Before running a `global` stage in a worktree, or when the generator can't
  open a file under `build/`**: run
  `/Users/Shared/code/acrostic-club/generator/clone-build.sh` from inside the
  worktree. The script clones the main checkout's `build/` at almost no disk
  cost, where rebuilding stores the worktree's own copy of many gigabytes.
  Rebuild an output only when the branch changes how its stage builds it. The
  main checkout's copy of the script serves branches older than the script too.
  Leave the script out of worktree setup: the user wants clones only where
  needed.

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

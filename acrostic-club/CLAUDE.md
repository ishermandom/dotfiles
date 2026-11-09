# Contributing to upstream

This checkout is a fork: changes reach the original repository (the `upstream`
remote) as pull requests opened from branches on the fork (the `origin` remote).
The rules below override the global CLAUDE.md rules they conflict with.

- **Before writing code, comments, or commit messages**: follow the conventions
  upstream's existing code and commit history use, over the global CLAUDE.md
  style rules. Never add a license header: the repository's `LICENSE` covers its
  files.
- **Never commit to `main` or `git land` onto it**: local `main` tracks
  `upstream/main` and only fast-forwards to match it. A commit on `main`
  diverges it from upstream, and undoing the divergence means rewriting `main`'s
  history.
- **Base each pull request branch on `upstream/main`**: the fork's `main` on
  `origin` may lag behind, since Claude never pushes to it.
- **Before pushing a branch to `origin`**: push only a branch meant to become a
  pull request, and only after the user has reviewed its changes. Never push any
  other branch.

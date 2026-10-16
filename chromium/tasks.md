# Tasks

Status key: `[ ]` not started · `[~]` in progress · `[x]` done · `[-]` dropped

- [ ] **Configure a fast local build, without building yet**
      {#fast-build-config} — write `out/Default/args.gn`, generate the build
      files, and show the user the resulting configuration along with the docs
      behind each setting. The user asked not to start a build yet.
  - Note: the candidates in `src/docs/mac_build_instructions.md` #faster-builds
    are `is_debug = false` (much faster links), `is_component_build = true`
    (much faster incremental builds), `symbol_level = 0` (faster builds and
    links, but no symbolized backtraces), and `use_lld = false` (Apple's linker,
    faster for a local arm64 build). Remote execution is out: the docs say
    Reclient doesn't support Mac builds for external contributors.
  - Note: check the installed Xcode 27.1 (macOS SDK 27.0) against
    `mac_sdk_official_version` in `src/build/config/mac/mac_sdk.gni`. The docs
    say newer SDKs usually work.
  - Note: the checkout used about 35 GiB, leaving 150 GiB free on 2026-10-15.
    The build output's size is unmeasured; confirm the headroom after the first
    build.
  - Note: this fanless MacBook Air sleeps after 1 minute of inactivity, and a
    build doesn't count as activity, so run builds as `caffeinate -i autoninja`.
  - Open question: does the user need debuggable builds? `is_debug = false` and
    `symbol_level = 0` give up debug checks and symbolized backtraces. The user
    plans to use the build to investigate a Chrome regression, and will decide
    when that work starts.
  - Note: `src/tools/bisect-builds.py` downloads prebuilt Chromium snapshots and
    binary-searches revisions, so a regression can be narrowed to a revision
    range before any local build.
  - Open question: does `gn gen` count as starting the build? It writes build
    files without compiling anything.

- [ ] **Speed up `git status` in `src/`** — Chromium's Mac docs recommend two
      per-repo settings: `core.untrackedCache` (once
      `git update-index --test-untracked-cache` reports `OK`) and
      `core.fsmonitor`. The installed git, 2.56, is past fsmonitor's 2.43
      minimum on Mac.

- [ ] **Decide whether to reapply the raised vnode cache at startup** — the
      `kern.maxvnodes=524288` set with `sudo sysctl` lasts only until reboot.
      Chromium's Mac build docs give a launch daemon that reapplies it at boot:
      `src/docs/mac_build_instructions.md` #increase-the-vnode-cache-size.
  - Note: decide after the first build, by measuring whether 524,288 records
    hold the files a rebuild checks. Run a rebuild with nothing to compile
    twice, reading `sysctl -n kern.num_recycledvnodes` before and after the
    second run. Near zero means the cache suffices; tens of thousands means
    raise it further before making it permanent.
  - Note: each cached file record costs about 0.9 KB of kernel memory, so
    524,288 costs roughly 250 MB more than the 263,168 default — estimated
    2026-10-15 from `zprint` zone sizes on this M4 MacBook Air.

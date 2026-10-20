# Tasks

Status key: `[ ]` not started · `[~]` in progress · `[x]` done · `[-]` dropped

Reference notes for this checkout sit beside this file's real location, in
`/Users/Shared/code/dotfiles/chromium/`:

- `building.md`: building the local checkout.
- `reproducing.md`: reproducing user-reported bugs in the local build.

---

- [ ] **Speed up `git status` in `src/`** — Chromium's Mac docs recommend two
      per-repo settings: `core.untrackedCache` (once
      `git update-index --test-untracked-cache` reports `OK`) and
      `core.fsmonitor`. The installed git, 2.56, is past fsmonitor's 2.43
      minimum on Mac.

- [ ] **Decide whether to reapply the raised vnode cache at startup** — the
      `kern.maxvnodes=524288` set with `sudo sysctl` lasts only until reboot.
      Chromium's Mac build docs give a launch daemon that reapplies it at boot:
      `src/docs/mac_build_instructions.md` #increase-the-vnode-cache-size.
  - Note: decide by measuring whether 524,288 records hold the files a rebuild
    checks. Run a rebuild with nothing to compile twice, reading
    `sysctl -n kern.num_recycledvnodes` before and after the second run. Near
    zero means the cache suffices; tens of thousands means raise it further
    before making it permanent.
  - Note: each cached file record costs about 0.9 KB of kernel memory, so
    524,288 costs roughly 250 MB more than the 263,168 default — estimated
    2026-10-15 from `zprint` zone sizes on this M4 MacBook Air.

- [ ] **[maybe] Lower `symbol_level` to 0** — `src/out/Default/args.gn` sets
      level 1 so that printed stack traces can be looked up for file, line, and
      inlined frames. The omnibox investigation never needed that: log lines
      carry their own file and line at any level, and narrowing by feature found
      the cause. Level 0 builds and links faster, by an unmeasured amount.
  - Note: the change recompiles everything, about 5 hours on this machine
    (`building.md`), so pair it with a rebuild that would be long anyway, such
    as after a large sync. Update the level's comment in `args.gn` to match.

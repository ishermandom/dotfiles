# Tasks

Status key: `[ ]` not started · `[~]` in progress · `[x]` done · `[-]` dropped

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

# Building the local Chromium checkout

How to rebuild the checkout at `/Users/Shared/code/chromium` on this machine.
Paths below are relative to that folder. The build's settings live in
`src/out/Default/args.gn`, whose comments explain each one.

- **Rebuild command**: from `src/`, run

  ```shell
  caffeinate -i autoninja -C out/Default chrome
  ```

  The `caffeinate -i` prefix keeps the Mac awake: this MacBook Air is set to
  sleep after 1 minute idle, and a build doesn't count as activity.

- **Full-build cost**: the first full build, finished 2026-10-16, took 5 hours
  16 minutes and left `src/out/Default` at 12 GiB, with 136 GiB still free on
  the disk.
- **Changing `is_debug` or `symbol_level`** recompiles everything, at roughly
  the full-build cost above.
- **Variable values for one target**: at `symbol_level` 1 or below, the build
  omits variable values. To get them in one target without a full recompile, add
  these lines to that target's definition in its `BUILD.gn`:

  ```gn
  configs -= [ "//build/config/compiler:default_symbols" ]
  configs += [ "//build/config/compiler:symbols" ]
  ```

- **"Missing Metal Toolchain" errors**: run these two commands, then rebuild:

  ```shell
  xcodebuild -showComponent MetalToolchain
  xcrun -f metal
  ```

  The first full build failed this way at a shader step in ANGLE, Chromium's
  graphics layer, even though the first command reported the toolchain
  installed; after both commands, the step passed. Presumably the toolchain
  mounts on demand.

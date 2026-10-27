# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Compile each Homebrew Python's standard library to bytecode, once per
# installed version.
#
# Python caches each module's compiled bytecode in a `__pycache__` folder beside
# its source, so later runs can skip compiling it. Homebrew ships that cache for
# only part of the standard library, and only the account that owns Homebrew
# can write the rest. Every other account, the Claude sandbox among them,
# therefore recompiles those modules on every run, which adds noticeably to
# short runs such as the Stop hook's tests. Compiling them once from the owning
# account fills the cache for every account.
#
# A marker file records that a version's standard library is compiled. A
# Homebrew upgrade installs Python under a new versioned folder, which has no
# marker, so the next login compiles the new version; `brew cleanup` later
# removes the old folder along with its bytecode and marker.

# Compiles, in the background, each standard library under `homebrew_opt_dir`
# that this account can write and that lacks a marker. Warns when an earlier
# compile failed, and retries it.
compile_python_stdlibs() { # compile_python_stdlibs [homebrew_opt_dir]
  local opt_dir="${1:-/opt/homebrew/opt}"
  # The standard library's own test suite deliberately holds files that do not
  # compile, which would fail every run. Nothing imports it or the other
  # packages left out, and site-packages is not part of the standard library.
  local excluded='/(test|idlelib|turtledemo|site-packages)/'
  local versions='Frameworks/Python.framework/Versions'
  local lib marker failure_log python output compile_status

  # `(N/)` matches directories only, and expands to nothing when none match,
  # rather than failing.
  for lib in "$opt_dir"/python@3.*/$versions/3.*/lib/python3.*(N/); do
    # Only the account that owns Homebrew can write here; every other account
    # has nothing to do.
    [[ -w $lib ]] || continue

    marker="$lib/__pycache__/.compileall-done"
    failure_log="$lib/__pycache__/.compileall-failed.log"
    [[ -e $marker ]] && continue

    if [[ -e $failure_log ]]; then
      echo "WARNING: compiling $lib failed at an earlier login; retrying." \
        "See $failure_log" >&2
    fi

    # `:h` drops a path's last segment and `:t` keeps only that segment, so
    # .../Versions/3.15/lib/python3.15 gives .../Versions/3.15/bin/python3.15.
    python="${lib:h:h}/bin/${lib:t}"
    if [[ ! -x $python ]]; then
      echo "WARNING: no interpreter at $python to compile $lib with" >&2
      continue
    fi

    mkdir -p "${marker:h}"
    # `&|` runs the compile in the background, detached from this shell, so a
    # login never waits on it. Its standard streams go to /dev/null, so it never
    # holds the terminal or writes to it later; what the compile prints is kept
    # in the failure log instead.
    (
      # `nice` lowers the compile's priority, so it never competes with anything
      # in the foreground. The interpreter's arguments:
      #
      # - `-m compileall` compiles each source file under `$lib`, writing its
      #   bytecode into the `__pycache__` folder beside it
      # - `-q` prints only errors, so the output is empty on success
      # - `-j 0` spreads the work over every core
      # - `-x` skips each file whose full path matches the `excluded` regular
      #   expression
      output=$(nice "$python" -m compileall -q -j 0 -x "$excluded" "$lib" 2>&1)
      compile_status=$?
      if ((compile_status == 0)); then
        rm -f "$failure_log"
        # `: >|` writes an empty marker; `>|` overwrites even under noclobber.
        : >| "$marker"
      else
        print -r -- "$output" >| "$failure_log"
      fi
    ) < /dev/null > /dev/null 2>&1 &|
  done
}

#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# Tests for zsh/.python-stdlib-bytecode.zsh. Each case builds a scratch Homebrew
# tree whose Pythons are stubs that record how they were called, and runs the
# compile step over that tree, so no real interpreter or Homebrew folder is
# touched.
#
# The step ships in the zsh stow package, whose contents install into $HOME, so
# a test beside it would be symlinked into the home directory. Tests for a
# package therefore live under tests/<package>/ instead.

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root="$script_dir/../.."
step_file="$repo_root/zsh/.python-stdlib-bytecode.zsh"

. "$repo_root/claude/scripts/shell-test-framework.sh"

require_commands zsh

# --- helpers ----------------------------------------------------------------

# Builds the standard library folder of a scratch Homebrew install of Python
# `version` under the current case, and echoes its path.
make_stdlib() { # make_stdlib <version>
  local framework_dir="$case_dir/opt/python@$1/Frameworks/Python.framework"
  local lib="$framework_dir/Versions/$1/lib/python$1"
  mkdir -p "$lib"
  echo "$lib"
}

# As make_stdlib, and also gives the install a stub interpreter. The stub
# appends its arguments to the case's `calls` file, then succeeds, or fails with
# an error message when STUB_FAILS is set.
make_python() { # make_python <version>
  local lib
  lib=$(make_stdlib "$1")
  # `%/lib/*` strips the trailing /lib/... from the path, leaving the version's
  # own folder, where its bin sits.
  local bin="${lib%/lib/*}/bin"
  mkdir -p "$bin"
  # Quoted delimiter: the stub's variables must resolve when it runs, not when
  # this file is written.
  cat > "$bin/python$1" << 'STUB'
#!/usr/bin/env bash
# Stubbed interpreter: records its arguments, then fails if the case asks it to.
echo "$*" >> "$STUB_CALLS"
if [ -n "${STUB_FAILS:-}" ]; then
  echo "stub compile error" >&2
  exit 1
fi
STUB
  chmod +x "$bin/python$1"
  echo "$lib"
}

# Sources the compile step and runs it over the current case's scratch Homebrew
# tree, printing everything it reports. Given any argument, the stub
# interpreters fail.
run_step() { # run_step [stub_failure]
  STUB_CALLS="$case_dir/calls" STUB_FAILS="${1:-}" \
    zsh -c "source '$step_file'; compile_python_stdlibs '$case_dir/opt'" 2>&1
}

# Waits up to five seconds for `path` to appear, since the step leaves its
# results from a background job, then prints whether it did: `present` or
# `absent`.
presence_after_wait() { # presence_after_wait <path>
  for _ in $(seq 50); do
    if [ -e "$1" ]; then
      echo present
      return
    fi
    sleep 0.1
  done
  echo absent
}

# The call each stub records when the step compiles `lib`.
expected_call() { # expected_call <lib>
  echo "-m compileall -q -j 0 -x /(test|idlelib|turtledemo|site-packages)/ $1"
}

# --- cases ------------------------------------------------------------------

begin_case compiles_a_missing_stdlib
lib=$(make_python 3.15)
output=$(run_step)
expect_equal "starts without a word" "$output" ""
expect_equal "marks the library compiled" \
  "$(presence_after_wait "$lib/__pycache__/.compileall-done")" present
expect_equal "compiles that library, leaving its test suite out" \
  "$(cat "$case_dir/calls")" "$(expected_call "$lib")"

begin_case compiles_each_installed_version
older=$(make_python 3.14)
newer=$(make_python 3.15)
run_step > /dev/null
expect_equal "marks the older version compiled" \
  "$(presence_after_wait "$older/__pycache__/.compileall-done")" present
expect_equal "marks the newer version compiled" \
  "$(presence_after_wait "$newer/__pycache__/.compileall-done")" present
calls=$(cat "$case_dir/calls")
expect "compiles the older version" \
  contains "$calls" "$(expected_call "$older")"
expect "compiles the newer version" \
  contains "$calls" "$(expected_call "$newer")"

begin_case skips_a_compiled_stdlib
lib=$(make_python 3.15)
mkdir -p "$lib/__pycache__"
: > "$lib/__pycache__/.compileall-done"
output=$(run_step)
# Long enough for a compile wrongly started in the background to record its
# call.
sleep 0.3
expect_equal "stays silent" "$output" ""
expect "starts no compile" test ! -e "$case_dir/calls"

begin_case skips_a_stdlib_this_account_cannot_write
lib=$(make_python 3.15)
chmod a-w "$lib"
output=$(run_step)
sleep 0.3
# Writable again, so the framework's cleanup can remove the case.
chmod u+w "$lib"
expect_equal "stays silent" "$output" ""
expect "starts no compile" test ! -e "$case_dir/calls"
expect "writes no marker" test ! -e "$lib/__pycache__"

begin_case logs_a_failed_compile_then_retries
lib=$(make_python 3.15)
marker="$lib/__pycache__/.compileall-done"
failure_log="$lib/__pycache__/.compileall-failed.log"
run_step stub_failure > /dev/null
expect_equal "logs the failure" "$(presence_after_wait "$failure_log")" present
expect "keeps the interpreter's error in the log" \
  contains "$(cat "$failure_log")" "stub compile error"
expect "leaves the library unmarked" test ! -e "$marker"
output=$(run_step)
expect "warns of the failure at the next login" \
  contains "$output" "failed at an earlier login"
expect "names the log in the warning" contains "$output" "$failure_log"
expect_equal "retries, and marks the library compiled" \
  "$(presence_after_wait "$marker")" present
expect "clears the log once the retry succeeds" test ! -e "$failure_log"

begin_case warns_when_the_interpreter_is_missing
lib=$(make_stdlib 3.15)
output=$(run_step)
expect "names the missing interpreter" \
  contains "$output" "no interpreter at ${lib%/lib/*}/bin/python3.15"
expect "leaves the library unmarked" \
  test ! -e "$lib/__pycache__/.compileall-done"

begin_case no_homebrew_python
mkdir -p "$case_dir/opt"
output=$(run_step)
expect_equal "stays silent" "$output" ""

exit_with_summary

#!/usr/bin/env bash
# Copyright 2026 Ilya Sherman (ishermandom@)
# SPDX-License-Identifier: MIT
#
# The test framework for the repo's shell test scripts, sourced rather than run.
# The shebang above tells shellcheck and editors which dialect to read this in;
# the file is deliberately left non-executable, since sourcing is the only way
# to use it.
#
# pytest gives the Python tests their scratch space, their assertions and their
# reporting. Shell has no runner, so this file plays that part. A test script
# sources it as its first act and gets:
#
# - `$test_script_root`, an empty directory that disappears on exit
# - `require_commands`, to stop with a clear message when a tool is missing
# - `begin_case`, which announces a test case and hands it `$case_dir`
# - `place_executable` and `stub_executable`, to put an executable where the
#   script under test will reach for it
# - `expect` and `expect_equal`, with the `contains` and `not_contains`
#   predicates to assert through
# - `exit_with_summary`, the last line of every test script
#
# Two edges to know about before writing a test script against this:
#
# - Cleanup rides on an EXIT trap installed here. A test script that installs an
#   EXIT trap of its own silently replaces this one, and its scratch tree then
#   outlives the run. Such a script has to remove `$test_script_root` itself.
# - A predicate a test script defines has to be called somewhere, not only
#   handed to `expect` by name. shellcheck cannot see a name passed as data, and
#   reports the function as never invoked (SC2329). Having the predicate print a
#   value, and comparing it with `expect_equal`, keeps it in plain sight.
#
# The file name deliberately avoids ending in `-test.sh`, the glob run_tests.sh
# collects test scripts with — a name inside that glob would have the suite try
# to run this file as one.

# --- the test script's identity and scratch space ---------------------------

# Importing this file via sourcing leaves $0 alone, so it still names the test
# script being run. Every message below carries that name, which saves each
# script from spelling it out in the lines it prints.
test_script_name=$(basename "$0" .sh)

# Somewhere to build fixtures. The trap covers every way the run can end, a
# `require_commands` bail-out included — subject to the EXIT trap caveat in the
# header.
test_script_root=$(mktemp -d)
trap 'rm -rf "$test_script_root"' EXIT

# --- preflight --------------------------------------------------------------

# Ends the run when a command the test script depends on is absent, naming every
# one that is missing so a single run tells the whole story. Without the check,
# a missing tool surfaces later as a failure in whichever case first reaches for
# it, where it reads as a bug in the script under test.
require_commands() { # require_commands <command>...
  local missing=()
  local command_name
  for command_name in "$@"; do
    command -v "$command_name" > /dev/null || missing+=("$command_name")
  done

  if [ ${#missing[@]} -gt 0 ]; then
    # `${missing[*]}` joins the names with a space, which serves as both a
    # readable list and a brew command that installs all of them at once.
    echo "$test_script_name: missing ${missing[*]};" \
      "try 'brew install ${missing[*]}'" >&2
    exit 1
  fi
}

# --- test cases -------------------------------------------------------------

# Announces a test case and gives it an empty directory of its own, `$case_dir`,
# so no case can see what another one left behind.
begin_case() { # begin_case <name>
  echo "case: $1"
  case_dir="$test_script_root/$1"
  mkdir -p "$case_dir"
}

# --- executable fixtures ----------------------------------------------------

# Executables are the costly fixture here, by a wide margin. macOS scans a file
# for malware the first time it is executed, and caches the verdict with the
# file itself rather than with its path: the first run of a newly created
# executable costs around 115ms, where a second run of the same file costs
# around 8ms. Writing a fake per case pays that scan per case, so a suite of a
# few dozen cases spends most of its time waiting on the scanner.
#
# Both helpers below put each distinct executable in `$pool_dir` once and give
# every case a hard link to it. A hard link is a second name for the pooled file
# rather than a copy of it, so running it reuses the scan already paid for. Each
# link is still an ordinary executable, at whatever path the case needs it. Only
# the file's identity is shared, never its location, so the isolation
# `begin_case` promises is untouched.
#
# Hard links rather than symlinks: `format.sh` and `stop_checks.sh` locate their
# siblings through `readlink -f "${BASH_SOURCE[0]}"`, which follows a symlink to
# its target. Placed as a symlink, either script would look for its siblings in
# the pool rather than beside itself in the case's fixture tree.
#
# The pool sits outside `$test_script_root` and so outlives the run that filled
# it: every test script shares it, and the scan for a given executable is paid
# once on the machine rather than once per script per run. That makes the pool a
# cache rather than scratch space, so nothing here removes it. Its entries are
# small, and macOS periodically clears the temporary directory it hands out.
#
# A pool entry is named for the contents it holds, so a stale entry cannot be
# served: edit a script under test, and its new contents hash to a new entry
# while the old one goes unused. The pool directory's name carries the user id
# because its fallback location is `/tmp`, which every account on the machine
# shares: without the id, the first user to run the suite would own a directory
# the next one cannot write into. `$UID` is a bash variable, so reading it
# starts no process.
pool_dir="${TMPDIR:-/tmp}/shell-test-executable-pool-$UID"
mkdir -p "$pool_dir"

# Makes sure <path>'s parent directory exists. Both helpers below call it for
# every fixture, often for a directory an earlier call already made, so it uses
# builtins where the obvious `mkdir -p "$(dirname ...)"` would start two
# processes every time: `${1%/*}` trims the last path segment as dirname would,
# and the `-d` test skips a mkdir that a repeat call would waste.
ensure_parent_dir() { # ensure_parent_dir <path>
  local parent
  case "$1" in
    */*) parent="${1%/*}" ;;
    # A bare filename's parent is the working directory, always already there.
    *) return 0 ;;
  esac

  [ -d "$parent" ] || mkdir -p "$parent"
}

# Puts <source> in the pool unless an entry for those exact contents is already
# there, and prints the pooled path. The entry's name starts with <source>'s
# basename, ahead of the digest, so a listing of the pool stays readable.
pool_executable() { # pool_executable <source>   -> prints the pooled path
  local digest
  digest=$(md5 -q "$1")
  if [ -z "$digest" ]; then
    echo "$test_script_name: cannot hash $1 for the executable pool" >&2
    exit 1
  fi

  local pooled="$pool_dir/${1##*/}-$digest"
  if [ ! -x "$pooled" ]; then
    # Build the entry under a private name and link it into place, so no other
    # test script can reach a half-written file. `ln` refuses a target that
    # exists, so a script that loses the race just discards its own copy. Both
    # copies hold the same contents, so which one survives does not matter.
    local staging="$pooled.staging.$$"
    cp "$1" "$staging"
    chmod +x "$staging"
    ln "$staging" "$pooled" 2> /dev/null
    rm -f "$staging"
  fi

  printf '%s' "$pooled"
}

# Places <source>, typically the script under test, at <destination> inside a
# case's fixture tree, as a hard link to its pooled copy.
place_executable() { # place_executable <source> <destination>
  ensure_parent_dir "$2"
  ln "$(pool_executable "$1")" "$2"
}

# The one pooled executable that every stub is a hard link to, put in the pool
# as the framework loads. It runs the plan file beside whichever link invoked
# it, so one file backs every fake in the suite. Since the pool is shared, that
# file is scanned once on the machine rather than once per test script.
cat > "$test_script_root/stub-source" << 'STUB'
#!/usr/bin/env bash
# A stub's behavior is the plan file beside it. `$0` is the path the caller
# reached this link through, so each link finds its own plan without having to
# be told where it is.
source "$0.plan"
STUB
stub_pool_entry=$(pool_executable "$test_script_root/stub-source")

# Creates a fake executable at <destination> that runs a fragment of shell code
# read from stdin. For example, a fixture's setup can install a `uv` that
# succeeds silently, and a case can then swap in a `uv` that fails:
#
# ```bash
# stub_executable "$case_dir/bin/uv" <<< 'exit 0'
# stub_executable "$case_dir/bin/uv" << 'EOF'
# echo "uv: cannot $1" >&2
# exit 2
# EOF
# ```
#
# After the second call, `"$case_dir/bin/uv" sync` prints `uv: cannot sync` on
# stderr and exits 2. The fragment runs as the stub's own code, so it sees the
# stub's arguments as `$1`, `"$@"` and so on, and its `exit` ends the stub. A
# second call for the same destination replaces the first call's fragment, which
# is how a case overrides a default its setup installed.
#
# Every stub is a hard link to one pooled executable, so creating a stub costs
# no first-run scan. That executable runs the fragment saved beside whichever
# link invoked it, at `<destination>.plan`: here, `$case_dir/bin/uv.plan`. A
# case that lists or counts the directory it stubbed into sees those plan files
# too.
stub_executable() { # stub_executable <destination>   (fragment on stdin)
  ensure_parent_dir "$1"
  [ -e "$1" ] || ln "$stub_pool_entry" "$1"
  cat > "$1.plan"
}

# --- assertions -------------------------------------------------------------

# Assertions that have failed so far — `expect` bumps it and `exit_with_summary`
# reports it, so a sourcing test script never touches it.
failure_count=0

# Runs the given command as an assertion: prints one result line, and on failure
# bumps failure_count so the run ends non-zero.
expect() { # expect <description> <command...>
  local description="$1"
  shift
  if "$@"; then
    echo "  ok: $description"
  else
    echo "  FAIL: $description" >&2
    failure_count=$((failure_count + 1))
  fi
}

contains() { # contains <haystack> <needle>
  case "$1" in
    *"$2"*) return 0 ;;
    *) return 1 ;;
  esac
}

not_contains() { # not_contains <haystack> <needle>
  ! contains "$1" "$2"
}

# Asserts that a value matches what the case expects. `expect` takes a command
# to run, so a plain comparison needs a `test ... = ...` around it; this
# supplies that once rather than at every call site.
expect_equal() { # expect_equal <description> <actual> <expected>
  expect "$1" test "$2" = "$3"
}

# --- the verdict ------------------------------------------------------------

# Ends the run: prints its verdict, then exits 0 when every assertion passed and
# 1 otherwise. The exit status is what run_tests.sh reads to decide whether the
# suite failed.
exit_with_summary() {
  echo
  if [ "$failure_count" -eq 0 ]; then
    echo "$test_script_name: all passed"
    exit 0
  fi
  echo "$test_script_name: $failure_count assertion(s) failed" >&2
  exit 1
}

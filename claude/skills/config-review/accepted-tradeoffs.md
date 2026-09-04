# Accepted tradeoffs

Defects verified real and deliberately left unfixed, with the user's why. The
review's verify pass (step 3) checks new claims against this list — a match gets
an acknowledgment, not re-litigation. The landing step (step 5) appends each new
acceptance.

- **`git diff --ext-diff` slips past the `git diff:*` allow rule**:
  exec-via-config is outside the permission gate's threat model.
- **testing.md's `**/*test*` glob over-matches**: the overmatch is rare and
  cheap; the user weighed it against the maintenance cost of enumerating test
  filename patterns and kept the simple glob.
- **`#plain-language` and `#explaining` both govern coined terms**: the overlap
  is deliberate. Repeating a directive at a second, sharper trigger is how an
  under-firing rule gets strengthened, and `#explaining` carries the
  session-coined-label prohibition that `#plain-language` does not.

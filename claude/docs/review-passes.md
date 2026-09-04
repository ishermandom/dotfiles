# Review passes

What a review pass covers, what becomes of its findings, and how they are
reported — the parts that stay the same whichever check the pass runs. A skill
that runs a pass supplies the check itself, and anything it wraps around these
steps.

## Scope {#scope}

The scope is everything not yet reviewed — usually the pending diff, plus any
other unreviewed work, whether or not it has been committed or pushed. Anything
the user names at invocation overrides that default scope.

## Weighing and applying findings {#weigh}

Fix the findings in the session that launched the pass. Every finding arrives as
a proposal from an agent that saw less of the work than that session has, so
evaluate each one on its merits and then accept it, refine it, or reject it.
Record every one of those decisions for the report.

## Reporting {#report}

Give every finding its resolution — accepted, refined, or rejected — with the
reasoning behind anything not applied as proposed. Judge each finding's severity
where the pass did not label it. List every high-severity finding individually;
summarize the rest when listing them all would be overwhelming. Stop there:
reviewing and fixing is the whole job, and committing is not part of it.

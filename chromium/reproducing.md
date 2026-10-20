# Reproducing user-reported bugs

Techniques for making the local build show a bug that one Chrome user sees but
others can't. Below, "the reporter" is that Chrome user, and "the user" is the
owner of this machine. Source paths are relative to the checkout at
`/Users/Shared/code/chromium`.

- **Experiment-dependent bugs**: a Chromium build fetches no server-side
  experiments (`IsFetchingEnabled` in
  `src/components/variations/service/variations_service.cc`). To match the
  reporter's state, have them open `chrome://version/?show-variations-cmd` in
  their Chrome and send the command line it shows, then launch the local build
  with those switches. That command line already includes
  `--disable-field-trial-config`, which keeps a Chromium build from layering its
  own testing experiments on top (`ShouldUseFieldTrialTestingConfig` in
  `src/components/variations/service/variations_field_trial_creator.cc`).
- **Narrowing to a feature**: on a fresh profile, launch once with no
  experiments and once with the reporter's full set, to confirm the bug depends
  on them. Then force single features on or off, as the reproduction script
  below does, to find the smallest set that still shows the bug.
- **Studies can mislead**: a study, Chromium's name for an experiment, can carry
  features its name doesn't hint at. `WebUIReloadButtonStudy`, named for the
  reload button, also carried `InitialWebUI`, `WebUILocationBar`, and
  `DeferLayoutDuringBrowserStartup`, which together caused an omnibox focus bug
  in new windows (https://issues.chromium.org/issues/571984154).
- **Reproduction script**: `/Users/Shared/transfer/repro-omnibox-focus.sh`
  launches the build with an empty profile, from either no experiments or the
  reporter's command line saved as `variations.txt` beside the script, and takes
  per-feature overrides. Its steps and logging target the omnibox focus bug; its
  header documents usage.
- **Who presses the keys**: the user, from their own account. The
  `claude-sandbox` account, where Claude runs, can't drive the browser
  interface: it lacks Accessibility, event-posting, and screen-recording
  permissions, and its graphical session runs in the background while the user's
  session owns the screen. The script writes its logs to
  `/Users/Shared/transfer/repro-logs/`, where Claude reads them.
- **Logs over a debugger for focus bugs**: pausing Chrome in a debugger would
  likely move focus to the terminal. Logs need no symbols: each log line carries
  its own file and line at any `symbol_level`, and a printed stack trace names
  its functions at any level. To add file, line, and inlined frames to a trace,
  look up its addresses with `atos -i`; that lookup needs `symbol_level` 1 or
  more.

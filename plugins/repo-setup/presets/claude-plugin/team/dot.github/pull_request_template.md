## What and why

<!-- One or two sentences. Link the intent: Closes #123 -->

## How it was verified

<!-- Tests added/changed, and what you tried with `claude --plugin-dir plugins/<name>` -->

## Human decisions needed

<!-- Anything the author (human or agent) could not decide alone. "None" if none. -->

## Checklist

- [ ] `make check` passes locally
- [ ] Tests added or updated for behaviour changes
- [ ] `CHANGELOG.md` has a line under "Unreleased" if users will notice the change
- [ ] Versions were not edited by hand (`make bump` only, in a release commit)
- [ ] New scripts or hooks say in the README what they do on the user's machine
- [ ] No secrets, credentials or personal data in the diff

<!-- The autonomy gate labels this PR risk:low / risk:medium / risk:high.
     low: agents may merge after CI + independent agent review. medium/high: a human approves. -->

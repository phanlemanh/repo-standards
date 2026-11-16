# repo-standards

A Claude Code marketplace with one plugin, `plugins/repo-setup`. Its templates are copied into
other repositories, so a change here changes what those repositories enforce.

## The rule: people decide, machines check

Read [docs/setup-principles.md](docs/setup-principles.md) before changing anything the plugin
generates. In short:

- A setup that brings a person in to make a change more reliable is not a good setup. Reliability
  comes from machines: required checks, rules read from the base branch, a proof re-checked
  before the merge.
- A person appears only where something is decided: a change to the rules of the game,
  production, a secret. Adding one more place where a person appears changes the rule itself:
  ask the owner first.
- The generated setup adds no stop of its own: no `ask` permission rules, no "get approval before
  you start", no tier used as a reason to stop.
- Walls are silent and sit where the machine cannot remove them. No deny rules on Bash patterns.

Section 43 of `tests/run.sh` fails when a change breaks the rule. Which repository owns which
question: [docs/three-repo-boundaries.md](docs/three-repo-boundaries.md).

## Working here

- `bash tests/run.sh`: fast tests, no network. Run it before saying a change is done.
- `bash tests/e2e.sh`: real installs and `make check` per combination. Needs network.
- Behaviour changes go under `## Unreleased` in `CHANGELOG.md`, with what breaks on upgrade.
- Docs in `docs/` are written in Vietnamese. Code, templates and the READMEs are in English.
- File, folder and branch names are English, also for a document written in Vietnamese. It is
  the rule every repository this plugin sets up gets (`AGENTS.md`, "Language"). No check can
  tell a Vietnamese name from an English one, so this line is what holds it: name a new file
  by the rule, not after the file next to it.

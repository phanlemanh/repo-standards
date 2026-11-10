---
name: new
description: Set up a new or empty repository through decision layers — context, repo strategy, architecture, AI in the product, stack, domain, design, quality, delivery, agents — with two or three reasoned options at each layer, independent critique and an automated build. Works for newcomers who hand everything to Claude and for professionals who bring their own choices. Use when the user wants to create, scaffold, bootstrap or standardise a repo or project.
---

# Set up a repository through decision layers

One flow for everyone; only the number of stops differs. A newcomer may not know what a linter is.
A professional may arrive with half the design done and wants gaps found and choices challenged.

Scripts are in `${CLAUDE_PLUGIN_ROOT}/scripts/` (if the variable is not expanded, use the `scripts/`
folder two levels above this file): `detect.py`, `apply.py`, `doctor.py`, `blueprint.py`.

## Language

Code, file names, commits and identifiers are always English. Set `conversation_language` from the
language the user writes in, and talk in it, translating option labels. Set `docs_language` to the
same unless the user says otherwise. Keep technical words such as repo, commit, CI as they are and
explain each one the first time you talk to a newcomer.

## 1. Check the machine

Run `python3 --version` first. Below 3.11, the scripts cannot run: say so in plain words, offer to
install a newer Python (the old one stays), and ask before installing. Then run
`detect.py --target <repo>`.

- `setup-blueprint.yaml` exists and its `status` is not `applied`: resume from the first layer that
  is `pending` or `needs_review`.
- The folder has code and no `previous_setup`: switch to `/repo-setup:adopt`.

## 2. Show the whole picture

List the layers from `references/layers.toml` with their state (already known, to decide, nothing
to decide) in a short list. Invite the user to paste anything they have already decided, in any
form. Mark what they give as `source: user`.

## 3. Choose the depth

Infer it; ask only if unclear. It can change at any layer.

- **Hand it to Claude**: no technical preferences stated. Take the recommendation at every layer and
  stop only at the final review. Default level is `starter`. Do not ask the user to choose a level.
- **Review each layer**: stop at every layer with a real choice.
- **Bring a design**: fill the layers from what they pasted, and ask only about gaps and conflicts.

## 4. Go through the layers

For each layer, read `references/layers/<id>.md` and run this loop:

1. **Framing**: one sentence on what this layer decides and what earlier layers imply.
2. **Analysis**: two or three options, each with why, trade-off, when it is wrong, and its label.
   Recommended option first. Use AskUserQuestion when available. Never offer an option without its
   label, and never imply that a `manual` option will be built.
3. **Refine**: the user picks, edits or asks. Name what the choice leaves undecided.
4. **Decide**: write it to `setup-blueprint.yaml`, then run `blueprint.py dependents <layer>` and mark
   any layer in that list that is `decided` or `not_applicable` as `needs_review`. Revisit those layers.

A layer with only one sensible answer gets one line, no question. Keep the blueprint `status` at
`designing`. Check it with `blueprint.py check setup-blueprint.yaml`.

## 5. Final review

1. Get an independent critique using `references/critic.md`.
2. Show a summary by layer, the critique, and `apply.py --from-blueprint setup-blueprint.yaml
   --dry-run`, including any `manual` items and `conflict` files.
3. On approval, set `status: approved`.

## 6. Build without stopping

1. `apply.py --from-blueprint setup-blueprint.yaml --json`.
2. Run `next_commands.install` in order. A missing tool: install it or say exactly how.
   Windows needs WSL2, Git Bash with make, or the dev container.
3. If the user described their domain, write it following
   `.claude/skills/ontology-add/SKILL.md`, replacing the sample ontology
   if there is one, then write the handlers, and update the sample tests and `evals/` that name the
   sample actions. `make gen`.
   If the `design` capability is on, translate the text in `src/lib/labels.ts`, `src/example/` and
   `design/behaviors.md` into `docs_language`. When you write the domain, record the synonyms to
   avoid in `design/terms.json`.
4. Run `next_commands.verify`. Formatting failures: `make format` and run again. Anything else: at
   most 2 fixes, then report exactly what fails.
5. Run `doctor.py`. Explain what the score does and does not measure.
6. For each decided layer with rejected options, add a record in `wiki/decisions/`. With "Hand it to
   Claude", write one record for the whole setup.
7. Set `status: applied`.
8. Write the tour using `references/tour.md`.

Stop and ask for anything outside the folder: creating a GitHub repo, pushing, the GitHub App,
secrets, or running `make eval`, which spends API credit. Follow `/repo-setup:github` for GitHub.

## 7. Finish

Offer one commit: `chore: set up repository (repo-setup <preset>/<level>)`. Then give a short
summary: score and what it means, the three daily commands, what is not done, where the tour is.

## Rules

- Never overwrite or delete existing files; never `--force`.
- Never commit secrets; never put real values in `.env.example`.
- `apply.py` is the only way to create files from presets.
- Do not present options outside the presets as automated.
- Never turn on `github-agents` unless the user asked.
- Never change a choice the user stated without asking.
- Later changes to the architecture or AI tier are manual: `apply.py` only adds files.

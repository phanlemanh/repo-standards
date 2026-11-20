---
name: doctor
description: Check any repository against the team's top-tier checklist, give a 0-100 score, explain gaps in plain language and fix them safely. Use when the user asks to audit, review, check the health of, or standardise an existing repo.
---

# Repository health check

Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/` (or `scripts/` two levels above this SKILL.md).

## Steps

1. Run `doctor.py --target <repo> --json` (add `--remote` when `gh` is authenticated and the
   repo is on GitHub: it also checks branch protection and whether CI on main is green). Without a `.repo-setup.json`, score at
   `starter` first; also run `--level team` if more than one person works on the repo.
   To use a team-specific standard, pass `--checklist <file>`.
   The report says which kind of repo it scored (`preset`, `preset_source`): the preset in
   `.repo-setup.json`, or `claude-plugin` when the repo has Claude Code plugin manifests. If that
   is wrong, pass `--preset <name>`.

2. Report to the user, in their language, for a non-expert:
   - the score and what it means (90+: excellent, 70–89: good with gaps, <70: risky);
   - the failed checks grouped as **Fix now** (weight 3), **Soon** (weight 2),
     **Nice to have** (weight 1) — each with one sentence of *why* from the checklist;
   - the manual items (secrets store; branch protection/CI when not run with `--remote`) as a
     short to-do;
   - the `not_applicable` checks, in one short block with their reason. They are not gaps: do not
     offer to fix them (for example, no ontology or lockfile for a plugin marketplace).
   - `ledgers_split`: the ledgers still kept as one hand-edited file (`log`, `index`, `glossary`,
     `gen`), each with its split command (`make split L=<ledger>`). It is a notice, never a score:
     say it in one line and leave the choice to the owner. Do not run a split unasked; each one is
     a pull request of its own.

3. Offer fixes, then act only on the ones the user approves:
   - If the stack has a preset (`detect.py` → `suggested_preset`): run
     `apply.py --preset <p> --level <l> --var ... --dry-run` and show what it would add and
     merge. A file repo-setup wrote and the repo edited since is merged with the new template
     (`merged`); where both changed the same lines it gets conflict markers (`marked`) and
     `make check` stays red until they are resolved. `base_unread` means the template the file
     came from could not be read (no network): run again online, or with `--base-from`. Files
     the repo deleted stay deleted (`removed`). Files the repo had before setup (`conflict`,
     `kept`) are left as they are; a `conflict` on an `mk/` file that joins checks to
     `make check` ends the run with 1 and names the checks left out (rename the repo's
     file, run again). Ask for project name/description/owner only if
     `.repo-setup.json` lacks them.
   - Otherwise (or for files that exist but fail a content check, e.g. tsconfig without
     `"strict": true`): make the minimal edit by hand and explain it. Turning on strict
     modes can surface many errors — warn first and offer to do it in a separate PR.

4. After changes, run the project's checks (`make check` if present) and `doctor.py` again.
   Its "Upgrade" block lists files still marked, files behind the last release, files edited
   in place and files deleted here.
   Show before → after score.

## Notes
- `env_not_committed` failing means a secret file is in git history: tell the user to
  **rotate those secrets** — removing the file is not enough.
- Doctor can be used in CI: `python3 doctor.py --min-score 90` exits non-zero below 90.

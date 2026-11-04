---
name: setup-doctor
description: Check any repository against the team's top-tier checklist, give a 0-100 score, explain gaps in plain language and fix them safely. Use when the user asks to audit, review, check the health of, or standardise an existing repo.
---

# Repository health check

Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/` (or `scripts/` two levels above this SKILL.md).

## Steps

1. Run `doctor.py --target <repo> --json` (add `--remote` when `gh` is authenticated and the
   repo is on GitHub: it also checks branch protection and whether CI on main is green). Without a `.repo-setup.json`, score at
   `starter` first; also run `--level team` if more than one person works on the repo.
   To use a team-specific standard, pass `--checklist <file>`.

2. Report to the user, in their language, for a non-expert:
   - the score and what it means (90+: excellent, 70–89: good with gaps, <70: risky);
   - the failed checks grouped as **Fix now** (weight 3), **Soon** (weight 2),
     **Nice to have** (weight 1) — each with one sentence of *why* from the checklist;
   - the manual items (secrets store; branch protection/CI when not run with `--remote`) as a
     short to-do.

3. Offer fixes, then act only on the ones the user approves:
   - If the stack has a preset (`detect.py` → `suggested_preset`): run
     `apply.py --preset <p> --level <l> --var ... --dry-run` and show which missing files
     it would add. Existing files are never overwritten; `conflict` files are left as they
     are. Ask for project name/description/owner only if `.repo-setup.json` lacks them.
   - Otherwise (or for files that exist but fail a content check, e.g. tsconfig without
     `"strict": true`): make the minimal edit by hand and explain it. Turning on strict
     modes can surface many errors — warn first and offer to do it in a separate PR.

4. After changes, run the project's checks (`make check` if present) and `doctor.py` again.
   Show before → after score.

## Notes
- `env_not_committed` failing means a secret file is in git history: tell the user to
  **rotate those secrets** — removing the file is not enough.
- Doctor can be used in CI: `python3 doctor.py --min-score 90` exits non-zero below 90.

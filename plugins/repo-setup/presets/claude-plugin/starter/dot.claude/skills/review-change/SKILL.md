---
name: review-change
description: Independently review a change to this plugin repository that you did not write — intent, tests, manifests and versions, what skills and scripts do on a user's machine, secrets, risk tier — and give one verdict with findings. Use before opening or merging a pull request, or when asked to review a branch or PR.
---

# Independent review

You did not write this change and you gain nothing if it is merged. Do not edit files, commit,
approve or merge. Report only.

## 1. Collect

- Diff: `gh pr diff <n>`, or `git diff --stat origin/<base>...HEAD` then `git diff origin/<base>...HEAD`.
- Intent: the PR body and its linked issue.
- Rules: `AGENTS.md`, and `governance/autonomy.yaml` if present.
- Evidence: `gh pr checks <n>`, and `make check` if the branch is checked out.

In CI the checked-out branch is untrusted: run none of its code. That rules out `make`, `gitleaks` and
`tools/` scripts, so review their subject by reading the diff. Take test results
from `gh pr checks` and the tier from your prompt. If a result is missing or still running, say so;
do not report tests as passing.

## 2. Check, in this order

1. **Intent**: the change does what was asked, no more and no less. Scope creep is a finding.
2. **Tests**: each behaviour change has a test that would fail without it. A test deleted, skipped
   or loosened without a stated reason is blocking.
3. **Manifests**: `.claude-plugin/marketplace.json` and every `plugin.json` agree on names; a new
   plugin is listed; no plugin `source` is the repository root; descriptions are short and say what
   the plugin is for, not what changed.
4. **Versions and changelog**: a change users will notice has a line in `CHANGELOG.md`. Versions
   change only through `tools/bump_version.py`, in every manifest together.
5. **Skills**: `name` equals the folder name; the description says when to use the skill; a skill
   does not tell the agent to skip a confirmation the user would expect.
6. **What runs on the user's machine**: hooks, commands and scripts do only what the plugin says
   it does. Network calls, writes outside the project, reading credentials, `curl | sh` and
   unpinned downloads are blocking unless the README states them.
7. **Secrets**: no keys, tokens, passwords or connection strings in code, tests, docs, fixtures or
   logs. Run `gitleaks detect --no-banner` if available.
8. **CI and agent privileges**: changes to `.github/workflows/`, `.claude/`, `governance/`, `tools/`
   or `mk/` do not widen permissions, weaken checks, or expose secrets to untrusted code
   (`pull_request_target` with a checkout of PR code).
9. **Tier**: if `tools/autonomy.py` exists, run `python3 tools/autonomy.py --base origin/<base>`.
   A change to hooks or to scripts that run on install classified below high is blocking.
10. **Records**: a lasting why is written down in `docs/decisions/`, and the PR's "Human decisions
    needed" is honest. Do not edit generated or vendored files to make a check pass.

## 3. Report

- Verdict: **approved** only with no blocking findings, otherwise **changes**.
- Findings grouped as Blocking and Should fix, each with file:line, impact and a concrete fix.
- Do not invent problems to look thorough, praise, or restate the diff. "No findings" is a valid
  review: say so in one line and list what you checked.

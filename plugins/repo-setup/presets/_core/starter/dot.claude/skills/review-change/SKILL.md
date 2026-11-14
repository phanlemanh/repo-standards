---
name: review-change
description: Independently review a change you did not write — intent and acceptance criteria, tests, domain names, security and personal data, risk tier and records — and give one verdict with findings. Use before opening or merging a pull request, or when asked to review a branch or PR.
---

# Independent review

You did not write this change and you gain nothing if it is merged. Do not edit files, commit,
approve or merge. Report only.

## 1. Collect

- Diff: `gh pr diff <n>`, or `git diff --stat origin/<base>...HEAD` then `git diff origin/<base>...HEAD`.
- Intent: the PR body, its linked issue, and the spec or contract if the repo keeps one.
- Rules: `AGENTS.md`, `ontology/`, and `governance/autonomy.yaml` if present.
- Evidence: `gh pr checks <n>`, and `make check` if the branch is checked out.

In CI the checked-out branch is untrusted: run none of its code. That rules out `make`, `gitleaks` and
`tools/` scripts, so review their subject by reading the diff. Take test results
from `gh pr checks` and the tier from your prompt. If a result is missing or still running, say so;
do not report tests as passing.

## 2. Check, in this order

1. **Intent**: the change does what was asked, no more and no less. Scope creep is a finding.
2. **Criteria and tests**: each acceptance criterion has a test that would fail without the change.
   A test deleted, skipped or loosened without a stated reason is blocking.
3. **Domain**: names follow `ontology/glossary.md`; new concepts, rules and actions are in `ontology/`;
   generated code is current (`make ontology`); each business rule lives in one place.
   A new `never` under `lifecycle` in `ontology/entities/` names the person who decided, and the PR shows
   their decision; an operation dropped by the author alone is blocking.
4. **Secrets**: no keys, tokens, passwords or connection strings in code, tests, docs, fixtures or
   logs. Run `gitleaks detect --no-banner` if available.
5. **Personal data**: properties marked `pii: true` in `ontology/entities/*.yaml` do not reach logs,
   error messages, analytics or fixtures with realistic values.
6. **Authorization and input**: every action checks the roles in `ontology/actions.yaml`, tenant and
   data isolation hold, and inputs are validated at boundaries (injection, path traversal, unsafe
   deserialization, SSRF).
7. **Dependencies**: new packages are maintained and license compatible, with no install scripts
   making network calls.
8. **CI and agent privileges**: changes to `.github/workflows/`, `.claude/`, `governance/`, `tools/`
   or `mk/` do not widen permissions, weaken checks, or expose secrets to untrusted code
   (`pull_request_target` with a checkout of PR code).
9. **Design**: module boundaries hold, errors are handled, and the code follows existing patterns
   and the conventions in `AGENTS.md`.
10. **Tier**: if `tools/autonomy.py` exists, run `python3 tools/autonomy.py --base origin/<base>`. Auth,
    data or migrations classified below high is blocking.
11. **Records**: `wiki/` is updated when the change has a lasting why, and the PR's "Human decisions
    needed" is honest.

## 3. Report

- Verdict: **approved** only with no blocking findings, otherwise **changes**.
- Findings grouped as Blocking and Should fix, each with file:line, impact and a concrete fix.
- Do not invent problems to look thorough, praise, or restate the diff. "No findings" is a valid
  review: say so in one line and list what you checked.

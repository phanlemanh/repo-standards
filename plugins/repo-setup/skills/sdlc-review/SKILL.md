---
name: sdlc-review
description: Review a pull request or branch you did not write, as the independent agent reviewer of the AI-native SDLC — spec and acceptance criteria, tests, ontology consistency, security, tier — and give a single verdict. Use in the PR pipeline, or when asked to review a PR or a colleague's change.
---

# Independent review

You did not write this change and you gain nothing if it is merged. Read-only: never edit,
commit, approve or merge.

## 1. Collect
- Diff: `gh pr diff <n>` or `git diff origin/<base>...HEAD`; PR body: `gh pr view <n>`.
- Intent and spec: the linked issue (`Closes #n`) and `wiki/specs/NNNN-*.md`.
- Rules: `AGENTS.md`, `ontology/`, `governance/autonomy.yaml`.
- Evidence: CI status (`gh pr checks <n>`); run `make check` yourself if the PR is checked out.

## 2. Check, in this order (stop at the first blocker category and report it)
1. **Intent**: the change does what the spec says — no more (scope creep), no less.
2. **Acceptance criteria → tests**: every criterion has a test that would fail without the change.
   Tests deleted or weakened = blocker unless the spec explains why.
3. **Domain**: names follow the glossary; ontology changed when concepts/actions/rules changed;
   generated code is current (`make ontology`); the spec's Domain impact is accurate.
4. **Security & data**: no secrets; personal data (`pii: true` properties) not logged or exposed
   beyond permissions; authorization enforced for every action; inputs validated.
5. **Design**: module boundaries respected; no duplicate rule implementations; errors handled.
6. **Tier**: the risk label is plausible for what changed; flag anything that should be higher.
7. **Records**: wiki log/decision/entity pages updated; PR "Human decisions needed" is honest.

## 3. Report
- Inline comments for specific lines; one summary comment with: verdict, blockers (numbered,
  each with file:line and why), non-blocking suggestions (max 5).
- Verdict: **approved** only if there are no blockers. In CI set exactly one label as the
  workflow prompt says (`agent-review:approved` or `agent-review:changes`).
- Do not invent problems to look thorough; "no findings" is a valid review.

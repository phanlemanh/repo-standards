---
name: sdlc-run
description: Take a feature, fix or change request from intent to a reviewed pull request in an AI-native way — spec, autonomy gate, tests first, implementation, independent review, wiki — stopping only where a human decision is required. Use when the user asks to build, add, fix or change something in a repo set up with repo-setup.
---

# AI-native delivery: intent → pull request

You do the work; the human stays at the edges: **intent**, **risky decisions**, **merge of
medium/high changes**, **production**. Everything else you do and prove with checks.

## 0. Orient (silently)
Read `AGENTS.md` (SDLC section), `wiki/index.md`, `governance/autonomy.yaml` (team level).
Make sure the working tree is clean and you are not on the default branch.

## 1. Intent
Restate the intent in one sentence and list **acceptance criteria** as observable checks
(Given / When / Then). Ask the human only what blocks a testable criterion — once, briefly.
If the request came from an issue, read it with `gh issue view <n>`.

## 2. Spec → follow **sdlc-spec**
It writes `wiki/specs/NNNN-*.md` and computes the expected tier.
- tier **low/medium** and nothing in "Open questions": continue.
- tier **high** (ontology, auth, data, infra, CI, agent rules): present the spec summary and
  ask the human to approve it. Do not touch high-tier files before that. (The PreToolUse gate
  will ask for approval on each such edit anyway.)

## 3. Build → follow **sdlc-implement**
Branch, tests first from the acceptance criteria, implementation, `make check` green,
ontology changes via **ontology-add**.

## 4. Independent review
Spawn the `code-reviewer` subagent (and `security-reviewer` when the change touches auth,
personal data, secrets, infra or workflows). Give them only: the spec path, the base branch,
and "review this change". Fix every blocking finding, re-run `make check`, review again if the
fixes were significant. Never review your own work in your own context.

## 5. Record → follow **wiki-ingest**
Log line, decision page for any new technical choice, entity pages for domain changes;
set the spec `status: implemented`.

## 6. Hand-off
- Push the branch and open the PR with `gh pr create` (template sections filled; "Closes #n").
  Without `gh`/remote, show the branch name and the PR text instead.
- Report to the human in 5–8 lines: what changed, evidence (tests, checks, reviewer verdict),
  tier, and **Human decisions needed** (or "none").
- Never merge medium/high PRs, never approve your own PR, never deploy to production.

## Stop and ask when
- an acceptance criterion is ambiguous or contradicts the ontology;
- the plan needs a high-tier change that the human has not approved;
- `make check` still fails after two honest attempts;
- you would need to delete data, rewrite history, change CI/governance, or weaken a test.

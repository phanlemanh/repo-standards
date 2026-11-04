---
name: sdlc-spec
description: Turn an intent (issue or request) into a reviewable spec in wiki/specs — acceptance criteria, domain impact, plan, test plan and autonomy tier — and decide whether a human must approve it before implementation. Use when the user or an issue asks for a spec, a plan for a feature, or when sdlc-run reaches the spec step.
---

# Write the spec

A spec is the contract between the human edge and the agents. Short, testable, honest.

## 1. Gather
- The intent: issue body/comments (`gh issue view <n> --comments`) or the user's words.
- The domain: `ontology/glossary.md`, relevant `ontology/entities/*.yaml`, `ontology/actions.yaml`
  (if present), related `wiki/` pages (decisions, flows, incidents).
- The code paths likely to change (search; do not guess).

## 2. Write `wiki/specs/NNNN-short-title.md`
Next free number; kebab-case title. Front matter:

```yaml
---
type: spec
title: <short title>
status: draft            # draft | needs-approval | approved | implemented | dropped
tier: <low|medium|high>  # from step 3
issue: <number or "none">
links: [<ontology/entities/X.yaml>, <wiki/entities/x.md>, ...]   # repo-relative, must exist
sources: [<"issue #n", "user, YYYY-MM-DD">]
---
```

Sections (all required, `## ` headings): **Intent** (one paragraph, the why) ·
**Acceptance criteria** (numbered Given/When/Then; each becomes ≥1 test) ·
**Domain impact** (entities/properties/actions/rules added or changed, or "none") ·
**Plan** (files/modules, steps, migration if any) · **Test plan** (criterion → test name/file) ·
**Autonomy tier** (tier and why, list of high-tier paths) ·
**Open questions** (only real ones; "none" otherwise).

Link it from `wiki/index.md` under Specs. Run `python3 tools/wiki_lint.py`.

## 3. Compute the tier
List the paths the plan will touch and run
`python3 tools/autonomy.py --files <paths...>` (team level). Without a policy file, treat
`ontology/`, migrations, auth, CI and infra as high.

## 4. Gate
- **high**, or any Open question → `status: needs-approval`. On an issue: post the spec
  (`gh issue comment <n> --body-file <spec>`), add the label `spec:needs-approval`, stop.
  Interactive: show the summary and ask the human to approve; on approval set `status: approved`
  and add `approved_by: <human>` to the front matter.
- **low/medium** with no open questions → `status: approved` (self-approved is fine at these
  tiers; the PR is still reviewed).

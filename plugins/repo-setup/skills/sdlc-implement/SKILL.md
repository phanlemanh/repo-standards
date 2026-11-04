---
name: sdlc-implement
description: Implement an approved spec as a small, test-first change on its own branch, with make check green, ontology and wiki updated, an independent agent review and a pull request with evidence. Use for issues labeled agent:implement or spec:approved, or when sdlc-run reaches the build step.
---

# Implement a spec

## 1. Preconditions
- The spec exists in `wiki/specs/` with `status: approved` (or the run was started by a human's
  `spec:approved` label). If it is missing, write it first (sdlc-spec).
- Branch from the up-to-date default branch: `agent/<issue>-<slug>` (or `feat/<slug>` locally).
  Never work on the default branch.

## 2. Tests first
For each acceptance criterion write the test(s) named in the Test plan. Run them and see them
fail for the right reason. Commit: `test: <criterion summary>`.

## 3. Implement
- Domain changes first, through **ontology-add** (glossary, entities, actions, relations),
  then `make gen`. Use the generated types and action definitions; never hand-edit generated files.
- Smallest change that makes the tests pass. Follow existing patterns and module boundaries
  (`make check` enforces them in modular-monolith repos).
- Commit in logical steps with Conventional Commits (`feat:`, `fix:`, `refactor:`...).

## 4. Verify
- `make format` then `make check` until green. Do not skip, weaken or delete tests to get
  there; if a test is wrong, say so in the PR and let the human decide.
- Check the real tier: `python3 tools/autonomy.py --base origin/<default> --head HEAD`.
  If it is higher than the spec said, update the spec and follow its gate rule.

## 5. Independent review
Run the `code-reviewer` subagent (plus `security-reviewer` for auth/data/secrets/infra/CI).
Address every blocking finding. Mention non-blocking ones in the PR.

## 6. Record
`wiki/log.md` line; decision page for new technical choices; entity pages for domain changes;
spec `status: implemented`. `python3 tools/wiki_lint.py` clean.

## 7. Pull request
`git push -u origin <branch>` then `gh pr create --title "<conventional title>" --body-file <file>`
using `.github/pull_request_template.md`: What and why (Closes #n), Spec, How it was verified
(criterion → test, check results, reviewer verdict), **Human decisions needed**, checklist.
Do not merge; the PR pipeline labels the tier, reviews again, and merges only low-tier changes.

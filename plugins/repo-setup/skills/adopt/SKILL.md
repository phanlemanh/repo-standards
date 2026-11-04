---
name: adopt
description: Bring an existing codebase up to the top-tier standard step by step — without breaking it, replacing its tools, or adding sample code — including AGENTS.md/CLAUDE.md, ontology/ and wiki/ seeded from the real code. Use when the user wants to standardise, modernise, clean up or make AI-ready a repo that already has code.
---

# Adopt the standard in an existing repository

Existing code has history and working tools. Your job is to add what is missing and
reconcile what overlaps, in small reviewable steps, never to impose a rewrite.

Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/` (or `scripts/` two levels above this SKILL.md).

## 1. Baseline
- `detect.py --target <repo>` → stack, tools, previous setup.
- `doctor.py --target <repo> --json` (and `--level team` for shared repos) → score before.
- Make sure the working tree is clean (`git status`). If not, ask the user to commit or
  stash first, so every change you make is reviewable on its own.
- Suggest a branch: `chore/adopt-repo-standard`.

## 2. Interview (short)
Same as `/repo-setup:new` (name, description, owner, license — read them from package.json /
pyproject / README / git remote first and only confirm), plus:
- Which level (`starter` / `team`)?
- Anything that must not change (deploy pipeline, a custom lint config, a release tool)?

If the stack has no preset (Go, Rust, Java…), skip to step 5 and work from the doctor list.

Pick archetype / capabilities / deploy target the same way as `/repo-setup:new` (purpose questions,
`apply.py --list-options`), but only when the existing code already has that shape — e.g. do
not add `modular-monolith` to a codebase without modules; propose it as a later refactor.

## 3. Plan with --adopt
Run `apply.py --target <repo> --preset <p> --level <l> --adopt --var ... --dry-run --diff --json`.
Explain the plan in plain words:
- **created**: missing files that will be added;
- **skipped**: preset files not added because the repo already has an equivalent
  (e.g. its own `.eslintrc`) or because they are sample code;
- **merged**: `.gitignore` / `.gitattributes` get only the missing lines;
- **conflict / kept**: existing files left exactly as they are.
Ask for the go-ahead, then run without `--dry-run`.

## 4. Reconcile what the preset could not add mechanically
Do these by hand, one at a time, each with the user's OK, and keep the repo's tools:
- **Makefile targets** (`setup lint typecheck test gen ontology check`): if the repo has
  no Makefile, the preset's one calls npm scripts / uv commands that may not exist yet —
  add the missing scripts (e.g. `"typecheck": "tsc --noEmit"`) or adapt the targets to
  the tools the repo already uses (jest instead of vitest, poetry instead of uv…).
- **Python**: add `[tool.ruff]`, `[tool.mypy]`, `[tool.pytest.ini_options]` to the existing
  `pyproject.toml` only if the repo has no equivalent config.
- **Strictness**: turning on `strict` (tsconfig/mypy) or a new linter in an old codebase can
  produce hundreds of errors. Measure first (run it once, count), then propose: enable now
  and fix, enable with a baseline/ignore list, or schedule as a separate PR. Never mass-edit
  code just to silence a new rule without asking.
- **CI**: if the repo has its own workflow, add `make check` (or the missing steps) to it
  instead of a second pipeline.
- **AGENTS.md / CLAUDE.md**: if one already exists, merge the preset's sections
  (commands, rules, after-a-task) into it instead of replacing it.

## 4b. Decisions

Use the layers in `../new/references/layers/` for anything the user wants to decide, and
record them in `setup-blueprint.yaml`. The `ai` layer is always `manual` here: do not add the `ai`
capability, because it would add sample code. Guide the user through adding what they need.

## 5. Seed the domain model from the real code
Read the main models/schemas/types (ORM models, DB migrations, API schemas). Propose the
3–7 core entities with definitions, properties and relations, confirm with the user, then
write them following `.claude/skills/ontology-add/SKILL.md` (glossary, `ontology/entities/*.yaml`,
`relations.yaml`, `wiki/entities/*.md`). Record the adoption itself as
`wiki/decisions/0002-adopt-repo-standard.md` and a line in `wiki/log.md`.
Do not replace existing hand-written types with generated ones in this PR — note it as a
follow-up.

## 6. Verify and report
- Run the preset install commands that apply (lockfile already present → `make setup`).
- `make check` must pass, or every remaining failure is explained with a plan.
- `doctor.py` again: show the score before → after and what is left.
- Offer one commit per logical step (config, CI, docs/agent guide, ontology+wiki) so the
  PR is easy to review.

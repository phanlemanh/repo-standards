# Changelog

## Unreleased

### Plugin marketplaces
- New stack preset `claude-plugin` for repositories that ship Claude Code plugins: a marketplace
  manifest, one sample plugin with a skill, `tools/plugin_lint.py`, `tools/bump_version.py` (every
  manifest and the changelog in one command), shell tests, a `Makefile`, a pinned Node version and
  CI that runs `make check` and `claude plugin validate`. No `package.json`, type checker, linter
  config, `.env.example`, ontology or wiki. Level `team` publishes a GitHub Release per version tag.
- `detect.py` suggests `claude-plugin` when it finds plugin manifests, and lists the plugins.
- `doctor` scores a repo as its kind: the preset in `.repo-setup.json`, plugin manifests it
  detects, or `--preset`. Checks that do not fit are listed under "not applicable" with the reason
  and are not scored. For a plugin marketplace these are the lockfile, formatter and linter, strict
  types, `.env.example`, ontology, wiki and coverage threshold; the first three apply again when
  the root has a `package.json`, `pyproject.toml` or `tsconfig.json`.
- New checks for plugin repos: manifests parse and agree on names; versions agree across manifests,
  unless `--var plugin_versioning=independent`; no plugin uses the repository root as its source;
  descriptions stay within 1024 characters; a bump tool, a changelog and a CI step that validates
  manifests exist; with `--remote`, version tags have GitHub Releases.
- The layers architecture, AI, domain and delivery are recorded as not applicable for this stack,
  each with a reason; `blueprint.py not-applicable <preset>` lists them and `check` rejects a
  blueprint that would build one.
- `apply.py` reports `not_applicable` (what a preset leaves out of the shared core, and why).

### Changes
- `--adopt`: a file of the repo's own at a sample path (for example `tests/run.sh`) is now listed
  as skipped, no longer as a conflict. Nothing is written in either case.
- A repository with plugin manifests and no `.repo-setup.json` is now scored as `claude-plugin`.
  Its score changes; pass `--preset <name>` to score it as something else.

### Fixes
- `pr-pipeline.yml` (`github-agents`): the reviewer accepts PRs opened by `claude[bot]`; before, its
  run failed and low-tier auto-merge never happened. A custom bot in `AGENT_AUTHORS` must also be
  added to `allowed_bots`.
- The reviewer no longer runs PR code in a job that holds tokens: no dependency install, no `make`,
  no MCP servers from the repo. It reads test results from `gh pr checks`.
- The gate keeps its base-branch rules in `$RUNNER_TEMP`, so a PR cannot plant `.gate/yaml.py` and
  run code in the job that sets the risk tier.

Re-apply to get these. The reviewer and its inline comments have not yet run on GitHub.

## 0.4.0 — 2026-11-05

### Breaking
- The plugin now stops at setup. Removed the skills `sdlc-run`, `sdlc-spec`, `sdlc-implement` and
  `sdlc-review`, the subagents `code-reviewer` and `security-reviewer`, and all three hooks.
- `ontology-add`, `wiki-ingest`, `wiki-query` and `wiki-health` moved into each generated repo's
  `.claude/skills/`, with a new `review-change`. Run `apply.py` again to get them in an existing repo;
  they are called as `/ontology-add`, no longer `/repo-setup:ontology-add`.
- Agent workflows no longer install the plugin in CI, and `github_setup.py` has no `--marketplace`.
  High-tier edits in CI now rest on the agent's instructions and the merge gate, because the edit
  gate left with the hooks. The variable `REPO_SETUP_MARKETPLACE` can be deleted.
- Skills renamed: `/repo-setup:new`, `adopt`, `doctor`, `explain` and `github` replace `setup-new`,
  `setup-adopt`, `setup-doctor`, `setup-explain` and `sdlc-github-setup`.
- Level `team` no longer includes agent workflows. New repos enable them with
  `--with github-agents`. Repos whose manifest lists the agent workflows keep the capability
  automatically on re-apply, with a note.
- `agent: confirm`: over HTTP, role `agent` now gets 403. MCP tools carry
  `_meta["anthropic/requiresUserInteraction"]`, which Claude Code enforces; other clients may not.
- `agent: forbidden` now also holds in `can()`, and wiki-lint rejects it combined with role `agent`.

### Guided setup
- `new` goes through nine decision layers at three depths, with labelled options
  (`automated`, `partial`, `manual`), an independent critique and a tour file.
- `setup-blueprint.yaml` and `apply.py --from-blueprint`; `doctor` reports drift and manual steps.
- Generated repos state a language rule in `AGENTS.md`; the glossary has a display name column.

### AI in the product
- Capability `ai` with tiers `call`, `workflow` and `agent`, using the official Anthropic SDK.
  `make eval` is separate from `make check`. The agent tier builds tools from the ontology.

### Fixes
- Tier classification: renames judge the old path, non-ASCII paths match, added skip markers count
  as weakening tests; nested agent config and `conftest.py` are high tier.
- Project names with accents give ASCII slugs. Clear error on Python below 3.11.
- `doctor` rejects hollow policies and pipelines and flags local-only scores.
- Python bytecode ignored in TypeScript presets; `.gitleaks.toml` allows manifest hashes; no
  credentials in the `.env.example` sample; tests run on macOS.

### Verified
- Offline suite, manifest validation and the end-to-end combinations in CI on the merged code; run
  by hand: `fastapi:service-api:container:github-agents`. A repo generated before the split picks up
  the five project skills and updated workflows on re-apply, with no conflicts.
- Not yet run: the agent workflows on GitHub, the renamed skills in a live Claude Code session, and
  the scenarios in `tests/scenarios/guided-setup.md`.

## 0.3.0 — 2026-11-04

### AI-native SDLC (humans at the edges)
- `governance/autonomy.yaml` + `tools/autonomy.py`: low / medium / high tiers by path, test
  deletions and dependency updates; CODEOWNERS generated from the policy (`make governance`).
- GitHub workflows (team): intent issue → spec → PR (`agent-implement`), `@claude` mentions,
  PR pipeline (tier label from the base-branch rules, independent agent review, auto-merge of
  low tier only), red-main fixer, weekly maintenance + delivery metrics, release → staging →
  production with a human gate. Intent issue form, PR template with "Human decisions needed".
- `.claude/settings.json`: secrets unreadable; workflows/governance not editable; no
  force-push or push to main; ask before merge/approve/release.
- PreToolUse hook: human approval for every edit to a high-tier file (CI: only when a person
  added `spec:approved`).
- Skills `sdlc-run`, `sdlc-spec`, `sdlc-implement`, `sdlc-review`, `sdlc-github-setup`;
  subagents `code-reviewer`, `security-reviewer`; wiki page types `spec`, `metrics`.
- `tools/github_setup.py` (labels, environments, ruleset, variables; dry run by default),
  `tools/sdlc_metrics.py` (DORA + agent numbers).

### Ontology → actions, roles, personal data
- `ontology/actions.yaml`, `ontology/roles.yaml`, `pii: true`; wiki-lint validates them.
- Codegen: `ActionHandlers`, `ACTIONS` with JSON schemas, `can()`, `redactPII()` (TS + Python).
- Capability `mcp`: MCP server exposing agent-allowed actions as tools, with permission checks,
  input validation, PII redaction and confirm markers (TS SDK, Python SDK 2.x).

### Configuration axes
- Archetypes `service-api` (OpenAPI generated from actions, `POST /v1/actions/{name}`, API keys →
  roles, breaking-change check) and `modular-monolith` (`architecture/modules.yaml`, boundary
  checker for TS and Python).
- Deploy target `container` (multi-stage, non-root, healthcheck, compose, push + rollout).
- Composition engine: `+file/` fragments, `mk/*.mk` targets joining `make check`,
  `[var=value]` conditions also for install commands, `--with` capabilities, `--list-options`.
- Interview asks about needs (who uses it, how big, agents?) and maps them to the axes.
- Doctor: checks per archetype, capability and deploy target; SDLC checks.

### Verified
- Offline suite plus end-to-end runs of the 5 stacks and 4 archetype combinations at team level
  (install, lint, strict types, tests with coverage thresholds, build, pre-commit, commit-msg
  hook, doctor 100/100); MCP and HTTP layers tested with a sample domain (roles, PII); all
  generated workflows pass actionlint.

## 0.2.0 — 2026-11-03

### Ontology + wiki machinery
- `tools/` vendored into every repo: `wiki_lint.py` (structure, links, page types, entity
  references, glossary coverage), `ontology_codegen.py` (TypeScript interfaces / Python
  dataclasses + subtype predicates from `ontology/entities/*.yaml`), shared YAML reader.
- `make gen` and `make ontology`; `make check` now fails when the wiki/ontology is broken or
  generated code is stale.
- New skills: `ontology-add`, `wiki-ingest`, `wiki-query`, `wiki-health`.

### Claude Code hooks
- SessionStart adds the repo map to Claude's context; Stop runs `make check` when code changed
  (blocks up to 3 times while red) and reminds once to update the wiki. Silent in other repos;
  can be turned off per repo or per session.

### Existing repositories and choices
- `setup-adopt` skill and `apply.py --adopt`: no sample code, skips files when an equivalent
  tool config exists, merges `.gitignore`/`.gitattributes` lines.
- License choice: MIT, Apache-2.0 or Proprietary (also sets package.json / pyproject license).
- `AGENTS.md` holds the agent guide (read by any agent); `CLAUDE.md` imports it.

### More of the top-tier standard
- Team level: coverage thresholds, commit-message hook + PR-title check (Conventional
  Commits), dev container. Doctor checks for each.
- `doctor.py --remote`: branch protection / rulesets and latest CI status via `gh`.

### Presets
- Preset inheritance (`extends`), conditional files (`[var=value]/`), `exclude`.
- New: `fastapi`, `ts-api` (Fastify), `react-vite`. All five pass end-to-end tests at team level.

### Tooling
- `tools/bump_version.py`; offline tests cover adopt mode, licenses, ontology tools and hooks.

## 0.1.0 — 2026-11-03

- Plugin `repo-setup` with skills `setup-new`, `setup-doctor`, `setup-explain`.
- Presets `ts-node` and `python`, each with `starter` and `team` levels.
- Core layer for every repo: README, LICENSE, editor/git config, `.env.example`,
  `CLAUDE.md`, `ontology/` (glossary, entity template, relations, page types) and
  `wiki/` (index, log, first decision record).
- `scripts/apply.py`: never overwrites, idempotent, remembers setup in `.repo-setup.json`,
  safe starter → team upgrade.
- `scripts/doctor.py`: 0–100 score against `checklists/top-tier.toml` (27 scored checks + manual reminders).
- Verified end to end: both presets reach 100/100 at team level with lint, strict type check,
  tests, build and pre-commit hooks passing.

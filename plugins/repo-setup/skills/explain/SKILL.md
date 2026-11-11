---
name: explain
description: Explain, in plain language, any file, tool or rule that repo-setup added (Makefile, lockfile, pre-commit, gitleaks, CODEOWNERS, ontology, wiki, CI…) and help when a check blocks a commit or a PR. Use when the user asks what something in the repo setup is, why it exists, or why their commit/CI failed.
---

# Explain the repository setup

The person asking is probably not an expert. Explain like a patient senior colleague.

## How to answer

1. Find the thing they ask about: open the file, and look up the matching check in
   `${CLAUDE_PLUGIN_ROOT}/checklists/top-tier.toml` (or `checklists/` two levels above
   this SKILL.md) — its `why` is the team's official reason.
2. Answer in this shape, in the user's language, short:
   - **What it is** — one sentence, with an everyday analogy if it helps.
   - **Why we have it** — the problem it prevents.
   - **What you need to do** — usually nothing, or one command.
3. If something **blocked them** (pre-commit hook, CI job, lint error):
   - read the actual error output (ask them to paste it, or re-run the command);
   - explain the cause in one line; give the fix command (`make format`, `make check`…);
   - for gitleaks findings: never suggest bypassing; if a real secret was committed,
     it must be removed and **rotated**; if it is a false positive, show how to add a
     `gitleaks:allow` comment or a `.gitleaksignore` entry.
   - Never recommend `--no-verify` or disabling a check as the fix.

## Quick reference

| Thing | Plain-language meaning |
| --- | --- |
| `Makefile` | A menu of shortcuts: `make check` runs everything CI runs |
| lockfile (`package-lock.json`, `uv.lock`) | Exact versions of every library, so all machines install the same |
| `.nvmrc` / `.python-version` | Which runtime version this project uses |
| linter / formatter | Spell-checker and auto-layout for code |
| strict type checking | Catches "wrong kind of value" bugs before running |
| CI (`.github/workflows/ci.yml`) | GitHub runs the checks on every push / PR |
| pre-commit | The same checks, on your machine, before each commit |
| gitleaks | Blocks passwords/API keys from being committed |
| Dependabot | Opens small PRs to keep libraries up to date |
| CodeQL | Automatic security review of the code |
| CODEOWNERS | Who is asked to review which folders |
| release-please | Writes the CHANGELOG and version numbers from commit messages |
| `AGENTS.md` / `CLAUDE.md` | Onboarding guide for AI agents (CLAUDE.md imports AGENTS.md) |
| `tools/wiki_lint.py` | Checks the wiki and ontology for broken links, unknown concepts, missing sections |
| `make gen` / generated types | Code types written from `ontology/`; never edit them by hand |
| coverage threshold | Tests must exercise at least ~80% of the code, or CI fails |
| commit-msg hook / PR title check | Messages must look like `feat: ...` / `fix: ...` (for automatic versions) |
| `.devcontainer/` | A ready-made dev environment (VS Code / Codespaces), handy on Windows |
| `ontology/` | The dictionary + map of business concepts (one meaning for everyone) |
| `wiki/` | Why things are the way they are: decisions, incidents, notes |
| `.repo-setup.json` | Remembers how the repo was set up, so upgrades are safe |
| `governance/autonomy.yaml` | Which changes agents may merge alone (low), which need a person (medium/high) |
| `risk:low/medium/high` label | The tier the PR pipeline computed for this PR from the files it changes |
| "needs approval" when an agent edits a file | The gate hook: that file is high-tier; approve the edit or the spec |
| `wiki/specs/` | Agent-written plan of a change, with acceptance criteria; humans approve risky ones |
| `ontology/actions.yaml` / `roles.yaml` | What can be done in the system, and who may do it (people and AI agents) |
| `pii: true` | Personal data: masked in what agents receive, for top-level fields only. Logs are not masked for you, so keep personal data out of them |
| `.mcp.json` / `make mcp` | Lets Claude and other agents use the system's actions as tools, with permission checks. Confirmation for `agent: confirm` depends on the client: Claude Code enforces it |
| `pyproject.toml` | The Python project's declaration: dependencies and tool settings |
| `.coveragerc` | How much code the tests must exercise before CI fails |
| `.gitleaks.toml` | Secret scanner settings. It only allows file hashes in the repo-setup manifest. Changing it needs a person |
| `setup-blueprint.yaml` | The decisions taken during setup, with reasons and rejected options |
| `docs/START-HERE.md` | The tour: what was built, what runs by itself, what is not done |
| `evals/` / `make eval` | Tasks that test AI features against the real API. Costs money, so not in `make check` |
| `ai_tier` | How much AI the product uses: one call, a workflow, or an agent |
| `github-agents` | Optional capability: agents work from GitHub issues and open PRs |
| `contracts/openapi.json` | The API contract, generated from the ontology; CI blocks breaking changes |
| `architecture/modules.yaml` | Business modules and who may depend on whom; CI checks imports |
| `Dockerfile` / `compose.yaml` | How the app is packaged and run as a container |
| `.claude-plugin/marketplace.json` | The list of plugins a repository offers to Claude Code, and where each one lives |
| `plugins/<name>/.claude-plugin/plugin.json` | One plugin's own card: name, version, short description |
| `tools/plugin_lint.py` / `make lint` (plugin repos) | Checks that those files are valid and agree on names and versions |
| `tools/bump_version.py` / `make bump` | Sets the next version in every manifest at once and dates the changelog |
| "not applicable" in `doctor` | A check that does not fit this kind of repo; it is listed with its reason and not scored |

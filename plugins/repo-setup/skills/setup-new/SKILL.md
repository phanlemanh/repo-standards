---
name: setup-new
description: Set up a new (or empty) repository to a top-tier standard — README, lint/format, strict types, tests, CI, security, CLAUDE.md, ontology/ and wiki/ — through a short interview, with no prior expertise needed. Use when the user wants to create, scaffold, bootstrap or standardise a repo or project.
---

# Set up a repository to a top-tier standard

You are guiding someone who may NOT know what a linter, lockfile or CI is.
Your job: ask a few plain-language questions, make every technical choice for them
using the presets, show the plan, apply it safely, prove it works, and explain the result.

Talk to the user in their language. Keep technical words to a minimum and explain any you use.

## Where the tools are

Scripts live in `${CLAUDE_PLUGIN_ROOT}/scripts/` (if the variable is not expanded,
use the `scripts/` folder two levels above this SKILL.md). All need only Python 3.11+.

- `detect.py --target DIR` — what is in the folder, which tools are installed (JSON)
- `apply.py --target DIR --preset P --level L --var k=v ... [--dry-run] [--diff] [--json]`
- `doctor.py --target DIR [--level L] [--json]` — score against `checklists/top-tier.toml`

Never write the scaffold files by hand: always go through `apply.py`, so results are
consistent and re-runnable.

## Steps

### 1. Detect
Run `detect.py --target <repo>` (default: current directory). Note:
- `is_empty`, `has_git`, `previous_setup` (already set up before → this is an upgrade),
- `suggested_preset`, `unsupported_stack`,
- missing tools (`node`/`npm` for ts-node, `uv` for python, `pre-commit` for team level).

If the folder already has code (not `is_empty`, no `previous_setup`), switch to the
**setup-adopt** skill: it avoids sample code and duplicate tool configs.

### 2. Interview (purpose first; at most two rounds of up to 4 questions)
Use AskUserQuestion when available; otherwise ask in one short message. Ask about **needs**,
never about architecture names; map the answers yourself with `apply.py --list-options`
(each option has `description`, `stacks`, `when`, `complexity`). Skip what detection answered.

Round 1 — what is being built:
1. **Name and one-sentence description** (free text).
2. **Who uses it?** people through a UI / other apps, partners or AI agents through an API /
   it runs as a tool, library or job.
3. **How big will it get?** one small team and one deployable app / several domains that
   should stay independent / not sure.
4. **Level**: `starter` (solo, small) or `team` (shared, long-lived: pre-commit, security
   scans, coverage, dev container, CODEOWNERS, releases, and the **AI-native SDLC**: autonomy
   policy, agent workflows on GitHub, independent agent review). Recommend `team` when more
   than one person, or any AI agent on GitHub, will work on it.

Map the answers (explain the choice in one line each):
- **stack**: Python API → `fastapi`; TypeScript API → `ts-api`; web front-end → `react-vite`;
  library/CLI/worker → `python` or `ts-node` (pre-select `suggested_preset`).
- **archetype**: consumed through an API (incl. agents) → `service-api`; several domains in
  one app → `modular-monolith`; small single-purpose app → none. Do not pick an archetype the
  answers do not justify; say it can be added later by re-running apply.
- **capabilities**: AI agents should operate the system → `--with mcp` (service-api has it).
- **deploy**: a service that will run on a server or cloud → `--deploy container`.

Round 2 — only what is still missing:
- **Owner** (GitHub user/org/`org/team`; propose it from the git remote) and **license**:
  `Proprietary` (usual for company code), `MIT` or `Apache-2.0` → `--var license=...`.
- Team level: the **marketplace** git URL of this plugin, so every clone and every CI agent
  gets it → `--var marketplace=<owner/repo or URL>` (skip if unknown).

Pass the choices as `--preset P --level L [--archetype A] [--deploy D] [--with mcp]`.

If the stack is unsupported (Go, Rust, Java…): say there is no preset yet, run
`doctor.py` to show what a top-tier repo needs, and offer to add the items by hand.

### 3. Show the plan
Run `apply.py ... --dry-run --diff`. Summarise for a non-expert in 5–8 lines:
what groups of files will be created and what each group gives them
(e.g. "CI: every push is checked automatically on GitHub"), plus any `conflict` files
(existing files that differ — they will be left untouched). Ask for a go-ahead.

### 4. Apply
Run `apply.py` without `--dry-run`. Report created / kept / conflict counts.
For each `conflict`, show the diff only if the user wants it; offer to merge the useful
parts by hand, and only with their approval.

### 5. Install
Run the `next_commands.install` list from the apply output (`--json` makes it easy),
in order, from the repo root. If a tool is missing, install it or tell the user exactly how:
- uv: `curl -LsSf https://astral.sh/uv/install.sh | sh` (or `brew install uv`)
- pre-commit (ts-node team): `uv tool install pre-commit` or `pipx install pre-commit`
- Node.js 22: via nvm / fnm / the official installer.
- Windows: the Makefile needs `make` and a POSIX shell. Recommend WSL2 (best), or Git Bash
  plus `winget install GnuWin32.Make` / `choco install make`. The dev container
  (team level) avoids all of this.

### 6. Verify — do not skip
Run the `next_commands.verify` list. Everything must pass.
- Formatting failures: run `make format`, then verify again.
- `gitleaks` may need a first-time download/build; if the network blocks it, say so and
  continue — CI will run it.
- Anything else: fix it (max 2 attempts), otherwise report precisely what is failing.

Then run `doctor.py`. Expected: 100/100 at the chosen level. Explain any gap.

### 7. Seed the domain model (optional, recommended)
Ask: "What are the 3–5 most important things your project deals with?"
(e.g. Customer, Order, Drink). For each: one-sentence definition and key properties.
Follow the **ontology-add** skill to write them (glossary, entity YAML, relations,
wiki entity pages), then `make gen` and `make check`. Keep it small — it can grow later.

### 7b. Domain actions (if archetype service-api or capability mcp)
Ask which 2–4 things users or agents must be able to **do** (place an order, award points…),
who may do each (roles) and whether agents may do it alone, with confirmation, or never.
Write them with **ontology-add** (`ontology/actions.yaml`, `roles.yaml`, `pii: true` on
personal data), `make gen`, then implement the handlers or leave them as the first issue.

### 7c. GitHub and the AI-native SDLC (team level)
Follow **sdlc-github-setup**: labels, environments, ruleset, the Claude GitHub App and one
secret. Then `doctor.py --remote` confirms branch protection and CI.

### 8. Commit (ask first)
If the repo has git, offer one commit: `chore: set up repository (repo-setup <preset>/<level>)`.
Do not push and do not create a GitHub repo unless asked.

### 9. Wrap up for a non-expert
Short summary:
- score from doctor, and the 3 commands they will use daily: `make dev`, `make check`, `make format`;
- what will now happen automatically (CI on every push, Dependabot PRs, secret scan…);
- the manual steps doctor lists (branch protection) with one line on how;
- that `/repo-setup:setup-explain` answers "what is this file / why did it block my commit?".

## Rules
- Never overwrite or delete existing files; never `--force` anything.
- Never commit secrets; never put real values in `.env.example`.
- Do not invent tool choices outside the preset; presets are the team standard.
- Re-running is safe: to upgrade starter → team, run `apply.py --level team` (vars are
  remembered in `.repo-setup.json`).

# repo-setup

Set up, adopt and audit repositories. Claude Code goes through decision layers with you, offers two
or three reasoned options at each, gets an independent critique, then builds and verifies the repo.

## Install

```
/plugin marketplace add phanlemanh/repo-standards
/plugin install repo-setup@repo-standards
```

Needs Python 3.11+ for the scripts.

## How setup works

One flow, three depths, changeable at any layer:

- **Hand it to Claude**: recommended options throughout, one review at the end. Level `starter`.
- **Review each layer**: stop at every layer with a real choice.
- **Bring a design**: paste what you decided; Claude asks only about gaps and conflicts.

The ten layers are context, repo strategy, architecture, AI in the product, stack, domain, design,
quality, delivery, and agents and governance. Every option carries a label: `automated`, `partial`, or
`manual` (recorded with guidance, not built).

Decisions go to `setup-blueprint.yaml` with reasons and rejected options. `apply.py --from-blueprint`
builds from it. It records one setup session: `apply.py` only adds files, so changing the
architecture later is manual work. A tour file, `docs/START-HERE.md`, explains the result.

## What you can configure

| Axis | Options |
| --- | --- |
| **Stack** | `ts-node`, `ts-api` (Fastify), `react-vite`, `python`, `fastapi` |
| **Archetype** | `service-api`, `modular-monolith`, or none |
| **Capability** | `ai` (tiers `call`, `workflow`, `agent`), `design` (React/Vite only), `mcp`, `github-agents` |
| **Deploy** | `container` |
| **Level** | `starter`, `team` |

`apply.py --list-options` lists them with when to use each.

### Design (React/Vite)

`--with design` adds the design floor. `tools/design_guards.mjs`, `mk/design.mk`,
`tests/App.test.tsx`, `tests/e2e/floor.spec.ts` and `tests/e2e/routes.ts` are owned by the plugin:
change them in the plugin and re-apply. A local edit costs the `design_guards_bite` points in
`doctor`. Screens and their states are listed once, in `src/screens.ts` (a path may have parts, such
as `/orders/:id`, with a real address to visit); the sample screen sits at `/example`. The builder
reads one page, `.claude/rules/ui.md`, and `make ui-floor` is the fast loop. The data source's test
hook (`?scenario=`) answers only in the unit tests and the browser checks' own build, never in
`npm run build`; there it answers every request, so the checks never reach a real server.

### AI in the product

`--with ai --var ai_tier=call|workflow|agent` uses the official Anthropic SDK. The agent tier builds
tools from the ontology with the same permission checks as MCP, and brings a sample ontology. `make
check` needs no API key. `make eval` calls the real API and costs money, so it stays out of `make
check` and CI.

### Agents on GitHub

Off by default. `--with github-agents` at level `team` adds issue-to-PR agents, an independent
reviewer and auto-merge of low-tier PRs. It needs the Claude GitHub App, one secret and API spend.
This layer has not yet been run against a real Claude session.

## Skills

| Command | Use it for |
| --- | --- |
| `/repo-setup:new` | A new repo, through the decision layers |
| `/repo-setup:adopt` | A repo that already has code, in small safe steps |
| `/repo-setup:doctor` | A 0-100 score (`--remote` also checks GitHub) |
| `/repo-setup:explain` | What a file or tool is, and why something was blocked |
| `/repo-setup:github` | GitHub settings, and agents on GitHub if enabled |

The plugin stops at setup. It runs when you call it and has no hooks. To build features with an
agent loop and acceptance gates, use a separate tool such as
[Acceptance Gate Kit](https://github.com/phanlemanh/acceptance-gate-kit).

## Procedures generated into the repo

These live in `.claude/skills/` of each generated repo, next to the tools they use, and work without
this plugin:

| Command | Use it for |
| --- | --- |
| `/ontology-add` | Add or change a concept, action, role or personal data |
| `/wiki-ingest`, `/wiki-query`, `/wiki-health` | Record, look up and review project knowledge |
| `/review-change` | Independent review: intent, tests, domain, security, tier |

## What actually protects the repo

Two groups, with different strength:

- **Enforced by GitHub**, regardless of what an agent does, once `tools/github_setup.py --apply` has
  run: the ruleset, CODEOWNERS and required checks.
- **Enforced per tool call, inside a Claude session**: `.claude/settings.json` deny rules. They
  prevent mistakes but are not a security boundary. A deny rule on `.env` does not stop a script from
  reading it. Use Claude Code's sandbox if you need operating-system level isolation.

The risk gate in `pr-pipeline.yml` reads its rules from the base branch. The `doctor` score covers
local files unless you pass `--remote`, and it measures whether checks are in place, not whether the
code is right.

## Ontology

```
ontology/entities/*.yaml   concepts (types, enums, refs, subtypes with rules, pii: true)
ontology/actions.yaml      what can be done: input, output, roles, agent: allowed|confirm|forbidden
ontology/roles.yaml        roles and inheritance (including role "agent")
        │ make gen
        ├── types + ActionHandlers + can() + redactPII()   (TypeScript / Python)
        ├── contracts/openapi.json → POST /v1/actions/{name} (service-api) + breaking-change check
        └── MCP tools for AI agents (mcp) and the agent tier (ai): permission checks, input checks, PII masking
```

`make check` fails when the wiki or ontology is wrong, generated code is stale, the contract is out
of date or breaks compatibility, or a module crosses a boundary.

## Language

Code, identifiers, file names, commits and instructions for AI are English. Claude talks in
`conversation_language`. Documents for people follow `docs_language`.

## How it is built

```
scripts/apply.py      composes layers: core, stack, archetype, capability, deploy (starter, then team)
                      "+<file>/NN-part" builds a file from parts; mk/*.mk joins make check;
                      "[var=value]/" is a conditional folder; never overwrites; safe to re-run
scripts/blueprint.py  reads and checks setup-blueprint.yaml
scripts/doctor.py     scores against checklists/top-tier.toml
presets/ archetypes/ capabilities/ deploy/   each folder: preset.toml + starter/ + team/
```

Direct use:

```bash
python3 scripts/apply.py --target ../shop --preset fastapi --archetype service-api \
  --deploy container --level team --var "project_name=Shop" --var "description=Orders API" \
  --var owner=my-org --var license=Proprietary --dry-run
python3 scripts/doctor.py --target ../shop --remote
```

**Windows**: use WSL2, Git Bash with `choco install make`, or the dev container (level team).

## Customise for your team

- Standards: `checklists/top-tier.toml`. Agent autonomy: `governance/autonomy.yaml` in each repo
  (a person must change it).
- New stack, archetype, capability or deploy target: a folder with `preset.toml` (`extends`,
  `stacks`, `not_stacks`, `requires_level`, `when`, `capabilities`, `install`, `verify`), `starter/`
  and `team/`.
- Release: `python3 tools/bump_version.py minor`.

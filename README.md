# repo-standards: a Claude Code marketplace

[Tiếng Việt](README.vi.md)

This marketplace holds one plugin, **repo-setup**. It sets up, adopts and audits repositories
through decision layers, for newcomers who hand everything to Claude and for professionals who bring
their own choices. An ontology generates types, the API contract and agent tools, and each repo gets
its own wiki and agent procedures. A repository that ships Claude Code plugins is its own kind
(`claude-plugin`): it gets manifests, a sample plugin, a manifest lint and a version bump instead
of app tooling, and is scored by checks made for plugin repos. It stops at setup: to build features with an agent loop and
acceptance gates, use a separate tool such as
[Acceptance Gate Kit](https://github.com/phanlemanh/acceptance-gate-kit). Details: [plugins/repo-setup/README.md](plugins/repo-setup/README.md).

## Install

You need [Claude Code](https://code.claude.com). You need Python 3.11 or newer for the plugin's
scripts, and a GitHub account only if you want to push code. In Claude Code:

```
/plugin marketplace add phanlemanh/repo-standards
/plugin install repo-setup@repo-standards
```

## Use

Open Claude Code in your project folder:

- New or empty repo: `/repo-setup:new`
- Repo that already has code: `/repo-setup:adopt`
- Health check: `/repo-setup:doctor`
- "What is this file, why was my commit blocked?": `/repo-setup:explain`
- GitHub settings: `/repo-setup:github`
- Day to day, in the generated repo, without the plugin: `/ontology-add`, `/wiki-ingest`,
  `/wiki-query`, `/wiki-health`, `/review-change`

## Share with a team

Commit this to the project's `.claude/settings.json`. Teammates are offered the plugin after they
trust the folder; until then the setting is ignored without any message.

```json
{
  "extraKnownMarketplaces": {
    "repo-standards": {
      "source": { "source": "github", "repo": "phanlemanh/repo-standards" }
    }
  },
  "enabledPlugins": {
    "repo-setup@repo-standards": true
  }
}
```

## Develop the plugin

```bash
bash tests/run.sh                        # fast tests, no network
bash tests/e2e.sh                        # real installs + make check for each combination (network)
PRESETS="fastapi:service-api:container" bash tests/e2e.sh   # stack:archetype:deploy:caps:ai_tier
claude plugin validate .                 # marketplace manifest
claude plugin validate plugins/repo-setup  # skills
python3 tools/bump_version.py minor      # bump the version everywhere + a CHANGELOG entry
```

History: [CHANGELOG.md](CHANGELOG.md).

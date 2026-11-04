# repo-standards: a Claude Code marketplace

[Tiếng Việt](README.vi.md)

This marketplace holds one plugin, **repo-setup**. It sets up, adopts and audits repositories
through decision layers, for newcomers who hand everything to Claude and for professionals who bring
their own choices. An ontology generates types, the API contract and agent tools, agents maintain a
wiki, and changes are tiered by risk. Details: [plugins/repo-setup/README.md](plugins/repo-setup/README.md).

## Install

You need [Claude Code](https://code.claude.com). You need Python 3.11 or newer for the plugin's
scripts, and a GitHub account only if you want to push code. In Claude Code:

```
/plugin marketplace add phanlemanh/repo-standards
/plugin install repo-setup@repo-standards
```

## Use

Open Claude Code in your project folder:

- New or empty repo: `/repo-setup:setup-new`
- Repo that already has code: `/repo-setup:setup-adopt`
- Health check: `/repo-setup:setup-doctor`
- "What is this file, why was my commit blocked?": `/repo-setup:setup-explain`
- A feature from intent to PR: `/repo-setup:sdlc-run`
- GitHub settings: `/repo-setup:sdlc-github-setup`
- Day to day: `/repo-setup:ontology-add`, `/repo-setup:wiki-ingest`, `/repo-setup:wiki-query`,
  `/repo-setup:wiki-health`

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
claude plugin validate plugins/repo-setup  # skills, agents and hooks
python3 tools/bump_version.py minor      # bump the version everywhere + a CHANGELOG entry
```

History: [CHANGELOG.md](CHANGELOG.md).

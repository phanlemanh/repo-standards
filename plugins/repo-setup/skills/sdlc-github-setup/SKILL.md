---
name: sdlc-github-setup
description: Connect a repo-setup repository to GitHub — merge settings, staging/production environments, branch ruleset and, when agent workflows are enabled, labels, variables, the Claude GitHub App and secrets — showing every change before applying it. Use after setup-new/setup-adopt at team level, or when agent workflows on GitHub do not start.
---

# Set up the repository on GitHub

Scripts in the repo: `tools/github_setup.py` (dry run by default) and `tools/autonomy.py`.
It detects agent workflows from `.github/workflows/pr-pipeline.yml`.

## 1. Preconditions
- `gh auth status` is logged in and the user has **admin** rights on the repository.
- The repo has a GitHub remote and the default branch is pushed.

## 2. Teamwork (always)
Run `python3 tools/github_setup.py` and explain in plain words what it will do: squash-only
merges, environments `staging` and `production` (production needs a human reviewer), and a
ruleset on the default branch (PR required, code-owner review, required check `check`). Ask for
the go-ahead, then run with `--apply`. Then run `doctor.py --remote`: branch protection and CI
checks should pass.

## 3. Agents on GitHub (only with the `github-agents` capability)
Off by default. Say this plainly before going further: agents picking up issues needs the GitHub
App and one secret, costs API usage on each run, and this layer has not yet been run against a
real Claude session. If the user wants it and the repo lacks it, re-run
`apply.py --with github-agents`.

The dry run then also shows labels (`agent:spec`, `agent:implement`, `spec:needs-approval`,
`spec:approved`, `risk:low|medium|high`, `agent-review:*`), auto-merge, Actions allowed to approve
low-tier PRs, the extra required check `gate`, and repository variables.

Things only the human can do (give exact steps):
- Install the **Claude GitHub App** on the repository (`/install-github-app` in Claude Code, or
  https://github.com/apps/claude).
- Add **one** secret: `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`
  (`gh secret set ANTHROPIC_API_KEY`). Never ask the user to paste a secret into the chat.
- Variable `REPO_SETUP_MARKETPLACE` = the marketplace git URL so CI agents load this plugin.

Smoke test: create a small intent issue with the "Intent" form (e.g. "add a log line to
wiki/log.md"), add `agent:implement`, and follow the run (`gh run watch`). Expected: a low-tier PR
that the PR pipeline reviews and auto-merges. Report what actually happened.

## 4. Optional, either way
`RELEASE_PLEASE_TOKEN` (so CI runs on release PRs); `DEPLOY_ENABLED=true` once `make deploy` works.

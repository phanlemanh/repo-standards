---
name: sdlc-github-setup
description: Connect a repo-setup repository to GitHub for the AI-native SDLC — labels, merge settings, staging/production environments, branch ruleset, variables, the Claude GitHub App and secrets — showing every change before applying it. Use after setup-new/setup-adopt at team level, or when agent workflows on GitHub do not start.
---

# Turn on the AI-native SDLC on GitHub

Scripts in the repo: `tools/github_setup.py` (dry run by default) and `tools/autonomy.py`.

## 1. Preconditions
- `gh auth status` is logged in and the user has **admin** rights on the repository.
- The repo has a GitHub remote and the default branch is pushed.

## 2. Dry run, explain, then apply
Run `python3 tools/github_setup.py` and explain in plain words what it will do:
labels (`agent:spec`, `agent:implement`, `spec:needs-approval`, `spec:approved`,
`risk:low|medium|high`, `agent-review:*`), squash-only merges + auto-merge, Actions allowed to
approve low-tier PRs, environments `staging` and `production` (production needs a human
reviewer), a ruleset on the default branch (PR required, code-owner review, required checks),
and repository variables. Ask for the go-ahead, then run with `--apply`.

## 3. Things only the human can do (give exact steps)
- Install the **Claude GitHub App** on the repository (`/install-github-app` in Claude Code, or
  https://github.com/apps/claude).
- Add **one** secret: `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`
  (`gh secret set ANTHROPIC_API_KEY`). Never ask the user to paste a secret into the chat.
- Optional: `RELEASE_PLEASE_TOKEN` (so CI runs on release PRs); variable
  `REPO_SETUP_MARKETPLACE` = the marketplace git URL so CI agents load this plugin;
  `DEPLOY_ENABLED=true` once `make deploy` works.

## 4. Smoke test
Create a small intent issue with the "Intent" form (e.g. "add a log line to wiki/log.md"),
add `agent:implement`, and follow the run (`gh run watch`). Expected: a low-tier PR that the
PR pipeline reviews and auto-merges. Then run `doctor.py --remote` — branch protection and CI
checks should pass.

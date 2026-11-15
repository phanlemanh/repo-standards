---
name: github
description: Connect a repo-setup repository to GitHub — merge settings, staging/production environments, branch ruleset and, when agent workflows are enabled, labels, variables, the Claude GitHub App and secrets — showing every change before applying it. Use after `/repo-setup:new` or `/repo-setup:adopt` at team level, or when agent workflows on GitHub do not start.
---

# Set up the repository on GitHub

Scripts in the repo: `tools/github_setup.py` (dry run by default) and `tools/autonomy.py`.
It detects agent workflows from `.github/workflows/pr-pipeline.yml`.

## 1. Preconditions
- `gh auth status` is logged in and the user has **admin** rights on the repository.
- The repo has a GitHub remote and the default branch is pushed.

## 2. Teamwork (always)
First find out how this repository merges pull requests: read `CONTRIBUTING.md` and ask when it
is not clear. The script allows one merge method and turns the others off:
- squash (the default, no option): one commit per pull request on the default branch.
- `--merge-method merge`: the branch's commits stay and a merge commit is added. Use it when the
  repository's process reads commits from the branch after the merge, for example a commit that
  must still exist on the default branch.

The choice is not stored. Pass the option on every run, the dry run and `--apply`: a run without
it sets the repository back to squash only.

Run `python3 tools/github_setup.py` (with `--merge-method merge` when that is the repository's
way) and explain in plain words what it will do: the merge method, environments `staging` and
`production` (production needs a human reviewer), and a ruleset on the default branch (PR
required, code-owner review, required check `check`). Ask for the go-ahead, then run with
`--apply` and the same options. Then run `doctor.py --remote`: branch protection and CI checks
should pass.

With merge commits, two generated files still describe squashing and are the user's to edit:
step 6 of `CONTRIBUTING.md`, and the comment at the top of `.github/workflows/pr-title.yml` (the
pull request title is no longer the commit message on the default branch; every commit on the
branch lands there with its own message). Say this before the go-ahead: release-please reads
those messages, and nothing checks them, so each commit on a branch needs a Conventional Commits
message for the release notes and the version to come out right.

## 3. Agents on GitHub (only with the `github-agents` capability)
Off by default. Say this plainly before going further: agents picking up issues needs the GitHub
App and one secret, costs API usage on each run, and this layer has not yet been run against a
real Claude session. If the user wants it and the repo lacks it, re-run
`apply.py --with github-agents`.

The dry run then also shows labels (`agent:spec`, `agent:implement`, `spec:needs-approval`,
`spec:approved`, `risk:low|medium|high`, `agent-review:*`), auto-merge, Actions allowed to approve
low-tier PRs, the extra required check `gate`, and repository variables. The PR pipeline merges
low-tier PRs with the method the repository allows: squash, or a merge commit when squash
merging is off.

Things only the human can do (give exact steps):
- Install the **Claude GitHub App** on the repository (`/install-github-app` in Claude Code, or
  https://github.com/apps/claude).
- Add **one** secret: `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`
  (`gh secret set ANTHROPIC_API_KEY`). Never ask the user to paste a secret into the chat.

Smoke test: create a small intent issue with the "Intent" form (e.g. "add a log line to
wiki/log.md"), add `agent:implement`, and follow the run (`gh run watch`). Expected: a low-tier PR
that the PR pipeline reviews and auto-merges. Report what actually happened.

## 4. Optional, either way
`RELEASE_PLEASE_TOKEN` (so CI runs on release PRs); `DEPLOY_ENABLED=true` once `make deploy` works.

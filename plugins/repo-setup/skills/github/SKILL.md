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
is not clear. The script allows one merge method and turns the others off. The choice is stored
as `merge_method` in `governance/autonomy.yaml`:
- `merge_method: squash` (what a new repository gets): one commit per pull request on the default
  branch.
- `merge_method: merge`: the branch's commits stay and a merge commit is added. Use it when the
  repository's process reads commits from the branch after the merge, for example a commit that
  must still exist on the default branch.

A repository that had commits before the setup first wrote the key got the method its last merges
showed: `merge` when one of the last 20 commits of the branch was a merge commit, else `squash`.
That is a reading of the history, not a decision: check the value against what the team wants
before a run with `--apply`. An upgrade does not change a value the policy names, and refuses a
`--var merge_method` that says otherwise. In a shallow clone that shows no merge commit the setup
cannot read the history: it stops and asks for `--var merge_method=squash` or `merge`.

Changing `merge_method` is a change to `governance/`, so a person makes it, in a pull request of
its own. A policy from before the key has no `merge_method`: then a run leaves the merge settings
as they are, and `--merge-method merge` (or `squash`) sets them for that run only; suggest storing
the choice. Where the policy names one, an option that differs is refused.

Run `python3 tools/github_setup.py` and explain in plain words what it will do: the merge method, environments `staging` and
`production` (production needs a human reviewer), and a ruleset on the default branch (PR
required, required checks `check`, `secret-scan`, `conventional-title` and `conventional-commits`,
a code owner only where `.github/CODEOWNERS` names one, and no other approval). Checks of the
repository's own, a browser suite for example, become required when `governance/autonomy.yaml`
names them under `required_checks`. The CI job `check` stands for every tier (`quick` and
`heavy`). When `heavy` or `e2e` is required too, the dry run says so: such a job is skipped when
the light tier fails or the pull request is a draft, and GitHub counts a skipped check as green.

The two commit-format checks run as the default branch defines them. When the dry run says one is
"not a required check yet", the default branch does not have its job: merge the upgrade that
brings it, then run the command again. On a private repository without GitHub Advanced Security,
CodeQL says it is off and ends green; it is not a required check.

A ruleset from an earlier run is updated in place. When that would drop a required check someone
added by hand, the dry run names it and `--apply` stops. Ask the user which they mean: name the
check under `required_checks` to keep it, or pass `--prune` to drop it. Ask for the go-ahead, then
run with `--apply` and the same options. Then run `doctor.py --remote`: branch protection and CI checks
should pass.

With merge commits, step 6 of `CONTRIBUTING.md` still describes squashing and is the user's to
edit. The `PR title` workflow needs no edit: it reads the merge settings on every pull request
and judges what will reach the default branch, the title when the repository squashes, each
commit of the branch otherwise (job `conventional-commits`, with the repository's own commit-msg
hook). Say this before the go-ahead: release-please reads those messages, so each commit on a
branch needs a Conventional Commits message.

The run ends with the secrets that are missing. Without `RELEASE_PLEASE_TOKEN` releases are off:
the `Release` workflow says so and stays green. Storing that key is the user's to do.

## 3. Agents on GitHub (only with the `github-agents` capability)
Off by default. Say this plainly before going further: agents picking up issues needs the GitHub
App and one secret, costs API usage on each run, and this layer has not yet been run against a
real Claude session. If the user wants it and the repo lacks it, re-run
`apply.py --with github-agents`.

The dry run then also shows labels (`agent:spec`, `agent:implement`, `spec:needs-approval`,
`spec:approved`, `risk:low|medium|high`, `agent-review:*`), auto-merge, the extra required check
`gate`, and GitHub Actions kept from approving pull requests. The PR pipeline merges
low-tier PRs with the method the repository allows: squash, or a merge commit when squash
merging is off.

Things only the human can do (give exact steps):
- Install the **Claude GitHub App** on the repository (`/install-github-app` in Claude Code, or
  https://github.com/apps/claude).
- Add **one** secret: `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`
  (`gh secret set ANTHROPIC_API_KEY`). Never ask the user to paste a secret into the chat.

Smoke test: create a small intent issue with the "Intent" form (e.g. "add a log entry with
`make log m=...`"), add `agent:implement`, and follow the run (`gh run watch`). Expected: a low-tier PR
that the PR pipeline reviews and auto-merges. Report what actually happened.

## 4. A proof instead of a person (optional)
By default product code is tier medium: a person merges it, because nothing proves it yet. When a
tool the team uses already proves each change in CI, for example the evidence re-check of a
feature loop, a person edits `governance/autonomy.yaml` (agents may not): `proof.check` names
that status check, and `default` may then be `low`. Before suggesting it, confirm the check
runs and reports on **every** pull request, including dependency updates: a required check that
never reports blocks the pull request, and a job that is skipped counts as passed. Then `make codeowners` and run the script again with `--apply`:
the check becomes required and product code merges itself when it is green. With agent workflows,
the PR pipeline also stops running its own reviewer agent. The check may not be `check`, nor
`gate` where agent workflows report under that name.

## 5. Optional, either way
`RELEASE_PLEASE_TOKEN` (so CI runs on release PRs); `DEPLOY_ENABLED=true` once `make deploy` works.

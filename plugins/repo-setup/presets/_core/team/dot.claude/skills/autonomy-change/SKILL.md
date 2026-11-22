---
name: autonomy-change
description: Change how much this repository lets the machine do on its own (governance/autonomy.yaml), from what the user says in plain words, as a pull request of its own that a code owner decides. Use when the user asks to let something merge without them, to make something wait for them, to name the check that proves a change, to require a check before merging, or to change who decides.
---

# Change the autonomy of this repository

The user says in words what they want: "let the docs merge on their own", "the browser suite must
pass before anything merges", "make Lan a decider". You draft the change; a code owner decides it.
A change to `governance/autonomy.yaml` changes the rules of the game: it is `high`.

## 1. Find the one key

| The user says | The key in `governance/autonomy.yaml` |
| --- | --- |
| X merges on its own once the checks pass | add the path of X to `low` |
| X waits for a person again | take the path of X out of `low` |
| product code merges on its own | `default: low`, which needs `proof.check` |
| check C proves that a change does what it should | `proof.check: "C"` |
| check C must pass before anything merges | add C to `required_checks` |
| who decides a change to the rules, or the rest | `owners.high`, `owners.medium` |
| dependency updates of one semver level | `rules.dependency_updates` |
| one commit per pull request, or the branch's commits | `merge_method` |

- One request is one key. When the words fit more than one key, or none, name the keys they could
  mean and what each would do, and let the user say which: the intent is theirs.
- `high` is for the rules of the game only (policy, CI, agent config, quality gates). A product
  path that should wait for a person is `medium` already, the default: do not put it in `high`
  because its name sounds risky.
- `tests/**` and the test patterns in `low` stay: the gate raises a deleted or weakened test on its
  own (`rules`).

## 2. Draft it on a branch of its own

```bash
git fetch origin
git switch -c autonomy/<short-name> origin/HEAD
```

`origin/HEAD` is the default branch of the remote. Where it is not set (a repository pushed rather
than cloned), `git remote set-head origin --auto` sets it.

Change that one key, and nothing else in the repository. Keep the comments of the file.

## 3. Run the policy check

```bash
make codeowners
make governance
```

`make governance` refuses a policy that loosens a wall without a machine proof: `default: low`
without `proof.check`, a proof that is one of the setup's own checks, a check name that is not a
name. When it refuses, show its words to the user, open no pull request, and go back
(`git switch -` and `git branch -D autonomy/<short-name>`): a person leaves only when a machine
proof takes the place.

## 4. Show before and after

- The line or lines of the key as they were, and as they are now.
- For a path the user named, the tier with each policy:

  ```bash
  git show origin/HEAD:governance/autonomy.yaml > "${TMPDIR:-/tmp}/autonomy.before.yaml"
  python3 tools/autonomy.py --policy "${TMPDIR:-/tmp}/autonomy.before.yaml" --files <path>
  python3 tools/autonomy.py --files <path>
  ```

- When the key is `proof.check`, `required_checks` or `merge_method`, it changes GitHub too: say
  that `python3 tools/github_setup.py` shows what its next `--apply` sets, after the merge.
- `.github/CODEOWNERS` changes with the policy; say which lines.

## 5. Open the pull request, then stop

```bash
git add governance/autonomy.yaml .github/CODEOWNERS
git commit -m "chore(governance): <what changes, in the user's words>"
git push -u origin autonomy/<short-name>
gh pr create --title "<the commit title>" --body-file <the body>
```

The body has the user's words, the before and after of step 4, and one line: "A code owner decides
this pull request. In a repository with one owner, merging it is the decision."

Your part ends with the link to the pull request. Never merge it and never turn on auto-merge for
it: it is `high`, and the decision is the code owner's.

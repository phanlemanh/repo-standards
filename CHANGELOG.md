# Changelog

## Unreleased

### Ledgers as fragments (RS2b), the shared mechanism
Design: `docs/superpowers/specs/2026-11-17-ledger-fragments-design.md`.

- New `make derived` (`mk/derived.mk`, `tools/ledgers.py`): it draws every file a repository keeps
  out of git. Layers add to `DERIVED_TARGETS` (targets that draw) and `DERIVED_FILES` (files they
  draw). `derived` waits for `upgrade`; in each preset `lint`, `typecheck`, `test`, `ontology`,
  `build` and `dev` wait for `derived`. No ledger is drawn yet: `make derived` says "nothing to
  draw".
- New `make check` step `derived-untracked`: red when a file in `DERIVED_FILES` is in git and
  opens with the stamp `tools/ledgers.py` writes, with the path and `git rm --cached <path>`.
- `doctor` lists the ledgers still kept as one file (`ledgers_split` in `--json`, a block in the text
  report) with their split command, `make split L=<ledger>`. It is a notice: the score does not move,
  and a repository without `tools/ledgers.py` gets nothing. An upgrade creates no fragment and
  leaves a one-file repository green; what breaks on upgrade: nothing, the split is the owner's
  call, one pull request per ledger.
- python preset: `pyproject.toml` excludes `tools/` (vendored by repo-setup) from ruff, so `make lint`
  does not read the ledger tools. What breaks on upgrade: nothing; `pyproject.toml` merges as before.
- `tools/ledgers.py shape <ledger>` prints `one-file` or `fragments`.
- What breaks on upgrade: nothing. A repository that keeps `wiki/log.md`, `wiki/index.md` and
  `ontology/glossary.md` in git and edits them by hand has no stamp, so they stay `one-file` and
  `derived-untracked` skips them. `Makefile` gains one line (`... : | derived`) after
  `-include mk/*.mk`; a Makefile edited here gets that line merged in, or marked on conflict.
- New `make log m="<text>"` (`ledgers.py add-log`): in the `one-file` shape it puts a line at the top of
  `wiki/log.md`; in the `fragments` shape it writes one file, `wiki/log/YYYY-MM-DD-NN-<slug>.md`.
  `make derived` draws `wiki/log.md` from those files (stamp line, then `wiki/log.head.md`, then
  one line per entry, newest first). A hand edit of the drawn file makes `draw` exit 1 and print
  the added lines. New `make check` step `ledgers-check`: a fragment with a wrong name, or a
  hand-kept `wiki/log.md` beside entries in `wiki/log/` (two sources), is red. What breaks on
  upgrade: nothing, a tracked unstamped `wiki/log.md` stays `one-file`.
- New `python3 tools/ledgers.py add-term <Term> --definition <s> [--display <s>] [--not-confused-with <s>]`:
  in the `one-file` shape it adds a row to the table of `ontology/glossary.md`; in the `fragments`
  shape it writes `ontology/glossary/<Term>.md` (front matter `term`, `display`, `not_confused_with`,
  body one sentence) and touches nothing else. `make derived` draws `ontology/glossary.md` (stamp,
  `ontology/glossary.head.md` or a built-in head, a four-column table sorted by term, `|` escaped),
  even with no term, so `wiki_lint.py` still reads it. A hand edit of the drawn file, or a hand-kept
  `ontology/glossary.md` beside fragments, makes `draw` exit 1. `ledgers-check` is red for a fragment
  whose `term` is not its file name or that has no `display`. What breaks on upgrade: nothing, a
  tracked unstamped `ontology/glossary.md` stays `one-file`.
- `make derived` draws `wiki/index.md` in the `fragments` shape: stamp, `wiki/index.head.md` (or a
  built-in head), one `## <Types>` section per page type of `ontology/page-types.yaml` in file order
  (types it does not know last), a line `- [<title>](<path>)` (plus ` — <summary>`) for each page, and
  the link to `log.md`. A page with no `type` or `title` is left out of the index, named by `draw`
  (exit 0), by `ledgers-check` (red) and by `wiki_lint.py` ("page has no type or title"). In the
  `fragments` shape `wiki_lint.py` no longer warns "not linked from wiki/index.md", treats the drawn
  `wiki/index.md` and `wiki/log.md` and the entries of `wiki/log/` as no page, and `sdlc_metrics.py
  --write` no longer edits `wiki/index.md` (the weekly page is listed by itself). Hidden files
  (`.DS_Store`) in `wiki/log/` and `ontology/glossary/` are no fragments. What breaks on upgrade:
  nothing, a tracked unstamped `wiki/index.md` stays `one-file` and keeps every old rule.
- The code generated from `ontology/` (`src/generated/ontology.ts`, `src/<pkg>/ontology_types.py`)
  is drawn by `make derived` (`gen-derived`, `ledgers.py draw-gen`) in the `fragments` shape: the
  generator output with ` sha256:<hex>` (the hash of everything after the first line) at the end of
  its first comment line, written only when the text changes, never over a hand edit (exit 1, names
  the file, says to edit `ontology/` and run `make derived`). `make ontology` keeps `ontology_codegen.py
  --check` in the `one-file` shape and skips it in `fragments`; `make gen` draws in `fragments`. The
  two Node presets get `"prepare": "command -v make >/dev/null 2>&1 && make -s derived || true"`;
  `image`, `up` and `deploy` of the `container` layer wait for `derived`. What breaks on upgrade:
  nothing, a committed unstamped generated file stays `one-file` and `make ontology` compares it as
  before.
- New `python3 tools/ledgers.py split <log|index|glossary|gen> [--dry-run]` (`tools/ledgers_split.py`;
  also `make split L=<ledger> [DRY=1]`): the one command an existing repository runs, in a pull
  request of its own, to move a one-file ledger into fragments. It works everything out in memory,
  draws the ledger with the real drawer in a scratch copy, and compares by entry, not by text: every
  entry before is there after, word for word; entries whose place changed are printed. Whitespace
  inside an entry is collapsed to one space, as `make log` and `add-term` write it, and printed
  (`whitespace collapsed: …`); an empty display name becomes the term (`display set to term: …`). A
  lost or extra entry, two sources, a term that cannot be a file name, more than 99 log lines on one
  day, a page the index links that has no `type` or `title`, a `.head.md` changed since repo-setup
  wrote it (its sha256 differs from `.repo-setup.json`), or a file it cannot write makes it exit 1 and
  write nothing. A write that fails part way puts every file and the git index back as they were. Then it writes the
  fragments (the same files `make log` and `add-term` write) and the head file, moves each index
  description to the `summary` of its page, runs `git rm --cached` on the old file, adds its path to
  `.gitignore` and puts the drawn file in its place. The glossary's `_Example:_` row and closing
  comment are dropped, and said so. `gen` has no fragments: the committed generated file (it must
  match what `ontology_codegen.py` writes) leaves git and is drawn, stamped. `--verify-against FILE`
  runs the comparison alone against a copy of the old file. What breaks on upgrade: nothing, the
  command runs only when called.
- **Breaking for new repositories:** a repository set up from now on keeps its wiki log, wiki index
  and glossary as fragments. The starter no longer gives `wiki/log.md`, `wiki/index.md` (`wiki/+index.md/`)
  or `ontology/glossary.md`; it gives `wiki/log.head.md`, `wiki/index.head.md`, `ontology/glossary.head.md`
  and the empty folders `wiki/log/` and `ontology/glossary/`. The three drawn files and the generated
  code (`src/generated/ontology.ts`, `src/<pkg>/ontology_types.py`) are in `.gitignore`; the two Node
  and Python presets add the lines, and `.prettierignore` lists the drawn markdown. The archetypes
  `service-api` and `modular-monolith` no longer add `wiki/+index.md/50-decisions.md`: the decision
  pages are listed by the drawn index. Once `make split` rewrites a head file, it is taken out of
  `.repo-setup.json` (it is the repository's own). New preset key `kept_quietly` (next to `user_owned`):
  a file listed there that the manifest does not record and the repository has is reported under `kept`
  with no note and no diff; `_core/preset.toml` lists the three head files, so an upgrade never asks
  anyone to merge one.
- `mk/derived.mk` runs `ledgers.py`, `ledgers_split.py` and `ontology_codegen.py` with `LEDGERS_PYTHON`
  (default `python3`, standard library only), not `PYTHON`: in a python or fastapi repository `make derived`
  and the SessionStart hook no longer go through `uv run`, which could sync a venv at every session start.
- `.claude/settings.json` gets a `SessionStart` hook that runs `make -s derived` (always exit 0; the
  error of a failed draw is printed for the agent; nothing happens when `make` or the Makefile is
  missing), so a session starts with the drawn files present. `tools/wiki_lint.py` draws a ledger that is
  kept as fragments when its drawn file is absent (a clean clone), so `/repo-setup:doctor` does not
  report a missing glossary or index before `make derived`.
- Every writer calls the commands instead of editing a drawn file: `AGENTS.md` (the guide says the
  three files are drawn by `make derived`; a new page needs only `type` and `title`; one sentence for a
  repository whose `wiki/index.md` is still in git), the skills `ontology-add` (`add-term`),
  `wiki-ingest` (the date of the last ingest is the newest file in `wiki/log/`, or the top line of
  `wiki/log.md` in an old repository), `wiki-health`, `adopt` and `github`, the agent workflow
  `agent-ci-fix.yml` (`make log m="..."`), and `ontology/README.md`. The `ontology` and `wiki` checks of
  `checklists/top-tier.toml` accept the head files and `ontology/glossary/`.
- `draw` on an untracked hand-kept `wiki/log.md` or `ontology/glossary.md` beside fragments no longer
  says `git rm --cached` (the file is not in git): it says to move the file aside, or delete it once its
  lines are copied.
- What breaks on upgrade: nothing visible. `apply.py` reports `wiki/log.md`, `wiki/index.md` and
  `ontology/glossary.md` as `dropped` (the template no longer gives them) and leaves them in place, so a
  repository that keeps them in git stays `one-file`; `wiki/log.md merge=union` stays in
  `.gitattributes`. It also creates the head files, the two folders (`.gitkeep`) and the hook, and
  merges the new `.gitignore` lines (the block sits after the first section of the file, so a `.gitignore`
  where a team only appended lines at the end merges cleanly; one edited next to that first section can still
  be marked); a tracked file is not affected by `.gitignore`. A repository that
  edited `.claude/settings.json` has the hook merged in or marked on conflict. Run `make split L=<ledger>`
  per ledger, in a pull request of its own, to move to the fragments shape.

## 0.7.0 — 2026-11-17

### Upgrade path
Step C of the plan in `docs/three-repo-overview-design.md` (package RS8). Design:
`docs/superpowers/specs/2026-11-17-upgrade-path-design.md`.

- Running `apply.py` again brings template fixes into files the repository edited in place. It
  rebuilds what the plugin wrote last time from the templates of the release that wrote it (the
  running plugin when the version is the same, otherwise that release's tag, downloaded from
  GitHub, or a folder given with `--base-from`), checks it against the hash in
  `.repo-setup.json`, and merges three ways with `git merge-file`. Nothing downloaded is run:
  only its templates are read.
- Where the template and the repository changed the same lines, the file gets conflict markers
  (`<<<<<<< this repository`, `||||||| repo-setup <release>`, `>>>>>>> repo-setup <release>`)
  and is reported as `marked`. A file whose recorded content no release gives is merged two
  ways, against an empty base (`||||||| repo-setup: no matching base`).
- New `make check` step `upgrade` (`mk/upgrade.mk`, `tools/upgrade_markers.py`): it fails while
  a file listed in `.repo-setup.json` holds those markers. It runs before the other steps, and
  `make format` waits for it: Prettier moves the markers of a Markdown file where no check sees
  them. A marker a formatter indented still counts.
- New groups in the output of `apply.py`: `edited` (edited here, the template did not change),
  `marked`, `base_unread` (the base could not be read: no network, no git, or git refused the
  merge; the file is left as it is, with the reason in `base_reasons`), `removed` and `dropped`.
  `conflict` keeps its meaning: a file the repository had before repo-setup wrote it.
- `.repo-setup.json` records, per file, the release its content follows (`file_versions`), and
  `today` under `vars`, so a later run renders the same files. `year` now comes from `today`.
- `doctor` prints an "Upgrade" block (files marked, behind the last release with both versions,
  edited in place, deleted here) and gains two checks: `setup_in_sync` (no markers, no file
  behind) and `upgrade_wall` (`make check` runs the marker check).

What changes on upgrade:
- `apply.py` now writes into files the repository edited: a merge, or conflict markers to
  resolve. Before, it left them as they were. `--dry-run --diff` shows what it would write.
- It ends with exit code 1 while a file is `marked` or `base_unread`; it used to end with 0.
- A file the plugin wrote and the repository deleted is no longer created again.
- A file the repository owns (`package.json`, `pyproject.toml`, `src/index.css`, the manifests
  and `CHANGELOG.md` of a plugin marketplace) is updated when nobody edited it, and merged when
  someone did. After `package.json` or `pyproject.toml` changes, run the install command to
  update the lockfile; the note says so.
- A repository built before this release has no `today` recorded, so its `wiki/log.md` is
  merged two ways once.
- The upgrade needs network access to GitHub for files written by an earlier release, unless
  `--base-from` points at a copy of it.

### Verified

- Run on GitHub, on the private probe repository: upgraded to tag `repo-setup-v0.6.0`, two setup
  files edited in place, then upgraded with this code from a stand-in release with two template
  fixes (the base rebuilt from the real tag). `.editorconfig` and `package.json` were merged,
  `AGENTS.md` (same line on both sides) and `wiki/log.md` (no `today` in the 0.6.0 manifest) were
  marked; `check` stayed red at the `upgrade` step, naming the files and lines, until the markers
  were merged by hand, then green. The first push showed the wall hidden behind `lint` and Prettier
  removing it, fixed above.
- Offline suite on Linux and macOS, manifest validation and the end-to-end combinations in CI,
  including a new one: install from the last release's tag, edit in place, upgrade with this
  code, `make check`.
- Not yet run: an upgrade between two published releases that change a template (the probe run
  used a stand-in release, so two of its files now carry hashes no release gives); the PR
  pipeline of `github-agents` on GitHub; CodeQL on a public repository after the upgrade.

### Known gaps
- A file without a final newline gets conflict markers when the template adds a last line,
  instead of a clean merge.
- `apply.py --dry-run` ends with exit code 1 when a file would be marked; the setup skills do not
  say so.
- The marker check misses a closing marker that Prettier turned into a quote (`> > > > > > >`).
  The opening marker is still found, so the file is still reported.
- `doctor`'s `upgrade_wall` check looks for the `include` lines of the Makefile exactly as the
  template writes them.
- The 0.6.0 gap on `production` without a reviewer, on a private repository on the free plan, is
  still open.

## 0.6.0 — 2026-11-17

### Parallel work
Step B of the plan in `docs/three-repo-overview-design.md` (packages RS2a and RS10): the one file
every pull request writes stops conflicting, and the numbers that say whether work queues come from
a command.

- `.gitattributes` merges `wiki/log.md` by union. Every branch adds its line at the top of that
  list, so merging the default branch into a branch conflicted there almost every time. Git now
  keeps the lines of both sides. It applies when a branch is merged or rebased on a machine.
  GitHub does not follow it: its merge button, its "Update branch" and auto-merge still see a
  conflict until the default branch is merged into the branch on a machine and pushed (seen on a
  probe repository, 2026-11-16). After such a merge the lines are
  not strictly newest first, so the `wiki-ingest` skill reads the latest date instead of the first
  line. The rule suits a file where lines are added and never edited.
- `tools/sdlc_metrics.py` gains a "Flow" section, and `--json` gains the keys `lead_time_max_h`,
  `back_merges`, `ci` and `capped`:
  - the longest time from open to merge, next to the median;
  - merges of the default branch into a pull request branch: how many, how many conflict when
    replayed with `git merge-tree`, and the files in conflict most often. It needs a full clone
    and git 2.38, fetches `refs/pull/<n>/head` for commits it lacks, and uses the merge rules of
    the checkout it runs in;
  - CI machine minutes per merged pull request (the job durations of every run in the window);
  - late red: heads where a job ended red after `gate` had passed;
  - red runs on the default branch, per workflow. Late red and this one count every attempt of a
    run, so a run made green by running it again still counts.

  A part that could not be read says `not read` and why; it is never shown as zero. That covers a
  shallow clone, commits that cannot be fetched, a list of workflow runs that GitHub cuts at 1,000,
  and a list of pull requests that stops at 300.

What changes on upgrade:
- A repository that edited its `.gitattributes` does not receive the new line: add
  `wiki/log.md merge=union` by hand.
- The metrics script makes one request per pull request and per workflow run, eight at a time. A
  week of a busy repository takes minutes, and can reach the hourly request limit of the Actions
  token; it then says that CI was not read.
- The row "Median PR lead time" now reads `<median> h, longest <max> h`.

### Documents renamed
- Four documents carried Vietnamese file names, against the rule the plugin gives every repository
  it sets up (file names are English; only the text follows the repository's language). They are
  now `docs/setup-principles.md`, `docs/three-repo-boundaries.md`,
  `docs/three-repo-overview-design.md` and `docs/superpowers/specs/2026-11-16-real-walls-design.md`;
  the text is unchanged and still Vietnamese. `CLAUDE.md` states the rule for this repository, and
  section 45 of `tests/run.sh` fails when a file points at an old name. A link from outside to an
  old name no longer resolves.

### Real walls
Four checks carried the name of a wall and held nothing. Each now has a test that makes it go red.
Design: `docs/superpowers/specs/2026-11-16-real-walls-design.md`; the picture across the three
repositories: `docs/three-repo-overview-design.md`.

- Secret scan in CI: `security.yml` ran `pre-commit run gitleaks --all-files`. That hook reads
  staged changes, and CI stages nothing, so it scanned zero bytes and passed whatever the commits
  held. `.pre-commit-config.yaml` gets a second gitleaks hook for CI (`gitleaks-history`, stage
  `manual`) that reads every commit of the branch being checked, and `security.yml` runs that one.
  A leak on another branch does not turn this branch red.
- `Release`: the workflow fell back to the Actions token, which may not open pull requests, so it
  failed after every merge. It now needs `RELEASE_PLEASE_TOKEN`; without it the job says that
  releases are off and ends green. `tools/github_setup.py` and `doctor.py --remote` (check
  `release_key`) report the missing key.
- `PR title`: the workflow checked the title on the ground that pull requests are squashed. It now
  reads the merge settings on each pull request. Job `conventional-title` checks the title unless
  squash merging is off; the new job `conventional-commits` checks each commit of the branch with
  the repository's own commit-msg hook when merge commits or rebase are allowed. Both run from the
  base branch. The `github` skill no longer asks a person to edit the workflow by hand.
- Ruleset: `secret-scan` is a required check. A repository names its own required checks under
  `required_checks` in `governance/autonomy.yaml` (a browser suite, for example), and
  `tools/github_setup.py` requires them. Before it updates a ruleset it reads the checks the
  branch requires today: it stops instead of dropping one the policy does not name, and says
  which. `--prune` drops them on purpose and names them. The dry run shows the same warning.
  `secret-scan` is required only where a workflow has a job of that name, and an entry under
  `required_checks` must be a name: a required check that no job reports blocks every pull
  request.
- `tools/github_setup.py` no longer takes "GitHub would not say" for "none". When it cannot read
  the rulesets it stops instead of making a second one; when it cannot list the secrets it says
  so instead of calling one missing. Secrets an organisation shares with the repository count.
- Breaking on upgrade: `secret-scan` can go red on the first run in a repository whose history
  already holds something shaped like a secret (rotate the key, then record its fingerprint in
  `.gitleaksignore`); after `tools/github_setup.py --apply` it is required. A repository that had
  turned on "Allow GitHub Actions to create and approve pull requests" stops opening release PRs
  until `RELEASE_PLEASE_TOKEN` is set. Every pull request gets the new check
  `conventional-commits`. `tools/github_setup.py --apply` now fails on a ruleset that requires a
  check the policy does not name: name it under `required_checks`, or pass `--prune`.
- `codeql` can go green. On a private repository without GitHub Advanced Security it could only
  fail ("Code scanning is not enabled for this repository"), since 0.4.0. The job now asks GitHub
  first: when the answer says code scanning is not enabled it skips the analysis, says CodeQL is
  off, and ends green; any other answer runs CodeQL as before. It also gets `actions: read`, which
  a private repository needs.
- The commit-format checks block a merge. `conventional-title` and `conventional-commits` were red
  on the right commits but required by nothing, so a pull request could merge with them red.
  `tools/github_setup.py` now requires both; each passes and says why when it does not apply to
  the repository's merge method. They run as the default branch defines them
  (`pull_request_target`), so a check is required only once the workflow on the default branch
  defines its job. Until then the command says so and leaves it out: a required check that never
  reports would block every pull request, the upgrade included. When that file cannot be read, a
  ruleset that already requires the check keeps it (also with `--prune`), and the command fails.
- Run on GitHub (a private probe repository built from 0.4.0): the secret scan is red on a token
  committed and deleted by the next commit, `conventional-commits` is red on a commit out of
  format and skips merges of the default branch, Release ends green and says releases are off, and
  the ruleset blocks a pull request whose secret scan is red.
- Breaking on upgrade: after `tools/github_setup.py --apply`, a pull request whose title or commits
  do not follow Conventional Commits cannot merge.
- Not built: `dependency-audit` and `codeql` stay advisory, because they judge the world and not
  the change. Staged CI, and a scan of other branches.

### People decide, machines check
- The rule the plugin now holds itself to is written in `docs/setup-principles.md`: a setup that
  brings a person in to make a change more reliable is not a good setup. A person appears where
  something is decided (a change to the rules, production, a secret); checking is a machine's
  job. Section 43 of `tests/run.sh` fails when a change to the plugin breaks the rule, and a root
  `CLAUDE.md` puts the rule in front of every session that works on this repository.
- Ruleset: no approval is required for its own sake (`required_approving_review_count` is 0).
  A code owner still decides wherever `.github/CODEOWNERS` names one. GitHub Actions is no
  longer allowed to approve pull requests: nothing needs it.
- `governance/autonomy.yaml` gets `proof.check`: the name of the status check that proves a
  change, for example the evidence re-check of a feature loop. With it, `default` may be `low`:
  `tools/github_setup.py` requires that check on the default branch, product code merges itself
  when it is green, CODEOWNERS loses its `*` line, and the PR pipeline no longer runs its own
  reviewer agent on the same change. `default: low` without a proof is refused (`make
  governance` fails, and the gate counts the default as `medium`). The proof may not be `check`
  or `gate`. The sample policy stays at `default: medium` with no proof.
- `high` is only the rules of the game: policy, CI, agent config, quality gates. `ontology/`,
  migrations, SQL, auth, security, permissions, infra, deploy and container files are no longer
  high because of their name (`**/*auth*.*` also matched `author.ts`).
- A looser agent guard is found by the machine instead: an action in `ontology/*.yaml` that is
  less guarded than before (`agent: forbidden` or `agent: confirm` loosened or removed), or a
  guarded action that is gone, raises the pull request to `high`
  (`rules.agent_guard_removals_raise_to`). Each action is compared with itself, so a guard added
  elsewhere does not pay for one removed. A tighter setting or a new action does not raise it.
- PR pipeline: a low-tier pull request merges itself whoever wrote it, once the proof or the
  reviewer agent has checked it. It used to do so only for `claude[bot]` and `dependabot[bot]`,
  so a pull request opened from a local session never did. The pipeline approves nothing.
- PR pipeline: the job that reads the pull request is now `tier`. `gate`, the required check,
  checks nothing out; it fails when the tier is unknown (a skipped required check counts as
  passed on GitHub), and it turns auto-merge off for a pull request that stopped being low on a
  later push, failing if it cannot. Auto-merge on the strength of a proof first confirms that the
  branch requires that check, and fails with the command to run when it does not. The jobs that
  check nothing out now tell `gh` which repository they mean.
- Generated instructions add no stop of their own: a tier says who decides the merge and is
  never a reason to stop and ask before working. `.claude/settings.json` has no `ask` rules and
  no deny rules on Bash commands; it keeps the silent ones on secrets, workflows and
  `governance/`. Which commands may run is left to Claude Code's permission mode.
- `tools/github_setup.py --apply` updates a ruleset it made earlier, replacing its rules; rules
  added to that ruleset by hand are lost. It used to leave it as it was. `doctor --remote`
  passes a default branch that requires a pull request, code owner review and checks; it no
  longer asks for an approval count, and it now fails when code owner review is off.
- `/repo-setup:explain` no longer names a gate hook: the plugin has shipped none since it became
  setup only.
- Breaking on upgrade, for a repo that takes the new files: run `make codeowners`, then
  `python3 tools/github_setup.py --apply` (with the same `--merge-method` as before) so the
  ruleset follows. Until then a low-tier pull request waits for an approval nobody gives.
  Pull requests that touch `ontology/`, auth, migrations or infra no longer ask a code owner. A
  docs-only pull request from a person now merges itself when the checks pass. Local Claude
  sessions are no longer stopped by the settings before `git push --force`, `git reset --hard`,
  `rm -rf` or a push to the default branch: on GitHub the ruleset refuses the last one and a
  force push to the default branch; the rest is up to the permission mode.
- Not built, and listed in the principle under what is still open: a way for a repo with one
  owner to merge its own change to the rules; a wall on GitHub for a pull request raised to
  `medium` on a path with no owner (anyone who can write, an agent included, can merge it once
  the checks pass); telling a new fixture in `conftest.py` from a switched-off test. The
  ruleset has run on a probe repository (see "Verified"); the PR pipeline has not, including
  whether the `gate` job is allowed to turn auto-merge off.

### Merge method
- `tools/github_setup.py --merge-method merge` allows merge commits and turns squash and rebase
  merging off, for a repository whose process needs the branch's commits to stay on the default
  branch. Without the option nothing changes: squash only, the same `gh` commands as before.
  Nothing else differs between the two: the same steps and the same settings, with
  `allow_squash_merge` and `allow_merge_commit` swapped and `allow_rebase_merge` off in both.
- The choice is not stored: pass the option on every run. A run without it sets the repository
  back to squash only. `/repo-setup:github` now finds out how the repository merges before it
  runs, and says what merge commits mean for release notes.
- With agent workflows, the PR pipeline merges low-tier pull requests with the method the
  repository allows: squash, or a merge commit when squash merging is off. It used to squash
  always, which fails in a repository that has squash merging off.
- Not built: rebase merging as a choice, a stored choice, and wording that follows the choice in
  the generated `CONTRIBUTING.md` and `pr-title.yml` (both still describe squashing).

### Relations and attributes
- Once a repo has `ontology/actions.yaml`, `make ontology` (wiki-lint) also fails on three things
  the model used to stay silent about. Each error names the action, relation or entity and every
  way to fix it; there is one error per relation and per entity, listing all that is missing.
  - An action a role may run only on its own records has no relation that says what "own" means.
    An action says it with `own: [role]`, next to `roles`; the permission-table form
    `scope: { Role: own }` is read too. A relation says it with `own: true`. A relation to the
    entity the action's entity is handled through (`lifecycle.via`) counts.
  - A relation in `ontology/relations.yaml` has no answer for `attach`, `detach` or `reassign`
    (a many-to-many relation: `attach` and `detach`). An action answers with
    `relations: { <relation name>: [attach] }`. Otherwise the choice goes under `lifecycle:` on the
    relation, in the same form as for an entity: `{ later: <where it is planned> }`, listed as a
    warning on every run, or `{ never: <reason>, decided_by: <person> }`. A link that is set when
    one end is created and never changes is one line: `lifecycle: { via: <that entity> }`.
  - A property of an entity that has a create or update action is set by no action. An action
    names what it sets with `sets: [...]`; without it, input fields named like a property count.
    Otherwise the entity lists the property under `not_set:` with the reason: `system: [...]`,
    `import: [...]`, `later: { <property>: <where> }` or
    `never: { <property>: { reason: ..., decided_by: ... } }`.
- Breaking on upgrade: a repo with actions that takes the new `tools/ontology_actions.py` will fail
  `make ontology` until every relation has its answers (most are one `via` line), every own scope
  has its relation, and every entity with a create or update action accounts for its properties
  (ids, timestamps and counters are one `system: [...]` line). That list is the work. A repo
  without `ontology/actions.yaml` is not affected, and neither is an entity that has no create or
  update action or is handled through its parent.
- A misspelt relation, operation or property name fails too, in actions and in the recorded
  reasons, so a rename that misses one place does not pass. A recorded choice that an action now
  covers is reported as out of date.
- `/ontology-add`, `/review-change`, `.claude/rules/ontology.md`, the ontology README, the entity
  template and the starter `relations.yaml` describe the new keys. `/review-change` checks a new
  `via` on a relation, because it claims the link never changes.
- Not built: `own` in the generated code (`can()` still answers per role only), which role uses
  which relation when two are marked `own`, record states and transitions, a `planned` status for
  actions, and properties of an entity handled through its parent.

### Entity lifecycle
- Once a repo has `ontology/actions.yaml`, `make ontology` (wiki-lint) fails when an entity has no
  `create`, `query`, `update` or `delete` action and no recorded choice. The choice goes under
  `lifecycle:` in the entity file: `{ later: <where it is planned> }`, listed as a warning on every
  run; `{ never: <reason>, decided_by: <person> }`; or `lifecycle: { via: <Entity> }` for a part
  handled through its parent. The error names the entity, the operation and both ways to fix it.
- A repo with actions that takes the new `tools/ontology_actions.py` will fail `make ontology`
  until each entity has its four answers. That list is the work: add the action, or ask the owner
  and record the answer. A repo without `ontology/actions.yaml` is not affected.
- `/ontology-add` asks for the whole life of a concept per role, and `/review-change` blocks a
  `never` that the author decided alone. The entity template shows the block.
- New `.claude/rules/ontology.md`, loaded when Claude works under `ontology/`: run
  `make ontology` after each edit, four answers per entity, never fill `decided_by` yourself.
- Not built: a hook that runs the lint after each edit, and a `planned` status for actions (an
  action that is declared but has no code still counts as an answer).
- `docs/three-repo-boundaries.md` records what belongs to this repository, to design-assembly and to
  delivery-loop.
- The same page now says which repository answers which UX question, where the three overlap
  today, and what each should carry next. Proposals only: nothing in the plugin changed.

### Design layer
- `new` has a tenth decision layer, `design` (after `domain`), and a `design` capability for
  `react-vite`: shadcn components, brand colour, a labels file, `design/terms.json`,
  `design/behaviors.md` and a sample screen in `src/example/` that the AI copies. `doctor` checks it
  (`design_present` and related checks).
- A `react-vite` repo built before this will fail `design_present` until you turn on the `design`
  capability. Turning it on there (`apply.py --with design`): if you edited `src/App.tsx`,
  `tests/App.test.tsx`, `vite.config.ts` or `eslint.config.js`, they show as conflicts and are left
  alone (`--diff` shows why); a kept `tests/App.test.tsx` costs the `design_guards_bite` points
  until you take the plugin's copy. Your own `src/index.css` is kept, with a note, and its design
  tokens must be merged by hand.
- `adopt` does not support the `design` capability yet: `apply.py` refuses it in adopt mode, and
  `doctor` reports `design_present` as not applicable there.
- `tools/design_guards.mjs`, `mk/design.mk`, `tests/App.test.tsx`, `tests/e2e/floor.spec.ts` and
  `tests/e2e/routes.ts` are owned by the plugin: change them in the plugin and re-apply; a local
  edit costs the `design_guards_bite` points.
- Cheaper for the builder: screens and states are registered once in `src/screens.ts`; the `ui`
  skill is folded into `.claude/rules/ui.md` (delete `.claude/skills/ui/` in older repos by hand);
  `make check` prints one short result per step and the full output of a failing one; the
  destructive badge and the wide table pass the browser checks out of the box.
- The sample screen takes its states from data, not from `?state=`: it loads from
  `src/example/data.ts`, which can be slow, fail or find nothing, and tests pick that answer with
  `?scenario=`; `src/screens.ts` lists, per state, the scenario, the user's steps and the text shown.
- Less for the builder to read and wire: a screen in `src/screens.ts` may have a path with parts
  (`/orders/:id`) plus `visit`, the real address the checks open, and receives the parts as
  `params`; a fixed path wins over a path with parts, whatever the order. `tests/App.test.tsx` is
  now a short generic walk over that list that waits for each state. The sample screen moved to
  `/example`; an unknown or malformed address shows a not-found page, and a screen whose code fails
  to load shows an error page, both with links to every registered screen (the browser checks visit
  the not-found page too). The `?scenario=` test hook answers only in unit tests and in the browser
  checks' own build (`vite build --mode floor` into `coverage/floor`), never in `npm run build`;
  there it answers every request (`ready` when no scenario is named), so the checks never reach a
  real server. The restyle guard's message no longer sends the builder into `src/components/ui`.
  At `team` level the sample is left out of coverage.
- A plugin marketplace (`claude-plugin`) has no screens: the `design` layer is recorded as not
  applicable with its reason, next to architecture, AI, domain and delivery, and `apply.py` refuses
  the `design` capability there.

### TypeScript presets
- TypeScript presets (ts-node, ts-api, react-vite): check steps run quietly; a failing step prints its
  full report; `make check` ends with one line. At `team`, a passing coverage run still prints its
  table, except with the `design` capability.

### Verified
- Offline suite on Linux and macOS, manifest validation and the end-to-end combinations in CI on
  every pull request of this release.
- Run on GitHub, on a private probe repository built from 0.4.0 and upgraded to the default branch
  before the last two walls landed: the walls listed under "Real walls", the ruleset with no
  approval and code owners from `.github/CODEOWNERS`, and the union merge of `wiki/log.md` on a
  machine (GitHub's own merge does not follow it). After the upgrade `codeql` ended green and off,
  the ruleset required four checks, and a pull request with a commit out of format was blocked.
- Not yet run: the PR pipeline of `github-agents` on GitHub (`gate`, a low-tier pull request that
  merges itself, `gate` turning auto-merge off, `proof.check`); an upgrade from 0.5.0 to this
  release; CodeQL on a public repository after the upgrade; the setup skills in a live Claude Code
  session.

### Known gaps
- On a private repository on GitHub's free plan, `tools/github_setup.py` cannot give the
  `production` environment a required reviewer (GitHub answers 422). It says so and exits 1, but
  the environment is created without the rule, so the `production` job of `deploy.yml` runs with
  nobody approving it.
- An upgrade leaves the files a repository owns (`src/index.css`, `package.json`, `pyproject.toml`
  and the like) as they are, even when nobody edited them, and names them only on the first
  install. Compare them with the plugin's copy by hand after an upgrade; on `react-vite`, the
  design tokens in `src/index.css` come first.

## 0.5.0 — 2026-11-11

### Plugin marketplaces
- New stack preset `claude-plugin` for repositories that ship Claude Code plugins: a marketplace
  manifest, one sample plugin with a skill, `tools/plugin_lint.py`, `tools/bump_version.py` (every
  manifest and the changelog in one command), shell tests, a `Makefile`, a pinned Node version and
  CI that runs `make check` and `claude plugin validate`. No `package.json`, type checker, linter
  config, `.env.example`, ontology or wiki. Level `team` publishes a GitHub Release per version tag.
- `detect.py` suggests `claude-plugin` when it finds plugin manifests, and lists the plugins.
- `doctor` scores a repo as its kind: the preset in `.repo-setup.json`, plugin manifests it
  detects, or `--preset`. Checks that do not fit are listed under "not applicable" with the reason
  and are not scored. For a plugin marketplace these are the lockfile, formatter and linter, strict
  types, `.env.example`, ontology, wiki and coverage threshold; the first three apply again when
  the root has a `package.json`, `pyproject.toml` or `tsconfig.json`.
- New checks for plugin repos: manifests parse and agree on names; versions agree across manifests,
  unless `--var plugin_versioning=independent`; no plugin uses the repository root as its source;
  descriptions stay within 1024 characters; a bump tool, a changelog and a CI step that validates
  manifests exist; with `--remote`, version tags have GitHub Releases.
- The layers architecture, AI, domain and delivery are recorded as not applicable for this stack,
  each with a reason; `blueprint.py not-applicable <preset>` lists them and `check` rejects a
  blueprint that would build one.
- `apply.py` reports `not_applicable` (what a preset leaves out of the shared core, and why).

### Changes
- `--adopt`: a file of the repo's own at a sample path (for example `tests/run.sh`) is now listed
  as skipped, no longer as a conflict. Nothing is written in either case.
- A repository with plugin manifests and no `.repo-setup.json` is now scored as `claude-plugin`.
  Its score changes; pass `--preset <name>` to score it as something else.

### Fixes
- `pr-pipeline.yml` (`github-agents`): the reviewer accepts PRs opened by `claude[bot]`; before, its
  run failed and low-tier auto-merge never happened. A custom bot in `AGENT_AUTHORS` must also be
  added to `allowed_bots`.
- The reviewer no longer runs PR code in a job that holds tokens: no dependency install, no `make`,
  no MCP servers from the repo. It reads test results from `gh pr checks`.
- The gate keeps its base-branch rules in `$RUNNER_TEMP`, so a PR cannot plant `.gate/yaml.py` and
  run code in the job that sets the risk tier.

Re-apply to get these. The reviewer and its inline comments have not yet run on GitHub.

- `tools/boundaries.py` (`modular-monolith`): `@/` imports were never checked and `src/app` was
  never scanned, so a Next.js repo could bypass every module boundary. Both now follow the same
  rules as relative imports. `server` is a second public entry next to `index`, and a
  `"use client"` file may not import one. These apply to every TypeScript repo: the client rule
  does nothing without the directive, and `server` only makes one exact filename public.

Re-applying does not replace a vendored tool: copy this file into an existing repo by hand, and
expect it to report violations that were hidden before.

### Verified
- Offline suite on Linux and macOS, manifest validation and the end-to-end combinations in CI on the
  pull request that added the `claude-plugin` preset. Run by hand on an existing marketplace
  repository with six plugins: detection, `doctor`, `--adopt --dry-run`, which left the
  repository unchanged, and `--adopt` on a copy, which added six paths, merged lines into two
  files and overwrote or deleted none; `doctor` on that copy went from 9 to 14 of 20 scored checks.
- Not yet run: the `team` level's release workflow on GitHub, and the setup skills in a live
  Claude Code session on a plugin repository.

## 0.4.0 — 2026-11-05

### Breaking
- The plugin now stops at setup. Removed the skills `sdlc-run`, `sdlc-spec`, `sdlc-implement` and
  `sdlc-review`, the subagents `code-reviewer` and `security-reviewer`, and all three hooks.
- `ontology-add`, `wiki-ingest`, `wiki-query` and `wiki-health` moved into each generated repo's
  `.claude/skills/`, with a new `review-change`. Run `apply.py` again to get them in an existing repo;
  they are called as `/ontology-add`, no longer `/repo-setup:ontology-add`.
- Agent workflows no longer install the plugin in CI, and `github_setup.py` has no `--marketplace`.
  High-tier edits in CI now rest on the agent's instructions and the merge gate, because the edit
  gate left with the hooks. The variable `REPO_SETUP_MARKETPLACE` can be deleted.
- Skills renamed: `/repo-setup:new`, `adopt`, `doctor`, `explain` and `github` replace `setup-new`,
  `setup-adopt`, `setup-doctor`, `setup-explain` and `sdlc-github-setup`.
- Level `team` no longer includes agent workflows. New repos enable them with
  `--with github-agents`. Repos whose manifest lists the agent workflows keep the capability
  automatically on re-apply, with a note.
- `agent: confirm`: over HTTP, role `agent` now gets 403. MCP tools carry
  `_meta["anthropic/requiresUserInteraction"]`, which Claude Code enforces; other clients may not.
- `agent: forbidden` now also holds in `can()`, and wiki-lint rejects it combined with role `agent`.

### Guided setup
- `new` goes through nine decision layers at three depths, with labelled options
  (`automated`, `partial`, `manual`), an independent critique and a tour file.
- `setup-blueprint.yaml` and `apply.py --from-blueprint`; `doctor` reports drift and manual steps.
- Generated repos state a language rule in `AGENTS.md`; the glossary has a display name column.

### AI in the product
- Capability `ai` with tiers `call`, `workflow` and `agent`, using the official Anthropic SDK.
  `make eval` is separate from `make check`. The agent tier builds tools from the ontology.

### Fixes
- Tier classification: renames judge the old path, non-ASCII paths match, added skip markers count
  as weakening tests; nested agent config and `conftest.py` are high tier.
- Project names with accents give ASCII slugs. Clear error on Python below 3.11.
- `doctor` rejects hollow policies and pipelines and flags local-only scores.
- Python bytecode ignored in TypeScript presets; `.gitleaks.toml` allows manifest hashes; no
  credentials in the `.env.example` sample; tests run on macOS.

### Verified
- Offline suite, manifest validation and the end-to-end combinations in CI on the merged code; run
  by hand: `fastapi:service-api:container:github-agents`. A repo generated before the split picks up
  the five project skills and updated workflows on re-apply, with no conflicts.
- Not yet run: the agent workflows on GitHub, the renamed skills in a live Claude Code session, and
  the scenarios in `tests/scenarios/guided-setup.md`.

## 0.3.0 — 2026-11-04

### AI-native SDLC (humans at the edges)
- `governance/autonomy.yaml` + `tools/autonomy.py`: low / medium / high tiers by path, test
  deletions and dependency updates; CODEOWNERS generated from the policy (`make governance`).
- GitHub workflows (team): intent issue → spec → PR (`agent-implement`), `@claude` mentions,
  PR pipeline (tier label from the base-branch rules, independent agent review, auto-merge of
  low tier only), red-main fixer, weekly maintenance + delivery metrics, release → staging →
  production with a human gate. Intent issue form, PR template with "Human decisions needed".
- `.claude/settings.json`: secrets unreadable; workflows/governance not editable; no
  force-push or push to main; ask before merge/approve/release.
- PreToolUse hook: human approval for every edit to a high-tier file (CI: only when a person
  added `spec:approved`).
- Skills `sdlc-run`, `sdlc-spec`, `sdlc-implement`, `sdlc-review`, `sdlc-github-setup`;
  subagents `code-reviewer`, `security-reviewer`; wiki page types `spec`, `metrics`.
- `tools/github_setup.py` (labels, environments, ruleset, variables; dry run by default),
  `tools/sdlc_metrics.py` (DORA + agent numbers).

### Ontology → actions, roles, personal data
- `ontology/actions.yaml`, `ontology/roles.yaml`, `pii: true`; wiki-lint validates them.
- Codegen: `ActionHandlers`, `ACTIONS` with JSON schemas, `can()`, `redactPII()` (TS + Python).
- Capability `mcp`: MCP server exposing agent-allowed actions as tools, with permission checks,
  input validation, PII redaction and confirm markers (TS SDK, Python SDK 2.x).

### Configuration axes
- Archetypes `service-api` (OpenAPI generated from actions, `POST /v1/actions/{name}`, API keys →
  roles, breaking-change check) and `modular-monolith` (`architecture/modules.yaml`, boundary
  checker for TS and Python).
- Deploy target `container` (multi-stage, non-root, healthcheck, compose, push + rollout).
- Composition engine: `+file/` fragments, `mk/*.mk` targets joining `make check`,
  `[var=value]` conditions also for install commands, `--with` capabilities, `--list-options`.
- Interview asks about needs (who uses it, how big, agents?) and maps them to the axes.
- Doctor: checks per archetype, capability and deploy target; SDLC checks.

### Verified
- Offline suite plus end-to-end runs of the 5 stacks and 4 archetype combinations at team level
  (install, lint, strict types, tests with coverage thresholds, build, pre-commit, commit-msg
  hook, doctor 100/100); MCP and HTTP layers tested with a sample domain (roles, PII); all
  generated workflows pass actionlint.

## 0.2.0 — 2026-11-03

### Ontology + wiki machinery
- `tools/` vendored into every repo: `wiki_lint.py` (structure, links, page types, entity
  references, glossary coverage), `ontology_codegen.py` (TypeScript interfaces / Python
  dataclasses + subtype predicates from `ontology/entities/*.yaml`), shared YAML reader.
- `make gen` and `make ontology`; `make check` now fails when the wiki/ontology is broken or
  generated code is stale.
- New skills: `ontology-add`, `wiki-ingest`, `wiki-query`, `wiki-health`.

### Claude Code hooks
- SessionStart adds the repo map to Claude's context; Stop runs `make check` when code changed
  (blocks up to 3 times while red) and reminds once to update the wiki. Silent in other repos;
  can be turned off per repo or per session.

### Existing repositories and choices
- `setup-adopt` skill and `apply.py --adopt`: no sample code, skips files when an equivalent
  tool config exists, merges `.gitignore`/`.gitattributes` lines.
- License choice: MIT, Apache-2.0 or Proprietary (also sets package.json / pyproject license).
- `AGENTS.md` holds the agent guide (read by any agent); `CLAUDE.md` imports it.

### More of the top-tier standard
- Team level: coverage thresholds, commit-message hook + PR-title check (Conventional
  Commits), dev container. Doctor checks for each.
- `doctor.py --remote`: branch protection / rulesets and latest CI status via `gh`.

### Presets
- Preset inheritance (`extends`), conditional files (`[var=value]/`), `exclude`.
- New: `fastapi`, `ts-api` (Fastify), `react-vite`. All five pass end-to-end tests at team level.

### Tooling
- `tools/bump_version.py`; offline tests cover adopt mode, licenses, ontology tools and hooks.

## 0.1.0 — 2026-11-03

- Plugin `repo-setup` with skills `setup-new`, `setup-doctor`, `setup-explain`.
- Presets `ts-node` and `python`, each with `starter` and `team` levels.
- Core layer for every repo: README, LICENSE, editor/git config, `.env.example`,
  `CLAUDE.md`, `ontology/` (glossary, entity template, relations, page types) and
  `wiki/` (index, log, first decision record).
- `scripts/apply.py`: never overwrites, idempotent, remembers setup in `.repo-setup.json`,
  safe starter → team upgrade.
- `scripts/doctor.py`: 0–100 score against `checklists/top-tier.toml` (27 scored checks + manual reminders).
- Verified end to end: both presets reach 100/100 at team level with lint, strict type check,
  tests, build and pre-commit hooks passing.

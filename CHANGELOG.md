# Changelog

## Unreleased

### Added: `make autonomy` prints the autonomy card, and an agent names its row
`make autonomy` answers four questions: when a person is called, what they do, why, and which switch would call them less. Two new files at the starter level of every preset, `tools/autonomy_card.py` and `mk/autonomy.mk`; an adopted `claude-plugin` repository gets them too. At `starter` it reads the repository. At `team` it also reads the merge policy through `tools/autonomy.py` (the gate's own words), the work outside the repository through `python3 tools/outside.py status --json`, and the layers that are on (agents on GitHub, deploys). A source it cannot read, such as no `gh` or no `governance/outside.toml`, is a row with `known: false` and the reason, never silence. It writes nothing and is not part of `make check`.
- Text consumers see new lines too: `python3 tools/outside.py status` prints a `card:` line under each list that calls a person, and the step summary of `tools/autonomy.py --github` ends with a `You are called: ...` line (without `To be called less` when the switch is `-`).
- The card never shows work nobody checked as done. A ledger row a person recorded by hand (`done = "..."`) is its own item, "rows a person recorded as done; no machine checks them", never "rows in place". The staging deploy line reads the `DEPLOY_ENABLED` row in every list of the ledger and its value: `false` is "paused", a row that is refused, unknown or not a checked `github-variable` is "not known", one still to apply or merge is "wait", and "off: add a row" only when no list has it. `outside.py status --json` rows gain one key, `value`, a setting's declared value (empty for every other row).
- The words "merge once the checks are green" are said only where `github-agents` (auto-merge) is on. Without it the card says "may merge with no approval once the checks are green; nothing merges it for you", and when `.repo-setup.json` cannot say, it says that and adds a `known: false` row. The same claim is reworded in the `tools/autonomy.py` docstring and in the team `AGENTS.md` ("`low` needs no approval once the required checks pass"); nothing else there changed.
- The same claim leaves every other file that said `low` "merges itself" without the agent pipeline: the comment at the top of `governance/autonomy.yaml`, both team `pull_request_template.md` files, the `risk:low` label (now "Autonomy gate: no approval needed once the checks pass"; the next `python3 tools/github_setup.py --apply` updates the label's description), the plugin README, the `github` skill and the governance layer of the tour. Only the `github-agents` rules, which ship with auto-merge, still say it merges itself.
- A policy refused for any reason (`default: lwo`, `required_checks: ["check"]`) now shows the policy's first problem and the switch "fix governance/autonomy.yaml" in the gate's `card`, instead of naming a switch the file already has. `tools/autonomy.py` gains `REASON_*` and tier constants that the card reads.
- `AGENTS.md`, at both levels, has one new rule in a section of its own: when you hand work to a person, name the row of the autonomy card that causes the call, and that row's switch. It words a call that already exists; it adds no stop and no approval.
- The JSON of `tools/autonomy.py` and of `outside.py status --json` gains a `card` key, the row of the card behind the call. It adds a key and removes none.
- The two `review-change` skills name the `card` key at their tier step, the tour points to `make autonomy` without copying the table into `docs/START-HERE.md`, and the `explain` table lists `tools/autonomy_card.py`.
- What breaks on upgrade: a file the plugin wrote and your repository then edited is three-way merged against what the plugin wrote last time, and `AGENTS.md` is one. Where your edit meets the new `The autonomy card` section the file can get conflict markers; `make check` stays red until you remove them, and the upgrade run exits 1. A repository that already has its own `tools/autonomy_card.py` or `mk/autonomy.mk` gets `conflict`: your file is left alone and reported, and you merge by hand. An adopted repository that already has an `AGENTS.md` skips it (`skipped`, "repo already has AGENTS.md") and `apply.py` prints no merge note; the `adopt` skill's step 4 is what tells you to add the new rule by hand. And a consumer of your own that asserts the exact key set of `outside.py status --json` (or of the gate's JSON) now sees `card`, and a `value` on each row of the ledger lists, and fails; read the keys you need instead. This repository's own section 52 had to change for that reason.

### Changed: the machine drafts a change to the rules, a person decides it
At team level a Claude session may now edit `.github/workflows/` and `governance/`. Such a change
goes in a pull request of its own; it is `high`, so a code owner decides it, and the machine never
merges it itself. Part 5.3 of the design of 2026-11-22.

- The generated `.claude/settings.json` of a team-level repository no longer denies
  `Edit(./.github/workflows/**)` and `Edit(./governance/**)`. The deny rules on reading secrets
  stay. A starter repository keeps both lines: it has no branch rule and no code owner, so no
  review could carry the decision. Both come from the one template.
- `AGENTS.md` (team) says it in two rules: a change there is `high` and a code owner decides it
  (held by the autonomy gate), and it goes in a pull request of its own that you never merge (kept
  by word). The `github-agents` rules say the same, and keep the spec on the issue for when GitHub
  refuses a workflow file from the agent's token.
- A new skill, `.claude/skills/autonomy-change/SKILL.md` (team): the user says in words what they
  want; it changes one key of `governance/autonomy.yaml` on a branch of its own, runs
  `make governance` (a loosened wall without a machine proof is refused, and no pull request is
  opened), shows before and after, opens the pull request and stops.
- One-owner repositories (the owner decided on 2026-11-22): when `owners.high` in
  `governance/autonomy.yaml` names one account, `tools/github_setup.py` writes the ruleset without
  code owner review and says why, in the dry run too; merging the pull request is the decision.
  This holds with `github-agents` on, since the session opens pull requests as the owner. With two
  or more deciders, or a team handle (`@org/team`), the ruleset asks for a code owner review as
  before. `doctor --remote` takes a ruleset without code owner review as protected when the
  repository's own `tools/autonomy.py` names one decider.

**What breaks on upgrade**:
- A team-level repository: the two `Edit` deny lines leave `.claude/settings.json`. A file nobody
  edited loses exactly those two lines; one edited next to them gets conflict markers. From then on
  the session can edit the CI files and the policy; what holds such a change is the `high` tier and
  the ruleset. A repository that has not run `python3 tools/github_setup.py --apply` has no ruleset:
  nothing but the words of `AGENTS.md` holds the change there.
- A one-owner repository: the next `python3 tools/github_setup.py --apply` turns code owner review
  off (the dry run and `--check` show it first). From then on "the machine does not merge a rule
  change itself" is kept by word only in that repository: GitHub cannot tell the owner's merge from
  the agent's, since both are the same account. The review is off for every path CODEOWNERS
  names, so "a person merges `medium`" is kept by word too; and with `github-agents`, the agents
  on GitHub (`claude[bot]`, with write access) could merge such a pull request once the checks pass,
  since the `gate` job only turns auto-merge off. Recorded under "Chỗ còn hở" in
  `docs/setup-principles.md`, with a way to close it the owner may choose (`bypass_actors`).
- `AGENTS.md` (team, and `github-agents`) and the comment at the top of `governance/autonomy.yaml`
  change wording; a team repository gets the new skill. With `github-agents`, the prompts in
  `.github/workflows/agent-implement.yml` and `agent-ci-fix.yml` change too: the agent opens a
  change to the rules as a pull request of its own instead of leaving it to a person, and falls
  back to the spec on the issue only when GitHub refuses a workflow file from its token. A
  repository that edited those prompts gets them merged, or conflict markers where the lines meet.

### Added: work outside the repository goes through one tool
A team-level repository gets a ledger of its work outside the repository (GitHub settings,
variables, keys, the platform it runs on) and `tools/outside.py`, which checks it, applies what
the machine may, and lists what only a person can do: create a key, enter it, decide.

- `governance/outside.toml` holds the kinds of command the machine may run ("recipes");
  `ops/outside.toml` holds each piece of work ("rows"). Both are read from the default branch of
  the remote, so a command runs only once the pull request that brings it is merged. A row only
  the working tree has is listed as not merged; `status --draft` prints what it would run.
- `python3 tools/outside.py status` (or `make outside`) prints what is in place, what the machine
  will apply, what is yours, and what is unknown: a check that cannot run or answer is never in
  place. `apply` applies settings and generates the keys the machine makes; a key present in one
  place only is never made again. `secrets` asks for each key a person creates, with the typing
  hidden, only in a terminal; the value goes to the store command on standard input and nowhere
  else.
- `tools/github_setup.py --check` says whether `--apply` would change anything (exit 0, 1, or 2
  when GitHub could not be read), and writes nothing. The ledger checks the GitHub settings with
  it; applying them still waits for a person's go-ahead.
- The kit seeds the GitHub part: the setup row and `RELEASE_PLEASE_TOKEN` (not for a plugin
  marketplace, which has no release-please); with `github-agents` the agent key and the GitHub
  App; with `--deploy container` the decision to approve production. `DEPLOY_ENABLED` is not
  seeded.
- `/repo-setup:new` has a stage "Outside the repository" before Finish, instead of stopping for
  everything outside the folder; `/repo-setup:github` and `/repo-setup:adopt` end with the
  status. `skills/new/references/outside.md` says how to write recipes for a platform the kit
  does not generate. The generated `AGENTS.md` (team) has a section on it, and
  `docs/setup-principles.md` has rule 11.

**What breaks on upgrade**: nothing. A team-level repository gets six new files
(`tools/outside.py`, `tools/outside_ledger.py`, `tools/github_check.py`,
`governance/outside.toml`, `ops/outside.toml`, `mk/outside.mk`) and a new section in `AGENTS.md`.
The tool needs Python 3.11 or later. Parts 5.3 (the machine drafts rule changes, a person
approves) and 5.2 (the autonomy card) of the design are not in this release.

**Checked**: a ts-api team repository with `github-agents` and `--deploy container`, set up with
0.10.4 and upgraded with this code: exit code 0, no conflict, the six files created,
`AGENTS.md`, `ci.yml`, `tools/ci_inputs.py` and `tools/github_setup.py` updated, and the five
seeded rows read.

**Kept by word**: only the two files of the ledger come from the default branch. The tools run
from the working tree (`tools/outside.py`, and `tools/github_setup.py` with the working tree's
policy), so a branch that changes them can change what counts as in place. Recorded under "Chỗ
còn hở" in `docs/setup-principles.md`.

**Not yet run**: the recipes against a real GitHub repository; `gh secret set` taking a value
on standard input for an environment secret.

### Fixed: the roadmap page of the feature loop is not an input of the heavy tier
`HEAVY_NOT_INPUTS` in the `ci.yml` of every preset, and the default list of `tools/ci_inputs.py`,
now end with `LO-TRINH.html`. The feature loop redraws that page in the commit that carries the
signature. It was an input, so that commit changed the key and the heavy tier ran again on a tree
whose code had not changed. Measured in `onehub-inventory`: 63 of 78 signature commits on `main`
differed from their parent only in this page among the inputs
([#71](https://github.com/phanlemanh/repo-standards/issues/71)).

- Only the file of that name at the root is left out. Another `.html` page, and a file of the same
  name in a subfolder, are still inputs.
- `docs/seam-contracts.md`, section 4, names the page next to `_acceptance/**`.

**What breaks on upgrade**: a pull request that changes only `LO-TRINH.html` (and other files
that are not inputs) reuses an earlier green heavy run instead of running the heavy tier. A
repository whose heavy tier reads that page loses a run it needs: take the name out of
`HEAVY_NOT_INPUTS` in its `ci.yml`. A repository that changed the line by hand to the same value
merges clean; one that changed it to something else gets the line between markers.

**Checked**: a scratch clone of `onehub-inventory`, which changed the line by hand to this value
before the fix: exit code 0, no conflict markers, `ci.yml` left as it is, and `tools/ci_inputs.py`
taking the new default. Nothing was pushed to it.

**Not yet run**: the reuse on a real pull request with a signature commit. The list itself is
tested on throwaway repositories.

## 0.10.4 — 2026-11-21

Two fixes, both found while the probe repository and `onehub-inventory` took 0.10.3.

### Fixed: an existing repository gets the merge method it uses, not `squash`
0.10.3 put `merge_method: squash` into the policy of every repository it upgraded. `squash` is
right for a new repository; one that exists already merges one way or the other, and the next
`tools/github_setup.py --apply` would have set it to squash only. Both repositories that took
0.10.3, the probe repository and `onehub-inventory`, merge with merge commits, and both had to
change the line by hand.

- The method is now read for the repository, in this order: the value its policy names; else
  `--var merge_method=merge` (or `squash`) of this run; else what an earlier run chose; else the
  last 20 commits of the branch, where a merge commit means `merge`. A repository with no commit,
  and a folder that is not the root of a repository of its own, get `squash`.
- The policy is where the choice is made. A value it names stays as it is, the manifest
  (`vars.merge_method`) follows it, and a `--var merge_method` that says otherwise is refused
  with the line of the policy to change, as `tools/github_setup.py` refuses one. Another word
  than `squash` or `merge` is refused too.
- A shallow clone that shows no merge commit cannot be read: git hides the parents of its last
  commits, so a merge commit there looks like any other. The run stops and asks for
  `--var merge_method=...` or for the full history, and writes nothing.
- Only a team repository has the policy, so only its manifest holds the variable.

**What breaks on upgrade**: nothing for a repository on 0.10.3: its policy names a method
already, and that value stays, also a `squash` the upgrade wrote and nobody changed. A repository
that comes from before 0.10.3 gets `merge` where its history holds a merge commit. An upgrade run
in a shallow clone of such a repository (`git clone --depth 1`, the default of
`actions/checkout`) stops until it is told the method.

**Known gaps**: the history is a guess. A repository that merges by rebase reads as `squash`; one
that squashes and has a merge commit made by hand among its last 20 commits reads as `merge`. A
`squash` that 0.10.3 wrote into a repository with merge commits cannot be told from a choice, so
it stays until a person changes it.

### Fixed: the policy file says what the agent pipeline does only where there is one
`governance/autonomy.yaml` carries a comment on the proof: once a check is named, "the PR pipeline
stops running its own reviewer agent". Every team repository got that line as a fact, also one
with no agent workflows, where no such pipeline runs. It is the same slip 0.10.3 took out of
`AGENTS.md`. Found on `onehub-inventory` while it took 0.10.3.

- The line now states its condition: "with agent workflows, the PR pipeline stops running its own
  reviewer agent".
- A check holds it: in a team repository without agent workflows, no line of the policy names the
  pipeline or its reviewer agent without those words.
- The `github` skill said the same thing as a fact, and still said a proof may never be named
  `gate`, which 0.10.2 allowed where no agent workflows report under that name. Both sentences
  now state the condition. No check holds the wording of a skill.

**What breaks on upgrade**: nothing. One comment of `governance/autonomy.yaml` changes; a
repository that edited the lines around it gets the usual three-way merge.

### Verified

- Offline suite on Linux and macOS, manifest validation and every end-to-end combination in CI:
  each of the two pull requests was green on the head that was merged, all five checks, `e2e` in
  21 minutes.
- What 0.10.3 listed as not yet run, an upgrade of a real repository to that version: the probe
  repository from 0.10.1 (phanlemanh/design-ci-probe#22) and `onehub-inventory` from 0.10.2
  (phanlemanh/onehub-inventory#98), both merged. Those two upgrades are where the two defects
  fixed here were found.
- The upgrade to this version on scratch clones of both repositories as they are now (on 0.10.3,
  the policy says `merge_method: merge`), full and `--depth 1`: exit code 0, no conflict
  markers, the method kept, `vars.merge_method` in the manifest set to `merge`. The only change
  to the policy is the comment of the second entry.
- The reading of the history on scratch clones of both repositories as they were before 0.10.3
  (the probe repository on 0.10.1, `onehub-inventory` on 0.10.2, no `merge_method` in either
  policy): both come out with `merge_method: merge`, where 0.10.3 wrote `squash`. The probe
  repository merges clean. `onehub-inventory` gets `governance/autonomy.yaml` between markers
  at the proof block it took out, the same place as on its real upgrade to 0.10.3, and the
  template's side there says `merge`.
- Nothing was pushed to either repository for this release: the clones were read and thrown away.
- Not yet run: an upgrade of a real repository to this version, merged; the stop in a shallow
  clone on a real repository (both name the method in their policy now, so their history is not
  read; the stop ran on repositories the tests build); `merge_method` on a real repository
  (`github_setup.py --apply`); an upgrade of a repository that was set up from a `devN` build;
  whether GitHub itself applies `merge=union` when it merges a pull request.

### Known gaps

- The gaps of the first entry are listed with it above: the history is a guess.
- The policy on `onehub-inventory` and what GitHub has there differ: the policy says `merge`,
  GitHub still allows merge, squash and rebase, because `github_setup.py --apply` has not run.
- `tools/ontology_actions.py`, a file every repository receives, is 856 lines, over the limit of
  800 the setup gives.
- No test runs the real tool of design-assembly or delivery-loop: the contracts in
  `docs/seam-contracts.md` are pinned from this side only.

## 0.10.3 — 2026-11-21

### Changed: the merge method is stored in `governance/autonomy.yaml`
`tools/github_setup.py` set squash unless `--merge-method merge` was passed, and nothing stored the
choice: one run that forgot the option set a repository back to squash only, which a feature loop
that needs merge commits (delivery-loop) cannot work with.

- `governance/autonomy.yaml` has `merge_method: squash` (or `merge`). `github_setup.py` sets that
  one method. An option that differs from it is refused with exit code 2, saying where the choice
  is made.
- A policy without the key (a repository from an earlier release): a run without the option
  leaves the merge settings as they are and says so; `--merge-method` still sets them for that
  run.
- A value that is neither `squash` nor `merge` turns `make check` red (`autonomy.py
  --check-codeowners` names it), and `github_setup.py` stops before any change. It never changes
  a tier.

**What breaks on upgrade**: the upgrade adds `merge_method: squash` to `governance/autonomy.yaml`.
A repository that merges with merge commits must set `merge_method: merge` in the same pull
request, or the next `github_setup.py --apply` sets it to squash. After that, a script that
passes `--merge-method merge` against a policy that says `squash` stops with exit code 2.
### Changed: a build between two tags has a version of its own, `X.Y.Z.devN`
Every commit between two tags carried the number of the release before it, so a repository set up
from the default branch recorded files under a release that did not hold them. That is how
`AGENTS.md` came out between conflict markers on the probe repository (0.10.1 fixed that case;
the gap stayed for a template that changes twice between tags).

- Right after a release the plugin's version becomes the next patch with `.dev0`
  (`python3 tools/bump_version.py dev`: 0.10.2 → 0.10.3.dev0; again: 0.10.3.dev1). From a dev
  version, `patch` releases that very number, and `minor` and `major` count from it. A dev
  version gets no changelog section and no tag.
- The upgrade path orders `X.Y.Z.devN` after every release before `X.Y.Z` and before `X.Y.Z`. A
  base recorded at a dev version is looked for in the plugin that runs, then in the releases
  before it, and never fetched as a release, since no tag has it. `doctor` reports a file
  written by a dev build as behind once a later release ran.
- The fast tests hold the rule for this repository: while `CHANGELOG.md` has entries under
  `## Unreleased`, the version is a `.devN`.

**What breaks on upgrade**: nothing for a repository set up from a tag. One set up from the
default branch now records `0.10.3.dev0` (and so on) in `.repo-setup.json` instead of the release
before.
### Added: the flow measure says which numbers are over their threshold
The owner chose a line in the report, and nothing more (2026-11-21): no exit code, no workflow, no
target in `make check`.

- `tools/sdlc_metrics.py` prints a "Thresholds" section, and `--json` a `thresholds` list:
  late red (more than 20% of the heads where the gate passed), red on the default branch per
  workflow (more than 1 in 20 finished runs), and the file in conflict most often (in more than
  half of the conflicting merges of the default branch). Each line says over, within, too few to
  tell (fewer than 20 cases), or not read, with the reason.
- The values are starting values the machine suggested on 2026-11-16; nothing derived them from
  data. They are named constants in the new `tools/sdlc_limits.py`, with the minimum sample.
- A number over its threshold never changes the exit code. Nothing runs the tool by itself: the
  page says how to run it and write it out (`--write`).

**What breaks on upgrade**: nothing. The JSON of `--json` gains the key `thresholds`, one more file
lands in `tools/`, and the page gains a section.

### Fixed: a team repository without the agent pipeline is not told that a gate raises the tier
The rule "Never delete or weaken a test to get green, and never loosen an `agent:` setting" in
`AGENTS.md` (from `55-autonomy.md`) went on "The gate sees both and raises the tier." Every team
repository got it, but only the agent pipeline runs that gate: elsewhere no gate sees anything.

- The rule keeps its first sentence. What catches a miss is said in "What holds these rules",
  which names the gate only where `.github/workflows/pr-pipeline.yml` is. A repository with the
  pipeline is still told so, there and in its own fragment.
- That rule is the last line of the rules in a team repository, right where a repository adds
  rules of its own. `git merge-file` marks two edits that touch, so the upgrade would have left
  conflict markers in such a repository. The merge of `AGENTS.md` now sets aside the lines a
  repository added after the template's last line, merges the rest three ways as before, and puts
  them back after it. A repository that also reworded the template's last line is still marked
  there.
- This also closes a gap 0.10.0 listed: rules kept right before the section, upgraded from
  starter to team, were marked because nothing said whether the team's rules or the
  repository's come first. Now the team's come first, then the repository's, then the section.

**What breaks on upgrade**: nothing. `AGENTS.md` loses one sentence, and a repository with rules
of its own at the end gets them after the template's text, as before.

### Changed: the flow measure tells where the time and the red go (RS10)
`tools/sdlc_metrics.py` printed about half the lines of the plan's measure; the rest were counted
by hand once, in the trace of decision to merge on `onehub-inventory`. It now prints them.

- **Late red no longer counts a draft.** Since the tiered CI (0.9.0) the summary job `check` is
  red while a pull request is a draft, because the heavy tier is skipped. Such a red (red at the
  step `Every tier is green`, beside a skipped job and no other red) was counted as late red. It
  is now counted apart, on a line of its own, and late red counts only reds that say something
  failed.
- **One row per CI job:** runs, green, red, cancelled, median minutes, machine hours, and how many
  reds ended at a step that runs checks (a `make` step), as against the summary step, another
  step, or a step not read.
- **The steps red on two or more branches**, as a sign of a red that is not one pull request's.
  Gate jobs and the summary step are left out. Test names are not read: that needs the log and
  the format of a test runner, and the page says so.
- **How a merged pull request spent its time,** from GitHub and git only: opened to last ready
  for review, ready to the last required check green on its last head (the checks the rules of
  the default branch require), green to merged; and the pushes (new heads CI ran on) and merges
  of the default branch after it was last ready. No file of the feature loop is read.
- **`--split DATE|TAG`** reports the window before and from a moment: a date, an ISO time, or a
  tag or commit of the clone. A pull request is on the side of its merge, an open one on the
  later side, a run on the side it was created.
- The tool is split into `sdlc_gh.py`, `sdlc_jobs.py`, `sdlc_pulls.py` and `sdlc_report.py`
  beside it, so no file nears the size limit.

**What breaks on upgrade**: the JSON of `--json` gains keys (`ci.jobs`, `ci.waiting_red`,
`ci.red_steps`, `ci.red_across_branches`, `pulls`), and with `--split` its top level becomes
`{split, before, after}`. Late red can go down on a repository with drafts: that is the
correction, not a change of the repository. The tool asks GitHub more (one timeline and one list
of check runs per merged pull request, the rules of the default branch), so a run takes longer:
on `onehub-inventory` one 11-day run makes about 2,200 API calls (1,729 workflow runs, each with
its jobs), close to half of GitHub's 5,000 an hour. Run one at a time.
Four new files land in `tools/`; a repository that copied `sdlc_metrics.py` alone must take them
too.

**Known gaps**: a pull request last ready before the window has its pushes left out, and the page
says how many. A repository whose rules require no check gets no times to and from green, with
that reason. A pull request with more than 250 commits loses merges, as before.

### Verified

- Offline suite on Linux and macOS, manifest validation and every end-to-end combination in CI:
  on `main` at `18b30ad`, which holds all five entries above, all five checks green, `e2e` in 26
  minutes. Each of the five pull requests was green on the head that was merged.
- The flow measure on real history, read only: `onehub-inventory` over 2, 3 and 6 days, and this
  repository over 17 days with and without `--split repo-setup-v0.9.0`. The job table, the time
  of a merged pull request, the steps red on several branches and the thresholds all print. On
  `onehub-inventory` from 14 November: late red 16 of 69, with 3 reds of a draft counted apart.
  One defect only real data showed (`gh --jq` prints a string without quotes, so the required
  checks were read only from the stand-in `gh` of the tests) was fixed before the merge, with a
  test.
- The thresholds on live data: `onehub-inventory` over 3 days, where every line says "too few to
  tell" because each sample is below 20. A verdict of "over" has been seen only on numbers saved
  from an earlier run, not on a live one.
- The version of a build between two tags: this repository itself carried `0.10.3.dev0` from the
  merge of that change until this release.
- What 0.10.2 listed as not yet run, the fenced `conventional-commits` job on a real runner: run
  on `onehub-inventory` after it took 0.10.2 (phanlemanh/onehub-inventory#95), by a trial pull
  request with one commit the hooks refuse (phanlemanh/onehub-inventory#96, closed unmerged).
  Read in the log of that run: the checkout with `persist-credentials: false`, the hook output
  between `::stop-commands::` and its closing token, and after the fence the error annotation
  naming the commit, with its `%` shown as written.
- Four of the five pull requests (the fifth was already on `main`) merged together on a scratch
  clone before they were merged, at the heads they had then: no conflict in `CHANGELOG.md` once
  the union rule was on the base, every entry whole, and the fast suite green on the result.
- Not yet run: `merge_method` on a real repository (`github_setup.py --apply`); an upgrade of a
  real repository to this version (the probe repository is on 0.10.1, `onehub-inventory` on
  0.10.2); an upgrade of a repository that was set up from a `devN` build; whether GitHub itself
  applies `merge=union` when it merges a pull request, which decides if the rule also helps
  there or only for merges made with git on a machine.

### Known gaps

- The gaps of the five entries are listed with them above.
- Nothing runs the flow measure by itself, and being over a threshold stops nothing: a line in
  the report only, by the owner's choice. A repository that never writes the report out does
  not see the line.
- A repository whose feature loop needs merge commits must say `merge_method: merge` when it
  upgrades: the upgrade writes `squash` where the key is missing.
- `tools/ontology_actions.py`, a file every repository receives, is 856 lines, over the limit of
  800 the setup gives.
- No test runs the real tool of design-assembly or delivery-loop: the contracts in
  `docs/seam-contracts.md` are pinned from this side only.

## 0.10.2 — 2026-11-20

Three fixes at the seams with design-assembly and delivery-loop. The first two were found by
reading each seam on both sides, on a repository that has all three tools (`onehub-inventory`),
then by running the setup; the third by that repository's acceptance round.

### Fixed: `gate` is the setup's own check name only where the agent pipeline reports it
`governance/autonomy.yaml` refused `gate` under `required_checks` ("is one of the setup's own
checks and is required already") and as `proof.check`, in every repository. Without agent
workflows nothing of the setup reports under that name and nothing required it, so the sentence
was untrue, and a repository whose feature loop reports its proof as `gate` could neither require
that check nor name it as the proof.

- `tools/autonomy.py` now takes `gate` as the setup's own only where
  `.github/workflows/pr-pipeline.yml` exists (`own_checks`). Elsewhere the name is the
  repository's: it may stand under `required_checks` or as `proof.check`, and
  `tools/github_setup.py` requires it.
- `check` and `secret-scan` stay the setup's own everywhere, as the comment in the policy file
  already said.

**What breaks on upgrade**: nothing. A repository with agent workflows gets the same answers as
before.

**Known gap**: a repository with agent workflows and another job called `gate` still has two jobs
reporting under one name. Give the other job a name of its own.

### Fixed: a conflict on a file that joins checks to `make check` no longer ends the run well
A repository that had its own `mk/design.mk` and added the `design` capability got exit code 0:
the file was reported as `conflict` and left alone, the rest of the layer was written, and
`design-guards` and `ui-floor` never joined `make check`, which went on printing "passed" and "no
heavy checks". The install commands printed next named `make ui-patch`, a target that did not
exist.

- Where the repository's own file sits at the path of an `mk/` template that puts targets in
  `CHECK_TARGETS`, `HEAVY_TARGETS` or `DERIVED_TARGETS`, and no file of the repository joins
  those targets, the run now ends with exit code 1, also with `--dry-run`. The file is still left
  as it is. `mk/upgrade.mk`, which puts itself first in the list, counts too.
- A repository whose own file joins the same targets itself loses nothing, and its run ends well.
- The run names the targets left out, next to the file (`skip_reasons` in `--json`) and in a note
  that says the way out: give the repository's file another name in `mk/`, since every
  `mk/*.mk` is read, then run again.
- A conflict on any other file is what it was: reported, left alone, exit code 0.

**What breaks on upgrade**: a repository that keeps a file of its own at such a path (for example
an `mk/derived.mk` or an `mk/design.mk` it wrote itself) and does not join the setup's targets
there now gets exit code 1 from `apply.py` until the file has another name. Its `make check` does
not change by itself.

**Known gap**: only files under `mk/` are read this way. A `Makefile` of the repository's own
where the setup's goes is still a plain conflict, with exit code 0.

### Fixed: what a commit-msg hook prints cannot reach the runner as a workflow command
Found by the acceptance round of `onehub-inventory` on its upgrade to 0.10.1. `conventional-commits`
(workflow "PR title") runs from the default branch (`pull_request_target`) and printed what the
hooks said as it came. A hook that prints the commit message back handed the message's lines to
the runner, and a line that starts with `::` is a workflow command there. The author of a pull
request could forge an annotation, mask a string in the log, or stop the commands that follow. The
verdict was not at stake: the exit code decides it, and a refused commit stayed red.

- What a hook printed is now shown between `::stop-commands::<token>` and `::<token>::`, so the
  runner reads it as text. The token is 32 hex characters from `/dev/urandom`, new on every call.
  Where no token can be made, nothing of the hooks' output is shown and the job is red.
- The job's own error lines quote the commit title, and pre-commit's error line, without control
  characters and with `%` escaped: a carriage return in a title started a line of its own, and
  the runner turns `%0A` into a line break.
- The checkout the hooks run in keeps no token of the repository (`persist-credentials: false`).

**What breaks on upgrade**: nothing. A repository that edited `pr-title.yml` in place gets the
change through the three-way merge.

**Known gaps**: GitHub lists at most 250 commits of a pull request, so the job judges no more
than that and does not say when a branch has more. `pipx run pre-commit` and the two actions are
named by a moving version, not a pinned one. The words of a refused commit's title still appear
in the job's error line, as text.

### Verified

- Offline suite on Linux and macOS, manifest validation and every end-to-end combination in CI:
  on `main` at `c1dbe05` (the two seam fixes merged) all five checks green, `e2e` in 23 minutes;
  on the head of the pull request with the third fix, `ad0761a`, all five green, `e2e` in 22
  minutes. The merge of that pull request, `a6491c7`, has the same tree; its run on `main` was
  still going when this was written.
- The upgrade case of the end-to-end suite now starts from 0.10.1: read in the log of the run on
  `main` at `c1dbe05`, the first one after that tag (`upgrade-python-from-repo-setup-v0.10.1`).
  This closes what 0.10.1 listed as not yet run.
- The probe repository is on the tag 0.10.1 (phanlemanh/design-ci-probe#21): exit code 0, only
  the manifest changed, all eight checks green. With the tag 0.10.0 the same run marked the whole
  of `AGENTS.md`.
- `onehub-inventory` upgraded from 0.9.0 to the tag 0.10.1 on a pull request
  (phanlemanh/onehub-inventory#93, not merged when this was written): one file updated, one
  merged, none marked; its light tier passes on a machine (2466 tests); the acceptance round of
  that repository judged the change with nine measures, all passed.
- The two seam fixes, each by a real run of the setup: a team repository without agent workflows
  that names `gate`, and a repository with its own `mk/design.mk` that adds the `design`
  capability. The fence around hook output, by running the job's own shell with stand-ins for
  `gh` and `pipx` and reading the output line by line as the runner does.
- Independent reviews of the three fixes found nothing critical or high. Their medium and low
  points are answered in the fixes, each with a test that failed first.
- Not yet run: the fenced job on a real runner (`stop-commands` and `persist-credentials: false`
  are read from GitHub's documentation); either seam fix on `onehub-inventory`, where both cases
  were seen; the join with design-assembly's real `affected.mjs`, which this side tests with a
  stand-in.

### Known gaps
- The gaps of the three fixes are listed with them above.
- The gaps 0.10.0 and 0.10.1 list are still open.
- How pull requests are merged is not stored: a run of `tools/github_setup.py` without
  `--merge-method merge` sets a repository back to squash only, and a feature loop that needs
  merge commits then breaks. The choice is kept by word.
- The names and shapes other tools rely on (the lists `CHECK_TARGETS`, `HEAVY_TARGETS` and
  `DERIVED_TARGETS`, the job names, the JSON of `affected.mjs`, the strings design-assembly
  recognises this setup's design checks by) are written down nowhere and pinned by no test.
- `plugins/repo-setup/scripts/apply.py` is 976 lines, over the 800-line limit for one file.

## 0.10.1 — 2026-11-20

### Fixed: a file written by a build between two releases finds its base on upgrade
Found on the probe repository, on its upgrade to the 0.10.0 tag: the whole of `AGENTS.md` came back
between conflict markers ("no matching base") and the run ended with exit code 1, although the
template of that file had not changed. The probe had been upgraded from `main` before 0.10.0 was
tagged. A build between two releases carries the version of the release before it, so the manifest
recorded `AGENTS.md` under 0.9.0 with the hash of a template 0.9.0 does not have. The lookup read
the recorded release and the older ones, found no match, and merged two ways against an empty
base.

- The templates of the running plugin are now tried first, whatever version the manifest names
  (`upgrade_base.BaseFinder.find`): a hash that matches proves the content. A file whose template
  did not change since it was written is `edited` again, and nothing is written into it.
- They are rendered with the choices the repository had, so a move from starter to team in the
  same run gets a three-way merge, not markers around the whole file.
- When they do not match, the answer is what it was: the recorded release, then the older ones.

**What breaks on upgrade**: nothing. One result changes: a file recorded under an older version
whose content is what today's template gives no longer needs that release's archive, so an upgrade
without network access goes through for it where it used to report `base_unread`.

**Known gap**: every commit between two releases carries the same version. A repository set up or
upgraded from such a commit, whose template of a file changes again before the next release, still
has no base for that file: it is merged two ways, with markers, if the repository edited it.
Upgrade from a tag.

### Verified

- Offline suite on Linux and macOS, manifest validation and every end-to-end combination in CI, on
  `main` at `f134e6a` (the fix above merged): all five checks green, `e2e` in 26 minutes. The
  end-to-end suite upgrades python from the newest release, now 0.10.0, and ts-node from
  `repo-setup-v0.7.0`.
- On a copy of the probe repository at `a59b938`, the state that 0.10.0 marked: with the fix the
  run ends with exit code 0, `AGENTS.md` is `edited`, no file is marked and only
  `.repo-setup.json` changes. With the 0.10.0 tag the same tree ends with exit code 1 and
  `AGENTS.md` marked from its first line to its last.
- An independent review of the fix found nothing at the critical, high or medium level.
- Not yet run: the probe repository itself, which waits for the tag of this release; an upgrade
  without network access of a file the fix now finds without a release.

### Known gaps
- The gap of this fix is listed with it above.
- The gaps 0.10.0 lists are still open.
- A base found in the running templates is labelled with the running version in conflict markers,
  since the manifest cannot say which build wrote the file.

## 0.10.0 — 2026-11-19

### Fixed: `conventional-commits` judges by the repository's own commit-msg hooks
Found on `onehub-inventory` after its upgrade to 0.9.0: `conventional-commits` (workflow "PR title")
was red on every pull request. The job called one hook by its id, `conventional-pre-commit`, and
that repository had replaced it with a commit-msg hook of its own, so pre-commit answered "No hook
with id `conventional-pre-commit` in stage `commit-msg`". A setup made by `tools/github_setup.py`
requires this check, so there the same edit would have blocked every merge.

- The job now runs the commit-msg stage (`pre-commit run --hook-stage commit-msg`), with no hook
  id: the hooks `git commit` runs in that repository judge each commit, whatever they are called.
- A repository whose hooks refuse no message is still red, and the job says so ("No hook of this
  repository refuses a message at commit-msg"): a green check that judges nothing is no wall. The
  job finds out by asking the hooks: before the commits, it gives them two messages no rule should
  accept (a single dot, and a line of 300 dots) and expects one refusal, so a hook that judges
  only the length counts as well as one that judges the format. It does not read the config for a
  `stages` line, so a hook whose stage comes from its own manifest counts too.
- When pre-commit itself cannot run (no `.pre-commit-config.yaml`, a config it cannot read, a hook
  repository it cannot fetch), the job says "pre-commit could not run in this repository" with
  pre-commit's own words, and does not blame the commits. It tells the two apart in two ways.
  An exit code above 1 is an error of pre-commit (3 when it cannot fetch a hook repository). A
  missing or unreadable config also ends with 1, like a refusal, so there the job looks for
  pre-commit's own error line, "An error has occurred: <kind>:", at the start of a line. Hooks
  print the commit message back, and those words inside a message are not read as an error: such
  a commit is reported as refused, like any other.
- The error line now reads "does not pass this repository's commit-msg hooks", since the format
  is the repository's.

**What breaks on upgrade**: a `.pre-commit-config.yaml` as the plugin writes it gives the same
result as before. Hooks that name no `stages` now also run in this job, once per commit, as they do
at `git commit`; they see only the message file, so a hook limited by `files` is skipped. One such
hook can turn a green check red: see the known gap. A repository that edited `pr-title.yml` in
place gets the change through the three-way merge.

**Known gap**: a hook that names no `stages`, runs on every commit (`always_run`) and needs the
project installed fails in this job, which installs nothing, and the check then goes red on every
commit. Give such a hook `stages: [pre-commit]`.

### Docs: git 2.38 or newer is listed in the install requirements
`tools/sdlc_metrics.py` (team level) replays merges of the default branch with
`git merge-tree --write-tree`, which git added in 2.38. On git 2.37 the back-merge numbers fail and
`tests/run.sh` reports 12 misses in its flow section. The READMEs now say so next to Python 3.11.

### Fixed: `dependency-audit` is green again on a `react-vite` setup with `design`
`npm audit --omit=dev --audit-level=high` (workflow "Security") had been red on every such setup since
2026-11-18: 8 high advisories, all through `shadcn`. The root is GHSA-fc5q-39xc-vjpf, a ReDoS in
`picomatch` (`<= 4.0.7`, no patched version yet), which `shadcn` pulls in through `@dotenvx/dotenvx`,
`@shadcn/registry`, `fast-glob`/`micromatch` and `ts-morph`.

- The design capability now installs `shadcn@4.23.0` with `--save-dev`. The app reads it only at
  build time: its CLI (`npx shadcn add`) and `@import "shadcn/tailwind.css"`, which Vite bundles. None
  of its code reaches the browser.
- Checked on a fresh `react-vite --with design` setup: `npm audit --omit=dev` finds 0
  vulnerabilities (10 before), `npm run build` gives the same CSS byte for byte, and `make check` is
  green with its 18 browser tests. The container `Dockerfile` runs `npm ci` before `npm run build`,
  so the build still has `shadcn`.
- `tests/run.sh` checks that the install line holds `shadcn@` only with `--save-dev`.
- The same advisory still reaches dev tools (`vite`, `vitest`, `typescript-eslint`). The job reads
  only what ships (`--omit=dev`), so it stays green until it matters there.

**What breaks on upgrade**: nothing turns red. A repository set up before this release keeps
`shadcn` under `dependencies` (npm wrote that `package.json`, the upgrade does not move a package),
so its `dependency-audit` stays red until it runs `npm install --save-dev shadcn@4.23.0` once.

### Rule kinds (RS7)
The generated `AGENTS.md` told every rule in the same voice, so nobody could tell a rule a machine
holds from a sentence. Now every rule says what holds it.

- `AGENTS.md` ends with a new section, **What holds these rules**. It lists the machines this
  repository has (for example `secret-scan`, the commit-format check, `make check` for module
  boundaries, the autonomy gate where the pull request pipeline runs it) with what each one catches and how it reacts, then says once that
  nothing listed covers the other rules. The list follows what is installed: a starter repository
  is not told of the commit check or the secret scan, a team repository is; going from starter to
  team adds the lines.
- In the plugin, every list item of the twelve `+AGENTS.md/` fragments carries a kind,
  `<!-- kept: <code> -->`: `word`, `none` (not a rule), or a machine listed in the new
  `rule-checks.toml`. `apply.py` takes the kinds off, so none reaches a repository.
- A machine may be named only when a test of this repository, tagged `# rule-check: <code>`,
  breaks the rule in a generated repository and sees the machine react. Seven machines qualify
  today. The count on this release: **13 rules held by a machine, 62 kept by word, 33 items that
  are not rules** (108 list items). `python3 plugins/repo-setup/scripts/rule_kinds.py check
  --tests tests` prints it; section 50 of `tests/run.sh` is red when an item has no kind, names a
  machine nobody registered, or names one without a tagged test.
- Six items that mixed a held rule with a worded one are now two items each (for example
  "Never commit secrets." and "Never commit `.env`. Configuration goes in `.env.example`."). The
  rules themselves did not change.

**On upgrade.** `AGENTS.md` gains the section and the six split items. A file nobody edited is
updated; a file with edits elsewhere is merged. A repository that added its own text at the very
end of `AGENTS.md`, where the section goes, keeps that text where it is and gets the section after
it, with no conflict markers: the section's place is last, so the order is known and nobody is
asked to sort it out. One case ends with conflict markers (`marked`, `make check` red until they
are resolved): the repository edited one of the six lines that are now split. A repository set up
with `--adopt` gets the split items and no section.

**For the plugin's authors.** A new list item in a `+AGENTS.md/` fragment needs a kind, or
`tests/run.sh` is red. Use `word` unless a tagged test proves a machine.

### Known gaps (rule kinds)
- Rules written in a paragraph or a table (the autonomy and SDLC fragments have some) are not
  list items, so nothing asks for their kind.
- "Not a rule" is the author's call; no check can tell a rule from a fact.
- On upgrade the section is found by its heading line. A repository that changed that line, or
  wrote inside the section, gets the ordinary merge: conflict markers where its edit meets a
  change of the template. So does text written right after the section's last sentence, when a
  release changes that sentence.
- Text the repository keeps right before the section still meets a release, or a move from
  starter to team, that adds a fragment at the end of the rules: both add at the same place and
  no rule says which comes first, so the file is marked. Text kept after the section does not
  meet such a fragment.
- The section follows the templates and the choices in `.repo-setup.json`, not the disk and not
  GitHub: a repository that deleted a check after setup still reads its line, and a check that the
  ruleset does not require is still named. `doctor` answers the second question.
- Repositories set up with `--adopt` skip files they already have, so the section could name a
  machine they lack; they get none until the manifest records which machines were written.
- The tag ties a test to a machine; that the test breaks the very rule is read by a person.
  Section 44b (the secret scan) is skipped on a machine without gitleaks, and its tag still counts.

### Verified

- Offline suite on Linux and macOS, manifest validation and every end-to-end combination in CI, on
  `main` at `eaea3af` (every package above merged): all five checks green, `e2e` in 20 minutes. The
  end-to-end suite upgrades python from the newest release (0.9.0) and ts-node from
  `repo-setup-v0.7.0`.
- Run on GitHub, on the private probe repository (react-vite, team, design): upgraded from `main`
  at `7e8a1b5`, the templates of 0.9.0, to `main` at `eaea3af` with no file marked
  (phanlemanh/design-ci-probe#20). The probe keeps a section of its own at the very end of
  `AGENTS.md`, added for this trial: the file is `merged` with no conflict markers, the two items
  it has among the six are split, the probe's section stays where it is and "What holds these
  rules" comes after it. A second run has nothing to do. `make check` is green on a machine, and
  all eight checks are green on the pull request, `conventional-commits` with the new
  `pr-title.yml` among them.
- The same probe tree upgraded with the build before the fix for own rules at the end of
  `AGENTS.md` (`cc6390c`): exit code 1 and `AGENTS.md` `marked` in one place, between the probe's
  section and the new one. This is the case the fix is for.
- An independent review of that fix compared the merge before and after on 6000 random cases:
  309 went from `marked` to `merged`, none lost a line of the repository or of the template, none
  had the heading twice, and none changed a result that was clean before.
- `dependency-audit` on the probe, a `react-vite` setup with `design` made before this release:
  green after `shadcn` moved to `devDependencies` there (phanlemanh/design-ci-probe#18).
- Not yet run: `conventional-commits` on `onehub-inventory`, where the red check was found (that
  repository is on 0.9.0); an upgrade from the tag of this release (the probe ran from `main`
  before the tag, so its manifest records 0.9.0); a move from starter to team on a real repository
  that keeps rules of its own in `AGENTS.md`. This release ran none of the other items 0.9.0 lists
  as not yet run.

### Known gaps
- The gaps of rule kinds and of the `conventional-commits` job are listed with their sections
  above.
- Still open from 0.7.0: a file without a final newline gets markers, the setup skills do not say
  that `apply.py --dry-run` ends with 1 when a file would be marked, the marker check misses a
  closing marker Prettier turned into a quote, `upgrade_wall` looks for the `include` lines exactly
  as the template writes them, and `production` has no reviewer on a private repository on the free
  plan.
- `plugins/repo-setup/scripts/apply.py` is 961 lines (930 at 0.9.0), over the 800-line limit for
  one file.
- `offline` on macOS went red once on `main` (at `bc31175`: exit code 1, no `FAIL` line) and green
  on the second attempt of the same commit. The cause is not found; a `printf | grep` pipe of
  `tests/run.sh` is suspected.
- The 0.9.0 gap on `dependency-audit` is closed for a new setup. A setup made before this release
  needs one command, see "What breaks on upgrade" of that fix.

## 0.9.0 — 2026-11-18

### Fixed: package.json no longer gets conflict markers when a Node repository upgrades
Found on the probe repository (0.7.0 -> 0.8.0, ts-node): 0.8.0 adds `"prepare"` as the last line
of `scripts`, and `npm install` had written `devDependencies` right after the `scripts` block. The
two changes touch, so the line merge (`git merge-file`) gave up and the upgrade reported
`package.json` as `marked`, with `make check` red until someone resolved it by hand.

- `package.json` is now merged key by key where the line merge meets
  (`upgrade_merge.merge_by_key`): this repository's keys keep their order and values, a key the
  template adds goes after the key that comes before it in the template, a key the template drops
  goes unless this repository changed it, and nested objects (`scripts`, `engines`) are merged
  the same way. The file is written the way npm writes it (`JSON.stringify` with the file's own
  indent, CRLF kept). The upgrade reports the file as `merged` and reminds you to run
  `npm install` again.
- The line merge and its markers stay where a key merge cannot keep both sides: one key changed
  on both sides to different values, a `package.json` that is not written the way npm writes it
  (someone formatted it by hand, which a rewrite would undo), or no base to read (a two-way merge).
- Only `package.json` is merged this way; every other file is merged by line as before.
- `tests/e2e.sh` runs a second upgrade case: ts-node from `repo-setup-v0.7.0` (override with
  `UPGRADE_NODE_FROM`), with that release's real install (`npm install`) run before the upgrade.
  Until now the upgrade case ran the python preset only, which is why this was missed.
- `tests/e2e.sh`, python upgrade case: it upgrades from the newest release, which is now 0.8.0, and
  it still built the base as a pre-0.8.0 repository (ledgers force-added to git, then `shape` must
  read `one-file`), so it was red on main. The case now reads the shape from the base release: a
  release with `mk/derived.mk` keeps its ledgers out of git and must stay `fragments`; an older one
  is checked and split as before.

**What breaks on upgrade**: nothing. A `package.json` that 0.8.0 would have marked now comes out
merged. A repository that already resolved the markers by hand has nothing to redo.

### Tiered CI (RS3)
Design: `docs/superpowers/specs/2026-11-17-tiered-ci-design.md`. A pull request that is not ready to
merge no longer pays for the heavy checks, and a push that changes nothing a heavy check reads
reuses the last green heavy run. Tried on the probe repository: the six trials passed (see
"Known gaps" for what they did not cover). Measured before
building, on `onehub-inventory`: 31 of 251 runs made while `gate` was red (12.4%) could have reused
a green heavy tier, 1,071 of 8,150 heavy minutes in those runs
(`docs/reports/2026-11-18-heavy-reuse-measure.md`).

**What is new**

- `make check` is now `check-quick check-heavy`. A layer lists its slow steps in `HEAVY_TARGETS`
  (the design capability puts `ui-floor` there) and everything else stays in `check-quick`.
  `make check-heavy` prints `no heavy checks` when a repository has none. The ts-node, python and
  claude-plugin Makefiles carry the targets.
- The three `ci.yml` templates have three jobs: `quick` (every push), `heavy` (after `quick`, when
  the pull request is ready for review, and always on main) and `check`, a summary cell that always
  runs (`if: always()`). `tools/ci_verdict.py` holds the rule of the summary cell, and its line
  for a skipped tier says which case it is: a draft (not its turn yet) or a tier it waits for that
  did not pass.
- `heavy` does not run its checks again when its input key matches an earlier green run: it ends
  green at once and says which run and commit it reuses. It is not skipped (a skipped `heavy`
  turns `check` red). `tools/ci_inputs.py` hashes the whole tree minus `HEAVY_NOT_INPUTS`
  (`docs/** wiki/** *.md _acceptance/**` in the templates). A green run saves a cache entry
  `heavy-ok-<key>` holding that run and commit; a later push with the same key restores it. A red
  run saves nothing. A pull request that moves from draft to ready (`ready_for_review`) runs
  `heavy`.
- `ui-floor` runs the screens a change reaches. On a pull request, `tools/ui_select.mjs` asks
  design-assembly's `tools/design-assembly/affected.mjs --json` which screens are reached and runs
  two Playwright lanes: the tests that name those screens, then the tests that name no screen. It
  runs the full set when the command is missing, fails or says all, on main, locally, with
  `UI_FULL=1`, and when no test names a reached screen. The heavy checkout uses `fetch-depth: 2`
  and passes `UI_BASE`.
- `tools/github_setup.py` warns when `heavy` or `e2e` is a required check: a skipped job counts as
  green, so only `check` stands for them. It drops nothing.
- This repository: `.github/workflows/test.yml` has `offline` and `validate` (light), `e2e` (heavy,
  by input key with `HEAVY_NOT_INPUTS: "docs/** *.md"`, runs only the combinations the change
  reaches through `tests/e2e_select.py`, every combination on main) and `check`. Section 49 of
  `tests/run.sh` (`tests/tiered_ci.sh`, 49a to 49k) holds the tests.
- A narrowed e2e list that holds `python` or `fastapi` also runs the upgrade case (`UPGRADE=1`):
  that case upgrades a python setup. Other narrowed lists do not reach what it reads.

**What breaks on upgrade**

- **`check` means the summary cell.** It is red unless both `quick` and `heavy` succeed. That
  includes a draft pull request (red there means "not your turn yet") and a pull request whose
  light tier is red. A repository that requires `check` keeps one required name; one that
  required `quick` or `heavy` by name should require `check` instead.
- **A repository that edited `ci.yml` in place** receives the new shape through the three-way
  merge of the upgrade path. It may conflict; resolve to the three jobs.
- **An `e2e` job a repository added itself** must move behind `quick` (as a heavy step, or as a
  job with `needs: quick` that `check` waits for), or stop being a required check. `github_setup.py`
  now says so.
- **The ts-node `quick` job runs `make build`**, not `npm run build`.
- **A Makefile edited in place** must keep `HEAVY_TARGETS`, `check-quick`, `check-heavy` and
  `check: check-quick check-heavy` after the merge. Without them `quick` is red ("No rule to make
  target check-quick"), and with `design` the browser step drops out and the design gate goes red.
- **The new `mk/design.mk` needs `tools/ui_select.mjs`.** An old `npx playwright test` line kept
  after a merge conflict makes the design gate red.
- **`make check` prints `no heavy checks`** when the repository has none.
- **The cache.** Each green heavy run leaves a tiny cache entry per input key.

**Known gaps**

- Run on the probe repository (`design-ci-probe`, the six trials in section 8 of the design, all
  passed): a pull request restores a key it saved, and a cancelled run saves none. Not yet seen:
  two runs saving the same key, and a pull request reusing a key saved on the main branch. The
  ruleset on `main` of this repository is still missing (section 9 of the design).
- Reuse assumes a test gives the same result on the same inputs. A flaky test can be reused once
  it was green; the full run on main is the net.
- Path-based selection can miss a break that comes through a path other than `extends`.
- Browser-test narrowing reads test titles: a test whose title holds a word starting with `/`
  counts as naming that screen, so on a pull request it runs only when that screen is reached. A
  test of a path that is not a screen (`/api/health`) named with its slash runs only on main;
  `.claude/rules/ui.md` tells builders to drop the slash.

### Verified

- Offline suite on Linux and macOS, manifest validation and every end-to-end combination in CI, on
  `main` at `7e8a1b5` (both packages above merged): all five checks green, `e2e` in 30 minutes. The
  end-to-end suite now upgrades two setups: python from the newest release (0.8.0), and ts-node
  from `repo-setup-v0.7.0` with that release's real `npm install` run first.
- Run on GitHub, on the private probe repository: upgraded from `repo-setup-v0.8.0` (ledgers
  already split) to `main` at `7e8a1b5` with no file marked; `quick`, `heavy` and `check` green
  on the first run. Then the six trials of section 8 of the tiered-CI design on one pull request,
  all passed: a red `quick` skips `heavy` and turns `check` red; a code change runs `heavy`; a
  docs-only push ends `heavy` green in 6 seconds, naming the run it reuses; a cancelled `heavy`
  and a draft turn `check` red; leaving draft runs `heavy`.
- This repository's own tiered `test.yml`: on a pull request that changes only docs, `e2e` ends in
  seconds instead of about 25 minutes.
- Not yet run: two runs saving the same input key; a pull request reusing a key saved on the main
  branch; the minutes-per-merged-PR comparison of `sdlc_metrics.py` after 10 pull requests; an
  upgrade from this release to the next; whether `claude-code-action` hands `claude_args` on
  unchanged; the PR pipeline of `github-agents` on GitHub; CodeQL on a public repository after the
  upgrade.

### Known gaps
- Still open from 0.7.0: a file without a final newline gets markers, the setup skills do not say
  that `apply.py --dry-run` ends with 1 when a file would be marked, the marker check misses a
  closing marker Prettier turned into a quote, `upgrade_wall` looks for the `include` lines exactly
  as the template writes them, and `production` has no reviewer on a private repository on the free
  plan.
- `dependency-audit` is red on a `react-vite` setup with `design`: `npm audit --omit=dev` reports
  high advisories in `shadcn` and the packages it pulls in, published after 0.8.0. The template
  lists `shadcn` under `dependencies`, although the sample app reads it only at build time
  (`@import "shadcn/tailwind.css"`). The job is not a required check.
- `plugins/repo-setup/scripts/apply.py` is 930 lines, over the 800-line limit for one file.
- The 0.8.0 gap on the probe's stand-in hashes is closed: its upgrade to 0.8.0 recorded real
  hashes, and the upgrade above found a base for every file.

## 0.8.0 — 2026-11-18

### Ledgers as fragments (RS2b)
Design: `docs/superpowers/specs/2026-11-17-ledger-fragments-design.md`. Two pull requests that each
add a log line, a glossary term or a wiki page no longer touch the same file, so the second one
should merge without "Update branch" (not yet measured on the probe repository).

**What is new**

- New `make derived` (`mk/derived.mk`, `tools/ledgers.py`): it draws every file a repository keeps
  out of git. Layers add to `DERIVED_TARGETS` (targets that draw) and `DERIVED_FILES` (files they
  draw). `derived` waits for `upgrade`; in each preset `lint`, `typecheck`, `test`, `ontology`,
  `build` and `dev` wait for `derived`, and so does every `make check` step a layer adds. It runs
  `ledgers.py`, `ledgers_split.py`, `ledgers_split_read.py`, `ledgers_ontology.py` and
  `ontology_codegen.py` with `LEDGERS_PYTHON` (default `python3`, standard library only), not
  `PYTHON`: in a python or fastapi repository neither `make derived` nor the SessionStart hook goes
  through `uv run`, which could sync a venv at every session start. `Makefile` gains one line
  (`... : | derived`) after `-include mk/*.mk`.
- Shape: `tools/ledgers.py shape <log|index|glossary|gen>` prints `one-file` or `fragments`. A ledger
  is `one-file` when its old file is in git and does not open with the stamp line; in every other
  case (the file absent, untracked, ignored, or tracked but stamped) it is `fragments`. Outside a
  git repository, an unstamped file that is there reads `one-file`.
- A drawn markdown file opens with `<!-- Drawn by tools/ledgers.py from <source>. Edit the source,
  not this file. sha256:<hex> -->`, `<hex>` being the hash of the rest of the file. A hand edit that
  adds a line no source holds makes `draw` exit 1, write nothing, list those lines and end with the
  way back: put each line in its source (an entry-shaped line with `make log m="..."` or
  `add-term`, any other line in the head file, an index line in a page), then delete the
  file and run `make derived`. Once every added line is in a source, or when the edit only removed
  lines, nothing would be lost and the file is drawn over. The generated code is stamped the same
  way, with ` sha256:<hex>` at the end of its first comment line.
- In the `fragments` shape a file at a drawn path that carries no stamp and that git does not track
  is never drawn over and never left alone in silence: `draw` exits 1, names it, lists its log
  lines or glossary rows that no source holds (head lines with the head file to move them to), and
  says to move it aside or delete it, then run
  `make derived`. The one exception is generated code whose first line is the header of
  `ontology_codegen.py` (someone ran the generator by hand): it is drawn over, stamped, so it
  follows `ontology/`. A tracked unstamped file is the `one-file` shape and is not affected.
- New `make check` steps: `derived-untracked` is red when a file of `DERIVED_FILES` is in git and
  opens with the stamp (it names the path and says `git rm --cached <path>`); `ledgers-check` is red
  for a log fragment with a wrong name, for a glossary fragment whose `term` is not its file name
  or that has no `display`, for a page with no `type` or `title`, and for two sources (see below).
- **Log.** `make log m="<text>"` (`ledgers.py add-log`): in the `one-file` shape it puts a line at
  the top of `wiki/log.md`; in the `fragments` shape it writes `wiki/log/YYYY-MM-DD-NN-<slug>.md`.
  `make derived` draws `wiki/log.md`: stamp, `wiki/log.head.md`, one line per entry, newest first.
  A hand-kept `wiki/log.md` beside entries in `wiki/log/` is "two sources": `draw` exits 1 and
  `ledgers-check` is red. The message lists every line of the hand-kept file that the drawn log
  lacks: an entry (also a malformed one, such as a hyphen for the dash) is to be copied, then
  `git rm wiki/log.md`, then added with `make log m="..."` (while the file is in git, `make log`
  writes into it); any other line goes into `wiki/log.head.md`. Only when no such line is left does
  it say the file is safe to delete.
- **Glossary.** `python3 tools/ledgers.py add-term <Term> --definition <s> [--display <s>]
  [--not-confused-with <s>]`: in the `one-file` shape it adds a row to the table of
  `ontology/glossary.md`; in the `fragments` shape it writes `ontology/glossary/<Term>.md` (front
  matter `term`, `display`, `not_confused_with`, a blank line, body one sentence; an empty key is
  written `key:` with no trailing space, so a `trailing-whitespace` or `end-of-file-fixer` hook
  leaves it as it is; the older form is still read) and touches nothing else. `make
  derived` draws `ontology/glossary.md` (stamp, `ontology/glossary.head.md` or a built-in head, a
  four-column table sorted by term, `|` escaped), even with no term, so `wiki_lint.py` still reads
  it. A hand-kept `ontology/glossary.md` beside fragments is two sources, with the same message as
  the log: every line the drawn glossary lacks is listed, a row to be copied, then
  `git rm ontology/glossary.md`, then added with `add-term`, any other line (a hand paragraph, a
  comment) into `ontology/glossary.head.md`. Only the template's own example row and closing
  comment, word for word, are left out; an edited or new `_Example:_` row is listed. Only when no
  such line is left does it say the file is safe to delete.
- **Index.** `make derived` draws `wiki/index.md` in the `fragments` shape: stamp,
  `wiki/index.head.md` (or a built-in head), one `## <Types>` section per page type of
  `ontology/page-types.yaml` in file order (types it does not know last), a line
  `- [<title>](<path>)` (plus ` — <summary>`) for each page, and the link to `log.md`. A page with no
  `type` or `title` is left out, named by `draw` (exit 0), by `ledgers-check` (red) and by
  `wiki_lint.py` ("page has no type or title"). The index has no fragment folder, so it is never "two
  sources": a tracked unstamped `wiki/index.md` is a one-file index; an untracked one is refused as
  above, so a new page never goes missing from the index unseen. In the `fragments` shape `wiki_lint.py` no
  longer warns "not linked from wiki/index.md", treats the drawn `wiki/index.md` and `wiki/log.md`
  and the entries of `wiki/log/` as no page, and `sdlc_metrics.py --write` no longer edits
  `wiki/index.md`. Hidden files (`.DS_Store`) in `wiki/log/` and `ontology/glossary/` are no
  fragments. `wiki_lint.py` draws a ledger kept as fragments when its drawn file is absent (a clean
  clone), so `/repo-setup:doctor` does not report a missing glossary or index before `make derived`.
- **Generated code** (`src/generated/ontology.ts`, `src/<pkg>/ontology_types.py`): in the `fragments`
  shape `make derived` draws it (`gen-derived`, `ledgers.py draw-gen`), only when the text changes,
  never over a hand edit that adds a line (exit 1, names the file and the lines, says to put what
  they say in `ontology/`, delete the file and run `make derived`).
  `make ontology` keeps `ontology_codegen.py --check` in the `one-file` shape and skips it in
  `fragments`; `make gen` draws in `fragments`. The two Node presets get `"prepare": "command -v
  make >/dev/null 2>&1 && make -s derived || true"`; `image`, `up` and `deploy` of the `container`
  layer wait for `derived`.
- `.claude/settings.json` gets a `SessionStart` hook that runs `make -s derived` (always exit 0; the
  error of a failed draw is printed for the agent; nothing happens when `make` or the Makefile is
  missing), so a session starts with the drawn files present.
- `github-agents`: the `review` job of `pr-pipeline.yml` checks the pull request out as data and runs
  none of its code, so its `claude_args` gain `--settings '{"disableAllHooks": true}'`: the hook
  above (and any hook a pull request adds to `.claude/settings.json`) does not run `make` from the
  pull request with that job's `pull-requests: write` and `id-token: write`. Claude Code's hooks
  documentation says this setting takes precedence over project and local settings. That
  `claude-code-action` hands `claude_args` to Claude Code unchanged is not yet checked on the probe
  repository.
- New `python3 tools/ledgers.py split <log|index|glossary|gen> [--dry-run]` (`tools/ledgers_split.py`
  with the parsers in `tools/ledgers_split_read.py`; also `make split L=<ledger> [DRY=1]`): the one
  command an existing repository runs, in a pull request of its own, to move a one-file ledger into
  fragments. It works everything out in memory, draws the ledger with the real drawer in a scratch
  copy, and compares by entry, not by text: every entry before is there after, word for word;
  entries whose place changed are printed. Whitespace inside an entry is collapsed to one space, as
  `make log` and `add-term` write it, and printed (`whitespace collapsed: ...`); an empty display
  name becomes the term (`display set to term: ...`). A lost or extra entry, two sources, a term that
  cannot be a file name, more than 99 log lines on one day, a page the index links that has no
  `type` or `title`, a `.head.md` changed since repo-setup wrote it (its sha256 differs from
  `.repo-setup.json`), or a file it cannot write makes it exit 1 and write nothing. A write that
  fails part way puts every file and the git index back as they were. Then it writes the fragments
  and the head file, moves each index description to the `summary` of its page, runs `git rm
  --cached` on the old file, adds its path to `.gitignore` and puts the drawn file in its place. The
  glossary's `_Example:_` row and closing comment are dropped, and said so, only as the template
  wrote them, word for word: an `_Example:_` row that differs is refused (make it a row of its own or
  delete it), and a closing comment with more in it stays in `ontology/glossary.head.md`. `gen` has no fragments:
  the committed generated file (it must match what `ontology_codegen.py` writes) leaves git and is
  drawn, stamped. `--verify-against FILE` runs the comparison alone against a copy of the old file.
- `doctor` lists the ledgers still kept as one file (`ledgers_split` in `--json`, a block in the text
  report) with their split command, `make split L=<ledger>`. It is a notice: the score does not
  move, and a repository without `tools/ledgers.py` gets nothing.
- Every writer calls the commands instead of editing a drawn file: `AGENTS.md` (the three files are
  drawn by `make derived`; a new page needs only `type` and `title`; one sentence for a repository
  whose `wiki/index.md` is still in git), the skills `ontology-add` (`add-term`), `wiki-ingest` (the
  date of the last ingest is the newest file in `wiki/log/`, or the top line of `wiki/log.md` in an
  old repository), `wiki-health`, `adopt` and `github`, the agent workflow `agent-ci-fix.yml` (`make
  log m="..."`), and `ontology/README.md`. The `ontology` and `wiki` checks of
  `checklists/top-tier.toml` accept the head files and `ontology/glossary/`.
- The ledger tools (`ledgers.py`, `ledgers_split.py`, `ledgers_split_read.py`, `ledgers_ontology.py`
  for add-term and the generated code, `wiki_lint.py`) pass a python repository's own `ruff check`
  and `ruff format --check`, so `make lint` keeps reading `tools/`. `claude-plugin` receives neither
  `ledgers_split_read.py` nor `ledgers_ontology.py`.
- New preset key `kept_quietly` (next to `user_owned`): a file listed there that the manifest does
  not record and the repository has is reported under `kept` with no note and no diff.
  `_core/preset.toml` lists the three head files, so an upgrade never asks anyone to merge one.
  Once `make split` rewrites a head file, it is taken out of `.repo-setup.json`: the head file is
  the repository's own.
- **Breaking for new repositories:** a repository set up from now on keeps its wiki log, wiki index
  and glossary as fragments. The starter no longer gives `wiki/log.md`, `wiki/index.md` or
  `ontology/glossary.md`; it gives `wiki/log.head.md`, `wiki/index.head.md`,
  `ontology/glossary.head.md` and the empty folders `wiki/log/` and `ontology/glossary/`. The three
  drawn files and the generated code are in `.gitignore` (the presets that generate code, ts-node
  and python, and the presets built on them, add the code's line), and the Node `.prettierignore`
  lists the drawn markdown. The archetypes `service-api` and `modular-monolith` no longer add
  `wiki/+index.md/50-decisions.md`: the decision pages are listed by the drawn index.

**What breaks on upgrade**

Running `apply.py` on an existing repository turns nothing red and splits nothing. It creates the
head files, the two folders (`.gitkeep`) and the hook, and adds the `Makefile` line, the `.gitignore`
lines and the Node `.prettierignore` lines. `wiki/log.md`, `wiki/index.md` and `ontology/glossary.md`
are reported as `dropped` (the template no longer gives them) and stay in place; a repository that
keeps them in git, unstamped, stays `one-file` and keeps every old rule (`wiki/log.md merge=union`
stays in `.gitattributes`, `derived-untracked` skips them, a committed generated file is still
compared by `make ontology`). A tracked file is not affected by `.gitignore`. `doctor` shows the
split notice. The following breaks, and only for what it names:

- A `.gitignore` edited next to its first section can still be marked on upgrade. The new block sits
  after that first section, so a `.gitignore` where a team only appended lines at the end merges
  cleanly. A `Makefile`, `.claude/settings.json` or `.prettierignore` edited where the template put its
  line has that line merged in, or marked on conflict (`make check` stays red on `upgrade` until a person resolves
  the markers).
- **A pull request open when a ledger is split** gets one "deleted here, modified there" conflict on
  the old file (`wiki/log.md`, `wiki/index.md`, `ontology/glossary.md`, or the generated code), because
  the split removes it from git. Take the deletion first on that branch (`git rm wiki/log.md`,
  resp. `git rm ontology/glossary.md`; `git diff MERGE_HEAD...HEAD -- <file>` shows what the branch
  added), then add the branch's own lines with `make log m="..."` or terms with
  `python3 tools/ledgers.py add-term ...`. The other order (`make log` first) writes into the
  conflicted file, which is still in git, and the line ends up twice. For the index, a new page
  needs only a `type` and a `title`; for the generated code, `make derived` draws it. Split in a pull request of its own, one
  ledger at a time.
- **A build that goes through neither `make` nor `npm ci` / `npm install`** lacks the drawn files
  once a ledger is split (and in a new repository): `src/generated/ontology.ts` or
  `src/<pkg>/ontology_types.py` is not in git, so `tsc`, `vitest`, `mypy` or `pytest` run by hand on a
  clean clone fail on the missing module, and a `docker build` that copies a clean clone has no
  generated file. Run `make derived` first (the `Makefile` targets and the Node `prepare` script do).
- **Prettier does not touch the drawn files or the fragments.** The Node `.prettierignore` lists
  `wiki/log.md`, `wiki/index.md` and `ontology/glossary.md` (a drawn file that any formatter rewrites
  is a hand edit and makes `draw` exit 1), and `wiki/log/` and `ontology/glossary/` (the fragments are
  machine-written; Prettier would rewrite a log line with `*x*` and cannot read a glossary front
  matter whose value starts with a backtick). A repository with its own formatter setup lists them
  there.
- In the `fragments` shape, an unstamped `wiki/log.md`, `wiki/index.md` or `ontology/glossary.md`
  that git does not track now makes `make derived` red (it used to be left alone); move it aside or
  delete it, then run `make derived`. A repository set up by this release has none.
- A hand edit of a drawn file, or a drawn file put back in git (for example `git add -f`), is red: `draw` exits 1, `derived-untracked` is red.

### Verified

- Offline suite on Linux and macOS, manifest validation and the end-to-end combinations in CI, on
  `main` at the merge of this package (`03c3b71`): all four checks green. A new end-to-end
  combination installs from tag `repo-setup-v0.7.0`, upgrades with this code, splits all four
  ledgers and runs `make check`.
- Not yet run: two pull requests at once on the probe repository, each adding a log line, a term
  and a page, merged one after the other without "Update branch" (the measurement this release is
  for); whether `claude-code-action` hands `claude_args` to Claude Code unchanged, so the review job
  runs with hooks off; an upgrade between two published releases that change a template (possible
  once this release is tagged); the PR pipeline of `github-agents` on GitHub; CodeQL on a public
  repository after the upgrade.

### Known gaps
- The gaps listed under 0.7.0 are still open: a file without a final newline gets markers, the
  setup skills do not say that `apply.py --dry-run` ends with 1 when a file would be marked, the
  marker check misses a closing marker Prettier turned into a quote, `upgrade_wall` looks for the
  `include` lines exactly as the template writes them, and `production` has no reviewer on a
  private repository on the free plan.
- Two files on the probe repository carry hashes no release gives (from the stand-in release used
  to verify 0.7.0), so its next upgrade merges them two ways, against an empty base.
- `plugins/repo-setup/scripts/apply.py` is 927 lines, over the 800-line limit for one file.

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

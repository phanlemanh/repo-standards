## Autonomy tiers

`governance/autonomy.yaml` says who decides that a change may merge. `low` needs no approval once the
required checks pass. `medium` is merged by a person. `high` changes the rules of the game and
needs a code owner.

- A tier is never a reason to stop and ask before you work: when to stop is decided by the
  workflow that drives you. Do the work, open the pull request, and say in it what a person has to
  decide. `python3 tools/autonomy.py --base origin/main` shows the tier and the file behind it. <!-- kept: word -->
- A change to `.github/workflows/` or `governance/` changes the rules of the game: it is `high`,
  and a code owner decides it. <!-- kept: autonomy-gate -->
- When the work needs such a change, draft it in a pull request of its own, with nothing else in
  it, and never merge it yourself. To change who decides a merge (`governance/autonomy.yaml`),
  follow `.claude/skills/autonomy-change/SKILL.md`. <!-- kept: word -->
- Do not merge a pull request yourself. A `low` one needs no approval once the checks pass (where the agent pipeline is
  installed, auto-merge merges it); any other merge is a person's decision. <!-- kept: word -->
- Never delete or weaken a test to get green, and never loosen an `agent:` setting in `ontology/`
  on your own. <!-- kept: autonomy-gate -->

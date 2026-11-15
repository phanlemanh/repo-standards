## Autonomy tiers

`governance/autonomy.yaml` says who decides that a change may merge. `low` merges itself when the
required checks pass. `medium` is merged by a person. `high` changes the rules of the game and
needs a code owner.

- A tier is never a reason to stop and ask before you work: when to stop is decided by the
  workflow that drives you. Do the work, open the pull request, and say in it what a person has to
  decide. `python3 tools/autonomy.py --base origin/main` shows the tier and the file behind it.
- Do not edit `.github/workflows/` or `governance/`: humans own them.
- Do not merge a pull request yourself. A `low` one merges itself when the checks pass; any
  other merge is a person's decision.
- Never delete or weaken a test to get green, and never loosen an `agent:` setting in `ontology/`
  on your own. The gate sees both and raises the tier.

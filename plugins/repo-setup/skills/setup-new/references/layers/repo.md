# Layer: repo

**Framing.** How is the code organised across repositories, and how do changes land and get released?

**Depends on:** context. Say how those decisions constrain this layer.

**Only one sensible answer when:** there is one product and one small team. Then say it in one line and move on.

## Options

Offer two or three. Put anything the user already named on the list, even if you would not
recommend it. Say when each option would be wrong.

| Option | Why | Trade-off | Wrong when | Label |
|---|---|---|---|---|
| One repo, one app | Least to run | Splitting later takes work | Several products ship independently | `automated` |
| Monorepo | Shared code, one change across packages | Tooling and CI get more complex | A small team with one package | `manual` |
| Several repos | Teams and releases stay independent | Changes across repos are slow | The parts always change together | `partial` |

Labels: `automated` (`apply.py` does it and it is verified), `partial` (the core is automated and
the manual steps are listed), `manual` (only recorded, with guidance; `doctor` does not score it).

For several repos, run setup once per repo; connecting them is manual. Other branching or
release rules are `manual`: the generated `CONTRIBUTING.md` describes the default.

**Recommendation when the user hands this to Claude:** one repo, one app; MIT for open code, Proprietary for company code. Branching and releases use the existing convention: short branches, squash merge, Conventional Commits.

## Recording

Write the result to `layers.repo` in `setup-blueprint.yaml`: `status`, `source` (`user` or
`proposed`), `automation`, `choice`, `why`, `rejected`, `manual_steps`.
Choice keys: `license`; for manual options record the decision in `why` and list `manual_steps`.

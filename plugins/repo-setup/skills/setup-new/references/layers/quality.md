# Layer: quality

**Framing.** How strict should the checks be? Level `team` adds pre-commit, secret scanning, coverage thresholds, CODEOWNERS and releases.

**Depends on:** repo. Say how those decisions constrain this layer.

**Only one sensible answer when:** one person on a small project: use `starter`. Then say it in one line and move on.

## Options

Offer two or three. Put anything the user already named on the list, even if you would not
recommend it. Say when each option would be wrong.

| Option | Why | Trade-off | Wrong when | Label |
|---|---|---|---|---|
| `starter` | Lint, types, tests, CI | No pre-commit or secret scan | Several people share the repo | `automated` |
| `team` | Shared, long-lived repo | More to learn and configure | Solo experiment | `automated` |
| A different coverage threshold or scanner | A team standard already exists | Edit the generated files by hand | The defaults are acceptable | `manual` |

Labels: `automated` (`apply.py` does it and it is verified), `partial` (the core is automated and
the manual steps are listed), `manual` (only recorded, with guidance; `doctor` does not score it).

**Recommendation when the user hands this to Claude:** `starter`. It can be upgraded later without starting again.

## Recording

Write the result to `layers.quality` in `setup-blueprint.yaml`: `status`, `source` (`user` or
`proposed`), `automation`, `choice`, `why`, `rejected`, `manual_steps`.
Choice keys: `level`.

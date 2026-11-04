# Layer: governance

**Framing.** How much may agents do on this repo, and who approves? Also: should the system offer tools to agents (MCP), and should agents work from GitHub issues?

**Depends on:** ai, quality. Say how those decisions constrain this layer.

**Only one sensible answer when:** level `starter` and no agents on GitHub: use the sample policy and say so. Then say it in one line and move on.

## Options

Offer two or three. Put anything the user already named on the list, even if you would not
recommend it. Say when each option would be wrong.

| Option | Why | Trade-off | Wrong when | Label |
|---|---|---|---|---|
| Local Claude Code only | Edits ask a person; nothing runs on GitHub | No agent picks up issues | The team wants agents on GitHub | `automated` |
| Add `github-agents` (level `team`) | Agents work from issues and open PRs | Needs the GitHub App, one secret and API spend. Not yet run against a real Claude session | No one will review the results | `automated` |
| Add `mcp` | Agents use the system through checked actions | Another surface to secure | Nothing outside needs the actions | `automated` |
| Custom tiers or approvers | An existing team policy | `governance/` is blocked for agents, so a person edits it | The sample policy fits | `partial` |

Labels: `automated` (`apply.py` does it and it is verified), `partial` (the core is automated and
the manual steps are listed), `manual` (only recorded, with guidance; `doctor` does not score it).

**Recommendation when the user hands this to Claude:** local Claude Code only. Never turn on `github-agents` without being asked.

## Recording

Write the result to `layers.governance` in `setup-blueprint.yaml`: `status`, `source` (`user` or
`proposed`), `automation`, `choice`, `why`, `rejected`, `manual_steps`. A layer marked `manual` is
not applied at all, so when a layer mixes both, use `partial`: keep what `apply.py` can do in `choice`
and put the rest in `manual_steps`.
Choice keys: `capabilities` (list), `marketplace`.

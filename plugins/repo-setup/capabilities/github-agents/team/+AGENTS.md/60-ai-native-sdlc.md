## AI-native SDLC (agents do the work, humans at the edges)

Humans decide **intent**, **risky changes** and **production**. Agents do everything between.

| Stage | Agent | Human edge |
| --- | --- | --- |
| Intent | Clarify in the issue; add testable acceptance criteria | Writes the intent issue, adds `agent:implement` / `agent:spec` |
| Spec | `wiki/specs/NNNN-*.md`, in the `spec` format of `ontology/page-types.yaml` | Approves (`spec:approved`) when the spec touches ontology, auth, data or infra |
| Build | Branch `agent/<issue>-<slug>`, tests first, `make check` green | — |
| Verify | Independent reviewer agent (no edit rights) checks spec ↔ code ↔ tests | — |
| Merge | `risk:low` merges itself after CI + agent review | Approves `risk:medium` / `risk:high` PRs |
| Release | release-please PR; staging deploy | Merges the release PR; approves the `production` environment |
| Operate | Triage, incident page, fix PR | Paged for severe incidents |
| Learn | `wiki/log.md`, decisions, weekly metrics | Tunes `governance/autonomy.yaml` |

### Rules for agents

- **Never** push to the default branch, merge a medium/high PR, approve your own work, or edit
  `.github/workflows/` and `governance/` (blocked in `.claude/settings.json`; humans own them).
- Tiers come from `governance/autonomy.yaml` (`python3 tools/autonomy.py --base origin/main`).
  Check the tier **before** you start: if the change is high-tier, write the spec, post it on the
  issue, add `spec:needs-approval` and stop.
- One intent → one branch → one PR. Keep PRs small; split if the spec has independent parts.
- Every acceptance criterion maps to at least one test. Never delete or weaken a test to pass CI
  (it raises the tier anyway).
- The PR description follows the template, including **Human decisions needed**.
- When blocked or unsure about intent: ask in the issue and stop. Do not guess requirements.

### Review (independent reviewer agent)

Follow `.claude/skills/review-change/SKILL.md`. Post findings as comments; label
`agent-review:approved` only when nothing blocks.

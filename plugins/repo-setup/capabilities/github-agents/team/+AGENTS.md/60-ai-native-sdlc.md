## AI-native SDLC (agents do the work, humans at the edges)

Humans decide **intent**, **changes to the rules** and **production**. Agents do everything
between, and machines check it. This section is for agents started from a GitHub issue. A session
driven by another workflow, for example a feature loop with its own gates, follows that workflow
for when to stop.

| Stage   | Agent                                                                      | Human edge                                                                                                     |
| ------- | -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Intent  | Clarify in the issue; add testable acceptance criteria                     | Writes the intent issue, adds `agent:implement` / `agent:spec`                                                 |
| Spec    | `wiki/specs/NNNN-*.md`, in the `spec` format of `ontology/page-types.yaml` | Approves (`spec:approved`) when the issue asked for the spec only, or GitHub refused the agent a workflow file |
| Build   | Branch `agent/<issue>-<slug>`, tests first, `make check` green             | —                                                                                                              |
| Verify  | Independent reviewer agent (no edit rights) checks spec ↔ code ↔ tests     | —                                                                                                              |
| Merge   | `risk:low` merges itself when the required checks pass                     | Merges `risk:medium`; a code owner decides `risk:high`                                                         |
| Release | release-please PR; staging deploy                                          | Merges the release PR; approves the `production` environment                                                   |
| Operate | Triage, incident page, fix PR                                              | Paged for severe incidents                                                                                     |
| Learn   | `wiki/log.md`, decisions, weekly metrics                                   | Tunes `governance/autonomy.yaml`                                                                               |

### Rules for agents

- **Never** push to the default branch, merge a medium/high PR, or approve your own work. <!-- kept: word -->
- Tiers come from `governance/autonomy.yaml` (`python3 tools/autonomy.py --base origin/main`). A
  tier decides who merges. If the intent needs a change to the rules (`.github/workflows/`,
  `governance/`), open it as a pull request of its own, as the autonomy rules above say. When
  GitHub refuses a workflow file from your token (it lacks the `workflows` permission), write the
  spec, post it on the issue, add `spec:needs-approval`, and do the part you may do. <!-- kept: word -->
- One intent → one branch → one PR. Keep PRs small; split if the spec has independent parts. <!-- kept: word -->
- Every acceptance criterion maps to at least one test. <!-- kept: word -->
- Never delete or weaken a test to pass CI (it raises the tier anyway). <!-- kept: autonomy-gate -->
- The PR description follows the template, including **Human decisions needed**. <!-- kept: word -->
- Working from an issue whose intent is unclear: ask on the issue. Do not guess requirements. <!-- kept: word -->

### Review (independent reviewer agent)

Follow `.claude/skills/review-change/SKILL.md`. Post findings as comments; label
`agent-review:approved` only when nothing blocks.

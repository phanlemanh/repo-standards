# Claude Code

@AGENTS.md

## Claude Code specifics

- With the `repo-setup` plugin installed, use its skills instead of improvising:
  `/repo-setup:ontology-add` (new or changed business concept),
  `/repo-setup:wiki-ingest` (record a change, decision or incident),
  `/repo-setup:wiki-query` (answer "why" questions from the wiki),
  `/repo-setup:wiki-health` and `/repo-setup:setup-doctor` (periodic checks).
- The plugin's hooks run `make check` and remind you about the wiki before you finish.
  Fix what they report; do not try to bypass them.

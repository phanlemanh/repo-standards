---
name: wiki-health
description: Health-check the repo's ontology and wiki — structural lint plus a review for contradictions, stale claims versus the code, missing entity pages and superseded decisions — and propose fixes. Use periodically, before a release, or when the user says the wiki or ontology may be outdated or inconsistent.
---

# Wiki and ontology health check

## 1. Structural check (mechanical)

Run `python3 tools/wiki_lint.py --strict --json`. Group the results: errors first
(broken links, unknown entities, missing sections), then warnings (orphans, glossary gaps,
missing entity pages). If `tools/wiki_lint.py` is missing, the repo predates it: offer
`/repo-setup:doctor` to add it, if that plugin is installed.

Also run the generated-code check (`make ontology`) to see if code generation is stale.

## 2. Content review (judgement)

Read `wiki/index.md`, every entity page, and the decision list. Look for:

- **Stale rules**: for each entity rule with `implemented_in`, open the code and compare
  the threshold/condition with the ontology and the wiki page.
- **Contradictions** between pages (two decisions in force for the same topic, an entity
  page that disagrees with the glossary).
- **Missing knowledge**: entities without a wiki page; important modules in `src/` with no
  entity, flow or decision mentioning them; incidents mentioned in commits
  (`git log --grep -i "hotfix\|incident\|outage"`) with no incident page.
- **Superseded decisions** still marked Accepted.
- **Bloat**: index longer than ~60 lines, pages that paste code.

## 3. Report and fix

Report in the user's language: score-like summary (errors / warnings / content issues),
then a short prioritised list. Fix with the user's approval, smallest changes first.
Ontology meaning changes go through ontology-add and need domain review.
After fixing, re-run wiki-lint and add one line to `wiki/log.md`:
`YYYY-MM-DD — wiki health check: <n> fixes`.

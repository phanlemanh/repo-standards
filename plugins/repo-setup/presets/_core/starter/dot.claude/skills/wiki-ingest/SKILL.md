---
name: wiki-ingest
description: Update the repo wiki from recent work — a branch/PR diff, merged commits, an incident, meeting notes or decisions from the conversation — following ontology/page-types.yaml. Use after finishing a task or PR, after an incident, or when the user says to record, document or update the wiki.
---

# Ingest knowledge into the wiki

The wiki (`wiki/`) records *why* things are the way they are. Code shows *what*.
You compile raw material into short, linked, sourced pages. Humans read; you write.

## 1. Gather the material
Pick what applies (ask if unclear):
- current branch: `git diff --stat main...HEAD` and `git log main..HEAD --oneline`;
- since the last ingest: date of the newest line in `wiki/log.md`, then
  `git log --since=<date> --oneline --merges` (or all commits);
- a PR or issue: `gh pr view <n>` / `gh issue view <n>` if `gh` is available;
- an incident or decision described in the conversation;
- files the user drops in `raw/` (if the repo uses one).

## 2. Decide which pages change
Read `wiki/index.md` and `ontology/page-types.yaml` first.
- **Always**: one line at the top of the list in `wiki/log.md`: `YYYY-MM-DD — what — source`.
- **New technical choice** (library, architecture, protocol, data store, convention):
  `wiki/decisions/NNNN-short-title.md` (next number). If it replaces an older decision,
  set the old one's Status to `Superseded by NNNN`.
- **Production problem**: `wiki/incidents/YYYY-MM-DD-short-title.md`.
- **Domain behaviour changed** (rule, state, property): update `wiki/entities/<name>.md`
  (History section) — and if the meaning changed, the ontology too (use ontology-add).
- **A multi-step business process** touched: `wiki/flows/<name>.md`.
Skip anything that is pure refactoring with no lasting "why".

## 3. Write
- Front matter: `type`, `title`, `links` (repo-relative paths), `sources`
  (PR/commit/issue/"user, <date>").
- Exactly the sections the page type requires, as `## Section` headings.
- Short: a page should be readable in one minute. Link to code paths instead of pasting code.
- Every claim must come from the material. If something is a guess, write
  "Needs confirmation:" and ask the user — never invent reasons.
- Link new pages from `wiki/index.md` in the right section.

## 4. Verify
Run `python3 tools/wiki_lint.py` (or `make ontology`) and fix all errors.
Run `make format` if the repo formats Markdown.

## 5. Report
List the pages created/updated with one line each. Do not paste the pages back.

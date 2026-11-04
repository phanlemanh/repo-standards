---
name: wiki-query
description: Answer questions about this project's domain, decisions, history or incidents from the repo wiki and ontology, checked against the code, and file valuable answers back into the wiki. Use when the user asks why something is built a certain way, what a business term means, what happened in a past incident, or how a flow works.
---

# Answer from the wiki

## 1. Navigate, don't grep blindly
1. Read `wiki/index.md`.
2. Follow links to the relevant entity / decision / incident / flow pages.
3. For business terms and rules, read `ontology/glossary.md` and
   `ontology/entities/<Name>.yaml`.
4. Only then open the code paths the pages point to.

## 2. Verify against the code
The wiki can be stale. When a page states a rule or behaviour that the answer depends on,
check the code it links to (`implemented_in`, "Where in the code").
If wiki and code disagree: answer from the **code**, say clearly that the wiki is out of
date, and offer to fix it (wiki-ingest / ontology-add).

## 3. Answer
- Lead with the answer, in the user's language.
- Cite the pages used as paths (`wiki/decisions/0003-use-postgres.md`).
- If the wiki has no answer, say so, answer from code/history if you can
  (`git log -S`, `git blame`), and note that it is not documented.

## 4. Compound the knowledge
If the answer took real digging and is likely to be asked again (a "why", a cross-cutting
explanation, a comparison), offer to save it: as a new page of the matching type, or as a
section on an existing page, then run `python3 tools/wiki_lint.py`. Only with the user's OK.

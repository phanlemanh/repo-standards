---
paths: ["ontology/**"]
---

# Changing the domain model

- Follow `/ontology-add` for a new or changed concept. After any edit here run `make ontology`
  and fix every error before you go on; it takes a second.
- Every entity answers four questions once `ontology/actions.yaml` exists: who creates it, who sees
  it, who changes it, who removes it. An action of that kind answers one; so does an entry under
  `lifecycle:` in the entity file.
- A feature that shows or stores an entity owes all four answers for it, not only the verb in the
  request. "Staff can add a fee" also asks: can a fee be renamed, and removed, and by whom?
- Leaving an operation out is a decision for a person. Ask; do not settle it yourself:
  - `later: <where it is planned>` when it will be built. Name the issue or roadmap row.
  - `never: <reason>` with `decided_by: <person, date>` when it must never exist. Write the name of
    the person who told you. Never fill `decided_by` yourself.
- A `later` is a debt: `make ontology` lists it on every run. When you build the action, delete
  the entry.
- Renaming or removing an entity, property or action is a breaking change: search for its uses
  first and say how many places change.

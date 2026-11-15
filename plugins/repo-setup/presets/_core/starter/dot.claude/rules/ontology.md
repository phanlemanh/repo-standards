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
- A relation is changed by people too. Each one in `ontology/relations.yaml` answers attach, detach
  and reassign: an action that names it (`relations: { keeps: [attach] }`), or `later` / `never`
  under `lifecycle:` on the relation. "A member keeps a listing" also asks: who gives a listing its
  first keeper, who takes it away, who hands it to someone else?
- `lifecycle: { via: <Entity> }` on a relation says the link is set when that entity is created and
  never changes. Write it only when that is true; if someone could ask to move it, ask the person.
- A role that acts only on its own records (`own: [role]` on the action) needs one relation marked
  `own: true`: the one that says what "own" means.
- Every property is set by an action, or the entity says why not. An action names what it sets with
  `sets: [...]`; its input fields with a property's name count when `sets` is absent. The rest go
  under `not_set:` in the entity file: `system`, `import`, `later` or `never`. "Staff can change
  the price" also asks: and the other properties, who changes those?
- `system` and `import` are facts you may write. `never` is a decision: same rule as above.
- A `later` is a debt: `make ontology` lists it on every run. When you build the action, delete
  the entry.
- Renaming or removing an entity, property or action is a breaking change: search for its uses
  first and say how many places change.

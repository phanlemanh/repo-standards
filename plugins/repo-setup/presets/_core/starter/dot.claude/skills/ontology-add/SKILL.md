---
name: ontology-add
description: Add or change a business concept in the repo's ontology — entity, property, subtype rule or relation — keeping glossary, entity YAML, relations, wiki page and generated types in sync. Use when the user introduces a new domain concept, changes a business rule, or asks to model their domain.
---

# Add or change a domain concept

The ontology (`ontology/`) is the source of truth for business meaning. A change here
changes what the whole system means, so do it completely and make it easy to review.

## 1. Understand the concept (ask only what is missing)

- Name in code (PascalCase, singular: `Customer`, not `Customers`/`Client`). Check
  `ontology/glossary.md` first: if a synonym exists, reuse it and tell the user.
- One-sentence definition, and what it must NOT be confused with.
- Properties: name, type, required or default, constraints.
- Subtypes with a rule (e.g. `VIPCustomer: points >= 100`).
- Relations to existing entities and cardinality. For each: can it be attached later, detached,
  or moved to another owner, and by whom? Or is it set once when one end is created?
- For each property: who sets it, and who may change it afterwards? "The system" and "an import"
  are answers too.
- Business rules and where they are (or will be) implemented.
- Its whole life, per role: who creates it, who sees it, who changes it, who removes it, and any
  step of its own (archive, lock, publish, hand over). An operation nobody mentioned is a question
  for the human, not a gap to skip: "X can be added; can it be renamed or removed, and by whom?"

## 2. Write the files

1. The glossary: `python3 tools/ledgers.py add-term <Name> --definition "..."`, plus
   `--display "..."` and `--not-confused-with "..."` (both optional). It writes one file,
   `ontology/glossary/<Name>.md`; `ontology/glossary.md` is drawn from those files by
   `make derived`, so never edit it. The code name is English. The display name and definition
   follow the repo's `docs_language`. If `ontology/glossary.md` is still in git (this repository
   has not split it yet), the same command adds the row to it.
2. `ontology/entities/<Name>.yaml` — same shape as `_template.yaml`:
   - `name` must equal the file name; `description` required.
   - property `type`: `string text integer number boolean date datetime uuid enum ref`
     (`enum` needs `values: [...]`; `ref` needs `target: <Entity>`).
   - `required: true` or a `default` makes a property non-optional in generated code.
   - subtype `rule`: comparisons joined by `and`/`or`, e.g. `"points >= 100 and status == 'active'"`.
     Only required/defaulted properties can be used, otherwise no predicate is generated.
   - `wiki: wiki/entities/<name>.md`, and `rules[].implemented_in: <path>` when known.
3. `ontology/relations.yaml`: `{from, name, to, cardinality}`; cardinality is
   `one-to-one | one-to-many | many-to-one | many-to-many`.
4. `wiki/entities/<name>.md` with front matter
   `type: entity`, `title`, `links: [ontology/entities/<Name>.yaml]`, `sources: [...]`
   and sections `## Definition`, `## Rules`, `## Where in the code`, `## History`.
   `type` and `title` are all the index needs: it lists the page under Entities by itself. If
   `wiki/index.md` is still in git, add the link there under Entities.
5. **Personal data**: mark properties that identify or describe a person with `pii: true`
   (name, phone, email, address, national id, birth date...). Generated helpers redact them in
   logs and in anything returned to AI agents.
6. **Actions** (what can be _done_): `ontology/actions.yaml` — `name` (camelCase verb),
   `description`, `entity`, `kind` (create/update/delete/query/command), `input` (same property
   types), `output` (entity, `Entity[]` or none), `roles`, `agent` (`allowed` / `confirm` /
   `forbidden`), `idempotent`. Roles live in `ontology/roles.yaml` (`name`, `inherits`,
   `description`); include an `agent` role if AI agents act on the system.
   Default to `agent: forbidden` for anything destructive or irreversible, `confirm` for
   money, points or personal data changes; ask the human when unsure.
7. **Lifecycle**: once `ontology/actions.yaml` exists, each entity needs a `create`, `query`,
   `update` and `delete` action. What the actions do not cover goes under `lifecycle:` in the
   entity file, one entry per operation:
   - `{ later: <where it is planned> }` when it will be built: say where (issue, roadmap row).
   - `{ never: <reason>, decided_by: <person, date> }` when it must never exist. Only a person
     decides this. Ask, then write their name: never fill `decided_by` yourself or with "agent".
   - `lifecycle: { via: <Entity> }` for a part that is created, changed and removed only through
     its parent (an order line through its order).
8. **Relations**: once actions exist, each relation answers `attach`, `detach` and `reassign`
   (a many-to-many relation: `attach` and `detach`).
   - An action answers by naming the relation: `relations: { keeps: [attach, reassign] }`.
   - What no action does is recorded on the relation, under `lifecycle:`, with the same
     `{ later: ... }` and `{ never: ..., decided_by: ... }` entries as above.
   - `lifecycle: { via: <Entity> }` when the link is set as that entity is created and never
     changes (an order and its customer). It replaces all three answers, so use it only when true.
   - A role that may act only on its own records gets `own: [role]` on the action, next to
     `roles`. One relation must then say what "own" means: mark it `own: true`.
9. **Properties**: once an entity has a create or update action, each of its properties is set by
   an action or listed with a reason.
   - An action sets its input fields that carry a property's name. Write `sets: [price, fees]`
     when the names differ or to be exact; `sets` then replaces the input fields.
   - Under `not_set:` in the entity file: `system: [id, createdAt]` (the system writes them, or
     they are derived), `import: [...]` (only an import writes them),
     `later: { <property>: <where it is planned> }`, and
     `never: { <property>: { reason: ..., decided_by: ... } }`. `never` follows the rule of step 7.
10. `make log m="ontology: <what changed>"` (one entry of the wiki log; never edit `wiki/log.md`).

## 3. Regenerate and verify

Run `make gen`, then `make format` (if available), then `make check`. `make gen` also
rewrites the API contract (service-api) and the MCP tool list; implement any new action in
the actions module (the compiler/mypy lists missing handlers).
`make ontology` alone runs wiki-lint + the generated-code check.
Fix every wiki-lint error before continuing.

## 4. Use it

Point the user to the generated types (`src/generated/ontology.ts` or
`src/<package>/ontology_types.py`) and use them in the code you write. Never edit the
generated file by hand.

## 5. Hand-off

In the summary / PR description, list the ontology changes explicitly under
"Domain changes — needs domain review". List every `lifecycle` and `not_set` entry you added there
too: each `later` with where it is planned, each `never` with who decided, each `via` on a relation.
Renaming or removing an entity or property is a breaking change: search the code for usages first
and say how many places change.

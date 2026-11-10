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
- Relations to existing entities and cardinality.
- Business rules and where they are (or will be) implemented.

## 2. Write the files

1. `ontology/glossary.md`: one table row `| \`Name\` | definition | not to be confused with | display name |`.
The code name is English. The display name and definition follow the repo's `docs_language`.
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
   Link it from `wiki/index.md` under Entities.
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
7. Append one line to `wiki/log.md`.

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
"Domain changes — needs domain review". Renaming or removing an entity or property is a
breaking change: search the code for usages first and say how many places change.

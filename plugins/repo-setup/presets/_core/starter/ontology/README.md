# Ontology

The domain model of this project: which business concepts exist, what they
mean, how they relate, and which rules apply. It is the **source of truth**
for people, code and AI agents.

| File              | Contains                                            |
| ----------------- | --------------------------------------------------- |
| `glossary/*.md`   | One file per business term, in plain language       |
| `glossary.md`     | Same terms in one table, drawn by `make derived`    |
| `entities/*.yaml` | One file per concept: properties, rules, subtypes   |
| `relations.yaml`  | How concepts connect (`Customer -places-> Order`)   |
| `page-types.yaml` | Allowed wiki page types and their required sections |

## How to change it

1. Edit the YAML and the glossary in the same PR as the code that depends on it. A new term:
   `python3 tools/ledgers.py add-term <Term> --definition "..."` (it writes `glossary/<Term>.md`;
   `glossary.md` is drawn from the fragments, so do not edit it).
2. Ontology changes change the meaning of the system: say so in the PR description.
3. Start small: 3–5 core entities. Add more only when they cause confusion.

## Lifecycle

Once `actions.yaml` exists, every entity answers four questions: who creates it, who sees it, who
changes it, who removes it. An action of that kind is an answer. So is a line under `lifecycle:` in
the entity file: `later` (planned, with where), `never` (with the person who decided), or `via`
(handled through its parent). `make ontology` fails on an operation with no answer, and lists
every `later` on each run.

## Relations

A relation is a thing people change, not only a line on a diagram. Once `actions.yaml` exists, every
relation in `relations.yaml` answers three questions: who attaches it, who detaches it, who moves it
to another owner. An action answers by naming the relation: `relations: { keeps: [attach] }`. So
does a line under `lifecycle:` on the relation itself, in the same words as for an entity: `later`,
or `never` with the person who decided. A link that is set when one end is created and never
changes says so once: `lifecycle: { via: <that entity> }`. A many-to-many relation is asked only to
attach and detach.

When a role may act only on its own records (`own: [role]` on the action), one relation must say
what "own" means: mark it `own: true`. `make ontology` fails on an own scope with no such relation.

## Properties

Every property of an entity that has a create or update action is set by one of them. An action
names what it sets with `sets: [price, fees]`; without `sets`, its input fields with the same name
as a property count. A property no action sets is listed under `not_set:` in the entity file, with
the reason: `system` (the system writes it, or it is derived), `import` (only an import writes it),
`later` (planned, with where), or `never` (with the reason and the person who decided).

Files starting with `_` (like `entities/_template.yaml`) are templates and are ignored.

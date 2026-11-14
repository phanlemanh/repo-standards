# Ontology

The domain model of this project: which business concepts exist, what they
mean, how they relate, and which rules apply. It is the **source of truth**
for people, code and AI agents.

| File              | Contains                                            |
| ----------------- | --------------------------------------------------- |
| `glossary.md`     | Plain-language definitions of every business term   |
| `entities/*.yaml` | One file per concept: properties, rules, subtypes, and its `lifecycle` |
| `relations.yaml`  | How concepts connect (`Customer -places-> Order`)   |
| `page-types.yaml` | Allowed wiki page types and their required sections |

## How to change it

1. Edit the YAML / glossary in the same PR as the code that depends on it.
2. Ontology changes need a human reviewer (they change the meaning of the system).
3. Start small: 3–5 core entities. Add more only when they cause confusion.

## Lifecycle

Once `actions.yaml` exists, every entity answers four questions: who creates it, who sees it, who
changes it, who removes it. An action of that kind is an answer. So is a line under `lifecycle:` in
the entity file: `later` (planned, with where), `never` (with the person who decided), or `via`
(handled through its parent). `make ontology` fails on an operation with no answer, and lists
every `later` on each run.

Files starting with `_` (like `entities/_template.yaml`) are templates and are ignored.

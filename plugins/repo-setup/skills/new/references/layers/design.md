# Layer: design

**Framing.** How should the screens look and read? This decides the visual floor of the product:
components, colours, spacing, number and date formats.

**Depends on:** context, stack. The description in `context` says whether people work in the
screens all day or read them; the stack must have a screen at all.

**Only one sensible answer when:** the stack has no user interface (for example `python`,
`fastapi`, `ts-node`, `ts-api`). Then write `not_applicable` in one line and move on.

**Stack `claude-plugin`:** not applicable. A plugin marketplace has no screens: the design floor is for a web front end (`react-vite`). Say that in one line, record `status: not_applicable` with it as `why`, and move on.

## Options

Offer these three. There is no "skip" row: a team that deliberately wants no floor records
`automation: manual` with a `why`, and the scoring table takes points off for it.

| Option | Why | Trade-off | Wrong when | Label |
|---|---|---|---|---|
| `shadcn` | Ready components, one accessible look, checked by lint | One visual family, restyled through a single brand colour | The company already has its own design system | `automated` |
| `company` | The company design system is the source of truth | Nothing is generated; the team wires it in | No such system exists yet | `manual` |
| `other` | A library the team already knows | Nothing is generated and the floor is not checked | `shadcn` would do | `manual` |

Labels: `automated` (`apply.py` does it and it is verified), `manual` (only recorded, with
guidance; `doctor` does not score it).

**Recommendation when the user hands this to Claude:** `shadcn`. Infer `surface` from the
description in `context`: `tool` when people work in the screens (back office, dashboards,
forms), `content` when people mostly read (marketing, docs, blogs). Keep the default identity
unless the user names a brand colour.

## Recording

Write the result to `layers.design` in `setup-blueprint.yaml`: `status`, `source` (`user` or
`proposed`), `automation`, `choice`, `why`, `rejected`, `manual_steps`. Write `choice` as a block,
one key per line.

Choice keys:

- `base`: `shadcn`, `company` or `other`.
- `surface`: `tool` or `content`.
- `brand_primary`: a `#rrggbb` colour, always in double quotes (an unquoted `#` starts a YAML
  comment and the value is lost). It needs a contrast of at least 4.5 against white text.
- `locale` and `currency`: filled in by the machine from `conversation_language` (`vi` gives
  `vi-VN` and `VND`; anything else gives `en-US` and `USD`) and shown in the final review so the
  user can veto them.

A font change is not a choice key: record it in `manual_steps`.

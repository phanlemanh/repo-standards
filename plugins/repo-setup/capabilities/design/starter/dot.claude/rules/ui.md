---
paths: ["src/**/*.tsx"]
---

# Building screens

- Use the components in `src/components/ui`. Never write a raw `button`, `input`, `select`,
  `textarea` or `table`. If one is missing, follow the `ui` skill.
- Do not edit `src/components/ui`. Change the look through the tokens in `src/index.css`.
- Copy the structure of a new screen from `src/example`: one `main`, one `h1`, and every state
  in `design/behaviors.md` that the screen can reach.
- Take every word from `src/lib/labels.ts`, and format every number and date with
  `src/lib/format.ts`.
- Use the token classes (`bg-primary`, `text-muted-foreground`) and the spacing and size scales.
  `make lint` rejects raw colours, arbitrary values and inline styles.
- Register every new screen in `src/screens.ts`, with its path and states. The app, the unit tests
  and `make ui-floor` read that list.
- `tools/design_guards.mjs`, `tests/e2e/floor.spec.ts` and `mk/design.mk` belong to the plugin. Do
  not edit them here: change them in the plugin and re-apply, or `doctor` loses points.

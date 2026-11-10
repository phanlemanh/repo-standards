---
name: ui
description: Find, read or add an interface component from the project's component base. Use before building a screen that needs a component not yet in src/components/ui, or when unsure how a component is used.
---

# Components

The component base is shadcn, pinned to one version. Always call it with that exact version.

1. Look for it: `npx shadcn@4.23.0 search @shadcn -q "date picker"`.
2. Read how it is used: `npx shadcn@4.23.0 docs calendar`.
3. Read its source before you install it: `npx shadcn@4.23.0 view @shadcn/calendar`.
4. Install it: `npx shadcn@4.23.0 add calendar`. Then run `make format`.

## Blocks

Search results marked `(block)` are ready-made sections. Read them with `view` for
ideas on structure and never `add` them: they bring their own layout and words past the guards.
Build the section from components, with `src/example` as the model.

## After adding

- Leave the files in `src/components/ui` as they arrive.
- Run `make check`. A guard failure means the screen should change, not the guard.

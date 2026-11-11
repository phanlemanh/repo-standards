---
paths: ["src/**/*.tsx"]
---

# Building screens

- Copy the structure of a new screen from `src/example`: one `main`, one `h1`, its data from a
  source module next to it (`data.ts`), and every state the screen can reach.
  `design/behaviors.md` says what each state shows and the text density.
- A state appears because of a real condition: a pending or failed request, an empty result, a
  filter with no match, a user action. Never because of a switch: a prop or URL value that exists
  only to pick the state. Tests choose the condition through the data source.
- Register every new screen in `src/screens.ts`, with its path and how to reach each state: the
  data source's scenario, the user's steps, and the text the state shows. The app, the unit tests
  and the browser checks read that list; there is nothing else to wire.
- Use the components in `src/components/ui`. Never write a raw `button`, `input`, `select`,
  `textarea` or `table`.
- Do not edit `src/components/ui`. Change the look through the tokens in `src/index.css`.
- Take every word from `src/lib/labels.ts`. Format every number and date with `@/lib/format`.
- Use the token classes (`bg-primary`, `text-muted-foreground`) and the spacing and size scales.
  `make lint` rejects raw colours, arbitrary values and inline styles.

## Loop

- Fast loop while building a screen: `make format lint ui-floor` (formatting, guards, then the
  browser checks at 1440 and 390 px).
- Before you finish: `make check`. A guard failure means the screen should change, not the guard.

## Traps

- A link that looks like a button stays a link:
  `<a href="..." className={buttonVariants({ variant: "outline" })}>`, with `buttonVariants` from
  `@/components/ui/button`. Never copy button classes onto an `<a>` by hand.
- Spacing inside a `Card`: put content in its slots (`CardHeader`, `CardContent`, `CardFooter`).
  For a stack inside a slot, wrap it in a plain `div` with `flex flex-col gap-*`; `gap` on the
  `Card` or a slot is rejected. For tighter cards use `size="sm"`.
- Numbers, money and dates only through `@/lib/format`, never `toLocaleString` or `Intl`.
- Wide tables on phones: the `Table` container scrolls sideways. Give `Table` an `aria-label` and
  do not force column widths.
- Statuses must stay visually distinct. If a `Badge` fails contrast, pick another variant; never
  give two statuses the same look to pass a check.
- A new screen that the browser checks never visit is missing from `src/screens.ts`.
- A state reachable only from a switch is not a state: the running app never shows it.

## Adding a component

shadcn is pinned to one version; always call it with that version.

1. Find it: `npx shadcn@4.23.0 search @shadcn -q "date picker"`.
2. Read how it is used: `npx shadcn@4.23.0 docs calendar`, and its source:
   `npx shadcn@4.23.0 view @shadcn/calendar`.
3. Install it: `npx shadcn@4.23.0 add calendar`, then `make ui-patch format`.

Results marked `(block)` are ready-made sections: read them with `view` for ideas, never `add`
them. They bring their own layout and words past the guards.

`tools/design_guards.mjs`, `tests/e2e/floor.spec.ts` and `mk/design.mk` belong to the plugin. Do
not edit them here: change them in the plugin and re-apply, or `doctor` loses points.

---
paths: ["src/**/*.tsx"]
---

# Building screens

- Copy the structure of a new screen from `src/example`: one `main`, one `h1`, its data from a
  source module next to it (`data.ts`), and every state the screen can reach.
  `design/behaviors.md` says what each state shows.
- Register every new screen and its states in `src/screens.ts`, as its comment says, paths with
  parts (`/orders/:id`) included. The app, the unit tests and the browser checks read that list;
  there is nothing else to wire.
- The sample screen sits at `/example`; your first screen takes `/`.
- Use the components in `src/components/ui`, never raw controls. Do not edit `src/components/ui`:
  change the look through the tokens in `src/index.css`.
- Take every word from `src/lib/labels.ts`. Format every number and date with `@/lib/format`.
- Use the token classes (`bg-primary`, `text-muted-foreground`) and the spacing and size scales;
  no raw colours, arbitrary values or inline styles.

## Loop

- While building: `make format lint ui-floor`. The browser checks, at 1440 and 390 px, are the
  visual check: no screenshots, no preview server.
- Before you finish: `make check`. A guard failure means the screen should change, not the guard.

## Traps

- A link that looks like a button stays a link:
  `<a className={buttonVariants({ variant: "outline" })}>`, from `@/components/ui/button`.
- Inside a `Card`, put content in its slots (`CardHeader`, `CardContent`, `CardFooter`); for a
  stack inside a slot, wrap it in a `div` with `flex flex-col gap-*`.
- No colour or type class on `TableCell`: wrap the text in a `span` and put the class there.
- Wide tables on phones: the `Table` (it needs an `aria-label`) scrolls sideways; do not force
  column widths.
- Statuses stay visually distinct. If a `Badge` fails contrast, pick another variant; never give
  two statuses the same look.
- A state appears because of a real condition: a pending or failed request, an empty result, a
  filter with no match, a user action. Never because of a switch (a prop or URL value that exists
  only to pick the state): a state reachable only from a switch is not a state.

## Adding a component

shadcn is pinned; always call it with its version:

1. Find: `npx shadcn@4.23.0 search @shadcn -q "date picker"`.
2. Read: `npx shadcn@4.23.0 docs calendar` and `npx shadcn@4.23.0 view @shadcn/calendar`.
3. Install: `npx shadcn@4.23.0 add calendar`, then `make ui-patch format`.

Results marked `(block)` are ready-made sections: `view` them for ideas, never `add` them.

`tools/design_guards.mjs`, `mk/design.mk`, `tests/App.test.tsx`, `tests/e2e/floor.spec.ts` and
`tests/e2e/routes.ts` belong to the plugin: you never need to open them, and an edit costs
`doctor` points.

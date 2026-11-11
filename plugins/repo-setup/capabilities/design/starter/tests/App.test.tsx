import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, expect, it } from "vitest";

import { App } from "../src/App.tsx";
import { ReferenceScreen, type ScreenState } from "../src/example/ReferenceScreen.tsx";
import { formatDate, formatMoney } from "../src/lib/format.ts";
import { LABELS } from "../src/lib/labels.ts";
import { pick, SCREENS } from "../src/screens.ts";
import { ROUTES } from "./e2e/routes.ts";

const SHOWN: [ScreenState, string][] = [
  ["ready", LABELS.sampleFirstName],
  ["loading", LABELS.loading],
  ["empty", LABELS.emptyTitle],
  ["error", LABELS.errorTitle],
  ["no-results", LABELS.noResultsTitle],
  ["saving", LABELS.saving],
  ["confirm-delete", LABELS.deleteItem(LABELS.sampleFirstName)],
];

afterEach(() => {
  window.history.replaceState(null, "", "/");
});

it("lists at least one screen", () => {
  expect(SCREENS.length).toBeGreaterThan(0);
});

it.each(SCREENS.flatMap((s) => s.states.map((state) => [s.path, state, s] as const)))(
  "renders %s in the %s state with one main and one h1",
  async (_path, state, entry) => {
    const Screen = await entry.load();
    render(<Screen state={state} />);
    // A dialog hides the page behind it from assistive tech; the structure must still be there.
    expect(screen.getAllByRole("main", { hidden: true })).toHaveLength(1);
    expect(screen.getAllByRole("heading", { level: 1, hidden: true })).toHaveLength(1);
  },
);

it.each(SHOWN)("shows the %s state under the page title", (state, text) => {
  render(<ReferenceScreen state={state} />);
  expect(screen.getByRole("heading", { level: 1, hidden: true })).toHaveTextContent(
    LABELS.screenTitle,
  );
  // A dialog opens outside the screen's own element, so look at the whole page.
  expect(document.body).toHaveTextContent(text);
});

it("disables the confirm button while saving", () => {
  render(<ReferenceScreen state="saving" />);
  expect(screen.getByRole("button", { name: LABELS.saving })).toBeDisabled();
});

it("asks before deleting, names the item, and can be cancelled", async () => {
  render(<ReferenceScreen state="ready" />);
  const name = LABELS.deleteItem(LABELS.sampleSecondName);
  fireEvent.click(screen.getByRole("button", { name }));
  expect(screen.getByRole("dialog")).toHaveTextContent(name);
  fireEvent.click(screen.getByRole("button", { name: LABELS.cancel }));
  await waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
  expect(screen.getByText(LABELS.sampleSecondName)).toBeInTheDocument();
});

it("deletes the item after the confirm button has shown it is saving", async () => {
  render(<ReferenceScreen state="ready" />);
  fireEvent.click(screen.getByRole("button", { name: LABELS.deleteItem(LABELS.sampleFirstName) }));
  fireEvent.click(screen.getByRole("button", { name: LABELS.deleteAction }));
  expect(screen.getByRole("button", { name: LABELS.saving })).toBeDisabled();
  await waitFor(() => expect(screen.queryByText(LABELS.sampleFirstName)).not.toBeInTheDocument());
});

it("gives the empty and no-results buttons something to do", () => {
  const { unmount } = render(<ReferenceScreen state="empty" />);
  fireEvent.click(screen.getByRole("button", { name: LABELS.emptyAction }));
  expect(screen.queryByText(LABELS.emptyTitle)).not.toBeInTheDocument();
  unmount();
  render(<ReferenceScreen state="no-results" />);
  fireEvent.click(screen.getByRole("button", { name: LABELS.noResultsAction }));
  expect(screen.queryByText(LABELS.noResultsTitle)).not.toBeInTheDocument();
});

it("gives every status its own badge, one of them destructive", () => {
  render(<ReferenceScreen state="ready" />);
  const look = new Map(
    [...document.querySelectorAll("[data-slot=badge]")].map((b) => [
      b.textContent,
      b.getAttribute("data-variant"),
    ]),
  );
  expect(look.size).toBeGreaterThan(1);
  expect(new Set(look.values()).size).toBe(look.size);
  expect([...look.values()]).toContain("destructive");
});

it("gives the browser checks a route for every state of every screen", () => {
  for (const { path, states } of SCREENS) {
    expect(ROUTES).toContain(path);
    for (const state of states.slice(1)) expect(ROUTES).toContain(`${path}?state=${state}`);
  }
});

it("falls back to the first state for an unknown state, and the first screen for an unknown path", () => {
  expect(pick("/", "?state=unknown")).toEqual({ screen: SCREENS[0], state: "ready" });
  expect(pick("/", "?state=error")?.state).toBe("error");
  expect(pick("/nowhere", "")?.screen).toBe(SCREENS[0]);
});

it("opens the state named in the address", async () => {
  window.history.replaceState(null, "", "/?state=error");
  render(<App />);
  expect(await screen.findByText(LABELS.errorTitle)).toBeInTheDocument();
});

it("falls back to the first state for an unknown state or path", async () => {
  window.history.replaceState(null, "", "/nowhere?state=unknown");
  render(<App />);
  expect(await screen.findByText(LABELS.sampleFirstName)).toBeInTheDocument();
});

it("formats money and dates", () => {
  expect(formatMoney(1200)).not.toBe("");
  expect(formatDate(new Date(2026, 0, 2))).not.toBe("");
});

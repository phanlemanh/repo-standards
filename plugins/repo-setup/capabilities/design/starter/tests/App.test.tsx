import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, expect, it } from "vitest";

import { App } from "../src/App.tsx";
import { ReferenceScreen } from "../src/example/ReferenceScreen.tsx";
import { formatDate, formatMoney } from "../src/lib/format.ts";
import { LABELS } from "../src/lib/labels.ts";
import { pick, SCREENS, type Step } from "../src/screens.ts";
import { ROUTES } from "./e2e/routes.ts";

// The fake data source answers according to `?scenario=` in the address.
function setScenario(scenario?: string) {
  window.history.replaceState(null, "", scenario ? `/?scenario=${scenario}` : "/");
}

async function take(step: Step) {
  if ("press" in step) fireEvent.click(await screen.findByRole("button", { name: step.press }));
  else fireEvent.change(await screen.findByLabelText(step.fill), { target: { value: step.text } });
}

const ready = () => screen.findByText(LABELS.sampleFirstName);

afterEach(() => {
  setScenario();
});

it("lists at least one screen", () => {
  expect(SCREENS.length).toBeGreaterThan(0);
});

it.each(SCREENS.flatMap((s) => s.states.map((state) => [s.path, state.name, s, state] as const)))(
  "reaches %s %s from the data source and the user, under one main and one h1",
  async (_path, _name, entry, state) => {
    setScenario(state.scenario);
    const Screen = await entry.load();
    render(<Screen />);
    for (const step of state.steps ?? []) await take(step);
    // A dialog renders outside the screen's own element, so look at the whole page.
    expect(await screen.findAllByText(state.shows)).not.toHaveLength(0);
    // A dialog hides the page behind it from assistive tech; the structure must still be there.
    expect(screen.getAllByRole("main", { hidden: true })).toHaveLength(1);
    expect(screen.getAllByRole("heading", { level: 1, hidden: true })).toHaveLength(1);
  },
);

it("shows loading while the request is pending, then the items", async () => {
  render(<ReferenceScreen />);
  expect(screen.getByRole("status")).toHaveTextContent(LABELS.loading);
  expect(await ready()).toBeInTheDocument();
  expect(screen.queryByRole("status")).not.toBeInTheDocument();
});

it("shows the error when the request fails, and retry runs it again", async () => {
  setScenario("fail");
  render(<ReferenceScreen />);
  expect(await screen.findByText(LABELS.errorTitle)).toBeInTheDocument();
  setScenario();
  fireEvent.click(screen.getByRole("button", { name: LABELS.retry }));
  expect(await ready()).toBeInTheDocument();
});

it("shows the empty state when the request finds nothing", async () => {
  setScenario("empty");
  render(<ReferenceScreen />);
  expect(await screen.findByText(LABELS.emptyTitle)).toBeInTheDocument();
  expect(screen.queryByLabelText(LABELS.filter)).not.toBeInTheDocument();
  setScenario();
  fireEvent.click(screen.getByRole("button", { name: LABELS.emptyAction }));
  expect(await ready()).toBeInTheDocument();
});

it("shows no results when the filter matches nothing, and clearing it brings the items back", async () => {
  render(<ReferenceScreen />);
  await ready();
  fireEvent.change(screen.getByLabelText(LABELS.filter), { target: { value: "zzz" } });
  expect(screen.getByText(LABELS.noResultsTitle)).toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: LABELS.noResultsAction }));
  expect(screen.getByText(LABELS.sampleFirstName)).toBeInTheDocument();
  expect(screen.getByLabelText(LABELS.filter)).toHaveValue("");
});

it("asks before deleting, names the item, and can be cancelled", async () => {
  render(<ReferenceScreen />);
  await ready();
  const name = LABELS.deleteItem(LABELS.sampleSecondName);
  fireEvent.click(screen.getByRole("button", { name }));
  expect(screen.getByRole("dialog")).toHaveTextContent(name);
  fireEvent.click(screen.getByRole("button", { name: LABELS.cancel }));
  await waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
  expect(screen.getByText(LABELS.sampleSecondName)).toBeInTheDocument();
});

it("shows saving while the delete request runs, then removes the item", async () => {
  render(<ReferenceScreen />);
  await ready();
  fireEvent.click(screen.getByRole("button", { name: LABELS.deleteItem(LABELS.sampleFirstName) }));
  fireEvent.click(screen.getByRole("button", { name: LABELS.deleteAction }));
  expect(screen.getByRole("button", { name: LABELS.saving })).toBeDisabled();
  expect(screen.getByRole("button", { name: LABELS.cancel })).toBeDisabled();
  await waitFor(() => expect(screen.queryByText(LABELS.sampleFirstName)).not.toBeInTheDocument());
});

it("keeps the item and says so in the dialog when the delete request fails", async () => {
  setScenario("fail-delete");
  render(<ReferenceScreen />);
  await ready();
  fireEvent.click(screen.getByRole("button", { name: LABELS.deleteItem(LABELS.sampleFirstName) }));
  fireEvent.click(screen.getByRole("button", { name: LABELS.deleteAction }));
  const failed = LABELS.deleteFailed(LABELS.sampleFirstName);
  expect(await screen.findByText(failed)).toBeInTheDocument();
  expect(screen.getByRole("button", { name: LABELS.deleteAction })).toBeEnabled();
  fireEvent.click(screen.getByRole("button", { name: LABELS.cancel }));
  await waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
  expect(screen.getByText(LABELS.sampleFirstName)).toBeInTheDocument();
});

it("gives every status its own badge, one of them destructive", async () => {
  render(<ReferenceScreen />);
  await ready();
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

it("gives the browser checks a route for every state and scenario of every screen", () => {
  for (const { path, states } of SCREENS)
    for (const { name, scenario } of states)
      expect(ROUTES).toContainEqual(
        expect.objectContaining({
          title: `${path} ${name}`,
          url: scenario ? `${path}?scenario=${scenario}` : path,
        }),
      );
});

it("picks the screen by path, and the first screen for an unknown path", () => {
  expect(pick("/")).toBe(SCREENS[0]);
  expect(pick("/nowhere")).toBe(SCREENS[0]);
});

it("opens the screen for the address, which loads its own data", async () => {
  window.history.replaceState(null, "", "/nowhere?scenario=fail");
  render(<App />);
  expect(await screen.findByText(LABELS.errorTitle)).toBeInTheDocument();
});

it("formats money and dates", () => {
  expect(formatMoney(1200)).not.toBe("");
  expect(formatDate(new Date(2026, 0, 2))).not.toBe("");
});

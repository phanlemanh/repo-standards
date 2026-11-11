import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";

import { formatDate, formatMoney } from "../src/lib/format.ts";
import { LABELS } from "../src/lib/labels.ts";
import { pick, SCREENS, type Step } from "../src/screens.ts";

// The sample screen's own behaviour. tests/e2e.sh copies this file into a generated repo and runs
// it; the repo itself ships only the generic walk over src/screens.ts in tests/App.test.tsx.
// The fake data source answers according to `?scenario=` in the address, after a real wait that
// fake timers skip. Each test gets a fresh source, because deleting and adding change its store.
function setScenario(scenario?: string) {
  window.history.replaceState(null, "", scenario ? `/?scenario=${scenario}` : "/");
}

const answer = () => act(() => vi.advanceTimersByTimeAsync(200));

async function show(scenario?: string) {
  setScenario(scenario);
  const { ReferenceScreen } = await import("../src/example/ReferenceScreen.tsx");
  const view = render(<ReferenceScreen />);
  await answer();
  return view;
}

async function take(step: Step) {
  if ("press" in step) fireEvent.click(screen.getByRole("button", { name: step.press }));
  else fireEvent.change(screen.getByLabelText(step.fill), { target: { value: step.text } });
  await answer();
}

function setOnline(online: boolean) {
  vi.spyOn(navigator, "onLine", "get").mockReturnValue(online);
}

beforeEach(() => {
  vi.useFakeTimers({ shouldAdvanceTime: true });
  vi.resetModules();
});

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
  vi.unstubAllEnvs();
  setScenario();
});

it("shows loading while the request is pending, then the items", async () => {
  setScenario();
  const { ReferenceScreen } = await import("../src/example/ReferenceScreen.tsx");
  render(<ReferenceScreen />);
  expect(screen.getByRole("status")).toHaveTextContent(LABELS.loading);
  await answer();
  expect(screen.queryByRole("status")).not.toBeInTheDocument();
  expect(screen.getByText(LABELS.sampleFirstName)).toBeInTheDocument();
});

it("ignores an answer that arrives after the screen has gone", async () => {
  const error = vi.spyOn(console, "error");
  setScenario();
  const { ReferenceScreen } = await import("../src/example/ReferenceScreen.tsx");
  const { unmount } = render(<ReferenceScreen />);
  unmount();
  await answer();
  render(<ReferenceScreen />);
  expect(screen.getByRole("status")).toHaveTextContent(LABELS.loading);
  expect(screen.queryByText(LABELS.sampleFirstName)).not.toBeInTheDocument();
  expect(error).not.toHaveBeenCalled();
});

it("shows the error when the request fails, and retry runs it again", async () => {
  await show("fail");
  expect(screen.getByText(LABELS.errorTitle)).toBeInTheDocument();
  setScenario();
  fireEvent.click(screen.getByRole("button", { name: LABELS.retry }));
  expect(screen.getByRole("status")).toHaveTextContent(LABELS.loading);
  await answer();
  expect(screen.getByText(LABELS.sampleFirstName)).toBeInTheDocument();
});

it("fails for real when the browser is offline, with no scenario", async () => {
  setOnline(false);
  await show();
  expect(screen.getByText(LABELS.errorTitle)).toBeInTheDocument();
  setOnline(true);
  fireEvent.click(screen.getByRole("button", { name: LABELS.retry }));
  await answer();
  setOnline(false);
  await take({ press: LABELS.deleteItem(LABELS.sampleFirstName) });
  await take({ press: LABELS.deleteAction });
  expect(screen.getByText(LABELS.deleteFailed(LABELS.sampleFirstName))).toBeInTheDocument();
});

it("reaches the empty state by deleting every item, and Add item brings one back", async () => {
  await show();
  const rowButtons = screen.getAllByRole("button", {
    name: new RegExp(`^${LABELS.deleteItem("")}`),
  });
  for (const name of rowButtons.map((b) => b.getAttribute("aria-label") ?? "")) {
    await take({ press: name });
    await take({ press: LABELS.deleteAction });
  }
  expect(screen.getByText(LABELS.emptyTitle)).toBeInTheDocument();
  expect(screen.queryByLabelText(LABELS.filter)).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: LABELS.emptyAction }));
  expect(screen.getByRole("status")).toHaveTextContent(LABELS.loading);
  await answer(); // the item is created
  await answer(); // the list is read again
  expect(screen.getByText(LABELS.sampleNewName)).toBeInTheDocument();
});

it("shows no results when the filter matches nothing, and clearing it brings the items back", async () => {
  await show();
  fireEvent.change(screen.getByLabelText(LABELS.filter), { target: { value: "zzz" } });
  expect(screen.getByText(LABELS.noResultsTitle)).toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: LABELS.noResultsAction }));
  expect(screen.getByText(LABELS.sampleFirstName)).toBeInTheDocument();
  expect(screen.getByLabelText(LABELS.filter)).toHaveValue("");
});

it("asks before deleting, names the item, and can be cancelled", async () => {
  await show();
  const name = LABELS.deleteItem(LABELS.sampleSecondName);
  fireEvent.click(screen.getByRole("button", { name }));
  expect(screen.getByRole("dialog")).toHaveTextContent(name);
  fireEvent.click(screen.getByRole("button", { name: LABELS.cancel }));
  await waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
  expect(screen.getByText(LABELS.sampleSecondName)).toBeInTheDocument();
});

it("shows saving while the delete request runs, then removes the item", async () => {
  await show();
  fireEvent.click(screen.getByRole("button", { name: LABELS.deleteItem(LABELS.sampleFirstName) }));
  fireEvent.click(screen.getByRole("button", { name: LABELS.deleteAction }));
  expect(screen.getByRole("button", { name: LABELS.saving })).toBeDisabled();
  expect(screen.getByRole("button", { name: LABELS.cancel })).toBeDisabled();
  await answer();
  await waitFor(() => expect(screen.queryByText(LABELS.sampleFirstName)).not.toBeInTheDocument());
});

it("keeps the item and says so in the dialog when the delete request fails", async () => {
  await show("fail-delete");
  await take({ press: LABELS.deleteItem(LABELS.sampleFirstName) });
  await take({ press: LABELS.deleteAction });
  expect(screen.getByText(LABELS.deleteFailed(LABELS.sampleFirstName))).toBeInTheDocument();
  expect(screen.getByRole("button", { name: LABELS.deleteAction })).toBeEnabled();
  fireEvent.click(screen.getByRole("button", { name: LABELS.cancel }));
  await waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
  expect(screen.getByText(LABELS.sampleFirstName)).toBeInTheDocument();
});

it("gives every status its own badge, one of them destructive", async () => {
  await show();
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

it("ignores ?scenario= in a build for users", async () => {
  vi.stubEnv("MODE", "production");
  await show("fail");
  expect(screen.getByText(LABELS.sampleFirstName)).toBeInTheDocument();
});

it("hands a screen the named parts of its path", () => {
  const detail = { ...SCREENS[0]!, path: "/things/:id/:part" };
  SCREENS.unshift(detail);
  try {
    expect(pick("/things/a%20b/c")).toEqual({ screen: detail, params: { id: "a b", part: "c" } });
    expect(pick("/things/a")).toBeNull();
    expect(pick("/things/%E0%A4/c")).toBeNull(); // a malformed address is no match
  } finally {
    SCREENS.shift();
  }
});

it("matches the text of a path literally, and survives a part name used twice", () => {
  const dotted = { ...SCREENS[0]!, path: "/v1.0/:id/x/:id" };
  SCREENS.unshift(dotted);
  try {
    expect(pick("/v1a0/1/x/2")).toBeNull();
    expect(pick("/v1.0/1/x/2")?.screen).toBe(dotted);
  } finally {
    SCREENS.shift();
  }
});

it("opens the page for a malformed address, not a blank one", async () => {
  const fresh = await import("../src/screens.ts"); // the copy App reads after resetModules
  fresh.SCREENS.unshift({ ...fresh.SCREENS[0]!, path: "/things/:id" });
  window.history.replaceState(null, "", "/things/%E0%A4");
  const { App } = await import("../src/App.tsx");
  render(<App />);
  expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(LABELS.notFound);
});

it("formats money and dates", () => {
  expect(formatMoney(1200)).not.toBe("");
  expect(formatDate(new Date(2026, 0, 2))).not.toBe("");
});

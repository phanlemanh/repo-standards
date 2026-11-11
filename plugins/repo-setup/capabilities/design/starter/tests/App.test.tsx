import { act, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";

import { LABELS } from "../src/lib/labels.ts";
import { address, pick, SCREENS } from "../src/screens.ts";
import { ROUTES } from "./e2e/routes.ts";

const answer = () => act(() => vi.advanceTimersByTimeAsync(200));

async function open(url: string) {
  window.history.replaceState(null, "", url);
  vi.resetModules(); // a fresh data source for each test
  const { App } = await import("../src/App.tsx");
  render(<App />);
  await screen.findAllByRole("main", { hidden: true });
}

beforeEach(() => vi.useFakeTimers({ shouldAdvanceTime: true }));
afterEach(() => {
  vi.useRealTimers();
  window.history.replaceState(null, "", "/");
});

it.each(ROUTES)("reaches $title under one main and one h1", async ({ url, steps, shows }) => {
  await open(url);
  await answer();
  for (const step of steps) {
    if ("press" in step) fireEvent.click(screen.getByRole("button", { name: step.press }));
    else fireEvent.change(screen.getByLabelText(step.fill), { target: { value: step.text } });
    await answer();
  }
  // A dialog renders outside the screen and hides the page behind it.
  expect(screen.getAllByText(shows)).not.toHaveLength(0);
  expect(screen.getAllByRole("main", { hidden: true })).toHaveLength(1);
  expect(screen.getAllByRole("heading", { level: 1, hidden: true })).toHaveLength(1);
});

it("gives every screen a real address that leads back to it", () => {
  for (const s of SCREENS) {
    expect(address(s)).not.toContain("/:");
    expect(pick(address(s))?.screen).toBe(s);
  }
});

it("shows no screen at an address none claims", async () => {
  await open("/no/such/page");
  expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(LABELS.notFound);
});

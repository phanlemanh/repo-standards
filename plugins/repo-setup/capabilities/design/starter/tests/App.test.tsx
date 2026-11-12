import { fireEvent, render, screen } from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";

import { address, pick, SCREENS } from "../src/screens.ts";
import { ROUTES } from "./e2e/routes.ts";

async function open(url: string) {
  window.history.replaceState(null, "", url);
  vi.resetModules(); // a fresh data source
  const { App } = await import("../src/App.tsx");
  render(<App />);
}

afterEach(() => window.history.replaceState(null, "", "/"));

it.each(ROUTES)("reaches $title under one main and one h1", async ({ url, steps, shows }) => {
  await open(url);
  for (const step of steps) {
    if ("press" in step) fireEvent.click(await screen.findByRole("button", { name: step.press }));
    else
      fireEvent.change(await screen.findByLabelText(step.fill), { target: { value: step.text } });
  }
  expect(await screen.findAllByText(shows)).not.toHaveLength(0);
  expect(screen.getAllByRole("main", { hidden: true })).toHaveLength(1);
  expect(screen.getAllByRole("heading", { level: 1, hidden: true })).toHaveLength(1);
});

it("gives every screen a real address that leads back to it", () => {
  for (const s of SCREENS) {
    expect(address(s)).not.toContain("/:");
    expect(pick(new URL(address(s), "http://x").pathname)?.screen).toBe(s);
  }
});

it("links every screen from the page for an address none claims", async () => {
  await open("/no/such/page");
  const links = await screen.findAllByRole("link");
  expect(links.map((a) => a.getAttribute("href"))).toEqual(SCREENS.map(address));
});

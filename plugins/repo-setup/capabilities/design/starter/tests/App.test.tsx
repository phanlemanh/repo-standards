import { render, screen } from "@testing-library/react";
import { afterEach, expect, it } from "vitest";

import { App } from "../src/App.tsx";
import { ReferenceScreen, type ScreenState } from "../src/example/ReferenceScreen.tsx";
import { formatDate, formatMoney } from "../src/lib/format.ts";
import { LABELS } from "../src/lib/labels.ts";

const SHOWN: [ScreenState, string][] = [
  ["ready", LABELS.sampleFirstName],
  ["loading", LABELS.loading],
  ["empty", LABELS.emptyTitle],
  ["error", LABELS.errorTitle],
  ["no-results", LABELS.noResultsTitle],
];

afterEach(() => {
  window.history.replaceState(null, "", "/");
});

it.each(SHOWN)("shows the %s state under the page title", (state, text) => {
  const { container } = render(<ReferenceScreen state={state} />);
  expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(LABELS.screenTitle);
  expect(container).toHaveTextContent(text);
});

it("opens the state named in the address", () => {
  window.history.replaceState(null, "", "/?state=error");
  render(<App />);
  expect(screen.getByText(LABELS.errorTitle)).toBeInTheDocument();
});

it("falls back to the ready state for an unknown address", () => {
  window.history.replaceState(null, "", "/?state=unknown");
  render(<App />);
  expect(screen.getByText(LABELS.sampleFirstName)).toBeInTheDocument();
});

it("formats money and dates", () => {
  expect(formatMoney(1200)).not.toBe("");
  expect(formatDate(new Date(2026, 0, 2))).not.toBe("");
});

import { fireEvent, render, screen, waitFor } from "@testing-library/react";
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
  ["saving", LABELS.saving],
  ["confirm-delete", LABELS.deleteItem(LABELS.sampleFirstName)],
];

afterEach(() => {
  window.history.replaceState(null, "", "/");
});

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

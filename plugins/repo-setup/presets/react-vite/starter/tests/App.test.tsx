import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { App } from "../src/App.tsx";

describe("App", () => {
  it("greets the world by default", () => {
    render(<App />);
    expect(screen.getByRole("heading")).toHaveTextContent("Hello, world!");
  });

  it("greets the typed name", () => {
    render(<App />);
    fireEvent.change(screen.getByLabelText(/your name/i), { target: { value: "Lan" } });
    expect(screen.getByRole("heading")).toHaveTextContent("Hello, Lan!");
  });
});

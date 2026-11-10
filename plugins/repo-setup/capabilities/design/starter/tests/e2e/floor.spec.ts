import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

import { ROUTES } from "./routes.ts";

for (const route of ROUTES) {
  for (const width of [1440, 390]) {
    test(`floor ${route} at ${width}px`, async ({ page }) => {
      await page.setViewportSize({ width, height: 800 });
      await page.goto(route);
      // styles loaded
      const primary = await page.evaluate(() =>
        getComputedStyle(document.documentElement).getPropertyValue("--primary").trim(),
      );
      expect(primary).not.toBe("");
      await expect(page.getByRole("main")).toHaveCount(1);
      await expect(page.getByRole("heading", { level: 1 })).toHaveCount(1);
      const overflow = await page.evaluate(
        () => document.documentElement.scrollWidth - window.innerWidth,
      );
      expect(overflow).toBeLessThanOrEqual(0);
      const { violations, incomplete } = await new AxeBuilder({ page }).analyze();
      expect(violations.map((v) => v.id)).toEqual([]);
      const sameColour = incomplete.flatMap((v) =>
        v.nodes.flatMap((n) =>
          n.any.filter(
            (a) => (a.data as { messageKey?: string } | null)?.messageKey === "equalRatio",
          ),
        ),
      );
      expect(sameColour).toEqual([]);
    });
  }
}

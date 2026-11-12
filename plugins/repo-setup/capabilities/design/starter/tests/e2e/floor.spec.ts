import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

import { ROUTES } from "./routes.ts";

for (const route of ROUTES) {
  for (const width of [1440, 390]) {
    test(`floor ${route.title} at ${width}px`, async ({ page }) => {
      await page.setViewportSize({ width, height: 800 });
      await page.goto(route.url);
      // Reach the state the way a user does, then wait until it is on the page.
      for (const step of route.steps) {
        if ("press" in step)
          await page.getByRole("button", { name: step.press, exact: true }).click();
        else await page.getByLabel(step.fill, { exact: true }).fill(step.text);
      }
      await page.waitForFunction((text) => document.body.textContent?.includes(text), route.shows);
      // styles loaded
      const primary = await page.evaluate(() =>
        getComputedStyle(document.documentElement).getPropertyValue("--primary").trim(),
      );
      expect(primary).not.toBe("");
      // An open dialog hides the page behind it from assistive tech; the structure must still be there.
      await expect(page.getByRole("main", { includeHidden: true })).toHaveCount(1);
      await expect(page.getByRole("heading", { level: 1, includeHidden: true })).toHaveCount(1);
      // Let opening animations (a dialog fading in) finish, so contrast is measured on the final look.
      await page.evaluate(() =>
        Promise.all(
          document
            .getAnimations()
            .filter((a) => a.effect?.getTiming().iterations !== Infinity)
            .map((a) => a.finished.catch(() => undefined)),
        ),
      );
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

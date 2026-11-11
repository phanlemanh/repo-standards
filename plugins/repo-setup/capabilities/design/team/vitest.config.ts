import { defineConfig, mergeConfig } from "vitest/config";

import viteConfig from "./vite.config.ts";

export default mergeConfig(
  viteConfig,
  defineConfig({
    test: {
      coverage: {
        enabled: true,
        provider: "v8",
        // The console shows only a missed threshold; coverage/index.html has the table per file.
        reporter: ["html", "json-summary"],
        include: ["src/**"],
        // Entry points and generated code are covered by other means.
        exclude: [
          "src/main.tsx",
          "src/**/stdio.ts",
          "src/generated/**",
          "src/**/*.d.ts",
          "src/components/ui/**",
        ],
        thresholds: {
          lines: 80,
          functions: 80,
          branches: 70,
          statements: 80,
        },
      },
    },
  }),
);

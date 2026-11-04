import { defineConfig, mergeConfig } from "vitest/config";

import viteConfig from "./vite.config.ts";

export default mergeConfig(
  viteConfig,
  defineConfig({
    test: {
      coverage: {
        enabled: true,
        provider: "v8",
        include: ["src/**"],
        // Entry points and generated code are covered by other means.
        exclude: ["src/main.tsx", "src/**/stdio.ts", "src/generated/**", "src/**/*.d.ts"],
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

import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "node:path";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { "@": path.resolve(import.meta.dirname, "./src") } },
  test: {
    environment: "jsdom",
    reporters: ["dot"],
    exclude: ["node_modules/**", "tests/e2e/**"],
    setupFiles: ["./tests/setup.ts"],
  },
});

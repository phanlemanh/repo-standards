import js from "@eslint/js";
import { defineConfig, globalIgnores } from "eslint/config";
import { plugin as shadcn } from "@shadcn/lint";
import prettier from "eslint-config-prettier/flat";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import globals from "globals";
import tseslint from "typescript-eslint";

export default defineConfig([
  globalIgnores(["dist/", "coverage/", "node_modules/", "src/generated/"]),
  js.configs.recommended,
  tseslint.configs.recommended,
  {
    files: ["src/**/*.{ts,tsx}"],
    languageOptions: { globals: globals.browser },
    extends: [reactHooks.configs.flat.recommended, reactRefresh.configs.vite],
  },
  // design-floor:start
  {
    files: ["src/**/*.{ts,tsx,js,jsx}"],
    ignores: ["src/components/ui/**", "src/lib/format.ts"],
    plugins: { shadcn },
    rules: {
      "shadcn/no-restyle": ["error", { allow: ["layout"] }],
      "shadcn/no-raw-colors": "error",
      "shadcn/no-arbitrary-values": "error",
      "shadcn/no-inline-styles": "error",
      "shadcn/no-unknown-classes": "error",
      "shadcn/require-static-classes": "error",
      "no-restricted-syntax": [
        "error",
        {
          selector:
            "JSXAttribute[name.name='className'] Literal[value=/(^|[\\s:])!?(h|w|size|min-h|min-w|max-h|max-w)-(?!(0|1|2|3|4|5|6|7|8|9|10|11|12|14|16|20|24|28|32|40|48|56|64|72|80|96)(!?(\\s|$)))[0-9.]+!?(\\s|$)/]",
          message: "Size is off the scale. Use a component size or a value from the size scale.",
        },
        {
          selector:
            "JSXAttribute[name.name='className'] Literal[value=/(^|[\\s:])!?-?(p|px|py|pt|pb|pl|pr|ps|pe|m|mx|my|mt|mb|ml|mr|ms|me|gap|gap-x|gap-y|space-x|space-y)-(?!(0|0\\.5|1|1\\.5|2|3|4|5|6|8|10|12|16|20|24)(!?(\\s|$)))[0-9.]+!?(\\s|$)/]",
          message:
            "Spacing is off the scale. Use 0, 0.5, 1, 1.5, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20 or 24.",
        },
        {
          selector: "JSXOpeningElement[name.name=/^(button|input|select|textarea|table)$/]",
          message: "Use the component from @/components/ui instead of a raw control.",
        },
        {
          selector: "CallExpression[callee.property.name=/^toLocale(Date|Time)?String$/]",
          message: "Format numbers and dates with @/lib/format.",
        },
        {
          selector: "CallExpression[callee.object.name='Intl']",
          message: "Format numbers and dates with @/lib/format.",
        },
        {
          selector: "NewExpression[callee.object.name='Intl']",
          message: "Format numbers and dates with @/lib/format.",
        },
      ],
    },
  },
  // design-floor:end
  { files: ["tools/**/*.mjs"], languageOptions: { globals: globals.node } },
  {
    files: ["src/components/ui/**/*.tsx"],
    rules: { "react-refresh/only-export-components": "off" },
  },
  prettier,
]);

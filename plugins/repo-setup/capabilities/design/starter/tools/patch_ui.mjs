// Fixes in the shadcn components that the browser checks need. Runs after `shadcn add`; safe to
// run again. Usage: node tools/patch_ui.mjs
import { existsSync, readFileSync, writeFileSync } from "node:fs";

const PATCHES = [
  {
    // A wide table scrolls inside its container; keyboard users must be able to reach and scroll it.
    file: "src/components/ui/table.tsx",
    done: /data-slot="table-container"\s+role="region"/,
    edits: [
      [
        /function Table\(\{\s*className,\s*\.\.\.props\s*\}:\s*React\.ComponentProps<"table">\)/,
        'function Table({ className, "aria-label": label, ...props }: React.ComponentProps<"table"> & { "aria-label": string })',
      ],
      [
        /<div\s+data-slot="table-container"\s+className=/,
        '<div data-slot="table-container" role="region" aria-label={label} tabIndex={0} className=',
      ],
    ],
  },
];

let failed = false;
for (const { file, done, edits } of PATCHES) {
  if (!existsSync(file)) continue;
  const text = readFileSync(file, "utf8");
  if (done.test(text)) continue;
  const missing = edits.filter(([from]) => !from.test(text));
  for (const [from] of missing)
    console.error(`${file} no longer matches ${from}: update tools/patch_ui.mjs`);
  if (missing.length) failed = true;
  else
    writeFileSync(
      file,
      edits.reduce((t, [from, to]) => t.replace(from, to), text),
    );
}
process.exit(failed ? 1 : 0);

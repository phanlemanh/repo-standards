#!/usr/bin/env bash
# End-to-end: apply each preset at team level, run its real install + verify commands,
# and require doctor = 100. Needs network, node/npm, uv and pre-commit. Run before a release.
#   bash tests/e2e.sh            # all presets
#   SKIP=gitleaks bash tests/e2e.sh   # if the gitleaks hook cannot be built offline
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/plugins/repo-setup/scripts"
TMP="$(mktemp -d)"
PREVIEW=""
trap '[ -z "$PREVIEW" ] || kill "$PREVIEW" 2>/dev/null; rm -rf "$TMP"' EXIT

# pre-commit refuses to install while a global core.hooksPath is set. Leave that setting alone:
# skip the install and run the commit-msg stage directly.
HOOKS_PATH="$(git config core.hooksPath || true)"
if ! command -v pre-commit >/dev/null; then
  mkdir -p "$TMP/bin"
  printf '#!/bin/sh\nexec uvx pre-commit "$@"\n' > "$TMP/bin/pre-commit"; chmod +x "$TMP/bin/pre-commit"
  PATH="$TMP/bin:$PATH"
fi

ALL=$(python3 "$S/apply.py" --list-presets --json | python3 -c "import json,sys; print(' '.join(json.load(sys.stdin)))")
# react-vite bare fails design_present, so it only runs with the design capability.
ALL=" $ALL "; ALL="${ALL/ react-vite / }"
# Combinations: stack:archetype:deploy:capabilities:ai_tier:design_surface
COMBOS="react-vite:none:none:design react-vite:none:none:design::content ts-api:service-api:container:github-agents fastapi:service-api:container ts-node:modular-monolith:none:mcp python:modular-monolith:none:mcp python:none:none:github-agents python:none:none:ai:call ts-node:none:none:ai:workflow python:none:none:ai:agent ts-node:none:none:ai:agent fastapi:service-api:none:ai:agent"
for spec in ${PRESETS:-$ALL $COMBOS}; do
  IFS=: read -r preset arch dep cap tier surface <<<"$spec"
  extra=(--archetype "${arch:-none}" --deploy "${dep:-none}")
  [ -n "$cap" ] && extra+=(--with "$cap")
  [ -n "$tier" ] && extra+=(--var "ai_tier=$tier")
  [ -n "$surface" ] && extra+=(--var "design_surface=$surface")
  d="$TMP/${spec//:/-}"; mkdir -p "$d"; cd "$d"; git init -q -b main
  out=$(python3 "$S/apply.py" --preset "$preset" "${extra[@]}" --level team \
        --var "project_name=Coffee Shop" --var "description=E2E test" --var owner=acme --json)
  install=$(python3 -c 'import json,sys;[print(c) for c in json.load(sys.stdin)["next_commands"]["install"]]' <<<"$out")
  verify=$(python3 -c 'import json,sys;[print(c) for c in json.load(sys.stdin)["next_commands"]["verify"]]' <<<"$out")
  while IFS= read -r c; do
    case "$c" in "") continue ;; *"pre-commit install"*) [ -z "$HOOKS_PATH" ] || continue ;; esac
    echo "[$spec] \$ $c"; bash -c "$c" >/dev/null </dev/null
  done <<<"$install"
  git add -A
  while IFS= read -r c; do [ -z "$c" ] || { echo "[$spec] \$ $c"; bash -c "$c" </dev/null; }; done <<<"$verify"
  python3 "$S/doctor.py" --min-score 100
  case ",$cap," in *,ai,*)
    env -u ANTHROPIC_API_KEY make check >/dev/null || { echo "FAIL: make check needs an API key"; exit 1; }
    if env -u ANTHROPIC_API_KEY make eval >/dev/null 2>&1; then echo "FAIL: make eval ran without a key"; exit 1; fi
    ;;
  esac
  case ",$cap," in *,design,*)
    # Break the design floor on purpose; each guard must go red, and every file is put back.
    # red <label> <expected text> <command...>: must exit non-zero AND say why.
    red() {
      local out rc=0
      out=$("${@:3}" 2>&1 </dev/null) || rc=$?
      if [ "$rc" -eq 0 ]; then echo "FAIL: $1 stayed green"; echo "$out"; exit 1; fi
      if ! grep -qF -- "$2" <<<"$out"; then
        echo "FAIL: $1 went red for another reason (expected: $2)"; echo "$out"; exit 1
      fi
    }
    changed() { if cmp -s "$1" "$2"; then echo "FAIL: $3 did not change the file"; exit 1; fi; }
    cp eslint.config.js "$TMP/e.bak"; awk '/"shadcn\/no-restyle": \[$/ { skip = 1 } !skip { print } skip && /^      \],$/ { skip = 0 }' "$TMP/e.bak" > eslint.config.js
    changed "$TMP/e.bak" eslint.config.js "removing the rule"
    red "removed rule" "not caught by shadcn/no-restyle" node tools/design_guards.mjs; cp "$TMP/e.bak" eslint.config.js
    awk 'hit { sub(/"error"/, "\"warn\""); hit = 0 } /"shadcn\/no-restyle": \[$/ { hit = 1 } { print }' "$TMP/e.bak" > eslint.config.js
    changed "$TMP/e.bak" eslint.config.js "the warn mutation"
    red "rule downgraded to warn" "not caught by shadcn/no-restyle" node tools/design_guards.mjs --only guards; cp "$TMP/e.bak" eslint.config.js
    sed 's#"src/generated/"\]#"src/generated/", "src/example/"]#' "$TMP/e.bak" > eslint.config.js
    changed "$TMP/e.bak" eslint.config.js "the ignored-folder mutation"
    red "screen ignored by eslint" "ignored by eslint: src/example/ReferenceScreen.tsx" node tools/design_guards.mjs --only guards; cp "$TMP/e.bak" eslint.config.js
    awk '{ print } /design-floor:end/ { print "  { files: [\"src/example/**\"], rules: { \"shadcn/no-restyle\": \"off\" } }," }' "$TMP/e.bak" > eslint.config.js
    changed "$TMP/e.bak" eslint.config.js "the folder override mutation"
    red "rule off for one folder" "shadcn/no-restyle differs from the floor for src/example/ReferenceScreen.tsx" node tools/design_guards.mjs --only guards; cp "$TMP/e.bak" eslint.config.js
    awk '{ print } /design-floor:end/ { print "  { files: [\"src/x/**\"], rules: { \"shadcn/no-raw-colors\": \"off\" } }," }' "$TMP/e.bak" > eslint.config.js
    changed "$TMP/e.bak" eslint.config.js "the other-rule override mutation"
    mkdir -p src/x; printf 'export const x = 1;\n' > src/x/a.ts
    red "other floor rule off for one folder" "shadcn/no-raw-colors differs from the floor for src/x/a.ts" node tools/design_guards.mjs --only guards; rm -r src/x; cp "$TMP/e.bak" eslint.config.js
    mkdir -p src/feature/components/ui; printf '// eslint-disable-next-line\nexport const x = 1;\n' > src/feature/components/ui/thing.ts
    red "disable in a nested ui folder" "eslint-disable without a reason: src/feature/components/ui/thing.ts" node tools/design_guards.mjs --only guards; rm -r src/feature
    cp mk/design.mk "$TMP/m.bak"; awk '{ if ($0 == "\t@npx playwright test") print "\t@-npx playwright test"; else print }' "$TMP/m.bak" > mk/design.mk
    changed "$TMP/m.bak" mk/design.mk "the ignored-step mutation"
    red "ignored browser step" "the browser step can no longer fail the gate" node tools/design_guards.mjs --only gate; cp "$TMP/m.bak" mk/design.mk
    cp src/main.tsx "$TMP/s.bak"; grep -v 'index.css' "$TMP/s.bak" > src/main.tsx
    changed "$TMP/s.bak" src/main.tsx "dropping the stylesheet import"
    red "missing stylesheet" 'expect(primary).not.toBe("")' make ui-floor; cp "$TMP/s.bak" src/main.tsx
    f=src/example/ReferenceScreen.tsx; cp "$f" "$TMP/r.bak"; sed 's#<h1#<h2#; s#</h1>#</h2>#' "$TMP/r.bak" > "$f"
    changed "$TMP/r.bak" "$f" "the heading mutation"
    red "missing heading" "getByRole('heading', { includeHidden: true, level: 1 })" make ui-floor; cp "$TMP/r.bak" "$f"
    # States come from the data source: when the list request can no longer fail, the error state is gone.
    f=src/example/data.ts; cp "$f" "$TMP/d.bak"; sed 's/ fail: "fail", empty/ empty/' "$TMP/d.bak" > "$f"
    changed "$TMP/d.bak" "$f" "the list request that cannot fail"
    red "error state without a failing request" "reaches /example error" make test; cp "$TMP/d.bak" "$f"
    # The reference screen shows a destructive badge: shadcn's own red must fail the floor there.
    cp src/index.css "$TMP/i.bak"; sed 's/--destructive: oklch(0.48 0.2 27.325)/--destructive: oklch(0.55 0.245 27.325)/' "$TMP/i.bak" > src/index.css
    changed "$TMP/i.bak" src/index.css "restoring the shadcn destructive red"
    red "destructive badge contrast" '"color-contrast"' make ui-floor; cp "$TMP/i.bak" src/index.css
    # A new screen is one entry in src/screens.ts, and the floor visits it. Its wide table has no
    # focusable cell, so only the patched scroll region keeps it reachable by keyboard.
    cp src/screens.ts "$TMP/sc.bak"; mkdir -p src/wide
    printf '%s\n' 'import { Table, TableBody, TableCell, TableRow } from "@/components/ui/table";' \
      'export function Wide() {' \
      '  const cells = Array.from({ length: 12 }, (_, i) => <TableCell key={i}>cell number {i}</TableCell>);' \
      '  return (<main><h1>Wide</h1><Table aria-label="wide"><TableBody><TableRow>{cells}</TableRow></TableBody></Table></main>);' \
      '}' > src/wide/Wide.tsx
    awk '{ print } /^export const SCREENS/ { print "  { path: \"/wide\", load: () => import(\"@/wide/Wide\").then((m) => m.Wide), states: [{ name: \"ready\", shows: \"cell number 0\" }] },"; }' "$TMP/sc.bak" > src/screens.ts
    changed "$TMP/sc.bak" src/screens.ts "registering a screen"
    npx playwright test --list > "$TMP/list.txt"
    grep -qF 'floor /wide ready at 390px' "$TMP/list.txt" || { echo "FAIL: the floor does not visit a registered screen"; exit 1; }
    make ui-floor >/dev/null || { echo "FAIL: a wide table failed the floor"; make ui-floor; exit 1; }
    cp src/components/ui/table.tsx "$TMP/t.bak"; grep -v 'tabIndex={0}' "$TMP/t.bak" > src/components/ui/table.tsx
    changed "$TMP/t.bak" src/components/ui/table.tsx "dropping the table patch"
    red "table scroll region" '"scrollable-region-focusable"' make ui-floor
    cp "$TMP/t.bak" src/components/ui/table.tsx; cp "$TMP/sc.bak" src/screens.ts; rm -r src/wide
    node node_modules/vite/bin/vite.js preview --host 127.0.0.1 --port 4173 >/dev/null 2>&1 & PREVIEW=$!
    for _ in $(seq 1 50); do (exec 3<>/dev/tcp/127.0.0.1/4173) 2>/dev/null && break; sleep 0.2; done
    red "busy port" "http://127.0.0.1:4173 is already used" make ui-floor
    kill "$PREVIEW"; wait "$PREVIEW" 2>/dev/null || true; PREVIEW=""
    # The sample's own behaviour is tested here, so the repo ships only the generic walk.
    cp "$ROOT/tests/fixtures/design/reference.test.tsx" tests/reference.test.tsx
    npx vitest run tests/reference.test.tsx --coverage.enabled=false >"$TMP/ref.txt" 2>&1 \
      || { echo "FAIL: the sample screen's own tests"; cat "$TMP/ref.txt"; exit 1; }
    rm tests/reference.test.tsx
    # The test hook is in the browser checks' build and gone from the build for users.
    npx vite build --mode floor --outDir coverage/floor --logLevel warn
    npm run --silent build >/dev/null
    ls dist/assets/*.js >/dev/null 2>&1 || { echo "FAIL: npm run build left no script to check"; exit 1; }
    grep -q 'Test scenario' coverage/floor/assets/*.js || { echo "FAIL: the browser checks' build lost the test hook"; exit 1; }
    if grep -q 'Test scenario' dist/assets/*.js; then echo "FAIL: the test hook ships in npm run build"; exit 1; fi
    echo "/* kept */" >> src/index.css
    python3 "$S/apply.py" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert not d["conflict"], d["conflict"]; assert "src/index.css" in d["kept"]'
    grep -q 'kept' src/index.css || { echo "FAIL: index.css overwritten"; exit 1; }
    make check >/dev/null || { echo "FAIL: make check after re-apply"; exit 1; }
    git checkout -q -- src/index.css 2>/dev/null || true
    ;;
  esac
  # commit-msg hook: bad message rejected, conventional message accepted
  if [ -n "$HOOKS_PATH" ]; then
    echo "initial setup" > "$TMP/msg"
    if pre-commit run --hook-stage commit-msg --commit-msg-filename "$TMP/msg" >/dev/null 2>&1; then
      echo "FAIL: non-conventional commit message was accepted"; exit 1
    fi
    echo "chore: initial setup" > "$TMP/msg"
    pre-commit run --hook-stage commit-msg --commit-msg-filename "$TMP/msg" >/dev/null
  elif git -c user.name=e2e -c user.email=e2e@example.com commit -qm "initial setup" >/dev/null 2>&1; then
    echo "FAIL: non-conventional commit message was accepted"; exit 1
  fi
  git -c user.name=e2e -c user.email=e2e@example.com commit -qm "chore: initial setup" >/dev/null
  echo "ok  $spec"
done
echo "E2E passed."

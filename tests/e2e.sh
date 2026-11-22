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
  # The autonomy card runs in a real install, with the real tools and no stand-in `gh`.
  make autonomy >"$TMP/autonomy.txt" 2>&1 || { echo "FAIL: make autonomy"; cat "$TMP/autonomy.txt"; exit 1; }
  grep -q "You are called when" "$TMP/autonomy.txt" || { echo "FAIL: make autonomy printed no card"; cat "$TMP/autonomy.txt"; exit 1; }
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
    cp mk/design.mk "$TMP/m.bak"; awk '{ if (index($0, "\t@node tools/ui_select.mjs --run") == 1) sub(/^\t@/, "\t@-"); print }' "$TMP/m.bak" > mk/design.mk
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
    # A real request behind the hook: the checks still pass, because the hook answers them.
    sed 's#^  return respond(() => \[\.\.\.items\]);$#  return fetch("/api/items").then((r) => r.json() as Promise<Item[]>);#' "$TMP/d.bak" > "$f"
    changed "$TMP/d.bak" "$f" "the real list request"
    make check >"$TMP/fetch.txt" 2>&1 || { echo "FAIL: a real request in the data source broke the checks"; cat "$TMP/fetch.txt"; exit 1; }
    cp "$TMP/d.bak" "$f"
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
    # An edit to a file the plugin wrote, whose template did not change: nothing to merge.
    python3 "$S/apply.py" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert not d["conflict"], d["conflict"]; assert "src/index.css" in d["edited"], d["edited"]'
    grep -qF '/* kept */' src/index.css || { echo "FAIL: re-apply lost an edit in src/index.css"; exit 1; }
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
  # The secret scan of CI (security.yml), run as CI runs it: green on a clean history, red once a
  # commit holds a token. The plain hook reads staged changes only and would pass both.
  case ",${SKIP:-}," in *,gitleaks,*) ;; *)
    if grep -q 'alias: gitleaks-history' .pre-commit-config.yaml 2>/dev/null; then
      pre-commit run gitleaks-history --hook-stage manual --all-files >/dev/null \
        || { echo "FAIL: the CI secret scan is red on a clean repository"; exit 1; }
      # Made at run time, so no token-shaped text sits in this file.
      python3 -c "import random, string; print('token = \"ghp_' + ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(36)) + '\"')" > e2e-planted.txt
      git add e2e-planted.txt
      SKIP=gitleaks git -c user.name=e2e -c user.email=e2e@example.com commit -qm "chore: planted token" >/dev/null
      if pre-commit run gitleaks-history --hook-stage manual --all-files >/dev/null 2>&1; then
        echo "FAIL: a committed token passes the CI secret scan"; exit 1
      fi
      git reset -q --hard HEAD~1
    fi ;;
  esac
  echo "ok  $spec"
done

# Upgrade from an earlier release (docs/superpowers/specs/2026-11-17-upgrade-path-design.md):
# build a repository with a tagged release, edit two files in place, upgrade with this tree. The
# fresh installs above never take this path. The base is downloaded, as a user's is.
# It runs with the default list; UPGRADE=1 runs it also when PRESETS narrows the list above.
#   python, from the newest release.
#   ts-node, from UPGRADE_NODE_FROM (default repo-setup-v0.7.0, the last release before its
#   package.json template changed), with that release's real install run before the upgrade:
#   npm writes devDependencies right after `scripts`, where the template adds its line too
#   (found on design-ci-probe, 0.7.0 -> 0.8.0: package.json came out marked).
# fetch_release <tag> <dir>: the release's tree, as GitHub serves it
fetch_release() {
  python3 - "$1" "$2" <<'PY'
import io, sys, tarfile, urllib.request
tag, dest = sys.argv[1], sys.argv[2]
url = f"https://codeload.github.com/phanlemanh/repo-standards/tar.gz/refs/tags/{tag}"
data = urllib.request.urlopen(url, timeout=60).read()
with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tar:
    tar.extractall(dest, filter="data")
PY
}
# run_install <label> <apply --json output>: its install commands, pre-commit left out
run_install() {
  local c
  while IFS= read -r c; do
    case "$c" in "") continue ;; *"pre-commit install"*) continue ;; esac
    echo "[$1] \$ $c"; bash -c "$c" >/dev/null </dev/null
  done < <(python3 -c 'import json,sys;[print(c) for c in json.loads(sys.argv[1])["next_commands"]["install"]]' "$2")
}
# upgrade_case <preset> <tag> <codegen lang> <install first: yes|no>
upgrade_case() {
  local preset="$1" tag="$2" lang="$3" install_first="$4"
  local prev="$TMP/prev-$tag" label="upgrade-$preset-from-$tag"
  [ -d "$prev" ] || { mkdir -p "$prev"; fetch_release "$tag" "$prev"; }
  local old_apply; old_apply=$(find "$prev" -path '*/plugins/repo-setup/scripts/apply.py' | head -1)
  [ -n "$old_apply" ] || { echo "FAIL: $tag has no apply.py"; exit 1; }
  local d="$TMP/$label"; mkdir -p "$d"; cd "$d"; git init -q -b main
  local old_out; old_out=$(python3 "$old_apply" --preset "$preset" --level team --var "project_name=Coffee Shop" \
    --var "description=E2E upgrade" --var owner=acme --json)
  [ "$install_first" = yes ] && run_install "$label (before)" "$old_out"
  gen_out=$(sed -n 's/^GEN_OUT := //p' Makefile | sed "s/\$(PKG)/$(sed -n 's/^PKG := //p' Makefile)/")
  # A release from before ledgers-as-fragments (0.8.0) has no mk/derived.mk: there the three
  # ledgers and the generated code are hand-kept files in git. A later release keeps them out.
  local one_file=no
  if [ ! -f mk/derived.mk ]; then
    one_file=yes
    mkdir -p "$(dirname "$gen_out")"
    python3 tools/ontology_codegen.py --lang "$lang" --out "$gen_out" >/dev/null
    git add -f -A
  else
    git add -A
  fi
  git -c user.name=e2e -c user.email=e2e@example.com commit -qm "chore: base from $tag"
  printf '# kept by the repository\n' | cat - .editorconfig > x && mv x .editorconfig
  echo "Kept by the repository." >> README.md
  rc=0; out=$(python3 "$S/apply.py" --json) || rc=$?
  field() { python3 -c "import json,sys; print(json.dumps(json.loads(sys.argv[1])[sys.argv[2]]))" "$out" "$1"; }
  [ "$(field base_unread)" = "[]" ] || { echo "FAIL: $label could not read a base: $(field base_reasons)"; exit 1; }
  grep -q '^# kept by the repository' .editorconfig || { echo "FAIL: $label lost an edit in .editorconfig"; exit 1; }
  grep -q '^Kept by the repository.' README.md || { echo "FAIL: $label lost an edit in README.md"; exit 1; }
  if [ "$install_first" = yes ]; then
    case "$(field marked)" in *'"package.json"'*) echo "FAIL: $label marked package.json after npm install"; exit 1 ;; esac
    grep -q '"prepare"' package.json || { echo "FAIL: $label did not bring the prepare script into package.json"; exit 1; }
    python3 -c "import json,sys; d=json.load(open('package.json')); sys.exit(0 if d.get('devDependencies') else 1)" \
      || { echo "FAIL: $label lost the devDependencies npm wrote"; exit 1; }
  fi
  run_install "$label" "$out"
  git add -A
  marked=$(field marked)
  if [ "$marked" = "[]" ] && [ "$one_file" = no ]; then
    [ "$rc" = 0 ] || { echo "FAIL: $label ended with $rc and nothing marked"; exit 1; }
    make check >/dev/null || { echo "FAIL: make check is red after $label"; exit 1; }
    for l in log index glossary; do
      [ "$(python3 tools/ledgers.py shape $l)" = fragments ] || { echo "FAIL: shape $l is not fragments after $label"; exit 1; }
    done
  elif [ "$marked" = "[]" ]; then
    [ "$rc" = 0 ] || { echo "FAIL: $label ended with $rc and nothing marked"; exit 1; }
    make check >/dev/null || { echo "FAIL: make check is red after $label"; exit 1; }
    # The upgrade created no fragment and moved nothing: the four ledgers are still one file each.
    for l in log index glossary; do
      [ "$(python3 tools/ledgers.py shape $l)" = one-file ] || { echo "FAIL: shape $l is not one-file after $label"; exit 1; }
    done
    [ "$(python3 tools/ledgers.py shape gen --gen-out "$gen_out")" = one-file ] || { echo "FAIL: shape gen is not one-file after $label"; exit 1; }
    # Then the owner splits them, one at a time, and a clean clone still passes make check.
    for l in log index glossary gen; do
      make split L=$l >/dev/null || { echo "FAIL: make split L=$l failed after $label"; exit 1; }
    done
    for l in log index glossary; do
      [ "$(python3 tools/ledgers.py shape $l)" = fragments ] || { echo "FAIL: shape $l is not fragments after its split"; exit 1; }
    done
    [ "$(python3 tools/ledgers.py shape gen --gen-out "$gen_out")" = fragments ] || { echo "FAIL: shape gen is not fragments after its split"; exit 1; }
    git add -A; git -c user.name=e2e -c user.email=e2e@example.com commit -qm "feat: split the ledgers"
    drawn=$(git ls-files | grep -xE "wiki/log.md|wiki/index.md|ontology/glossary.md|$gen_out" || true)
    [ -z "$drawn" ] || { echo "FAIL: git ls-files lists drawn files after the splits: $drawn"; exit 1; }
    git clone -q "$d" "$TMP/$label-clone"; ( cd "$TMP/$label-clone"
      run_install "$label (clone)" "$out" >/dev/null
      make check >/dev/null ) || { echo "FAIL: make check is red on a fresh clone after the splits"; exit 1; }
    echo "ok  split all four ledgers after $label"
  else
    [ "$rc" = 1 ] || { echo "FAIL: $label marked $marked but ended with $rc"; exit 1; }
    wall=$(make upgrade 2>&1) && { echo "FAIL: make upgrade is green with $marked marked"; exit 1; }
    first=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])[0])" "$marked")
    grep -qF "$first:" <<<"$wall" || { echo "FAIL: make upgrade does not name $first"; exit 1; }
  fi
  echo "ok  $label (marked: $marked)"
}
if [ -z "${PRESETS:-}" ] || [ -n "${UPGRADE:-}" ]; then
  # The newest release, read the way apply.py reads it (git ls-remote): CI checks out one commit
  # and no tags, so `git describe` finds none.
  tag=$(python3 -c "import sys; sys.path.insert(0, sys.argv[1]); import upgrade_base; print(upgrade_base.TAG_PREFIX + upgrade_base.released_versions(None)[0])" "$ROOT/plugins/repo-setup/scripts")
  upgrade_case python "$tag" python no
  upgrade_case ts-node "${UPGRADE_NODE_FROM:-repo-setup-v0.7.0}" ts yes
fi
echo "E2E passed."

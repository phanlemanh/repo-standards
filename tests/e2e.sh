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
    cp eslint.config.js "$TMP/e.bak"; grep -v 'shadcn/no-restyle' "$TMP/e.bak" > eslint.config.js
    changed "$TMP/e.bak" eslint.config.js "removing the rule"
    red "removed rule" "not caught by shadcn/no-restyle" node tools/design_guards.mjs; cp "$TMP/e.bak" eslint.config.js
    sed 's#"shadcn/no-restyle": \["error"#"shadcn/no-restyle": ["warn"#' "$TMP/e.bak" > eslint.config.js
    changed "$TMP/e.bak" eslint.config.js "the warn mutation"
    red "rule downgraded to warn" "not caught by shadcn/no-restyle" node tools/design_guards.mjs --only guards; cp "$TMP/e.bak" eslint.config.js
    cp mk/design.mk "$TMP/m.bak"; awk '{ if ($0 == "\tnpx playwright test") print "\t-npx playwright test"; else print }' "$TMP/m.bak" > mk/design.mk
    changed "$TMP/m.bak" mk/design.mk "the ignored-step mutation"
    red "ignored browser step" "the browser step can no longer fail the gate" node tools/design_guards.mjs --only gate; cp "$TMP/m.bak" mk/design.mk
    cp src/main.tsx "$TMP/s.bak"; grep -v 'index.css' "$TMP/s.bak" > src/main.tsx
    changed "$TMP/s.bak" src/main.tsx "dropping the stylesheet import"
    red "missing stylesheet" 'expect(primary).not.toBe("")' make ui-floor; cp "$TMP/s.bak" src/main.tsx
    f=src/example/ReferenceScreen.tsx; cp "$f" "$TMP/r.bak"; sed 's#<h1#<h2#; s#</h1>#</h2>#' "$TMP/r.bak" > "$f"
    changed "$TMP/r.bak" "$f" "the heading mutation"
    red "missing heading" "getByRole('heading', { level: 1 })" make ui-floor; cp "$TMP/r.bak" "$f"
    node node_modules/vite/bin/vite.js preview --host 127.0.0.1 --port 4173 >/dev/null 2>&1 & PREVIEW=$!
    for _ in $(seq 1 50); do (exec 3<>/dev/tcp/127.0.0.1/4173) 2>/dev/null && break; sleep 0.2; done
    red "busy port" "http://127.0.0.1:4173 is already used" make ui-floor
    kill "$PREVIEW"; wait "$PREVIEW" 2>/dev/null || true; PREVIEW=""
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

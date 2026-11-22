#!/usr/bin/env bash
# Fast offline tests for the repo-setup scripts (no dependency installs).
# Full end-to-end verification (real installs + make check + pre-commit): tests/e2e.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/plugins/repo-setup/scripts"
TMP="$(mktemp -d)"
# bash 3.2 (macOS) leaves a sourced file that does not parse with exit code 0 once this trap has
# run, so a run that stops before its last line fails here instead of passing in silence.
reached_end=
trap 'rm -rf "$TMP"; [ -n "$reached_end" ] || { echo "FAIL: tests/run.sh stopped before its last check" >&2; exit 1; }' EXIT
fail() { echo "FAIL: $*" >&2; reached_end=1; exit 1; }
json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }
# Portable in-place edit: `sed -i` differs between GNU and BSD (macOS).
subst() { sed "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"; }
# Regression checks report every miss before the run fails.
misses=0
miss() { echo "FAIL: $*" >&2; misses=$((misses + 1)); }

# What a release before ledgers-as-fragments wrote: the wiki log, the wiki index and the glossary as hand-kept
# files. A fixture that tests the one-file shape (an old repository) calls this; with a second word it also
# puts them in git, past the .gitignore lines that keep a new repository's drawn copies out of it.
onefile_ledgers() { # <dir> [track]
  mkdir -p "$1/wiki" "$1/ontology"
  cat > "$1/wiki/log.md" <<'LEDGER'
---
type: log
title: Change log of the wiki and notable code changes
---

# Log

Newest first. One line each: `YYYY-MM-DD — what changed — link`.

- 2026-01-01 — Repository created with repo-setup (test).
LEDGER
  cat > "$1/ontology/glossary.md" <<'LEDGER'
# Glossary — P

One line per business term. If two people could understand a word differently,
it belongs here. Code, docs and agents must use these exact names.

| Term (code name)      | Definition                             | Not to be confused with    | Display name |
| --------------------- | -------------------------------------- | -------------------------- | ------------ |
| _Example:_ `Customer` | A person who has bought at least once. | `Visitor` (has not bought) | Customer     |

<!-- Add your terms above. Keep definitions to one sentence. -->
LEDGER
  cat > "$1/wiki/index.md" <<'LEDGER'
---
type: index
title: P wiki
---

# P wiki

Short, linked pages about the _why_ of this project. Agents read this page
first; keep it under ~60 lines. Page formats: `ontology/page-types.yaml`.

## Entities

<!-- - [Customer](entities/customer.md) — who buys; VIP rules -->

## Flows

<!-- - [Checkout](flows/checkout.md) -->

## Specs

<!-- - [0001 VIP discount](specs/0001-vip-discount.md) -->

## Decisions

- [0001 Record decisions in the wiki](decisions/0001-record-decisions-in-the-wiki.md)

## Incidents

<!-- - [2026-01-15 Double charge](incidents/2026-01-15-double-charge.md) -->

## Metrics

<!-- weekly reports from tools/sdlc_metrics.py (team level) -->

## Log

See [log.md](log.md) for a chronological list of changes.
LEDGER
  [ "${2:-}" = track ] && git -C "$1" add -f wiki/log.md wiki/index.md ontology/glossary.md
  return 0
}

PRESETS=$(python3 "$S/apply.py" --list-presets --json | python3 -c "import json,sys; print(' '.join(json.load(sys.stdin)))")
for preset in $PRESETS; do
  for level in starter team; do
    d="$TMP/$preset-$level"
    mkdir -p "$d" && git -C "$d" init -q -b main

    # 1. dry run writes nothing
    python3 "$S/apply.py" --target "$d" --preset "$preset" --level "$level" \
      --var 'project_name=Coffee "Shop"' --var 'description=Orders \ loyalty' --var owner=acme --dry-run --json >/dev/null
    [ -z "$(ls -A "$d" | grep -v '^.git$' || true)" ] || fail "$preset/$level: dry run wrote files"

    # 2. apply creates files, no unrendered placeholders
    created=$(python3 "$S/apply.py" --target "$d" --preset "$preset" --level "$level" \
      --var 'project_name=Coffee "Shop"' --var 'description=Orders \ loyalty' --var owner=acme --json | json 'len(d["created"])')
    [ "$created" -ge 20 ] || fail "$preset/$level: only $created files created"
    if grep -rIlE --exclude-dir=.git --exclude-dir=workflows '\{\{ *[a-z_]+ *\}\}' "$d" ; then fail "$preset/$level: unrendered placeholder"; fi

    # 3. generated JSON/TOML stay valid even with quotes and backslashes in vars
    python3 - "$d" <<'PY'
import json, sys, tomllib, pathlib
root = pathlib.Path(sys.argv[1])
for p in root.rglob("*.json"):
    json.loads(p.read_text())
for p in root.rglob("*.toml"):
    tomllib.loads(p.read_text())
PY

    # 4. second run is a no-op
    again=$(python3 "$S/apply.py" --target "$d" --json | json 'len(d["created"])+len(d["updated"])+len(d["conflict"])')
    [ "$again" -eq 0 ] || fail "$preset/$level: second run changed $again files"

    # 5. user edits are never overwritten: the template did not change, so there is nothing to merge
    echo "my note" >> "$d/README.md"
    edited=$(python3 "$S/apply.py" --target "$d" --json | json '"README.md" in d["edited"]')
    [ "$edited" = "True" ] || fail "$preset/$level: edited README not reported as edited"
    grep -q "my note" "$d/README.md" || fail "$preset/$level: README was overwritten"

    # 6. doctor: everything except the lockfile (needs an install) passes;
    #    a plugin marketplace has nothing to install, so nothing fails
    git -C "$d" add -A
    expected=lockfile; [ "$preset" = claude-plugin ] && expected=""
    failed=$(python3 "$S/doctor.py" --target "$d" --level "$level" --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
    [ "$preset" = react-vite ] && expected=design_present,lockfile
    [ "$failed" = "$expected" ] || fail "$preset/$level: unexpected doctor failures: $failed"

    # 6b. bytecode from the vendored Python tools never reaches a commit
    git -C "$d" check-ignore -q tools/__pycache__/x.pyc || miss "$preset/$level: tools/__pycache__ is not ignored"

    # 6c. sample config has no credential-shaped values: secret scanners would block the first commit
    if [ -f "$d/.env.example" ] && grep -qE '://[^/[:space:]]+:[^@[:space:]]+@' "$d/.env.example"; then miss "$preset/$level: .env.example has credentials in a URL"; fi

    echo "ok  $preset/$level"
  done
done

# 6d. Prettier must not rewrite the manifest: re-apply would then rewrite it unformatted
grep -qxF '.repo-setup.json' "$TMP/ts-node-starter/.prettierignore" || miss "ts-node: .prettierignore does not list .repo-setup.json"

# 7. starter -> team upgrade adds team files only
d="$TMP/upgrade"; mkdir -p "$d"
python3 "$S/apply.py" --target "$d" --preset python --var project_name=Up --var description=x --var owner=acme >/dev/null
added=$(python3 "$S/apply.py" --target "$d" --level team --json | json 'len(d["created"])')
[ "$added" -ge 10 ] || fail "upgrade added only $added files"
level=$(python3 -c "import json;print(json.load(open('$d/.repo-setup.json'))['level'])")
[ "$level" = "team" ] || fail "manifest level not upgraded"
echo "ok  upgrade starter -> team"

# 8. doctor on an empty folder scores 0 and --min-score fails
e="$TMP/empty"; mkdir -p "$e"
if python3 "$S/doctor.py" --target "$e" --min-score 50 >/dev/null; then fail "min-score did not fail"; fi
echo "ok  doctor --min-score"

# 9. adopt mode on an existing codebase
a="$TMP/legacy"; mkdir -p "$a/src" "$a/.github/workflows" && git -C "$a" init -q -b main
printf '{"name":"legacy","scripts":{"test":"jest"}}\n' > "$a/package.json"
printf '{"extends":"eslint:recommended"}\n' > "$a/.eslintrc.json"
printf '# Legacy\n' > "$a/README.md"
printf 'node_modules/\n' > "$a/.gitignore"
printf 'export const a = 1;\n' > "$a/src/app.ts"
printf 'name: test\n' > "$a/.github/workflows/test.yml"
out=$(python3 "$S/apply.py" --target "$a" --preset ts-node --level team --adopt \
  --var project_name=Legacy --var description=x --var owner=acme --json)
check() { python3 -c "import json,sys; d=json.loads(sys.argv[1]); assert $2, sys.argv[2]" "$out" "$1" || fail "adopt: $1"; }
check "'eslint.config.js' in d['skipped']" "'eslint.config.js' in d['skipped']"
check "'.github/workflows/ci.yml' in d['skipped']" "'.github/workflows/ci.yml' in d['skipped']"
check "'src/greet.ts' in d['skipped']" "'src/greet.ts' in d['skipped']"
check "'README.md' in d['conflict']" "'README.md' in d['conflict']"
check "'.gitignore' in d['merged']" "'.gitignore' in d['merged']"
check "'package.json' in d['kept']" "'package.json' in d['kept']"
check "'AGENTS.md' in d['created'] and 'ontology/glossary.head.md' in d['created'] and 'ontology/glossary.md' not in d['created']" "'AGENTS.md' in d['created'] and 'ontology/glossary.head.md' in d['created'] and 'ontology/glossary.md' not in d['created']"
grep -q '^node_modules/$' "$a/.gitignore" && grep -q '^\.env$' "$a/.gitignore" || fail "adopt: .gitignore not merged"
[ "$(grep -c '^\.env$' "$a/.gitignore")" = 1 ] || fail "adopt: duplicate lines"
again=$(python3 "$S/apply.py" --target "$a" --json | json 'len(d["created"])+len(d["merged"])')
[ "$again" -eq 0 ] || fail "adopt: second run changed $again files"
[ ! -e "$a/src/greet.ts" ] || fail "adopt: sample code added"
echo "ok  adopt mode"

# 10. license variants
for lic in MIT Apache-2.0 Proprietary; do
  l="$TMP/lic-$lic"; mkdir -p "$l"
  python3 "$S/apply.py" --target "$l" --preset ts-node --var project_name=L --var description=x --var owner=acme --var license=$lic >/dev/null
  case $lic in
    MIT) grep -q "MIT License" "$l/LICENSE" && grep -q '"license": "MIT"' "$l/package.json" ;;
    Apache-2.0) grep -q "Apache License" "$l/LICENSE" && grep -q '"license": "Apache-2.0"' "$l/package.json" ;;
    Proprietary) grep -q "All rights reserved" "$l/LICENSE" && grep -q '"license": "UNLICENSED"' "$l/package.json" ;;
  esac || fail "license $lic"
  [ "$(ls "$l" | grep -c '^\[')" = 0 ] || fail "license $lic: condition folder leaked"
done
if python3 "$S/apply.py" --target "$TMP/lic-bad" --preset python --var project_name=L --var description=x --var owner=acme --var license=GPL >/dev/null 2>&1; then fail "bad license accepted"; fi
echo "ok  license variants"

# 11. ontology tools: wiki-lint + codegen on a sample domain (no installs needed)
o="$TMP/onto"; mkdir -p "$o" && git -C "$o" init -q -b main
python3 "$S/apply.py" --target "$o" --preset ts-node --var project_name=Onto --var description=x --var owner=acme >/dev/null
python3 "$ROOT/tests/apply_fixture.py" coffee "$o" >/dev/null
( cd "$o" && python3 tools/wiki_lint.py >/dev/null ) || fail "wiki-lint failed on fixture"
( cd "$o" && python3 tools/ontology_codegen.py --lang ts --out src/generated/ontology.ts >/dev/null \
  && python3 tools/ontology_codegen.py --lang python --out gen/ontology_types.py >/dev/null )
grep -q 'export function isVIPCustomer(e: Customer): boolean' "$o/src/generated/ontology.ts" || fail "codegen ts predicate"
grep -q 'e.points >= 100 && e.status === "active"' "$o/src/generated/ontology.ts" || fail "codegen ts rule"
grep -q 'def is_vip_customer(e: Customer) -> bool:' "$o/gen/ontology_types.py" || fail "codegen py predicate"
grep -q 'predicate not generated (property .phone. is optional)' "$o/gen/ontology_types.py" || fail "codegen optional guard"
python3 -c "import ast,sys; ast.parse(open('$o/gen/ontology_types.py').read())" || fail "codegen py syntax"
( cd "$o" && python3 tools/ontology_codegen.py --lang ts --out src/generated/ontology.ts --check >/dev/null ) || fail "codegen --check fresh"
subst 's/points >= 100/points >= 150/' "$o/ontology/entities/Customer.yaml"
if ( cd "$o" && python3 tools/ontology_codegen.py --lang ts --out src/generated/ontology.ts --check >/dev/null 2>&1 ); then fail "codegen drift not detected"; fi
subst 's/target: Customer/target: Client/' "$o/ontology/entities/Order.yaml"
if ( cd "$o" && python3 tools/wiki_lint.py >/dev/null ); then fail "wiki-lint missed unknown ref"; fi
subst 's/target: Client/target: Customer/' "$o/ontology/entities/Order.yaml"
printf -- '---\ntype: decision\ntitle: Bad\n---\n# x\n' > "$o/wiki/decisions/bad.md"
errs=$( cd "$o" && { python3 tools/wiki_lint.py --json || true; } | json 'len(d["errors"])' )
# rule-check: wiki-format
[ "$errs" -ge 3 ] || fail "wiki-lint: bad decision page gave only $errs errors"
echo "ok  ontology tools (wiki-lint, codegen)"

# 13. archetype / deploy / capability combinations (offline: generate code with the tools)
for combo in "ts-api:service-api:container" "fastapi:service-api:container" "python:modular-monolith:none" "ts-node:modular-monolith:none:mcp" "python:none:none:mcp"; do
  IFS=: read -r stack arch dep cap <<<"$combo"
  c="$TMP/combo-${stack}-${arch}-${dep}-${cap:-x}"; mkdir -p "$c" && git -C "$c" init -q -b main
  python3 "$S/apply.py" --target "$c" --preset "$stack" --archetype "$arch" --deploy "$dep" --with "github-agents${cap:+,$cap}" --level team \
    --var project_name=Combo --var description=x --var owner=acme/platform >/dev/null || fail "$combo: apply"
  ( cd "$c"
    lang=$(python3 -c "import json; print(json.load(open('.repo-setup.json'))['preset'])")
    case "$stack" in ts-*|react-*) python3 tools/ontology_codegen.py --lang ts --out src/generated/ontology.ts >/dev/null ;;
      *) python3 tools/ontology_codegen.py --lang python --out src/combo/ontology_types.py >/dev/null ;; esac
    [ -f tools/openapi_gen.py ] && python3 tools/openapi_gen.py >/dev/null
    git add -A ) || fail "$combo: generate"
  failed=$(python3 "$S/doctor.py" --target "$c" --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
  [ "$failed" = "lockfile" ] || fail "$combo: unexpected doctor failures: $failed"
  grep -q "## AI-native SDLC" "$c/AGENTS.md" || fail "$combo: SDLC section missing from AGENTS.md"
  case "$arch" in
    service-api) grep -q "## Architecture: Service API" "$c/AGENTS.md" && [ -f "$c/contracts/openapi.json" ] || fail "$combo: service-api parts" ;;
    modular-monolith) grep -q "## Architecture: modular monolith" "$c/AGENTS.md" && [ -f "$c/architecture/modules.yaml" ] || fail "$combo: monolith parts" ;;
  esac
  if [ "$dep" = container ]; then grep -q "^USER " "$c/Dockerfile" && grep -q "ghcr.io/acme" "$c/mk/deploy.mk" || fail "$combo: container"; fi
  if [ "$arch" = service-api ] || [ "$cap" = mcp ]; then [ -f "$c/.mcp.json" ] || fail "$combo: .mcp.json"; fi
  echo "ok  combo $combo"
done
if python3 "$S/apply.py" --target "$TMP/bad-combo" --preset react-vite --archetype service-api --var project_name=B --var description=x --var owner=a >/dev/null 2>&1; then fail "incompatible combo accepted"; fi
echo "ok  incompatible combination rejected"

# 13b. the container guide says only what the level builds: a rollout to staging and an approval
# for production are named in AGENTS.md only where deploy.yml and `make deploy` exist (level team)
for stack in ts-api fastapi; do
  for lv in starter team; do
    cg="$TMP/container-guide-$stack-$lv"; mkdir -p "$cg" && git -C "$cg" init -q -b main
    python3 "$S/apply.py" --target "$cg" --preset "$stack" --deploy container --level "$lv" \
      --var project_name=Cg --var description=x --var owner=acme/platform >/dev/null || fail "container guide: $stack $lv: apply"
    grep -q '^## Deployment: container' "$cg/AGENTS.md" && grep -qF '`make image`' "$cg/AGENTS.md" && grep -qF '/health' "$cg/AGENTS.md" \
      || miss "container guide: $stack $lv: AGENTS.md lost what the image layer gives (make image, /health)"
    if [ -f "$cg/.github/workflows/deploy.yml" ] && grep -q '^deploy:' "$cg/mk/deploy.mk" 2>/dev/null; then
      grep -qi 'staging' "$cg/AGENTS.md" && grep -q 'approve' "$cg/AGENTS.md" && grep -qF '`make deploy`' "$cg/AGENTS.md" \
        || miss "container guide: $stack $lv: the repository deploys, and AGENTS.md does not say staging rolls out and production waits for an approval"
      [ "$lv" = team ] || miss "container guide: $stack $lv: a deploy pipeline below level team"
    else
      cg_said=$(grep -niE 'staging|make deploy|approve|releases? deploy' "$cg/AGENTS.md" || true)
      [ -z "$cg_said" ] || miss "container guide: $stack $lv: AGENTS.md promises a rollout the repository does not have (no deploy.yml, no make deploy): $(echo $cg_said)"
      [ "$lv" = starter ] || miss "container guide: $stack $lv: level team has no deploy pipeline"
    fi
  done
done
# the two texts the setup skill reads before anything is built say the same: the rollout is level team
python3 "$S/apply.py" --list-options | json 'd["deploy"]["container"]["description"]' | grep 'at level team, image push + rollout' >/dev/null \
  || miss "container guide: --list-options promises the image push and the rollout at every level"
grep -qF 'come with level `team`' "$ROOT/plugins/repo-setup/skills/new/references/layers/delivery.md" \
  || miss "container guide: the delivery layer page does not say the rollout comes with level team"
echo "ok  container guide matches the level (or misses reported above)"

# 14. module boundaries catch violations
b="$TMP/combo-python-modular-monolith-none-x"
printf 'from coffee_bad import x\nfrom ..loyalty import points_for\n' >> "$b/src/combo/modules/sales/pricing.py"
# rule-check: module-boundaries
if ( cd "$b" && python3 tools/boundaries.py >/dev/null ); then fail "boundaries missed a forbidden dependency"; fi
echo "ok  module boundaries"

# 14b. TS boundaries: `@/` alias, the server entry, src/app and "use client"
bt="$TMP/combo-ts-node-modular-monolith-none-mcp/tools/boundaries.py"
boundary_errors() { # $1 = file to plant, $2 = its text
  local r; r=$(mktemp -d "$TMP/bnd.XXXXXX")
  mkdir -p "$r/architecture" "$r/src/modules/listings" "$r/src/modules/contacts" "$(dirname "$r/$1")"
  printf 'modules:\n  - name: listings\n    owns: []\n    depends_on: [contacts]\n  - name: contacts\n    owns: []\n    depends_on: []\n' > "$r/architecture/modules.yaml"
  printf 'export {};\n' > "$r/src/modules/listings/index.ts"
  printf 'export {};\n' > "$r/src/modules/contacts/index.ts"
  printf '%b' "$2" > "$r/$1"
  { python3 "$bt" --root "$r" --json || true; } | json '"\n".join(d["errors"])'
}
expect_boundary() { # $1 = case, $2 = file, $3 = text, $4 = part of the expected error, "" = none
  local out; out=$(boundary_errors "$2" "$3") || out="tool crashed"
  if [ -z "$4" ]; then
    [ -z "$out" ] || miss "boundaries: $1: unexpected error: $out"
  else
    case "$out" in *"$4"*) ;; *) miss "boundaries: $1: expected '$4', got '${out:-no error}'" ;; esac
  fi
}
expect_boundary "server entry of a declared dependency" src/modules/listings/a.ts \
  'import { x } from "../contacts/server";\n' ""
expect_boundary "server entry of an undeclared dependency" src/modules/contacts/a.ts \
  'import { x } from "../listings/server";\n' "may not use"
expect_boundary "internal file through @/" src/modules/listings/a.ts \
  'import { x } from "@/modules/contacts/phones";\n' "public API"
expect_boundary "undeclared dependency through @/" src/modules/contacts/a.ts \
  'import { x } from "@/modules/listings";\n' "may not use"
expect_boundary "@/ reaches modules under a package folder" src/shop/modules/orders/a.ts \
  'import { x } from "@/shop/modules/billing/inner";\n' "may not use"
expect_boundary "internal file from src/app through @/" src/app/page.tsx \
  'import { x } from "@/modules/contacts/phones";\n' "public API"
expect_boundary "internal file from src/app, relative" src/app/page.tsx \
  'import { x } from "../modules/contacts/phones";\n' "public API"
expect_boundary "client file imports a server entry" src/app/widget.tsx \
  '"use client";\nimport { x } from "@/modules/contacts/server";\n' "client file"
expect_boundary "client directive after a comment" src/app/widget.tsx \
  '// banner\n"use client";\nimport { x } from "@/modules/contacts/server";\n' "client file"
expect_boundary "client file imports its own module's server entry" src/modules/contacts/widget.tsx \
  "'use client';\nimport { x } from './server';\n" "client file"
expect_boundary "client file uses the index entry" src/app/widget.tsx \
  '"use client";\nimport { x } from "@/modules/contacts";\n' ""
expect_boundary "server component uses a server entry" src/app/page.tsx \
  'import { x } from "@/modules/contacts/server";\n' ""
echo "ok  ts module boundaries (or misses reported above)"

# 15. API breaking-change detection
a="$TMP/combo-fastapi-service-api-container-x"
cp "$a/contracts/openapi.json" "$TMP/old.json"
python3 - "$TMP/old.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["paths"]["/v1/actions/gone"] = {"post": {"operationId": "gone", "responses": {"200": {"description": "ok"}}}}
json.dump(d, open(p, "w"))
PY
# rule-check: api-compat
if python3 "$a/tools/api_compat.py" --base "$TMP/old.json" --head "$a/contracts/openapi.json" >/dev/null 2>&1; then fail "api-compat missed a removed operation"; fi
python3 "$a/tools/api_compat.py" --base "$a/contracts/openapi.json" --head "$a/contracts/openapi.json" >/dev/null || fail "api-compat false positive"
echo "ok  api breaking-change detection"

# 16. autonomy tiers and the PreToolUse gate
g="$TMP/combo-ts-api-service-api-container-x"
tier=$(cd "$g" && python3 tools/autonomy.py --files wiki/log.md src/app.ts governance/autonomy.yaml | json 'd["tier"]')
[ "$tier" = high ] || fail "autonomy tier: $tier"
mid=$(cd "$g" && python3 tools/autonomy.py --files wiki/log.md src/app.ts ontology/actions.yaml | json 'd["tier"]')
[ "$mid" = medium ] || fail "autonomy tier of product code and ontology: $mid"
low=$(cd "$g" && python3 tools/autonomy.py --files wiki/log.md docs/x.md | json 'd["tier"]')
[ "$low" = low ] || fail "autonomy low tier: $low"
( cd "$g" && python3 tools/autonomy.py --check-codeowners >/dev/null ) || fail "codeowners out of sync"
echo "ok  autonomy tiers"

# 17. tiers on real git history: renames, weakened tests, agent config, non-ASCII names
r="$TMP/tiers"; mkdir -p "$r/governance" "$r/src" "$r/tests/a" "$r/wiki" "$r/docs"
git -C "$r" init -q -b main
seq 1 30 > "$r/governance/x.yaml"
seq 1 30 > "$r/governance/đơn.yaml"
seq 1 30 > "$r/src/app.ts"
seq 1 30 > "$r/tests/a/test_x.py"
seq 1 30 > "$r/tests/a/app.test.ts"
commit() { git -C "$r" add -A && git -C "$r" -c user.name=t -c user.email=t@example.com commit -qm "$1"; }
commit init
start() { git -C "$r" checkout -q -B "$1" main; }
expect_tier() {
  actual=$(python3 "$g/tools/autonomy.py" --root "$r" --policy "$g/governance/autonomy.yaml" --base main --head HEAD | json 'd["tier"]')
  [ "$actual" = "$2" ] || miss "tier of '$1': got $actual, want $2"
}
start c1; git -C "$r" mv governance/x.yaml wiki/x.yaml; commit c1
expect_tier "high-tier file renamed into wiki/" high
start c2; git -C "$r" mv src/app.ts docs/app.ts; commit c2
expect_tier "source file renamed into docs/" medium
start c3; mkdir -p "$r/tests/b"; git -C "$r" mv tests/a/test_x.py tests/b/test_x.py; subst '$d' "$r/tests/b/test_x.py"; commit c3
expect_tier "test moved with a line removed" medium
start c4; printf 'describe.skip("off", () => {});\n' >> "$r/tests/a/app.test.ts"; commit c4
# rule-check: autonomy-gate
expect_tier "describe.skip added" medium
start c5; printf '@pytest.mark.skip\ndef test_y(): ...\n' >> "$r/tests/a/test_x.py"; commit c5
expect_tier "pytest skip marker added" medium
start c6; echo 'collect_ignore_glob = ["*"]' > "$r/tests/conftest.py"; commit c6
expect_tier "conftest.py added" high
start c7; mkdir -p "$r/docs"; echo x > "$r/docs/CLAUDE.md"; commit c7
expect_tier "nested CLAUDE.md" high
start c8; echo '{}' > "$r/tests/.mcp.json"; commit c8
expect_tier "nested .mcp.json" high
start c9; echo 31 >> "$r/governance/đơn.yaml"; commit c9
expect_tier "non-ASCII high-tier path" high
start c10; mkdir -p "$r/docs"; echo x > "$r/docs/new.md"; printf 'def test_new(): ...\n' >> "$r/tests/a/test_x.py"; commit c10
expect_tier "plain docs and an added test" low
echo "ok  tiers on git history (or misses reported above)"

# 20. `agent: forbidden` holds in can() itself, so every entry point honours it; lint rejects the mix
f="$TMP/forbidden"; mkdir -p "$f" && git -C "$f" init -q -b main
python3 "$S/apply.py" --target "$f" --preset python --var project_name=F --var description=x --var owner=acme >/dev/null
python3 "$ROOT/tests/apply_fixture.py" coffee "$f" >/dev/null
cat >> "$f/ontology/actions.yaml" <<'YAML'
  - name: wipeLoyalty
    description: Must never be run by an agent.
    entity: Customer
    kind: delete
    input:
      id: { type: uuid, required: true }
    roles: [manager, agent]
    agent: forbidden
YAML
if ( cd "$f" && python3 tools/wiki_lint.py >/dev/null 2>&1 ); then miss "wiki-lint accepted agent: forbidden with role agent"; fi
( cd "$f" && python3 tools/ontology_codegen.py --lang python --out gen/ontology_types.py >/dev/null \
  && python3 tools/ontology_codegen.py --lang ts --out src/generated/ontology.ts >/dev/null )
verdict=$(cd "$f/gen" && python3 -B -c "
import ontology_types as o
a = next(x for x in o.ACTIONS if x.name == 'wipeLoyalty')
print(o.can('agent', a), o.can('manager', a))")
[ "$verdict" = "False True" ] || miss "python can(): agent, manager on a forbidden action gave '$verdict'"
grep -q '=== "agent" && action.agent === "forbidden"' "$f/src/generated/ontology.ts" || miss "ts can() ignores agent: forbidden"
echo "ok  agent: forbidden (or misses reported above)"

# 21. doctor: a hollow policy or pipeline does not score, and a local score says it is local
h="$TMP/python-team-agents"; mkdir -p "$h" && git -C "$h" init -q -b main
python3 "$S/apply.py" --target "$h" --preset python --level team --with github-agents --var project_name=H --var description=x --var owner=acme >/dev/null
git -C "$h" add -A
local_only=$(python3 "$S/doctor.py" --target "$h" --json | json 'd.get("local_only")')
[ "$local_only" = True ] || miss "doctor does not flag a score without GitHub checks: $local_only"
python3 "$S/doctor.py" --target "$h" | grep 'GitHub protection was not checked' >/dev/null || miss "doctor text does not warn about local-only score"
printf 'high:\n  - nothing\n' > "$h/governance/autonomy.yaml"
printf 'on: push\n# claude-code-action test check\n' > "$h/.github/workflows/pr-pipeline.yml"
( cd "$h" && python3 tools/autonomy.py --write-codeowners >/dev/null; git add -A )
failed=$(python3 "$S/doctor.py" --target "$h" --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
case ",$failed," in *,autonomy_policy,*) ;; *) miss "doctor accepted a hollow autonomy policy: $failed" ;; esac
case ",$failed," in *,agent_workflows,*) ;; *) miss "doctor accepted a hollow PR pipeline: $failed" ;; esac
echo "ok  doctor honesty (or misses reported above)"

# 22. gitleaks: manifest file hashes are allowed, narrowly; the config itself is high-tier
leak_cfg() {
  python3 - "$1/.gitleaks.toml" <<'PY'
import re, sys, tomllib
cfg = tomllib.load(open(sys.argv[1], "rb"))
assert cfg["extend"]["useDefault"] is True, "default rules must stay on"
[rule] = cfg["allowlists"]
assert rule["condition"] == "AND", "path and value must both match"
assert any(re.search(p, ".repo-setup.json") for p in rule["paths"])
assert not any(re.search(p, "src/.repo-setup.json") or re.search(p, "config.json") for p in rule["paths"])
good, bad = "5aa89fea883d6eb806a0008bafafd84b27481aac169c51ae78e1ce81e57de9e3", "sk_live_" + "a" * 40
assert any(re.search(p, good) for p in rule["regexes"])
assert not any(re.search(p, bad) or re.search(p, good + "x") for p in rule["regexes"])
PY
}
leak_cfg "$TMP/fastapi-team" 2>/dev/null || miss "team repo has no narrow gitleaks allowlist for manifest hashes"
[ ! -e "$TMP/fastapi-starter/.gitleaks.toml" ] || miss "starter repo got .gitleaks.toml without a gitleaks hook"
tier=$(cd "$g" && python3 tools/autonomy.py --files .gitleaks.toml | json 'd["tier"]')
[ "$tier" = high ] || miss "tier of .gitleaks.toml: $tier"
echo "ok  gitleaks allowlist (or misses reported above)"

# 23. github-agents: team alone has no agent workflows; the capability adds them
n="$TMP/team-no-agents"; mkdir -p "$n" && git -C "$n" init -q -b main
python3 "$S/apply.py" --target "$n" --preset python --level team --var project_name=N --var description=x --var owner=acme >/dev/null
[ ! -e "$n/.github/workflows/pr-pipeline.yml" ] || miss "team without agents got pr-pipeline.yml"
[ ! -e "$n/.github/ISSUE_TEMPLATE/intent.yml" ] || miss "team without agents got intent.yml"
[ -e "$n/governance/autonomy.yaml" ] || miss "team lost the autonomy policy"
git -C "$n" add -A
failed=$(python3 "$S/doctor.py" --target "$n" --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
[ "$failed" = lockfile ] || miss "team without agents: doctor failures: $failed"
y="$TMP/team-agents"; mkdir -p "$y" && git -C "$y" init -q -b main
python3 "$S/apply.py" --target "$y" --preset python --level team --with github-agents --var project_name=Y --var description=x --var owner=acme >/dev/null
[ -e "$y/.github/workflows/pr-pipeline.yml" ] || miss "github-agents did not add pr-pipeline.yml"
rm -f "$y/.github/workflows/agent-implement.yml" "$y/.github/workflows/pr-pipeline.yml"; git -C "$y" add -A
failed=$(python3 "$S/doctor.py" --target "$y" --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
case ",$failed," in *,agent_workflows,*) ;; *) miss "doctor did not notice missing agent workflows: $failed" ;; esac
if python3 "$S/apply.py" --target "$TMP/bad-agents" --preset python --level starter --with github-agents --var project_name=B --var description=x --var owner=a >/dev/null 2>&1; then miss "github-agents accepted at starter"; fi
o2="$TMP/old-team"; mkdir -p "$o2/.github/workflows" && git -C "$o2" init -q -b main
printf 'name: PR pipeline\n' > "$o2/.github/workflows/pr-pipeline.yml"
python3 "$S/apply.py" --target "$o2" --preset python --level team --var project_name=O --var description=x --var owner=a >/dev/null
[ -e "$o2/.github/workflows/pr-pipeline.yml" ] || miss "apply removed an existing pr-pipeline.yml"
steps() { ( cd "$1" && python3 -B -c "
import json,sys; sys.path.insert(0,'tools')
import github_setup as g
print(json.dumps(g.plan('o/r','main','@a',agents=$2)))" ); }
steps "$n" False | python3 -c "import json,sys; d=json.load(sys.stdin); w=[x['what'] for x in d]; r=[x for x in d if 'ruleset' in x][0]; c=[k['context'] for k in r['ruleset']['rules'][-1]['parameters']['required_status_checks']]; assert c==['check','secret-scan'],c; assert not any('label' in a for a in w),w; assert not any('approve' in a for a in w),w; assert not any('REPO_SETUP_MARKETPLACE' in a for a in w),w" || miss "github_setup without agents"
steps "$n" True | python3 -c "import json,sys; d=json.load(sys.stdin); r=[x for x in d if 'ruleset' in x][0]; c=[k['context'] for k in r['ruleset']['rules'][-1]['parameters']['required_status_checks']]; assert c==['check','gate','secret-scan'],c" || miss "github_setup with agents"
( cd "$o2" && python3 -B -c "import sys; sys.path.insert(0,'tools'); import github_setup as g, pathlib; assert g.has_agents(pathlib.Path('.'))" ) || miss "old team repo not detected as having agents"
( cd "$n" && python3 -B -c "import sys; sys.path.insert(0,'tools'); import github_setup as g, pathlib; assert not g.has_agents(pathlib.Path('.'))" ) || miss "team repo wrongly detected as having agents"
echo "ok  github-agents (or misses reported above)"

# 24. capability ai: env keys, evals outside make check, valid tiers, no browser stacks
for stack in python ts-node; do
  a="$TMP/ai-$stack"; mkdir -p "$a" && git -C "$a" init -q -b main
  python3 "$S/apply.py" --target "$a" --preset "$stack" --with ai --var project_name=Ai --var description=x --var owner=acme >/dev/null 2>&1 || miss "ai: apply failed on $stack"
  grep -q '^CLAUDE_MODEL=' "$a/.env.example" 2>/dev/null && grep -q '^ANTHROPIC_API_KEY=$' "$a/.env.example" && grep -q '^APP_ENV=' "$a/.env.example" || miss "ai: .env.example on $stack"
  [ -f "$a/evals/tasks.json" ] && grep -q '^eval:' "$a/mk/ai.mk" 2>/dev/null || miss "ai: eval parts on $stack"
  if grep -qE '^CHECK_TARGETS.*eval' "$a/mk/ai.mk" 2>/dev/null; then miss "ai: eval joined make check on $stack"; fi
  [ "$(python3 -c "import json;print(len(json.load(open('$a/evals/tasks.json'))))" 2>/dev/null || echo 0)" -ge 5 ] || miss "ai: fewer than 5 eval tasks on $stack"
done
if python3 "$S/apply.py" --target "$TMP/bad-tier" --preset python --with ai --var ai_tier=magic --var project_name=B --var description=x --var owner=a >/dev/null 2>&1; then miss "bad ai_tier accepted"; fi
if python3 "$S/apply.py" --target "$TMP/ai-browser" --preset react-vite --with ai --var project_name=B --var description=x --var owner=a >/dev/null 2>&1; then miss "ai accepted on a browser stack"; fi
for tier in call workflow agent; do
  t="$TMP/ai-tier-$tier"; mkdir -p "$t" && git -C "$t" init -q -b main
  python3 "$S/apply.py" --target "$t" --preset python --with ai --var ai_tier=$tier --var project_name=T --var description=x --var owner=acme >/dev/null || miss "ai: tier $tier failed"
  if [ "$tier" = call ]; then [ ! -e "$t/src/t/triage.py" ] || miss "tier call got triage.py"; else [ -e "$t/src/t/triage.py" ] || miss "tier $tier lacks triage.py"; fi
done
g2="$TMP/ai-tier-agent"
python3 -c "import json;d=json.load(open('$g2/.repo-setup.json'));assert 'mcp' in d['capabilities'],d['capabilities']" || miss "agent tier did not bring mcp"
( cd "$g2" && python3 tools/wiki_lint.py >/dev/null ) || miss "agent tier sample ontology fails wiki-lint"
[ ! -e "$TMP/ai-tier-call/ontology/actions.yaml" ] || miss "call tier got the sample ontology"
grep -q 'purgeNotes' "$g2/ontology/actions.yaml" 2>/dev/null || miss "agent tier lacks the sample ontology"
echo '{}' > "$g2/uv.lock"; git -C "$g2" add -A
python3 "$S/doctor.py" --target "$g2" --json | json '[r["id"] for r in d["failed"]]' | grep ai_agent_bounded >/dev/null && miss "doctor rejects an intact agent"
subst 's/MAX_ITERATIONS/MAX_TURNS/g' "$g2/src/t/agent.py" 2>/dev/null || true; git -C "$g2" add -A
python3 "$S/doctor.py" --target "$g2" --json | json '[r["id"] for r in d["failed"]]' | grep ai_agent_bounded >/dev/null || miss "doctor missed an agent without a turn limit"
python3 "$S/doctor.py" --target "$TMP/ai-tier-call" --json | json '[r["id"] for r in d["failed"]+d["passed"] if isinstance(r,dict)]+d["passed"]' | grep ai_agent_bounded >/dev/null && miss "call tier is checked for an agent limit"
echo "ok  ai capability (or misses reported above)"

# 25. blueprint: checked, mapped to apply.py, blocks unfinished work, drift only warns
B="$ROOT/tests/fixtures/blueprints"
bp="$S/blueprint.py"
python3 "$bp" check "$B/ok.yaml" >/dev/null 2>&1 || miss "blueprint: ok rejected"
if python3 "$bp" check "$B/bad-value.yaml" >/dev/null 2>&1; then miss "blueprint: bad value accepted"; fi
deps=$(python3 "$bp" dependents ai 2>/dev/null || true)
case " $deps " in *stack*domain*) ;; *) miss "blueprint: dependents of ai: $deps" ;; esac
x="$TMP/bp-ok"; mkdir -p "$x" && git -C "$x" init -q -b main
mapped=$(python3 "$S/apply.py" --target "$x" --from-blueprint "$B/ok.yaml" --json 2>/dev/null | json 'd["preset"]+"/"+d["level"]+"/"+",".join(d["capabilities"])' 2>/dev/null || true)
[ "$mapped" = python/starter/ai ] || miss "blueprint: wrong mapping: $mapped"
y2="$TMP/bp-pending"; mkdir -p "$y2"
if python3 "$S/apply.py" --target "$y2" --from-blueprint "$B/pending.yaml" >/dev/null 2>&1; then miss "blueprint: pending applied"; fi
[ -z "$(ls -A "$y2")" ] || miss "blueprint: pending wrote files"
python3 "$S/apply.py" --target "$y2" --from-blueprint "$B/ok-designing.yaml" --dry-run >/dev/null 2>&1 || miss "blueprint: designing dry-run refused"
if python3 "$S/apply.py" --target "$y2" --from-blueprint "$B/ok-designing.yaml" >/dev/null 2>&1; then miss "blueprint: designing applied"; fi
[ -z "$(ls -A "$y2")" ] || miss "blueprint: designing wrote files"
if python3 "$S/apply.py" --target "$y2" --from-blueprint "$B/ok.yaml" --preset fastapi >/dev/null 2>&1; then miss "blueprint: mixed with preset flags"; fi
if [ -f "$x/.repo-setup.json" ]; then
  cp "$B/ok.yaml" "$x/setup-blueprint.yaml"; git -C "$x" add -A
  drift=$(python3 "$S/doctor.py" --target "$x" --json | json 'd.get("blueprint_drift")')
  [ "$drift" = "[]" ] || miss "blueprint: false drift: $drift"
  python3 "$S/doctor.py" --target "$x" --json | json 'd["manual_steps"]' | grep 'Add a database' >/dev/null || miss "blueprint: manual steps not listed"
  before=$(python3 "$S/doctor.py" --target "$x" --json | json 'd["score"]')
  python3 - "$x/.repo-setup.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["level"]="team"; json.dump(d,open(p,"w"))
PY
  python3 "$S/doctor.py" --target "$x" --json | json 'len(d["blueprint_drift"])' | grep -v '^0$' >/dev/null || miss "blueprint: drift not reported"
  printf 'status: [' > "$x/setup-blueprint.yaml"
  python3 "$S/doctor.py" --target "$x" --json >/dev/null 2>&1 || miss "blueprint: broken file crashed doctor"
fi
echo "ok  blueprint (or misses reported above)"

# 26. new: layers, references, language rule, Vietnamese names, old Python
SK="$ROOT/plugins/repo-setup/skills/new"
for l in context repo architecture ai stack domain design quality delivery governance; do
  [ -f "$SK/references/layers/$l.md" ] || miss "layer file missing: $l"
  for w in "Framing" "automated" "Recommendation"; do grep -q "$w" "$SK/references/layers/$l.md" 2>/dev/null || miss "layer $l lacks: $w"; done
done
# 26a. the build step and docs describe the design layer
sed -n 's/^description: //p' "$SK/SKILL.md" | grep 'context, repo strategy, architecture, AI in the product, stack, domain, design, quality, delivery, agents' >/dev/null \
  || miss "new: description does not list the layers in layers.toml order"
grep -q 'design/terms.json' "$SK/SKILL.md" && grep -q 'docs_language' "$SK/SKILL.md" || miss "SKILL.md build step lacks design/terms.json and docs_language"
awk '/^## 6\./{f=1;next} /^## 7\./{f=0} f' "$SK/SKILL.md" | grep 'design/terms.json' >/dev/null || miss "SKILL.md step 6 lacks design/terms.json"
grep -q 'src/example' "$SK/references/tour.md" || miss "tour.md lacks src/example"
grep -q 'ten layers' "$ROOT/plugins/repo-setup/README.md" || miss "plugin README lacks: ten layers"
grep '`react-vite`' "$SK/references/layers/stack.md" | grep 'design' >/dev/null || miss "stack.md react-vite row lacks design"
# 26b. design layer: choices, colours, mapping to apply.py
python3 "$bp" check "$B/design.yaml" >/dev/null || miss "design.yaml should be valid"
args=$(python3 -c "
import sys; sys.path.insert(0, '$S'); import blueprint
from pathlib import Path
print(' '.join(blueprint.to_apply_args(blueprint.load(Path('$B/design.yaml')))))")
for w in "--with design" "design_surface=tool" "brand_primary=#0246ff" "locale=vi-VN" "currency=VND"; do
  case "$args" in *"$w"*) ;; *) miss "blueprint args lack: $w" ;; esac
done
python3 - "$S" <<'PY' || miss "colour rules"
import sys; sys.path.insert(0, sys.argv[1]); import blueprint as b
assert round(b.contrast_ratio("#0246ff", "#ffffff"), 2) == 6.32
assert b.readable_on("#0246ff") == "#ffffff" and b.readable_on("#ffba00") == "#0a0a0a"
assert b.brand_errors("#0246FF") == []
for bad in ("#ffba00", "#FFF", "blue", None, ""):
    assert b.brand_errors(bad), bad
PY
bad_design() { python3 - "$B/design.yaml" "$TMP/dv.yaml" "$1" "$2" <<'PY'
import sys
src, dst, old, new = sys.argv[1:]
t = open(src, encoding="utf-8").read()
assert old in t, old
open(dst, "w", encoding="utf-8").write(t.replace(old, new, 1))
PY
  if python3 "$bp" check "$TMP/dv.yaml" >/dev/null 2>&1; then miss "design: accepted $3"; fi
}
bad_design 'surface: tool' 'surface: magazine' "an unknown surface"
bad_design 'base: shadcn' 'base: bootstrap' "an unbuilt base marked automated"
bad_design 'preset: react-vite' 'preset: python' "a stack without a screen"
bad_design 'brand_primary: "#0246ff"' 'brand_primary: #0246ff' "an unquoted colour"
bad_design 'locale: vi-VN' 'locale: vietnamese' "an invalid locale"
bad_design 'currency: VND' 'currency: dong' "an invalid currency"
python3 - "$B/design.yaml" "$TMP/dna.yaml" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
start = t.index("  design:\n"); end = t.index("  quality:\n")
open(sys.argv[2], "w", encoding="utf-8").write(t[:start] + "  design:\n    status: not_applicable\n" + t[end:])
PY
out=$(python3 "$bp" check "$TMP/dna.yaml" 2>&1) && miss "design: not_applicable accepted for a stack with a screen"
case "$out" in *"automation manual"*) ;; *) miss "design not_applicable: unclear message: $out" ;; esac
python3 - "$B/design.yaml" "$TMP/dman.yaml" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
old = "    automation: automated\n    choice:\n      base: shadcn"
assert old in t
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(old, "    automation: manual\n    choice:\n      base: company"))
PY
python3 "$bp" check "$TMP/dman.yaml" >/dev/null || miss "design: a manual base with a why should be valid"
args=$(python3 -c "
import sys; sys.path.insert(0, '$S'); import blueprint
from pathlib import Path
print(' '.join(blueprint.to_apply_args(blueprint.load(Path('$TMP/dman.yaml')))))")
case "$args" in *design*) miss "design: a manual base still gives --with design: $args" ;; esac
grep -E 'needs_review' "$SK/SKILL.md" | grep 'not_applicable' >/dev/null || miss "needs_review ignores not_applicable layers"
for f in "$ROOT"/plugins/repo-setup/skills/*/SKILL.md; do [ "$(wc -l < "$f")" -lt 500 ] || miss "too long: $f"; done
grep -q 'references/critic.md' "$SK/SKILL.md" && grep -q 'references/tour.md' "$SK/SKILL.md" && grep -q 'from-blueprint' "$SK/SKILL.md" || miss "new does not use its references"
grep -qi 'really need an agent' "$SK/references/layers/ai.md" 2>/dev/null || miss "ai layer does not ask whether an agent is needed"
if grep -q 'make every technical choice for them' "$SK/SKILL.md"; then miss "new still decides everything alone"; fi
v="$TMP/viet"; mkdir -p "$v"
slug=$(python3 "$S/apply.py" --target "$v" --preset python --var 'project_name=Quán Cà Phê Đông' --var description=x --var owner=a --dry-run --json | json '[c for c in d["created"] if c.startswith("src/")][0].split("/")[1]')
[ "$slug" = quan_ca_phe_dong ] || miss "Vietnamese project name gives package: $slug"
python3 - "$ROOT/plugins/repo-setup" <<'PY' || miss "Vietnamese text or non-ASCII path inside the plugin"
import pathlib, re, sys
vi = re.compile("[ăâđêôơưàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ]", re.I)
bad = []
for p in pathlib.Path(sys.argv[1]).rglob("*"):
    if p.is_file():
        if not str(p.relative_to(sys.argv[1])).isascii():
            bad.append(str(p))
        elif "__pycache__" not in p.parts and vi.search(p.read_text("utf-8", "ignore")):
            bad.append(str(p))
print(*bad, sep="\n")
sys.exit(1 if bad else 0)
PY
la="$TMP/lang"; mkdir -p "$la"
python3 "$S/apply.py" --target "$la" --preset python --var project_name=L --var description=x --var owner=a --var conversation_language=vi --var docs_language=en >/dev/null
grep -q '^## Language' "$la/AGENTS.md" && grep -q 'Conversation: vi' "$la/AGENTS.md" && grep -q 'Documents: en' "$la/AGENTS.md" || miss "AGENTS.md lacks the language rule"
( cd "$la" && python3 tools/ledgers.py draw >/dev/null 2>&1 )   # the glossary is drawn from its fragments
grep -q 'Display name' "$la/ontology/glossary.md" || miss "glossary lacks a display name column"
git -C "$la" init -q -b main; git -C "$la" add -A
python3 "$S/doctor.py" --target "$la" --json | json '",".join(r["id"] for r in d["failed"])' | grep language_policy >/dev/null && miss "doctor rejects the language section"
old=/usr/bin/python3
if [ -x "$old" ] && ! "$old" -c 'import tomllib' 2>/dev/null; then
  for script in apply doctor; do
    msg=$("$old" "$S/$script.py" --help 2>&1 || true)
    case "$msg" in *"Python 3.11"*) ;; *) miss "old Python: unfriendly error from $script: $msg" ;; esac
  done
fi
echo "ok  new layers (or misses reported above)"

# 27. docs: real marketplace name, Vietnamese README, honest wording, plugin folder validated
if grep -q 'your-org/repo-standards' "$ROOT/README.md"; then miss "README still says your-org"; fi
grep -q 'phanlemanh/repo-standards' "$ROOT/README.md" || miss "README lacks the real marketplace"
[ -f "$ROOT/README.vi.md" ] || miss "README.vi.md missing"
grep -q 'README.vi.md' "$ROOT/README.md" || miss "README does not link the Vietnamese version"
E="$ROOT/plugins/repo-setup/skills/explain/SKILL.md"
for t in pyproject.toml .coveragerc .gitleaks.toml setup-blueprint.yaml evals/ START-HERE.md; do grep -q "$t" "$E" || miss "explain lacks: $t"; done
if grep -q 'hidden from logs and from AI agents automatically' "$E"; then miss "explain overclaims pii"; fi
if grep -qi 'real guardrails\|Rào chắn thật' "$ROOT/plugins/repo-setup/README.md"; then miss "plugin README overclaims guardrails"; fi
grep -q 'plugin validate plugins/repo-setup' "$ROOT/.github/workflows/test.yml" || miss "CI does not validate the plugin folder"
echo "ok  docs (or misses reported above)"

# 28. review findings: old team repos keep agents, blueprint values, labels, auto-merge
r1="$TMP/old-with-agents"; mkdir -p "$r1" && git -C "$r1" init -q -b main
python3 "$S/apply.py" --target "$r1" --preset python --level team --with github-agents --var project_name=R --var description=x --var owner=a >/dev/null
python3 - "$r1/.repo-setup.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["capabilities"]=[]; json.dump(d,open(p,"w"))
PY
out=$(python3 "$S/apply.py" --target "$r1" --json)
echo "$out" | json '"\n".join(d["notes"])' | grep github-agents >/dev/null || miss "re-apply: no notice about kept agents"
grep -q '## AI-native SDLC' "$r1/AGENTS.md" || miss "re-apply dropped the agent rules while workflows remain"
python3 -c "import json;assert 'github-agents' in json.load(open('$r1/.repo-setup.json'))['capabilities']" || miss "re-apply did not record github-agents"
variant() { python3 - "$B/ok.yaml" "$TMP/variant.yaml" "$1" "$2" <<'PY'
import sys
src, dst, old, new = sys.argv[1:]
t = open(src, encoding="utf-8").read()
assert old in t, old
open(dst, "w", encoding="utf-8").write(t.replace(old, new, 1))
PY
}
variant '{ai_tier: call}' '{ai_tier: magic}'
if python3 "$bp" check "$TMP/variant.yaml" >/dev/null 2>&1; then miss "blueprint: unknown ai_tier accepted"; fi
variant '{ai_tier: call}' '{ai_tier: agent, agent_runtime: agent-sdk}'
if python3 "$bp" check "$TMP/variant.yaml" >/dev/null 2>&1; then miss "blueprint: agent-sdk marked automated"; fi
variant '{ai_tier: call}' '{ai_tier: agent, agent_runtime: tool-runner}'
python3 "$bp" check "$TMP/variant.yaml" >/dev/null 2>&1 || miss "blueprint: tool-runner rejected"
variant '    automation: automated
    choice: {level: starter}' '    choice: {level: starter}'
if python3 "$bp" check "$TMP/variant.yaml" >/dev/null 2>&1; then miss "blueprint: decided layer without automation accepted"; fi
grep -E 'coverage threshold' "$SK/references/layers/quality.md" | grep '`partial`' >/dev/null || miss "quality: mixed option must be partial"
grep -E '^\| Monorepo' "$SK/references/layers/repo.md" | grep '`partial`' >/dev/null || miss "repo: monorepo must be partial"
grep -E 'Custom tiers' "$SK/references/layers/governance.md" | grep '`partial`' >/dev/null || miss "governance: custom tiers must be partial"
grep -q 'tests' "$SK/SKILL.md" && grep -qi 'sample tests' "$SK/SKILL.md" || miss "new forgets the sample tests when replacing the ontology"
steps "$n" False | grep allow_auto_merge >/dev/null && miss "github_setup changes auto-merge without agents"
echo "ok  review findings (or misses reported above)"

# 29. setup only: the plugin stops at setup; generated repos own their procedures
PL="$ROOT/plugins/repo-setup"
actual=$(ls "$PL/skills" | sort | tr '\n' ' ')
[ "$actual" = "adopt doctor explain github new " ] || miss "plugin skills are not setup only: $actual"
for s in adopt doctor explain github new; do grep -q "^name: $s$" "$PL/skills/$s/SKILL.md" 2>/dev/null || miss "skill folder and name differ: $s"; done
old=$(grep -rIlE 'setup-(new|adopt|doctor|explain)|sdlc-github-setup' "$PL" "$ROOT/README.md" "$ROOT/README.vi.md" "$ROOT/tests/fixtures" || true)
[ -z "$old" ] || miss "old skill names remain: $old"
[ ! -e "$PL/hooks" ] || miss "plugin still ships hooks"
[ ! -e "$PL/agents" ] || miss "plugin still ships subagents"
ls "$PL"/scripts/hook_*.py >/dev/null 2>&1 && miss "plugin still ships hook scripts"
stale=$(grep -rIlE 'repo-setup:(sdlc-(run|spec|implement|review)|ontology-add|wiki-)|sdlc-(run|spec|implement|review)|code-reviewer|security-reviewer|hook_(stop|session|pretool)|Stop hook|PreToolUse|REPO_SETUP_(APPROVAL|MARKETPLACE|HOOKS)|plugin_marketplaces' "$PL" "$ROOT/README.md" "$ROOT/README.vi.md" || true)
[ -z "$stale" ] || miss "references to removed runtime: $stale"
v="$TMP/setup-only"; mkdir -p "$v" && git -C "$v" init -q -b main
python3 "$S/apply.py" --target "$v" --preset python --var project_name=V --var description=x --var owner=acme >/dev/null
for s in ontology-add wiki-ingest wiki-query wiki-health review-change; do
  grep -q "^name: $s$" "$v/.claude/skills/$s/SKILL.md" 2>/dev/null || miss "generated repo lacks the $s procedure"
done
for word in 'pii: true' 'gitleaks' 'pull_request_target' 'autonomy.py' 'Do not edit'; do
  grep -q "$word" "$v/.claude/skills/review-change/SKILL.md" 2>/dev/null || miss "review-change does not cover: $word"
done
grep -q '/review-change' "$v/CLAUDE.md" || miss "CLAUDE.md does not point to the generated procedures"
if grep -qi 'hook' "$v/CLAUDE.md"; then miss "CLAUDE.md still promises hooks"; fi
u="$TMP/setup-only-agents"; mkdir -p "$u" && git -C "$u" init -q -b main
python3 "$S/apply.py" --target "$u" --preset python --level team --with github-agents --var project_name=U --var description=x --var owner=acme >/dev/null
grep -q '.claude/skills/review-change/SKILL.md' "$u/.github/workflows/pr-pipeline.yml" || miss "pr-pipeline does not use the repo's review procedure"
if grep -qE '^ +plugins:' "$u"/.github/workflows/*.yml; then miss "agent workflows still install the plugin"; fi
grep -q 'page-types.yaml' "$u/AGENTS.md" || miss "AGENTS.md lost the spec format"
if python3 "$u/tools/github_setup.py" --help | grep marketplace >/dev/null; then miss "github_setup still sets a marketplace for CI"; fi
grep -q 'phanlemanh/delivery-loop' "$ROOT/README.md" || miss "README does not say where the feature loop lives"
echo "ok  setup only (or misses reported above)"

# 30. PR pipeline: bots can be reviewed, review runs no PR code, the gate runs no PR code
g="$TMP/gate-repo"; mkdir -p "$g" && git -C "$g" init -q -b main
python3 "$S/apply.py" --target "$g" --preset python --level team --with github-agents --var project_name=G --var description=x --var owner=a >/dev/null
pipeline="$g/.github/workflows/pr-pipeline.yml"
review=$(sed -n '/^  review:$/,/^  automerge:$/p' "$pipeline")
grep -q 'allowed_bots: "claude\[bot\]"' <<<"$review" || miss "review rejects PRs opened by claude[bot]"
if grep -q "allowed_bots: *['\"]\*" "$pipeline"; then miss "pipeline allows every bot"; fi
if grep -q 'setup-project' <<<"$review"; then miss "review installs the PR's dependencies"; fi
if grep -q 'Bash(make:' <<<"$review"; then miss "review may run make from the PR"; fi
grep -q -- '--strict-mcp-config' <<<"$review" || miss "review may start MCP servers from the PR"
grep -qF -- "--settings '{\"disableAllHooks\": true}'" <<<"$review" || miss "review may run the PR's hooks (SessionStart runs make from the PR)"
grep -q 'Bash(gh pr checks:' <<<"$review" || miss "review cannot read the CI result"
grep -q 'checks: read' <<<"$review" || miss "review lacks permission to read checks"
skill="$g/.claude/skills/review-change/SKILL.md"
grep -q 'In CI' "$skill" || miss "review-change does not say what to skip in CI"
git -C "$g" add -A && git -C "$g" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -qm base
git -C "$g" update-ref refs/remotes/origin/main main
git -C "$g" switch -qc pr
mkdir -p "$g/.gate"
printf 'import os\nopen(os.environ["TRAP"], "w").write("ran")\n' > "$g/.gate/yaml.py"
cp "$g/.gate/yaml.py" "$g/yaml.py"
cat "$g/.gate/yaml.py" "$g/tools/autonomy.py" > "$g/tools/autonomy.py.new" && mv "$g/tools/autonomy.py.new" "$g/tools/autonomy.py"
git -C "$g" add -A && git -C "$g" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -qm pr
steps_of() { python3 - "$pipeline" "$1" <<'PY_STEP'
import sys
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
start = next(i for i, l in enumerate(lines) if sys.argv[2] in l and "- name:" in l)
run = next(i for i in range(start, len(lines)) if lines[i].strip() == "run: |")
indent = len(lines[run]) - len(lines[run].lstrip()) + 2
for l in lines[run + 1:]:
    if l.strip() and len(l) - len(l.lstrip()) < indent:
        break
    print(l[indent:])
PY_STEP
}
gate_run() { # base-branch rules present or removed: $1 = output file
  ( cd "$g" && TRAP="$TMP/trap" RUNNER_TEMP="$TMP/runner" GITHUB_WORKSPACE="$g" GITHUB_OUTPUT="$1" \
    GITHUB_STEP_SUMMARY="$TMP/summary" BASE=main AUTHOR=someone UPDATE_TYPE="" \
    bash -e -c "$(steps_of 'Load the rules from the base branch'; steps_of 'Classify')" ) >/dev/null 2>&1
}
mkdir -p "$TMP/runner"; rm -f "$TMP/trap"
gate_run "$TMP/gate.out" || miss "gate failed on a pull request with a planted .gate/yaml.py"
[ ! -e "$TMP/trap" ] || miss "gate ran code from the pull request"
grep -q '^tier=high$' "$TMP/gate.out" 2>/dev/null || miss "gate did not judge a tools/ change as high"
[ ! -e "$g/.gate/autonomy.py" ] || miss "gate copied its rules into the checkout"
git -C "$g" update-ref refs/remotes/origin/bare "$(git -C "$g" -c user.name=t -c user.email=t@t commit-tree -m none "$(git -C "$g" mktree </dev/null)")"
rm -f "$TMP/gate2.out" "$TMP/trap"
( cd "$g" && TRAP="$TMP/trap" RUNNER_TEMP="$TMP/runner" GITHUB_WORKSPACE="$g" GITHUB_OUTPUT="$TMP/gate2.out" \
  GITHUB_STEP_SUMMARY="$TMP/summary" BASE=bare AUTHOR=someone UPDATE_TYPE="" \
  bash -e -c "$(steps_of 'Load the rules from the base branch'; steps_of 'Classify')" ) >/dev/null 2>&1 \
  || miss "gate failed when the base branch has no rules"
grep -q '^tier=high$' "$TMP/gate2.out" 2>/dev/null || miss "gate without base rules must be high"
[ ! -e "$TMP/trap" ] || miss "gate ran code from the pull request when the base has no rules"
echo "ok  pr pipeline (or misses reported above)"

# 31. design capability
for level in starter team; do
  d="$TMP/design-$level"; mkdir -p "$d"; git -C "$d" init -q -b main
  python3 "$S/apply.py" --target "$d" --preset react-vite --level "$level" --with design \
    --var 'project_name=Quán "Cà" \ Phê' --var description=x --var owner=acme \
    --var 'brand_primary=#0246ff' --var locale=vi-VN --var currency=VND --json >/dev/null \
    || miss "design: apply failed at $level"
  grep -q -- '--primary: #0246ff' "$d/src/index.css" || miss "design: brand block missing"
  [ "$(tail -6 "$d/src/index.css" | grep -c primary)" -ge 2 ] || miss "design: brand block must come last"
  grep -q 'lang="vi"' "$d/index.html" || miss "design: page language"
  # shadcn's destructive red fails 4.5:1 on its own 10% tint (badge, button); e2e pins it in the browser.
  grep -q -- '--destructive: oklch(0.48 0.2 27.325);' "$d/src/index.css" || miss "design: destructive token not darkened"
  grep -q '"vi-VN"' "$d/src/lib/format.ts" && grep -q '"VND"' "$d/src/lib/format.ts" || miss "design: locale"
  grep -qx 'CHECK_TARGETS += design-guards' "$d/mk/design.mk" && grep -qx 'HEAVY_TARGETS += ui-floor' "$d/mk/design.mk" \
    || miss "design: not in the gate"
  [ -f "$d/.mcp.json" ] && miss "design: must not add .mcp.json"
  # The measurement protocol cuts the capability at these exact lines.
  grep -qx ' *// design-floor:start' "$d/eslint.config.js" && grep -qx ' *// design-floor:end' "$d/eslint.config.js" \
    || miss "design: eslint markers missing"
  grep -qx '## Design floor' "$d/AGENTS.md" || miss "design: AGENTS section heading"
  again=$(python3 "$S/apply.py" --target "$d" --json | json 'len(d["created"])+len(d["updated"])+len(d["conflict"])') || again=-1
  [ "$again" -eq 0 ] || miss "design/$level: second run changed $again files"
done
grep -q 'src/components/ui' "$TMP/design-team/vitest.config.ts" || miss "design: team coverage counts vendor code"
# The table patch: runs after `shadcn add` and before `make format`, is safe to run twice,
# and stops loudly when the component no longer looks like the pinned version.
python3 - "$S/../capabilities/design/preset.toml" <<'PY' || miss "design: make ui-patch not run between shadcn add and make format"
import sys, tomllib
cmds = tomllib.load(open(sys.argv[1], "rb"))["starter"]["install"]
at = lambda word: next(i for i, c in enumerate(cmds) if word in c)
assert at("shadcn@4.23.0 add") < at("make ui-patch") < at("make format"), cmds
PY
# shadcn is read only at build time (its CLI, and shadcn/tailwind.css that Vite bundles): it goes
# under devDependencies, or `npm audit --omit=dev` in security.yml reports what it pulls in.
python3 - "$S/../capabilities/design/preset.toml" <<'PY' || miss "design: shadcn not installed with --save-dev"
import sys, tomllib
cmds = tomllib.load(open(sys.argv[1], "rb"))["starter"]["install"]
installs = [c.split() for c in cmds if c.startswith("npm install")]
with_shadcn = [c for c in installs if any(w.startswith("shadcn@") for w in c)]
assert with_shadcn and all("--save-dev" in c for c in with_shadcn), cmds
PY
d="$TMP/design-team"; mkdir -p "$d/src/components/ui"
cat > "$d/src/components/ui/table.tsx" <<'TSX'
function Table({ className, ...props }: React.ComponentProps<"table">) {
  return (
    <div
      data-slot="table-container"
      className="relative w-full overflow-x-auto"
    >
TSX
( cd "$d" && make -s ui-patch && cp src/components/ui/table.tsx "$TMP/table.once" && make -s ui-patch ) \
  || miss "design: patch_ui.mjs failed on the shadcn table"
grep -q 'role="region" aria-label={label} tabIndex={0}' "$d/src/components/ui/table.tsx" && grep -q '"aria-label": string' "$d/src/components/ui/table.tsx" \
  || miss "design: table scroll region not focusable and named after the patch"
cmp -s "$TMP/table.once" "$d/src/components/ui/table.tsx" || miss "design: patch_ui.mjs is not idempotent"
echo 'export {};' > "$d/src/components/ui/table.tsx"
out=$(cd "$d" && node tools/patch_ui.mjs 2>&1) && miss "design: patch_ui.mjs accepted an unknown table"
case "$out" in *"no longer matches"*) ;; *) miss "design: patch_ui.mjs failed without saying why: $out" ;; esac
rm -r "$d/src/components"
d="$TMP/design-plain"; python3 "$S/apply.py" --target "$d" --preset react-vite --with design \
  --var project_name=P --var description=x --var owner=a >/dev/null || miss "design: no brand must work"
grep -q 'brand' "$d/src/index.css" && miss "design: brand block without a brand"
d="$TMP/design-content"; python3 "$S/apply.py" --target "$d" --preset react-vite --with design --var design_surface=content \
  --var project_name=P --var description=x --var owner=a >/dev/null || miss "design: content surface apply failed"
grep -q 'TableRow' "$d/src/example/ReferenceScreen.tsx" && miss "design: content surface got the table screen"
grep -q 'variant: "destructive"' "$d/src/example/ReferenceScreen.tsx" || miss "design: content screen shows no destructive badge"
for v in default outline destructive; do
  grep -q "variant: \"$v\"" "$TMP/design-plain/src/example/ReferenceScreen.tsx" || miss "design: tool screen has no $v badge"
done
grep -q 'text-base' "$d/design/behaviors.md" || miss "design: content surface lacks its density"
grep -q 'text-sm' "$TMP/design-plain/design/behaviors.md" || miss "design: tool surface lacks its density"
if python3 "$S/apply.py" --target "$TMP/design-py" --preset fastapi --with design \
  --var project_name=P --var description=x --var owner=a >/dev/null 2>&1; then miss "design: stack without a screen accepted"; fi
if python3 "$S/apply.py" --target "$TMP/design-bad" --preset react-vite --with design --var 'brand_primary=red' \
  --var project_name=P --var description=x --var owner=a >/dev/null 2>&1; then miss "design: bad colour accepted"; fi
for bad in design_surface=magazine locale=vietnamese locale=vi_VN currency=dong currency=VN; do
  out=$(python3 "$S/apply.py" --target "$TMP/design-bad" --preset react-vite --with design --var "$bad" \
    --var project_name=P --var description=x --var owner=a 2>&1) && miss "design: --var $bad accepted"
  case "$out" in *"${bad%%=*} must"*) ;; *) miss "design: --var $bad refused without saying why: $out" ;; esac
done
[ ! -e "$TMP/design-bad/package.json" ] || miss "design: a bad --var still wrote files"
d="$TMP/design-starter"; git -C "$d" add -A
failed=$(python3 "$S/doctor.py" --target "$d" --level starter --json | json '",".join(sorted(r["id"] for r in d["failed"]))')
[ "$failed" = "design_guards_bite,lockfile" ] || miss "design doctor without install: $failed"
# 31a. dropping design from the manifest does not switch the checks off unseen
d="$TMP/design-plain"; git -C "$d" init -q -b main 2>/dev/null; git -C "$d" add -A
python3 - "$d/.repo-setup.json" <<'PY'
import json, sys
p = sys.argv[1]; m = json.load(open(p)); m["capabilities"].remove("design"); json.dump(m, open(p, "w"))
PY
detail=$(python3 "$S/doctor.py" --target "$d" --json | json '[r.get("detail","") for r in d["failed"] if r["id"]=="design_present"]')
case "$detail" in *"does not list design"*) ;; *) miss "doctor: design dropped from the manifest went unseen: $detail" ;; esac
# 31b. turning design on in an existing react-vite repo: the user's own stylesheet is kept, with a note
d="$TMP/design-later"; mkdir -p "$d/src"; git -C "$d" init -q -b main
python3 "$S/apply.py" --target "$d" --preset react-vite --var project_name=P --var description=x --var owner=a >/dev/null
echo 'body { margin: 0; }' > "$d/src/index.css"
notes=$(python3 "$S/apply.py" --target "$d" --with design --json | json '" ".join(d["notes"])+" kept="+",".join(d["kept"])')
case "$notes" in *"kept your own src/index.css"*"design tokens"*"by hand"*"kept=src/index.css"*) ;; *) miss "design later: no note about src/index.css: $notes" ;; esac
grep -q 'margin: 0' "$d/src/index.css" || miss "design later: own stylesheet overwritten"
d="$TMP/design-team"; echo "/* mine */" >> "$d/src/index.css"
notes=$(python3 "$S/apply.py" --target "$d" --json | json '" ".join(d["notes"])')
case "$notes" in *"src/index.css"*) miss "design: note for a stylesheet apply wrote itself: $notes" ;; esac
# 31c. adopt does not support design yet: apply refuses it, doctor does not score it
d="$TMP/design-adopt"; mkdir -p "$d"; git -C "$d" init -q -b main
out=$(python3 "$S/apply.py" --target "$d" --preset react-vite --adopt --with design \
  --var project_name=P --var description=x --var owner=a 2>&1) && miss "design: accepted under adopt"
case "$out" in *"adopt does not support the design capability yet"*) ;; *) miss "design under adopt: unclear refusal: $out" ;; esac
[ -z "$(ls -A "$d" | grep -v '^.git$' || true)" ] || miss "design under adopt: files written"
python3 "$S/apply.py" --target "$d" --preset react-vite --adopt --var project_name=P --var description=x --var owner=a >/dev/null \
  || miss "adopt react-vite without design failed"
if python3 "$S/apply.py" --target "$d" --with design >/dev/null 2>&1; then miss "design: added later to an adopted repo"; fi
git -C "$d" add -A
skip=$(python3 "$S/doctor.py" --target "$d" --json | json '[r.get("detail","") for r in d["skipped"] if r["id"]=="design_present"]')
case "$skip" in *"not applicable"*) ;; *) miss "doctor: design_present not skipped for an adopted repo: $skip" ;; esac
# 31d. doctor: the floor files must stay as apply wrote them
d="$TMP/design-starter"
floor() { python3 "$S/doctor.py" --target "$d" --level starter --json | json '[r.get("detail","")+" | "+r["fix"] for r in d["failed"] if r["id"]=="design_guards_bite"][0]'; }
case "$(floor)" in *"changed since apply"*) miss "design floor: fresh repo reported as changed" ;; esac
cp "$d/tests/e2e/floor.spec.ts" "$TMP/floor.bak"; echo "// weaker" >> "$d/tests/e2e/floor.spec.ts"
case "$(floor)" in *"changed since apply wrote them: tests/e2e/floor.spec.ts"*"Re-apply the design capability"*) ;;
  *) miss "design floor: edited floor.spec.ts not reported: $(floor)" ;; esac
cp "$TMP/floor.bak" "$d/tests/e2e/floor.spec.ts"
cp "$d/.repo-setup.json" "$TMP/manifest.bak"
python3 - "$d/.repo-setup.json" <<'PY'
import json, sys
p = sys.argv[1]; m = json.load(open(p)); del m["files"]["mk/design.mk"]; json.dump(m, open(p, "w"))
PY
case "$(floor)" in *"changed since apply"*) miss "design floor: no hash and the plugin copy reported as changed" ;; esac
cp "$d/mk/design.mk" "$TMP/mk.bak"; printf '\t-true\n' >> "$d/mk/design.mk"
case "$(floor)" in *"changed since apply wrote them: mk/design.mk"*) ;; *) miss "design floor: no hash, edit not caught against the plugin copy" ;; esac
python3 - "$d/.repo-setup.json" "$d/mk/design.mk" <<'PY'
import hashlib, json, sys
p, f = sys.argv[1:]; m = json.load(open(p))
m["files"]["mk/design.mk"] = hashlib.sha256(open(f, "rb").read()).hexdigest(); json.dump(m, open(p, "w"))
PY
case "$(floor)" in *"changed since apply"*) miss "design floor: compared with the plugin copy although a hash is recorded" ;; esac
cp "$TMP/mk.bak" "$d/mk/design.mk"; cp "$TMP/manifest.bak" "$d/.repo-setup.json"
# 31f. one registry of screens: the browser routes come from src/screens.ts
d="$TMP/design-team"
( cd "$d" && node tools/design_guards.mjs --only reference >/dev/null 2>&1 ) || miss "design reference: red on a fresh repo"
grep -q 'from "@/screens"' "$d/src/App.tsx" || miss "design: App.tsx does not read src/screens.ts"
ref_red() { # <file> <replacement content> <expected text>
  cp "$d/$1" "$TMP/ref.bak"; printf '%s\n' "$2" > "$d/$1"
  out=$(cd "$d" && node tools/design_guards.mjs --only reference 2>&1) && miss "design reference: stayed green with $1 = $2"
  case "$out" in *"$3"*) ;; *) miss "design reference: $1 went red for another reason: $out" ;; esac
  cp "$TMP/ref.bak" "$d/$1"
}
ref_red src/screens.ts 'export const SCREENS = [];' "src/screens.ts lists no screen path starting with /"
ref_red src/screens.ts $'// A path may name parts (`/orders/:id`), visit `/orders/1`.\nexport const SCREENS = [];' \
  "src/screens.ts lists no screen path starting with /"
ref_red tests/e2e/routes.ts 'export const ROUTES = ["/"];' "tests/e2e/routes.ts does not take its routes from src/screens.ts"
# 31g. one page for the builder: the rule holds the component steps and the traps, the skill is gone
[ ! -e "$d/.claude/skills/ui" ] || miss "design: the ui skill is still generated"
grep -q '^## Traps' "$d/.claude/rules/ui.md" && grep -q 'npx shadcn@4.23.0 add' "$d/.claude/rules/ui.md" \
  && grep -q 'design/behaviors.md' "$d/.claude/rules/ui.md" || miss "design: ui.md lacks its traps, the component steps or the behaviors pointer"
grep -q 'skills/ui' "$d/AGENTS.md" && miss "design: AGENTS.md still points to the ui skill"
ref_red .claude/rules/ui.md "$(seq 1 61)" ".claude/rules/ui.md has 61 lines, the limit is 60"
# 31h. states come from data: the reference screen loads from a source that can be slow, fail or
# find nothing; it takes no state prop and reads no address. Tests choose through the source.
for d in "$TMP/design-plain" "$TMP/design-content"; do
  f="$d/src/example/ReferenceScreen.tsx"
  grep -q 'from "@/example/data"' "$f" && grep -q 'useEffect' "$f" || miss "design: $f does not load from src/example/data.ts"
  grep -qE 'ScreenState|\{ state \}|location|URLSearchParams|scenario' "$f" && miss "design: $f picks its state from a prop or the address"
  for s in 'slow: "never"' 'fail: "fail"' 'empty: []' '"slow-delete": "never"' '"fail-delete": "fail"' \
    'get("scenario")' '!navigator.onLine' 'export function createItem' 'let items'; do
    grep -qF "$s" "$d/src/example/data.ts" || miss "design: $d/src/example/data.ts lacks $s"
  done
  # The test hook sits at the top of each request, apart from the request itself.
  [ "$(grep -c '^  if (test) return test;$' "$d/src/example/data.ts")" -eq 3 ] || miss "design: $d data.ts test hook not at the top of list, delete and create"
  # In the checks the hook also answers the normal path, so a real request never runs there.
  grep -q 'ready: items' "$d/src/example/data.ts" && grep -q '?? "ready"' "$d/src/example/data.ts" \
    || miss "design: $d data.ts hook does not answer the normal path in the checks"
  grep -q 'replace each function body' "$d/src/example/data.ts" && miss "design: $d data.ts tells the builder to delete the test hook"
  # The hook answers only in the checks' builds; nothing else in the source depends on the mode.
  grep -qF 'if (import.meta.env.MODE !== "test" && import.meta.env.MODE !== "floor") return null;' "$d/src/example/data.ts" \
    || miss "design: $d data.ts test hook is live outside the checks"
  [ "$(grep -c 'MODE' "$d/src/example/data.ts")" -eq 1 ] || miss "design: $d data.ts has a test-only branch besides the hook"
  grep -q 'onAction={addFirst}' "$f" && grep -q 'open={asking}' "$f" || miss "design: $f empty action does not add, or the dialog loses its item while closing"
done
grep -q 'findAllByText(shows)' "$TMP/design-team/tests/App.test.tsx" && grep -q 'findByRole("button"' "$TMP/design-team/tests/App.test.tsx" \
  || miss "design: the unit walk does not wait for each step and state"
d="$TMP/design-team"
grep -q 'scenario: "fail"' "$d/src/screens.ts" && grep -q 'steps: ' "$d/src/screens.ts" \
  && ! grep -qE '\?state|location' "$d/src/screens.ts" || miss "design: src/screens.ts does not reach states through the data source and the user"
grep -q 'getByRole("button", { name: step.press' "$d/tests/e2e/floor.spec.ts" && grep -q 'route.shows' "$d/tests/e2e/floor.spec.ts" \
  || miss "design: the browser floor does not drive the steps or wait for the state"
# The rule in full on both pages: what a real condition is and what a switch is.
for f in design/behaviors.md .claude/rules/ui.md; do
  text=$(tr -s ' \n' '  ' < "$d/$f")
  for s in 'A state appears because of a real condition: a pending or failed request, an empty result, a filter with no match, a user action.' \
    'Never because of a switch' 'a prop or URL value that exists only to pick the state'; do
    grep -qF "$s" <<<"$text" || miss "design: $f lacks the real-condition rule ($s)"
  done
done
grep -qi 'A state reachable only from a switch is not a state' "$d/.claude/rules/ui.md" || miss "design: ui.md traps lack the switch trap"
# 31i. the registry is enough on its own: paths with parts, the sample off the home page, the test
# files owned by the plugin, a guard message that agrees with the rule, no screenshots.
grep -q 'path: "/example"' "$d/src/screens.ts" && grep -q 'visit?: string' "$d/src/screens.ts" \
  && grep -q 'params: Params' "$d/src/screens.ts" || miss "design: src/screens.ts lacks the sample at /example or the visit and params shape"
grep -q 'LABELS.notFound' "$d/src/App.tsx" && grep -q 'SCREENS.map' "$d/src/App.tsx" \
  || miss "design: an unknown address does not get its own page with links to the screens"
grep -q 'url: "/no/such/page"' "$d/tests/e2e/routes.ts" || miss "design: the browser floor does not visit the not-found page"
grep -q 'ROUTES' "$d/tests/App.test.tsx" && ! grep -qE 'ReferenceScreen|example' "$d/tests/App.test.tsx" \
  || miss "design: tests/App.test.tsx is not a generic walk over the registry"
for f in tests/App.test.tsx tests/e2e/routes.ts tests/e2e/floor.spec.ts; do
  grep -qF "\`$f\`" "$d/.claude/rules/ui.md" || miss "design: ui.md does not say the plugin owns $f"
  grep -qF "\"$f\"" "$PL/checklists/top-tier.toml" || miss "design: doctor does not guard $f"
done
grep -q 'TableCell' "$d/.claude/rules/ui.md" && grep -q 'no screenshots' "$d/.claude/rules/ui.md" \
  || miss "design: ui.md lacks the TableCell trap or the no-screenshot line"
grep -q 'never edit src/components/ui' "$d/eslint.config.js" || miss "design: the restyle message still sends the builder into src/components/ui"
grep -q 'vite build --mode floor --outDir coverage/floor' "$d/playwright.config.ts" \
  || miss "design: the browser checks do not build in their own mode, apart from dist/"
grep -q '"src/example/\*\*"' "$d/vitest.config.ts" || miss "design: team coverage counts the sample"
# 31e. the gate check goes red when make could skip the guards or ignore their failure
d="$TMP/design-team"
( cd "$d" && node tools/design_guards.mjs --only gate >/dev/null 2>&1 ) || miss "design gate: red on a fresh repo"
gate_red() { # <file> <line to add, or "" to drop design-guards from the gate> <expected text>
  cp "$d/$1" "$TMP/gate.bak"
  if [ -n "$2" ]; then printf '%s\n' "$2" >> "$d/$1"; else subst 's/^CHECK_TARGETS += design-guards$/CHECK_TARGETS +=/' "$d/$1"; fi
  cmp -s "$TMP/gate.bak" "$d/$1" && miss "design gate: mutation '$2' did not change $1"
  out=$(cd "$d" && node tools/design_guards.mjs --only gate 2>&1) && miss "design gate: stayed green with '$2' in $1"
  case "$out" in *"$3"*) ;; *) miss "design gate: '$2' in $1 went red for another reason: $out" ;; esac
  cp "$TMP/gate.bak" "$d/$1"
}
gate_red mk/design.mk "" "make check does not run the design guards"
gate_red mk/design.mk ".IGNORE:" "mk/design.mk ignores errors with .IGNORE"
gate_red Makefile "MAKEFLAGS += -i" "Makefile ignores errors through MAKEFLAGS"
gate_red Makefile "MAKEFLAGS += --keep-going --ignore-errors" "Makefile ignores errors through MAKEFLAGS"
gate_red Makefile "export MAKEFLAGS += -i" "Makefile ignores errors through MAKEFLAGS"
printf '.PHONY: check\ncheck:\n\t@true\n' > "$d/GNUmakefile"
out=$(cd "$d" && node tools/design_guards.mjs --only gate 2>&1) && miss "design gate: stayed green with a GNUmakefile"
case "$out" in *"GNUmakefile exists: make reads it before Makefile"*) ;; *) miss "design gate: GNUmakefile went red for another reason: $out" ;; esac
rm -f "$d/GNUmakefile"
( cd "$d" && printf 'MAKEFLAGS += --no-print-directory\n' >> Makefile && node tools/design_guards.mjs --only gate >/dev/null 2>&1 ) \
  || miss "design gate: an unrelated MAKEFLAGS setting went red"
# Quiet steps: a silent recipe (@) still counts, an error-ignoring one (- in any order) does not.
for prefix in '@-' '-@'; do
  cp "$d/mk/design.mk" "$TMP/gate.bak"
  subst "s#^	@node tools/ui_select.mjs --run#	${prefix}node tools/ui_select.mjs --run#" "$d/mk/design.mk"
  cmp -s "$TMP/gate.bak" "$d/mk/design.mk" && miss "design gate: the $prefix mutation did not change mk/design.mk"
  out=$(cd "$d" && node tools/design_guards.mjs --only gate 2>&1) && miss "design gate: stayed green with ${prefix}node tools/ui_select.mjs --run"
  case "$out" in *"the browser step can no longer fail the gate"*) ;; *) miss "design gate: $prefix went red for another reason: $out" ;; esac
  cp "$TMP/gate.bak" "$d/mk/design.mk"
done
# make check is quiet: no echoed commands, no npm banners, one dot per test, coverage table in a file.
grep -q '^	@npm run --silent lint$' "$d/Makefile" && grep -q '^	@npm run --silent test$' "$d/Makefile" \
  && grep -q '^	@echo "make check passed' "$d/Makefile" || miss "quiet check: Makefile steps echo their commands"
grep -q 'prettier --check --log-level warn' "$d/package.json" || miss "quiet check: prettier prints on success"
grep -q 'reporter: "dot"' "$d/playwright.config.ts" && grep -q 'reporters: \["dot"\]' "$d/vite.config.ts" \
  && grep -q 'reporter: \["html", "json-summary"\]' "$d/vitest.config.ts" || miss "quiet check: a test step prints every test"
grep -q 'tsc --noEmit >&2' "$d/playwright.config.ts" || miss "quiet check: build errors hidden from the browser step"
python3 - "$ROOT/plugins/repo-setup" <<'PY' || miss "design checks wired wrongly"
import sys, tomllib, pathlib
checks = {c["id"]: c for c in tomllib.loads((pathlib.Path(sys.argv[1]) / "checklists/top-tier.toml").read_text())["check"]}
for k, mode in (("design_guards_bite", "guards"), ("design_floor_in_gate", "gate"), ("design_reference", "reference")):
    assert checks[k]["type"] == "command" and checks[k]["capabilities"] == ["design"] and mode in checks[k]["command"], k
assert checks["design_present"]["presets"] == ["react-vite"] and checks["design_present"]["weight"] == 3
PY
echo "ok  design capability (or misses reported above)"

# 32. claude-plugin: a working skeleton for a plugin marketplace, without app tooling
k="$TMP/plug"; mkdir -p "$k" && git -C "$k" init -q -b main
out=$(python3 "$S/apply.py" --target "$k" --preset claude-plugin --var 'project_name=Sample Kit' --var description=x --var owner=acme --json)
for f in .claude-plugin/marketplace.json plugins/sample-kit/.claude-plugin/plugin.json plugins/sample-kit/skills/hello/SKILL.md \
  tools/bump_version.py tools/plugin_lint.py .github/workflows/ci.yml .nvmrc Makefile tests/run.sh CHANGELOG.md AGENTS.md CLAUDE.md \
  .editorconfig .gitattributes .gitignore .claude/settings.json LICENSE README.md; do
  [ -f "$k/$f" ] || miss "claude-plugin: skeleton lacks $f"
done
for f in package.json tsconfig.json eslint.config.js .prettierrc.json .env.example pyproject.toml ontology wiki tools/wiki_lint.py \
  tools/ontology_codegen.py tools/repo_ontology.py .claude/skills/ontology-add .claude/skills/wiki-ingest src; do
  [ ! -e "$k/$f" ] || miss "claude-plugin: skeleton has app-shaped $f"
done
echo "$out" | json '"\n".join(n["what"]+": "+n["reason"] for n in d["not_applicable"])' > "$TMP/na.txt"
grep -q '^Domain ontology and project wiki: A plugin marketplace has no business domain to model' "$TMP/na.txt" || miss "claude-plugin: apply does not say why ontology and wiki are left out"
grep -q '^\.env\.example: ' "$TMP/na.txt" || miss "claude-plugin: apply does not say why .env.example is left out"
python3 "$S/apply.py" --target "$TMP/plug-dry" --preset claude-plugin --var project_name=P --var description=x --var owner=a --dry-run \
  | grep 'NOT APPLICABLE to a claude-plugin repository' >/dev/null || miss "claude-plugin: text output hides what is not applicable"
if grep -qiE 'ontology|wiki/|make gen|typecheck' "$k/AGENTS.md" "$k/CLAUDE.md" "$k/README.md" "$k/.claude/skills/review-change/SKILL.md"; then miss "claude-plugin: guides still talk about ontology, wiki or app tooling"; fi
grep -q '^## Language' "$k/AGENTS.md" || miss "claude-plugin: AGENTS.md lacks the language rule"
for t in setup lint test check; do grep -q "^$t:" "$k/Makefile" || miss "claude-plugin: Makefile lacks $t"; done
grep -q 'make check' "$k/.github/workflows/ci.yml" && grep -q 'make validate' "$k/.github/workflows/ci.yml" || miss "claude-plugin: CI does not run the checks and the validator"
[ "$(cat "$k/.nvmrc")" = 22 ] || miss "claude-plugin: Node version not pinned"
( cd "$k" && make check >/dev/null 2>&1 ) || miss "claude-plugin: make check fails on a fresh skeleton"
python3 "$S/apply.py" --list-options | json 'd["stacks"]["claude-plugin"]["description"]' | grep 'plugin marketplace' >/dev/null || miss "claude-plugin: not in --list-options"
( cd "$k" && python3 tools/bump_version.py minor >/dev/null ) || miss "claude-plugin: bump failed"
grep -q '"version": "0.2.0"' "$k/.claude-plugin/marketplace.json" && grep -q '"version": "0.2.0"' "$k/plugins/sample-kit/.claude-plugin/plugin.json" \
  || miss "claude-plugin: bump did not reach every manifest"
grep -q '^## 0\.2\.0 — ' "$k/CHANGELOG.md" && grep -q '^## Unreleased$' "$k/CHANGELOG.md" || miss "claude-plugin: bump did not date the changelog"
[ "$(cd "$k" && python3 tools/bump_version.py --notes 0.2.0)" = "- Repository skeleton with one sample plugin." ] || miss "claude-plugin: --notes does not print the section"
( cd "$k" && make check >/dev/null 2>&1 ) || miss "claude-plugin: make check fails after a bump"
# The bump edited files the plugin wrote; their templates did not change, so nothing is merged.
again=$(python3 "$S/apply.py" --target "$k" --json | json 'str(len(d["conflict"])+len(d["updated"])+len(d["created"])+len(d["merged"])+len(d["marked"]))+" "+str(sorted(d["edited"]))')
[ "$again" = "0 ['.claude-plugin/marketplace.json', 'CHANGELOG.md', 'plugins/sample-kit/.claude-plugin/plugin.json']" ] || miss "claude-plugin: re-apply after a bump: $again"
git -C "$k" add -A
verdict=$(python3 "$S/doctor.py" --target "$k" --json | json 'str(d["score"])+" "+d["preset"]+" "+",".join(r["id"] for r in d["failed"])')
[ "$verdict" = "100 claude-plugin " ] || miss "claude-plugin: doctor on the skeleton: $verdict"
n2="$TMP/plug-named"; mkdir -p "$n2"
python3 "$S/apply.py" --target "$n2" --preset claude-plugin --var project_name=Tools --var description=x --var owner=a --var 'plugin_name=My Greeter' >/dev/null
[ -f "$n2/plugins/my-greeter/.claude-plugin/plugin.json" ] && grep -q '"source": "./plugins/my-greeter"' "$n2/.claude-plugin/marketplace.json" || miss "claude-plugin: plugin_name not used"
if python3 "$S/apply.py" --target "$TMP/plug-bad" --preset claude-plugin --var project_name=B --var description=x --var owner=a --var plugin_versioning=sometimes >/dev/null 2>&1; then miss "claude-plugin: bad plugin_versioning accepted"; fi
for extra in "--archetype modular-monolith" "--archetype service-api" "--with ai" "--with mcp" "--deploy container"; do
  # shellcheck disable=SC2086
  if python3 "$S/apply.py" --target "$TMP/plug-bad" --preset claude-plugin $extra --var project_name=B --var description=x --var owner=a >/dev/null 2>&1; then miss "claude-plugin accepted $extra"; fi
done
kt="$TMP/claude-plugin-team"
[ -f "$kt/tools/repo_ontology.py" ] || miss "claude-plugin team: the YAML reader of the team tools is missing"
grep -q 'gh release create' "$kt/.github/workflows/release.yml" || miss "claude-plugin team: release workflow does not publish a GitHub Release"
[ ! -e "$kt/.github/workflows/deploy.yml" ] && [ ! -e "$kt/mk/deploy.mk" ] || miss "claude-plugin team: got a deploy pipeline"
if grep -qiE 'ontology|wiki' "$kt/CONTRIBUTING.md" "$kt/.github/pull_request_template.md"; then miss "claude-plugin team: contributor docs talk about ontology or wiki"; fi
grep -q 'plugin_lint.py' "$kt/.pre-commit-config.yaml" || miss "claude-plugin team: pre-commit does not lint manifests"
( cd "$kt" && make check >/dev/null 2>&1 ) || miss "claude-plugin team: make check fails"
kg="$TMP/plug-agents"; mkdir -p "$kg" && git -C "$kg" init -q -b main
python3 "$S/apply.py" --target "$kg" --preset claude-plugin --level team --with github-agents --var project_name=G --var description=x --var owner=a >/dev/null || miss "claude-plugin: github-agents refused"
[ -f "$kg/.github/actions/setup-project/action.yml" ] || miss "claude-plugin: agent workflows have no setup-project action"
echo "ok  claude-plugin skeleton (or misses reported above)"

# 33. detection: plugin manifests decide the kind; other repos are unaffected
kind() { python3 "$S/detect.py" --target "$1" | json 'str(d["suggested_preset"])+" "+str(d["signals"]["claude_plugin"])'; }
[ "$(kind "$k")" = "claude-plugin True" ] || miss "detect: skeleton gives $(kind "$k")"
[ "$(kind "$ROOT")" = "claude-plugin True" ] || miss "detect: this repo gives $(kind "$ROOT")"
[ "$(kind "$ROOT/tests/fixtures/plugin-repos/intact")" = "claude-plugin True" ] || miss "detect: fixture not recognised"
python3 "$S/detect.py" --target "$ROOT/tests/fixtures/plugin-repos/intact" | json '",".join(d["claude_plugin"]["plugins"])' | grep '^alpha,beta$' >/dev/null || miss "detect: plugins not listed"
[ "$(kind "$TMP/ts-node-starter")" = "ts-node False" ] || miss "detect: ts-node repo gives $(kind "$TMP/ts-node-starter")"
[ "$(kind "$TMP/python-starter")" = "python False" ] || miss "detect: python repo gives $(kind "$TMP/python-starter")"
[ "$(kind "$e")" = "None False" ] || miss "detect: empty folder gives $(kind "$e")"
lone="$TMP/lone-plugin"; mkdir -p "$lone/plugins/solo/.claude-plugin"; echo '{"name":"solo"}' > "$lone/plugins/solo/.claude-plugin/plugin.json"
[ "$(kind "$lone")" = "claude-plugin True" ] || miss "detect: plugin manifests without a marketplace give $(kind "$lone")"
echo "ok  detection of plugin repos (or misses reported above)"

# 34. adopt on an existing plugin repo: only what fits, nothing overwritten
PF="$ROOT/tests/fixtures/plugin-repos/intact"
fresh() { rm -rf "$1"; cp -R "$PF" "$1"; git -C "$1" init -q -b main; git -C "$1" add -A; }
ad="$TMP/plug-adopt"; fresh "$ad"
before=$(cd "$ad" && find . -type f -not -path './.git/*' | sort | xargs cksum | cksum)
out=$(python3 "$S/apply.py" --target "$ad" --preset claude-plugin --level starter --adopt --dry-run \
  --var project_name=Sample --var description=x --var owner=acme --json)
[ "$before" = "$(cd "$ad" && find . -type f -not -path './.git/*' | sort | xargs cksum | cksum)" ] || miss "adopt plugin repo: dry run changed files"
padopt() { python3 -c "import json,sys; d=json.loads(sys.argv[1]); assert $1, sys.argv[2]" "$out" "$1" 2>/dev/null || miss "adopt plugin repo: $1"; }
padopt "sorted(d['created']) == ['.claude/settings.json', '.claude/skills/review-change/SKILL.md', '.editorconfig', '.gitattributes', '.nvmrc', 'AGENTS.md', 'CLAUDE.md', 'Makefile', 'mk/autonomy.mk', 'mk/derived.mk', 'mk/upgrade.mk', 'tools/autonomy_card.py', 'tools/ci_inputs.py', 'tools/ci_verdict.py', 'tools/ledgers.py', 'tools/plugin_lint.py', 'tools/upgrade_markers.py']"
padopt "d['merged'] == ['.gitignore']"
padopt "d['kept'] == ['.claude-plugin/marketplace.json', 'CHANGELOG.md']"
padopt "d['conflict'] == ['LICENSE', 'README.md']"
padopt "all(s in d['skipped'] for s in ['plugins/sample/.claude-plugin/plugin.json', 'plugins/sample/skills/hello/SKILL.md', 'plugins/sample/README.md', 'tests/run.sh', 'tools/bump_version.py', '.github/workflows/ci.yml'])"
padopt "d['skip_reasons']['tools/bump_version.py'] == 'repo already has scripts/bump.sh'"
padopt "d['skip_reasons']['tests/run.sh'] == 'sample code (adopt mode)'"
padopt "not [f for f in d['created'] + d['merged'] if f.split('/')[0] in ('ontology', 'wiki', 'src', 'plugins', 'tests') or f in ('package.json', 'tsconfig.json', 'eslint.config.js', '.prettierrc.json', '.env.example', 'tools/wiki_lint.py', 'tools/repo_ontology.py')]"
padopt "[n['what'] for n in d['not_applicable']] == ['Domain ontology and project wiki', '.env.example']"
python3 "$S/apply.py" --target "$ad" --preset claude-plugin --adopt --var project_name=Sample --var description=x --var owner=acme >/dev/null
for f in .claude-plugin/marketplace.json README.md LICENSE CHANGELOG.md tests/run.sh scripts/bump.sh .github/workflows/test.yml plugins/alpha/.claude-plugin/plugin.json; do
  cmp -s "$PF/$f" "$ad/$f" || miss "adopt plugin repo: $f was changed"
done
grep -q '^node_modules/$' "$ad/.gitignore" && grep -q '^\.env$' "$ad/.gitignore" || miss "adopt plugin repo: .gitignore not merged"
( cd "$ad" && make check >/dev/null 2>&1 ) || miss "adopt plugin repo: make check fails after adopting"
git -C "$ad" add -A
after=$(python3 "$S/doctor.py" --target "$ad" --json | json 'str(d["score"])+" "+",".join(r["id"] for r in d["failed"])')
[ "$after" = "100 " ] || miss "adopt plugin repo: doctor after adopting: $after"
echo "ok  adopt on a plugin repo (or misses reported above)"

# 35. doctor profile for plugin repos: each check fails on a broken repo and passes on an intact one
verdict() { # dir, check id, extra doctor flags -> "pass" | "fail: ..." | "na: reason" | "skipped: ..." | "absent"
  python3 "$S/doctor.py" --target "$1" --json ${3:-} | python3 -c '
import json, sys
d, cid = json.load(sys.stdin), sys.argv[1]
out = ["pass"] if cid in d["passed"] else []
for key, label in (("failed", "fail"), ("skipped", "skipped"), ("not_applicable", "na")):
    out += [label + ": " + " | ".join(str(r.get(k)) for k in ("detail", "reason", "title", "why", "fix") if r.get(k)) for r in d[key] if r["id"] == cid]
print(out[0] if out else "absent")' "$2"; }
expect() { # dir, check id, regex the verdict must match, extra doctor flags
  got=$(verdict "$1" "$2" "${4:-}"); grep -qE "$3" <<<"$got" || miss "doctor on $(basename "$1"): $2 gave '$got', want /$3/"; }
edit_json() { python3 - "$1" "$2" <<'PY'
import json, sys
path, code = sys.argv[1:]
d = json.load(open(path))
exec(code)
json.dump(d, open(path, "w"), indent=2)
PY
}
ok="$TMP/pd-intact"; fresh "$ok"
for id in plugin_manifests plugin_versions plugin_source_not_root plugin_description_short plugin_bump_tool plugin_ci_validates plugin_changelog tests ci; do
  expect "$ok" "$id" '^pass$'
done
expect "$ok" lockfile '^na: No dependency manifest at the root'
expect "$ok" type_check '^na: No typed application code'
expect "$ok" formatter_linter '^na: No application code at the root'
expect "$ok" env_example '^na: Plugins read no environment configuration'
for id in ontology wiki ontology_wiki_valid ontology_in_check; do expect "$ok" "$id" '^na: A plugin marketplace has no business domain to model'; done
text=$(python3 "$S/doctor.py" --target "$ok")
grep -q 'Scored as: claude-plugin (detected: Claude Code plugin manifests)' <<<"$text" || miss "doctor text does not say how the repo was scored"
grep -q 'Not applicable to a claude-plugin repository (not scored):' <<<"$text" || miss "doctor text hides the checks that do not apply"
grep -q 'Domain ontology: glossary + entity definitions: A plugin marketplace has no business domain' <<<"$text" || miss "doctor text gives no reason for skipping the ontology"
# An app profile still demands what an app needs, and has none of the plugin checks.
expect "$ok" lockfile '^fail' '--preset python'
expect "$ok" ontology '^fail' '--preset python'
expect "$ok" tests '^fail' '--preset python'
expect "$ok" plugin_manifests '^absent$' '--preset python'
expect "$TMP/python-starter" plugin_manifests '^absent$'
expect "$TMP/python-starter" ontology '^pass$'
# A root dependency manifest makes the app checks apply again.
x="$TMP/pd-deps"; fresh "$x"; echo '{"name":"tooling"}' > "$x/package.json"
expect "$x" lockfile '^fail: .*Dependency lockfile committed'
expect "$x" type_check '^na: '
# manifests
x="$TMP/pd-badjson"; fresh "$x"; printf '{ "name": "beta", ' > "$x/plugins/beta/.claude-plugin/plugin.json"
expect "$x" plugin_manifests '^fail: plugins/beta/.claude-plugin/plugin.json is not valid JSON'
x="$TMP/pd-name"; fresh "$x"; edit_json "$x/plugins/alpha/.claude-plugin/plugin.json" 'd["name"] = "alfa"'
expect "$x" plugin_manifests "^fail: plugins/alpha/.claude-plugin/plugin.json says 'alfa' but the marketplace lists it as 'alpha'"
x="$TMP/pd-unlisted"; fresh "$x"; mkdir -p "$x/plugins/gamma/.claude-plugin"; echo '{"name":"gamma","version":"1.2.0"}' > "$x/plugins/gamma/.claude-plugin/plugin.json"
expect "$x" plugin_manifests '^fail: plugins/gamma has a plugin.json but is not listed'
x="$TMP/pd-missing"; fresh "$x"; rm -rf "$x/plugins/beta"
expect "$x" plugin_manifests "^fail: plugin 'beta': source folder plugins/beta/ does not exist"
x="$TMP/pd-market"; fresh "$x"; echo 'not json' > "$x/.claude-plugin/marketplace.json"
expect "$x" plugin_manifests '^fail: .claude-plugin/marketplace.json is not valid JSON'
expect "$x" plugin_versions '^skipped: .claude-plugin/marketplace.json is not valid JSON'
# versions
x="$TMP/pd-version"; fresh "$x"; edit_json "$x/plugins/beta/.claude-plugin/plugin.json" 'd["version"] = "1.3.0"'
expect "$x" plugin_versions "^fail: plugin 'beta': the marketplace says 1.2.0 but plugin.json says 1.3.0"
x="$TMP/pd-drift"; fresh "$x"; edit_json "$x/plugins/beta/.claude-plugin/plugin.json" 'd["version"] = "2.0.0"'
edit_json "$x/.claude-plugin/marketplace.json" 'd["plugins"][1]["version"] = "2.0.0"'
expect "$x" plugin_versions '^fail: plugins are at different versions \(alpha 1.2.0, beta 2.0.0\) and no independent versioning is declared'
echo '{"preset": "claude-plugin", "vars": {"plugin_versioning": "independent"}}' > "$x/.repo-setup.json"
expect "$x" plugin_versions '^pass$'
x="$TMP/pd-noversion"; fresh "$x"; edit_json "$x/plugins/alpha/.claude-plugin/plugin.json" 'del d["version"]'
edit_json "$x/.claude-plugin/marketplace.json" 'del d["plugins"][0]["version"]'
expect "$x" plugin_versions "^fail: plugin 'alpha' states no version"
x="$TMP/pd-oneplace"; fresh "$x"; edit_json "$x/.claude-plugin/marketplace.json" 'del d["plugins"][0]["version"]; del d["plugins"][1]["version"]'
expect "$x" plugin_versions '^pass$'
# source
x="$TMP/pd-root"; fresh "$x"; mv "$x/plugins/alpha/.claude-plugin/plugin.json" "$x/.claude-plugin/plugin.json"
edit_json "$x/.claude-plugin/marketplace.json" 'd["plugins"][0]["source"] = "./"'
expect "$x" plugin_source_not_root "^fail: plugin 'alpha' uses the repository root as its source \('./'\): every install copies the whole repository"
expect "$x" plugin_manifests '^pass$'
x="$TMP/pd-outside"; fresh "$x"; edit_json "$x/.claude-plugin/marketplace.json" 'd["plugins"][0]["source"] = "../elsewhere"'
expect "$x" plugin_source_not_root "^fail: plugin 'alpha': source '../elsewhere' points outside the repository"
x="$TMP/pd-hosted"; fresh "$x"; edit_json "$x/.claude-plugin/marketplace.json" 'd["plugins"].append({"name": "far", "source": {"source": "github", "repo": "acme/far"}})'
expect "$x" plugin_source_not_root '^pass$'
expect "$x" plugin_manifests '^pass$'
# description
x="$TMP/pd-long"; fresh "$x"; edit_json "$x/plugins/alpha/.claude-plugin/plugin.json" 'd["description"] = "x" * 2000'
expect "$x" plugin_description_short '^fail: plugins/alpha/.claude-plugin/plugin.json: description is 2,000 characters \(limit 1,024\)'
edit_json "$x/plugins/alpha/.claude-plugin/plugin.json" 'd["description"] = "x" * 1024'
expect "$x" plugin_description_short '^pass$'
edit_json "$x/.claude-plugin/marketplace.json" 'd["plugins"][1]["description"] = "y" * 1025'
expect "$x" plugin_description_short "^fail: marketplace entry 'beta': description is 1,025 characters"
[ "$(python3 -c "import tomllib; print([c['params']['max_chars'] for c in tomllib.load(open('$ROOT/plugins/repo-setup/checklists/top-tier.toml','rb'))['check'] if c['id']=='plugin_description_short'][0])")" \
  = "$(sed -n 's/^MAX_DESCRIPTION = //p' "$S/../presets/claude-plugin/starter/tools/plugin_lint.py")" ] || miss "description limit differs between the checklist and plugin_lint.py"
# bump tool, CI, changelog, tests
x="$TMP/pd-nobump"; fresh "$x"; rm "$x/scripts/bump.sh"
expect "$x" plugin_bump_tool '^fail: One command bumps the version in every manifest .*tools/bump_version.py'
x="$TMP/pd-ci"; fresh "$x"; printf 'name: Test\non: push\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      # later: claude plugin validate .\n      - run: bash tests/run.sh\n' > "$x/.github/workflows/test.yml"
expect "$x" plugin_ci_validates '^fail: CI validates the plugin manifests .*claude plugin validate'
expect "$x" ci '^pass$'
rm -rf "$x/.github"
expect "$x" ci '^fail'
x="$TMP/pd-nolog"; fresh "$x"; rm "$x/CHANGELOG.md"
expect "$x" plugin_changelog '^fail: A changelog says what changed in each version'
x="$TMP/pd-notests"; fresh "$x"; rm -rf "$x/tests"
expect "$x" tests '^fail: Automated tests exist'
# the repo's own lint command says the same thing
if python3 "$TMP/plug/tools/plugin_lint.py" --root "$TMP/pd-drift" >/dev/null 2>&1; then :; else miss "plugin_lint: independent versions rejected despite the declared policy"; fi
if python3 "$TMP/plug/tools/plugin_lint.py" --root "$TMP/pd-version" >/dev/null 2>"$TMP/lint.err"; then miss "plugin_lint: version mismatch accepted"; fi
grep -q "\[versions\] plugin 'beta': the marketplace says 1.2.0 but plugin.json says 1.3.0" "$TMP/lint.err" || miss "plugin_lint: no message for a version mismatch"
# rule-check: plugin-lint
{ python3 "$TMP/plug/tools/plugin_lint.py" --root "$TMP/pd-root" --json || true; } | json 'str(d["ok"])+" "+str(d["checks"]["sources"]["ok"])' | grep '^False False$' >/dev/null || miss "plugin_lint --json"
echo "ok  doctor profile for plugin repos (or misses reported above)"

# 36. version tags without GitHub Releases (--remote, with a stand-in gh)
rl="$TMP/pd-releases"; fresh "$rl"
git -C "$rl" -c user.name=t -c user.email=t@example.com -c core.hooksPath=/dev/null commit -qm base
mkdir -p "$TMP/fakebin"
cat > "$TMP/fakebin/gh" <<'SH'
#!/bin/sh
case "$1 $2" in
  "repo view") echo '{"nameWithOwner":"acme/sample-market","defaultBranchRef":{"name":"main"}}' ;;
  "release list") cat "$FAKE_RELEASES" ;;
  *) exit 1 ;;
esac
SH
chmod +x "$TMP/fakebin/gh"
remote_verdict() { PATH="$TMP/fakebin:$PATH" FAKE_RELEASES="$TMP/releases.json" verdict "$rl" plugin_releases '--level team --remote'; }
echo '[]' > "$TMP/releases.json"
remote_verdict | grep '^pass$' >/dev/null || miss "releases: a repo without tags must pass: $(remote_verdict)"
git -C "$rl" tag v1.1.0; git -C "$rl" tag v1.2.0
remote_verdict | grep '^fail: 2 tag(s) and no GitHub Release' >/dev/null || miss "releases: tags without releases: $(remote_verdict)"
echo '[{"tagName":"v1.1.0"},{"tagName":"v1.2.0"}]' > "$TMP/releases.json"
remote_verdict | grep '^pass$' >/dev/null || miss "releases: released tags must pass: $(remote_verdict)"
verdict "$rl" plugin_releases '--level team' | grep '^absent$' >/dev/null || miss "releases: must be a reminder without --remote"
python3 "$S/doctor.py" --target "$rl" --level team | grep 'Version tags are published as GitHub Releases' >/dev/null || miss "releases: no reminder without --remote"
echo "ok  releases for tags (or misses reported above)"

# 37. bump tool: every manifest together, or one plugin when versions are independent
BT="$S/../presets/claude-plugin/starter/tools/bump_version.py"
ver() { python3 -c "import json; m=json.load(open('$1/.claude-plugin/marketplace.json')); print(' '.join(str(p.get('version'))+'/'+json.load(open('$1/'+p['source']+'/.claude-plugin/plugin.json')).get('version','-') for p in m['plugins']))"; }
b="$TMP/bump-all"; fresh "$b"
python3 "$BT" --root "$b" minor --dry-run >/dev/null; [ "$(ver "$b")" = "1.2.0/1.2.0 1.2.0/1.2.0" ] || miss "bump: dry run wrote files"
python3 "$BT" --root "$b" minor >/dev/null; [ "$(ver "$b")" = "1.3.0/1.3.0 1.3.0/1.3.0" ] || miss "bump: lockstep gave $(ver "$b")"
grep -q '^## 1\.3\.0 — ' "$b/CHANGELOG.md" && [ "$(grep -n '^## ' "$b/CHANGELOG.md" | head -1 | cut -d: -f2 | cut -c1-8)" = "## 1.3.0" ] || miss "bump: changelog section missing or not first"
b="$TMP/pd-version"   # beta's two files disagree
if python3 "$BT" --root "$b" patch --plugin alpha >/dev/null 2>&1; then :; else miss "bump: --plugin refused"; fi
b="$TMP/bump-drift"; fresh "$b"; edit_json "$b/plugins/beta/.claude-plugin/plugin.json" 'd["version"] = "2.0.0"'
if python3 "$BT" --root "$b" patch >/dev/null 2>"$TMP/bump.err"; then miss "bump: guessed a version for plugins that differ"; fi
grep -q 'plugins are at different versions (alpha 1.2.0, beta 2.0.0)' "$TMP/bump.err" || miss "bump: no message for differing versions"
python3 "$BT" --root "$b" 3.0.0 >/dev/null; [ "$(ver "$b")" = "3.0.0/3.0.0 3.0.0/3.0.0" ] || miss "bump: explicit version gave $(ver "$b")"
b="$TMP/bump-own"; fresh "$b"; echo '{"vars": {"plugin_versioning": "independent"}}' > "$b/.repo-setup.json"
if python3 "$BT" --root "$b" patch >/dev/null 2>"$TMP/bump.err"; then miss "bump: bumped every plugin despite independent versioning"; fi
grep -q 'pass --plugin NAME' "$TMP/bump.err" || miss "bump: no hint to pass --plugin"
python3 "$BT" --root "$b" patch --plugin beta >/dev/null; [ "$(ver "$b")" = "1.2.0/1.2.0 1.2.1/1.2.1" ] || miss "bump: --plugin gave $(ver "$b")"
grep -q '^## beta 1\.2\.1 — ' "$b/CHANGELOG.md" || miss "bump: changelog does not name the plugin"
python3 "$BT" --root "$b" --notes 1.2.0 | grep 'alpha greets' >/dev/null || miss "bump: --notes"
b="$TMP/bump-kitlike"; fresh "$b"; edit_json "$b/.claude-plugin/marketplace.json" 'del d["plugins"][0]["version"]; del d["plugins"][1]["version"]'
python3 "$BT" --root "$b" patch >/dev/null; [ "$(ver "$b")" = "None/1.2.1 None/1.2.1" ] || miss "bump: added a version to marketplace entries that had none: $(ver "$b")"
echo "ok  bump tool (or misses reported above)"

# 38. decision layers: what does not apply to a plugin marketplace is recorded with its reason, never built
python3 "$bp" not-applicable claude-plugin > "$TMP/layers-na.txt"
for l in architecture ai domain design delivery; do grep -q "^$l: ." "$TMP/layers-na.txt" || miss "layers: $l is not marked not applicable for claude-plugin"; done
grep -q '^domain: A plugin marketplace has no business domain to model: ontology/ and wiki/ are not generated' "$TMP/layers-na.txt" || miss "layers: no reason for ontology and wiki"
[ -z "$(python3 "$bp" not-applicable python)" ] || miss "layers: an app stack has layers marked not applicable"
for l in architecture ai domain design delivery; do grep -q 'Stack `claude-plugin`:\*\* not applicable' "$SK/references/layers/$l.md" || miss "layer $l does not tell the agent it is not applicable for claude-plugin"; done
grep -q '`claude-plugin`' "$SK/references/layers/stack.md" && grep -q 'claude-plugin' "$SK/references/layers/context.md" || miss "stack/context layers do not offer claude-plugin"
grep -q 'not-applicable' "$SK/SKILL.md" && grep -q 'never dropped silently' "$SK/SKILL.md" || miss "new does not show layers that do not apply"
grep -q 'claude-plugin' "$ROOT/plugins/repo-setup/skills/adopt/SKILL.md" && grep -q 'not_applicable' "$ROOT/plugins/repo-setup/skills/doctor/SKILL.md" || miss "adopt/doctor skills do not cover plugin repos"
python3 "$bp" check "$B/ok-claude-plugin.yaml" >/dev/null 2>&1 || miss "blueprint: plugin marketplace blueprint rejected"
pvariant() { python3 - "$B/ok-claude-plugin.yaml" "$TMP/pvariant.yaml" "$1" "$2" <<'PY'
import sys
src, dst, old, new = sys.argv[1:]
t = open(src, encoding="utf-8").read()
assert old in t, old
open(dst, "w", encoding="utf-8").write(t.replace(old, new, 1))
PY
}
pvariant '  domain:
    status: not_applicable
' '  domain:
    status: decided
    source: user
    automation: automated
    choice: {seed: [Order]}
'
python3 "$bp" check "$TMP/pvariant.yaml" > "$TMP/pvariant.out" 2>&1 && miss "blueprint: an ontology was forced onto a plugin marketplace"
grep -q 'domain: not applicable with preset claude-plugin (A plugin marketplace has no business domain' "$TMP/pvariant.out" || miss "blueprint: no reason given when a layer does not apply: $(cat "$TMP/pvariant.out")"
if python3 "$S/apply.py" --target "$TMP/bp-forced" --from-blueprint "$TMP/pvariant.yaml" >/dev/null 2>&1; then miss "blueprint: apply built a layer that does not apply"; fi
pvariant '  domain:
    status: not_applicable
' '  domain:
    status: decided
    source: user
    automation: manual
    choice: {glossary: docs/glossary.md}
'
python3 "$bp" check "$TMP/pvariant.yaml" >/dev/null 2>&1 || miss "blueprint: a manual note on a layer that does not apply was rejected"
pvariant 'choice: {preset: claude-plugin}' 'choice: {preset: claude-plugin, plugin_name: greeter, plugin_versioning: independent}'
z="$TMP/bp-plugin"; mkdir -p "$z" && git -C "$z" init -q -b main
mapped=$(python3 "$S/apply.py" --target "$z" --from-blueprint "$TMP/pvariant.yaml" --json 2>/dev/null | json 'd["preset"]+"/"+d["level"]+"/"+d["archetype"]+"/"+d["deploy"]' 2>/dev/null || true)
[ "$mapped" = claude-plugin/starter/none/none ] || miss "blueprint: plugin marketplace mapping: $mapped"
[ -f "$z/plugins/greeter/.claude-plugin/plugin.json" ] && [ ! -e "$z/ontology" ] && [ ! -e "$z/wiki" ] || miss "blueprint: plugin marketplace was not built as designed"
python3 -c "import json; assert json.load(open('$z/.repo-setup.json'))['vars']['plugin_versioning'] == 'independent'" 2>/dev/null || miss "blueprint: versioning policy not recorded"
cp "$TMP/pvariant.yaml" "$z/setup-blueprint.yaml"; git -C "$z" add -A
[ "$(python3 "$S/doctor.py" --target "$z" --json | json 'str(d["score"])+str(d["blueprint_drift"])')" = "100[]" ] || miss "blueprint: plugin marketplace drift or score"
echo "ok  layers for plugin repos (or misses reported above)"

# 39. entity lifecycle: once a repo declares actions, every entity answers create / query / update / delete
l="$TMP/lifecycle"; mkdir -p "$l" && git -C "$l" init -q -b main
python3 "$S/apply.py" --target "$l" --preset ts-node --var project_name=L --var description=x --var owner=acme >/dev/null
python3 "$ROOT/tests/apply_fixture.py" coffee "$l" >/dev/null
order="$l/ontology/entities/Order.yaml"
grep -q '^lifecycle:' "$order" || miss "lifecycle: the sample domain does not declare one"
order_base=$(sed '/^lifecycle:/,$d' "$order")
put() { printf '%s\n%b' "$order_base" "$1" > "$order"; }
lerrs() { ( cd "$l" && { python3 tools/wiki_lint.py --json || true; } ) | json '"\n".join(e["message"] for e in d["errors"])'; }
lwarns() { ( cd "$l" && { python3 tools/wiki_lint.py --json || true; } ) | json '"\n".join(w["message"] for w in d["warnings"])'; }
[ -z "$(lerrs)" ] || miss "lifecycle: the sample domain fails: $(lerrs)"
put ''
out=$(lerrs)
[ "$(printf '%s\n' "$out" | grep -c "action for Order")" -eq 3 ] || miss "lifecycle: an entity with only a create action gave: $out"
grep -q "no 'delete' action for Order" <<<"$out" || miss "lifecycle: the missing delete is not named: $out"
grep -q "lifecycle.delete" <<<"$out" || miss "lifecycle: the message does not say how to record the choice: $out"
grep -q "no 'create' action" <<<"$out" && miss "lifecycle: a covered operation was reported: $out"
put 'lifecycle:\n  query: { later: Order history screen }\n  update: { never: Not changed after it is placed }\n  delete: { later: Yearly clean-up }\n'
lerrs | grep "lifecycle.update: 'never' needs decided_by" >/dev/null || miss "lifecycle: a refusal with nobody behind it passed: $(lerrs)"
put 'lifecycle:\n  query:\n    later: Order history screen\n  update:\n    never: Not changed after it is placed\n    decided_by: shop owner 2026-01-05\n  delete: { later: Yearly clean-up }\n'
[ -z "$(lerrs)" ] || miss "lifecycle: recorded choices still fail: $(lerrs)"
lwarns | grep "Order: 'query' is planned, not built (Order history screen)" >/dev/null || miss "lifecycle: a postponed operation is not listed: $(lwarns)"
lwarns | grep "Order: 'update'" >/dev/null && miss "lifecycle: a decided refusal is listed as a debt: $(lwarns)"
put 'lifecycle:\n  create: { later: x }\n  query: { later: x }\n  update: { later: x }\n  delete: { later: x }\n'
lwarns | grep "lifecycle.create is out of date: placeOrder" >/dev/null || miss "lifecycle: a stale entry is not reported: $(lwarns)"
put 'lifecycle:\n  via: Customer\n'
[ -z "$(lerrs)" ] || miss "lifecycle: an entity handled through another one fails: $(lerrs)"
put 'lifecycle:\n  via: Nobody\n'
lerrs | grep "lifecycle.via: 'Nobody' is not an entity" >/dev/null || miss "lifecycle: via an unknown entity passed: $(lerrs)"
put 'lifecycle:\n  via: Order\n'
lerrs | grep "lifecycle.via: an entity cannot be handled through itself" >/dev/null || miss "lifecycle: via itself passed: $(lerrs)"
put 'lifecycle:\n  remove: { later: x }\n'
lerrs | grep "lifecycle.remove: unknown key" >/dev/null || miss "lifecycle: an unknown key passed: $(lerrs)"
put 'lifecycle: later\n'
lerrs | grep "lifecycle must be a mapping" >/dev/null || miss "lifecycle: a bare word passed: $(lerrs)"
put ''
rm "$l/ontology/actions.yaml"
[ -z "$(lerrs)" ] || miss "lifecycle: a repo that declares no actions was asked for them: $(lerrs)"
grep -q '^paths: \["ontology/\*\*"\]' "$l/.claude/rules/ontology.md" 2>/dev/null || miss "lifecycle: no rule file scoped to ontology/"
grep -q 'decided_by' "$l/.claude/rules/ontology.md" 2>/dev/null || miss "lifecycle: the rule file does not say who fills decided_by"
grep -q 'lifecycle' "$l/.claude/skills/ontology-add/SKILL.md" || miss "lifecycle: ontology-add does not ask for it"
grep -q 'lifecycle' "$l/ontology/entities/_template.yaml" || miss "lifecycle: the entity template does not show it"
[ ! -e "$z/.claude/rules/ontology.md" ] || miss "lifecycle: a plugin marketplace got the ontology rule file"
echo "ok  entity lifecycle (or misses reported above)"

# 40. relations: an "own" scope needs a relation behind it; every relation answers attach / detach / reassign
r="$TMP/relations"; mkdir -p "$r" && git -C "$r" init -q -b main
python3 "$S/apply.py" --target "$r" --preset ts-node --var project_name=R --var description=x --var owner=acme >/dev/null
python3 "$ROOT/tests/apply_fixture.py" coffee "$r" >/dev/null
rel="$r/ontology/relations.yaml"; act="$r/ontology/actions.yaml"; cust="$r/ontology/entities/Customer.yaml"
cp "$act" "$TMP/actions.base"; cp "$rel" "$TMP/relations.base"; cp "$cust" "$TMP/customer.base"
rerrs() { ( cd "$r" && { python3 tools/wiki_lint.py --json || true; } ) | json '"\n".join(e["message"] for e in d["errors"])'; }
rwarns() { ( cd "$r" && { python3 tools/wiki_lint.py --json || true; } ) | json '"\n".join(w["message"] for w in d["warnings"])'; }
# The same lint without PyYAML: generated repos fall back to the built-in reader.
rerrs_builtin() { ( cd "$r" && { python3 -c 'import runpy, sys; sys.modules["yaml"] = None; sys.path.insert(0, "tools"); sys.argv = ["wiki_lint.py", "--json"]; runpy.run_path("tools/wiki_lint.py", run_name="__main__")' || true; } ) | json '"\n".join(e["message"] for e in d["errors"])'; }
# relation <extra lines> [cardinality]: the sample relation, with other lines in place of its lifecycle
relation() { printf 'relations:\n  - from: Customer\n    name: places\n    to: Order\n    cardinality: %s\n%b' "${2:-one-to-many}" "$1" > "$rel"; }
# action <extra lines>: the sample actions plus more
action() { { cat "$TMP/actions.base"; printf '%b' "$1"; } > "$act"; }
grep -q 'lifecycle: { via: Order }' "$rel" || miss "relations: the sample relation does not say how it changes"
[ -z "$(rerrs)" ] || miss "relations: the sample domain fails: $(rerrs)"
[ -z "$(rerrs_builtin)" ] || miss "relations: the sample domain fails with the built-in YAML reader: $(rerrs_builtin)"
relation ''
out=$(rerrs)
grep -q "Customer -places-> Order: no answer for attach, detach, reassign" <<<"$out" || miss "relations: a relation nobody can change gave: $out"
[ "$(printf '%s\n' "$out" | grep -c "no answer for")" -eq 1 ] || miss "relations: one relation gave more than one error: $out"
grep -q "relations: {places: \[<operation>\]}" <<<"$out" || miss "relations: the message does not say how an action answers: $out"
grep -q "lifecycle.<operation>: {later: <where it is planned>}" <<<"$out" || miss "relations: the message does not say how to record the choice: $out"
grep -q "lifecycle: {via: <that entity>}" <<<"$out" || miss "relations: the message does not show the one-line form: $out"
relation '' many-to-many
rerrs | grep "Customer -places-> Order: no answer for attach, detach:" >/dev/null || miss "relations: a many-to-many relation was asked to reassign: $(rerrs)"
relation '    lifecycle:\n      attach: { later: Counter sign-up }\n      detach: { never: Orders stay with their customer }\n      reassign: { later: Merge two customers }\n'
rerrs | grep "Customer -places-> Order: lifecycle.detach: 'never' needs decided_by" >/dev/null || miss "relations: a refusal with nobody behind it passed: $(rerrs)"
relation '    lifecycle:\n      attach: { later: Counter sign-up }\n      detach:\n        never: Orders stay with their customer\n        decided_by: shop owner 2026-01-05\n      reassign: { later: Merge two customers }\n'
[ -z "$(rerrs)" ] || miss "relations: recorded choices still fail: $(rerrs)"
[ -z "$(rerrs_builtin)" ] || miss "relations: recorded choices fail with the built-in YAML reader: $(rerrs_builtin)"
rwarns | grep "Customer -places-> Order: 'reassign' is planned, not built (Merge two customers)" >/dev/null || miss "relations: a postponed operation is not listed: $(rwarns)"
rwarns | grep "Customer -places-> Order: 'detach'" >/dev/null && miss "relations: a decided refusal is listed as a debt: $(rwarns)"
action '  - name: moveOrder\n    description: Move an order to another customer.\n    entity: Order\n    kind: command\n    roles: [manager]\n    relations: { places: [reassign] }\n'
rwarns | grep "Customer -places-> Order: lifecycle.reassign is out of date: moveOrder" >/dev/null || miss "relations: a stale entry is not reported: $(rwarns)"
relation ''
out=$(rerrs)
grep -q "Customer -places-> Order: no answer for attach, detach:" <<<"$out" || miss "relations: an action that reassigns did not answer reassign: $out"
relation '    lifecycle: { via: Order }\n'
rerrs | grep "Customer -places-> Order: lifecycle.via says the link never changes, but moveOrder" >/dev/null || miss "relations: via next to an action that changes the link passed: $(rerrs)"
action '  - name: moveOrder\n    description: Move an order.\n    entity: Order\n    kind: command\n    roles: [manager]\n    relations: { places: reasign, serves: attach }\n'
out=$(rerrs)
grep -q "action 'moveOrder': relation 'places': unknown operation 'reasign'" <<<"$out" || miss "relations: a misspelt operation passed: $out"
grep -q "action 'moveOrder': relation 'serves' is not in ontology/relations.yaml" <<<"$out" || miss "relations: an unknown relation passed: $out"
action '  - name: moveOrder\n    description: Move an order.\n    entity: Order\n    kind: command\n    roles: [manager]\n    relations: places\n'
rerrs | grep "action 'moveOrder': relations must be a mapping" >/dev/null || miss "relations: a bare word under relations passed: $(rerrs)"
action '  - name: moveOrder\n    description: Move an order.\n    entity: Order\n    kind: command\n    roles: [manager]\n    relations: { places: reassign }\n'
{ cat "$TMP/relations.base"; printf '  - from: Order\n    name: places\n    to: Customer\n    cardinality: many-to-many\n    lifecycle: { via: Order }\n'; } > "$rel"
rerrs | grep "action 'moveOrder': relation 'places' is the name of 2 relations" >/dev/null || miss "relations: an ambiguous relation name passed: $(rerrs)"
action ''
relation '    lifecycle: { via: Nobody }\n'
rerrs | grep "Customer -places-> Order: lifecycle.via: 'Nobody' is not one of its ends" >/dev/null || miss "relations: via an entity outside the relation passed: $(rerrs)"
relation '    lifecycle: { remove: { later: x } }\n'
rerrs | grep "Customer -places-> Order: lifecycle.remove: unknown key" >/dev/null || miss "relations: an unknown key passed: $(rerrs)"
relation '    lifecycle: fixed\n'
rerrs | grep "Customer -places-> Order: lifecycle must be a mapping" >/dev/null || miss "relations: a bare word passed: $(rerrs)"
# own: the starter form (own: [role]) and the scope form are read alike
cp "$TMP/relations.base" "$rel"
action '  - name: viewOrder\n    description: See an order.\n    entity: Order\n    kind: query\n    roles: [staff, manager]\n    own: [staff]\n'
out=$(rerrs)
grep -q "action 'viewOrder': staff may run it only on their own Order, but no relation says what 'own' means" <<<"$out" || miss "relations: an own scope with no relation behind it gave: $out"
grep -q "mark it own: true" <<<"$out" || miss "relations: the own message does not say how to fix it: $out"
action '  - name: viewOrder\n    description: See an order.\n    entity: Order\n    kind: query\n    scope: { staff: own, manager: company }\n'
rerrs | grep "action 'viewOrder': staff may run it only on their own Order" >/dev/null || miss "relations: the scope form of own is not read: $(rerrs)"
relation '    own: true\n    lifecycle: { via: Order }\n'
[ -z "$(rerrs)" ] || miss "relations: an own scope with its relation still fails: $(rerrs)"
[ -z "$(rerrs_builtin)" ] || miss "relations: an own scope with its relation fails with the built-in YAML reader: $(rerrs_builtin)"
relation '    own: maybe\n    lifecycle: { via: Order }\n'
rerrs | grep "Customer -places-> Order: own must be true or false" >/dev/null || miss "relations: own: maybe passed: $(rerrs)"
# PyYAML reads yes / no as true / false; the built-in reader keeps them as words. Neither may read "no" as a yes.
for word in no yes maybe; do
  relation "    own: $word\n    lifecycle: { via: Order }\n"
  rerrs_builtin | grep "Customer -places-> Order: own must be true or false" >/dev/null || miss "relations: own: $word passed with the built-in YAML reader: $(rerrs_builtin)"
done
relation '    own: no\n    lifecycle: { via: Order }\n'
rerrs | grep "action 'viewOrder': staff may run it only on their own Order" >/dev/null || miss "relations: own: no was read as a yes: $(rerrs)"
# through the entity it lives under: Customer handled through Order, the own relation ends at Order
relation '    own: true\n    lifecycle: { via: Order }\n'
action '  - name: viewCustomerPhone\n    description: See the phone of a customer.\n    entity: Customer\n    kind: command\n    roles: [staff]\n    own: [staff]\n'
{ sed '/^lifecycle:/,$d' "$TMP/customer.base"; printf 'lifecycle: { via: Order }\n'; } > "$cust"
printf 'relations:\n  - from: Order\n    name: served_at\n    to: Order\n    cardinality: one-to-one\n    own: true\n    lifecycle: { via: Order }\n' > "$rel"
[ -z "$(rerrs)" ] || miss "relations: own through the entity it lives under fails: $(rerrs)"
cp "$TMP/customer.base" "$cust"
rerrs | grep "action 'viewCustomerPhone': staff may run it only on their own Customer" >/dev/null || miss "relations: own passed without via or a relation: $(rerrs)"
cp "$TMP/relations.base" "$rel"
action '  - name: viewOrder\n    description: See an order.\n    entity: Order\n    kind: query\n    roles: [manager]\n    own: [staff]\n'
rerrs | grep "action 'viewOrder': own lists role 'staff', which is not in its roles" >/dev/null || miss "relations: own for a role that may not run the action passed: $(rerrs)"
action '  - name: viewOrders\n    description: See orders.\n    kind: query\n    roles: [staff]\n    own: [staff]\n'
rerrs | grep "action 'viewOrders': own needs entity" >/dev/null || miss "relations: own without an entity passed: $(rerrs)"
relation ''; rm "$act"
[ -z "$(rerrs)" ] || miss "relations: a repo that declares no actions was asked about relations: $(rerrs)"
grep -q 'attach' "$r/.claude/rules/ontology.md" || miss "relations: the rule file does not name attach, detach, reassign"
grep -q 'own: true' "$r/.claude/skills/ontology-add/SKILL.md" || miss "relations: ontology-add does not say how to mark the own relation"
grep -q 'via' "$ROOT/plugins/repo-setup/presets/_core/starter/ontology/relations.yaml" || miss "relations: the starter relations file does not show the block"
grep -q 'via' "$r/.claude/skills/review-change/SKILL.md" || miss "relations: review-change does not look at via on a relation"
echo "ok  relations and own scope (or misses reported above)"

# 41. attributes: every property is set by a create or update action, or the entity says why not
a="$TMP/attributes"; mkdir -p "$a" && git -C "$a" init -q -b main
python3 "$S/apply.py" --target "$a" --preset ts-node --var project_name=A --var description=x --var owner=acme >/dev/null
python3 "$ROOT/tests/apply_fixture.py" coffee "$a" >/dev/null
cust="$a/ontology/entities/Customer.yaml"; ord="$a/ontology/entities/Order.yaml"; act="$a/ontology/actions.yaml"
grep -q '^not_set:' "$cust" || miss "attributes: the sample domain does not declare one"
cust_base=$(sed '/^not_set:/,$d' "$cust"); ord_base=$(sed '/^not_set:/,$d' "$ord"); cp "$act" "$TMP/actions.base"; cp "$ord" "$TMP/order.base"
aerrs() { ( cd "$a" && { python3 tools/wiki_lint.py --json || true; } ) | json '"\n".join(e["message"] for e in d["errors"])'; }
awarns() { ( cd "$a" && { python3 tools/wiki_lint.py --json || true; } ) | json '"\n".join(w["message"] for w in d["warnings"])'; }
aerrs_builtin() { ( cd "$a" && { python3 -c 'import runpy, sys; sys.modules["yaml"] = None; sys.path.insert(0, "tools"); sys.argv = ["wiki_lint.py", "--json"]; runpy.run_path("tools/wiki_lint.py", run_name="__main__")' || true; } ) | json '"\n".join(e["message"] for e in d["errors"])'; }
setc() { printf '%s\n%b' "$cust_base" "$1" > "$cust"; }
action() { { cat "$TMP/actions.base"; printf '%b' "$1"; } > "$act"; }
[ -z "$(aerrs)" ] || miss "attributes: the sample domain fails: $(aerrs)"
[ -z "$(aerrs_builtin)" ] || miss "attributes: the sample domain fails with the built-in YAML reader: $(aerrs_builtin)"
awarns | grep "Customer: setting name, phone is planned, not built (Sign-up at the counter)" >/dev/null || miss "attributes: postponed properties are not listed together: $(awarns)"
setc ''
out=$(aerrs)
grep -q "Customer: no create or update action sets id, name, phone, status, joinedAt:" <<<"$out" || miss "attributes: properties nobody can set gave: $out"
[ "$(printf '%s\n' "$out" | grep -c "no create or update action sets")" -eq 1 ] || miss "attributes: one entity gave more than one error: $out"
grep -q "sets: \[...\]" <<<"$out" || miss "attributes: the message does not say how an action answers: $out"
grep -q "not_set: system: \[...\]" <<<"$out" || miss "attributes: the message does not say how to record the reason: $out"
# an explicit sets wins over the input fields, and counts on any kind of action
action '  - name: blockCustomer\n    description: Stop a customer from ordering.\n    entity: Customer\n    kind: command\n    roles: [manager]\n    sets: [status]\n'
aerrs | grep "Customer: no create or update action sets id, name, phone, joinedAt:" >/dev/null || miss "attributes: sets on a command did not count: $(aerrs)"
awk '{ print } /^    kind: update$/ { print "    sets: [name]" }' "$TMP/actions.base" > "$act"
grep -q 'sets: \[name\]' "$act" || miss "attributes: the test did not add sets to the update action"
aerrs | grep "Customer: no create or update action sets id, phone, points, status, joinedAt:" >/dev/null || miss "attributes: an explicit sets did not win over the input fields: $(aerrs)"
action '  - name: blockCustomer\n    description: Stop a customer.\n    entity: Customer\n    kind: command\n    roles: [manager]\n    sets: [state]\n'
aerrs | grep "action 'blockCustomer': sets 'state', which is not a property of Customer" >/dev/null || miss "attributes: an unknown property under sets passed: $(aerrs)"
action '  - name: blockCustomer\n    description: Stop a customer.\n    entity: Customer\n    kind: command\n    roles: [manager]\n    sets: status\n'
aerrs | grep "action 'blockCustomer': sets must be a list of property names" >/dev/null || miss "attributes: a bare word under sets passed: $(aerrs)"
action '  - name: blockAll\n    description: Stop everyone.\n    kind: command\n    roles: [manager]\n    sets: [status]\n'
aerrs | grep "action 'blockAll': sets needs entity" >/dev/null || miss "attributes: sets without an entity passed: $(aerrs)"
action ''
setc 'not_set:\n  system: [id, joinedAt]\n  import: [phone]\n  later: { name: Sign-up at the counter }\n  never:\n    status: { reason: Customers are never blocked }\n'
aerrs | grep "not_set.never.status: 'never' needs decided_by" >/dev/null || miss "attributes: a refusal with nobody behind it passed: $(aerrs)"
setc 'not_set:\n  system: [id, joinedAt]\n  import: [phone]\n  later: { name: Sign-up at the counter }\n  never:\n    status: { reason: Customers are never blocked, decided_by: shop owner 2026-01-05 }\n'
[ -z "$(aerrs)" ] || miss "attributes: recorded reasons still fail: $(aerrs)"
[ -z "$(aerrs_builtin)" ] || miss "attributes: recorded reasons fail with the built-in YAML reader: $(aerrs_builtin)"
awarns | grep "Customer: setting name is planned, not built (Sign-up at the counter)" >/dev/null || miss "attributes: a postponed property is not listed: $(awarns)"
awarns | grep "Customer: setting.*status" >/dev/null && miss "attributes: a decided refusal is listed as a debt: $(awarns)"
setc 'not_set:\n  system: [id, joinedAt, points]\n  later: { name: x, phone: x, status: x }\n'
awarns | grep "not_set.system: 'points' is out of date: awardPoints now sets it" >/dev/null || miss "attributes: a stale entry is not reported: $(awarns)"
setc 'not_set:\n  system: [id, joinedAt, nickname]\n  later: { name: x, phone: x, status: x }\n'
aerrs | grep "not_set.system: 'nickname' is not a property of Customer" >/dev/null || miss "attributes: an unknown property under not_set passed: $(aerrs)"
setc 'not_set:\n  derived: [id]\n'
aerrs | grep "not_set.derived: unknown key" >/dev/null || miss "attributes: an unknown key passed: $(aerrs)"
setc 'not_set: system\n'
aerrs | grep "not_set must be a mapping" >/dev/null || miss "attributes: a bare word passed: $(aerrs)"
setc 'not_set:\n  system: id\n  later: [name]\n  never: [status]\n'
out=$(aerrs)
grep -q "not_set.system must be a list of property names" <<<"$out" || miss "attributes: system as a bare word passed: $out"
grep -q "not_set.later must be a mapping" <<<"$out" || miss "attributes: later as a list passed: $out"
grep -q "not_set.never must be a mapping" <<<"$out" || miss "attributes: never as a list passed: $out"
setc 'not_set:\n  system: [id, joinedAt]\n  later: { name: x, phone: x }\n  never:\n    status: { decided_by: shop owner 2026-01-05 }\n'
aerrs | grep "not_set.never.status: give reason" >/dev/null || miss "attributes: a refusal without a reason passed: $(aerrs)"
# an entity with no create or update action, or handled through its parent, is not asked per property
cp "$a/ontology/entities/Customer.yaml" "$TMP/customer.any"; printf '%s\n' "$cust_base" | sed '/^lifecycle:/,$d' > "$cust"; printf 'lifecycle: { via: Order }\n' >> "$cust"
aerrs | grep "no create or update action sets" >/dev/null && miss "attributes: an entity handled through its parent was asked: $(aerrs)"
printf '%s\n' "$ord_base" > "$ord"
aerrs | grep "Order: no create or update action sets id, placedOn:" >/dev/null || miss "attributes: the control case did not fail: $(aerrs)"
sed 's/^    kind: create$/    kind: command/' "$TMP/actions.base" > "$act"
aerrs | grep "Order: no create or update action sets" >/dev/null && miss "attributes: an entity with no create or update action was asked: $(aerrs)"
cp "$TMP/actions.base" "$act"; rm "$act"
[ -z "$(aerrs)" ] || miss "attributes: a repo that declares no actions was asked about properties: $(aerrs)"
grep -q 'not_set' "$a/.claude/rules/ontology.md" || miss "attributes: the rule file does not name not_set"
grep -q 'sets' "$a/.claude/skills/ontology-add/SKILL.md" || miss "attributes: ontology-add does not say how an action names properties"
grep -q 'not_set' "$a/ontology/entities/_template.yaml" || miss "attributes: the entity template does not show the block"
grep -q 'not_set' "$a/ontology/README.md" || miss "attributes: the ontology README does not explain it"
echo "ok  attributes (or misses reported above)"

# 42. merge method: squash unless asked; --merge-method merge keeps merge commits and changes nothing else
FX="$ROOT/tests/fixtures/github-setup"
gs="$TMP/gs-team"; gsa="$TMP/gs-agents"
for d in "$gs" "$gsa"; do mkdir -p "$d" && git -C "$d" init -q -b main; done
python3 "$S/apply.py" --target "$gs" --preset python --level team --var project_name=M --var description=x --var owner=acme >/dev/null
python3 "$S/apply.py" --target "$gsa" --preset python --level team --with github-agents --var project_name=M --var description=x --var owner=acme >/dev/null
mkdir -p "$TMP/gsbin"
# Stand-in gh: answers the two reads of a dry run and records every other call.
cat > "$TMP/gsbin/gh" <<'SH'
#!/bin/sh
case "$1 $2" in
  "repo view") echo '{"nameWithOwner":"acme/sample","defaultBranchRef":{"name":"main"}}' ;;
  "secret list") ;;
  "api repos/acme/sample/rulesets") ;;   # a read: no ruleset from an earlier run
  "api repos/acme/sample/actions/organization-secrets") ;;   # a read: no shared secret
  "api -H")   # a read: a file of the default branch
    [ -z "${GS_BASE_DOWN:-}" ] || { echo "gh: Server Error (HTTP 502)" >&2; exit 1; }
    file="${GS_BASE:-.}/$(echo "$4" | sed 's|^repos/acme/sample/contents/||; s|?ref=main$||')"
    [ -f "$file" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
    cat "$file" ;;
  *) echo "$*" >> "$GH_CALLS"; exit 1 ;;
esac
SH
chmod +x "$TMP/gsbin/gh"
dry() { ( cd "$1" && shift && PATH="$TMP/gsbin:$PATH" GH_CALLS="$TMP/gs-calls" python3 -B tools/github_setup.py "$@" ) 2>&1; }
# the fixtures are the dry run without the option
[ "$(dry "$gs")" = "$(cat "$FX/dry-run-team.txt")" ] || miss "merge method: the dry run without the option changed: $(dry "$gs" | diff "$FX/dry-run-team.txt" - | head -5)"
[ "$(dry "$gsa")" = "$(cat "$FX/dry-run-team-agents.txt")" ] || miss "merge method: the dry run with agents and without the option changed: $(dry "$gsa" | diff "$FX/dry-run-team-agents.txt" - | head -5)"
[ "$(dry "$gs" --merge-method squash)" = "$(cat "$FX/dry-run-team.txt")" ] || miss "merge method: squash is not the default: $(dry "$gs" --merge-method squash | head -3)"
# asking for merge commits (merge_method: merge in the policy): the diff against the fixture is the title of one
# step and two values on its line
gs_policy() { # <repo> <copy> <the merge_method line, or "" to leave the key out>
  rm -rf "$2"; cp -R "$1" "$2"
  python3 - "$2/governance/autonomy.yaml" "$3" <<'PY2'
import re, sys
path, line = sys.argv[1:]
text = open(path, encoding="utf-8").read()
text, n = re.subn(r"^merge_method: .*\n", line + "\n" if line else "", text, flags=re.M)
if n != 1:
    sys.exit(f"{path}: {n} merge_method lines, not one")
open(path, "w", encoding="utf-8").write(text)
PY2
}
gsm="$TMP/gs-team-merge"; gsam="$TMP/gs-agents-merge"
gs_policy "$gs" "$gsm" 'merge_method: merge' || miss "merge method: the policy of a new repository has no merge_method line to change"
gs_policy "$gsa" "$gsam" 'merge_method: merge' || miss "merge method: the policy of a new repository with agents has no merge_method line to change"
gsdiff() { { dry "$1" || true; } | diff "$FX/$2" - | grep '^[<>]' | head -8 || true; }
want_diff() { printf '%s\n' \
  "<   - squash-only merges, delete merged branches$1" \
  "<       gh api -X PATCH repos/acme/sample$2 -F delete_branch_on_merge=true -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false" \
  ">   - merge commits only, delete merged branches$1" \
  ">       gh api -X PATCH repos/acme/sample$2 -F delete_branch_on_merge=true -F allow_squash_merge=false -F allow_merge_commit=true -F allow_rebase_merge=false"; }
[ "$(gsdiff "$gsm" dry-run-team.txt)" = "$(want_diff '' '')" ] || miss "merge method: merge changed more or less than the three merge settings: $(gsdiff "$gs" dry-run-team.txt)"
[ "$(gsdiff "$gsam" dry-run-team-agents.txt)" = "$(want_diff ', auto-merge' ' -F allow_auto_merge=true')" ] || miss "merge method: merge with agents changed more or less than the three merge settings: $(gsdiff "$gsa" dry-run-team-agents.txt)"
# the same from the plan: one step differs, same fields in the same order, two values flipped
( cd "$gsa" && python3 -B -c "
import sys; sys.path.insert(0,'tools')
import github_setup as g
for agents in (False, True):
    a = g.plan('o/r','main','@a',agents)
    b = g.plan('o/r','main','@a',agents,merge_method='merge')
    assert a == g.plan('o/r','main','@a',agents,merge_method='squash')
    assert len(a) == len(b)
    changed = [(x, y) for x, y in zip(a, b) if x != y]
    assert len(changed) == 1, changed
    x, y = changed[0]
    assert set(x) == set(y) == {'what', 'args'}, (x, y)
    fields = lambda s: [v.split('=', 1) for v in s['args'] if '=' in v]
    assert [k for k, _ in fields(x)] == [k for k, _ in fields(y)]
    assert [v for v in x['args'] if '=' not in v] == [v for v in y['args'] if '=' not in v]
    assert {k: (dict(fields(x))[k], v) for k, v in fields(y) if dict(fields(x))[k] != v} == {
        'allow_squash_merge': ('true', 'false'), 'allow_merge_commit': ('false', 'true')}
    assert dict(fields(y))['allow_rebase_merge'] == 'false'
" ) || miss "merge method: the plan for merge commits differs from squash in more than the merge settings"
out=$(dry "$gs" --merge-method rebase || true)
grep -q "invalid choice: 'rebase'" <<<"$out" || miss "merge method: an unknown method was not refused by name: $out"
dry "$gsm" --merge-method merge --reviewer @b | grep 'human approval by @b' >/dev/null || miss "merge method: --reviewer is lost next to --merge-method"
[ ! -s "$TMP/gs-calls" ] || miss "merge method: a dry run called gh to change something: $(cat "$TMP/gs-calls")"
python3 "$gs/tools/github_setup.py" --help | grep -- '--merge-method' >/dev/null || miss "merge method: --help does not show the option"
# agents merge low-tier PRs with the method the repository allows, and squash when it cannot tell
pipeline="$gsa/.github/workflows/pr-pipeline.yml"
if grep -q -- '--auto --squash' "$pipeline"; then miss "merge method: the PR pipeline always squashes"; fi
mkdir -p "$TMP/pmbin"
cat > "$TMP/pmbin/gh" <<'SH'
#!/bin/sh
case "$1 $2" in
  "repo view") # answers only the question the pipeline must ask, for this repository
    [ "$*" = "repo view acme/sample --json squashMergeAllowed --jq .squashMergeAllowed" ] || exit 1
    [ "$SQUASH_ALLOWED" = unknown ] && exit 1; echo "$SQUASH_ALLOWED" ;;
  *) echo "$*" >> "$GH_CALLS" ;;
esac
SH
chmod +x "$TMP/pmbin/gh"
merged_with() { rm -f "$TMP/pm-calls"
  ( PATH="$TMP/pmbin:$PATH" GH_CALLS="$TMP/pm-calls" SQUASH_ALLOWED="$1" PR=7 GITHUB_REPOSITORY=acme/sample \
    bash -e -c "$(steps_of 'Enable auto-merge')" ) >/dev/null 2>&1 || true
  grep '^pr merge' "$TMP/pm-calls" 2>/dev/null || true; }
[ "$(merged_with true)" = "pr merge 7 --auto --squash" ] || miss "merge method: the pipeline does not squash where squash is allowed: $(merged_with true)"
[ "$(merged_with false)" = "pr merge 7 --auto --merge" ] || miss "merge method: the pipeline does not use a merge commit where squash is off: $(merged_with false)"
[ "$(merged_with unknown)" = "pr merge 7 --auto --squash" ] || miss "merge method: the pipeline does not fall back to squash: $(merged_with unknown)"
grep -q -- '--merge-method merge' "$ROOT/plugins/repo-setup/skills/github/SKILL.md" || miss "merge method: the github skill does not name the option"
# 42b. the choice is stored in governance/autonomy.yaml (merge_method), so a run without the option
#      does not set a repository back to squash. Found on a repository whose feature loop needs merge
#      commits: one run that forgot --merge-method merge made it squash-only again.
grep -q '^merge_method: squash$' "$gs/governance/autonomy.yaml" || miss "merge method: a new repository's policy does not store merge_method: squash"
dry "$gsm" | grep 'merge commits only' >/dev/null || miss "merge method: merge_method: merge in the policy is not what github_setup sets"
# an option that disagrees with the policy is refused, and says where the choice is made
rc=0; out=$(dry "$gs" --merge-method merge) || rc=$?
[ "$rc" = 2 ] || miss "merge method: --merge-method merge against merge_method: squash ends with $rc, not 2"
case "$out" in *"merge_method: squash"*governance/autonomy.yaml*) ;; *) miss "merge method: the refusal does not name the policy and its value: $out" ;; esac
[ "$(dry "$gs" --merge-method squash)" = "$(dry "$gs")" ] || miss "merge method: an option that agrees with the policy changes the run"
# a policy from before this key: without the option the merge settings are left as they are, never reset
gso="$TMP/gs-team-nokey"; gs_policy "$gs" "$gso" '' || true
out=$(dry "$gso")
case "$out" in *allow_squash_merge*|*allow_merge_commit*) miss "merge method: a policy with no merge_method still sets the merge settings: $(grep -m1 allow_ <<<"$out")" ;; esac
case "$out" in *"names no merge_method"*) ;; *) miss "merge method: a policy with no merge_method does not say the merge settings are left as they are" ;; esac
grep -q 'delete_branch_on_merge=true' <<<"$out" || miss "merge method: a policy with no merge_method loses the rest of the repository settings"
dry "$gso" --merge-method merge | grep 'merge commits only' >/dev/null || miss "merge method: with no merge_method in the policy, --merge-method merge is not used"
# a value that is neither squash nor merge: autonomy.py names it, github_setup stops before any change
gsb="$TMP/gs-team-badkey"; gs_policy "$gs" "$gsb" 'merge_method: rebase' || true
out=$( cd "$gsb" && python3 -B tools/autonomy.py --check-codeowners 2>&1 || true )
case "$out" in *"merge_method: rebase is not one of squash, merge"*) ;; *) miss "merge method: autonomy.py does not name a merge_method that is neither squash nor merge: $out" ;; esac
rc=0; out=$(dry "$gsb") || rc=$?
[ "$rc" = 1 ] || miss "merge method: github_setup goes on with merge_method: rebase (exit $rc)"
case "$out" in *"merge_method: rebase"*) ;; *) miss "merge method: github_setup does not say which merge_method it refused: $out" ;; esac
# 42c. the method a repository gets when the setup first writes the key is the one it uses (the
#      owner, 2026-11-21): the last commits of the branch decide, a merge commit among them means
#      merge. A repository with no commit gets squash (42b). --var merge_method=... wins. The upgrade
#      cases, where a policy already names a value, are in tests/upgrade.sh (47p).
mc_git() { git -C "$1" -c user.name=t -c user.email=t@example.com "${@:2}"; }
mc_repo() { # <dir> <merges|linear>: a repository with that history, before the setup comes
  rm -rf "$1"; mkdir -p "$1"; git -C "$1" init -q -b main
  echo one > "$1/one.txt" && mc_git "$1" add -A && mc_git "$1" commit -q -m one
  if [ "$2" = merges ]; then
    mc_git "$1" checkout -q -b side && echo two > "$1/two.txt" && mc_git "$1" add -A && mc_git "$1" commit -q -m two
    mc_git "$1" checkout -q main && mc_git "$1" merge -q --no-ff --no-edit side
  else
    echo two > "$1/two.txt" && mc_git "$1" add -A && mc_git "$1" commit -q -m two
  fi
}
mc_apply() { python3 "$S/apply.py" --target "$1" --preset python --level "${MC_LEVEL:-team}" --var project_name=M --var description=x --var owner=acme "${@:2}"; }
mc_line() { grep '^merge_method:' "$1/governance/autonomy.yaml" || true; }
mc_var() { python3 -c "import json,sys; print(json.load(open(sys.argv[1]+'/.repo-setup.json'))['vars'].get('merge_method', 'none'))" "$1"; }
mcm="$TMP/mc-merges"; mc_repo "$mcm" merges; mc_apply "$mcm" >/dev/null
[ "$(mc_line "$mcm")" = "merge_method: merge" ] || miss "merge method: a repository that merges with merge commits gets '$(mc_line "$mcm")', not merge"
[ "$(mc_var "$mcm")" = merge ] || miss "merge method: the manifest does not keep the method that was chosen ($(mc_var "$mcm"))"
mcl="$TMP/mc-linear"; mc_repo "$mcl" linear; mc_apply "$mcl" >/dev/null
[ "$(mc_line "$mcl")" = "merge_method: squash" ] || miss "merge method: a repository with no merge commit gets '$(mc_line "$mcl")', not squash"
mcv="$TMP/mc-var"; mc_repo "$mcv" linear; mc_apply "$mcv" --var merge_method=merge >/dev/null
[ "$(mc_line "$mcv")" = "merge_method: merge" ] || miss "merge method: --var merge_method=merge is not used ('$(mc_line "$mcv")')"
mcb="$TMP/mc-bad"; mc_repo "$mcb" linear
rc=0; out=$(mc_apply "$mcb" --var merge_method=rebase 2>&1) || rc=$?
[ "$rc" != 0 ] || miss "merge method: --var merge_method=rebase is accepted"
case "$out" in *squash*merge*) ;; *) miss "merge method: the refusal of --var merge_method=rebase does not name the two methods: $out" ;; esac
[ ! -e "$mcb/governance/autonomy.yaml" ] || miss "merge method: a refused merge_method still wrote the policy"
# a starter repository has no policy: it is not given a merge method to carry
mcs="$TMP/mc-starter"; mc_repo "$mcs" merges; MC_LEVEL=starter mc_apply "$mcs" >/dev/null
[ "$(mc_var "$mcs")" = none ] || miss "merge method: a starter repository's manifest holds a merge method ($(mc_var "$mcs"))"
# ... and gets it from its history on the run that makes it a team repository
python3 "$S/apply.py" --target "$mcs" --level team >/dev/null
[ "$(mc_line "$mcs")" = "merge_method: merge" ] || miss "merge method: starter to team in a repository with merge commits gives '$(mc_line "$mcs")', not merge"
# Only the repository's own history counts. A folder inside another repository has none of its
# own: git would answer for the repository around it.
mco="$TMP/mc-outer"; mc_repo "$mco" merges; mkdir -p "$mco/new-service"
mc_apply "$mco/new-service" >/dev/null
[ "$(mc_line "$mco/new-service")" = "merge_method: squash" ] || miss "merge method: a folder inside another repository takes that repository's history ('$(mc_line "$mco/new-service")')"
# A shallow clone hides the parents of its last commits: a merge commit there reads as a plain one.
# Where no merge commit is seen in a shallow history, the run does not guess: it asks for the word.
mch="$TMP/mc-shallow"; rm -rf "$mch"; git clone -q --depth 1 "file://$mcm" "$mch"
rm -f "$mch/governance/autonomy.yaml" "$mch/.repo-setup.json"
rc=0; out=$(mc_apply "$mch" 2>&1) || rc=$?
[ "$rc" != 0 ] || miss "merge method: a shallow history with no merge commit in sight is read as $(mc_line "$mch")"
case "$out" in *shallow*"--var merge_method"*) ;; *) miss "merge method: the refusal on a shallow history does not say why and what to pass: $out" ;; esac
mc_apply "$mch" --var merge_method=merge >/dev/null
[ "$(mc_line "$mch")" = "merge_method: merge" ] || miss "merge method: --var merge_method=merge on a shallow history gives '$(mc_line "$mch")'"
# The policy is where the choice is made. After a person changes it, the next run keeps their word
# and the manifest follows; an option that says otherwise is refused, as tools/github_setup.py does.
mcp="$TMP/mc-person"; mc_repo "$mcp" merges; mc_apply "$mcp" >/dev/null
subst 's/^merge_method: merge$/merge_method: squash/' "$mcp/governance/autonomy.yaml"
python3 "$S/apply.py" --target "$mcp" >/dev/null
[ "$(mc_line "$mcp")" = "merge_method: squash" ] || miss "merge method: the word a person put in the policy was changed to '$(mc_line "$mcp")'"
[ "$(mc_var "$mcp")" = squash ] || miss "merge method: the manifest does not follow the policy a person changed ($(mc_var "$mcp"))"
rc=0; out=$(python3 "$S/apply.py" --target "$mcp" --var merge_method=merge 2>&1) || rc=$?
[ "$rc" != 0 ] || miss "merge method: --var merge_method=merge against merge_method: squash in the policy is accepted"
case "$out" in *"merge_method: squash"*governance/autonomy.yaml*) ;; *) miss "merge method: the refusal does not name the policy and its value: $out" ;; esac
[ "$(mc_line "$mcp")" = "merge_method: squash" ] || miss "merge method: a refused option still changed the policy to '$(mc_line "$mcp")'"
echo "ok  merge method (or misses reported above)"

# 43. people decide, machines check (docs/setup-principles.md): nothing the setup generates uses a
#     person as a checker. A person appears where something is decided: the rules, production.
pd="$TMP/people-decide"; mkdir -p "$pd" && git -C "$pd" init -q -b main
python3 "$S/apply.py" --target "$pd" --preset python --level team --with github-agents --var project_name=P --var description=x --var owner=acme >/dev/null
tier_of() { ( cd "$pd" && python3 tools/autonomy.py --files "$@" | json 'd["tier"]' ); }
# 43a. high is the rules of the game and nothing else: no product path is high because of its name
# rule-check: autonomy-gate
for f in governance/autonomy.yaml .github/workflows/ci.yml .claude/settings.json tools/autonomy.py Makefile AGENTS.md; do
  [ "$(tier_of "$f")" = high ] || miss "people decide: a rule file is not high: $f is $(tier_of "$f")"
done
for f in ontology/actions.yaml src/auth/login.py src/author.py db/migrations/001.sql infra/main.tf deploy/app.yaml Dockerfile compose.yaml; do
  [ "$(tier_of "$f")" = medium ] || miss "people decide: a product path is judged by its name: $f is $(tier_of "$f")"
done
# 43b. the ruleset asks nobody to approve; a code owner decides only where CODEOWNERS names one
( cd "$pd" && python3 -B -c "
import sys; sys.path.insert(0,'tools')
import github_setup as g
def rules_of(steps):
    return {r['type']: r.get('parameters', {}) for r in [s for s in steps if 'ruleset' in s][0]['ruleset']['rules']}
def checks_of(steps):
    return [c['context'] for c in rules_of(steps)['required_status_checks']['required_status_checks']]
for agents in (False, True):
    steps = g.plan('o/r','main','@a',agents)
    pr = rules_of(steps)['pull_request']
    assert pr['required_approving_review_count'] == 0, pr
    assert pr['require_code_owner_review'] is True, pr
    assert not any('can_approve_pull_request_reviews=true' in a for s in steps for a in s['args']), 'Actions may approve'
    assert agents == any('can_approve_pull_request_reviews=false' in a for s in steps for a in s['args']), 'Actions not told'
    own = ['check', 'gate', 'secret-scan'] if agents else ['check', 'secret-scan']
    assert checks_of(steps) == own, checks_of(steps)
    assert checks_of(g.plan('o/r','main','@a',agents,proof='evidence')) == own + ['evidence']
" ) || miss "people decide: the ruleset needs an approval, lets Actions approve, or does not require the proof"
# 43c. a person leaves only when a machine proof takes the place: default low needs proof.check
policy="$pd/governance/autonomy.yaml"; cp "$policy" "$TMP/policy.orig"
set_policy() { python3 - "$policy" "$TMP/policy.orig" "$1" "$2" <<'PY'
import re, sys
out, src, default, proof = sys.argv[1:]
t = open(src, encoding="utf-8").read()
t, n = re.subn(r"(?m)^default: .*$", f"default: {default}", t)
t, m = re.subn(r"(?m)^  check: .*$", f'  check: "{proof}"', t)
assert n == 1 and m == 1, (n, m)
open(out, "w", encoding="utf-8").write(t)
PY
}
governance_ok() { ( cd "$pd" && python3 tools/autonomy.py --write-codeowners >/dev/null && python3 tools/autonomy.py --check-codeowners >/dev/null 2>&1 ); }
grep -q '^default: medium$' "$policy" || miss "people decide: the sample policy must start without a proof, at default medium"
grep -q '^\*  @acme$' "$pd/.github/CODEOWNERS" || miss "people decide: without a proof, unproven code lost its owner"
set_policy low "" 2>/dev/null || miss "people decide: the policy has no proof.check to set"
if governance_ok; then miss "people decide: default low was accepted without a proof"; fi
[ "$(tier_of src/app.py)" = medium ] || miss "people decide: default low without a proof lets unproven code merge itself: $(tier_of src/app.py)"
for reserved in check gate; do
  set_policy low "$reserved" 2>/dev/null || true
  if governance_ok; then miss "people decide: the repo's own check '$reserved' was accepted as the proof"; fi
  [ "$(cd "$pd" && python3 tools/autonomy.py --files docs/x.md 2>/dev/null | json 'd.get("proof")')" = "" ] || miss "people decide: the pipeline is told that '$reserved' proves a change"
done
set_policy low evidence 2>/dev/null || true
governance_ok || miss "people decide: default low with a proof was refused"
[ "$(tier_of src/app.py)" = low ] || miss "people decide: proven code still waits for a person: $(tier_of src/app.py)"
[ "$(tier_of governance/autonomy.yaml)" = high ] || miss "people decide: with a proof, the rules lost their decider"
[ "$(cd "$pd" && python3 tools/autonomy.py --files src/app.py | json 'd.get("proof")')" = evidence ] || miss "people decide: the tier result does not name the proof"
if grep -qE '^\*( |$)' "$pd/.github/CODEOWNERS"; then miss "people decide: with a proof, every path still has an owner"; fi
grep -q '^/governance/\*\*  @acme$' "$pd/.github/CODEOWNERS" || miss "people decide: with a proof, governance/ lost its owner"
dry "$pd" | grep 'checks check, gate, secret-scan, conventional-title, conventional-commits, evidence' >/dev/null || miss "people decide: github_setup does not require the proof the policy names"
# 43d. a looser agent guard is a rule change, wherever it is written; a new action is not
mkdir -p "$pd/ontology" "$pd/src"
printf 'actions:\n  - name: wipe\n    agent: forbidden\n  - name: refund\n    agent: confirm\n' > "$pd/ontology/actions.yaml"
pd_save() { git -C "$pd" add -A && git -C "$pd" -c user.name=t -c user.email=t@example.com commit -q -m "$1"; }
pd_start() { git -C "$pd" checkout -q -B "$1" main; }
pd_tier() { actual=$(cd "$pd" && python3 tools/autonomy.py --base main --head HEAD | json 'd["tier"]')
  [ "$actual" = "$2" ] || miss "people decide: tier of '$1': got $actual, want $2"; }
pd_save base
pd_start e1; subst '/agent: forbidden/d' "$pd/ontology/actions.yaml"; pd_save e1
# rule-check: autonomy-gate
pd_tier "agent: forbidden removed" high
pd_start e2; subst 's/agent: confirm/agent: allowed/' "$pd/ontology/actions.yaml"; pd_save e2
pd_tier "agent: confirm made allowed" high
pd_start e3; subst 's/agent: forbidden/agent: confirm/' "$pd/ontology/actions.yaml"; pd_save e3
pd_tier "agent: forbidden made confirm" high
pd_start e4; subst 's/agent: confirm/agent: forbidden/' "$pd/ontology/actions.yaml"; pd_save e4
pd_tier "agent: confirm made forbidden (tighter)" low
pd_start e5; printf '  - name: greet\n    agent: allowed\n' >> "$pd/ontology/actions.yaml"; pd_save e5
pd_tier "a new action" low
pd_start e6; git -C "$pd" rm -q ontology/actions.yaml; pd_save e6
pd_tier "the file with the guards deleted" high
pd_start e7; subst 's/agent: confirm/agent: allowed/' "$pd/ontology/actions.yaml"
printf '  - name: purge\n    agent: forbidden\n' >> "$pd/ontology/actions.yaml"; pd_save e7
pd_tier "one guard dropped while a new action brings one" high
pd_start e8; printf 'actions:\n  - name: wipe\n    agent: confirm\n  - name: refund\n    agent: forbidden\n' > "$pd/ontology/actions.yaml"; pd_save e8
pd_tier "two actions swap their guards" high
pd_start e9; printf 'actions:\n  - name: refund\n    agent: "confirm"\n  - name: wipe\n    agent: forbidden\n' > "$pd/ontology/actions.yaml"; pd_save e9
pd_tier "actions reordered and a guard quoted, nothing looser" low
pd_start e10; printf 'actions:\n  - name: wipe\n    agent: forbidden\n  - name: refund\n    agent: [confirm\n' > "$pd/ontology/actions.yaml"; pd_save e10
pd_tier "a guarded file that can no longer be read" high
# 43e. the gate hands the proof to the pipeline, from the base branch
git -C "$pd" update-ref refs/remotes/origin/main main
pd_start g1; echo 'X = 1' > "$pd/src/new_module.py"; pd_save g1
pipeline="$pd/.github/workflows/pr-pipeline.yml"
mkdir -p "$TMP/runner"; rm -f "$TMP/pd-gate.out"
( cd "$pd" && RUNNER_TEMP="$TMP/runner" GITHUB_WORKSPACE="$pd" GITHUB_OUTPUT="$TMP/pd-gate.out" \
  GITHUB_STEP_SUMMARY="$TMP/summary" BASE=main AUTHOR=someone UPDATE_TYPE="" \
  bash -e -c "$(steps_of 'Load the rules from the base branch'; steps_of 'Classify')" ) >/dev/null 2>&1 \
  || miss "people decide: the gate failed on a proven change"
grep -q '^tier=low$' "$TMP/pd-gate.out" 2>/dev/null || miss "people decide: the gate does not judge a proven change as low"
grep -q '^proof=evidence$' "$TMP/pd-gate.out" 2>/dev/null || miss "people decide: the gate does not tell the pipeline about the proof"
# 43f. the pipeline: no second reviewer on proven changes, merge by proof and not by author, no approvals
review=$(sed -n '/^  review:$/,/^  automerge:$/p' "$pipeline")
automerge=$(sed -n '/^  automerge:$/,$p' "$pipeline")
grep -q "needs.gate.outputs.proof == ''" <<<"$review" || miss "people decide: the reviewer agent runs again on a change the proof covers"
grep -q "needs.gate.outputs.proof != ''" <<<"$automerge" || miss "people decide: a proven change does not merge itself without the reviewer agent"
grep -q 'draft == false' <<<"$automerge" || miss "people decide: auto-merge may fire on a draft"
if grep -q 'AGENT_AUTHORS' "$pipeline"; then miss "people decide: auto-merge depends on who the author is"; fi
if grep -qE 'gh pr review|--approve' "$pipeline"; then miss "people decide: the pipeline approves pull requests"; fi
# a change that stops being low does not keep the auto-merge an earlier push turned on
mkdir -p "$TMP/holdbin"
cat > "$TMP/holdbin/gh" <<'SH'
#!/bin/sh
case "$1 $2" in
  "pr view") cat "$HOLD_STATE" ;;
  "pr merge") echo "$*" >> "$GH_CALLS"; if [ "$HOLD_CAN_DISABLE" = yes ]; then echo off > "$HOLD_STATE"; fi ;;
  *) exit 1 ;;
esac
SH
chmod +x "$TMP/holdbin/gh"
hold() { echo "$1" > "$TMP/hold-state"; rm -f "$TMP/hold-calls"
  ( PATH="$TMP/holdbin:$PATH" GH_CALLS="$TMP/hold-calls" HOLD_STATE="$TMP/hold-state" HOLD_CAN_DISABLE="$2" PR=7 \
    bash -e -c "$(steps_of 'Hold a change that is no longer low')" ) >/dev/null 2>&1; }
grep -A1 'Hold a change that is no longer low' "$pipeline" | grep "needs.tier.outputs.tier != 'low'" >/dev/null || miss "people decide: the hold does not run for every tier above low"
gate_job=$(sed -n '/^  gate:$/,/^  review:$/p' "$pipeline")
grep -q 'if: always()' <<<"$gate_job" || miss "people decide: the required check is skipped, and so counts as passed, when the tier job fails"
grep -q "needs.tier.result != 'success'" <<<"$gate_job" || miss "people decide: the required check passes without a tier"
grep -q 'contents: write' <<<"$gate_job" || miss "people decide: the job that turns auto-merge off may not do so"
if grep -q 'actions/checkout' <<<"$gate_job"; then miss "people decide: the job that may write checks out the pull request"; fi
sed -n '/^  tier:$/,/^  gate:$/p' "$pipeline" | grep 'contents: read' >/dev/null || miss "people decide: the job that reads the pull request may write"
( bash -e -c "$(steps_of 'Fail when the tier is unknown')" ) >/dev/null 2>&1 && miss "people decide: the step for an unknown tier does not fail"
hold off yes && [ ! -e "$TMP/hold-calls" ] || miss "people decide: the gate touches an auto-merge that is off"
hold on yes && grep -q '^pr merge 7 --disable-auto$' "$TMP/hold-calls" 2>/dev/null || miss "people decide: a change that stopped being low keeps its auto-merge"
if hold on no; then miss "people decide: the gate passes while auto-merge stays on for a change above low"; fi
if hold "" no; then miss "people decide: the gate passes without knowing whether auto-merge is on"; fi
# auto-merge on the strength of a proof only when GitHub itself requires that proof
mkdir -p "$TMP/prbin"
printf '#!/bin/sh\n[ "$1" = api ] || exit 1\n[ -f "$REQUIRED" ] || exit 1\ncat "$REQUIRED"\n' > "$TMP/prbin/gh"; chmod +x "$TMP/prbin/gh"
proof_required() { ( PATH="$TMP/prbin:$PATH" REQUIRED="$1" PROOF=evidence BASE=main GITHUB_REPOSITORY=acme/sample \
    bash -e -o pipefail -c "$(steps_of 'Require that GitHub requires the proof')" ) >/dev/null 2>&1; }
printf 'check\ngate\nevidence\n' > "$TMP/required-yes"; printf 'check\ngate\nevidence-old\n' > "$TMP/required-no"
proof_required "$TMP/required-yes" || miss "people decide: a required proof is not recognised"
if proof_required "$TMP/required-no"; then miss "people decide: auto-merge trusts a proof the branch does not require"; fi
if proof_required "$TMP/required-missing"; then miss "people decide: auto-merge trusts a proof when the rules cannot be read"; fi
grep -q "needs.gate.result == 'success'" <<<"$automerge" || miss "people decide: auto-merge may run although the gate failed"
# 43g. generated instructions add no stop of their own; settings ask nothing and keep the silent walls
for phrase in 'get approval before you start' 'ask in the issue and stop' 'need human review' 'need a human reviewer' 'one approval is required' '(high tier)'; do
  if grep -qiF "$phrase" "$pd/AGENTS.md" "$pd/CONTRIBUTING.md" "$pd/.github/pull_request_template.md" "$pd/ontology/README.md" "$ROOT/plugins/repo-setup/archetypes/service-api/starter/+AGENTS.md/40-service-api.md" "$ROOT/plugins/repo-setup/archetypes/service-api/starter/tools/api_compat.py"; then miss "people decide: generated text stops for a person: $phrase"; fi
done
grep -q 'never a reason to stop' "$pd/AGENTS.md" || miss "people decide: AGENTS.md does not say that a tier is no reason to stop"
# At team level the machine drafts a change to the rules in a pull request of its own (53a): the
# two edit walls are gone there, and the wall on reading secrets stays.
python3 - "$pd/.claude/settings.json" <<'PY' || miss "people decide: settings.json asks, blocks Bash by pattern, lost a silent wall, or still keeps the machine from drafting a rule change"
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8"))["permissions"]
assert not p.get("ask"), p.get("ask")
assert not [r for r in p["deny"] if r.startswith("Bash(")], p["deny"]
assert "Read(./.env)" in p["deny"], p["deny"]
for wall in ("Edit(./.github/workflows/**)", "Edit(./governance/**)"):
    assert wall not in p["deny"], wall
PY
if grep -q 'gate hook' "$ROOT/plugins/repo-setup/skills/explain/SKILL.md"; then miss "people decide: explain names a gate hook the plugin no longer ships"; fi
# 43h. the principle is written down where the next change to the plugin will find it
[ -f "$ROOT/docs/setup-principles.md" ] || miss "people decide: docs/setup-principles.md is missing"
grep -q 'docs/setup-principles.md' "$ROOT/README.md" || miss "people decide: README.md does not point to the principle"
grep -q 'setup-principles.md' "$ROOT/plugins/repo-setup/README.md" || miss "people decide: the plugin README does not point to the principle"
grep -q 'docs/setup-principles.md' "$ROOT/CLAUDE.md" 2>/dev/null || miss "people decide: the root CLAUDE.md does not point to the principle, so the next session will not load it"
# 43i. doctor: protection is a pull request plus required checks; it asks for no approval count
mkdir -p "$TMP/bpbin"
cat > "$TMP/bpbin/gh" <<'SH'
#!/bin/sh
case "$1 $2" in
  "repo view") echo '{"nameWithOwner":"acme/sample","defaultBranchRef":{"name":"main"}}' ;;
  "api repos/acme/sample/branches/main/protection") echo 'Not Found (HTTP 404)' >&2; exit 1 ;;
  "api repos/acme/sample/rules/branches/main") cat "$FAKE_RULES" ;;
  *) exit 1 ;;
esac
SH
chmod +x "$TMP/bpbin/gh"
bp_verdict() { PATH="$TMP/bpbin:$PATH" FAKE_RULES="$TMP/rules.json" verdict "$pd" branch_protection '--level team --remote'; }
echo '[{"type":"pull_request","parameters":{"required_approving_review_count":0,"require_code_owner_review":true}},{"type":"required_status_checks"}]' > "$TMP/rules.json"
bp_verdict | grep '^pass$' >/dev/null || miss "people decide: doctor wants an approval count: $(bp_verdict)"
echo '[{"type":"required_status_checks"}]' > "$TMP/rules.json"
bp_verdict | grep '^fail' >/dev/null || miss "people decide: doctor accepts a branch that needs no pull request: $(bp_verdict)"
echo '[{"type":"pull_request","parameters":{"required_approving_review_count":1,"require_code_owner_review":true}}]' > "$TMP/rules.json"
bp_verdict | grep '^fail' >/dev/null || miss "people decide: doctor accepts approvals in place of required checks: $(bp_verdict)"
# with two deciders for the rules, a ruleset without code owner review has lost them (53d)
pd2="$TMP/people-decide-two"; rm -rf "$pd2"; cp -R "$pd" "$pd2"
subst 's|^  high: \[.*\]$|  high: ["@acme", "@lan"]|' "$pd2/governance/autonomy.yaml"
bp_two() { PATH="$TMP/bpbin:$PATH" FAKE_RULES="$TMP/rules.json" verdict "$pd2" branch_protection '--level team --remote'; }
echo '[{"type":"pull_request","parameters":{"required_approving_review_count":1,"require_code_owner_review":false}},{"type":"required_status_checks"}]' > "$TMP/rules.json"
bp_two | grep '^fail' >/dev/null || miss "people decide: doctor accepts a branch where the rules have lost their deciders: $(bp_two)"
# with one decider the owner's merge is the decision: no code owner review is what github_setup writes
echo '[{"type":"pull_request","parameters":{"required_approving_review_count":0,"require_code_owner_review":false}},{"type":"required_status_checks"}]' > "$TMP/rules.json"
bp_verdict | grep '^pass' >/dev/null || miss "people decide: doctor fails a one-owner repository for the ruleset github_setup writes it: $(bp_verdict)"
bp_two | grep '^fail' >/dev/null || miss "people decide: doctor accepts no code owner review with two deciders: $(bp_two)"
# one decider and an approval count: the owner cannot approve their own pull request, so nothing merges
echo '[{"type":"pull_request","parameters":{"required_approving_review_count":1,"require_code_owner_review":false}},{"type":"required_status_checks"}]' > "$TMP/rules.json"
bp_verdict | grep '^fail' >/dev/null || miss "people decide: doctor accepts a one-owner ruleset that asks for an approval the owner cannot give: $(bp_verdict)"
# a tools/autonomy.py from before the rule: its github_setup.py still asks for the review, and so does doctor
pd_old="$TMP/people-decide-old"; rm -rf "$pd_old"; cp -R "$pd" "$pd_old"
python3 - "$pd_old/tools/autonomy.py" <<'PY'
import re, sys
f = sys.argv[1]; t = open(f, encoding="utf-8").read()
t, n = re.subn(r"(?ms)^def sole_decider\(.*?(?=^def )", "", t)
assert n == 1; open(f, "w", encoding="utf-8").write(t)
PY
echo '[{"type":"pull_request","parameters":{"required_approving_review_count":0,"require_code_owner_review":false}},{"type":"required_status_checks"}]' > "$TMP/rules.json"
bp_old() { PATH="$TMP/bpbin:$PATH" FAKE_RULES="$TMP/rules.json" verdict "$pd_old" branch_protection '--level team --remote'; }
bp_old | grep '^fail' >/dev/null || miss "people decide: doctor accepts no code owner review where the repository's tools predate the one-decider rule: $(bp_old)"
# 43j. a ruleset from an earlier run is brought up to date, so an upgrade reaches the repository
mkdir -p "$TMP/rsbin"
cat > "$TMP/rsbin/gh" <<'SH'
#!/bin/sh
case "$1 $2" in
  "repo view") echo '{"nameWithOwner":"acme/sample","defaultBranchRef":{"name":"main"}}' ;;
  "secret list") ;;
  "api repos/acme/sample/rulesets") cat "$FAKE_RULESET_IDS" ;;
  "api repos/acme/sample/rulesets/41") [ "$3" = "--jq" ] && { [ -f "${FAKE_CHECKS:-}" ] && cat "$FAKE_CHECKS"; true; } || echo "$*" >> "$GH_CALLS" ;;
  "api -H")   # a read: a file of the default branch, here the repository's own
    [ -z "${RS_BASE_DOWN:-}" ] || { echo "gh: Server Error (HTTP 502)" >&2; exit 1; }
    cat "./$(echo "$4" | sed 's|^repos/acme/sample/contents/||; s|?ref=main$||')" ;;
  *) echo "$*" >> "$GH_CALLS"
     case "$*" in *rulesets*"--input -"*) cat > "$GH_CALLS.body" ;; esac ;;
esac
SH
chmod +x "$TMP/rsbin/gh"
ruleset_call() { echo "$1" > "$TMP/ruleset-ids"; rm -f "$TMP/rs-calls"
  ( cd "$pd" && PATH="$TMP/rsbin:$PATH" GH_CALLS="$TMP/rs-calls" FAKE_RULESET_IDS="$TMP/ruleset-ids" \
    python3 -B tools/github_setup.py --apply </dev/null ) >/dev/null 2>&1 || true
  grep 'rulesets' "$TMP/rs-calls" 2>/dev/null || true; }
[ "$(ruleset_call '')" = "api -X POST repos/acme/sample/rulesets --input -" ] || miss "people decide: a first run does not create the ruleset: $(ruleset_call '')"
[ "$(ruleset_call 41)" = "api -X PUT repos/acme/sample/rulesets/41 --input -" ] || miss "people decide: an old ruleset keeps asking for an approval after the upgrade: $(ruleset_call 41)"
# 43k. every rule of docs/setup-principles.md has a row in "Luật nằm ở đâu trong mã", and every test
#      section that row names exists; the three principles of the overview design (section 4: one
#      check one place, one writer per file, the ladder) are rules there (RS6)
principles_hold() { # <page>: prints what does not hold, exits 1 when anything does not
  python3 - "$1" "$ROOT/tests" <<'PY'
import pathlib, re, sys
page, tests = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"), pathlib.Path(sys.argv[2])
headers = "\n".join(p.read_text(encoding="utf-8") for p in sorted(tests.glob("*.sh")))
rules_part = page.split("## Mười một luật", 1)[1].split("\n## ", 1)[0] if "## Mười một luật" in page else ""
rules = {int(n): title for n, title in re.findall(r"^(\d+)\. \*\*(.+?)\*\*", rules_part, re.M)}
table = page.split("## Luật nằm ở đâu trong mã", 1)[-1].split("\n## ", 1)[0]
rows = {int(m.group(1)): m.group(2) for m in re.finditer(r"^\| (\d+) \|.*\| ([^|]+) \|$", table, re.M)}
bad = [f"rule {n} ({title}) has no row" for n, title in sorted(rules.items()) if n not in rows]
for n, ids in sorted(rows.items()):
    for tid in re.findall(r"\b\d{2}[a-z]*\b", ids):
        if not re.search(rf"^# {tid}[.\s(]", headers, re.M):
            bad.append(f"rule {n} names test section {tid}, which no file in tests/ has")
for title in ("Một phép kiểm, một chỗ.", "Mỗi tệp một người ghi.", "Bậc thang thay người."):
    if title not in rules.values():
        bad.append(f"the principle «{title}» is not a rule of the page")
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
}
out=$(principles_hold "$ROOT/docs/setup-principles.md") || miss "people decide: the principles page does not hold: $out"
# the red direction, on copies: a rule without a row, a row that names a section nobody has
cp "$ROOT/docs/setup-principles.md" "$TMP/principles-norow.md"
subst '/^| 9 | /d' "$TMP/principles-norow.md"
if principles_hold "$TMP/principles-norow.md" >/dev/null; then miss "people decide: a rule without a row in the table goes unseen"; fi
cp "$ROOT/docs/setup-principles.md" "$TMP/principles-noid.md"
subst 's/^\(| 8 | .*| \)49a, /\199z, /' "$TMP/principles-noid.md"
if principles_hold "$TMP/principles-noid.md" >/dev/null; then miss "people decide: a row that names a test section nobody has goes unseen"; fi
echo "ok  people decide, machines check (or misses reported above)"

# 44. real walls (docs/superpowers/specs/2026-11-16-real-walls-design.md): a check that carries the
#     name of a wall must be able to go red.
rw="$TMP/real-walls"; mkdir -p "$rw" && git -C "$rw" init -q -b main
python3 "$S/apply.py" --target "$rw" --preset ts-node --level team --var project_name=P --var description=x --var owner=acme >/dev/null
# 44a. the secret scan in CI reads commits, not the staging area that CI leaves empty
for preset in ts-node python claude-plugin; do
  grep -q 'pre-commit run gitleaks-history --hook-stage manual' "$ROOT/plugins/repo-setup/presets/$preset/team/dot.github/workflows/security.yml" \
    || miss "real walls: the $preset secret scan still reads the staging area, which CI leaves empty"
done
scan=$({ grep -A4 'alias: gitleaks-history' "$rw/.pre-commit-config.yaml" || true; } | sed -n 's/^ *entry: //p')
[ -n "$scan" ] || miss "real walls: no gitleaks hook for CI in .pre-commit-config.yaml"
case "$scan" in *--staged*) miss "real walls: the CI secret scan reads staged changes only" ;; esac
case "$scan" in *--log-opts=HEAD*) ;; *) miss "real walls: the CI secret scan reads other branches, so one leak turns every pull request red" ;; esac
{ grep -A4 'alias: gitleaks-history' "$rw/.pre-commit-config.yaml" || true; } | grep 'stages: \[manual\]' >/dev/null || miss "real walls: the CI secret scan also runs on every local commit"
# 44b. the red direction: a token in a commit turns the scan red, also after a later commit deletes it
rw_save() { git -C "$rw" add -A && git -C "$rw" -c user.name=t -c user.email=t@example.com commit -q -m "$1"; }
rw_scan() { ( cd "$rw" && $scan >/dev/null 2>&1 ); }
if command -v gitleaks >/dev/null 2>&1 && [ -n "$scan" ]; then
  rw_save "chore: base"
  rw_scan || miss "real walls: the secret scan is red on a clean repository"
  # Made at run time, so no token-shaped text sits in this file.
  python3 -c "import random, string; print('const token = \"ghp_' + ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(36)) + '\";')" > "$rw/src/planted.ts"
  rw_save "feat: planted"
  # rule-check: secret-scan
  if rw_scan; then miss "real walls: a committed token passes the secret scan"; fi
  git -C "$rw" rm -q src/planted.ts && rw_save "fix: remove the token"
  if rw_scan; then miss "real walls: a token deleted by a later commit passes the secret scan"; fi
  git -C "$rw" checkout -q -b clean "$(git -C "$rw" rev-list --max-parents=0 HEAD)"
  rw_scan || miss "real walls: a leak on another branch turns a clean branch red"
  git -C "$rw" checkout -q main
else
  echo "skip  real walls 44b: gitleaks is not installed, the red direction was not run"
fi
# 44c. Release is not red for want of a key: without the key it says so and ends green
rel="$rw/.github/workflows/release.yml"
if grep -q 'github.token' "$rel"; then miss "real walls: Release falls back to the Actions token, which may not open pull requests"; fi
grep -q "secrets.RELEASE_PLEASE_TOKEN != ''" "$rel" || miss "real walls: Release does not look at whether its key exists"
grep -q "if: env.HAS_RELEASE_TOKEN == 'true'" "$rel" || miss "real walls: release-please runs without its key"
grep -q "if: env.HAS_RELEASE_TOKEN != 'true'" "$rel" || miss "real walls: Release without a key says nothing"
dry "$rw" | grep 'RELEASE_PLEASE_TOKEN is missing: releases are off' >/dev/null || miss "real walls: github_setup does not say that releases are off"
mkdir -p "$TMP/rkbin"
cat > "$TMP/rkbin/gh" <<'SH'
#!/bin/sh
case "$1 $2" in
  "repo view") echo '{"nameWithOwner":"acme/sample","defaultBranchRef":{"name":"main"}}' ;;
  "secret list") cat "$FAKE_SECRETS" ;;
  *) exit 1 ;;
esac
SH
chmod +x "$TMP/rkbin/gh"
rk_verdict() { PATH="$TMP/rkbin:$PATH" FAKE_SECRETS="$TMP/secrets" verdict "$rw" release_key '--level team --remote'; }
: > "$TMP/secrets"
rk_verdict | grep '^fail' >/dev/null || miss "real walls: doctor is content with releases that have no key: $(rk_verdict)"
echo RELEASE_PLEASE_TOKEN > "$TMP/secrets"
rk_verdict | grep '^pass$' >/dev/null || miss "real walls: doctor does not see the release key: $(rk_verdict)"
# 44d. the commit-format check judges what reaches the default branch: the title when squashing, the commits otherwise
pt="$rw/.github/workflows/pr-title.yml"
for job in conventional-title conventional-commits; do
  grep -q "^  $job:\$" "$pt" || miss "real walls: pr-title.yml has no $job job"
done
grep -q 'squashMergeAllowed' "$pt" || miss "real walls: the title check does not read whether the repository squashes"
grep -q 'mergeCommitAllowed' "$pt" || miss "real walls: the commit check does not read whether the repository keeps commits"
grep -q 'pre-commit run --hook-stage commit-msg' "$pt" || miss "real walls: commits are not judged by the repository's own commit-msg hooks"
if grep -q 'pre-commit run conventional-pre-commit' "$pt"; then
  miss "real walls: the commit check names one hook id, so a repository with its own commit-msg hook is red on every pull request"
fi
# the commit check, run with stand-ins for gh (two commits, the second one given) and for the hook
pipeline="$pt"
mkdir -p "$TMP/ccbin" "$TMP/ccrun"
cat > "$TMP/ccbin/gh" <<'SH'
#!/bin/sh
case "$1 $2" in
  "repo view") [ "$CC_KEEPS" = unreadable ] && exit 1; echo "$CC_KEEPS" ;;
  "api --paginate") printf 'aaa\nbbb\n' ;;
  "api repos/acme/sample/commits/aaa") echo "feat: one" ;;
  "api repos/acme/sample/commits/bbb") cat "$CC_SECOND" ;;
  *) exit 1 ;;
esac
SH
cat > "$TMP/ccbin/pipx" <<'SH'
#!/bin/sh
# Stand-in for `pipx run pre-commit run [<hook id>] --hook-stage commit-msg --commit-msg-filename <file>`.
# Like pre-commit, it refuses a hook id the repository's config does not have; then it judges the
# message in the file given last.
case "${4:-}" in
  --*|"") ;;
  *) grep -q "id: $4\$" .pre-commit-config.yaml || { echo "No hook with id $4 in stage commit-msg"; exit 1; } ;;
esac
for a in "$@"; do f=$a; done
echo "$f" >> "$CC_CALLS"
# With no hook at commit-msg, pre-commit runs nothing on the message and ends green.
grep -v '^default_install_hook_types' .pre-commit-config.yaml | grep 'commit-msg\|id: conventional-pre-commit$' >/dev/null || exit 0
case "${CC_HOOK:-format}" in
  # pre-commit itself cannot run (its own words)
  broken) echo "An error has occurred: InvalidConfigError: "; echo "=====> .pre-commit-config.yaml is not a file"; exit 1 ;;
  # the same, with a line in its output that reads like a workflow command
  brokenforged) echo "::warning::forged by a hook"; echo "An error has occurred: InvalidConfigError: "; exit 1 ;;
  # a hook whose only rule is the length of the first line
  maxlen) [ "$(head -1 "$f" | wc -c)" -le 73 ]; exit $? ;;
  # a hook repository pre-commit cannot fetch: its other wording, and exit code 3
  unfetched) echo "An unexpected error has occurred: CalledProcessError: command: ('git', 'fetch', 'origin', '--tags')"; exit 3 ;;
  # the network fails only once the commits are judged: the probes were answered
  flaky) case "$f" in */message) echo "An unexpected error has occurred: CalledProcessError: command: ('git', 'fetch', 'origin', '--tags')"; exit 3 ;; esac ;;
esac
grep -qE '^(feat|fix|chore|docs|test|refactor|perf|ci)(\([a-z-]+\))?!?: .+' "$f" || { echo "stand-in: refused"; cat "$f"; exit 1; }
SH
chmod +x "$TMP/ccbin/gh" "$TMP/ccbin/pipx"
cc() { : > "$TMP/cc-calls"; echo "$2" > "$TMP/cc-second"
  ( cd "${CC_REPO:-$rw}" && PATH="$TMP/ccbin:$PATH" CC_KEEPS="$1" CC_SECOND="$TMP/cc-second" CC_CALLS="$TMP/cc-calls" CC_HOOK="${CC_HOOK:-format}" PR=7 GITHUB_REPOSITORY=acme/sample \
    RUNNER_TEMP="$TMP/ccrun" GITHUB_STEP_SUMMARY="$TMP/cc-summary" bash -e -c "$(steps_of 'Check every commit the branch would add')" ) 2>&1; }
cc true 'fix: two' >/dev/null || miss "real walls: the commit check rejects a branch whose commits are all conventional"
[ "$(grep -c '/message$' "$TMP/cc-calls")" = 2 ] || miss "real walls: the commit check did not judge both commits"
# rule-check: commit-format
if cc true 'changed stuff' >/dev/null; then miss "real walls: the commit check accepts a commit that is not conventional"; fi
{ cc true 'changed stuff' || true; } | grep '::error::Commit bbb' >/dev/null || miss "real walls: the commit check does not name the commit it rejects"
cc false 'changed stuff' >/dev/null || miss "real walls: the commit check judges commits in a repository that squashes"
[ ! -s "$TMP/cc-calls" ] || miss "real walls: the commit check ran the hook in a repository that squashes"
{ cc unreadable 'changed stuff' || true; } | grep '::warning::' >/dev/null || miss "real walls: the commit check is silent when it cannot read how the repository merges"
# a repository that replaced the hook with one of its own (another id) is still judged, by that hook;
# one with no commit-msg hook at all is red and says so: a green check that judges nothing is no wall
mkdir -p "$TMP/cc-own" "$TMP/cc-block" "$TMP/cc-bare" "$TMP/cc-none"
python3 - "$rw/.pre-commit-config.yaml" "$TMP/cc-own" "$TMP/cc-block" "$TMP/cc-bare" "$TMP/cc-none" <<'PY_CC'
import sys
src, own, block, bare, none = sys.argv[1:]
text = open(src, encoding="utf-8").read()
mark = "  - repo: https://github.com/compilerla/conventional-pre-commit"
head, found, tail = text.partition(mark)
assert found, "the sample config has no conventional-pre-commit block"
rest = tail.split("\n  - repo:", 1)
after = "\n  - repo:" + rest[1] if len(rest) == 2 else "\n"
hook = ("  - repo: local\n    hooks:\n      - id: commit-message\n        name: Commit message\n"
        "        entry: python3 tools/commit_msg.py\n        language: system\n")
def write(folder, body):
    open(f"{folder}/.pre-commit-config.yaml", "w", encoding="utf-8").write(body)
write(own, head + hook + "        stages: [commit-msg]" + after)
write(block, head + hook + "        stages:\n          - pre-commit\n          - \"commit-msg\"" + after)
# the hook listed with no `stages` line: its own manifest puts it at commit-msg
write(bare, text.replace("      - id: conventional-pre-commit\n        stages: [commit-msg]\n",
                         "      - id: conventional-pre-commit\n"))
assert "stages: [commit-msg]" not in open(f"{bare}/.pre-commit-config.yaml", encoding="utf-8").read()
write(none, head.rstrip("\n") + after)
PY_CC
for own in cc-own cc-block cc-bare; do
  CC_REPO="$TMP/$own" cc true 'fix: two' >/dev/null || miss "real walls: the commit check is red in a repository whose commit-msg hook is written another way ($own)"
  if CC_REPO="$TMP/$own" cc true 'changed stuff' >/dev/null; then miss "real walls: the commit check accepts a bad commit in a repository whose commit-msg hook is written another way ($own)"; fi
done
# a hook that judges something else than the format (here only the length of the title) is a wall too
CC_HOOK=maxlen cc true 'any words at all' >/dev/null || miss "real walls: the commit check calls a length-only commit-msg hook no hook"
long_title=$(printf '%0100d' 0)
if CC_HOOK=maxlen cc true "$long_title" >/dev/null; then miss "real walls: the commit check accepts a commit the length-only hook refuses"; fi
# pre-commit that cannot run is said to be that: the commits are not blamed
if CC_HOOK=broken cc true 'fix: two' >/dev/null; then miss "real walls: the commit check is green when pre-commit cannot run"; fi
{ CC_HOOK=broken cc true 'fix: two' || true; } | grep '::error::pre-commit could not run' >/dev/null || miss "real walls: the commit check does not say that pre-commit could not run"
if { CC_HOOK=broken cc true 'fix: two' || true; } | grep '::error::Commit ' >/dev/null; then miss "real walls: the commit check blames the commits when pre-commit cannot run"; fi
for how in unfetched flaky; do
  if CC_HOOK=$how cc true 'fix: two' >/dev/null; then miss "real walls: the commit check is green when pre-commit ends with an unexpected error ($how)"; fi
  { CC_HOOK=$how cc true 'fix: two' || true; } | grep '::error::pre-commit could not run' >/dev/null || miss "real walls: the commit check does not say that pre-commit could not run ($how)"
  if { CC_HOOK=$how cc true 'fix: two' || true; } | grep '::error::Commit ' >/dev/null; then miss "real walls: the commit check blames the commits for an unexpected error of pre-commit ($how)"; fi
done
# what the hook said about a refused commit is in the log, for whoever has to fix the message
{ cc true 'changed stuff' || true; } | grep 'stand-in: refused' >/dev/null || miss "real walls: the commit check hides what the hook said about the commit it refuses"
# hooks print the message back: a refused commit that holds pre-commit's error words is still a refused commit
for words in 'An error has occurred in login' 'An unexpected error has occurred: the page is blank'; do
  if cc true "$words" >/dev/null; then miss "real walls: the commit check accepts a bad commit whose message holds pre-commit's error words ($words)"; fi
  { cc true "$words" || true; } | grep '::error::Commit bbb' >/dev/null || miss "real walls: the commit check does not name a refused commit whose message holds pre-commit's error words ($words)"
  if { cc true "$words" || true; } | grep '::error::pre-commit could not run' >/dev/null; then miss "real walls: the commit check reads a refused commit as pre-commit failing, from words in its message ($words)"; fi
done
# what a hook prints may hold the commit message, and its author wrote that: the job runs from the
# default branch (pull_request_target), so no line of it may reach the runner as a workflow command.
# cc_fenced <output file> <text>: every line holding the text is inside a ::stop-commands:: fence
# that is closed again, and the job's own verdict is outside one.
cc_fenced() { python3 - "$1" "$2" <<'PY_FENCE'
import re, sys
lines, text = open(sys.argv[1], encoding="utf-8").read().splitlines(), sys.argv[2]
fence, inside, outside, verdict, tokens = None, 0, 0, 0, []
for line in lines:
    if fence is None:
        opened = re.fullmatch(r"::stop-commands::([0-9a-f]{32,})", line)
        if opened:
            fence = opened.group(1); tokens.append(fence)
        elif line.startswith("::error::Commit bbb") or line.startswith("::error::pre-commit could not run"):
            verdict += 1  # the job's own line: it may quote the title, after its own words
        elif text in line and line.startswith("::"):
            outside += 1
    elif line == f"::{fence}::":
        fence = None
    elif text in line:
        inside += 1
print("ok" if fence is None and inside and not outside and verdict == 1 and len(set(tokens)) == len(tokens)
      else f"inside={inside} outside={outside} verdict={verdict} open={fence is not None} tokens={len(tokens)}")
print(" ".join(tokens))
PY_FENCE
}
forged=$(printf 'changed stuff\n\n::error file=README.md::forged by the author\n::add-mask::changed')
{ cc true "$forged" || true; } > "$TMP/cc-forged-1"; { cc true "$forged" || true; } > "$TMP/cc-forged-2"
[ "$(cc_fenced "$TMP/cc-forged-1" 'forged by the author' | head -1)" = ok ] \
  || miss "real walls: a line of a refused commit's message reaches the runner as a workflow command ($(cc_fenced "$TMP/cc-forged-1" 'forged by the author' | head -1))"
[ "$(cc_fenced "$TMP/cc-forged-1" 'forged' | tail -1)" != "$(cc_fenced "$TMP/cc-forged-2" 'forged' | tail -1)" ] \
  || miss "real walls: the fence around what a hook printed has the same token on every run"
# the first line of a refused message is quoted in the job's own error line: a carriage return in
# it must not start a line of its own
{ cc true "$(printf 'changed\r::warning::forged after a return')" || true; } > "$TMP/cc-forged-cr"
[ "$(cc_fenced "$TMP/cc-forged-cr" 'forged after a return' | head -1)" = ok ] \
  || miss "real walls: a carriage return in a commit title starts a workflow command ($(cc_fenced "$TMP/cc-forged-cr" 'forged after a return' | head -1))"
# a percent sign in the title is escaped, so the runner does not turn `%0A` into a line break
{ cc true 'changed %0A::warning::forged by percent' || true; } | grep '^::error::Commit bbb .*changed %250A::warning::forged by percent$' >/dev/null \
  || miss "real walls: a percent sign in a commit title is handed to the runner unescaped"
# no token, no fence: what the hook printed is then not shown at all, and the job is red
cc_od=$(command -v od)
printf '#!/bin/sh\n[ -z "${CC_NO_OD:-}" ] || exit 1\nexec %s "$@"\n' "$cc_od" > "$TMP/ccbin/od"; chmod +x "$TMP/ccbin/od"
if CC_NO_OD=1 cc true "$forged" > "$TMP/cc-forged-no-od" 2>&1; then miss "real walls: the commit check is green when it cannot fence what a hook printed"; fi
if grep -q 'forged by the author' "$TMP/cc-forged-no-od"; then miss "real walls: without a fence, what the hook printed is shown all the same"; fi
grep -q '^::error::.*could not be shown safely' "$TMP/cc-forged-no-od" || miss "real walls: the commit check does not say why it shows nothing of the hook"
# the hooks run with no token of the repository left in the checkout
grep -A3 'uses: actions/checkout' "$pt" | grep 'persist-credentials: false' >/dev/null || miss "real walls: the commit check leaves the checkout's token where the hooks run"
# the same when pre-commit could not run: what it printed is shown, and read as text only
{ CC_HOOK=brokenforged cc true 'fix: two' || true; } > "$TMP/cc-forged-3"
[ "$(cc_fenced "$TMP/cc-forged-3" 'forged by a hook' | head -1)" = ok ] \
  || miss "real walls: a line pre-commit printed when it could not run reaches the runner as a workflow command ($(cc_fenced "$TMP/cc-forged-3" 'forged by a hook' | head -1))"
if CC_REPO="$TMP/cc-none" cc true 'fix: two' >/dev/null; then miss "real walls: the commit check is green in a repository with no commit-msg hook"; fi
{ CC_REPO="$TMP/cc-none" cc true 'fix: two' || true; } | grep -i '::error::.*no hook.*commit-msg' >/dev/null || miss "real walls: the commit check does not say that no hook judges the commits"
if grep -q 'pr-title.yml' "$ROOT/plugins/repo-setup/skills/github/SKILL.md"; then
  miss "real walls: the github skill still asks a person to edit pr-title.yml by hand"
fi
if grep -q 'nothing checks them' "$ROOT/plugins/repo-setup/skills/github/SKILL.md"; then
  miss "real walls: the github skill still says nothing checks the commits of a branch"
fi
# 44e. the ruleset requires the checks the repository names, and the secret scan
rw_policy="$rw/governance/autonomy.yaml"; cp "$rw_policy" "$TMP/rw-policy.orig"
rw_checks() { python3 - "$rw_policy" "$TMP/rw-policy.orig" "$1" <<'PY'
import re, sys
out, src, value = sys.argv[1:]
t = open(src, encoding="utf-8").read()
t, n = re.subn(r"(?m)^required_checks: .*$", f"required_checks: {value}", t)
assert n == 1, n
open(out, "w", encoding="utf-8").write(t)
PY
}
rw_governance_ok() { ( cd "$rw" && python3 tools/autonomy.py --write-codeowners >/dev/null && python3 tools/autonomy.py --check-codeowners >/dev/null 2>&1 ); }
grep -q '^required_checks: \[\]$' "$rw_policy" || miss "real walls: the sample policy has no required_checks to fill in"
dry "$rw" | grep 'checks check, secret-scan, conventional-title, conventional-commits$' >/dev/null || miss "real walls: the secret scan is not a required check: $(dry "$rw" | grep 'ruleset on')"
rw_checks '[e2e, e2e-db]' 2>/dev/null || true
rw_governance_ok || miss "real walls: a policy that names its own checks was refused"
dry "$rw" | grep 'checks check, secret-scan, conventional-title, conventional-commits, e2e, e2e-db$' >/dev/null || miss "real walls: github_setup does not require the checks the policy names: $(dry "$rw" | grep 'ruleset on')"
# `gate` is the setup's own only with agent workflows, which this repository has not: section 51a.
for reserved in check secret-scan; do
  rw_checks "[$reserved]" 2>/dev/null || true
  if rw_governance_ok; then miss "real walls: the setup's own check '$reserved' was accepted under required_checks"; fi
done
# 44f. an upgrade never drops a required check that nobody named: it stops and says which
echo 41 > "$TMP/rw-ids"
rw_apply() { rm -f "$TMP/rw-calls"
  ( cd "$rw" && PATH="$TMP/rsbin:$PATH" GH_CALLS="$TMP/rw-calls" FAKE_RULESET_IDS="$TMP/rw-ids" FAKE_CHECKS="$TMP/rw-checks" \
    python3 -B tools/github_setup.py --apply "$@" </dev/null ) 2>&1; }
rw_put() { { grep -- '-X PUT repos/acme/sample/rulesets/41' "$TMP/rw-calls" 2>/dev/null || true; } | wc -l | tr -d ' '; }
printf 'check\ne2e\n' > "$TMP/rw-checks"
rw_checks '[]' 2>/dev/null || true
out=$(rw_apply || true)
[ "$(rw_put)" = 0 ] || miss "real walls: an upgrade dropped the required check e2e that the policy does not name"
grep -q 'e2e' <<<"$out" || miss "real walls: the refusal does not say which required check would go"
grep -q -- '--prune' <<<"$out" || miss "real walls: the refusal does not say how to drop the check on purpose"
rw_apply --prune >/dev/null || true
[ "$(rw_put)" = 1 ] || miss "real walls: --prune does not update the ruleset"
rw_checks '[e2e]' 2>/dev/null || true
rw_apply >/dev/null || true
[ "$(rw_put)" = 1 ] || miss "real walls: a ruleset whose extra check is named in the policy was not updated"
printf 'check\ne2e\n' > "$TMP/rw-checks"; rw_checks '[]' 2>/dev/null || true
{ rw_apply --prune || true; } | grep 'dropping the required check(s) e2e' >/dev/null || miss "real walls: --prune does not say which required check it drops"
cp "$TMP/rw-policy.orig" "$rw_policy"
# 44g. what GitHub would not say is not taken for "none": no second ruleset, no "missing" secret
mkdir -p "$TMP/nrbin"
cat > "$TMP/nrbin/gh" <<'SH'
#!/bin/sh
case "$1 $2" in
  "repo view") echo '{"nameWithOwner":"acme/sample","defaultBranchRef":{"name":"main"}}' ;;
  *) echo "$*" >> "$GH_CALLS"; exit 1 ;;
esac
SH
chmod +x "$TMP/nrbin/gh"
nr() { rm -f "$TMP/nr-calls"; ( cd "$rw" && PATH="$TMP/nrbin:$PATH" GH_CALLS="$TMP/nr-calls" python3 -B tools/github_setup.py "$@" </dev/null ) 2>&1 || true; }
out=$(nr)
grep -q 'could not be listed' <<<"$out" || miss "real walls: github_setup is silent when it cannot list the secrets"
if grep -q 'is missing' <<<"$out"; then miss "real walls: github_setup calls a secret missing when it could not list the secrets"; fi
grep -q 'rulesets could not be read' <<<"$out" || miss "real walls: the dry run is silent when it cannot read the rulesets"
nr --apply >/dev/null
if grep -q -- '-X POST repos/acme/sample/rulesets' "$TMP/nr-calls" 2>/dev/null; then miss "real walls: github_setup made a ruleset without knowing whether one exists"; fi
# 44h. a required check must be one that a job reports
rw_checks '[e2e, ""]' 2>/dev/null || true
if rw_governance_ok; then miss "real walls: an empty name was accepted under required_checks"; fi
cp "$TMP/rw-policy.orig" "$rw_policy"
mv "$rw/.github/workflows/security.yml" "$TMP/security.yml.kept"
dry "$rw" | grep 'checks check, conventional-title, conventional-commits$' >/dev/null || miss "real walls: secret-scan is required in a repository where no job has that name: $(dry "$rw" | grep 'ruleset on')"
dry "$rw" | grep 'secret-scan is not a required check' >/dev/null || miss "real walls: github_setup does not say that secret-scan is not required"
mv "$TMP/security.yml.kept" "$rw/.github/workflows/security.yml"
# 44i. CodeQL says it is off where code scanning is not enabled, and ends green; any other answer
#      runs it. A private repository needs GitHub Advanced Security, and a check that is red
#      whatever the code says teaches people to ignore red.
cs_step() {
  python3 - "$1" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
start = next(n for n, line in enumerate(lines) if line.strip() == "id: scanning")
run = next(n for n in range(start, len(lines)) if lines[n].strip() == "run: |")
indent = len(lines[run]) - len(lines[run].lstrip())
body = []
for line in lines[run + 1:]:
    if line.strip() and len(line) - len(line.lstrip()) <= indent:
        break
    body.append(line)
print("\n".join(body))
PY
}
mkdir -p "$TMP/csbin"
cat > "$TMP/csbin/gh" <<'SH'
#!/bin/sh
# What GitHub answers to a list of code scanning analyses, as gh prints it.
case "$CS_ANSWER" in
  off) echo '{"message":"Code scanning is not enabled for this repository. Please enable code scanning in the repository settings.","status":"403"}'
       echo "gh: Code scanning is not enabled for this repository. Please enable code scanning in the repository settings. (HTTP 403)" >&2; exit 1 ;;
  ghas) echo "gh: Advanced Security must be enabled for this repository to use code scanning. (HTTP 403)" >&2; exit 1 ;;
  none) echo '{"message":"no analysis found","status":"404"}'; echo "gh: no analysis found (HTTP 404)" >&2; exit 1 ;;
  denied) echo "gh: Resource not accessible by integration (HTTP 403)" >&2; exit 1 ;;
  *) echo '[]' ;;
esac
SH
chmod +x "$TMP/csbin/gh"
cs_run() {
  : > "$TMP/cs-out"; : > "$TMP/cs-summary"
  ( PATH="$TMP/csbin:$PATH" CS_ANSWER="$2" GITHUB_REPOSITORY=acme/sample GITHUB_OUTPUT="$TMP/cs-out" \
    GITHUB_STEP_SUMMARY="$TMP/cs-summary" bash -e -c "$1" ) >/dev/null 2>&1 || echo "step failed" >> "$TMP/cs-out"
  cat "$TMP/cs-out"
}
for preset in ts-node python claude-plugin; do
  sec="$ROOT/plugins/repo-setup/presets/$preset/team/dot.github/workflows/security.yml"
  job=$(sed -n '/^  codeql:/,$p' "$sec")
  grep -q 'actions: read' <<<"$job" || miss "real walls: the $preset CodeQL job may not read its own run, which a private repository needs"
  for uses in actions/checkout github/codeql-action/init github/codeql-action/analyze; do
    grep -A1 "uses: $uses" <<<"$job" | grep "if: steps.scanning.outputs.on != 'false'" >/dev/null \
      || miss "real walls: the $preset CodeQL job runs $uses where code scanning is off"
  done
  step=$(cs_step "$sec" 2>/dev/null || true)
  [ -n "$step" ] || { miss "real walls: the $preset CodeQL job does not ask whether code scanning is on"; continue; }
  for answer in off ghas; do
    [ "$(cs_run "$step" $answer)" = "on=false" ] || miss "real walls: the $preset CodeQL job runs where GitHub says code scanning is off ($answer): $(cs_run "$step" $answer)"
  done
  grep -q 'CodeQL is off' "$TMP/cs-summary" || miss "real walls: the $preset CodeQL job is off without saying so"
  for answer in none denied list; do
    [ "$(cs_run "$step" $answer)" = "on=true" ] || miss "real walls: the $preset CodeQL job is off on an answer that does not say so ($answer): $(cs_run "$step" $answer)"
  done
done
# 44j. the commit-format checks are required, once the default branch defines them: they run from
#      the default branch (pull_request_target), and a required check that never reports blocks
#      every pull request, the upgrade that brings the job included
gs_base="$TMP/gs-base"; mkdir -p "$gs_base/.github/workflows"
python3 - "$rw/.github/workflows/pr-title.yml" "$gs_base/.github/workflows/pr-title.yml" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
cut = text.index("\n  conventional-commits:")
open(sys.argv[2], "w", encoding="utf-8").write(text[:cut] + "\n")
PY
out=$(GS_BASE="$gs_base" dry "$rw")
grep -q 'checks check, secret-scan, conventional-title$' <<<"$out" || miss "real walls: a commit-format check the default branch does not define yet is required: $(echo "$out" | grep 'ruleset on')"
grep -q 'conventional-commits is not a required check yet' <<<"$out" || miss "real walls: github_setup does not say that conventional-commits waits for the default branch"
out=$(GS_BASE_DOWN=1 dry "$rw" || true)
grep -q 'checks check, secret-scan$' <<<"$out" || miss "real walls: a commit-format check is required although the default branch could not be read: $(echo "$out" | grep 'ruleset on')"
grep -q 'could not be read' <<<"$out" || miss "real walls: github_setup is silent when it cannot read the workflows of the default branch"
# 44k. a default branch that cannot be read is no reason to drop a wall the ruleset has, and the
#      command says it failed
printf 'check\nsecret-scan\nconventional-title\nconventional-commits\n' > "$TMP/rw-checks"
for prune in "" --prune; do
  rm -f "$TMP/rw-calls.body"
  if RS_BASE_DOWN=1 rw_apply $prune >/dev/null; then miss "real walls: github_setup ends well although it could not read the default branch ($prune)"; fi
  [ "$(rw_put)" = 1 ] || miss "real walls: an unreadable default branch stopped the update of the ruleset ($prune)"
  for name in conventional-title conventional-commits; do
    grep -q "\"$name\"" "$TMP/rw-calls.body" 2>/dev/null || miss "real walls: an unreadable default branch dropped the required check $name ($prune)"
  done
done
echo "ok  real walls (or misses reported above)"

# 45. this repository keeps the rule it gives every repository it sets up (AGENTS.md, "Language"):
#     file names are English, whatever language the document is written in. No check can tell a
#     Vietnamese name from an English one, so the rule is a line in CLAUDE.md, the four documents
#     that broke it carry English names, and nothing points at the old names.
grep -q 'names are English' "$ROOT/CLAUDE.md" || miss "own rules: CLAUDE.md does not say that file, folder and branch names are English"
# 45c. the plugin's own scripts keep the size limit every repository is given: 800 lines a file
for script in "$ROOT"/plugins/repo-setup/scripts/*.py; do
  n=$(wc -l < "$script" | tr -d ' ')
  [ "$n" -le 800 ] || miss "own rules: ${script#"$ROOT"/} has $n lines, more than 800"
done
for doc in docs/setup-principles.md docs/three-repo-boundaries.md docs/three-repo-overview-design.md docs/superpowers/specs/2026-11-16-real-walls-design.md; do
  [ -f "$ROOT/$doc" ] || miss "own rules: $doc is missing"
done
# 45e. CHANGELOG.md is written by every pull request that changes behaviour, each adding an entry right
#      under "## Unreleased": two of them merge without a conflict and both entries stay (merge=union in
#      .gitattributes, the rule this setup gives wiki/log.md; the owner, 2026-11-21). The red direction
#      first: without the rule the same merge conflicts, so the check proves something.
cl="$TMP/changelog-union"; rm -rf "$cl"; mkdir -p "$cl" && git -C "$cl" init -q -b main
cl_git() { git -C "$cl" -c user.name=t -c user.email=t@example.com "$@"; }
cp "$ROOT/CHANGELOG.md" "$cl/"; [ -f "$ROOT/.gitattributes" ] && cp "$ROOT/.gitattributes" "$cl/"
cl_git add -A && cl_git commit -q -m base
cl_entry() { python3 - "$cl/CHANGELOG.md" "$1" <<'PY'
import sys
path, name = sys.argv[1:]
text = open(path, encoding="utf-8").read()
head = "## Unreleased\n\n"
entry = f"### Changed: {name}\nWhat {name} does.\n\n**What breaks on upgrade**: nothing.\n\n"
text = text.replace(head, head + entry, 1) if head in text else text.replace("# Changelog\n", "# Changelog\n\n" + head + entry, 1)
open(path, "w", encoding="utf-8").write(text)
PY
}
cl_git checkout -q -b one && cl_entry "entry one" && cl_git commit -qam one
cl_git checkout -q -b two main && cl_entry "entry two" && cl_git commit -qam two
if grep -q '^CHANGELOG.md  *merge=union' "$cl/.gitattributes" 2>/dev/null; then
  cl_git checkout -q -b plain two && printf '' > "$cl/.gitattributes" && cl_git commit -qam plain
  if cl_git merge -q --no-edit one >/dev/null 2>&1; then miss "own rules: two changelog entries merge cleanly even without the rule, so the check proves nothing"; fi
  cl_git merge --abort >/dev/null 2>&1 || true
  cl_git checkout -q two
  if cl_git merge -q --no-edit one >/dev/null 2>&1; then
    for e in "entry one" "entry two"; do
      [ "$(grep -c "^### Changed: $e$" "$cl/CHANGELOG.md")" = 1 ] || miss "own rules: the merged CHANGELOG.md does not hold the entry '$e' exactly once"
    done
  else
    miss "own rules: two pull requests that each add a changelog entry conflict"
    cl_git merge --abort >/dev/null 2>&1 || true
  fi
else
  miss "own rules: .gitattributes does not merge CHANGELOG.md by union, so every two pull requests that change behaviour conflict"
fi
grep -q 'merge=union' "$ROOT/CLAUDE.md" || miss "own rules: CLAUDE.md does not say that CHANGELOG.md merges by union and how to add an entry"
old_names='nguyen-tac-setup\.md|ranh-gioi-ba-kho\.md|thiet-ke-tong-quan-ba-kho\.md|tuong-that-design\.md'
stale=$(cd "$ROOT" && git ls-files | grep -E "$old_names" || true)
[ -z "$stale" ] || miss "own rules: a document still has a Vietnamese file name: $stale"
stale=$(cd "$ROOT" && git grep -l -E "$old_names" -- . ':!tests/run.sh' || true)
[ -z "$stale" ] || miss "own rules: a file still points at a renamed document: $(echo $stale)"
# 45b. the fast tests never stop without saying why. Under `set -euo pipefail` an assignment from a
#      pipe into a reader that can stop early (head, grep -q, grep -m, sed ...q) fails when the
#      writer is still writing: it gets SIGPIPE, or a write error where SIGPIPE is ignored, and the
#      run ends on the spot with no FAIL line. It is a race, so it is red only now and then: the
#      macOS job at bc31175 ended that way, right after "ok  derived". Such an assignment needs a
#      guard after the substitution, or a reader that reads to the end.
early=$(cd "$ROOT" && grep -nE '^[[:space:]]*(local[[:space:]]+)?[A-Za-z_][A-Za-z_0-9]*=\$\(.*\|[[:space:]]*(head|grep[^|)]*-(q|m)|sed[^|)]*q)\b' tests/*.sh | grep -vE '\|\|' || true)
[ -z "$early" ] || miss "own rules: an assignment pipes into a reader that stops early, so a run can end with no FAIL line: $early"
# The same race, red instead of silent: grep -q at the end of a pipe exits at its match while the writer may still
# write; the writer then gets SIGPIPE (141 under pipefail), and a line that is there reads as missing.
# Seen on macOS, where a pipe starts with a small buffer: 49f at f02085f. grep without -q reads to the
# end (grep ... >/dev/null), and a here-string (`grep -q ... <<<"$x"`) has no pipe at all.
early=$(cd "$ROOT" && grep -nE '\|[[:space:]]*grep([[:space:]]+-[a-zA-Z]+)*[[:space:]]+-[a-zA-Z]*[qm]' tests/*.sh || true)
[ -z "$early" ] || miss "own rules: a pipe ends in grep -q or -m, which can stop the writer and read as a miss: $(printf '%s\n' "$early" | wc -l | tr -d ' ') places, first $(printf '%s\n' "$early" | sed -n 1p)"
# 45d. a build between two tags carries a version of its own (the owner, 2026-11-21): while CHANGELOG.md has
#      entries under "## Unreleased", the plugin's version is X.Y.Z.devN, so a repository set up from main
#      never names a release that does not hold what it got. tools/bump_version.py dev sets it.
own_version() { # <root>: "ok", or what does not hold
  python3 - "$1" <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
text = (root / "CHANGELOG.md").read_text(encoding="utf-8")
unreleased = text.split("\n## Unreleased\n", 1)[1].split("\n## ", 1)[0] if "\n## Unreleased\n" in text else ""
version = json.loads((root / "plugins/repo-setup/.claude-plugin/plugin.json").read_text())["version"]
market = [p["version"] for p in json.loads((root / ".claude-plugin/marketplace.json").read_text())["plugins"]
          if p["name"] == "repo-setup"]
bad = []
if market != [version]:
    bad.append(f"marketplace.json says {market}, plugin.json says {version}")
if unreleased.strip() and not re.fullmatch(r"\d+\.\d+\.\d+\.dev\d+", version):
    bad.append(f"CHANGELOG.md has entries under Unreleased and the version is {version}: run tools/bump_version.py dev")
print("\n".join(bad) or "ok")
PY
}
ov=$(own_version "$ROOT")
[ "$ov" = ok ] || miss "own rules: $ov"
# the bump tool, on a copy: dev after a release, then the release it leads to
bv="$TMP/bump-own"; rm -rf "$bv"; mkdir -p "$bv/plugins/repo-setup" "$bv/tools"
cp -R "$ROOT/.claude-plugin" "$bv/"; cp -R "$ROOT/plugins/repo-setup/.claude-plugin" "$bv/plugins/repo-setup/"
cp "$ROOT/tools/bump_version.py" "$bv/tools/"
bv_set() { python3 - "$bv" "$1" <<'PY'
import json, pathlib, sys
root, v = pathlib.Path(sys.argv[1]), sys.argv[2]
for f in (root / "plugins/repo-setup/.claude-plugin/plugin.json", root / ".claude-plugin/marketplace.json"):
    j = json.loads(f.read_text())
    for p in j.get("plugins", [j]):
        if p.get("name", "repo-setup") == "repo-setup":
            p["version"] = v
    f.write_text(json.dumps(j, indent=2) + "\n")
PY
}
bv_is() { # <part> <expected version> <changelog section expected: yes|no>
  printf '# Changelog\n\n## Unreleased\n\n- a change\n' > "$bv/CHANGELOG.md"
  ( cd "$bv" && python3 tools/bump_version.py "$1" >/dev/null 2>&1 ) || { miss "own rules: bump_version.py $1 fails"; return; }
  got=$(python3 -c "import json; print(json.load(open('$bv/plugins/repo-setup/.claude-plugin/plugin.json'))['version'])")
  [ "$got" = "$2" ] || miss "own rules: bump_version.py $1 gives $got, not $2"
  market=$(python3 -c "import json; print([p['version'] for p in json.load(open('$bv/.claude-plugin/marketplace.json'))['plugins']][0])")
  [ "$market" = "$2" ] || miss "own rules: bump_version.py $1 leaves marketplace.json at $market"
  if grep -q "^## $2 — " "$bv/CHANGELOG.md"; then
    [ "$3" = yes ] || miss "own rules: bump_version.py $1 dates a changelog section for $2, a build between tags"
  else
    [ "$3" = no ] || miss "own rules: bump_version.py $1 adds no changelog section for the release $2"
  fi
}
bv_set 0.10.2; bv_is dev 0.10.3.dev0 no
bv_set 0.10.3.dev0; bv_is dev 0.10.3.dev1 no
bv_set 0.10.3.dev1; bv_is patch 0.10.3 yes
bv_set 0.10.3.dev1; bv_is minor 0.11.0 yes
bv_set 0.10.3.dev0; bv_is 0.10.3 0.10.3 yes
# the red direction: entries under Unreleased beside a release version
bv_set 0.10.3
[ "$(own_version "$bv")" != ok ] || miss "own rules: entries under Unreleased beside a release version go unseen"
echo "ok  own rules (or misses reported above)"

# 46. parallel work does not queue (docs/three-repo-overview-design.md, RS2a and RS10): the one file
#     every pull request writes merges by itself, and the numbers that say whether work queues come
#     from a command, not from a count made by hand once.
fl="$TMP/flow"; mkdir -p "$fl" && git -C "$fl" init -q -b main
python3 "$S/apply.py" --target "$fl" --preset ts-node --level team --var project_name=P --var description=x --var owner=acme >/dev/null
fl_git() { git -C "$fl" -c user.name=t -c user.email=t@example.com "$@"; }
fl_save() { fl_git add -A && fl_git commit -q -m "$1"; }
onefile_ledgers "$fl" track   # the merge=union rule is for a repository that keeps wiki/log.md in git (one-file shape)
# The log is "newest first": every branch adds its line at the same place.
fl_log() {
  python3 - "$fl/wiki/log.md" "$1" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
first = next(n for n, line in enumerate(lines) if line.startswith("- "))
path.write_text("\n".join([*lines[:first], sys.argv[2], *lines[first:]]) + "\n", encoding="utf-8")
PY
}
echo 'export const grid = "base";' > "$fl/src/grid.ts"
fl_save "chore: base"
fl_git checkout -q -b one && fl_log "- 2026-01-02 — one — #1" && fl_save "docs: one"
fl_git checkout -q -b two main && fl_log "- 2026-01-03 — two — #2" && fl_save "docs: two"
fl_git checkout -q -b three main && echo 'export const grid = "three";' > "$fl/src/grid.ts" && fl_save "feat: three"
fl_git checkout -q main && fl_git merge -q --ff-only one
echo 'export const grid = "main";' > "$fl/src/grid.ts" && fl_save "feat: main moves"
# 46a. two branches that each add a line to wiki/log.md merge without a conflict, and both lines stay
grep -q '^wiki/log.md  *merge=union' "$fl/.gitattributes" || miss "flow: .gitattributes does not merge wiki/log.md by union"
# Branch two also merges a branch of its own: both parents are its commits, so it is no merge of main.
fl_git checkout -q -b two-side two && echo 'export const side = 1;' > "$fl/src/side.ts" && fl_save "feat: side"
fl_git checkout -q two && echo 'export const own = 1;' > "$fl/src/own.ts" && fl_save "feat: own"
fl_git merge -q --no-ff --no-edit two-side
fl_before=$(fl_git rev-parse two)
# The red direction first: without the rule the same merge conflicts, so the check below can fail.
subst '/merge=union/d' "$fl/.gitattributes"
if fl_git merge -q --no-edit main >/dev/null 2>&1; then
  miss "flow: the wiki log merges cleanly without the rule, so the check that follows proves nothing"
else
  fl_git merge --abort >/dev/null 2>&1 || true
fi
fl_git reset -q --hard "$fl_before"
if fl_git merge -q --no-edit main >/dev/null 2>&1; then
  for entry in one two; do
    [ "$(grep -c -- "— $entry —" "$fl/wiki/log.md" || true)" = 1 ] || miss "flow: the merged wiki log does not hold the line of branch $entry exactly once"
  done
else
  miss "flow: two branches that each add a line to wiki/log.md conflict"
  fl_git merge --abort >/dev/null 2>&1 || true
fi
# 46b. the measure: tools/sdlc_metrics.py replays every merge of the default branch into a pull
#      request branch and says how many conflict and in which files
fl_git checkout -q three
fl_git merge -q --no-edit main >/dev/null 2>&1 || true
echo 'export const grid = "three and main";' > "$fl/src/grid.ts" && fl_git add -A && fl_git commit -q --no-edit
fl_git checkout -q main
mkdir -p "$TMP/flbin" "$TMP/flowgh"
# Every answer falls on the first day of the window the tool asks for (seven days back).
fl_day=$(python3 -c "import datetime as d; print((d.datetime.now(d.UTC) - d.timedelta(days=7)).date())")
# The answers have the shape GitHub gives: the fake gh below runs the tool's own --jq program on them.
python3 - "$fl" "$TMP/flowgh" "$fl_day" <<'PY'
import json, pathlib, subprocess, sys

repo, out, day = sys.argv[1], pathlib.Path(sys.argv[2]), sys.argv[3]
DAY = f"{day}T00:"


def at(hour: int, minute: int = 0) -> str:
    return f"{day}T{hour:02d}:{minute:02d}:00Z"


def listed(branch: str) -> list[dict]:
    """What GitHub lists for a pull request: the commits of the branch that main does not have."""
    rows = subprocess.run(["git", "-C", repo, "rev-list", "--parents", branch, "^main"],
                          capture_output=True, text=True, check=True).stdout.splitlines()
    return [commit(r.split()[0], r.split()[1:]) for r in rows]


def commit(sha: str, parents: list[str]) -> dict:
    # A merge is made two hours into the day, after both pull requests were last ready.
    date = at(2) if len(parents) == 2 else at(0, 5)
    return {"sha": sha, "commit": {"message": "x", "committer": {"date": date}},
            "parents": [{"sha": p, "url": "u"} for p in parents]}


def pull(number: int, base: str = "main", merged: str | None = None, head: str = "") -> dict:
    return {"number": number, "title": f"feat: {number}", "author": {"login": "dev"}, "labels": [], "reviews": [],
            "createdAt": at(0), "mergedAt": merged, "closedAt": merged, "baseRefName": base,
            "headRefName": head, "headRefOid": str(number) * 40}


def failed_at(step: str) -> list[dict]:
    return [{"name": "Set up job", "conclusion": "success", "number": 1},
            {"name": step, "conclusion": "failure", "number": 2}]


def job(name: str, conclusion: str, start: int, end: int, steps: list | None = None, attempt: int = 1) -> dict:
    return {"id": 1, "name": name, "conclusion": conclusion, "status": "completed", "run_attempt": attempt,
            "started_at": f"{DAY}{start:02d}:00Z", "completed_at": f"{DAY}{end:02d}:00Z", "steps": steps or []}


def run(number: int, name: str, event: str, branch: str, conclusion: str, created: str) -> dict:
    return {"id": number, "name": name, "event": event, "head_branch": branch, "status": "completed",
            "head_sha": f"{number:040x}", "conclusion": conclusion, "run_attempt": 1, "created_at": created}


def save(name: str, *pages: object) -> None:
    (out / name).write_text("".join(json.dumps(page) + "\n" for page in pages))


save("merged.json", [pull(2, merged=at(10), head="two"), pull(3, merged=at(20), head="three")])
save("closed.json", [pull(6)])
# Pull request 5 goes into branch two: the branch it merges is not the default one.
save("open.json", [pull(4), pull(5, base="two")])
save("pr2.json", listed("two"))
save("pr3.json", listed("three"))
# A merge whose commits this clone does not have, and cannot fetch: there is no remote.
save("pr4.json", [commit("a" * 40, ["b" * 40, "c" * 40])])
save("pr5.json", [commit("d" * 40, ["e" * 40, "f" * 40])])
save("pr6.json", [commit("9" * 40, ["8" * 40])])
# Pull request 2 was ready, went back to draft and was ready again at 00:30: the last time counts.
save("timeline-2.json", [{"event": "labeled", "created_at": at(0, 1)},
                         {"event": "ready_for_review", "created_at": at(0, 15)},
                         {"event": "convert_to_draft", "created_at": at(0, 20)},
                         {"event": "ready_for_review", "created_at": at(0, 30)}])
# Pull request 3 was opened ready for review.
save("timeline-3.json", [])
save("rules.json", [{"type": "pull_request", "parameters": {}},
                    {"type": "required_status_checks",
                     "parameters": {"required_status_checks": [{"context": "check"}, {"context": "gate"}]}}])
# The last required check turns green at 04:00 on pull request 2 (gate was red first) and at 06:00 on
# pull request 3; e2e is not required, and a green after the merge does not count.
save("checks-" + "2" * 40 + ".json", {"total_count": 4, "check_runs": [
    {"name": "gate", "conclusion": "failure", "completed_at": at(2)},
    {"name": "check", "conclusion": "success", "completed_at": at(3)},
    {"name": "gate", "conclusion": "success", "completed_at": at(4)},
    {"name": "e2e", "conclusion": "success", "completed_at": at(9)}]})
save("checks-" + "3" * 40 + ".json", {"total_count": 3, "check_runs": [
    {"name": "check", "conclusion": "success", "completed_at": at(5)},
    {"name": "gate", "conclusion": "success", "completed_at": at(6)},
    {"name": "gate", "conclusion": "success", "completed_at": at(21)}]})
runs = [
    run(1, "CI", "pull_request", "two", "failure", at(1)),
    run(2, "CI", "pull_request", "three", "success", at(1)),
    run(5, "CI", "pull_request", "five", "success", at(1)),
    run(7, "CI", "pull_request", "seven", "failure", at(1)),
    # Branch two was pushed before it was last ready, branch three twice after.
    run(8, "CI", "pull_request", "two", "failure", at(0, 10)),
    run(9, "CI", "pull_request", "three", "success", at(2)),
    run(3, "CI", "push", "main", "success", at(11)),
    run(6, "CI", "push", "main", "success", at(21)),
    run(4, "Release", "push", "main", "failure", at(11)),
]
# Two pages, as GitHub pages a long list.
save("runs.json", {"total_count": 9, "workflow_runs": runs[:4]}, {"total_count": 9, "workflow_runs": runs[4:]})
# A list GitHub cut short: it says nine runs and hands over one.
save("runs-short.json", {"total_count": 9, "workflow_runs": runs[:1]})
save("runs-none.json", {"total_count": 0, "workflow_runs": []})
jobs = {
    # gate passed and a heavier job ended red afterwards on the same head: a late red.
    1: [job("gate", "success", 0, 2), job("check", "success", 0, 3),
        job("e2e-db", "failure", 0, 30, failed_at("Run make e2e-db"))],
    # red first, then run again: gate passed only after the red had ended. Not a late red.
    2: [job("check", "failure", 0, 3), job("gate", "failure", 0, 1),
        job("check", "success", 10, 13, attempt=2), job("gate", "success", 10, 12, attempt=2)],
    # a late red that a second attempt turned green: it still counts.
    5: [job("gate", "success", 0, 2), job("e2e", "failure", 0, 10, failed_at("Run make e2e")),
        job("gate", "success", 20, 22, attempt=2), job("e2e", "success", 20, 30, attempt=2)],
    # a draft: the heavy tier is skipped, so the summary job is red after gate passed. It says
    # "not run yet", not "failed": no late red.
    7: [job("gate", "success", 0, 1), job("quick", "success", 0, 3), job("heavy", "skipped", 3, 3),
        job("check", "failure", 3, 4, failed_at("Every tier is green"))],
    # the same step red on two branches (five above, and two here)
    8: [job("e2e", "failure", 0, 6, failed_at("Run make e2e"))],
    9: [job("quick", "success", 0, 2)],
    # the default branch: red on the first attempt (at a step that runs no checks), green on the second.
    3: [job("check", "failure", 0, 5, failed_at("Run npm ci")), job("check", "success", 10, 15, attempt=2)],
    6: [job("check", "success", 0, 4)],
    4: [job("release-please", "failure", 0, 1)],
}
for number, rows in jobs.items():
    save(f"jobs-{number}.json", {"total_count": len(rows), "jobs": rows})
PY
cat > "$TMP/flbin/gh" <<'SH'
#!/bin/sh
# Canned answers in the shape GitHub gives. A list is asked for the way the tool must ask (every
# page, 100 a page, the filter that matters), and its --jq program runs here on the raw answer.
all="$*"
rows() {
  file="$FLOW_GH/$1"; shift
  case "$all" in *--paginate*per_page=100*) ;; *) echo "not every page is asked for: $all" >&2; exit 1 ;; esac
  while [ "$#" -gt 1 ] && [ "$1" != --jq ]; do shift; done
  jq -c -r "$2" "$file"   # gh --jq prints a string as it is, without quotes
}
case "$all" in
  "pr list --state merged"*baseRefName*headRefOid*) cat "$FLOW_GH/merged.json" ;;
  "pr list --state closed"*baseRefName*) cat "$FLOW_GH/closed.json" ;;
  "pr list --state open"*baseRefName*) cat "$FLOW_GH/open.json" ;;
  "repo view"*) echo '{"nameWithOwner":"acme/p","defaultBranchRef":{"name":"main"}}' ;;
  *deployments*) echo '[]' ;;
  *"/rules/branches/main"*)
    [ -z "${FLOW_NO_RULES:-}" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
    rows rules.json "$@" ;;
  *"/issues/"*"/timeline"*) rows "timeline-$(echo "$all" | sed 's|.*/issues/\([0-9]*\)/timeline.*|\1|').json" "$@" ;;
  *"/commits/"*"/check-runs"*filter=all*) rows "checks-$(echo "$all" | sed 's|.*/commits/\([0-9a-f]*\)/check-runs.*|\1|').json" "$@" ;;
  *"/pulls/"*"/commits"*) rows "pr$(echo "$all" | sed 's|.*/pulls/\([0-9]*\)/commits.*|\1|').json" "$@" ;;
  *"/actions/runs/"*"/jobs"*filter=all*) rows "jobs-$(echo "$all" | sed 's|.*/actions/runs/\([0-9]*\)/jobs.*|\1|').json" "$@" ;;
  *"/actions/runs "*"created="*)
    # The runs are asked for one day at a time; all of them fall on the first day of the window.
    [ -z "${FLOW_NO_RUNS:-}" ] || { echo "gh: Resource not accessible by integration (HTTP 403)" >&2; exit 1; }
    case "$all" in *"created=$FLOW_DAY "*) rows "${FLOW_RUNS:-runs}.json" "$@" ;; *) rows runs-none.json "$@" ;; esac ;;
  *) echo "unexpected gh call: $all" >&2; exit 1 ;;
esac
SH
chmod +x "$TMP/flbin/gh"
fl_metrics() { ( cd "$1" && PATH="$TMP/flbin:$PATH" FLOW_GH="$TMP/flowgh" FLOW_DAY="$fl_day" python3 tools/sdlc_metrics.py --days 7 "${@:2}" 2>/dev/null || true ); }
fl_is() { [ "$(echo "$flow" | json "$1" 2>/dev/null || true)" = "$2" ] || miss "flow: $3 (got: $(echo "$flow" | json "$1" 2>&1 | tail -1))"; }
if command -v jq >/dev/null 2>&1; then
  flow=$(fl_metrics "$fl" --json)
  fl_is 'd["lead_time_median_h"]' 15.0 "the median time from open to merge changed"
  fl_is 'd["lead_time_max_h"]' 20.0 "the longest time from open to merge is not reported"
  fl_is 'd["back_merges"]["pull_requests"]' 4 "merges of main are not looked for on merged, closed and open pull requests into the default branch, and only those"
  fl_is 'd["back_merges"]["found"]' 3 "a merge of main is missed, or a merge of the branch's own commits or of another base is taken for one"
  fl_is 'd["back_merges"]["replayed"]' 2 "the merges of main whose commits are here are not replayed"
  fl_is 'd["back_merges"]["conflicting"]' 1 "a merge of main that conflicted is not counted as one (or the union rule of the wiki log is not read)"
  fl_is 'd["back_merges"]["files"]' "{'src/grid.ts': 1}" "the files in conflict are not named"
  # 46c. what could not be read is not counted as clean, and the reason is given
  fl_is 'd["back_merges"]["not_replayed"]' 1 "a merge whose commits are not in this clone is dropped or counted as clean"
  fl_is 'd["back_merges"]["not_replayed_because"].startswith("git fetch")' True "a merge that could not be replayed carries no reason"
  git clone -q --depth 1 "file://$fl" "$TMP/flow-shallow" 2>/dev/null
  shallow=$(fl_metrics "$TMP/flow-shallow" --json | json 'd["back_merges"].get("unread", "")' 2>/dev/null || true)
  case "$shallow" in *shallow*) ;; *) miss "flow: a shallow clone replays merges on a history it does not have" ;; esac
  # 46d. machine minutes per merged pull request, late red, and red on the default branch
  fl_is 'd["ci"]["runs"]' 9 "the workflow runs of every page and of every day of the window are not counted once each"
  fl_is 'd["ci"]["machine_minutes"]' 96.0 "machine minutes are not the sum of the job durations of every attempt"
  fl_is 'd["ci"]["machine_minutes_per_merged_pr"]' 48.0 "machine minutes are not set against the merged pull requests"
  fl_is 'd["ci"]["late_red"]' "[2, 4]" "late red is not: a job that ended red after gate passed on that head, also when a second attempt turned it green, and not when the red came first, and not a summary job that only says the heavy tier has not run yet"
  fl_is 'd["ci"]["default_branch"]' "{'CI': [1, 2], 'Release': [1, 1]}" "red on the default branch is not counted per workflow, or a run made green by a second attempt is not counted as red"
  # 46g. a summary job that is red only because the heavy tier of a draft has not run yet is counted
  #      apart: it says "not its turn", not "failed"
  fl_is 'd["ci"]["waiting_red"]' 1 "a summary job red beside a skipped tier is not counted apart from late red"
  # 46h. one row per job: runs, green, red, cancelled, median minutes, machine hours, red at a step
  #      that runs checks (a make step); and where in the job each red ended
  fl_is 'd["ci"]["jobs"]["e2e"]' "{'runs': 3, 'green': 1, 'red': 2, 'cancelled': 0, 'median_minutes': 10.0, 'machine_hours': 0.43, 'red_at_check_step': 2}" "the row of a job is not its attempts, outcomes, median, machine hours and reds at a check step"
  fl_is 'd["ci"]["jobs"]["check"]' "{'runs': 7, 'green': 4, 'red': 3, 'cancelled': 0, 'median_minutes': 3.0, 'machine_hours': 0.4, 'red_at_check_step': 0}" "a red at the summary step, at an install step or with no step read is taken for a red at a check step"
  fl_is 'd["ci"]["jobs"]["heavy"]["median_minutes"]' None "a job that only ever skipped gets a median of zero"
  fl_is 'd["ci"]["red_steps"]' "{'checks': 3, 'summary': 1, 'other': 1, 'not_read': 3}" "red jobs are not split by the step they ended at"
  # 46i. the same step red on two or more branches: a sign of a red that is not the pull request's
  fl_is 'd["ci"]["red_across_branches"]' "[{'job': 'e2e', 'step': 'Run make e2e', 'branches': ['five', 'two']}]" "a step red on two branches is not named, or a step red on one branch is"
  # 46j. how a merged pull request spent its time, from GitHub and git only
  fl_is 'd["pulls"]["required_checks"]' "['check', 'gate']" "the required checks are not read from the rules of the default branch"
  fl_is 'd["pulls"]["to_ready"]' "{'n': 2, 'median_h': 0.25, 'max_h': 0.5}" "opened to ready for review is not measured to the last time it was ready"
  fl_is 'd["pulls"]["to_green"]' "{'n': 2, 'median_h': 4.75, 'max_h': 6.0}" "ready to the last required check green is not measured on the last head, before the merge"
  fl_is 'd["pulls"]["to_merged"]' "{'n': 2, 'median_h': 10.0, 'max_h': 14.0}" "last required check green to merged is not measured"
  fl_is 'd["pulls"]["pushes_after_ready"]' "{'n': 2, 'total': 3, 'median': 1.5, 'max': 2}" "pushes after the pull request was last ready are not the new heads CI ran on"
  fl_is 'd["pulls"]["merges_after_ready"]' "{'n': 2, 'total': 2, 'median': 1.0, 'max': 1}" "merges of the default branch after the pull request was last ready are not counted"
  flow=$(FLOW_NO_RUNS=1 fl_metrics "$fl" --json)
  fl_is 'bool(d["ci"]["unread"])' True "workflow runs that could not be read are reported as zero runs"
  fl_is 'd["back_merges"]["conflicting"]' 1 "one part that cannot be read hides the parts that can"
  fl_is 'bool(d["pulls"]["pushes_after_ready"]["unread"])' True "pushes are counted as zero when the workflow runs cannot be read"
  fl_is 'd["pulls"]["to_green"]["n"]' 2 "the time of a pull request is not read when only the workflow runs cannot be"
  flow=$(FLOW_NO_RULES=1 fl_metrics "$fl" --json)
  fl_is 'bool(d["pulls"]["unread"])' True "the time of a pull request is reported without the required checks"
  flow=$(FLOW_RUNS=runs-short fl_metrics "$fl" --json)
  fl_is '"1 of 9" in d["ci"]["unread"]' True "a list of workflow runs that GitHub cut short is reported as the whole list"
  # 46k. the window split at a moment: each pull request on the side of its merge, each run on the
  #      side it was created, so a number can be read before and after a package
  flow=$(fl_metrics "$fl" --json --split "${fl_day}T15:00:00Z")
  fl_is 'd["split"]["at"]' "${fl_day}T15:00:00+00:00" "the moment of the split is not the one asked for"
  fl_is '[d["before"]["merged"], d["after"]["merged"]]' "[1, 1]" "the merged pull requests are not split by the time they merged"
  fl_is '[d["before"]["lead_time_median_h"], d["after"]["lead_time_median_h"]]' "[10.0, 20.0]" "the time from open to merge is not split"
  fl_is '[d["before"]["ci"]["runs"], d["after"]["ci"]["runs"]]' "[8, 1]" "the workflow runs are not split by the time they were created"
  fl_is '[d["before"]["back_merges"]["found"], d["after"]["back_merges"]["found"]]' "[1, 2]" "merges of main are not split with their pull request"
  fl_git tag -a -m v1 split-tag main
  flow=$(fl_metrics "$fl" --json --split split-tag)
  fl_is '[d["split"]["by"], d["before"]["ci"]["runs"], d["after"]["ci"]["runs"]]' "['split-tag', 9, 0]" "a tag does not split the window at the time of its commit"
  rc=0; err=$( cd "$fl" && PATH="$TMP/flbin:$PATH" FLOW_GH="$TMP/flowgh" FLOW_DAY="$fl_day" python3 tools/sdlc_metrics.py --days 7 --split no-such-tag 2>&1 >/dev/null ) || rc=$?
  [ "$rc" = 2 ] && case "$err" in *no-such-tag*) true ;; *) false ;; esac || miss "flow: a split that is neither a date nor a tag does not stop with exit 2 and its name (rc $rc: $err)"
  # 46e. the page a person reads carries the same lines
  page=$(fl_metrics "$fl")
  for line in 'longest 20.0 h' 'Merges of the default branch into a pull request branch | 3 on 4' \
    'conflict when replayed | 1 of 2' 'could not be replayed | 1 (git fetch' '`src/grid.ts` 1' \
    'per merged pull request (every run in the window) | 48.0' \
    'Late red (a job ended red on a head after `gate` passed) | 2 of 4' 'CI 1 of 2, Release 1 of 1' \
    'only says the heavy tier has not run yet | 1' \
    '| `e2e` | 3 | 1 | 2 | 0 | 10.0 | 0.43 | 2 |' '| `heavy` | 1 | 0 | 0 | 0 | n/a | 0.0 | 0 |' \
    'Red jobs: 8; at a step that runs checks (a `make` step) 3, at the summary step 1, at another step 1, step not read 3' \
    '`e2e` at `Run make e2e` | 2 branches: five, two' 'Test names are not read' \
    'Opened to ready for review | median 0.25 h, longest 0.5 h (2 pull requests)' \
    'Ready to the last required check green | median 4.75 h, longest 6.0 h (2 pull requests)' \
    'Last required check green to merged | median 10.0 h, longest 14.0 h (2 pull requests)' \
    'Pushes after it was last ready (new heads CI ran on) | 3, median 1.5, most 2 (2 pull requests)' \
    'Merges of the default branch after it was last ready | 2, median 1.0, most 1 (2 pull requests)'; do
    grep -qF -- "$line" <<<"$page" || miss "flow: the report does not carry the line: $line"
  done
  FLOW_NO_RUNS=1 fl_metrics "$fl" | grep 'not read' >/dev/null || miss "flow: the report shows numbers for workflow runs it could not read"
  FLOW_NO_RULES=1 fl_metrics "$fl" | grep 'Opened to ready for review | not read' >/dev/null || miss "flow: the report shows times of pull requests it could not read"
  page=$(fl_metrics "$fl" --split "${fl_day}T15:00:00Z")
  for line in "## Before ${fl_day}T15:00:00+00:00" "## From ${fl_day}T15:00:00+00:00"; do
    grep -qF -- "$line" <<<"$page" || miss "flow: the split report does not carry the heading: $line"
  done
  # 46l. the measure reads no file of the feature loop: its gate marks are its own to measure
  grep -n '_acceptance' "$fl"/tools/sdlc_*.py && miss "flow: the measure reads _acceptance/, the feature loop's files"
  # 46m. thresholds (the owner, 2026-11-21: a line in the report, nothing more): late red, red on the default
  #      branch per workflow, and one file in most of the conflicting merges each say over, within, too few
  #      to tell, or not read. A number over its threshold never changes the exit code.
  flow=$(fl_metrics "$fl" --json)
  fl_is '[(t["measure"], t.get("subject", ""), t["verdict"]) for t in d["thresholds"]]' \
    "[('late red', '', 'too few to tell'), ('default branch red', 'CI', 'too few to tell'), ('default branch red', 'Release', 'too few to tell'), ('one file in the conflicting merges', 'src/grid.ts', 'too few to tell')]" \
    "the thresholds are not one line per measure and per workflow, each too few to tell on four heads, two runs and one conflict"
  th=$(cd "$fl" && python3 - <<'PY' 2>&1 || true
import sys
sys.path.insert(0, "tools")
import sdlc_limits as L

def rows(ci, merges):
    return [(t["measure"], t.get("subject", ""), t["verdict"]) for t in L.thresholds({"ci": ci, "back_merges": merges})]

problems = []
def want(name, got, expected):
    if got != expected:
        problems.append(f"{name}: {got}, want {expected}")

clean = {"conflicting": 0, "files": {}}
want("late red 5 of 20 is over 20%", rows({"late_red": [5, 20], "default_branch": {}}, clean), [("late red", "", "over")])
want("late red 4 of 20 is not over 20%", rows({"late_red": [4, 20], "default_branch": {}}, clean), [("late red", "", "within")])
want("late red 5 of 19 is too few", rows({"late_red": [5, 19], "default_branch": {}}, clean), [("late red", "", "too few to tell")])
want("per workflow", rows({"late_red": [0, 0], "default_branch": {"CI": [2, 36], "Release": [33, 40], "Docs": [0, 25]}}, clean),
     [("late red", "", "too few to tell"), ("default branch red", "CI", "over"),
      ("default branch red", "Docs", "within"), ("default branch red", "Release", "over")])
want("one file in most conflicts", rows({"late_red": [0, 0], "default_branch": {}}, {"conflicting": 140, "files": {"LO-TRINH.html": 129, "b": 30}}),
     [("late red", "", "too few to tell"), ("one file in the conflicting merges", "LO-TRINH.html", "over")])
want("no file in most conflicts", rows({"late_red": [0, 0], "default_branch": {}}, {"conflicting": 40, "files": {"a": 20, "b": 20}}),
     [("late red", "", "too few to tell"), ("one file in the conflicting merges", "a", "within")])
unread = L.thresholds({"ci": {"unread": "rate limit"}, "back_merges": {"unread": "shallow clone"}})
want("unread parts", [(t["measure"], t["verdict"], t.get("reason")) for t in unread],
     [("late red", "not read", "rate limit"), ("default branch red", "not read", "rate limit"),
      ("one file in the conflicting merges", "not read", "shallow clone")])
want("the values", (L.LATE_RED_MAX, L.DEFAULT_RED_MAX, L.ONE_FILE_MAX, L.MIN_SAMPLE), (0.2, 0.05, 0.5, 20))
print("\n".join(problems) or "ok")
PY
)
  [ "$th" = ok ] || miss "flow: thresholds: $th"
  # over a threshold: the page says so, and the exit code is still 0
  th_rc=0; th_page=$(cd "$fl" && PATH="$TMP/flbin:$PATH" FLOW_GH="$TMP/flowgh" FLOW_DAY="$fl_day" python3 -c "
import sys; sys.path.insert(0, 'tools')
import sdlc_limits, sdlc_metrics
sdlc_limits.MIN_SAMPLE = 1
sys.exit(sdlc_metrics.main(['--days', '7']))" 2>/dev/null) || th_rc=$?
  [ "$th_rc" = 0 ] || miss "flow: a number over its threshold changes the exit code to $th_rc"
  grep -F -- '| Late red | 2 of 4 (50%) | more than 20% | over |' <<<"$th_page" >/dev/null || miss "flow: the page does not say late red is over its threshold"
  page=$(fl_metrics "$fl")
  for line in '## Thresholds' '| Red on the default branch: `CI` | 1 of 2 (50%) | more than 1 in 20 | too few to tell (fewer than 20) |' \
    'starting values' 'python3 tools/sdlc_metrics.py --days 14 --write'; do
    grep -F -- "$line" <<<"$page" >/dev/null || miss "flow: the page does not carry the line: $line"
  done
else
  echo "skip  flow 46b-46m: jq is not installed, the measure was not run"
fi
# 46f. a list of pull requests that stops at the limit of the query is said to be partial
partial=$(cd "$fl" && python3 -c "
import sys; sys.path.insert(0, 'tools'); import sdlc_metrics as s
print(s.capped({'merged': [0] * s.PR_LIMIT, 'open': [0]}))" 2>/dev/null || true)
[ "$partial" = "['merged']" ] || miss "flow: a list of pull requests cut at the limit is taken for the whole list"
echo "ok  flow (or misses reported above)"

# 48. ledgers as fragments (docs/superpowers/specs/2026-11-17-ledger-fragments-design.md, 5.1 and 5.2):
#     `make derived` draws every file the repository keeps out of git, in an order every other step
#     waits for, and a drawn file that is still in git turns `make check` red.
dv="$TMP/derived"; mkdir -p "$dv" && git -C "$dv" init -q -b main
python3 "$S/apply.py" --target "$dv" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
onefile_ledgers "$dv" track   # an older repository: the three ledgers are hand-kept files in git
dv_git() { git -C "$dv" -c user.name=t -c user.email=t@example.com "$@"; }
dv_ledger() { ( cd "$dv" && python3 tools/ledgers.py "$@" ); }
# 48a. a target a later file adds to DERIVED_TARGETS still runs before `make test`, on a clean clone
printf 'DERIVED_TARGETS += zz\n.PHONY: zz\nzz: ; @touch zz.done\n' > "$dv/mk/zz.mk"
# a step a layer appends to CHECK_TARGETS waits for derived too: it sees what zz drew
printf 'CHECK_TARGETS += yy\n.PHONY: yy\nyy: ; @test -f zz.done && touch yy.ok\n' > "$dv/mk/yy.mk"
dv_git add -A && dv_git commit -q -m "chore: base"
git clone -q "$dv" "$TMP/derived-clone" 2>/dev/null
( cd "$TMP/derived-clone" && make test >/dev/null 2>&1 || true )
[ -f "$TMP/derived-clone/zz.done" ] || miss "derived: a target added to DERIVED_TARGETS by a later mk file did not run before make test"
git clone -q "$dv" "$TMP/derived-clone2" 2>/dev/null
( cd "$TMP/derived-clone2" && make yy >/dev/null 2>&1 || true )
[ -f "$TMP/derived-clone2/yy.ok" ] || miss "derived: a check step a layer appended to CHECK_TARGETS ran before make derived"
dv_out=$(cd "$TMP/derived-clone" && make derived 2>&1 || true)
case "$dv_out" in *"nothing to draw"*) ;; *) false ;; esac || miss "derived: make derived on a repository with no drawn ledger does not say there is nothing to draw"
dv_out=$(cd "$TMP/derived-clone" && make -n check 2>/dev/null || true)
case "$dv_out" in *"ledgers.py untracked"*) ;; *) false ;; esac || miss "derived: derived-untracked is not part of make check"
# 48b. the shape of a ledger is read from git and from the stamp, never from a folder
dv_git rm -q --cached wiki/log.md; rm -f "$dv/wiki/log.md"
[ "$(dv_ledger shape log 2>&1)" = fragments ] || miss "derived: shape log is not fragments when wiki/log.md is absent"
printf '# Log\n\n- 2026-01-01 — start\n' > "$dv/wiki/log.md"
[ "$(dv_ledger shape log 2>&1)" = fragments ] || miss "derived: shape log is not fragments while wiki/log.md is not in git"
dv_git add -f wiki/log.md
[ "$(dv_ledger shape log 2>&1)" = one-file ] || miss "derived: shape log is not one-file when an unstamped wiki/log.md is in git"
printf 'x sha256:abc\n- 2026-01-01 — start\n' > "$dv/wiki/log.md"; dv_git add -f wiki/log.md
[ "$(dv_ledger shape log 2>&1)" = one-file ] || miss "derived: a wiki/log.md whose first line only contains sha256: is not one-file"
dv_nogit="$TMP/derived-nogit"; mkdir -p "$dv_nogit/wiki" "$dv_nogit/tools"
cp "$dv/tools/ledgers.py" "$dv_nogit/tools/" 2>/dev/null || true
[ "$(cd "$dv_nogit" && python3 tools/ledgers.py shape log 2>&1)" = fragments ] || miss "derived: shape log is not fragments outside git with no wiki/log.md"
printf '# Log\n' > "$dv_nogit/wiki/log.md"
[ "$(cd "$dv_nogit" && python3 tools/ledgers.py shape log 2>&1)" = one-file ] || miss "derived: shape log is not one-file outside git when an unstamped wiki/log.md is there"
rc=0; ( cd "$dv_nogit" && python3 tools/ledgers.py nonsense >/dev/null 2>&1 ) || rc=$?
[ "$rc" = 2 ] || miss "derived: ledgers.py exits $rc, not 2, on wrong usage"
rc=0; ( cd "$dv_nogit" && python3 tools/ledgers.py shape nonsense >/dev/null 2>&1 ) || rc=$?
[ "$rc" = 2 ] || miss "derived: ledgers.py shape exits $rc, not 2, for an unknown ledger"
# 48c. a drawn (stamped) file that is in git is red and says how to leave git; an unstamped one is a
#      one-file ledger and stays green
dv_untracked() { ( cd "$dv" && make derived-untracked 2>&1 ); }
dv_untracked >/dev/null || miss "derived: derived-untracked is red for an unstamped wiki/log.md in git (a one-file ledger)"
dv_git commit -q -m "docs: one-file log"
( cd "$dv" && python3 -c "
import pathlib, sys; sys.path.insert(0, 'tools'); import ledgers
pathlib.Path('wiki/log.md').write_text(ledgers.stamp('- 2026-01-01 — start\n', 'wiki/log/'), encoding='utf-8')" )
dv_git add -f wiki/log.md
if out=$(dv_untracked); then miss "derived: derived-untracked is green for a stamped wiki/log.md in git"; fi
case "$out" in *wiki/log.md*"git rm --cached wiki/log.md"*) ;; *) miss "derived: derived-untracked does not name wiki/log.md and git rm --cached wiki/log.md ($out)" ;; esac
dv_git rm -q --cached wiki/log.md
dv_untracked >/dev/null || miss "derived: derived-untracked stays red after git rm --cached"
# the stamp: a hand edit is seen, and a file that carries no stamp reads as none
( cd "$dv" && python3 -c "
import pathlib, sys; sys.path.insert(0, 'tools'); import ledgers
path = pathlib.Path('wiki/log.md')
body, edited = ledgers.read_stamped(path)
assert body == '- 2026-01-01 — start\n' and edited is False, (body, edited)
path.write_text(path.read_text(encoding='utf-8') + 'by hand\n', encoding='utf-8')
body, edited = ledgers.read_stamped(path)
assert edited is True, edited
assert ledgers.read_stamped(pathlib.Path('wiki/nothing.md')) == (None, False)
assert ledgers.read_stamped(pathlib.Path('README.md')) == (None, False)
" ) || miss "derived: stamp and read_stamped do not round-trip, or a hand edit is not seen"
# 48d-48g. the wiki log: one file per entry, drawn into wiki/log.md
lg="$TMP/logrepo"; mkdir -p "$lg" && git -C "$lg" init -q -b main
python3 "$S/apply.py" --target "$lg" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
onefile_ledgers "$lg" track
lg_git() { git -C "$lg" -c user.name=t -c user.email=t@example.com "$@"; }
lg_tool() { ( cd "$lg" && python3 tools/ledgers.py "$@" ); }
lg_git add -A && lg_git commit -q -m "chore: base"
# 48d. one-file: the line goes to the top of the list; fragments: exactly one new file
today=$(date +%Y-%m-%d)
( cd "$lg" && make log m="x — #1" >/dev/null 2>&1 ) || miss "log: make log failed in the one-file shape"
sed -n '/^- /p' "$lg/wiki/log.md" | head -1 | grep -xF -- "- $today — x — #1" >/dev/null \
  || miss "log: make log in the one-file shape did not put '- <today> — x — #1' at the top of the list"
[ -z "$(ls "$lg/wiki/log" 2>/dev/null)" ] || miss "log: make log in the one-file shape wrote a fragment"
lg_git checkout -q -- wiki/log.md && lg_git rm -q --cached wiki/log.md && rm -f "$lg/wiki/log.md"
lg_git commit -q -m "docs: log becomes fragments"
( cd "$lg" && make log m="x — #1" >/dev/null 2>&1 ) || miss "log: make log failed in the fragments shape"
[ "$(lg_git status --porcelain | wc -l | tr -d ' ')" = 1 ] || miss "log: make log in the fragments shape did not touch exactly one file ($(lg_git status --porcelain | tr '\n' ';'))"
[ -f "$lg/wiki/log/$today-01-x-1.md" ] || miss "log: the fragment is not wiki/log/$today-01-x-1.md ($(ls "$lg/wiki/log" 2>&1 | tr '\n' ' '))"
# 48e. three fragments, one with a dash and a pipe: the stamp, the head, three lines newest first
rm -f "$lg"/wiki/log/*.md
printf 'Head of the log\n' > "$lg/wiki/log.head.md"
lg_tool add-log --date 2026-02-01 "first" >/dev/null
lg_tool add-log --date 2026-02-03 "third — with a | pipe and a dash" >/dev/null
lg_tool add-log --date 2026-02-02 "second" >/dev/null
lg_tool draw >/dev/null || miss "log: draw failed on three fragments"
want=$(printf '%s\n' 'Head of the log' '' '- 2026-02-03 — third — with a | pipe and a dash' '- 2026-02-02 — second' '- 2026-02-01 — first')
got=$(tail -n +2 "$lg/wiki/log.md")
[ "$got" = "$want" ] || miss "log: the drawn log is not the head and three lines, newest first ($got)"
head -1 "$lg/wiki/log.md" | grep -E '^<!-- Drawn by tools/ledgers.py from wiki/log/\. Edit the source, not this file\. sha256:[0-9a-f]{64} -->$' >/dev/null \
  || miss "log: wiki/log.md does not open with the stamp line"
[ "$(grep -c '^- ' "$lg/wiki/log.md")" = 3 ] || miss "log: a dash or a pipe in an entry split it into more than one line"
cp "$lg/wiki/log.md" "$TMP/log.once"; lg_tool draw >/dev/null
cmp -s "$TMP/log.once" "$lg/wiki/log.md" || miss "log: drawing a second time changed a byte"
lg_tool check || miss "log: check fails on good fragments"
# a wrong name, and two sources
printf 'x\n' > "$lg/wiki/log/notes.md"
if lg_tool check >/dev/null 2>&1; then miss "log: check is green for a fragment named notes.md"; fi
rm "$lg/wiki/log/notes.md"
# 48f. two branches, one make log each on the same day: no conflict, no shared file, both lines drawn
rm -f "$lg"/wiki/log/*.md "$lg/wiki/log.md"; lg_git add -A; lg_git commit -q -m "docs: head" || true
lg_git checkout -q -b branch-a; lg_tool add-log --date 2026-03-01 "from a" >/dev/null; lg_git add -A; lg_git commit -q -m "docs: a"
lg_git checkout -q main; lg_git checkout -q -b branch-b; lg_tool add-log --date 2026-03-01 "from b" >/dev/null; lg_git add -A; lg_git commit -q -m "docs: b"
common=$(comm -12 <(lg_git diff --name-only main branch-a | sort) <(lg_git diff --name-only main branch-b | sort))
[ -z "$common" ] || miss "log: two make log on two branches changed a common file ($common)"
lg_git merge -q --no-edit branch-a >/dev/null 2>&1 || miss "log: merging two branches that each added an entry conflicted"
lg_tool draw >/dev/null
grep -qF -- "- 2026-03-01 — from a" "$lg/wiki/log.md" && grep -qF -- "- 2026-03-01 — from b" "$lg/wiki/log.md" \
  || miss "log: the merged log does not carry both lines"
lg_git checkout -q main
# 48g. a line added by hand to the drawn file: draw refuses, says what and how, and leaves the file as it was
cp "$lg/wiki/log.md" "$TMP/log.edit"; printf -- '- 2026-03-09 — typed by hand\n' >> "$TMP/log.edit"; cp "$TMP/log.edit" "$lg/wiki/log.md"
rc=0; out=$(lg_tool draw 2>&1) || rc=$?
[ "$rc" = 1 ] || miss "log: draw exits $rc, not 1, on a hand-edited wiki/log.md"
case "$out" in *"typed by hand"*'make log m='*) ;; *) miss "log: draw does not print the added line and the make log command ($out)" ;; esac
cmp -s "$TMP/log.edit" "$lg/wiki/log.md" || miss "log: draw changed a hand-edited wiki/log.md"
# 48h. a new repository with nothing committed: the template gives no wiki/log.md, so make derived is
#      green and draws it; a hand-written wiki/log.md that git does not know is refused, named and kept
nc="$TMP/nocommit"; mkdir -p "$nc" && git -C "$nc" init -q -b main
python3 "$S/apply.py" --target "$nc" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
( cd "$nc" && make derived >/dev/null 2>&1 ) || miss "log: make derived is red in a new repository with no commit yet"
head -1 "$nc/wiki/log.md" | grep '^<!-- Drawn by' >/dev/null || miss "log: make derived did not draw wiki/log.md in a new repository with no commit yet"
rm -f "$nc/wiki/log.md" "$nc/wiki/index.md" "$nc/ontology/glossary.md"
onefile_ledgers "$nc"   # a hand-kept wiki/log.md that git does not know
cp "$nc/wiki/log.md" "$TMP/nc.log"
rc=0; out=$(cd "$nc" && python3 tools/ledgers.py draw 2>&1) || rc=$?
[ "$rc" = 1 ] || miss "log: draw exits $rc, not 1, for an unstamped wiki/log.md that git does not know"
case "$out" in *wiki/log.md*"delete wiki/log.md"*"Repository created with repo-setup (test)."*'make log m='*) ;; *) miss "log: the refusal of an unstamped untracked wiki/log.md does not name it, list its line and say how to move it ($out)" ;; esac
cmp -s "$TMP/nc.log" "$nc/wiki/log.md" || miss "log: draw changed an unstamped wiki/log.md"
# 48i. the text of make log reaches the fragment as typed: $, $(HOME), backticks and quotes
rm -f "$lg"/wiki/log/*.md
typed='cost $5 `x` $(HOME) "q" '"'"'s'"'"
( cd "$lg" && make log m="$typed" >/dev/null 2>&1 ) || miss "log: make log failed on a text with dollar signs, backticks and quotes"
frag=$(ls "$lg"/wiki/log/*.md 2>/dev/null | head -1 || true)
[ -n "$frag" ] && [ "$(cat "$frag")" = "$typed" ] || miss "log: make log changed the text: $(cat "$frag" 2>/dev/null || true)"
# 48j. two sources: a tracked hand-kept wiki/log.md beside an entry is red in check and in make check
ts="$TMP/twosrc"; mkdir -p "$ts" && git -C "$ts" init -q -b main
python3 "$S/apply.py" --target "$ts" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
onefile_ledgers "$ts" track
git -C "$ts" add -A && git -C "$ts" -c user.name=t -c user.email=t@example.com commit -q -m "chore: base"
mkdir -p "$ts/wiki/log" && printf 'x\n' > "$ts/wiki/log/2026-01-01-01-x.md"
rc=0; out=$(cd "$ts" && python3 tools/ledgers.py check 2>&1) || rc=$?
[ "$rc" = 1 ] || miss "log: check exits $rc, not 1, for two sources"
case "$out" in *wiki/log.md*) ;; *) miss "log: check does not name wiki/log.md for two sources ($out)" ;; esac
if ( cd "$ts" && make ledgers-check >/dev/null 2>&1 ); then miss "log: make ledgers-check is green for two sources"; fi
# 48k (plan 48h). the glossary: one file per term; ontology/glossary.md is the head and a four-column
#      table, sorted by term, a pipe escaped
gl="$TMP/glossrepo"; mkdir -p "$gl" && git -C "$gl" init -q -b main
python3 "$S/apply.py" --target "$gl" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
onefile_ledgers "$gl" track
gl_git() { git -C "$gl" -c user.name=t -c user.email=t@example.com "$@"; }
gl_tool() { ( cd "$gl" && python3 tools/ledgers.py "$@" ); }
gl_git add -A && gl_git commit -q -m "chore: base"
# one-file shape: the row goes into the table of ontology/glossary.md, above the closing comment
gl_tool add-term Order --definition "A confirmed purchase." --not-confused-with "Cart" >/dev/null || miss "glossary: add-term failed in the one-file shape"
grep -qF '| `Order` | A confirmed purchase. | Cart | Order |' "$gl/ontology/glossary.md" || miss "glossary: add-term in the one-file shape wrote no row"
[ -z "$(ls "$gl/ontology/glossary" 2>/dev/null)" ] || miss "glossary: add-term in the one-file shape wrote a fragment"
if gl_tool add-term Order --definition "again" >/dev/null 2>&1; then miss "glossary: add-term twice for one term is green in the one-file shape"; fi
gl_git checkout -q -- ontology/glossary.md && gl_git rm -q --cached ontology/glossary.md && rm -f "$gl/ontology/glossary.md"
gl_git commit -q -m "docs: glossary becomes fragments"
gl_tool draw >/dev/null || miss "glossary: draw failed with no term"
[ "$(sed -n '2,$p' "$gl/ontology/glossary.md" | grep -c '^| ')" = 2 ] || miss "glossary: with no term the drawn file is not the head, a header row and a separator"
gl_tool add-term Order --definition "A confirmed | purchase." --display "Customer order" >/dev/null || miss "glossary: add-term failed in the fragments shape"
gl_tool add-term Customer --definition "A person who has bought." --not-confused-with '`Visitor`' >/dev/null || miss "glossary: add-term Customer failed"
[ "$(gl_git status --porcelain | grep -vc -e ' ontology/glossary.md$' -e '^?? ontology/glossary/')" = 0 ] || miss "glossary: add-term touched more than the fragment folder ($(gl_git status --porcelain | tr '\n' ';'))"
grep -qx 'term: Order' "$gl/ontology/glossary/Order.md" || miss "glossary: the fragment has no term: line"
gl_tool draw >/dev/null || miss "glossary: draw failed on two fragments"
head -1 "$gl/ontology/glossary.md" | grep -E '^<!-- Drawn by tools/ledgers.py from ontology/glossary/\. Edit the source, not this file\. sha256:[0-9a-f]{64} -->$' >/dev/null || miss "glossary: ontology/glossary.md does not open with the stamp line"
grep -qxF '| Term (code name) | Definition | Not to be confused with | Display name |' "$gl/ontology/glossary.md" || miss "glossary: the header row is not the four columns"
rows=$(grep -E '^\| `' "$gl/ontology/glossary.md")
[ "$rows" = "$(printf '%s\n' '| `Customer` | A person who has bought. | `Visitor` | Customer |' '| `Order` | A confirmed \| purchase. |  | Customer order |')" ] || miss "glossary: the rows are not sorted by term with the pipe escaped ($rows)"
cp "$gl/ontology/glossary.md" "$TMP/gl.once"; gl_tool draw >/dev/null
cmp -s "$TMP/gl.once" "$gl/ontology/glossary.md" || miss "glossary: drawing a second time changed a byte"
# terms with a space or a dot: the file name is the term
gl_tool add-term "Sales order" --definition "x" >/dev/null && [ -f "$gl/ontology/glossary/Sales order.md" ] || miss "glossary: a term with a space is not the file name"
gl_tool add-term "v1.2" --definition "x" >/dev/null && [ -f "$gl/ontology/glossary/v1.2.md" ] || miss "glossary: a term with a dot is not the file name"
rc=0; out=$(gl_tool add-term "a/b" --definition x 2>&1) || rc=$?
[ "$rc" = 2 ] && case "$out" in *"/"*) true ;; *) false ;; esac || miss "glossary: add-term a/b exits $rc, or does not name the character ($out)"
rc=0; gl_tool add-term ".hidden" --definition x >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || miss "glossary: add-term with a leading dot exits $rc, not 2"
rc=0; out=$(gl_tool add-term Order --definition again 2>&1) || rc=$?
[ "$rc" = 1 ] && case "$out" in *Order*) true ;; *) false ;; esac || miss "glossary: add-term for an existing term exits $rc, or does not name it ($out)"
# 48l (plan 48i). a fragment whose term differs from its file name, or without display: check names the file
gl_tool check >/dev/null || miss "glossary: check fails on good fragments ($(gl_tool check 2>&1))"
printf -- '---\nterm: Client\ndisplay: Client\nnot_confused_with:\n---\nA buyer.\n' > "$gl/ontology/glossary/Customer.md"
rc=0; out=$(gl_tool check 2>&1) || rc=$?
[ "$rc" = 1 ] && case "$out" in *glossary/Customer.md*) true ;; *) false ;; esac || miss "glossary: check exits $rc, or does not name Customer.md for a different term ($out)"
printf -- '---\nterm: Customer\nnot_confused_with:\n---\nA buyer.\n' > "$gl/ontology/glossary/Customer.md"
rc=0; out=$(gl_tool check 2>&1) || rc=$?
[ "$rc" = 1 ] && case "$out" in *glossary/Customer.md*display*) true ;; *) false ;; esac || miss "glossary: check exits $rc, or does not name the missing display ($out)"
printf -- '---\nterm: Customer\ndisplay: Customer\nnot_confused_with:\n---\nA buyer.\n' > "$gl/ontology/glossary/Customer.md"
# wiki_lint reads the drawn file: a term in it is defined, an entity outside it is a warning
mkdir -p "$gl/ontology/entities"
printf 'name: Customer\n' > "$gl/ontology/entities/Customer.yaml"; printf 'name: Ghost\n' > "$gl/ontology/entities/Ghost.yaml"
gl_tool draw >/dev/null
lint=$(cd "$gl" && python3 tools/wiki_lint.py 2>&1 || true)
case "$lint" in *"entity 'Ghost' is not defined in the glossary"*) ;; *) miss "glossary: wiki_lint does not warn that Ghost is outside the drawn glossary ($lint)" ;; esac
case "$lint" in *"entity 'Customer' is not defined"*) miss "glossary: wiki_lint warns about Customer although the drawn glossary has it" ;; esac
case "$lint" in *"missing glossary"*) miss "glossary: wiki_lint says the drawn glossary is missing" ;; esac
# 48m. a hand edit of the drawn glossary is refused and named; a hand-kept file beside fragments is two sources
cp "$gl/ontology/glossary.md" "$TMP/gl.edit"; printf '| `Typed` | by hand | | Typed |\n' >> "$TMP/gl.edit"; cp "$TMP/gl.edit" "$gl/ontology/glossary.md"
rc=0; out=$(gl_tool draw 2>&1) || rc=$?
[ "$rc" = 1 ] || miss "glossary: draw exits $rc, not 1, on a hand-edited ontology/glossary.md"
case "$out" in *Typed*"ledgers.py add-term"*) ;; *) miss "glossary: draw does not print the added line and the add-term command ($out)" ;; esac
cmp -s "$TMP/gl.edit" "$gl/ontology/glossary.md" || miss "glossary: draw changed a hand-edited ontology/glossary.md"
printf '# Glossary\n' > "$gl/ontology/glossary.md"
rc=0; out=$(gl_tool draw 2>&1) || rc=$?
[ "$rc" = 1 ] && case "$out" in *"two sources"*) true ;; *) false ;; esac || miss "glossary: draw exits $rc, or does not say two sources, for a hand-kept glossary beside fragments ($out)"
[ "$(cat "$gl/ontology/glossary.md")" = "# Glossary" ] || miss "glossary: draw overwrote an unstamped ontology/glossary.md"
# 48n (plan 48j). the wiki index: head, one section per page type in page-types.yaml order, one line per page
ix="$TMP/indexrepo"; mkdir -p "$ix" && git -C "$ix" init -q -b main
python3 "$S/apply.py" --target "$ix" --preset ts-node --level team --var project_name=P --var description=x --var owner=acme >/dev/null
onefile_ledgers "$ix" track
ix_git() { git -C "$ix" -c user.name=t -c user.email=t@example.com "$@"; }
ix_tool() { ( cd "$ix" && python3 tools/ledgers.py "$@" ); }
ix_git add -A && ix_git commit -q -m "chore: base"
ix_git rm -q --cached wiki/index.md && rm -f "$ix/wiki/index.md"
printf -- '---\ntype: entity\ntitle: Customer\nsummary: who buys; VIP rules\n---\n# Customer\n' > "$ix/wiki/entities/customer.md"
printf -- '---\ntype: entity\ntitle: Basket\n---\n# Basket\n' > "$ix/wiki/entities/basket.md"
printf -- '---\ntype: note\ntitle: Odd page\n---\n# Odd\n' > "$ix/wiki/odd.md"
printf 'noise\n' > "$ix/wiki/.DS_Store"; printf -- '---\ntype: entity\ntitle: Hidden\n---\n' > "$ix/wiki/entities/.hidden.md"
printf -- '---\ntype: index\ntitle: Mine\n---\n\n# Mine\n\nHand-written head.\n' > "$ix/wiki/index.head.md"
ix_tool draw >/dev/null || miss "index: draw failed on the pages"
head -1 "$ix/wiki/index.md" | grep -E '^<!-- Drawn by tools/ledgers.py from wiki/\. Edit the source, not this file\. sha256:[0-9a-f]{64} -->$' >/dev/null || miss "index: wiki/index.md does not open with the stamp line"
want=$(printf '%s\n' '---' 'type: index' 'title: Mine' '---' '' '# Mine' '' 'Hand-written head.' '' \
  '## Entities' '' '- [Basket](entities/basket.md)' '- [Customer](entities/customer.md) — who buys; VIP rules' '' \
  '## Decisions' '' '- [Record decisions in the wiki](decisions/0001-record-decisions-in-the-wiki.md)' '' \
  '## Notes' '' '- [Odd page](odd.md)' '' \
  '## Log' '' 'See [log.md](log.md) for a chronological list of changes.')
got=$(tail -n +2 "$ix/wiki/index.md")
[ "$got" = "$want" ] || miss "index: the drawn index is not the head, Entities, Decisions, a type page-types.yaml does not know and the log link ($got)"
case "$got" in *Hidden*|*"index.head"*|*"[Mine]"*|*"## Metrics"*) miss "index: the index lists a dot-file, the head, itself or a type with no page" ;; esac
cp "$ix/wiki/index.md" "$TMP/ix.once"; ix_tool draw >/dev/null
cmp -s "$TMP/ix.once" "$ix/wiki/index.md" || miss "index: drawing a second time changed a byte"
# with no head file the built-in head is used, and it carries no placeholder
rm -f "$ix/wiki/index.head.md"; ix_tool draw >/dev/null || miss "index: draw failed without a head file"
sed -n '2,4p' "$ix/wiki/index.md" | grep -x 'title: Wiki' >/dev/null || miss "index: the built-in head does not carry title: Wiki"
if grep -q '{{' "$ix/wiki/index.md"; then miss "index: the built-in head has a placeholder"; fi
# wiki_lint: the drawn index is not a page, and nothing is unlinked in the fragments shape
ix_tool check >/dev/null || miss "index: check fails on good pages ($(ix_tool check 2>&1))"
lint=$(cd "$ix" && python3 tools/wiki_lint.py 2>&1 || true)
case "$lint" in *"not linked from wiki/index.md"*) miss "index: wiki_lint says a page is not linked from the index in the fragments shape ($lint)" ;; esac
case "$lint" in *"ERROR wiki/index.md"*|*"ERROR wiki/log.md"*) miss "index: wiki_lint treats a drawn file as a page ($lint)" ;; esac
# 48o (plan 48k). a page with no title and a page with broken front matter: draw still draws the others, check and wiki_lint name them
printf -- '---\ntype: entity\n---\n# No title\n' > "$ix/wiki/entities/untitled.md"
printf 'no front matter at all\n' > "$ix/wiki/entities/bare.md"
rc=0; out=$(ix_tool draw 2>&1) || rc=$?
[ "$rc" = 0 ] || miss "index: draw exits $rc, not 0, with a page that has no title ($out)"
grep -qF -- '- [Customer](entities/customer.md) — who buys; VIP rules' "$ix/wiki/index.md" || miss "index: draw did not draw the other pages around a page with no title"
if grep -qE 'untitled|bare' "$ix/wiki/index.md"; then miss "index: the index lists a page with no title"; fi
rc=0; out=$(ix_tool check 2>&1) || rc=$?
[ "$rc" = 1 ] || miss "index: check exits $rc, not 1, for a page with no title"
case "$out" in *entities/untitled.md*) ;; *) miss "index: check does not name wiki/entities/untitled.md ($out)" ;; esac
case "$out" in *entities/bare.md*) ;; *) miss "index: check does not name wiki/entities/bare.md ($out)" ;; esac
lint=$(cd "$ix" && python3 tools/wiki_lint.py 2>&1 || true)
case "$lint" in *"ERROR wiki/entities/untitled.md: page has no type or title"*) ;; *) miss "index: wiki_lint does not say 'page has no type or title' for untitled.md ($lint)" ;; esac
rm -f "$ix/wiki/entities/untitled.md" "$ix/wiki/entities/bare.md"
# a one-file repository keeps the old rules: a page the hand-kept index does not link is still a warning
ix1="$TMP/indexrepo1"; mkdir -p "$ix1" && git -C "$ix1" init -q -b main
python3 "$S/apply.py" --target "$ix1" --preset ts-node --level team --var project_name=P --var description=x --var owner=acme >/dev/null
onefile_ledgers "$ix1" track
git -C "$ix1" add -A && git -C "$ix1" -c user.name=t -c user.email=t@example.com commit -q -m "chore: base"
printf -- '---\ntype: entity\ntitle: Basket\n---\n# Basket\n' > "$ix1/wiki/entities/basket.md"
lint=$(cd "$ix1" && python3 tools/wiki_lint.py 2>&1 || true)
case "$lint" in *"entities/basket.md: not linked from wiki/index.md"*) ;; *) miss "index: wiki_lint dropped 'not linked from wiki/index.md' in the one-file shape ($lint)" ;; esac
# 48p (plan 48l). sdlc_metrics leaves wiki/index.md alone in the fragments shape and edits it in the one-file shape
metrics_link() { ( cd "$1" && python3 -c "
import sys; sys.path.insert(0, 'tools'); import sdlc_metrics as s, pathlib
s.link_in_index(pathlib.Path('.'), '2026-W07')" ); }
ix_tool draw >/dev/null; cp "$ix/wiki/index.md" "$TMP/ix.before"; ix_status=$(ix_git status --porcelain wiki/index.md)
metrics_link "$ix" || miss "index: link_in_index failed in the fragments shape"
cmp -s "$TMP/ix.before" "$ix/wiki/index.md" || miss "index: link_in_index changed the drawn wiki/index.md"
[ "$(ix_git status --porcelain wiki/index.md)" = "$ix_status" ] || miss "index: link_in_index changed wiki/index.md in git status ($(ix_git status --porcelain wiki/index.md))"
mkdir -p "$ix/wiki/metrics"
printf -- '---\ntype: metrics\ntitle: Delivery metrics 2026-W07\n---\n# m\n\n## Summary\n\n## Delivery\n\n## Agents\n\n## Notes\n' > "$ix/wiki/metrics/2026-W07.md"
ix_tool draw >/dev/null
grep -qF -- '- [Delivery metrics 2026-W07](metrics/2026-W07.md)' "$ix/wiki/index.md" || miss "index: the weekly metrics page does not show up in the drawn index"
metrics_link "$ix1" && grep -qF -- '- [2026-W07](metrics/2026-W07.md)' "$ix1/wiki/index.md" || miss "index: link_in_index no longer adds its line in the one-file shape"
# 48q. hidden files (.DS_Store) in the two fragment folders are not fragments
mkdir -p "$ix/wiki/log" "$ix/ontology/glossary"; printf 'x\n' > "$ix/wiki/log/.DS_Store"; printf 'x\n' > "$ix/ontology/glossary/.DS_Store"
ix_tool check >/dev/null 2>&1 || miss "index: a .DS_Store in wiki/log/ or ontology/glossary/ turns check red ($(ix_tool check 2>&1))"
ix_tool draw >/dev/null 2>&1 || miss "index: a .DS_Store in a fragment folder makes draw refuse"
# 48r. the index has no fragment folder, so it is never two sources: a head file beside a hand-kept wiki/index.md
#      (tracked, or untracked before the first commit) is no reason to refuse
printf -- '---\ntype: index\ntitle: Mine\n---\n\n# Mine\n' > "$ix1/wiki/index.head.md"; cp "$ix1/wiki/index.md" "$TMP/ix1.before"
rc=0; out=$( cd "$ix1" && python3 tools/ledgers.py draw 2>&1 ) || rc=$?
[ "$rc" = 0 ] || miss "index: draw exits $rc, not 0, for a tracked hand-kept wiki/index.md beside wiki/index.head.md ($out)"
rc=0; out=$( cd "$ix1" && python3 tools/ledgers.py check 2>&1 ) || rc=$?
[ "$rc" = 0 ] || miss "index: check exits $rc, not 0, for a tracked hand-kept wiki/index.md beside wiki/index.head.md ($out)"
cmp -s "$TMP/ix1.before" "$ix1/wiki/index.md" || miss "index: draw or check changed a tracked hand-kept wiki/index.md"
ix0="$TMP/indexrepo0"; mkdir -p "$ix0" && git -C "$ix0" init -q -b main
python3 "$S/apply.py" --target "$ix0" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
onefile_ledgers "$ix0"
printf -- '---\ntype: index\ntitle: Mine\n---\n\n# Mine\n' > "$ix0/wiki/index.head.md"; cp "$ix0/wiki/index.md" "$TMP/ix0.before"
# untracked and unstamped: refused and named (new pages would never show up), kept, but not two sources
rc=0; out=$( cd "$ix0" && python3 tools/ledgers.py draw 2>&1 ) || rc=$?
[ "$rc" = 1 ] || miss "index: draw exits $rc, not 1, for an untracked unstamped wiki/index.md ($out)"
case "$out" in *wiki/index.md*"delete wiki/index.md"*"make derived"*) ;; *) miss "index: the refusal of an untracked unstamped wiki/index.md does not say to delete it and run make derived ($out)" ;; esac
cmp -s "$TMP/ix0.before" "$ix0/wiki/index.md" || miss "index: draw changed an untracked unstamped wiki/index.md"
case "$out" in *"two sources"*) miss "index: draw says two sources for the index ($out)" ;; esac
# 48s (plan 48m). the code generated from ontology/ is drawn, stamped, and never committed in the fragments shape;
#      a repository that still commits it keeps today's behaviour exactly. The real `make test` on a clean
#      clone (npm ci, uv sync) is left to tests/e2e.sh; here the draw is proved, and that it comes first.
gn_make() { ( cd "$1" && shift && make "$@" 2>&1 ); }
gn_check_stamp() { # <file> <label>: the first line carries sha256 of everything after it
  python3 - "$1" <<'PY' 2>/dev/null || miss "gen: $2: the stamp is not the sha256 of the body"
import hashlib, re, sys
text = open(sys.argv[1], encoding="utf-8").read()
first, _, body = text.partition("\n")
m = re.search(r" sha256:([0-9a-f]{64})", first)
assert m and hashlib.sha256(body.encode()).hexdigest() == m.group(1)
PY
}
gn_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }
gn="$TMP/genrepo"; mkdir -p "$gn" && git -C "$gn" init -q -b main
python3 "$S/apply.py" --target "$gn" --preset ts-node --level starter --var project_name=G --var description=x --var owner=acme >/dev/null
gn_git() { git -C "$gn" -c user.name=t -c user.email=t@example.com "$@"; }
gn_out=src/generated/ontology.ts
# one-file: the file is committed, as today; make derived leaves it alone and make ontology still compares it
( cd "$gn" && python3 tools/ontology_codegen.py --lang ts --out $gn_out >/dev/null )
gn_git add -A && gn_git add -f "$gn_out" && gn_git commit -q -m "chore: base"
[ "$(cd "$gn" && python3 tools/ledgers.py shape gen --gen-out $gn_out)" = one-file ] || miss "gen: shape gen is not one-file for a committed unstamped $gn_out"
cp "$gn/$gn_out" "$TMP/gn.before"
gn_make "$gn" derived >/dev/null || miss "gen: make derived fails in the one-file shape"
cmp -s "$TMP/gn.before" "$gn/$gn_out" || miss "gen: make derived changed a committed one-file $gn_out"
gn_make "$gn" ontology >/dev/null || miss "gen: make ontology is red for an up to date committed $gn_out"
printf '// edited by hand\n' >> "$gn/$gn_out"; cp "$gn/$gn_out" "$TMP/gn.handedit"
if gn_make "$gn" ontology >/dev/null; then miss "gen: make ontology is green for a committed $gn_out that is out of date (one-file shape)"; fi
gn_make "$gn" derived >/dev/null; cmp -s "$TMP/gn.handedit" "$gn/$gn_out" || miss "gen: make derived overwrote a hand edit of a committed one-file $gn_out"
gn_git checkout -q -- "$gn_out"
# fragments: out of git and off disk; make derived draws it, stamped, and a second run writes no byte
gn_git rm -q --cached "$gn_out"; rm -f "$gn/$gn_out"
[ "$(cd "$gn" && python3 tools/ledgers.py shape gen --gen-out $gn_out)" = fragments ] || miss "gen: shape gen is not fragments for an absent $gn_out"
gn_make "$gn" derived >/dev/null || miss "gen: make derived fails in the fragments shape"
[ -f "$gn/$gn_out" ] || miss "gen: make derived did not draw $gn_out"
head -1 "$gn/$gn_out" | grep '^// Generated from ontology/ by tools/ontology_codegen.py\. Do not edit: run `make gen`\. sha256:[0-9a-f]\{64\}$' >/dev/null || miss "gen: the first line of the drawn $gn_out is not the generator header plus a sha256 stamp ($(head -1 "$gn/$gn_out"))"
gn_check_stamp "$gn/$gn_out" ts
( cd "$gn" && python3 tools/ontology_codegen.py --lang ts --out "$TMP/gn.direct.ts" >/dev/null )
[ "$(tail -n +2 "$gn/$gn_out")" = "$(tail -n +2 "$TMP/gn.direct.ts")" ] || miss "gen: the body of the drawn $gn_out differs from what ontology_codegen.py writes"
cp "$gn/$gn_out" "$TMP/gn.drawn"; touch -t 202001010000 "$gn/$gn_out"; gn_t=$(gn_mtime "$gn/$gn_out")
out=$(gn_make "$gn" derived); cmp -s "$TMP/gn.drawn" "$gn/$gn_out" || miss "gen: a second make derived changed $gn_out"
[ "$(gn_mtime "$gn/$gn_out")" = "$gn_t" ] || miss "gen: a second make derived rewrote $gn_out (it must write no byte when nothing changed)"
case "$out" in *drew*) miss "gen: a second make derived is not quiet ($out)" ;; esac
gn_make "$gn" derived-untracked >/dev/null || miss "gen: derived-untracked is red for a drawn $gn_out that is out of git"
gn_make "$gn" ontology >/dev/null || miss "gen: make ontology is red in the fragments shape ($(gn_make "$gn" ontology))"
# make test and make build draw it first
out=$(gn_make "$gn" -n test); case "$out" in *"ledgers.py draw-gen"*"npm run --silent test"*) ;; *) miss "gen: make -n test does not draw $gn_out before the test step ($out)" ;; esac
out=$(gn_make "$gn" -n build); case "$out" in *"ledgers.py draw-gen"*"npm run build"*) ;; *) miss "gen: make -n build does not draw $gn_out before the build ($out)" ;; esac
rm -f "$gn/$gn_out"; gn_make "$gn" derived >/dev/null; [ -f "$gn/$gn_out" ] || miss "gen: make derived did not draw a deleted $gn_out again"
# a change in ontology/ is drawn again; a hand edit is refused and named, never overwritten
python3 "$ROOT/tests/apply_fixture.py" coffee "$gn" >/dev/null
gn_make "$gn" derived >/dev/null; grep -q 'isVIPCustomer' "$gn/$gn_out" || miss "gen: make derived did not draw again after ontology/ changed"
gn_check_stamp "$gn/$gn_out" ts-again
printf '// by hand\n' >> "$gn/$gn_out"; cp "$gn/$gn_out" "$TMP/gn.edited"
rc=0; out=$(gn_make "$gn" derived) || rc=$?
[ "$rc" != 0 ] || miss "gen: make derived is green for a hand-edited $gn_out"
case "$out" in *"$gn_out"*"ontology/"*"make derived"*) ;; *) miss "gen: the refusal does not name $gn_out and say to edit ontology/ and run make derived ($out)" ;; esac
cmp -s "$TMP/gn.edited" "$gn/$gn_out" || miss "gen: a hand-edited $gn_out was overwritten"
# an unstamped file that git does not know and the generator did not write: refused, named, kept
printf '// mine\n' > "$gn/$gn_out"
rc=0; out=$(gn_make "$gn" derived) || rc=$?
[ "$rc" != 0 ] && case "$out" in *"$gn_out"*"make derived"*) true ;; *) false ;; esac || miss "gen: make derived exits $rc or does not name an untracked unstamped $gn_out that the generator did not write ($out)"
[ "$(cat "$gn/$gn_out")" = "// mine" ] || miss "gen: an untracked unstamped $gn_out was overwritten"
# a drawn file that is in git is red
rm -f "$gn/$gn_out"; gn_make "$gn" derived >/dev/null; gn_git add -f "$gn_out"
if gn_make "$gn" derived-untracked >/dev/null; then miss "gen: derived-untracked is green for a drawn $gn_out in git"; fi
gn_git rm -q --cached "$gn_out"
# the package.json of the two Node presets draws on npm ci / npm install
for pj in "$ROOT"/plugins/repo-setup/presets/ts-node/starter/package.json.tmpl "$ROOT"/plugins/repo-setup/presets/react-vite/starter/package.json.tmpl; do
  grep -qF '"prepare": "command -v make >/dev/null 2>&1 && make -s derived || true"' "$pj" || miss "gen: $pj has no prepare script that draws"
done
# python: the same, with the file under src/<pkg>/ and the stamp before the closing quotes of the docstring
gq="$TMP/genrepo-py"; mkdir -p "$gq" && git -C "$gq" init -q -b main
python3 "$S/apply.py" --target "$gq" --preset python --level starter --var project_name=Gq --var description=x --var owner=acme >/dev/null
gq_out=src/gq/ontology_types.py
gq_make() { ( cd "$gq" && make PYTHON=python3 "$@" 2>&1 ); }
gq_make derived >/dev/null || miss "gen: python: make derived fails in the fragments shape"
head -1 "$gq/$gq_out" | grep '^"""Generated from ontology/ by tools/ontology_codegen.py\. Do not edit: run `make gen`\. sha256:[0-9a-f]\{64\}"""$' >/dev/null || miss "gen: python: the first line is not the docstring with the stamp before the closing quotes ($(head -1 "$gq/$gq_out"))"
python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$gq/$gq_out" || miss "gen: python: the drawn file is not valid python"
gn_check_stamp "$gq/$gq_out" python
cp "$gq/$gq_out" "$TMP/gq.drawn"; gq_make derived >/dev/null; cmp -s "$TMP/gq.drawn" "$gq/$gq_out" || miss "gen: python: a second make derived changed the file"
out=$(gq_make -n test); case "$out" in *"ledgers.py draw-gen"*"pytest"*) ;; *) miss "gen: python: make -n test does not draw before pytest ($out)" ;; esac
gq_make ontology >/dev/null || miss "gen: python: make ontology is red in the fragments shape"
# python one-file: committed and edited, make ontology is red as today
rm -f "$gq/$gq_out"; ( cd "$gq" && python3 tools/ontology_codegen.py --lang python --out $gq_out >/dev/null )
git -C "$gq" add -A; git -C "$gq" add -f "$gq_out"; git -C "$gq" -c user.name=t -c user.email=t@example.com commit -q -m "chore: base"
printf '# x\n' >> "$gq/$gq_out"
if gq_make ontology >/dev/null; then miss "gen: python: make ontology is green for an out of date committed file (one-file shape)"; fi
# 48t (plan 48n). the image waits for derived; the drawn file reaches the build context
gc="$TMP/gen-container"; mkdir -p "$gc" && git -C "$gc" init -q -b main
python3 "$S/apply.py" --target "$gc" --preset ts-api --deploy container --level team --var project_name=Gc --var description=x --var owner=acme/platform >/dev/null
for t in image up deploy; do
  out=$(cd "$gc" && make -n "$t" 2>&1 || true)
  case "$out" in *"ledgers.py draw-gen"*"docker "*) ;; *) miss "gen: container: make $t does not draw before docker ($out)" ;; esac
done
if grep -qxE 'src/?|src/\*\*|src/generated/?|\*\.ts|\*\.py' "$gc/.dockerignore"; then miss "gen: container: .dockerignore leaves the drawn file out of the build context"; fi
# 48u-48w. split moves a one-file ledger into fragments, in a pull request of its own, without losing
#      an entry (spec section 6.3). The fixtures in tests/fixtures/ledgers/ imitate shapes seen in an
#      older repository: an index in insertion order, 20 log lines on one day, a hand paragraph
#      between the glossary intro and its table, terms with a space and a dot.
LF="$ROOT/tests/fixtures/ledgers"
sp_new() { # <dir>: a ts-node repository with the fixture ledgers and a committed generated file, all one-file
  mkdir -p "$1" && git -C "$1" init -q -b main
  python3 "$S/apply.py" --target "$1" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
  cp -R "$LF/." "$1/"
  ( cd "$1" && python3 tools/ontology_codegen.py --lang ts --out src/generated/ontology.ts >/dev/null )
  git -C "$1" add -A && git -C "$1" add -f wiki/log.md wiki/index.md ontology/glossary.md src/generated/ontology.ts && git -C "$1" -c user.name=t -c user.email=t@example.com commit -q -m "chore: base"
}
sp_snap() { # <dir>: one hash of every file outside .git and of the git index
  python3 - "$1" <<'PY'
import hashlib, pathlib, subprocess, sys
root = pathlib.Path(sys.argv[1]); h = hashlib.sha256()
for p in sorted(q for q in root.rglob("*") if q.is_file() and not {".git", "__pycache__"} & set(q.relative_to(root).parts)):
    h.update(p.relative_to(root).as_posix().encode() + b"\0" + p.read_bytes() + b"\0")
h.update(subprocess.run(["git", "-C", str(root), "ls-files", "-s"], capture_output=True).stdout)
print(h.hexdigest())
PY
}
sp_rows() { # <glossary file>: the table rows as cells, read without the code under test
  python3 - "$1" <<'PY'
import re, sys
rows = []
for line in open(sys.argv[1], encoding="utf-8"):
    if not line.startswith("|") or "Term (code name)" in line or re.match(r"^\|[\s|:-]+\|\s*$", line) or "_Example:_" in line:
        continue
    cells = [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", line.strip())[1:-1]]
    cells[0] = cells[0].strip("`")
    rows.append(" | ".join(cells))
print("\n".join(sorted(rows)))
PY
}
sp_log_lines() { grep -E '^- [0-9]{4}-[0-9]{2}-[0-9]{2} — ' "$1" | LC_ALL=C sort; }
sp="$TMP/split"; sp_new "$sp"
sp_git() { git -C "$sp" -c user.name=t -c user.email=t@example.com "$@"; }
sp_tool() { ( cd "$sp" && python3 tools/ledgers.py "$@" ); }
sp_gen=src/generated/ontology.ts
sp_lint_errors() { ( cd "$sp" && python3 tools/wiki_lint.py 2>&1 | grep '^ERROR' | LC_ALL=C sort || true ); }
sp_lint_before=$(sp_lint_errors)
# 48u (plan 48o). each of the four ledgers: --dry-run writes nothing; split leaves the fragments shape,
#      the old path out of git and in .gitignore, every check green, and the drawn file with the same entries
for L in log index glossary gen; do
  case $L in log) old=wiki/log.md ;; index) old=wiki/index.md ;; glossary) old=ontology/glossary.md ;; gen) old=$sp_gen ;; esac
  cp "$sp/$old" "$TMP/split.old.$L"
  before=$(sp_snap "$sp")
  rc=0
  if [ $L = gen ]; then out=$( cd "$sp" && make -s PYTHON=python3 split L=gen DRY=1 2>&1 ) || rc=$?
  else out=$(sp_tool split $L --dry-run 2>&1) || rc=$?; fi
  [ "$rc" = 0 ] || miss "split: split $L --dry-run exits $rc ($out)"
  [ "$(sp_snap "$sp")" = "$before" ] || miss "split: split $L --dry-run wrote or removed a file"
  case "$out" in *"$old"*) ;; *) miss "split: split $L --dry-run does not name $old ($out)" ;; esac
  rc=0
  if [ $L = gen ]; then out=$( cd "$sp" && make -s PYTHON=python3 split L=gen 2>&1 ) || rc=$?
  else out=$(sp_tool split $L 2>&1) || rc=$?; fi
  [ "$rc" = 0 ] || miss "split: split $L exits $rc ($out)"
  printf '%s\n' "$out" > "$TMP/split.out.$L"
  gen_arg=""; [ $L = gen ] && gen_arg="--gen-out $sp_gen"
  [ "$(sp_tool shape $L $gen_arg)" = fragments ] || miss "split: shape $L is not fragments after split"
  [ -z "$(sp_git ls-files -- "$old")" ] || miss "split: $old is still in git after split $L"
  grep -qxF "$old" "$sp/.gitignore" || miss "split: .gitignore has no line $old after split $L"
  [ -f "$sp/$old" ] || miss "split: split $L left no drawn $old"
  case "$out" in *"deleted here, modified there"*) ;; *) miss "split: split $L does not remind open pull requests of the conflict they get ($out)" ;; esac
done
case "$(cat "$TMP/split.out.log")" in *'make log m='*) ;; *) miss "split: split log does not say to run make log again on an open branch" ;; esac
sp_tool check >/dev/null 2>&1 || miss "split: ledgers.py check is red after the four splits ($(sp_tool check 2>&1))"
( cd "$sp" && make -s PYTHON=python3 derived >/dev/null 2>&1 ) || miss "split: make derived is red after the four splits ($(cd "$sp" && make -s PYTHON=python3 derived 2>&1))"
( cd "$sp" && make -s PYTHON=python3 derived-untracked >/dev/null 2>&1 ) || miss "split: make derived-untracked is red after the four splits"
[ "$(sp_lint_errors)" = "$sp_lint_before" ] || miss "split: wiki_lint reports other errors after the four splits ($(sp_lint_errors))"
[ "$(sp_log_lines "$sp/wiki/log.md")" = "$(sp_log_lines "$TMP/split.old.log")" ] || miss "split: the drawn log does not carry the entries of the old one"
[ "$(sp_rows "$sp/ontology/glossary.md")" = "$(sp_rows "$TMP/split.old.glossary")" ] || miss "split: the drawn glossary does not carry the rows of the old one ($(sp_rows "$sp/ontology/glossary.md"))"
for page in entities/warehouse.md entities/bin.md entities/stock-move.md flows/receiving.md decisions/0001-record-decisions-in-the-wiki.md; do
  grep -qF "]($page)" "$sp/wiki/index.md" || miss "split: the drawn index lost the link to $page"
done
head -1 "$sp/$sp_gen" | grep ' sha256:[0-9a-f]\{64\}$' >/dev/null || miss "split: the generated file is not drawn stamped after split gen"
[ "$(tail -n +2 "$sp/$sp_gen")" = "$(tail -n +2 "$TMP/split.old.gen")" ] || miss "split: the drawn generated code differs from the committed one"
rc=0; out=$(sp_tool split log 2>&1) || rc=$?
[ "$rc" = 0 ] && case "$out" in *"already split"*) true ;; *) false ;; esac || miss "split: a second split log exits $rc or does not say it is already split ($out)"
sp_git add -A && sp_git commit -q -m "docs: split the ledgers"
[ -z "$(sp_git ls-files -- wiki/log.md wiki/index.md ontology/glossary.md "$sp_gen")" ] || miss "split: a drawn file was committed after split"
# 48v (plan 48p). the three shapes of the fixtures
gh="$sp/ontology/glossary.head.md"
grep -qF 'Terms below follow the names used on the floor' "$gh" || miss "split: the hand paragraph of the glossary did not move to ontology/glossary.head.md"
grep -qF 'One line per business term' "$gh" || miss "split: the glossary intro did not move to ontology/glossary.head.md"
if grep -qE '^\||Add your terms above' "$gh"; then miss "split: ontology/glossary.head.md keeps a table row or the template comment"; fi
case "$(cat "$TMP/split.out.glossary")" in *"_Example:_"*) ;; *) miss "split: split glossary does not say it dropped the _Example:_ row" ;; esac
[ -f "$sp/ontology/glossary/Stock move.md" ] && [ -f "$sp/ontology/glossary/Lot.Code.md" ] || miss "split: a term with a space or a dot is not its fragment's file name ($(ls "$sp/ontology/glossary" | tr '\n' ';'))"
grep -qx 'term: Stock move' "$sp/ontology/glossary/Stock move.md" || miss "split: the fragment of 'Stock move' does not carry term: Stock move"
grep -qxF 'not_confused_with: `Transfer` | `Shipment`' "$sp/ontology/glossary/Stock move.md" || miss "split: the escaped pipe of a cell is not unescaped in the fragment"
if grep -rq 'Customer' "$sp/ontology/glossary/"; then miss "split: the _Example:_ row became a fragment"; fi
[ "$(grep '^- 2026-06-02 — ' "$sp/wiki/log.md")" = "$(grep '^- 2026-06-02 — ' "$TMP/split.old.log")" ] || miss "split: the 20 lines of one day are not in the same order after split"
[ "$(ls "$sp/wiki/log" | grep -c '^2026-06-02-')" = 20 ] || miss "split: the 20 lines of one day are not 20 fragments"
[ -f "$sp/wiki/log/2026-06-02-20-zone-codes-printed-on-every-bin-label-40.md" ] && [ -f "$sp/wiki/log/2026-06-02-01-first-entry-of-a-long-day.md" ] || miss "split: the top line of a day is not its highest NN ($(ls "$sp/wiki/log" | tr '\n' ';'))"
grep -qF 'Repository created with repo-setup' "$sp/wiki/log.md" || miss "split: the template's first log line was dropped"
grep -qx 'type: log' "$sp/wiki/log.head.md" && grep -qF 'Newest first.' "$sp/wiki/log.head.md" || miss "split: wiki/log.head.md is not the head of the old log"
if grep -q '^- 20' "$sp/wiki/log.head.md"; then miss "split: an entry stayed in wiki/log.head.md"; fi
grep -qx 'summary: a building that holds stock' "$sp/wiki/entities/warehouse.md" || miss "split: the description after — did not move to the summary of the page"
grep -qx 'summary: the smallest place stock sits; one zone each' "$sp/wiki/entities/bin.md" && ! grep -q 'an older text' "$sp/wiki/entities/bin.md" || miss "split: the summary of a page was not replaced by the description of the index"
grep -qx 'owner: stock team' "$sp/wiki/entities/bin.md" || miss "split: split index changed another key of a page"
if grep -q '^summary:' "$sp/wiki/entities/stock-move.md"; then miss "split: a page linked with no description got a summary"; fi
grep -qxF -- '- [Warehouse](entities/warehouse.md) — a building that holds stock' "$sp/wiki/index.md" || miss "split: the drawn index does not show the description as the summary"
ih="$sp/wiki/index.head.md"
grep -qF 'Read the receiving flow first' "$ih" && grep -qF '[Supplier portal](https://example.com/portal)' "$ih" || miss "split: a paragraph or a link to no page did not stay in wiki/index.head.md"
if grep -qE '^## (Entities|Flows|Decisions|Log)$|^- \[Warehouse\]' "$ih"; then miss "split: wiki/index.head.md keeps a heading the index draws, or an entry"; fi
[ "$(grep -c '^## Entities$' "$sp/wiki/index.md")" = 1 ] && [ "$(grep -c '^## Log$' "$sp/wiki/index.md")" = 1 ] || miss "split: the drawn index has a doubled section"
case "$(cat "$TMP/split.out.index")" in *entities/zone.md*) ;; *) miss "split: split index does not name the page it adds (entities/zone.md)" ;; esac
case "$(cat "$TMP/split.out.index")" in *moved*) ;; *) miss "split: split index does not print the entries whose order changed" ;; esac
# 48w (plan 48q). a lost entry stops the comparison; a head file is overwritten only while it is as repo-setup wrote it
rm "$sp"/wiki/log/2026-06-02-*-warehouse-page-opening-hours*.md
rc=0; out=$(sp_tool split log --verify-against "$TMP/split.old.log" 2>&1) || rc=$?
[ "$rc" = 1 ] && case "$out" in *"Warehouse page: opening hours"*) true ;; *) false ;; esac || miss "split: a missing fragment is not named, or the comparison exits $rc, not 1 ($out)"
sp_git checkout -q -- wiki/log
rc=0; sp_tool split log --verify-against "$TMP/split.old.log" >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] || miss "split: the comparison exits $rc for a complete set of fragments"
sb="$TMP/split-b"; sp_new "$sb"
sb_git() { git -C "$sb" -c user.name=t -c user.email=t@example.com "$@"; }
sb_tool() { ( cd "$sb" && python3 tools/ledgers.py "$@" ); }
sb_refused() { # <label> <args...>: split exits 1 and writes nothing
  label=$1; shift; before=$(sp_snap "$sb"); rc=0; out=$(sb_tool split "$@" 2>&1) || rc=$?
  [ "$rc" = 1 ] || miss "split: $label: split exits $rc, not 1 ($out)"
  [ "$(sp_snap "$sb")" = "$before" ] || miss "split: $label: split wrote or removed a file"
}
# two sources: the old file in git and a fragment beside it
mkdir -p "$sb/wiki/log" && printf 'x\n' > "$sb/wiki/log/2026-01-01-01-x.md"
sb_refused "two sources" log; case "$out" in *"two sources"*) ;; *) miss "split: two sources are not named ($out)" ;; esac
rm -rf "$sb/wiki/log"
# a term that cannot be a file name, and more than 99 entries on one day
cp "$sb/ontology/glossary.md" "$TMP/sb.gl"
awk '{ print } /^\| `Bin`/ { print "| `In/Out` | x. | | In out |" }' "$TMP/sb.gl" > "$sb/ontology/glossary.md"
sb_refused "a term with a slash" glossary; case "$out" in *"In/Out"*) ;; *) miss "split: the term that cannot be a file name is not named ($out)" ;; esac
cp "$TMP/sb.gl" "$sb/ontology/glossary.md"
cp "$sb/wiki/log.md" "$TMP/sb.log"; i=0; while [ $i -lt 100 ]; do printf -- '- 2026-07-01 — line %s\n' $i >> "$sb/wiki/log.md"; i=$((i + 1)); done
sb_refused "100 entries on one day" log; case "$out" in *99*) ;; *) miss "split: 100 entries on one day are refused without saying the limit is 99 ($out)" ;; esac
cp "$TMP/sb.log" "$sb/wiki/log.md"
# a page the index links that has no title: it would vanish from the drawn index
cp "$sb/wiki/entities/warehouse.md" "$TMP/sb.wh"; printf -- '---\ntype: entity\n---\n# Warehouse\n' > "$sb/wiki/entities/warehouse.md"
sb_refused "a linked page with no title" index; case "$out" in *entities/warehouse.md*) ;; *) miss "split: the page with no title is not named ($out)" ;; esac
cp "$TMP/sb.wh" "$sb/wiki/entities/warehouse.md"
# a head file: edited, refused; as repo-setup wrote it (its hash in .repo-setup.json), overwritten
printf -- '---\ntype: log\ntitle: Log\n---\n\n# Log\n' > "$sb/wiki/log.head.md"
( cd "$sb" && python3 - <<'PY'
import hashlib, json, pathlib
m = pathlib.Path(".repo-setup.json"); d = json.loads(m.read_text())
d["files"]["wiki/log.head.md"] = hashlib.sha256(pathlib.Path("wiki/log.head.md").read_bytes()).hexdigest()
m.write_text(json.dumps(d, indent=2) + "\n")
PY
)
sb_git add -A && sb_git commit -q -m "chore: head file from the template"
printf 'A line typed by hand.\n' >> "$sb/wiki/log.head.md"
sb_refused "an edited head file" log; case "$out" in *wiki/log.head.md*) ;; *) miss "split: the edited head file is not named ($out)" ;; esac
sb_git checkout -q -- wiki/log.head.md
rc=0; out=$(sb_tool split log 2>&1) || rc=$?
[ "$rc" = 0 ] || miss "split: a head file as repo-setup wrote it is refused ($out)"
grep -qF 'Newest first.' "$sb/wiki/log.head.md" || miss "split: a head file as repo-setup wrote it was not overwritten"
# 48x (fix round 1, plan 48o). whitespace inside an entry is collapsed, as add-log and add-term write it,
#      and said; an empty display name becomes the term, as add-term makes it
sc="$TMP/split-c"; mkdir -p "$sc"; sp_new "$sc"
sc_tool() { ( cd "$sc" && python3 tools/ledgers.py "$@" ); }
python3 - "$sc" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
def edit(rel, old, new):
    path = root / rel; text = path.read_text(encoding="utf-8"); assert old in text, (rel, old)
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
edit("wiki/log.md", "Dock 3 opens for returns", "Dock 3  opens\tfor returns")
edit("ontology/glossary.md", "One change of place of one lot.", "One change  of place\tof one lot.")
edit("ontology/glossary.md", "| Lot code     |", "|              |")
edit("wiki/index.md", "goods in, counted twice", "goods in,  counted\ttwice")
PY
git -C "$sc" add -A && git -C "$sc" -c user.name=t -c user.email=t@example.com commit -q -m "docs: whitespace"
for L in log glossary index; do
  rc=0; out=$(sc_tool split $L 2>&1) || rc=$?
  [ "$rc" = 0 ] || miss "split: split $L exits $rc for an entry with a double space and a tab ($out)"
  case "$out" in *"whitespace collapsed"*) ;; *) miss "split: split $L does not say it collapsed the whitespace of an entry ($out)" ;; esac
  printf '%s\n' "$out" > "$TMP/split.ws.$L"
done
grep -qxF -- '- 2026-06-02 — Dock 3 opens for returns' "$sc/wiki/log.md" || miss "split: the log entry with a double space and a tab is not drawn as one line"
[ "$(cat "$sc"/wiki/log/2026-06-02-*-dock-3-opens-for-returns.md 2>/dev/null)" = "Dock 3 opens for returns" ] || miss "split: the log fragment is not in the form add-log writes"
grep -qxF 'One change of place of one lot.' "$sc/ontology/glossary/Stock move.md" || miss "split: the glossary definition is not in the form add-term writes"
grep -qx 'display: Lot.Code' "$sc/ontology/glossary/Lot.Code.md" || miss "split: an empty display name did not become the term"
case "$(cat "$TMP/split.ws.glossary")" in *"display set to term: Lot.Code"*) ;; *) miss "split: split glossary does not say the display name was set to the term" ;; esac
grep -qx 'summary: goods in, counted twice' "$sc/wiki/flows/receiving.md" || miss "split: the index description is not in one-line form in the summary"
sc_tool check >/dev/null 2>&1 || miss "split: ledgers.py check is red after a split that collapsed whitespace ($(sc_tool check 2>&1))"
# 48y (fix round 1). an error while writing leaves nothing half done: git and every file as before
if [ "$(id -u)" != 0 ]; then
  # an older repository: its .gitignore has no line for the drawn glossary yet, so split has to write one
  grep -vxF 'ontology/glossary.md' "$sb/.gitignore" > "$sb/.gitignore.tmp"; mv "$sb/.gitignore.tmp" "$sb/.gitignore"
  chmod 444 "$sb/.gitignore"; st=$(sb_git status --porcelain)
  sb_refused "a read-only .gitignore" glossary; case "$out" in *.gitignore*) ;; *) miss "split: a read-only .gitignore is not named ($out)" ;; esac
  [ "$(sb_git status --porcelain)" = "$st" ] || miss "split: a read-only .gitignore changed git status ($(sb_git status --porcelain | tr '\n' ';'))"
  chmod 644 "$sb/.gitignore"
else
  echo "skip  split: read-only .gitignore (running as root)"
fi
before=$(sp_snap "$sb"); st=$(sb_git status --porcelain)
rc=0; out=$( cd "$sb" && python3 - 2>&1 <<'PY'
import sys
sys.path.insert(0, "tools")
import ledgers, ledgers_split
real, calls = ledgers_split.write_file, []
def failing(path, text, created):  # the third file fails: two are written, one folder is made
    calls.append(path)
    if len(calls) == 3:
        raise OSError("disk full (test)")
    real(path, text, created)
ledgers_split.write_file = failing
sys.exit(ledgers.main(["split", "glossary"]))
PY
) || rc=$?
[ "$rc" = 1 ] && case "$out" in *"disk full"*"back as they were"*) true ;; *) false ;; esac || miss "split: a write that fails half way exits $rc, or does not say it put everything back ($out)"
[ "$(sp_snap "$sb")" = "$before" ] || miss "split: a write that fails half way left a file behind or changed one"
[ "$(sb_git status --porcelain)" = "$st" ] || miss "split: a write that fails half way left git changed ($(sb_git status --porcelain | tr '\n' ';'))"
[ "$(sb_tool shape glossary)" = one-file ] || miss "split: after a write that failed half way the glossary is not one-file again"
# 48z (plan 48r). a new repository keeps its three ledgers as fragments, in every preset: nothing the
#      machine draws is in git after the first commit, and a clean clone draws it and passes the checks.
#      The real `make check` per preset (npm ci, uv sync) is left to tests/e2e.sh.
for nw_preset in $PRESETS; do
  nw="$TMP/newrepo-$nw_preset"; mkdir -p "$nw" && git -C "$nw" init -q -b main
  python3 "$S/apply.py" --target "$nw" --preset "$nw_preset" --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
  nw_git() { git -C "$nw" -c user.name=t -c user.email=t@example.com "$@"; }
  case $nw_preset in ts-node|ts-api|react-vite) nw_gen=src/generated/ontology.ts ;; python|fastapi) nw_gen=src/p/ontology_types.py ;; *) nw_gen="" ;; esac
  for nw_l in log index glossary; do
    [ "$(cd "$nw" && python3 tools/ledgers.py shape $nw_l 2>&1)" = fragments ] || miss "new repo ($nw_preset): shape $nw_l is not fragments"
  done
  ( cd "$nw" && make derived PYTHON=python3 >/dev/null 2>&1 ) || miss "new repo ($nw_preset): make derived is red before the first commit"
  nw_git add -A && nw_git commit -q -m "chore: base"
  nw_tracked=$(nw_git ls-files | grep -xE "wiki/log.md|wiki/index.md|ontology/glossary.md|${nw_gen:-no-gen-file}" || true)
  [ -z "$nw_tracked" ] || miss "new repo ($nw_preset): the first commit holds drawn files: $(echo $nw_tracked)"
  if [ "$nw_preset" != claude-plugin ]; then
    for nw_f in wiki/log.head.md wiki/index.head.md ontology/glossary.head.md wiki/log/.gitkeep ontology/glossary/.gitkeep; do
      nw_git ls-files --error-unmatch "$nw_f" >/dev/null 2>&1 || miss "new repo ($nw_preset): $nw_f is not part of the first commit"
    done
    for nw_f in wiki/log.md.tmpl ontology/glossary.md.tmpl wiki/+index.md; do
      [ ! -e "$nw/$nw_f" ] || miss "new repo ($nw_preset): $nw_f is still given"
    done
  fi
  nw_clone="$TMP/newrepo-$nw_preset-clone"; git clone -q "$nw" "$nw_clone" 2>/dev/null
  ( cd "$nw_clone" && make derived PYTHON=python3 >/dev/null 2>&1 ) || miss "new repo ($nw_preset): make derived is red on a clean clone"
  ( cd "$nw_clone" && python3 tools/ledgers.py check >/dev/null 2>&1 ) || miss "new repo ($nw_preset): ledgers.py check is red on a clean clone"
  ( cd "$nw_clone" && make derived-untracked PYTHON=python3 >/dev/null 2>&1 ) || miss "new repo ($nw_preset): make derived-untracked is red on a clean clone"
  [ -z "$nw_gen" ] || [ -f "$nw_clone/$nw_gen" ] || miss "new repo ($nw_preset): a clean clone does not draw $nw_gen"
  if [ "$nw_preset" != claude-plugin ]; then
    for nw_f in wiki/log.md wiki/index.md ontology/glossary.md; do
      [ -f "$nw_clone/$nw_f" ] || miss "new repo ($nw_preset): a clean clone does not draw $nw_f"
    done
    ( cd "$nw_clone" && python3 tools/wiki_lint.py >/dev/null 2>&1 ) || miss "new repo ($nw_preset): wiki_lint is red on a clean clone ($(cd "$nw_clone" && python3 tools/wiki_lint.py 2>&1 | head -5))"
    grep -qF 'Newest first.' "$nw_clone/wiki/log.md" || miss "new repo ($nw_preset): the drawn log has no head"
    if grep -qF 'Repository created' "$nw_clone/wiki/log.md"; then miss "new repo ($nw_preset): the drawn log has a first line nobody wrote"; fi
    grep -qF -- '(decisions/0001-record-decisions-in-the-wiki.md)' "$nw_clone/wiki/index.md" || miss "new repo ($nw_preset): the drawn index lacks the first decision"
    grep -qxF '| Term (code name) | Definition | Not to be confused with | Display name |' "$nw_clone/ontology/glossary.md" || miss "new repo ($nw_preset): the drawn glossary has no header row"
    grep -qF '# Glossary — P' "$nw_clone/ontology/glossary.md" || miss "new repo ($nw_preset): the drawn glossary lost the project name"
  fi
done
# 48za (plan 48s). no writer is told to edit a drawn file: the guide, the skills and the agent workflow call
#      make log and add-term, and keep one sentence for a repository that has not split yet
nw_guide="$TMP/newrepo-ts-node/AGENTS.md"; wr="$ROOT/plugins/repo-setup"
for nw_f in "$nw_guide" "$wr/presets/_core/starter/dot.claude/skills/wiki-ingest/SKILL.md" "$wr/presets/_core/starter/dot.claude/skills/wiki-health/SKILL.md" \
  "$wr/presets/_core/starter/dot.claude/skills/ontology-add/SKILL.md" "$wr/skills/adopt/SKILL.md" "$wr/skills/github/SKILL.md" \
  "$wr/capabilities/github-agents/team/dot.github/workflows/agent-ci-fix.yml"; do
  grep -qF 'make log' "$nw_f" || miss "writers: ${nw_f#$ROOT/} does not tell to run make log"
  if grep -nE 'wiki/log\.md' "$nw_f" | grep -iE 'append|add (one|a) line|one line at the top|table row|at the top of the list' >/dev/null; then
    miss "writers: ${nw_f#$ROOT/} still tells to edit wiki/log.md by hand"
  fi
done
grep -qF 'ledgers.py add-term' "$wr/presets/_core/starter/dot.claude/skills/ontology-add/SKILL.md" || miss "writers: ontology-add does not call add-term"
if grep -qF 'one table row' "$wr/presets/_core/starter/dot.claude/skills/ontology-add/SKILL.md"; then miss "writers: ontology-add still writes a table row of the glossary by hand"; fi
grep -qF 'are drawn by `make derived`; edit the fragments, not the drawn files' "$nw_guide" || miss "writers: AGENTS.md does not say that the three ledgers are drawn"
for nw_f in "$nw_guide" "$wr/presets/_core/starter/dot.claude/skills/wiki-ingest/SKILL.md" "$wr/presets/_core/starter/dot.claude/skills/ontology-add/SKILL.md"; do
  grep -qF 'still in git' "$nw_f" || miss "writers: ${nw_f#$ROOT/} has no sentence for a repository whose wiki/index.md is still in git"
done
grep -qF 'needs only `type` and `title`' "$nw_guide" || miss "writers: AGENTS.md does not say that a new page needs only type and title"
grep -q 'wiki/log/' "$wr/presets/_core/starter/dot.claude/skills/wiki-ingest/SKILL.md" || miss "writers: wiki-ingest does not read the date of the last ingest from wiki/log/"
grep -qF 'glossary/' "$wr/checklists/top-tier.toml" || miss "writers: the ontology check of top-tier.toml does not accept ontology/glossary/"
# 48zb (plan 48t). settings.json opens every session by drawing; the hook always exits 0 and prints what went wrong
hk="$TMP/newrepo-ts-node"; hk_cmd="$TMP/hook.cmd"
python3 - "$hk/.claude/settings.json" "$hk_cmd" <<'PY' || miss "hook: .claude/settings.json has no SessionStart hook that runs make -s derived"
import json, sys
groups = json.load(open(sys.argv[1], encoding="utf-8"))["hooks"]["SessionStart"]
cmds = [h["command"] for g in groups for h in g["hooks"] if h["type"] == "command"]
assert len(cmds) == 1 and "make -s derived" in cmds[0], cmds
assert cmds[0].rstrip().endswith("exit 0"), cmds[0]
open(sys.argv[2], "w", encoding="utf-8").write(cmds[0])
PY
hk_work="$TMP/hook-work"; git clone -q "$hk" "$hk_work" 2>/dev/null
rc=0; ( cd "$hk_work" && /bin/sh -c "$(cat "$hk_cmd")" >/dev/null 2>&1 ) || rc=$?
[ "$rc" = 0 ] || miss "hook: the SessionStart command exits $rc on a clean clone"
[ -f "$hk_work/wiki/log.md" ] || miss "hook: the SessionStart command did not draw wiki/log.md"
printf 'DERIVED_TARGETS += zz\n.PHONY: zz\nzz: ; @echo zz-broke >&2; false\n' > "$hk_work/mk/zz.mk"
rc=0; out=$( cd "$hk_work" && /bin/sh -c "$(cat "$hk_cmd")" 2>&1 ) || rc=$?
[ "$rc" = 0 ] || miss "hook: the SessionStart command exits $rc when make derived fails"
case "$out" in *zz-broke*) ;; *) miss "hook: the SessionStart command hides the error of make derived ($out)" ;; esac
rc=0; ( cd "$hk_work" && env PATH=/nonexistent /bin/sh -c "$(cat "$hk_cmd")" >/dev/null 2>&1 ) || rc=$?
[ "$rc" = 0 ] || miss "hook: the SessionStart command exits $rc when make is not installed"
hk_mk="$TMP/hook-market"; mkdir -p "$hk_mk"
python3 "$S/apply.py" --target "$hk_mk" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme --var marketplace=acme/standards >/dev/null
python3 - "$hk_mk/.claude/settings.json" <<'PY' || miss "hook: with a marketplace, settings.json is not one JSON object with the hook and the plugin keys"
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
assert "SessionStart" in s["hooks"] and "extraKnownMarketplaces" in s and "enabledPlugins" in s, list(s)
PY
# 48zc. split takes a head file out of the manifest once it rewrites it, so a later repo-setup run keeps it
mf="$TMP/manifest"; mkdir -p "$mf" && git -C "$mf" init -q -b main
python3 "$S/apply.py" --target "$mf" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
mf_git() { git -C "$mf" -c user.name=t -c user.email=t@example.com "$@"; }
onefile_ledgers "$mf" track
awk '/^Newest first\./ { print "A note the team added."; print "" } { print }' "$mf/wiki/log.md" > "$mf/wiki/log.tmp" && mv "$mf/wiki/log.tmp" "$mf/wiki/log.md"   # a head that differs from the template
printf -- '- 2026-01-02 — typed by hand\n' >> "$mf/wiki/log.md"
mf_git add -f -A && mf_git commit -q -m "chore: base"
( cd "$mf" && python3 - <<'PY'
import json, pathlib
d = json.loads(pathlib.Path(".repo-setup.json").read_text())
assert "wiki/log.head.md" in d["files"], "the template gives wiki/log.head.md"
PY
) || miss "split manifest: .repo-setup.json does not record wiki/log.head.md"
( cd "$mf" && python3 tools/ledgers.py split log >/dev/null 2>&1 ) || miss "split manifest: split log failed on a head file as the template wrote it ($(cd "$mf" && python3 tools/ledgers.py split log 2>&1 | head -3))"
mf_git add -A && mf_git commit -q -m "docs: split"
( cd "$mf" && python3 - <<'PY'
import json, pathlib
d = json.loads(pathlib.Path(".repo-setup.json").read_text())
assert "wiki/log.head.md" not in d["files"] and "wiki/log.head.md" not in d.get("file_versions", {}), list(d["files"])
assert "wiki/index.head.md" in d["files"] and d["tool"] == "repo-setup"
PY
) || miss "split manifest: split log left wiki/log.head.md in .repo-setup.json, or lost another key"
cp "$mf/wiki/log.head.md" "$TMP/mf.head"
mf_out=$(python3 "$S/apply.py" --target "$mf" --json)
printf '%s' "$mf_out" | json '"wiki/log.head.md" in d["kept"] and not [k for k in ("created","updated","merged","edited","marked","conflict") if "wiki/log.head.md" in d[k]]' | grep True >/dev/null || miss "split manifest: apply.py does not report the split wiki/log.head.md as kept ($(printf '%s' "$mf_out" | json 'd["kept"]'))"
cmp -s "$TMP/mf.head" "$mf/wiki/log.head.md" || miss "split manifest: apply.py changed a split wiki/log.head.md"
mf_text=$(python3 "$S/apply.py" --target "$mf" 2>&1)
case "$mf_text" in *"by hand"*) miss "split manifest: apply.py asks for a merge by hand of a split head file ($mf_text)" ;; esac
printf '%s' "$mf_out" | json 'd["notes"]' | grep 'head' >/dev/null && miss "split manifest: apply.py notes something about a split head file"
# a dry run leaves the manifest as it was
mf2="$TMP/manifest2"; mkdir -p "$mf2" && git -C "$mf2" init -q -b main
python3 "$S/apply.py" --target "$mf2" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
onefile_ledgers "$mf2" track; git -C "$mf2" add -f -A; git -C "$mf2" -c user.name=t -c user.email=t@example.com commit -q -m "chore: base"
cp "$mf2/.repo-setup.json" "$TMP/mf2.manifest"
( cd "$mf2" && python3 tools/ledgers.py split log --dry-run >/dev/null 2>&1 )
cmp -s "$TMP/mf2.manifest" "$mf2/.repo-setup.json" || miss "split manifest: split --dry-run changed .repo-setup.json"
# 48zd. a repository from an earlier release keeps its tracked one-file ledgers when it upgrades
od="$TMP/oldrepo"; mkdir -p "$od" && git -C "$od" init -q -b main
python3 "$S/apply.py" --target "$od" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
onefile_ledgers "$od" track
python3 - "$od" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1]); m = root / ".repo-setup.json"; d = json.loads(m.read_text())
for rel in ("wiki/log.md", "wiki/index.md", "ontology/glossary.md"):   # what the earlier release recorded
    d["files"][rel] = hashlib.sha256((root / rel).read_bytes()).hexdigest()
    d["file_versions"][rel] = d["version"]
m.write_text(json.dumps(d, indent=2) + "\n")
PY
git -C "$od" add -f -A; git -C "$od" -c user.name=t -c user.email=t@example.com commit -q -m "chore: base"
cp "$od/wiki/log.md" "$TMP/od.log"; cp "$od/wiki/index.md" "$TMP/od.index"; cp "$od/ontology/glossary.md" "$TMP/od.gl"
od_out=$(python3 "$S/apply.py" --target "$od" --json)
printf '%s' "$od_out" | json 'sorted(set(d["dropped"]) & {"wiki/log.md","wiki/index.md","ontology/glossary.md"})' | grep -F "['ontology/glossary.md', 'wiki/index.md', 'wiki/log.md']" >/dev/null || miss "old repo: apply.py does not report the three one-file ledgers as dropped ($(printf '%s' "$od_out" | json 'd["dropped"]'))"
cmp -s "$TMP/od.log" "$od/wiki/log.md" && cmp -s "$TMP/od.index" "$od/wiki/index.md" && cmp -s "$TMP/od.gl" "$od/ontology/glossary.md" || miss "old repo: an upgrade changed a hand-kept ledger"
for od_l in log index glossary; do
  [ "$(cd "$od" && python3 tools/ledgers.py shape $od_l)" = one-file ] || miss "old repo: shape $od_l is not one-file after the upgrade (the new .gitignore lines must not matter to a tracked file)"
done
grep -qxF 'wiki/log.md' "$od/.gitignore" || miss "old repo: the upgrade did not bring the new .gitignore lines"
( cd "$od" && python3 tools/ledgers.py check >/dev/null 2>&1 && make derived-untracked PYTHON=python3 >/dev/null 2>&1 && make derived PYTHON=python3 >/dev/null 2>&1 ) || miss "old repo: check, derived-untracked or derived is red after the upgrade"
cmp -s "$TMP/od.log" "$od/wiki/log.md" || miss "old repo: make derived changed a tracked hand-kept wiki/log.md"
( cd "$od" && make log m="still works" >/dev/null 2>&1 ) && grep -qF -- '— still works' "$od/wiki/log.md" || miss "old repo: make log does not add the line to the hand-kept wiki/log.md"
# 48ze. an untracked hand-kept wiki/log.md beside entries: the refusal does not say git rm --cached (the file is not in git)
nw_clone="$TMP/newrepo-ts-node-clone"; ( cd "$nw_clone" && rm -f wiki/log.md && printf '# Log\n' > wiki/log.md && python3 tools/ledgers.py add-log "one" >/dev/null )
rc=0; out=$( cd "$nw_clone" && python3 tools/ledgers.py draw 2>&1 ) || rc=$?
[ "$rc" = 1 ] || miss "two sources: draw exits $rc, not 1, for an untracked wiki/log.md beside entries"
case "$out" in *"two sources"*"move wiki/log.md aside"*'make log m='*) ;; *) miss "two sources: the refusal does not say to move wiki/log.md aside and use make log ($out)" ;; esac
case "$out" in *"git rm --cached"*) miss "two sources: the refusal says git rm --cached for a file that is not in git ($out)" ;; esac
# 48zf. a .gitignore with a team line at its end is upgraded from the previous template without a conflict
gi="$TMP/gi-arch"; mkdir -p "$gi"
for v in 0.0.1; do
  cp -R "$ROOT/plugins/repo-setup" "$gi/repo-setup-v$v"; find "$gi/repo-setup-v$v" -name __pycache__ -prune -exec rm -rf {} +
  subst "s/\"version\": \"[^\"]*\"/\"version\": \"$v\"/" "$gi/repo-setup-v$v/.claude-plugin/plugin.json"
  for f in _core/starter/dot.gitignore ts-node/starter/dot.gitignore python/starter/dot.gitignore.tmpl; do   # the template before the drawn-file block
    python3 - "$gi/repo-setup-v$v/presets/$f" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text()
p.write_text(re.sub(r"# Drawn by `make derived` from their fragments; never committed\n(?:[^\n]+\n)+\n", "", t))
PY
  done
done
for gi_p in ts-node python; do
  gr="$TMP/gi-$gi_p"; mkdir -p "$gr" && git -C "$gr" init -q -b main
  python3 "$gi/repo-setup-v0.0.1/scripts/apply.py" --target "$gr" --preset "$gi_p" --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
  grep -q 'Drawn by' "$gr/.gitignore" && miss "gitignore upgrade ($gi_p): the stand-in old release already has the block"
  printf 'my-team-file.txt\n' >> "$gr/.gitignore"
  gi_out=$(python3 "$S/apply.py" --target "$gr" --base-from "$gi" --json) && gi_rc=0 || gi_rc=$?
  [ "$gi_rc" = 0 ] || miss "gitignore upgrade ($gi_p): apply.py exits $gi_rc for a .gitignore with a team line at its end"
  printf '%s' "$gi_out" | json '".gitignore" not in d["marked"] and ".gitignore" not in d["conflict"] and (".gitignore" in d["merged"] or ".gitignore" in d["updated"])' | grep True >/dev/null || miss "gitignore upgrade ($gi_p): .gitignore is not merged cleanly ($(printf '%s' "$gi_out" | json '[k for k in ("marked","conflict","merged","updated","edited") if ".gitignore" in d[k]]'))"
  grep -q '<<<<<<<' "$gr/.gitignore" && miss "gitignore upgrade ($gi_p): conflict markers in .gitignore"
  grep -qxF 'my-team-file.txt' "$gr/.gitignore" && grep -qxF 'wiki/log.md' "$gr/.gitignore" || miss "gitignore upgrade ($gi_p): the upgraded .gitignore lost the team line or lacks the new block"
done
# 48zg. the hook and make derived never go through `uv run`: the ledger tools use the standard library only
gp="$TMP/newrepo-python"
out=$(cd "$gp" && make -n derived 2>&1 || true)
case "$out" in *"uv run"*) miss "python: make -n derived goes through uv run ($out)" ;; esac
case "$out" in *"python3 tools/ledgers.py draw"*) ;; *) miss "python: make -n derived does not draw with python3 ($out)" ;; esac
out=$(cd "$gp" && make -n gen 2>&1 || true)
case "$out" in *"uv run"*) miss "python: make -n gen goes through uv run ($out)" ;; esac
# 48zh (plan 48u). an upgrade creates no fragment and stays green; doctor names the ledgers not split yet
#      and the score does not move for it (the fresh fragments repo of the same preset is the yardstick)
ou="$TMP/oldshape"; mkdir -p "$ou" && git -C "$ou" init -q -b main
python3 "$S/apply.py" --target "$ou" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
onefile_ledgers "$ou" track
( cd "$ou" && mkdir -p src/generated && python3 tools/ontology_codegen.py --lang ts --out src/generated/ontology.ts >/dev/null 2>&1 ) || miss "one-file upgrade: cannot generate the hand-kept src/generated/ontology.ts"
python3 - "$ou" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1]); m = root / ".repo-setup.json"; d = json.loads(m.read_text())
for rel in ("wiki/log.md", "wiki/index.md", "ontology/glossary.md", "src/generated/ontology.ts"):
    d["files"][rel] = hashlib.sha256((root / rel).read_bytes()).hexdigest()
    d["file_versions"][rel] = d["version"]
m.write_text(json.dumps(d, indent=2) + "\n")
PY
git -C "$ou" add -f -A; git -C "$ou" -c user.name=t -c user.email=t@example.com commit -q -m "chore: base"
python3 "$S/apply.py" --target "$ou" >/dev/null 2>&1 || miss "one-file upgrade: apply.py is not green on a repository that keeps its ledgers as files"
for ou_d in wiki/log ontology/glossary; do
  [ -z "$(ls -A "$ou/$ou_d" 2>/dev/null | grep -v '^\.gitkeep$')" ] || miss "one-file upgrade: a fragment was created in $ou_d"
done
for ou_l in log index glossary; do
  [ "$(cd "$ou" && python3 tools/ledgers.py shape $ou_l)" = one-file ] || miss "one-file upgrade: shape $ou_l is not one-file"
done
[ "$(cd "$ou" && python3 tools/ledgers.py shape gen --gen-out src/generated/ontology.ts)" = one-file ] || miss "one-file upgrade: shape gen is not one-file"
( cd "$ou" && python3 tools/ledgers.py check >/dev/null 2>&1 && make derived PYTHON=python3 >/dev/null 2>&1 && make derived-untracked PYTHON=python3 >/dev/null 2>&1 && python3 tools/wiki_lint.py >/dev/null 2>&1 ) || miss "one-file upgrade: check, derived, derived-untracked or wiki_lint is red"
( cd "$ou" && make log m=x PYTHON=python3 >/dev/null 2>&1 ) && grep -qF -- '— x' "$ou/wiki/log.md" || miss "one-file upgrade: make log m=x does not write into wiki/log.md"
ou_json=$(python3 "$S/doctor.py" --target "$ou" --level starter --json)
printf '%s' "$ou_json" | json '[n["ledger"] for n in d["ledgers_split"]]' | grep -F "['log', 'index', 'glossary', 'gen']" >/dev/null || miss "doctor: ledgers_split does not list the four ledgers ($(printf '%s' "$ou_json" | json 'd.get("ledgers_split")'))"
printf '%s' "$ou_json" | json '[n["command"] for n in d["ledgers_split"]]' | grep -F "make split L=glossary" >/dev/null || miss "doctor: ledgers_split does not carry the split command"
python3 "$S/doctor.py" --target "$ou" --level starter | grep -F 'Ledgers still kept as one file (not scored):' >/dev/null || miss "doctor text: no ledgers notice for a one-file repository"
fr="$TMP/oldshape-fresh"; mkdir -p "$fr" && git -C "$fr" init -q -b main
python3 "$S/apply.py" --target "$fr" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
git -C "$fr" add -A; git -C "$fr" -c user.name=t -c user.email=t@example.com commit -q -m "chore: base"
fr_json=$(python3 "$S/doctor.py" --target "$fr" --level starter --json)
[ "$(printf '%s' "$fr_json" | json 'd["ledgers_split"]')" = "[]" ] || miss "doctor: a fragments repository gets a ledgers notice ($(printf '%s' "$fr_json" | json 'd["ledgers_split"]'))"
[ "$(printf '%s' "$ou_json" | json 'd["score"]')" = "$(printf '%s' "$fr_json" | json 'd["score"]')" ] || miss "doctor: the ledgers notice changes the score ($(printf '%s' "$ou_json" | json 'd["score"]') against $(printf '%s' "$fr_json" | json 'd["score"]'))"
[ "$(printf '%s' "$ou_json" | json 'sorted(r["id"] for r in d["failed"])')" = "$(printf '%s' "$fr_json" | json 'sorted(r["id"] for r in d["failed"])')" ] || miss "doctor: the ledgers notice adds a failed check"
# an install from before tools/ledgers.py: no notice, no error
ol="$TMP/oldshape-noledgers"; cp -R "$ou" "$ol"; rm -f "$ol/tools/ledgers.py"
[ "$(python3 "$S/doctor.py" --target "$ol" --level starter --json | json 'd["ledgers_split"]')" = "[]" ] || miss "doctor: a repository without tools/ledgers.py gets a notice or an error"
# 48zi. the tools a python repository receives pass its own ruff config (check and format), as every vendored tool did
#      before the ledger tools. Skipped without ruff on the PATH or in uv's cache (it never goes to the network).
if command -v ruff >/dev/null 2>&1; then ruff_cmd="ruff"; elif command -v uvx >/dev/null 2>&1 && uvx --offline ruff --version >/dev/null 2>&1; then ruff_cmd="uvx --offline ruff"; else ruff_cmd=""; fi
if [ -n "$ruff_cmd" ]; then
  # starter and team: the team level brings tools of its own (sdlc_*.py, autonomy.py, github_setup.py)
  for ruff_repo in "$TMP/newrepo-python" "$TMP/python-team"; do
    ( cd "$ruff_repo" && $ruff_cmd check . >/dev/null 2>&1 ) || miss "python repo ${ruff_repo##*/}: ruff check is red on the vendored tools ($(cd "$ruff_repo" && $ruff_cmd check . --output-format concise 2>&1 | head -3))"
    ( cd "$ruff_repo" && $ruff_cmd format --check . >/dev/null 2>&1 ) || miss "python repo ${ruff_repo##*/}: ruff format --check is red on the vendored tools"
  done
fi
# 48zj. a hand edit of a drawn file: once every line it added is in a source, make derived draws again; a line in
#       no source is refused with the lines and the way back; an edit that only removes lines is drawn over
he="$TMP/handedit"; mkdir -p "$he" && git -C "$he" init -q -b main
python3 "$S/apply.py" --target "$he" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
git -C "$he" add -A && git -C "$he" -c user.name=t -c user.email=t@example.com commit -q -m "chore: base"
he_make() { ( cd "$he" && make -s PYTHON=python3 "$@" 2>&1 ); }
he_tool() { ( cd "$he" && python3 tools/ledgers.py "$@" ); }
he_gen=src/generated/ontology.ts
he_make derived >/dev/null || miss "hand edit: make derived is red on a new repository ($(he_make derived))"
he_day=$(date +%Y-%m-%d)
printf -- '- %s — typed by hand\n' "$he_day" >> "$he/wiki/log.md"; cp "$he/wiki/log.md" "$TMP/he.log"
rc=0; out=$(he_make derived) || rc=$?
[ "$rc" != 0 ] || miss "hand edit: make derived is green with a line typed into the drawn wiki/log.md"
case "$out" in *"+ - $he_day — typed by hand"*'make log m='*"delete wiki/log.md"*"make derived"*) ;; *) miss "hand edit: the refusal does not list the line and end with the way back ($out)" ;; esac
case "$out" in *"is lost"*) miss "hand edit: the refusal says the hand edit is lost, though nothing was written ($out)" ;; esac
cmp -s "$TMP/he.log" "$he/wiki/log.md" || miss "hand edit: make derived changed a wiki/log.md with a line in no entry"
( cd "$he" && make -s log m="typed by hand" >/dev/null 2>&1 ) || miss "hand edit: make log failed"
rc=0; out=$(he_make derived) || rc=$?
[ "$rc" = 0 ] || miss "hand edit: make derived stays red once the typed line is an entry ($out)"
[ "$(grep -cxF -- "- $he_day — typed by hand" "$he/wiki/log.md")" = 1 ] || miss "hand edit: the moved line is not in the drawn log exactly once"
( cd "$he" && python3 -c "
import pathlib, sys; sys.path.insert(0, 'tools'); import ledgers
body, edited = ledgers.read_stamped(pathlib.Path('wiki/log.md')); assert body is not None and not edited" ) || miss "hand edit: the redrawn wiki/log.md does not carry a stamp that matches"
grep -vF 'Newest first.' "$he/wiki/log.md" > "$TMP/he.cut"; cp "$TMP/he.cut" "$he/wiki/log.md"
rc=0; out=$(he_make derived) || rc=$?
[ "$rc" = 0 ] && grep -qF 'Newest first.' "$he/wiki/log.md" || miss "hand edit: an edit that only removed a line of wiki/log.md is not drawn over ($out)"
printf '| `Basket` | Goods not yet bought. |  | Basket |\n' >> "$he/ontology/glossary.md"
if he_make derived >/dev/null; then miss "hand edit: make derived is green with a row typed into the drawn glossary"; fi
he_tool add-term Basket --definition "Goods not yet bought." >/dev/null || miss "hand edit: add-term failed"
he_make derived >/dev/null || miss "hand edit: make derived stays red once the typed row is a fragment ($(he_make derived))"
[ "$(grep -c '^| `Basket` |' "$he/ontology/glossary.md")" = 1 ] || miss "hand edit: the row is not in the drawn glossary exactly once"
cp "$he/$he_gen" "$TMP/he.gen"; sed '$d' "$TMP/he.gen" > "$he/$he_gen"
he_make derived >/dev/null && cmp -s "$TMP/he.gen" "$he/$he_gen" || miss "hand edit: an edit that only removed a line of $he_gen is not drawn over"
printf '// by hand\n' >> "$he/$he_gen"
rc=0; out=$(he_make derived) || rc=$?
[ "$rc" != 0 ] && case "$out" in *"+ // by hand"*"delete $he_gen"*"make derived"*) true ;; *) false ;; esac || miss "hand edit: a line typed into $he_gen is not refused with the line and the way back ($out)"
rm -f "$he/$he_gen"; he_make derived >/dev/null || miss "hand edit: make derived is red after the way back for $he_gen"
# 48zk. a file at a drawn path with no stamp that git does not know, in the fragments shape: what the generator
#       wrote is drawn over, stamped, so it follows ontology/; an index is refused and named, never left stale
( cd "$he" && python3 tools/ontology_codegen.py --lang ts --out $he_gen >/dev/null )
python3 "$ROOT/tests/apply_fixture.py" coffee "$he" >/dev/null
rc=0; out=$(he_make derived) || rc=$?
[ "$rc" = 0 ] || miss "unstamped: make derived is red for an unstamped $he_gen the generator wrote ($out)"
head -1 "$he/$he_gen" | grep ' sha256:[0-9a-f]\{64\}$' >/dev/null || miss "unstamped: an unstamped $he_gen the generator wrote is not drawn over, stamped"
grep -q 'isVIPCustomer' "$he/$he_gen" || miss "unstamped: the drawn $he_gen does not follow ontology/"
tail -n +2 "$he/wiki/index.md" > "$TMP/he.ix"; cp "$TMP/he.ix" "$he/wiki/index.md"
printf -- '---\ntype: entity\ntitle: Basket\n---\n# Basket\n' > "$he/wiki/entities/basket.md"
rc=0; out=$(he_make derived) || rc=$?
[ "$rc" != 0 ] || miss "unstamped: make derived is green with an unstamped wiki/index.md that git does not know"
case "$out" in *wiki/index.md*"delete wiki/index.md"*"make derived"*) ;; *) miss "unstamped: the refusal does not name wiki/index.md and say to delete it and run make derived ($out)" ;; esac
cmp -s "$TMP/he.ix" "$he/wiki/index.md" || miss "unstamped: make derived changed an unstamped wiki/index.md"
rm -f "$he/wiki/index.md"; he_make derived >/dev/null || miss "unstamped: make derived is red after wiki/index.md is deleted"
grep -qF -- '- [Basket](entities/basket.md)' "$he/wiki/index.md" || miss "unstamped: a new page is not in the index drawn after the delete"
# 48zl. an open pull request that added a log line, after split on main: the way the reminder gives keeps the
#       line once and loses nothing; keeping the hand-kept file is two sources, and check lists what to move
cf="$TMP/conflict"; mkdir -p "$cf" && git -C "$cf" init -q -b main
python3 "$S/apply.py" --target "$cf" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
onefile_ledgers "$cf" track
cf_git() { git -C "$cf" -c user.name=t -c user.email=t@example.com "$@"; }
cf_tool() { ( cd "$cf" && python3 tools/ledgers.py "$@" ); }
cf_git add -A && cf_git commit -q -m "chore: base"
cf_git checkout -q -b pr
( cd "$cf" && make -s log m="from the pr" >/dev/null 2>&1 ) || miss "conflict: make log failed on the open branch"
cf_git commit -q -am "docs: a line on the open branch"
cf_git checkout -q main
rc=0; out=$(cf_tool split log 2>&1) || rc=$?
[ "$rc" = 0 ] || miss "conflict: split log exits $rc ($out)"
case "$out" in *"git rm wiki/log.md"*'make log m='*) ;; *) miss "conflict: the reminder does not say git rm wiki/log.md first, then make log ($out)" ;; esac
cf_git add -A && cf_git commit -q -m "docs: split the log"
cf_git checkout -q pr
if cf_git merge -q --no-edit main >/dev/null 2>&1; then miss "conflict: merging main into the open branch did not conflict on wiki/log.md"; fi
cp "$cf/wiki/log.md" "$TMP/cf.pr"
cf_git add wiki/log.md   # keep the hand-kept file: two sources
rc=0; out=$(cf_tool check 2>&1) || rc=$?
[ "$rc" = 1 ] && case "$out" in *"two sources"*"from the pr"*"git rm wiki/log.md"*'make log m='*) true ;; *) false ;; esac || miss "conflict: check exits $rc, or does not list the line in no entry and the way to move it ($out)"
case "$out" in *"Repository created with repo-setup"*) miss "conflict: check lists a line that is already an entry ($out)" ;; esac
grep -vF 'from the pr' "$TMP/cf.pr" > "$cf/wiki/log.md"
rc=0; out=$(cf_tool check 2>&1) || rc=$?
case "$out" in *"safe to delete"*) ;; *) miss "conflict: check does not say a hand-kept file whose lines are all entries is safe to delete ($out)" ;; esac
cp "$TMP/cf.pr" "$cf/wiki/log.md"
cf_git rm -q -f wiki/log.md
( cd "$cf" && make -s log m="from the pr" >/dev/null 2>&1 ) || miss "conflict: make log failed after git rm"
cf_git add -A && cf_git commit -q --no-edit
( cd "$cf" && make -s PYTHON=python3 derived >/dev/null 2>&1 && python3 tools/ledgers.py check >/dev/null 2>&1 ) || miss "conflict: derived or check is red after the reminder's way ($(cd "$cf" && make -s PYTHON=python3 derived 2>&1; python3 tools/ledgers.py check 2>&1))"
[ "$(grep -cF -- '— from the pr' "$cf/wiki/log.md")" = 1 ] || miss "conflict: the line of the open branch is not in the drawn log exactly once"
grep -qF -- '— Repository created with repo-setup (test).' "$cf/wiki/log.md" || miss "conflict: a line of main was lost"
[ -z "$(cf_git ls-files -- wiki/log.md)" ] || miss "conflict: wiki/log.md is in git after the reminder's way"
cf_git checkout -q main
out=$(cf_tool split glossary 2>&1) || true
case "$out" in *"git rm ontology/glossary.md"*"add-term"*) ;; *) miss "conflict: the glossary reminder does not say git rm ontology/glossary.md first, then add-term ($out)" ;; esac
# 48zm. a fragment is in the form the format checks keep: no trailing whitespace, a blank line after the front
#       matter, one newline at the end; the Node presets keep the two fragment folders out of Prettier
fm="$TMP/fragform"; mkdir -p "$fm" && git -C "$fm" init -q -b main
python3 "$S/apply.py" --target "$fm" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
( cd "$fm" && python3 tools/ledgers.py add-term Order --definition "A confirmed purchase." >/dev/null && python3 tools/ledgers.py add-log "a *starred* __word__" >/dev/null ) || miss "fragment form: add-term or add-log failed"
printf -- '---\nterm: Order\ndisplay: Order\nnot_confused_with:\n---\n\nA confirmed purchase.\n' > "$TMP/fm.want"
cmp -s "$TMP/fm.want" "$fm/ontology/glossary/Order.md" || miss "fragment form: add-term does not write the canonical fragment ($(cat -e "$fm/ontology/glossary/Order.md"))"
fm_bad=$(python3 - "$fm/wiki/log" "$fm/ontology/glossary" "$sp/wiki/log" "$sp/ontology/glossary" <<'PY'
import pathlib, sys
for folder in sys.argv[1:]:
    for p in sorted(pathlib.Path(folder).iterdir()):
        if p.name.startswith("."):
            continue
        text = p.read_text(encoding="utf-8")
        if any(line != line.rstrip() for line in text.split("\n")) or not text.endswith("\n") or text.endswith("\n\n"):
            print(p)
PY
)
[ -z "$fm_bad" ] || miss "fragment form: a fragment written by add-term, add-log or split has trailing whitespace or a wrong end ($fm_bad)"
for fm_line in 'wiki/log/' 'ontology/glossary/'; do
  grep -qxF "$fm_line" "$fm/.prettierignore" || miss "fragment form: .prettierignore of a Node preset does not leave out $fm_line"
done
printf -- '---\nterm: Old\ndisplay: Old\nnot_confused_with: \n---\nOld form.\n' > "$fm/ontology/glossary/Old.md"
( cd "$fm" && python3 tools/ledgers.py draw >/dev/null && python3 tools/ledgers.py check >/dev/null ) || miss "fragment form: a fragment in the old form is no longer read"
grep -qxF '| `Old` | Old form. |  | Old |' "$fm/ontology/glossary.md" && grep -qxF '| `Order` | A confirmed purchase. |  | Order |' "$fm/ontology/glossary.md" || miss "fragment form: the old and the new form do not draw the same kind of row"
# 48zn. a hand-kept ledger beside fragments is safe to delete only when every line of it is in a source: a
#       malformed entry line and a line of the head part are listed too, each with where it goes
rs="$TMP/residual"; mkdir -p "$rs" && git -C "$rs" init -q -b main
python3 "$S/apply.py" --target "$rs" --preset ts-node --level starter --var project_name=P --var description=x --var owner=acme >/dev/null
onefile_ledgers "$rs" track
rs_git() { git -C "$rs" -c user.name=t -c user.email=t@example.com "$@"; }
rs_tool() { ( cd "$rs" && python3 tools/ledgers.py "$@" ); }
rs_git add -A && rs_git commit -q -m "chore: base"
cp "$rs/wiki/log.md" "$TMP/rs.log"; cp "$rs/ontology/glossary.md" "$TMP/rs.gl"
rs_tool split log >/dev/null 2>&1 && rs_tool split glossary >/dev/null 2>&1 || miss "residual: split log or glossary failed"
rs_tool add-term Order --definition "A purchase." >/dev/null || miss "residual: add-term failed"
rs_git add -A && rs_git commit -q -m "docs: split"
{ cat "$TMP/rs.log"; printf -- '- 2026-11-17 - typed with a hyphen\nSee also the release notes in docs/.\n'; } > "$rs/wiki/log.md"
rs_git add -f wiki/log.md   # a hand-kept log back in git beside the entries: two sources
rc=0; out=$(rs_tool check 2>&1) || rc=$?
[ "$rc" = 1 ] || miss "residual: check exits $rc, not 1, for a hand-kept log beside entries"
case "$out" in *"- 2026-11-17 - typed with a hyphen"*'make log m='*) ;; *) miss "residual: check does not list the malformed entry line with make log ($out)" ;; esac
case "$out" in *"See also the release notes in docs/."*"wiki/log.head.md"*) ;; *) miss "residual: check does not list the head line with wiki/log.head.md ($out)" ;; esac
case "$out" in *"safe to delete"*) miss "residual: check says the log is safe to delete while two of its lines are in no source ($out)" ;; esac
printf 'See also the release notes in docs/.\n' >> "$rs/wiki/log.head.md"
printf 'typed with a hyphen\n' > "$rs/wiki/log/2026-11-17-01-typed-with-a-hyphen.md"
{ cat "$TMP/rs.log"; printf -- '- 2026-11-17 — typed with a hyphen\nSee also the release notes in docs/.\n'; } > "$rs/wiki/log.md"
out=$(rs_tool check 2>&1 || true)
case "$out" in *"wiki/log.md"*"safe to delete"*) ;; *) miss "residual: check does not say the log is safe to delete once every line is in a source ($out)" ;; esac
rs_git rm -q -f wiki/log.md
{ cat "$TMP/rs.gl"; printf 'Terms follow the names used on the floor.\n'; } > "$rs/ontology/glossary.md"
rs_git add -f ontology/glossary.md
rc=0; out=$(rs_tool check 2>&1) || rc=$?
[ "$rc" = 1 ] && case "$out" in *"Terms follow the names used on the floor."*"ontology/glossary.head.md"*) true ;; *) false ;; esac || miss "residual: check exits $rc, or does not list the hand paragraph of the glossary with ontology/glossary.head.md ($out)"
case "$out" in *"safe to delete"*) miss "residual: check says the glossary is safe to delete while a line of it is in no source ($out)" ;; esac
printf 'Terms follow the names used on the floor.\n' >> "$rs/ontology/glossary.head.md"
out=$(rs_tool check 2>&1 || true)
case "$out" in *"ontology/glossary.md"*"safe to delete"*) ;; *) miss "residual: check does not say the glossary is safe to delete once every line is in a source ($out)" ;; esac
rs_git rm -q -f ontology/glossary.md
# untracked, unstamped: the same lines are listed, with the same places to go
{ cat "$TMP/rs.log"; printf 'An untracked note.\n'; } > "$rs/wiki/log.md"
rc=0; out=$(rs_tool draw 2>&1) || rc=$?
[ "$rc" = 1 ] && case "$out" in *"An untracked note."*"wiki/log.head.md"*) true ;; *) false ;; esac || miss "residual: draw exits $rc, or does not list a head line of an untracked wiki/log.md with wiki/log.head.md ($out)"
rm -f "$rs/wiki/log.md"
# a line typed above the entries of a drawn file goes to the head file, not to make log
rs_tool draw >/dev/null || miss "residual: draw failed"
awk 'NR == 2 { print "A note typed above the entries." } { print }' "$rs/wiki/log.md" > "$TMP/rs.edit"; cp "$TMP/rs.edit" "$rs/wiki/log.md"
rc=0; out=$(rs_tool draw 2>&1) || rc=$?
[ "$rc" = 1 ] && case "$out" in *"A note typed above the entries."*"wiki/log.head.md"*"delete wiki/log.md"*) true ;; *) false ;; esac || miss "residual: a head line typed into the drawn log is not sent to wiki/log.head.md ($out)"
case "$out" in *'make log m='*) miss "residual: a head line typed into the drawn log is sent to make log ($out)" ;; esac
printf 'A note typed above the entries.\n' >> "$rs/wiki/log.head.md"
rs_tool draw >/dev/null 2>&1 || miss "residual: draw stays red once the typed head line is in wiki/log.head.md ($(rs_tool draw 2>&1))"
# 48zo. only the template's own example row and closing comment, exactly as it wrote them, are dropped from a
#       hand-kept glossary: an edited or new example row, or a comment with more in it, is listed (check, the
#       untracked draw) or kept (split's head file) or refused (split, for an example row that is not the template's)
rs_gl_check() { # <line>: a tracked hand-kept glossary with the template's lines and <line>; check must list it
  { cat "$TMP/rs.gl"; printf '%s\n' "$1"; } > "$rs/ontology/glossary.md"; rs_git add -f ontology/glossary.md
  rc=0; out=$(rs_tool check 2>&1) || rc=$?
  [ "$rc" = 1 ] && case "$out" in *"$1"*) true ;; *) false ;; esac || miss "glossary exact: check exits $rc, or does not list: $1 ($out)"
  case "$out" in *"safe to delete"*) miss "glossary exact: check says safe to delete beside: $1" ;; esac
  rs_git rm -q -f ontology/glossary.md
}
rs_gl_check '<!-- Add your terms above. Pricing terms: ask finance first. -->'
rs_gl_check '<!-- Add your terms above. Keep definitions to one sentence. --> VIP means a customer with 10+ orders.'
rs_gl_check '| _Example:_ `Customer` | A person who has bought at least twice (finance rule, 2026). | `Visitor` (has not bought) | Customer |'
rs_gl_check '| _Example:_ `Refund` | Money returned after a return. | `Discount` | Refund |'
cp "$TMP/rs.gl" "$rs/ontology/glossary.md"; rs_git add -f ontology/glossary.md
out=$(rs_tool check 2>&1 || true)
case "$out" in *"ontology/glossary.md"*"safe to delete"*) ;; *) miss "glossary exact: the untouched template example row and comment alone are not safe to delete ($out)" ;; esac
rs_git rm -q -f ontology/glossary.md
{ cat "$TMP/rs.gl"; printf '%s\n' '<!-- Add your terms above. Pricing terms: ask finance first. -->'; } > "$rs/ontology/glossary.md"
rc=0; out=$(rs_tool draw 2>&1) || rc=$?
[ "$rc" = 1 ] && case "$out" in *"Pricing terms: ask finance first."*"ontology/glossary.head.md"*) true ;; *) false ;; esac || miss "glossary exact: the untracked draw does not list a comment with more in it ($out)"
case "$out" in *"A line goes into"*) miss "glossary exact: the untracked draw gives the add-term command when only head lines are listed ($out)" ;; esac
rm -f "$rs/ontology/glossary.md"; rs_tool draw >/dev/null 2>&1 || true
# split: the template's own lines are dropped and said; an edited example row is refused; a longer comment stays in the head
se="$TMP/split-exact"; sp_new "$se"
se_tool() { ( cd "$se" && python3 tools/ledgers.py "$@" ); }
cp "$se/ontology/glossary.md" "$TMP/se.gl"
python3 - "$se/ontology/glossary.md" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
old = "A person who has bought at least once."
assert old in t; p.write_text(t.replace(old, "A person who has bought at least twice (finance rule, 2026).", 1), encoding="utf-8")
PY
rc=0; out=$(se_tool split glossary --dry-run 2>&1) || rc=$?
[ "$rc" = 1 ] && case "$out" in *"_Example:_"*"at least twice"*) true ;; *) false ;; esac || miss "glossary exact: split does not refuse an edited example row, naming it (rc $rc, $out)"
python3 - "$se/ontology/glossary.md" "$TMP/se.gl" <<'PY'
import pathlib, sys
t = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
old = "<!-- Add your terms above. Keep definitions to one sentence. -->"
assert old in t; pathlib.Path(sys.argv[1]).write_text(t.replace(old, "<!-- Add your terms above. Pricing terms: ask finance first. -->", 1), encoding="utf-8")
PY
rc=0; out=$(se_tool split glossary 2>&1) || rc=$?
[ "$rc" = 0 ] || miss "glossary exact: split refuses a glossary with a longer closing comment ($out)"
grep -qF 'Pricing terms: ask finance first.' "$se/ontology/glossary.head.md" || miss "glossary exact: split dropped a closing comment with more in it instead of keeping it in ontology/glossary.head.md"
case "$out" in *"dropped the template's example row"*) ;; *) miss "glossary exact: split does not say it dropped the template's example row ($out)" ;; esac
# the hand-edit refusal: one header for both lists; the untracked refusal: no command when only head lines are listed
awk 'NR == 2 { print "A note typed above the entries, again." } { print } END { print "- 2026-11-18 — typed below" }' "$rs/wiki/log.md" > "$TMP/rs.edit2"; cp "$TMP/rs.edit2" "$rs/wiki/log.md"
out=$(rs_tool draw 2>&1 || true)
[ "$(printf '%s\n' "$out" | grep -c 'in no source yet')" = 1 ] || miss "hand edit: the refusal prints its header more than once ($out)"
case "$out" in *"typed below"*'make log m='*) ;; *) miss "hand edit: the refusal does not send the entry line to make log ($out)" ;; esac
case "$out" in *"again."*"wiki/log.head.md"*) ;; *) miss "hand edit: the refusal does not send the head line to wiki/log.head.md ($out)" ;; esac
rm -f "$rs/wiki/log.md"; rs_tool draw >/dev/null 2>&1 || true
echo "ok  derived (or misses reported above)"

# shellcheck source=tests/upgrade.sh
. "$ROOT/tests/upgrade.sh"

# shellcheck source=tests/tiered_ci.sh
. "$ROOT/tests/tiered_ci.sh"

# shellcheck source=tests/rule_kinds.sh
. "$ROOT/tests/rule_kinds.sh"

# shellcheck source=tests/seams.sh
. "$ROOT/tests/seams.sh"

# shellcheck source=tests/outside.sh
. "$ROOT/tests/outside.sh"

# shellcheck source=tests/autonomy_change.sh
. "$ROOT/tests/autonomy_change.sh"

# shellcheck source=tests/autonomy_card.sh
. "$ROOT/tests/autonomy_card.sh"

[ "$misses" -eq 0 ] || fail "$misses regression check(s) failed"
echo "All tests passed."
reached_end=1

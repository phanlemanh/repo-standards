#!/usr/bin/env bash
# Fast offline tests for the repo-setup scripts (no dependency installs).
# Full end-to-end verification (real installs + make check + pre-commit): tests/e2e.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/plugins/repo-setup/scripts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }
# Portable in-place edit: `sed -i` differs between GNU and BSD (macOS).
subst() { sed "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"; }
# Regression checks report every miss before the run fails.
misses=0
miss() { echo "FAIL: $*" >&2; misses=$((misses + 1)); }

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

    # 5. user edits are never overwritten
    echo "my note" >> "$d/README.md"
    conflict=$(python3 "$S/apply.py" --target "$d" --json | json '"README.md" in d["conflict"]')
    [ "$conflict" = "True" ] || fail "$preset/$level: edited README not reported as conflict"
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
check "'AGENTS.md' in d['created'] and 'ontology/glossary.md' in d['created']" "'AGENTS.md' in d['created'] and 'ontology/glossary.md' in d['created']"
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

# 14. module boundaries catch violations
b="$TMP/combo-python-modular-monolith-none-x"
printf 'from coffee_bad import x\nfrom ..loyalty import points_for\n' >> "$b/src/combo/modules/sales/pricing.py"
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
python3 "$S/doctor.py" --target "$h" | grep -q 'GitHub protection was not checked' || miss "doctor text does not warn about local-only score"
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
python3 "$S/doctor.py" --target "$g2" --json | json '[r["id"] for r in d["failed"]]' | grep -q ai_agent_bounded && miss "doctor rejects an intact agent"
subst 's/MAX_ITERATIONS/MAX_TURNS/g' "$g2/src/t/agent.py" 2>/dev/null || true; git -C "$g2" add -A
python3 "$S/doctor.py" --target "$g2" --json | json '[r["id"] for r in d["failed"]]' | grep -q ai_agent_bounded || miss "doctor missed an agent without a turn limit"
python3 "$S/doctor.py" --target "$TMP/ai-tier-call" --json | json '[r["id"] for r in d["failed"]+d["passed"] if isinstance(r,dict)]+d["passed"]' | grep -q ai_agent_bounded && miss "call tier is checked for an agent limit"
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
  python3 "$S/doctor.py" --target "$x" --json | json 'd["manual_steps"]' | grep -q 'Add a database' || miss "blueprint: manual steps not listed"
  before=$(python3 "$S/doctor.py" --target "$x" --json | json 'd["score"]')
  python3 - "$x/.repo-setup.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["level"]="team"; json.dump(d,open(p,"w"))
PY
  python3 "$S/doctor.py" --target "$x" --json | json 'len(d["blueprint_drift"])' | grep -qv '^0$' || miss "blueprint: drift not reported"
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
sed -n 's/^description: //p' "$SK/SKILL.md" | grep -q 'context, repo strategy, architecture, AI in the product, stack, domain, design, quality, delivery, agents' \
  || miss "new: description does not list the layers in layers.toml order"
grep -q 'design/terms.json' "$SK/SKILL.md" && grep -q 'docs_language' "$SK/SKILL.md" || miss "SKILL.md build step lacks design/terms.json and docs_language"
awk '/^## 6\./{f=1;next} /^## 7\./{f=0} f' "$SK/SKILL.md" | grep -q 'design/terms.json' || miss "SKILL.md step 6 lacks design/terms.json"
grep -q 'src/example' "$SK/references/tour.md" || miss "tour.md lacks src/example"
grep -q 'ten layers' "$ROOT/plugins/repo-setup/README.md" || miss "plugin README lacks: ten layers"
grep '`react-vite`' "$SK/references/layers/stack.md" | grep -q 'design' || miss "stack.md react-vite row lacks design"
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
grep -E 'needs_review' "$SK/SKILL.md" | grep -q 'not_applicable' || miss "needs_review ignores not_applicable layers"
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
grep -q 'Display name' "$la/ontology/glossary.md" || miss "glossary lacks a display name column"
git -C "$la" init -q -b main; git -C "$la" add -A
python3 "$S/doctor.py" --target "$la" --json | json '",".join(r["id"] for r in d["failed"])' | grep -q language_policy && miss "doctor rejects the language section"
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
echo "$out" | json '"\n".join(d["notes"])' | grep -q github-agents || miss "re-apply: no notice about kept agents"
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
grep -E 'coverage threshold' "$SK/references/layers/quality.md" | grep -q '`partial`' || miss "quality: mixed option must be partial"
grep -E '^\| Monorepo' "$SK/references/layers/repo.md" | grep -q '`partial`' || miss "repo: monorepo must be partial"
grep -E 'Custom tiers' "$SK/references/layers/governance.md" | grep -q '`partial`' || miss "governance: custom tiers must be partial"
grep -q 'tests' "$SK/SKILL.md" && grep -qi 'sample tests' "$SK/SKILL.md" || miss "new forgets the sample tests when replacing the ontology"
steps "$n" False | grep -q allow_auto_merge && miss "github_setup changes auto-merge without agents"
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
if python3 "$u/tools/github_setup.py" --help | grep -q marketplace; then miss "github_setup still sets a marketplace for CI"; fi
grep -q 'acceptance-gate-kit' "$ROOT/README.md" || miss "README does not say where the feature loop lives"
echo "ok  setup only (or misses reported above)"

# 30. PR pipeline: bots can be reviewed, review runs no PR code, the gate runs no PR code
g="$TMP/gate-repo"; mkdir -p "$g" && git -C "$g" init -q -b main
python3 "$S/apply.py" --target "$g" --preset python --level team --with github-agents --var project_name=G --var description=x --var owner=a >/dev/null
pipeline="$g/.github/workflows/pr-pipeline.yml"
review=$(sed -n '/^  review:$/,/^  automerge:$/p' "$pipeline")
echo "$review" | grep -q 'allowed_bots: "claude\[bot\]"' || miss "review rejects PRs opened by claude[bot]"
if grep -q "allowed_bots: *['\"]\*" "$pipeline"; then miss "pipeline allows every bot"; fi
if echo "$review" | grep -q 'setup-project'; then miss "review installs the PR's dependencies"; fi
if echo "$review" | grep -q 'Bash(make:'; then miss "review may run make from the PR"; fi
echo "$review" | grep -q -- '--strict-mcp-config' || miss "review may start MCP servers from the PR"
echo "$review" | grep -q 'Bash(gh pr checks:' || miss "review cannot read the CI result"
echo "$review" | grep -q 'checks: read' || miss "review lacks permission to read checks"
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
  grep -q 'CHECK_TARGETS += design-guards ui-floor' "$d/mk/design.mk" || miss "design: not in the gate"
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
  if [ -n "$2" ]; then printf '%s\n' "$2" >> "$d/$1"; else subst 's/^CHECK_TARGETS += design-guards /CHECK_TARGETS += /' "$d/$1"; fi
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
  subst "s/^	@npx playwright test\$/	${prefix}npx playwright test/" "$d/mk/design.mk"
  cmp -s "$TMP/gate.bak" "$d/mk/design.mk" && miss "design gate: the $prefix mutation did not change mk/design.mk"
  out=$(cd "$d" && node tools/design_guards.mjs --only gate 2>&1) && miss "design gate: stayed green with ${prefix}npx playwright test"
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
  | grep -q 'NOT APPLICABLE to a claude-plugin repository' || miss "claude-plugin: text output hides what is not applicable"
if grep -qiE 'ontology|wiki/|make gen|typecheck' "$k/AGENTS.md" "$k/CLAUDE.md" "$k/README.md" "$k/.claude/skills/review-change/SKILL.md"; then miss "claude-plugin: guides still talk about ontology, wiki or app tooling"; fi
grep -q '^## Language' "$k/AGENTS.md" || miss "claude-plugin: AGENTS.md lacks the language rule"
for t in setup lint test check; do grep -q "^$t:" "$k/Makefile" || miss "claude-plugin: Makefile lacks $t"; done
grep -q 'make check' "$k/.github/workflows/ci.yml" && grep -q 'make validate' "$k/.github/workflows/ci.yml" || miss "claude-plugin: CI does not run the checks and the validator"
[ "$(cat "$k/.nvmrc")" = 22 ] || miss "claude-plugin: Node version not pinned"
( cd "$k" && make check >/dev/null 2>&1 ) || miss "claude-plugin: make check fails on a fresh skeleton"
python3 "$S/apply.py" --list-options | json 'd["stacks"]["claude-plugin"]["description"]' | grep -q 'plugin marketplace' || miss "claude-plugin: not in --list-options"
( cd "$k" && python3 tools/bump_version.py minor >/dev/null ) || miss "claude-plugin: bump failed"
grep -q '"version": "0.2.0"' "$k/.claude-plugin/marketplace.json" && grep -q '"version": "0.2.0"' "$k/plugins/sample-kit/.claude-plugin/plugin.json" \
  || miss "claude-plugin: bump did not reach every manifest"
grep -q '^## 0\.2\.0 — ' "$k/CHANGELOG.md" && grep -q '^## Unreleased$' "$k/CHANGELOG.md" || miss "claude-plugin: bump did not date the changelog"
[ "$(cd "$k" && python3 tools/bump_version.py --notes 0.2.0)" = "- Repository skeleton with one sample plugin." ] || miss "claude-plugin: --notes does not print the section"
( cd "$k" && make check >/dev/null 2>&1 ) || miss "claude-plugin: make check fails after a bump"
again=$(python3 "$S/apply.py" --target "$k" --json | json 'str(len(d["conflict"])+len(d["updated"])+len(d["created"]))+" "+str(sorted(d["kept"]))')
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
python3 "$S/detect.py" --target "$ROOT/tests/fixtures/plugin-repos/intact" | json '",".join(d["claude_plugin"]["plugins"])' | grep -q '^alpha,beta$' || miss "detect: plugins not listed"
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
padopt "sorted(d['created']) == ['.claude/settings.json', '.claude/skills/review-change/SKILL.md', '.editorconfig', '.gitattributes', '.nvmrc', 'AGENTS.md', 'CLAUDE.md', 'Makefile', 'tools/plugin_lint.py']"
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
  got=$(verdict "$1" "$2" "${4:-}"); echo "$got" | grep -qE "$3" || miss "doctor on $(basename "$1"): $2 gave '$got', want /$3/"; }
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
echo "$text" | grep -q 'Scored as: claude-plugin (detected: Claude Code plugin manifests)' || miss "doctor text does not say how the repo was scored"
echo "$text" | grep -q 'Not applicable to a claude-plugin repository (not scored):' || miss "doctor text hides the checks that do not apply"
echo "$text" | grep -q 'Domain ontology: glossary + entity definitions: A plugin marketplace has no business domain' || miss "doctor text gives no reason for skipping the ontology"
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
{ python3 "$TMP/plug/tools/plugin_lint.py" --root "$TMP/pd-root" --json || true; } | json 'str(d["ok"])+" "+str(d["checks"]["sources"]["ok"])' | grep -q '^False False$' || miss "plugin_lint --json"
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
remote_verdict | grep -q '^pass$' || miss "releases: a repo without tags must pass: $(remote_verdict)"
git -C "$rl" tag v1.1.0; git -C "$rl" tag v1.2.0
remote_verdict | grep -q '^fail: 2 tag(s) and no GitHub Release' || miss "releases: tags without releases: $(remote_verdict)"
echo '[{"tagName":"v1.1.0"},{"tagName":"v1.2.0"}]' > "$TMP/releases.json"
remote_verdict | grep -q '^pass$' || miss "releases: released tags must pass: $(remote_verdict)"
verdict "$rl" plugin_releases '--level team' | grep -q '^absent$' || miss "releases: must be a reminder without --remote"
python3 "$S/doctor.py" --target "$rl" --level team | grep -q 'Version tags are published as GitHub Releases' || miss "releases: no reminder without --remote"
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
python3 "$BT" --root "$b" --notes 1.2.0 | grep -q 'alpha greets' || miss "bump: --notes"
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
printf '%s\n' "$out" | grep -q "no 'delete' action for Order" || miss "lifecycle: the missing delete is not named: $out"
printf '%s\n' "$out" | grep -q "lifecycle.delete" || miss "lifecycle: the message does not say how to record the choice: $out"
printf '%s\n' "$out" | grep -q "no 'create' action" && miss "lifecycle: a covered operation was reported: $out"
put 'lifecycle:\n  query: { later: Order history screen }\n  update: { never: Not changed after it is placed }\n  delete: { later: Yearly clean-up }\n'
lerrs | grep -q "lifecycle.update: 'never' needs decided_by" || miss "lifecycle: a refusal with nobody behind it passed: $(lerrs)"
put 'lifecycle:\n  query:\n    later: Order history screen\n  update:\n    never: Not changed after it is placed\n    decided_by: shop owner 2026-01-05\n  delete: { later: Yearly clean-up }\n'
[ -z "$(lerrs)" ] || miss "lifecycle: recorded choices still fail: $(lerrs)"
lwarns | grep -q "Order: 'query' is planned, not built (Order history screen)" || miss "lifecycle: a postponed operation is not listed: $(lwarns)"
lwarns | grep -q "Order: 'update'" && miss "lifecycle: a decided refusal is listed as a debt: $(lwarns)"
put 'lifecycle:\n  create: { later: x }\n  query: { later: x }\n  update: { later: x }\n  delete: { later: x }\n'
lwarns | grep -q "lifecycle.create is out of date: placeOrder" || miss "lifecycle: a stale entry is not reported: $(lwarns)"
put 'lifecycle:\n  via: Customer\n'
[ -z "$(lerrs)" ] || miss "lifecycle: an entity handled through another one fails: $(lerrs)"
put 'lifecycle:\n  via: Nobody\n'
lerrs | grep -q "lifecycle.via: 'Nobody' is not an entity" || miss "lifecycle: via an unknown entity passed: $(lerrs)"
put 'lifecycle:\n  via: Order\n'
lerrs | grep -q "lifecycle.via: an entity cannot be handled through itself" || miss "lifecycle: via itself passed: $(lerrs)"
put 'lifecycle:\n  remove: { later: x }\n'
lerrs | grep -q "lifecycle.remove: unknown key" || miss "lifecycle: an unknown key passed: $(lerrs)"
put 'lifecycle: later\n'
lerrs | grep -q "lifecycle must be a mapping" || miss "lifecycle: a bare word passed: $(lerrs)"
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
printf '%s\n' "$out" | grep -q "Customer -places-> Order: no answer for attach, detach, reassign" || miss "relations: a relation nobody can change gave: $out"
[ "$(printf '%s\n' "$out" | grep -c "no answer for")" -eq 1 ] || miss "relations: one relation gave more than one error: $out"
printf '%s\n' "$out" | grep -q "relations: {places: \[<operation>\]}" || miss "relations: the message does not say how an action answers: $out"
printf '%s\n' "$out" | grep -q "lifecycle.<operation>: {later: <where it is planned>}" || miss "relations: the message does not say how to record the choice: $out"
printf '%s\n' "$out" | grep -q "lifecycle: {via: <that entity>}" || miss "relations: the message does not show the one-line form: $out"
relation '' many-to-many
rerrs | grep -q "Customer -places-> Order: no answer for attach, detach:" || miss "relations: a many-to-many relation was asked to reassign: $(rerrs)"
relation '    lifecycle:\n      attach: { later: Counter sign-up }\n      detach: { never: Orders stay with their customer }\n      reassign: { later: Merge two customers }\n'
rerrs | grep -q "Customer -places-> Order: lifecycle.detach: 'never' needs decided_by" || miss "relations: a refusal with nobody behind it passed: $(rerrs)"
relation '    lifecycle:\n      attach: { later: Counter sign-up }\n      detach:\n        never: Orders stay with their customer\n        decided_by: shop owner 2026-01-05\n      reassign: { later: Merge two customers }\n'
[ -z "$(rerrs)" ] || miss "relations: recorded choices still fail: $(rerrs)"
[ -z "$(rerrs_builtin)" ] || miss "relations: recorded choices fail with the built-in YAML reader: $(rerrs_builtin)"
rwarns | grep -q "Customer -places-> Order: 'reassign' is planned, not built (Merge two customers)" || miss "relations: a postponed operation is not listed: $(rwarns)"
rwarns | grep -q "Customer -places-> Order: 'detach'" && miss "relations: a decided refusal is listed as a debt: $(rwarns)"
action '  - name: moveOrder\n    description: Move an order to another customer.\n    entity: Order\n    kind: command\n    roles: [manager]\n    relations: { places: [reassign] }\n'
rwarns | grep -q "Customer -places-> Order: lifecycle.reassign is out of date: moveOrder" || miss "relations: a stale entry is not reported: $(rwarns)"
relation ''
out=$(rerrs)
printf '%s\n' "$out" | grep -q "Customer -places-> Order: no answer for attach, detach:" || miss "relations: an action that reassigns did not answer reassign: $out"
relation '    lifecycle: { via: Order }\n'
rerrs | grep -q "Customer -places-> Order: lifecycle.via says the link never changes, but moveOrder" || miss "relations: via next to an action that changes the link passed: $(rerrs)"
action '  - name: moveOrder\n    description: Move an order.\n    entity: Order\n    kind: command\n    roles: [manager]\n    relations: { places: reasign, serves: attach }\n'
out=$(rerrs)
printf '%s\n' "$out" | grep -q "action 'moveOrder': relation 'places': unknown operation 'reasign'" || miss "relations: a misspelt operation passed: $out"
printf '%s\n' "$out" | grep -q "action 'moveOrder': relation 'serves' is not in ontology/relations.yaml" || miss "relations: an unknown relation passed: $out"
action '  - name: moveOrder\n    description: Move an order.\n    entity: Order\n    kind: command\n    roles: [manager]\n    relations: places\n'
rerrs | grep -q "action 'moveOrder': relations must be a mapping" || miss "relations: a bare word under relations passed: $(rerrs)"
action '  - name: moveOrder\n    description: Move an order.\n    entity: Order\n    kind: command\n    roles: [manager]\n    relations: { places: reassign }\n'
{ cat "$TMP/relations.base"; printf '  - from: Order\n    name: places\n    to: Customer\n    cardinality: many-to-many\n    lifecycle: { via: Order }\n'; } > "$rel"
rerrs | grep -q "action 'moveOrder': relation 'places' is the name of 2 relations" || miss "relations: an ambiguous relation name passed: $(rerrs)"
action ''
relation '    lifecycle: { via: Nobody }\n'
rerrs | grep -q "Customer -places-> Order: lifecycle.via: 'Nobody' is not one of its ends" || miss "relations: via an entity outside the relation passed: $(rerrs)"
relation '    lifecycle: { remove: { later: x } }\n'
rerrs | grep -q "Customer -places-> Order: lifecycle.remove: unknown key" || miss "relations: an unknown key passed: $(rerrs)"
relation '    lifecycle: fixed\n'
rerrs | grep -q "Customer -places-> Order: lifecycle must be a mapping" || miss "relations: a bare word passed: $(rerrs)"
# own: the starter form (own: [role]) and the scope form are read alike
cp "$TMP/relations.base" "$rel"
action '  - name: viewOrder\n    description: See an order.\n    entity: Order\n    kind: query\n    roles: [staff, manager]\n    own: [staff]\n'
out=$(rerrs)
printf '%s\n' "$out" | grep -q "action 'viewOrder': staff may run it only on their own Order, but no relation says what 'own' means" || miss "relations: an own scope with no relation behind it gave: $out"
printf '%s\n' "$out" | grep -q "mark it own: true" || miss "relations: the own message does not say how to fix it: $out"
action '  - name: viewOrder\n    description: See an order.\n    entity: Order\n    kind: query\n    scope: { staff: own, manager: company }\n'
rerrs | grep -q "action 'viewOrder': staff may run it only on their own Order" || miss "relations: the scope form of own is not read: $(rerrs)"
relation '    own: true\n    lifecycle: { via: Order }\n'
[ -z "$(rerrs)" ] || miss "relations: an own scope with its relation still fails: $(rerrs)"
[ -z "$(rerrs_builtin)" ] || miss "relations: an own scope with its relation fails with the built-in YAML reader: $(rerrs_builtin)"
relation '    own: maybe\n    lifecycle: { via: Order }\n'
rerrs | grep -q "Customer -places-> Order: own must be true or false" || miss "relations: own: maybe passed: $(rerrs)"
# PyYAML reads yes / no as true / false; the built-in reader keeps them as words. Neither may read "no" as a yes.
for word in no yes maybe; do
  relation "    own: $word\n    lifecycle: { via: Order }\n"
  rerrs_builtin | grep -q "Customer -places-> Order: own must be true or false" || miss "relations: own: $word passed with the built-in YAML reader: $(rerrs_builtin)"
done
relation '    own: no\n    lifecycle: { via: Order }\n'
rerrs | grep -q "action 'viewOrder': staff may run it only on their own Order" || miss "relations: own: no was read as a yes: $(rerrs)"
# through the entity it lives under: Customer handled through Order, the own relation ends at Order
relation '    own: true\n    lifecycle: { via: Order }\n'
action '  - name: viewCustomerPhone\n    description: See the phone of a customer.\n    entity: Customer\n    kind: command\n    roles: [staff]\n    own: [staff]\n'
{ sed '/^lifecycle:/,$d' "$TMP/customer.base"; printf 'lifecycle: { via: Order }\n'; } > "$cust"
printf 'relations:\n  - from: Order\n    name: served_at\n    to: Order\n    cardinality: one-to-one\n    own: true\n    lifecycle: { via: Order }\n' > "$rel"
[ -z "$(rerrs)" ] || miss "relations: own through the entity it lives under fails: $(rerrs)"
cp "$TMP/customer.base" "$cust"
rerrs | grep -q "action 'viewCustomerPhone': staff may run it only on their own Customer" || miss "relations: own passed without via or a relation: $(rerrs)"
cp "$TMP/relations.base" "$rel"
action '  - name: viewOrder\n    description: See an order.\n    entity: Order\n    kind: query\n    roles: [manager]\n    own: [staff]\n'
rerrs | grep -q "action 'viewOrder': own lists role 'staff', which is not in its roles" || miss "relations: own for a role that may not run the action passed: $(rerrs)"
action '  - name: viewOrders\n    description: See orders.\n    kind: query\n    roles: [staff]\n    own: [staff]\n'
rerrs | grep -q "action 'viewOrders': own needs entity" || miss "relations: own without an entity passed: $(rerrs)"
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
awarns | grep -q "Customer: setting name, phone is planned, not built (Sign-up at the counter)" || miss "attributes: postponed properties are not listed together: $(awarns)"
setc ''
out=$(aerrs)
printf '%s\n' "$out" | grep -q "Customer: no create or update action sets id, name, phone, status, joinedAt:" || miss "attributes: properties nobody can set gave: $out"
[ "$(printf '%s\n' "$out" | grep -c "no create or update action sets")" -eq 1 ] || miss "attributes: one entity gave more than one error: $out"
printf '%s\n' "$out" | grep -q "sets: \[...\]" || miss "attributes: the message does not say how an action answers: $out"
printf '%s\n' "$out" | grep -q "not_set: system: \[...\]" || miss "attributes: the message does not say how to record the reason: $out"
# an explicit sets wins over the input fields, and counts on any kind of action
action '  - name: blockCustomer\n    description: Stop a customer from ordering.\n    entity: Customer\n    kind: command\n    roles: [manager]\n    sets: [status]\n'
aerrs | grep -q "Customer: no create or update action sets id, name, phone, joinedAt:" || miss "attributes: sets on a command did not count: $(aerrs)"
awk '{ print } /^    kind: update$/ { print "    sets: [name]" }' "$TMP/actions.base" > "$act"
grep -q 'sets: \[name\]' "$act" || miss "attributes: the test did not add sets to the update action"
aerrs | grep -q "Customer: no create or update action sets id, phone, points, status, joinedAt:" || miss "attributes: an explicit sets did not win over the input fields: $(aerrs)"
action '  - name: blockCustomer\n    description: Stop a customer.\n    entity: Customer\n    kind: command\n    roles: [manager]\n    sets: [state]\n'
aerrs | grep -q "action 'blockCustomer': sets 'state', which is not a property of Customer" || miss "attributes: an unknown property under sets passed: $(aerrs)"
action '  - name: blockCustomer\n    description: Stop a customer.\n    entity: Customer\n    kind: command\n    roles: [manager]\n    sets: status\n'
aerrs | grep -q "action 'blockCustomer': sets must be a list of property names" || miss "attributes: a bare word under sets passed: $(aerrs)"
action '  - name: blockAll\n    description: Stop everyone.\n    kind: command\n    roles: [manager]\n    sets: [status]\n'
aerrs | grep -q "action 'blockAll': sets needs entity" || miss "attributes: sets without an entity passed: $(aerrs)"
action ''
setc 'not_set:\n  system: [id, joinedAt]\n  import: [phone]\n  later: { name: Sign-up at the counter }\n  never:\n    status: { reason: Customers are never blocked }\n'
aerrs | grep -q "not_set.never.status: 'never' needs decided_by" || miss "attributes: a refusal with nobody behind it passed: $(aerrs)"
setc 'not_set:\n  system: [id, joinedAt]\n  import: [phone]\n  later: { name: Sign-up at the counter }\n  never:\n    status: { reason: Customers are never blocked, decided_by: shop owner 2026-01-05 }\n'
[ -z "$(aerrs)" ] || miss "attributes: recorded reasons still fail: $(aerrs)"
[ -z "$(aerrs_builtin)" ] || miss "attributes: recorded reasons fail with the built-in YAML reader: $(aerrs_builtin)"
awarns | grep -q "Customer: setting name is planned, not built (Sign-up at the counter)" || miss "attributes: a postponed property is not listed: $(awarns)"
awarns | grep -q "Customer: setting.*status" && miss "attributes: a decided refusal is listed as a debt: $(awarns)"
setc 'not_set:\n  system: [id, joinedAt, points]\n  later: { name: x, phone: x, status: x }\n'
awarns | grep -q "not_set.system: 'points' is out of date: awardPoints now sets it" || miss "attributes: a stale entry is not reported: $(awarns)"
setc 'not_set:\n  system: [id, joinedAt, nickname]\n  later: { name: x, phone: x, status: x }\n'
aerrs | grep -q "not_set.system: 'nickname' is not a property of Customer" || miss "attributes: an unknown property under not_set passed: $(aerrs)"
setc 'not_set:\n  derived: [id]\n'
aerrs | grep -q "not_set.derived: unknown key" || miss "attributes: an unknown key passed: $(aerrs)"
setc 'not_set: system\n'
aerrs | grep -q "not_set must be a mapping" || miss "attributes: a bare word passed: $(aerrs)"
setc 'not_set:\n  system: id\n  later: [name]\n  never: [status]\n'
out=$(aerrs)
printf '%s\n' "$out" | grep -q "not_set.system must be a list of property names" || miss "attributes: system as a bare word passed: $out"
printf '%s\n' "$out" | grep -q "not_set.later must be a mapping" || miss "attributes: later as a list passed: $out"
printf '%s\n' "$out" | grep -q "not_set.never must be a mapping" || miss "attributes: never as a list passed: $out"
setc 'not_set:\n  system: [id, joinedAt]\n  later: { name: x, phone: x }\n  never:\n    status: { decided_by: shop owner 2026-01-05 }\n'
aerrs | grep -q "not_set.never.status: give reason" || miss "attributes: a refusal without a reason passed: $(aerrs)"
# an entity with no create or update action, or handled through its parent, is not asked per property
cp "$a/ontology/entities/Customer.yaml" "$TMP/customer.any"; printf '%s\n' "$cust_base" | sed '/^lifecycle:/,$d' > "$cust"; printf 'lifecycle: { via: Order }\n' >> "$cust"
aerrs | grep -q "no create or update action sets" && miss "attributes: an entity handled through its parent was asked: $(aerrs)"
printf '%s\n' "$ord_base" > "$ord"
aerrs | grep -q "Order: no create or update action sets id, placedOn:" || miss "attributes: the control case did not fail: $(aerrs)"
sed 's/^    kind: create$/    kind: command/' "$TMP/actions.base" > "$act"
aerrs | grep -q "Order: no create or update action sets" && miss "attributes: an entity with no create or update action was asked: $(aerrs)"
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
# asking for merge commits: the diff against the fixture is the title of one step and two values on its line
gsdiff() { { dry "$1" --merge-method merge || true; } | diff "$FX/$2" - | grep '^[<>]' | head -8 || true; }
want_diff() { printf '%s\n' \
  "<   - squash-only merges, delete merged branches$1" \
  "<       gh api -X PATCH repos/acme/sample$2 -F delete_branch_on_merge=true -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false" \
  ">   - merge commits only, delete merged branches$1" \
  ">       gh api -X PATCH repos/acme/sample$2 -F delete_branch_on_merge=true -F allow_squash_merge=false -F allow_merge_commit=true -F allow_rebase_merge=false"; }
[ "$(gsdiff "$gs" dry-run-team.txt)" = "$(want_diff '' '')" ] || miss "merge method: merge changed more or less than the three merge settings: $(gsdiff "$gs" dry-run-team.txt)"
[ "$(gsdiff "$gsa" dry-run-team-agents.txt)" = "$(want_diff ', auto-merge' ' -F allow_auto_merge=true')" ] || miss "merge method: merge with agents changed more or less than the three merge settings: $(gsdiff "$gsa" dry-run-team-agents.txt)"
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
printf '%s\n' "$out" | grep -q "invalid choice: 'rebase'" || miss "merge method: an unknown method was not refused by name: $out"
dry "$gs" --merge-method merge --reviewer @b | grep -q 'human approval by @b' || miss "merge method: --reviewer is lost next to --merge-method"
[ ! -s "$TMP/gs-calls" ] || miss "merge method: a dry run called gh to change something: $(cat "$TMP/gs-calls")"
python3 "$gs/tools/github_setup.py" --help | grep -q -- '--merge-method' || miss "merge method: --help does not show the option"
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
echo "ok  merge method (or misses reported above)"

# 43. people decide, machines check (docs/setup-principles.md): nothing the setup generates uses a
#     person as a checker. A person appears where something is decided: the rules, production.
pd="$TMP/people-decide"; mkdir -p "$pd" && git -C "$pd" init -q -b main
python3 "$S/apply.py" --target "$pd" --preset python --level team --with github-agents --var project_name=P --var description=x --var owner=acme >/dev/null
tier_of() { ( cd "$pd" && python3 tools/autonomy.py --files "$@" | json 'd["tier"]' ); }
# 43a. high is the rules of the game and nothing else: no product path is high because of its name
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
dry "$pd" | grep -q 'checks check, gate, secret-scan, conventional-title, conventional-commits, evidence' || miss "people decide: github_setup does not require the proof the policy names"
# 43d. a looser agent guard is a rule change, wherever it is written; a new action is not
mkdir -p "$pd/ontology" "$pd/src"
printf 'actions:\n  - name: wipe\n    agent: forbidden\n  - name: refund\n    agent: confirm\n' > "$pd/ontology/actions.yaml"
pd_save() { git -C "$pd" add -A && git -C "$pd" -c user.name=t -c user.email=t@example.com commit -q -m "$1"; }
pd_start() { git -C "$pd" checkout -q -B "$1" main; }
pd_tier() { actual=$(cd "$pd" && python3 tools/autonomy.py --base main --head HEAD | json 'd["tier"]')
  [ "$actual" = "$2" ] || miss "people decide: tier of '$1': got $actual, want $2"; }
pd_save base
pd_start e1; subst '/agent: forbidden/d' "$pd/ontology/actions.yaml"; pd_save e1
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
echo "$review" | grep -q "needs.gate.outputs.proof == ''" || miss "people decide: the reviewer agent runs again on a change the proof covers"
echo "$automerge" | grep -q "needs.gate.outputs.proof != ''" || miss "people decide: a proven change does not merge itself without the reviewer agent"
echo "$automerge" | grep -q 'draft == false' || miss "people decide: auto-merge may fire on a draft"
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
grep -A1 'Hold a change that is no longer low' "$pipeline" | grep -q "needs.tier.outputs.tier != 'low'" || miss "people decide: the hold does not run for every tier above low"
gate_job=$(sed -n '/^  gate:$/,/^  review:$/p' "$pipeline")
echo "$gate_job" | grep -q 'if: always()' || miss "people decide: the required check is skipped, and so counts as passed, when the tier job fails"
echo "$gate_job" | grep -q "needs.tier.result != 'success'" || miss "people decide: the required check passes without a tier"
echo "$gate_job" | grep -q 'contents: write' || miss "people decide: the job that turns auto-merge off may not do so"
if echo "$gate_job" | grep -q 'actions/checkout'; then miss "people decide: the job that may write checks out the pull request"; fi
sed -n '/^  tier:$/,/^  gate:$/p' "$pipeline" | grep -q 'contents: read' || miss "people decide: the job that reads the pull request may write"
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
echo "$automerge" | grep -q "needs.gate.result == 'success'" || miss "people decide: auto-merge may run although the gate failed"
# 43g. generated instructions add no stop of their own; settings ask nothing and keep the silent walls
for phrase in 'get approval before you start' 'ask in the issue and stop' 'need human review' 'need a human reviewer' 'one approval is required' '(high tier)'; do
  if grep -qiF "$phrase" "$pd/AGENTS.md" "$pd/CONTRIBUTING.md" "$pd/.github/pull_request_template.md" "$pd/ontology/README.md" "$ROOT/plugins/repo-setup/archetypes/service-api/starter/+AGENTS.md/40-service-api.md" "$ROOT/plugins/repo-setup/archetypes/service-api/starter/tools/api_compat.py"; then miss "people decide: generated text stops for a person: $phrase"; fi
done
grep -q 'never a reason to stop' "$pd/AGENTS.md" || miss "people decide: AGENTS.md does not say that a tier is no reason to stop"
python3 - "$pd/.claude/settings.json" <<'PY' || miss "people decide: settings.json asks, blocks Bash by pattern, or lost a silent wall"
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8"))["permissions"]
assert not p.get("ask"), p.get("ask")
assert not [r for r in p["deny"] if r.startswith("Bash(")], p["deny"]
for wall in ("Read(./.env)", "Edit(./.github/workflows/**)", "Edit(./governance/**)"):
    assert wall in p["deny"], wall
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
bp_verdict | grep -q '^pass$' || miss "people decide: doctor wants an approval count: $(bp_verdict)"
echo '[{"type":"required_status_checks"}]' > "$TMP/rules.json"
bp_verdict | grep -q '^fail' || miss "people decide: doctor accepts a branch that needs no pull request: $(bp_verdict)"
echo '[{"type":"pull_request","parameters":{"required_approving_review_count":1,"require_code_owner_review":true}}]' > "$TMP/rules.json"
bp_verdict | grep -q '^fail' || miss "people decide: doctor accepts approvals in place of required checks: $(bp_verdict)"
echo '[{"type":"pull_request","parameters":{"required_approving_review_count":1,"require_code_owner_review":false}},{"type":"required_status_checks"}]' > "$TMP/rules.json"
bp_verdict | grep -q '^fail' || miss "people decide: doctor accepts a branch where the rules have lost their decider: $(bp_verdict)"
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
{ grep -A4 'alias: gitleaks-history' "$rw/.pre-commit-config.yaml" || true; } | grep -q 'stages: \[manual\]' || miss "real walls: the CI secret scan also runs on every local commit"
# 44b. the red direction: a token in a commit turns the scan red, also after a later commit deletes it
rw_save() { git -C "$rw" add -A && git -C "$rw" -c user.name=t -c user.email=t@example.com commit -q -m "$1"; }
rw_scan() { ( cd "$rw" && $scan >/dev/null 2>&1 ); }
if command -v gitleaks >/dev/null 2>&1 && [ -n "$scan" ]; then
  rw_save "chore: base"
  rw_scan || miss "real walls: the secret scan is red on a clean repository"
  # Made at run time, so no token-shaped text sits in this file.
  python3 -c "import random, string; print('const token = \"ghp_' + ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(36)) + '\";')" > "$rw/src/planted.ts"
  rw_save "feat: planted"
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
dry "$rw" | grep -q 'RELEASE_PLEASE_TOKEN is missing: releases are off' || miss "real walls: github_setup does not say that releases are off"
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
rk_verdict | grep -q '^fail' || miss "real walls: doctor is content with releases that have no key: $(rk_verdict)"
echo RELEASE_PLEASE_TOKEN > "$TMP/secrets"
rk_verdict | grep -q '^pass$' || miss "real walls: doctor does not see the release key: $(rk_verdict)"
# 44d. the commit-format check judges what reaches the default branch: the title when squashing, the commits otherwise
pt="$rw/.github/workflows/pr-title.yml"
for job in conventional-title conventional-commits; do
  grep -q "^  $job:\$" "$pt" || miss "real walls: pr-title.yml has no $job job"
done
grep -q 'squashMergeAllowed' "$pt" || miss "real walls: the title check does not read whether the repository squashes"
grep -q 'mergeCommitAllowed' "$pt" || miss "real walls: the commit check does not read whether the repository keeps commits"
grep -q 'pre-commit run conventional-pre-commit --hook-stage commit-msg' "$pt" || miss "real walls: commits are not judged by the repository's own commit-msg hook"
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
# Stand-in for the commit-msg hook: the last argument is the file with the message.
for a in "$@"; do f=$a; done
echo "$f" >> "$CC_CALLS"
grep -qE '^(feat|fix|chore|docs|test|refactor|perf|ci)(\([a-z-]+\))?!?: .+' "$f"
SH
chmod +x "$TMP/ccbin/gh" "$TMP/ccbin/pipx"
cc() { : > "$TMP/cc-calls"; echo "$2" > "$TMP/cc-second"
  ( PATH="$TMP/ccbin:$PATH" CC_KEEPS="$1" CC_SECOND="$TMP/cc-second" CC_CALLS="$TMP/cc-calls" PR=7 GITHUB_REPOSITORY=acme/sample \
    RUNNER_TEMP="$TMP/ccrun" GITHUB_STEP_SUMMARY="$TMP/cc-summary" bash -e -c "$(steps_of 'Check every commit the branch would add')" ) 2>&1; }
cc true 'fix: two' >/dev/null || miss "real walls: the commit check rejects a branch whose commits are all conventional"
[ "$(wc -l < "$TMP/cc-calls" | tr -d ' ')" = 2 ] || miss "real walls: the commit check did not judge both commits"
if cc true 'changed stuff' >/dev/null; then miss "real walls: the commit check accepts a commit that is not conventional"; fi
{ cc true 'changed stuff' || true; } | grep -q '::error::Commit bbb' || miss "real walls: the commit check does not name the commit it rejects"
cc false 'changed stuff' >/dev/null || miss "real walls: the commit check judges commits in a repository that squashes"
[ ! -s "$TMP/cc-calls" ] || miss "real walls: the commit check ran the hook in a repository that squashes"
{ cc unreadable 'changed stuff' || true; } | grep -q '::warning::' || miss "real walls: the commit check is silent when it cannot read how the repository merges"
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
dry "$rw" | grep -q 'checks check, secret-scan, conventional-title, conventional-commits$' || miss "real walls: the secret scan is not a required check: $(dry "$rw" | grep 'ruleset on')"
rw_checks '[e2e, e2e-db]' 2>/dev/null || true
rw_governance_ok || miss "real walls: a policy that names its own checks was refused"
dry "$rw" | grep -q 'checks check, secret-scan, conventional-title, conventional-commits, e2e, e2e-db$' || miss "real walls: github_setup does not require the checks the policy names: $(dry "$rw" | grep 'ruleset on')"
for reserved in check gate secret-scan; do
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
echo "$out" | grep -q 'e2e' || miss "real walls: the refusal does not say which required check would go"
echo "$out" | grep -q -- '--prune' || miss "real walls: the refusal does not say how to drop the check on purpose"
rw_apply --prune >/dev/null || true
[ "$(rw_put)" = 1 ] || miss "real walls: --prune does not update the ruleset"
rw_checks '[e2e]' 2>/dev/null || true
rw_apply >/dev/null || true
[ "$(rw_put)" = 1 ] || miss "real walls: a ruleset whose extra check is named in the policy was not updated"
printf 'check\ne2e\n' > "$TMP/rw-checks"; rw_checks '[]' 2>/dev/null || true
{ rw_apply --prune || true; } | grep -q 'dropping the required check(s) e2e' || miss "real walls: --prune does not say which required check it drops"
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
echo "$out" | grep -q 'could not be listed' || miss "real walls: github_setup is silent when it cannot list the secrets"
if echo "$out" | grep -q 'is missing'; then miss "real walls: github_setup calls a secret missing when it could not list the secrets"; fi
echo "$out" | grep -q 'rulesets could not be read' || miss "real walls: the dry run is silent when it cannot read the rulesets"
nr --apply >/dev/null
if grep -q -- '-X POST repos/acme/sample/rulesets' "$TMP/nr-calls" 2>/dev/null; then miss "real walls: github_setup made a ruleset without knowing whether one exists"; fi
# 44h. a required check must be one that a job reports
rw_checks '[e2e, ""]' 2>/dev/null || true
if rw_governance_ok; then miss "real walls: an empty name was accepted under required_checks"; fi
cp "$TMP/rw-policy.orig" "$rw_policy"
mv "$rw/.github/workflows/security.yml" "$TMP/security.yml.kept"
dry "$rw" | grep -q 'checks check, conventional-title, conventional-commits$' || miss "real walls: secret-scan is required in a repository where no job has that name: $(dry "$rw" | grep 'ruleset on')"
dry "$rw" | grep -q 'secret-scan is not a required check' || miss "real walls: github_setup does not say that secret-scan is not required"
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
  echo "$job" | grep -q 'actions: read' || miss "real walls: the $preset CodeQL job may not read its own run, which a private repository needs"
  for uses in actions/checkout github/codeql-action/init github/codeql-action/analyze; do
    echo "$job" | grep -A1 "uses: $uses" | grep -q "if: steps.scanning.outputs.on != 'false'" \
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
echo "$out" | grep -q 'checks check, secret-scan, conventional-title$' || miss "real walls: a commit-format check the default branch does not define yet is required: $(echo "$out" | grep 'ruleset on')"
echo "$out" | grep -q 'conventional-commits is not a required check yet' || miss "real walls: github_setup does not say that conventional-commits waits for the default branch"
out=$(GS_BASE_DOWN=1 dry "$rw" || true)
echo "$out" | grep -q 'checks check, secret-scan$' || miss "real walls: a commit-format check is required although the default branch could not be read: $(echo "$out" | grep 'ruleset on')"
echo "$out" | grep -q 'could not be read' || miss "real walls: github_setup is silent when it cannot read the workflows of the default branch"
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
for doc in docs/setup-principles.md docs/three-repo-boundaries.md docs/three-repo-overview-design.md docs/superpowers/specs/2026-11-16-real-walls-design.md; do
  [ -f "$ROOT/$doc" ] || miss "own rules: $doc is missing"
done
old_names='nguyen-tac-setup\.md|ranh-gioi-ba-kho\.md|thiet-ke-tong-quan-ba-kho\.md|tuong-that-design\.md'
stale=$(cd "$ROOT" && git ls-files | grep -E "$old_names" || true)
[ -z "$stale" ] || miss "own rules: a document still has a Vietnamese file name: $stale"
stale=$(cd "$ROOT" && git grep -l -E "$old_names" -- . ':!tests/run.sh' || true)
[ -z "$stale" ] || miss "own rules: a file still points at a renamed document: $(echo $stale)"
echo "ok  own rules (or misses reported above)"

# 46. parallel work does not queue (docs/three-repo-overview-design.md, RS2a and RS10): the one file
#     every pull request writes merges by itself, and the numbers that say whether work queues come
#     from a command, not from a count made by hand once.
fl="$TMP/flow"; mkdir -p "$fl" && git -C "$fl" init -q -b main
python3 "$S/apply.py" --target "$fl" --preset ts-node --level team --var project_name=P --var description=x --var owner=acme >/dev/null
fl_git() { git -C "$fl" -c user.name=t -c user.email=t@example.com "$@"; }
fl_save() { fl_git add -A && fl_git commit -q -m "$1"; }
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
# The answers have the shape GitHub gives: the fake gh below runs the tool's own --jq program on them.
python3 - "$fl" "$TMP/flowgh" <<'PY'
import json, pathlib, subprocess, sys

repo, out = sys.argv[1], pathlib.Path(sys.argv[2])
DAY = "2026-01-02T00:"


def listed(branch: str) -> list[dict]:
    """What GitHub lists for a pull request: the commits of the branch that main does not have."""
    rows = subprocess.run(["git", "-C", repo, "rev-list", "--parents", branch, "^main"],
                          capture_output=True, text=True, check=True).stdout.splitlines()
    return [commit(r.split()[0], r.split()[1:]) for r in rows]


def commit(sha: str, parents: list[str]) -> dict:
    return {"sha": sha, "commit": {"message": "x"}, "parents": [{"sha": p, "url": "u"} for p in parents]}


def pull(number: int, base: str = "main", merged: str | None = None) -> dict:
    return {"number": number, "title": f"feat: {number}", "author": {"login": "dev"}, "labels": [], "reviews": [],
            "createdAt": "2026-01-01T00:00:00Z", "mergedAt": merged, "closedAt": merged, "baseRefName": base}


def job(name: str, conclusion: str, start: int, end: int) -> dict:
    return {"id": 1, "name": name, "conclusion": conclusion, "status": "completed",
            "started_at": f"{DAY}{start:02d}:00Z", "completed_at": f"{DAY}{end:02d}:00Z"}


def run(number: int, name: str, event: str, branch: str, conclusion: str) -> dict:
    return {"id": number, "name": name, "event": event, "head_branch": branch, "status": "completed",
            "head_sha": f"{number:040x}", "conclusion": conclusion, "run_attempt": 1}


def save(name: str, *pages: object) -> None:
    (out / name).write_text("".join(json.dumps(page) + "\n" for page in pages))


save("merged.json", [pull(2, merged="2026-01-01T10:00:00Z"), pull(3, merged="2026-01-01T20:00:00Z")])
save("closed.json", [pull(6)])
# Pull request 5 goes into branch two: the branch it merges is not the default one.
save("open.json", [pull(4), pull(5, base="two")])
save("pr2.json", listed("two"))
save("pr3.json", listed("three"))
# A merge whose commits this clone does not have, and cannot fetch: there is no remote.
save("pr4.json", [commit("a" * 40, ["b" * 40, "c" * 40])])
save("pr5.json", [commit("d" * 40, ["e" * 40, "f" * 40])])
save("pr6.json", [commit("9" * 40, ["8" * 40])])
runs = [
    run(1, "CI", "pull_request", "two", "failure"),
    run(2, "CI", "pull_request", "three", "success"),
    run(5, "CI", "pull_request", "five", "success"),
    run(3, "CI", "push", "main", "success"),
    run(6, "CI", "push", "main", "success"),
    run(4, "Release", "push", "main", "failure"),
]
# Two pages, as GitHub pages a long list.
save("runs.json", {"total_count": 6, "workflow_runs": runs[:3]}, {"total_count": 6, "workflow_runs": runs[3:]})
# A list GitHub cut short: it says nine runs and hands over one.
save("runs-short.json", {"total_count": 9, "workflow_runs": runs[:1]})
save("runs-none.json", {"total_count": 0, "workflow_runs": []})
jobs = {
    # gate passed and a heavier job ended red afterwards on the same head: a late red.
    1: [job("gate", "success", 0, 2), job("check", "success", 0, 3), job("e2e-db", "failure", 0, 30)],
    # red first, then run again: gate passed only after the red had ended. Not a late red.
    2: [job("check", "failure", 0, 3), job("gate", "failure", 0, 1),
        job("check", "success", 10, 13), job("gate", "success", 10, 12)],
    # a late red that a second attempt turned green: it still counts.
    5: [job("gate", "success", 0, 2), job("e2e", "failure", 0, 10),
        job("gate", "success", 20, 22), job("e2e", "success", 20, 30)],
    # the default branch: red on the first attempt, green on the second.
    3: [job("check", "failure", 0, 5), job("check", "success", 10, 15)],
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
  jq -c "$2" "$file"
}
case "$all" in
  "pr list --state merged"*baseRefName*) cat "$FLOW_GH/merged.json" ;;
  "pr list --state closed"*baseRefName*) cat "$FLOW_GH/closed.json" ;;
  "pr list --state open"*baseRefName*) cat "$FLOW_GH/open.json" ;;
  "repo view"*) echo '{"nameWithOwner":"acme/p","defaultBranchRef":{"name":"main"}}' ;;
  *deployments*) echo '[]' ;;
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
fl_day=$(python3 -c "import datetime as d; print((d.datetime.now(d.UTC) - d.timedelta(days=7)).date())")
fl_metrics() { ( cd "$1" && PATH="$TMP/flbin:$PATH" FLOW_GH="$TMP/flowgh" FLOW_DAY="$fl_day" python3 tools/sdlc_metrics.py --days 7 "${@:2}" 2>/dev/null || true ); }
fl_is() { [ "$(echo "$flow" | json "$1" 2>/dev/null || true)" = "$2" ] || miss "flow: $3"; }
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
  fl_is 'd["ci"]["runs"]' 6 "the workflow runs of every page and of every day of the window are not counted once each"
  fl_is 'd["ci"]["machine_minutes"]' 83.0 "machine minutes are not the sum of the job durations of every attempt"
  fl_is 'd["ci"]["machine_minutes_per_merged_pr"]' 41.5 "machine minutes are not set against the merged pull requests"
  fl_is 'd["ci"]["late_red"]' "[2, 3]" "late red is not: a job that ended red after gate passed on that head, also when a second attempt turned it green, and not when the red came first"
  fl_is 'd["ci"]["default_branch"]' "{'CI': [1, 2], 'Release': [1, 1]}" "red on the default branch is not counted per workflow, or a run made green by a second attempt is not counted as red"
  flow=$(FLOW_NO_RUNS=1 fl_metrics "$fl" --json)
  fl_is 'bool(d["ci"]["unread"])' True "workflow runs that could not be read are reported as zero runs"
  fl_is 'd["back_merges"]["conflicting"]' 1 "one part that cannot be read hides the parts that can"
  flow=$(FLOW_RUNS=runs-short fl_metrics "$fl" --json)
  fl_is '"1 of 9" in d["ci"]["unread"]' True "a list of workflow runs that GitHub cut short is reported as the whole list"
  # 46e. the page a person reads carries the same lines
  page=$(fl_metrics "$fl")
  for line in 'longest 20.0 h' 'Merges of the default branch into a pull request branch | 3 on 4' \
    'conflict when replayed | 1 of 2' 'could not be replayed | 1 (git fetch' '`src/grid.ts` 1' \
    'per merged pull request (every run in the window) | 41.5' \
    'Late red (a job ended red on a head after `gate` passed) | 2 of 3' 'CI 1 of 2, Release 1 of 1'; do
    echo "$page" | grep -qF -- "$line" || miss "flow: the report does not carry the line: $line"
  done
  FLOW_NO_RUNS=1 fl_metrics "$fl" | grep -q 'not read' || miss "flow: the report shows numbers for workflow runs it could not read"
else
  echo "skip  flow 46b-46e: jq is not installed, the measure was not run"
fi
# 46f. a list of pull requests that stops at the limit of the query is said to be partial
partial=$(cd "$fl" && python3 -c "
import sys; sys.path.insert(0, 'tools'); import sdlc_metrics as s
print(s.capped({'merged': [0] * s.PR_LIMIT, 'open': [0]}))" 2>/dev/null || true)
[ "$partial" = "['merged']" ] || miss "flow: a list of pull requests cut at the limit is taken for the whole list"
echo "ok  flow (or misses reported above)"

# shellcheck source=tests/upgrade.sh
. "$ROOT/tests/upgrade.sh"

[ "$misses" -eq 0 ] || fail "$misses regression check(s) failed"
echo "All tests passed."

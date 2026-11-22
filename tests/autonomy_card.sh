# 54. the autonomy card (docs/superpowers/specs/2026-11-22-outside-work-and-autonomy-card-design.md,
#     5.2): the autonomy gate names the row of the card that calls a person, so `make autonomy` and
#     the gate say the same words. 54e is the gate's own part. Sourced by tests/run.sh; uses its
#     ROOT, S, TMP, json, subst and miss.

acd_t="$TMP/acd-team"; mkdir -p "$acd_t"; git -C "$acd_t" init -q -b main
python3 "$S/apply.py" --target "$acd_t" --preset python --level team --var project_name=A --var description=x --var owner=acme >/dev/null

acd_tier() { # <repo> <policy or ""> <args...>: the gate's JSON for a change
  local repo="$1" policy="$2"; shift 2
  if [ -n "$policy" ]; then python3 "$repo/tools/autonomy.py" --root "$repo" --policy "$policy" "$@"
  else python3 "$repo/tools/autonomy.py" --root "$repo" "$@"; fi
}
acd_save() { # <repo> <message>: record what is staged, as a throwaway author
  git -C "$1" -c user.name=t -c user.email=t@t commit -q -m "$2"
}

# 54a. `make autonomy` at the starter level (a python repo and a claude-plugin repo): the card of
#      ruling 7, six keys on every row, nothing written, no traceback
acd_starter() { # <dir> <preset>: a committed starter repo
  mkdir -p "$1"; git -C "$1" init -q -b main
  python3 "$S/apply.py" --target "$1" --preset "$2" --level starter --var project_name=A --var description=x --var owner=acme >/dev/null
  git -C "$1" add -A; acd_save "$1" init
}
acd_s="$TMP/acd-starter"; acd_starter "$acd_s" python
acd_p="$TMP/acd-starter-plugin"; acd_starter "$acd_p" claude-plugin

acd_rc=0; acd_make=$(cd "$acd_s" && make autonomy 2>&1) || acd_rc=$?
[ "$acd_rc" = 0 ] || miss "autonomy card: make autonomy exits $acd_rc: $acd_make"
case "$acd_make" in *"Autonomy card"*) ;; *) miss "autonomy card: make autonomy prints no Autonomy card: $acd_make" ;; esac
case "$acd_make" in *"You are called when"*) ;; *) miss "autonomy card: make autonomy prints no You are called when: $acd_make" ;; esac

acd_card() { python3 "$1/tools/autonomy_card.py" --root "$1" "${@:2}"; }
acd_card_json=$(acd_card "$acd_s" --json 2>&1 || true)
out=$(printf '%s' "$acd_card_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['level'] == 'starter', d
keys = {'when', 'you_do', 'why', 'switch', 'keys', 'known'}
assert all(set(r) == keys for r in d['called']), d['called']
any_row = [r for r in d['called'] if r['when'] == 'Any change merges']
assert len(any_row) == 1 and '--level team' in any_row[0]['switch'], d['called']
assert any_row[0]['you_do'] == 'merge' and any_row[0]['known'] is True, any_row
walls = [r for r in d['called'] if '.github/workflows/' in r['when']]
assert len(walls) == 1 and walls[0]['you_do'] == 'you edit it', d['called']
assert any('ci.yml' in m['what'] or 'ci.yml' in m['keys'] for m in d['machine']), d['machine']
assert len(d['next_level']) == 3, d['next_level']
assert 'not_allowed' not in d, d
" 2>&1) || miss "autonomy card: the starter card is wrong: $out"

acd_keys=$(acd_card "$acd_s" --keys 2>&1 || true)
out=$(printf '%s\n' "$acd_keys" | python3 -c "
import sys
lines = sys.stdin.read().splitlines()
ks = [i for i, l in enumerate(lines) if l.lstrip().startswith('keys: ')]
assert len(ks) >= 2, lines
for i in ks:
    assert lines[i - 1].strip() != '' and not lines[i - 1].lstrip().startswith('keys: '), (i, lines[i - 1])
" 2>&1) || miss "autonomy card: --keys does not put a keys: line under each row: $out"
acd_plain=$(acd_card "$acd_s" 2>&1 || true)
case "$acd_plain" in *"keys: "*) miss "autonomy card: keys: lines show without --keys" ;; esac

acd_before=$(git -C "$acd_s" status --porcelain)
acd_card "$acd_s" --json >/dev/null 2>&1; acd_card "$acd_s" >/dev/null 2>&1
[ "$acd_before" = "$(git -C "$acd_s" status --porcelain)" ] || miss "autonomy card: a run changed the repository"
acd_ign=$(git -C "$acd_s" status --porcelain --ignored)
case "$acd_ign" in *__pycache__*) miss "autonomy card: a run left a cache folder" ;; esac

rm -f "$acd_s/.repo-setup.json"
acd_before=$(git -C "$acd_s" status --porcelain)
acd_guess=$(acd_card "$acd_s" --json 2>&1 || true)
[ "$acd_before" = "$(git -C "$acd_s" status --porcelain)" ] || miss "autonomy card: a run without .repo-setup.json changed the repository"
out=$(printf '%s' "$acd_guess" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['level'] == 'starter', d
assert any('guess' in m['what'] and '.repo-setup.json' in m['what'] for m in d['machine']), d['machine']
" 2>&1) || miss "autonomy card: the level guessed from files is wrong: $out"

acd_rc=0; acd_pj=$(acd_card "$acd_p" --json 2>"$TMP/acd-plugin.err") || acd_rc=$?
[ "$acd_rc" = 0 ] || miss "autonomy card: the claude-plugin card exits $acd_rc"
acd_err=$(cat "$TMP/acd-plugin.err")
[ -z "$acd_err" ] || miss "autonomy card: the claude-plugin card wrote to stderr: $acd_err"
out=$(printf '%s' "$acd_pj" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['level'] == 'starter' and 'not_allowed' not in d, d
" 2>&1) || miss "autonomy card: the claude-plugin card has a not_allowed part: $out"

acd_plain_rc=0; acd_card "$TMP" >/dev/null 2>&1 || acd_plain_rc=$?
[ "$acd_plain_rc" = 2 ] || miss "autonomy card: outside a git repository exits $acd_plain_rc, not 2"

# 54g. the actions of ontology/ an agent may not run freely (ruling 8)
mkdir -p "$acd_s/ontology"
cat > "$acd_s/ontology/actions.yaml" <<'YAML'
actions:
  - name: placeOrder
    description: A customer places an order.
    kind: create
    agent: confirm
  - name: dropOrders
    description: Remove every order.
    kind: delete
    agent: forbidden
  - name: listOrders
    description: List orders.
    kind: query
YAML
acd_og=$(acd_card "$acd_s" --json 2>&1 || true)
out=$(printf '%s' "$acd_og" | python3 -c "
import json, sys
d = json.load(sys.stdin)
row = [r for r in d['called'] if r['when'] == 'An agent runs one of 1 product actions marked confirm']
assert len(row) == 1 and row[0]['switch'] == 'agent: allowed on that action', d['called']
# a missing agent counts as forbidden, as ontology_actions reads it
assert len(d['not_allowed']) == 1 and '2' in d['not_allowed'][0]['what'], d['not_allowed']
" 2>&1) || miss "autonomy card: the ontology actions are wrong: $out"
rm -rf "$acd_s/ontology/actions.yaml"
acd_on=$(acd_card "$acd_s" --json 2>&1 || true)
out=$(printf '%s' "$acd_on" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert not any('product actions' in r['when'] for r in d['called']), d['called']
assert 'not_allowed' not in d, d
" 2>&1) || miss "autonomy card: no actions.yaml still gives an ontology part: $out"

# 54e. the gate names the row: the words of ruling 3, six keys, None where nothing calls a person
out=$(acd_tier "$acd_t" "" --files src/a/x.py 2>&1 | python3 -c "
import json, sys
c = json.load(sys.stdin)['card']
assert c['when'] == 'Product code merges', c
assert c['you_do'] == 'merge', c
assert 'proof.check' in c['switch'], c
assert set(c) == {'when', 'you_do', 'why', 'switch', 'keys', 'known'}, sorted(c)
assert c['known'] is True, c
" 2>&1) || miss "autonomy card: the row of product code is wrong: $out"

out=$(acd_tier "$acd_t" "" --files governance/autonomy.yaml 2>&1 | python3 -c "
import json, sys
c = json.load(sys.stdin)['card']
assert c['when'] == 'The rules change', c
assert c['you_do'] == 'merge the pull request', c
assert 'one owner' in c['why'], c
assert c['switch'] == '-', c
" 2>&1) || miss "autonomy card: the row of a rule change (one owner) is wrong: $out"

acd_two="$TMP/acd-two.yaml"; sed 's/^  high: \["@acme"\]/  high: ["@acme", "@lan"]/' "$acd_t/governance/autonomy.yaml" > "$acd_two"
out=$(acd_tier "$acd_t" "$acd_two" --files governance/autonomy.yaml 2>&1 | python3 -c "
import json, sys
c = json.load(sys.stdin)['card']
assert c['you_do'] == 'approve the pull request (code owner)', c
assert 'one owner' not in c['why'], c
" 2>&1) || miss "autonomy card: the row of a rule change (two owners) is wrong: $out"

out=$(acd_tier "$acd_t" "" --files docs/x.md 2>&1 | python3 -c "
import json, sys
assert json.load(sys.stdin)['card'] is None
" 2>&1) || miss "autonomy card: a low change got a row: $out"

acd_b="$TMP/acd-base"; mkdir -p "$acd_b"; git -C "$acd_b" init -q -b main
python3 "$S/apply.py" --target "$acd_b" --preset python --level team --var project_name=A --var description=x --var owner=acme >/dev/null
mkdir -p "$acd_b/tests"; printf 'def test_a():\n    assert 1\n\ndef test_b():\n    assert 2\n' > "$acd_b/tests/test_x.py"
git -C "$acd_b" add tests/test_x.py
acd_save "$acd_b" one
printf 'def test_a():\n    assert 1\n' > "$acd_b/tests/test_x.py"
git -C "$acd_b" add tests/test_x.py
acd_save "$acd_b" two
out=$(acd_tier "$acd_b" "" --base HEAD~1 --head HEAD 2>&1 | python3 -c "
import json, sys
c = json.load(sys.stdin)['card']
assert c['why'] == 'a guard was loosened', c
" 2>&1) || miss "autonomy card: the row of a removed test is wrong: $out"

acd_sum="$TMP/acd-summary.md"; : > "$acd_sum"
GITHUB_STEP_SUMMARY="$acd_sum" acd_tier "$acd_t" "" --files src/a/x.py --github >/dev/null 2>&1
acd_text=$(cat "$acd_sum")
case "$acd_text" in *"To be called less"*) ;; *) miss "autonomy card: the step summary has no To be called less line: $acd_text" ;; esac

# the job `tier` of pr-pipeline.yml copies only these three files into a folder of their own
acd_ci="$TMP/acd-ci"; mkdir -p "$acd_ci/tools" "$acd_ci/governance"
cp "$acd_t/tools/autonomy.py" "$acd_t/tools/repo_ontology.py" "$acd_ci/tools/"
cp "$acd_t/governance/autonomy.yaml" "$acd_ci/governance/"
out=$(cd "$acd_ci" && python3 tools/autonomy.py --policy governance/autonomy.yaml --files src/a/x.py 2>&1 | python3 -c "
import json, sys
assert json.load(sys.stdin)['card']['when'] == 'Product code merges'
" 2>&1) || miss "autonomy card: the gate copied alone (as in CI) has no card: $out"

# 54f. the outside ledger names the row behind each person's step (status --json "card", and a
#      card: line in the text), the words of ruling 5
acd_o="$TMP/acd-outside"; mkdir -p "$acd_o"; git -C "$acd_o" init -q -b main
python3 "$S/apply.py" --target "$acd_o" --preset python --level team --with github-agents --var project_name=A --var description=x --var owner=acme >/dev/null
printf '\n[[item]]\ndecision = "approve-production"\nwhen = "each deploy to production"\n' >> "$acd_o/ops/outside.toml"
acd_gh="$TMP/acd-gh"; mkdir -p "$acd_gh"; printf '#!/bin/sh\nexit 0\n' > "$acd_gh/gh"; chmod +x "$acd_gh/gh"
acd_status() { ( cd "$acd_o" && PATH="$acd_gh:$PATH" OUTSIDE_TIMEOUT=1 python3 tools/outside.py status "$@" 2>/dev/null ); }
acd_json=$(acd_status --json || true); acd_text=$(acd_status || true)
out=$(printf '%s' "$acd_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in ('base', 'ok', 'apply', 'yours', 'decisions', 'unknown', 'unmerged', 'refused'):
    assert k in d, k
called = d['card']['called']
keys = {'when', 'you_do', 'why', 'switch', 'keys', 'known'}
assert all(set(r) == keys for r in called), called
miss_row = [r for r in called if r['when'] == '2 keys are missing']
assert len(miss_row) == 1, called
assert miss_row[0]['switch'] == 'python3 tools/outside.py secrets', miss_row
assert 'RELEASE_PLEASE_TOKEN' in miss_row[0]['keys'] and 'CLAUDE_CODE_OAUTH_TOKEN' in miss_row[0]['keys'], miss_row
dec = [r for r in called if r['when'] == 'each deploy to production']
assert len(dec) == 1 and dec[0]['why'] == 'always yours' and dec[0]['switch'] == '-', called
once = [r for r in called if r['you_do'] == 'do once']
assert len(once) == 1 and 'install-claude-github-app' in once[0]['keys'], called
unk = [r for r in called if r['known'] is False]
assert len(unk) == 1 and unk[0]['switch'] == 'python3 tools/outside.py status', called
assert all(set(m) == {'what', 'keys'} for m in d['card']['machine']), d['card']['machine']
" 2>&1) || miss "autonomy card: outside.py status --json has no right card: $out"
acd_line=$(printf '%s\n' "$acd_text" | grep -A1 '^Yours (' | tail -1)
case "$acd_line" in "  card: "*"2 keys are missing"*) ;; *) miss "autonomy card: no card: line under Yours: $acd_line" ;; esac

# 54b. `make autonomy` at the team level: the policy through autonomy.card_row, the ledger through
#      outside.py status --json, the layers that are on (rulings 4, 6, 10). Reuses 54f's repo.
acd_tcard() { # <repo> <args...>: the team card, with the stand-in gh in front
  local repo="$1"; shift
  ( cd "$repo" && PATH="$acd_gh:$PATH" OUTSIDE_TIMEOUT=1 python3 tools/autonomy_card.py --root "$repo" "$@" 2>&1 )
}
acd_rules_row=$(acd_tier "$acd_o" "" --files governance/autonomy.yaml 2>&1 || true)
acd_tj=$(acd_tcard "$acd_o" --json || true)
out=$(ACD_RULES="$acd_rules_row" python3 -c "
import json, os, sys
d = json.loads(sys.stdin.read())
gate = json.loads(os.environ['ACD_RULES'])['card']
assert d['level'] == 'team', d['level']
keys = {'when', 'you_do', 'why', 'switch', 'keys', 'known'}
assert all(set(r) == keys for r in d['called']), d['called']
rules = [r for r in d['called'] if r['when'] == 'The rules change']
assert rules == [gate], (rules, gate)
assert len([r for r in d['called'] if r['when'] == 'Product code merges']) == 1, d['called']
assert len([r for r in d['called'] if r['when'] == '2 keys are missing']) == 1, d['called']
assert len([r for r in d['called'] if r['when'] == 'each deploy to production']) == 1, d['called']
assert d['called'], 'a fresh team repository calls nobody'
assert [r for r in d['called'] if r['when'] == 'A dependency update (minor)'], d['called']
assert [r for r in d['called'] if r['when'] == 'A dependency update (major)'], d['called']
assert not [r for r in d['called'] if r['when'] == 'A dependency update (patch)'], d['called']
mach = [m['what'] for m in d['machine']]
assert any('patch' in m for m in mach), mach
assert any('docs/**' in m for m in mach), mach
assert any('an agent on GitHub' in m for m in mach), mach
assert 'next_level' not in d, d
" <<<"$acd_tj" 2>&1) || miss "autonomy card: the team card is wrong: $out"

acd_bin="$TMP/acd-bin"; mkdir -p "$acd_bin"
for acd_tool in python3 git make; do ln -sf "$(command -v "$acd_tool")" "$acd_bin/$acd_tool"; done
acd_f="$TMP/acd-fastapi"; mkdir -p "$acd_f"; git -C "$acd_f" init -q -b main
python3 "$S/apply.py" --target "$acd_f" --preset fastapi --level team --deploy container --var project_name=A --var description=x --var owner=acme >/dev/null
acd_fj=$(acd_tcard "$acd_f" --json || true)
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
mach = [m['what'] for m in d['machine']]
assert any('staging deploys are off' in m for m in mach), mach
" <<<"$acd_fj" 2>&1) || miss "autonomy card: a deploy repository without DEPLOY_ENABLED does not say deploys are off: $out"
printf '\n[[item]]\nrecipe = "github-variable"\nname = "DEPLOY_ENABLED"\nvalue = "true"\n' >> "$acd_f/ops/outside.toml"
acd_gh2="$TMP/acd-gh2"; mkdir -p "$acd_gh2"; printf '#!/bin/sh\necho DEPLOY_ENABLED=true\n' > "$acd_gh2/gh"; chmod +x "$acd_gh2/gh"
acd_fj=$( ( cd "$acd_f" && PATH="$acd_gh2:$PATH" OUTSIDE_TIMEOUT=1 python3 tools/autonomy_card.py --json 2>&1 ) || true)
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
mach = [m['what'] for m in d['machine']]
assert any('deploys to staging after each merge' in m for m in mach), mach
assert not any('staging deploys are off' in m for m in mach), mach
" <<<"$acd_fj" 2>&1) || miss "autonomy card: DEPLOY_ENABLED in place does not say deploys run: $out"

# no gh: the DEPLOY_ENABLED row exists but cannot be checked: not known, never "off"
acd_fj=$( ( cd "$acd_f" && PATH="$acd_bin" OUTSIDE_TIMEOUT=1 python3 tools/autonomy_card.py --json 2>&1 ) || true)
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
mach = [m['what'] for m in d['machine']]
assert not any('staging deploys are off' in m for m in mach), mach
assert any('not known' in m and 'DEPLOY_ENABLED' in m for m in mach), mach
" <<<"$acd_fj" 2>&1) || miss "autonomy card: an unchecked DEPLOY_ENABLED row reads as deploys off: $out"

# 54c. a policy that is changed in a copy of the repository: the card follows it
acd_var() { # <name> <python edit of the policy text s>: the team card JSON of a changed copy
  local d="$TMP/acd-var-$1"; rm -rf "$d"; cp -R "$acd_o" "$d"
  python3 -c "
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / 'governance' / 'autonomy.yaml'
s = p.read_text()
$2
p.write_text(s)
" "$d"
  acd_tcard "$d" --json || true
}
acd_v=$(acd_var proof "
s = s.replace('default: medium', 'default: low').replace('check: \"\"', 'check: \"evidence\"')")
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert not [r for r in d['called'] if r['when'] == 'Product code merges'], d['called']
assert any('evidence' in m['what'] for m in d['machine']), d['machine']
" <<<"$acd_v" 2>&1) || miss "autonomy card: a policy with a proof still calls a person for product code: $out"
acd_v=$(acd_var refused "s = s.replace('default: medium', 'default: low')")
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
r = [r for r in d['called'] if r['when'] == 'Product code merges']
assert len(r) == 1 and r[0]['why'].startswith('default: low lets code merge'), d['called']
assert r[0]['switch'] == 'fix governance/autonomy.yaml', r
assert not any('product code' in m['what'].lower() and 'merge' in m['what'].lower() for m in d['machine']), d['machine']
" <<<"$acd_v" 2>&1) || miss "autonomy card: a refused default: low is shown as a machine merge: $out"
acd_v=$(acd_var owners "s = s.replace('high: [\"@acme\"]', 'high: [\"@acme\", \"@lan\"]')")
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
r = [r for r in d['called'] if r['when'] == 'The rules change']
assert len(r) == 1 and r[0]['you_do'] == 'approve the pull request (code owner)', d['called']
" <<<"$acd_v" 2>&1) || miss "autonomy card: two owners do not make the rules row a code owner approval: $out"
acd_v=$(acd_var minor "s = s.replace('minor: medium', 'minor: low')")
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert not [r for r in d['called'] if r['when'] == 'A dependency update (minor)'], d['called']
assert any('minor' in m['what'] for m in d['machine']), d['machine']
" <<<"$acd_v" 2>&1) || miss "autonomy card: minor: low is still a row: $out"

# 54d. a source that cannot be read is a known: false row with the reason, never silence
acd_before=$(git -C "$acd_o" status --porcelain)
acd_rc=0; acd_ng=$( ( cd "$acd_o" && PATH="$acd_bin" OUTSIDE_TIMEOUT=1 python3 tools/autonomy_card.py --json 2>&1 ) ) || acd_rc=$?
[ "$acd_rc" = 0 ] || miss "autonomy card: without gh the card exits $acd_rc: $acd_ng"
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert [r for r in d['called'] if r['when'] == 'The rules change'], d['called']
unk = [r for r in d['called'] if r['known'] is False]
assert unk and any('gh' in r['why'] for r in unk), d['called']
" <<<"$acd_ng" 2>&1) || miss "autonomy card: without gh a part of the card reads as nothing: $out"
acd_nl="$TMP/acd-noledger"; rm -rf "$acd_nl"; cp -R "$acd_o" "$acd_nl"; rm -f "$acd_nl/governance/outside.toml"
acd_rc=0; acd_nj=$(acd_tcard "$acd_nl" --json) || acd_rc=$?
[ "$acd_rc" = 0 ] || miss "autonomy card: without governance/outside.toml the card exits $acd_rc: $acd_nj"
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
r = [r for r in d['called'] if r['when'] == 'Work outside the repository']
assert len(r) == 1 and r[0]['known'] is False and r[0]['why'].startswith('unknown: '), d['called']
assert [r for r in d['called'] if r['when'] == 'The rules change'], d['called']
" <<<"$acd_nj" 2>&1) || miss "autonomy card: a missing ledger is not a known: false row: $out"
[ "$acd_before" = "$(git -C "$acd_o" status --porcelain)" ] || miss "autonomy card: a team run changed the repository"
acd_ign=$(git -C "$acd_o" status --porcelain --ignored)
case "$acd_ign" in *__pycache__*) miss "autonomy card: a team run left a cache folder" ;; esac
# a damaged actions.yaml: an item that is not a mapping, and `agent: null`
mkdir -p "$acd_nl/ontology"
printf 'actions:\n  - just a string\n  - name: x\n    agent: null\n' > "$acd_nl/ontology/actions.yaml"
acd_rc=0; acd_dj=$(acd_card "$acd_nl" --json 2>&1) || acd_rc=$?
[ "$acd_rc" = 0 ] || miss "autonomy card: a damaged actions.yaml gives exit $acd_rc: $acd_dj"
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
r = [r for r in d['called'] if r['when'] == 'An agent runs a product action']
assert len(r) == 1 and r[0]['known'] is False, d['called']
" <<<"$acd_dj" 2>&1) || miss "autonomy card: a damaged actions.yaml is not a known: false row: $out"

# 54i. final review: the card never shows unchecked work as done
# (1) a row a person recorded by hand is not machine work "in place"
acd_hr="$TMP/acd-hand"; rm -rf "$acd_hr"; cp -R "$acd_o" "$acd_hr"
printf '\n[[item]]\naction = "sign-the-dpa"\ndone = "2026-11-01"\n' >> "$acd_hr/ops/outside.toml"
acd_hj=$( ( cd "$acd_hr" && PATH="$acd_gh:$PATH" OUTSIDE_TIMEOUT=1 python3 tools/outside.py status --json 2>/dev/null ) || true)
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert [r['id'] for r in d['ok']] == ['action:sign-the-dpa'], d['ok']
what = [m['what'] for m in d['card']['machine']]
assert not any('in place' in w for w in what), what
hand = [m for m in d['card']['machine'] if 'recorded as done' in m['what']]
assert len(hand) == 1 and 'no machine checks it' in hand[0]['what'] and 'sign-the-dpa' in hand[0]['keys'], what
" <<<"$acd_hj" 2>&1) || miss "autonomy card: a row recorded by hand counts as in place: $out"
out=$(cd "$acd_t/tools" && python3 -c "
import outside
R = outside.Row
lists = {n: [] for n in outside.LISTS}
lists['ok'] = [R('a:one', 'setting', 'x', 'checked: in place', ''), R('action:two', 'action', '', 'recorded by hand on 2026-11-01, not checked', '')]
what = [m['what'] for m in outside.card(lists)['machine']]
assert what == ['1 row in place', '1 row a person recorded as done; no machine checks it'], what
" 2>&1) || miss "autonomy card: checked and hand-recorded rows are not told apart: $out"

# (2) the deploy line is never false: the id is read in every list, and the value counts
acd_dep() { # <name> <ledger rows> <gh output>: the team card JSON of a deploy repository
  local d="$TMP/acd-dep-$1" g="$TMP/acd-depgh-$1"; rm -rf "$d" "$g"; cp -R "$acd_f" "$d"; mkdir -p "$g"
  python3 -c "
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / 'ops' / 'outside.toml'
s = p.read_text().replace('\n[[item]]\nrecipe = \"github-variable\"\nname = \"DEPLOY_ENABLED\"\nvalue = \"true\"\n', sys.argv[2].replace('\\\\n', '\\n'))
p.write_text(s)
" "$d" "$2"
  printf '#!/bin/sh\n%s\n' "$3" > "$g/gh"; chmod +x "$g/gh"
  ( cd "$d" && PATH="$g:$PATH" OUTSIDE_TIMEOUT=1 python3 tools/autonomy_card.py --json 2>&1 ) || true
}
acd_deploy_line() { python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(' | '.join(m['what'] for m in d['machine'] if 'staging' in m['what']))
"; }
acd_dj=$(acd_dep refused '\n[[item]]\nrecipe = "github-variable"\nname = "DEPLOY_ENABLED"\n' 'echo DEPLOY_ENABLED=true')
acd_line=$(acd_deploy_line <<<"$acd_dj")
case "$acd_line" in *"not known"*) ;; *) miss "autonomy card: a refused DEPLOY_ENABLED row does not read not known: $acd_line" ;; esac
case "$acd_line" in *"are off"*|*"add a "*|*"deploys to staging after"*) miss "autonomy card: a refused DEPLOY_ENABLED row reads as off or on: $acd_line" ;; esac
acd_dj=$(acd_dep false '\n[[item]]\nrecipe = "github-variable"\nname = "DEPLOY_ENABLED"\nvalue = "false"\n' 'echo DEPLOY_ENABLED=false')
acd_line=$(acd_deploy_line <<<"$acd_dj")
case "$acd_line" in *"deploys to staging after each merge"*) miss "autonomy card: DEPLOY_ENABLED = false reads as deploying: $acd_line" ;; esac
case "$acd_line" in *"paused"*"false"*) ;; *) miss "autonomy card: DEPLOY_ENABLED = false does not read paused by its value: $acd_line" ;; esac
case "$acd_line" in *"add a "*) miss "autonomy card: DEPLOY_ENABLED = false says add a row: $acd_line" ;; esac
acd_dj=$(acd_dep hand '\n[[item]]\naction = "set-DEPLOY_ENABLED"\ndone = "2026-11-01"\n' 'echo nothing')
acd_line=$(acd_deploy_line <<<"$acd_dj")
case "$acd_line" in *"not known"*) ;; *) miss "autonomy card: a DEPLOY_ENABLED row recorded by hand does not read not known: $acd_line" ;; esac
case "$acd_line" in *"deploys to staging after"*|*"are off"*) miss "autonomy card: a hand-recorded DEPLOY_ENABLED row reads as on or off: $acd_line" ;; esac
acd_dj=$(acd_dep apply '\n[[item]]\nrecipe = "github-variable"\nname = "DEPLOY_ENABLED"\nvalue = "true"\n' 'echo nothing')
acd_line=$(acd_deploy_line <<<"$acd_dj")
case "$acd_line" in *"wait"*) ;; *) miss "autonomy card: an unapplied DEPLOY_ENABLED row does not wait: $acd_line" ;; esac

# (3) a policy refused for any reason names the file, not a switch it already has
acd_v=$(acd_var lowcheck "
s = s.replace('default: medium', 'default: low').replace('check: \"\"', 'check: \"evidence\"').replace('required_checks: []', 'required_checks: [\"check\"]')")
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
r = [r for r in d['called'] if r['when'] == 'Product code merges']
assert len(r) == 1, d['called']
assert r[0]['switch'] == 'fix governance/autonomy.yaml', r
assert r[0]['why'].startswith('required_checks: check is one of the setup'), r
" <<<"$acd_v" 2>&1) || miss "autonomy card: a refused required_checks policy names the wrong switch: $out"
acd_v=$(acd_var typo "s = s.replace('default: medium', 'default: lwo')")
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
r = [r for r in d['called'] if r['when'] == 'Product code merges']
assert len(r) == 1, d['called']
assert r[0]['switch'] == 'fix governance/autonomy.yaml', r
assert r[0]['why'].startswith('default: lwo is not one of'), r
" <<<"$acd_v" 2>&1) || miss "autonomy card: a mistyped default says no machine proof yet: $out"
out=$(acd_tier "$acd_t" "" --files src/a/x.py 2>&1 | python3 -c "
import json, sys
c = json.load(sys.stdin)['card']
assert c['why'] == 'no machine proof yet' and 'proof.check' in c['switch'], c
" 2>&1) || miss "autonomy card: a valid policy without a proof lost its words: $out"

# 54j. final review, Important 4: "merge once the checks are green" is said only where the agent
#      pipeline (github-agents) can merge; without it, or when the record cannot say, no merge is claimed
acd_merge_lines() { python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(' | '.join(m['what'] for m in d['machine'] if 'merge' in m['what'] and 'an agent on GitHub' not in m['what']))
"; }
acd_ml=$(acd_merge_lines <<<"$acd_tj")
case "$acd_ml" in *"changes to "*" merge once the checks are green"*) ;; *) miss "autonomy card: with github-agents the low merge wording is gone: $acd_ml" ;; esac
case "$acd_ml" in *"nothing merges it for you"*) miss "autonomy card: with github-agents the card says nothing merges: $acd_ml" ;; esac
acd_na="$TMP/acd-noagents"; rm -rf "$acd_na"; mkdir -p "$acd_na"; git -C "$acd_na" init -q -b main
python3 "$S/apply.py" --target "$acd_na" --preset python --level team --var project_name=A --var description=x --var owner=acme >/dev/null
acd_naj=$(acd_tcard "$acd_na" --json || true)
acd_ml=$(acd_merge_lines <<<"$acd_naj")
case "$acd_ml" in *"once the checks are green; nothing merges it for you"*) ;; *) miss "autonomy card: without github-agents the card does not say nothing merges it: $acd_ml" ;; esac
case "$acd_ml" in *" merge once the checks"*) miss "autonomy card: without github-agents a machine item claims the merge: $acd_ml" ;; esac
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert not [r for r in d['called'] if r['known'] is False and r['when'].startswith('A pull request that needs no person')], d['called']
" <<<"$acd_naj" 2>&1) || miss "autonomy card: a known record gives an unknown merge row: $out"
rm -f "$acd_na/.repo-setup.json"
acd_nuj=$(acd_tcard "$acd_na" --json || true)
acd_ml=$(acd_merge_lines <<<"$acd_nuj")
case "$acd_ml" in *" merge once the checks"*) miss "autonomy card: an unreadable record still claims the merge: $acd_ml" ;; esac
out=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
r = [r for r in d['called'] if r['when'].startswith('A pull request that needs no person')]
assert len(r) == 1 and r[0]['known'] is False and 'github-agents' in r[0]['why'] and r[0]['why'].startswith('unknown: '), d['called']
" <<<"$acd_nuj" 2>&1) || miss "autonomy card: an unreadable record is not a known: false merge row: $out"

# 54h. the rule and the words around it: AGENTS.md at both levels, the two review-change skills,
#      the tour, the explain table and the changelog
for acd_d in "$acd_s" "$acd_t"; do
  acd_ag=$(cat "$acd_d/AGENTS.md")
  case "$acd_ag" in *'row of the autonomy card'*'make autonomy'*|*'make autonomy'*'row of the autonomy card'*) ;; *) miss "autonomy card: $(basename "$acd_d") AGENTS.md lacks the rule (make autonomy, row of the autonomy card)" ;; esac
  acd_hits=$(printf '%s\n' "$acd_ag" | awk '/^## /{sec=$0} /row of the autonomy card/{print sec}')
  [ "$acd_hits" = "## The autonomy card" ] || miss "autonomy card: $(basename "$acd_d") rule is not under the heading The autonomy card: $acd_hits"
done
acd_pl="$ROOT/plugins/repo-setup"
for acd_f in "$acd_pl/presets/_core/starter/dot.claude/skills/review-change/SKILL.md" "$acd_pl/presets/claude-plugin/starter/dot.claude/skills/review-change/SKILL.md"; do
  acd_tier_step=$(grep -A4 'Tier\*\*' "$acd_f")
  case "$acd_tier_step" in *'`card`'*) ;; *) miss "autonomy card: the tier step of ${acd_f#"$acd_pl/"} does not name the card key" ;; esac
done
acd_tour=$(cat "$acd_pl/skills/new/references/tour.md")
case "$acd_tour" in *'make autonomy'*) ;; *) miss "autonomy card: tour.md does not name make autonomy" ;; esac
case "$acd_tour" in *'START-HERE'*'make autonomy'*|*'make autonomy'*'START-HERE'*) ;; *) miss "autonomy card: tour.md does not tie make autonomy to START-HERE" ;; esac
case "$acd_tour" in *'not copy the table into `docs/START-HERE.md`'*) ;; *) miss "autonomy card: tour.md does not say the table is not copied into START-HERE.md" ;; esac
acd_ex=$(grep 'autonomy_card.py' "$acd_pl/skills/explain/SKILL.md" || true)
[ -n "$acd_ex" ] || miss "autonomy card: the explain table lacks tools/autonomy_card.py"
acd_cl=$(awk '/^## Unreleased/{f=1;next} /^## /{f=0} f' "$ROOT/CHANGELOG.md")
case "$acd_cl" in *'make autonomy'*) ;; *) miss "autonomy card: the changelog does not name make autonomy under Unreleased" ;; esac
for acd_w in 'tools/autonomy_card.py' 'mk/autonomy.mk' '`card`'; do
  case "$acd_cl" in *"$acd_w"*) ;; *) miss "autonomy card: the changelog does not name $acd_w under Unreleased" ;; esac
done
case "$acd_cl" in *'What breaks on upgrade'*) ;; *) miss "autonomy card: the changelog has no What breaks on upgrade line under Unreleased" ;; esac

# 54k. the owner's ruling "say what is true": a low pull request merges by itself only where the
# agent pipeline is installed (its auto-merge). Outside capabilities/github-agents, no template,
# label or doc says it merges itself; it needs no approval once the checks pass.
acd_self=$(grep -rn -E 'merges itself|can merge itself' "$acd_pl" "$acd_pl/README.md" 2>/dev/null \
  | grep -v '/capabilities/github-agents/' | sort -u || true)
[ -z "$acd_self" ] || miss "autonomy card: an unconditional 'merges itself' claim outside github-agents: $acd_self"

echo "ok  the autonomy card: the gate names the row (or misses reported above)"

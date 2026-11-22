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

echo "ok  the autonomy card: the gate names the row (or misses reported above)"

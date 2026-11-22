# 53. the machine drafts, a person decides (docs/superpowers/specs/2026-11-22-outside-work-and-autonomy-card-design.md,
#     5.3): at team level the session may edit .github/workflows/ and governance/, such a change is a
#     pull request of its own that a code owner decides, a skill drafts a change of autonomy, and a
#     one-owner repository merges a rule change by the owner's merge. Sourced by tests/run.sh; uses
#     its ROOT, S, TMP, json, subst and miss.

ac_install() { # <target> <apply arguments...>
  local target="$1"; shift
  mkdir -p "$target"; git -C "$target" init -q -b main
  python3 "$S/apply.py" --target "$target" "$@" --var project_name=A --var description=x --var owner=acme >/dev/null
}
ac_s="$TMP/ac-starter"; ac_install "$ac_s" --preset python
ac_t="$TMP/ac-team"; ac_install "$ac_t" --preset python --level team --with github-agents

# 53a. one template, two results: the team level loses the two edit walls, both keep the read walls
ac_walls() { # <repo>: the deny list of its settings, one per line; exits 1 when the file is not what 43g wants
  python3 - "$1/.claude/settings.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8"))["permissions"]
assert not p.get("ask"), p.get("ask")
assert not [r for r in p["deny"] if r.startswith("Bash(")], p["deny"]
print("\n".join(p["deny"]))
PY
}
ac_reads='Read(./.env)
Read(./.env.local)
Read(./.env.*.local)
Read(./.env.production)
Read(./.env.staging)
Read(./secrets/**)
Read(./**/*.pem)'
ac_edits='Edit(./.github/workflows/**)
Edit(./governance/**)'
[ "$(ac_walls "$ac_t")" = "$ac_reads" ] || miss "machine drafts: the team settings are not the read walls alone: $(ac_walls "$ac_t" | tr '\n' ' ')"
[ "$(ac_walls "$ac_s")" = "$ac_reads
$ac_edits" ] || miss "machine drafts: the starter settings lost a wall: $(ac_walls "$ac_s" | tr '\n' ' ')"
[ "$(find "$ROOT/plugins/repo-setup" -name 'settings.json.tmpl' | wc -l | tr -d ' ')" = 1 ] || miss "machine drafts: the settings come from more than one template"

# 53b. the rules say what the walls now are: a rule change is a pull request of its own, high, never
#      merged by the machine; nothing still says the session may not edit those folders
ac_rules="$ac_t/AGENTS.md"
for said in 'a pull request of its own' 'never merge it yourself' 'a code owner decides' '.claude/skills/autonomy-change/SKILL.md'; do
  grep -qF "$said" "$ac_rules" || miss "machine drafts: the team AGENTS.md does not say: $said"
done
if grep -qiE 'do not edit `\.github/workflows|never\*\* edit `\.github/workflows|blocked in `\.claude/settings\.json`|humans own them' "$ac_rules"; then
  miss "machine drafts: the team AGENTS.md still forbids editing the rules: $(grep -iE 'do not edit|never\*\* edit|humans own them' "$ac_rules" | head -2)"
fi
if grep -q 'must be done by a human' "$ac_t/governance/autonomy.yaml"; then miss "machine drafts: the policy still says a person must make its changes"; fi
grep -q 'drafts' "$ac_t/governance/autonomy.yaml" || miss "machine drafts: the policy does not say the machine drafts its changes"
python3 - "$ROOT/plugins/repo-setup/README.md" <<'PY' || miss "machine drafts: the plugin README says the settings deny editing workflows at every level"
import sys
text = " ".join(open(sys.argv[1], encoding="utf-8").read().split())
assert "deny rules on secrets, workflows and `governance/`" not in text
assert "at starter level, on editing workflows and `governance/`" in text
PY

echo "ok  the machine drafts, a person decides (or misses reported above)"

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

echo "ok  the machine drafts, a person decides (or misses reported above)"

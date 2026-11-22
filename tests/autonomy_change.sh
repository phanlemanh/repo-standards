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

# 53c. the skill that drafts a change of autonomy: at team level only; every command it names is in
#      the repository; it runs the policy check, opens a pull request on a branch of its own, and
#      never merges; it adds no stop of its own (the phrases of 43g)
ac_skill=".claude/skills/autonomy-change/SKILL.md"
[ -f "$ac_t/$ac_skill" ] || miss "machine drafts: a team repository has no $ac_skill"
if [ -e "$ac_s/$ac_skill" ]; then miss "machine drafts: a starter repository, with no policy, got $ac_skill"; fi
out=$(python3 - "$ac_t" "$ac_skill" <<'PY' 2>&1
import pathlib, re, sys
root, skill = pathlib.Path(sys.argv[1]), sys.argv[2]
text = (root / skill).read_text(encoding="utf-8")
bad = []
head = text.split("---", 2)
if not text.startswith("---\n") or "\nname: autonomy-change\n" not in head[1] or "\ndescription: " not in head[1]:
    bad.append("the frontmatter lacks name: autonomy-change or a description")
targets = set()
for mk in [root / "Makefile", *sorted((root / "mk").glob("*.mk"))]:
    targets |= set(re.findall(r"(?m)^([a-z][a-z0-9-]*):", mk.read_text(encoding="utf-8")))
for tool in sorted(set(re.findall(r"python3 (tools/[\w./-]+\.py)", text))):
    if not (root / tool).is_file():
        bad.append(f"names {tool}, which the repository does not have")
# a command is a line of a code block, or code in backticks; prose may say "make" too
for target in sorted(set(re.findall(r"(?m)(?:^|`)make ([a-z][a-z0-9-]*)", text))):
    if target not in targets:
        bad.append(f"names make {target}, which no Makefile defines")
for said in ("make governance", "git switch -c", "gh pr create", "governance/autonomy.yaml"):
    if said not in text:
        bad.append(f"does not say {said}")
for never in (r"gh pr merge", r"gh pr \w+[^\n]*--auto", r"--admin"):
    if re.search(never, text):
        bad.append(f"says {never}: the skill merges, or turns auto-merge on")
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
) || miss "machine drafts: the autonomy-change skill: $out"
for phrase in 'get approval before you start' 'ask in the issue and stop' 'need human review' 'need a human reviewer' 'one approval is required' '(high tier)'; do
  if grep -qiF "$phrase" "$ac_t/$ac_skill" 2>/dev/null; then miss "machine drafts: the skill stops for a person: $phrase"; fi
done

echo "ok  the machine drafts, a person decides (or misses reported above)"

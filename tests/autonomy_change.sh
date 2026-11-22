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
for target in sorted(set(re.findall(r"(?m)(?:^|\x60)make ([a-z][a-z0-9-]*)", text))):  # \x60, a backtick: bash 3.2 reads a lone one inside $( ) as a command
    if target not in targets:
        bad.append(f"names make {target}, which no Makefile defines")
for said in ("make governance", "git worktree add", "gh pr create", "governance/autonomy.yaml"):
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

# 53d. one decider for the rules (the owner, 2026-11-22): GitHub does not let the author of a pull
#      request approve it, and the machine opens pull requests as the owner. So the ruleset asks for
#      no code owner review there, and says why before --apply; with two deciders, or a team, it
#      asks as before. Uses the stand-in GitHub of 52g ($ob_ghbin), which keeps its state.
out=$(python3 -B - "$ac_t/tools" <<'PY' 2>&1
import sys; sys.path.insert(0, sys.argv[1])
from autonomy import sole_decider
cases = [
    ({"owners": {"high": ["@acme"]}}, "@acme"),
    ({"owners": {"high": ["@Acme", " acme "]}}, "@acme"),
    ({"owners": {"high": ["acme"]}}, "@acme"),
    ({"owners": {"high": ["@acme", "@lan"]}}, ""),
    ({"owners": {"high": ["@acme/core"]}}, ""),
    ({"owners": {"high": []}}, ""),
    ({"owners": {"high": "@acme"}}, ""),
    ({"owners": {"medium": ["@acme"]}}, ""),
    ({"owners": "x"}, ""),
    ({}, ""),
]
bad = [f"{policy} gives {sole_decider(policy)!r}, want {want!r}" for policy, want in cases if sole_decider(policy) != want]
print("\n".join(bad)); sys.exit(1 if bad else 0)
PY
) || miss "machine drafts: sole_decider: $out"
out=$( cd "$ac_t" && python3 -B - <<'PY' 2>&1
import sys; sys.path.insert(0, "tools")
import github_setup as g
def pull_request(steps):
    ruleset = [s for s in steps if "ruleset" in s][0]
    return ruleset["what"], {r["type"]: r.get("parameters", {}) for r in ruleset["ruleset"]["rules"]}["pull_request"]
bad = []
for agents in (False, True):
    what, pr = pull_request(g.plan("o/r", "main", "@acme", agents, one_decider="@acme"))
    if pr["require_code_owner_review"] is not False or pr["required_approving_review_count"] != 0:
        bad.append(f"one decider, agents={agents}: {pr}")
    if "no code owner review (one decider: @acme)" not in what:
        bad.append(f"one decider, agents={agents}: the step does not say so: {what}")
    what, pr = pull_request(g.plan("o/r", "main", "@acme", agents))
    if pr["require_code_owner_review"] is not True or "no code owner review" in what:
        bad.append(f"more deciders, agents={agents}: {pr} {what}")
print("\n".join(bad)); sys.exit(1 if bad else 0)
PY
) || miss "machine drafts: the plan of the ruleset: $out"
# ac_gh <repo> <state dir> <github_setup arguments...>: run it against the stand-in GitHub
ac_gh() { local repo="$1" state="$2"; shift 2
  ( cd "$repo" && PATH="$ob_ghbin:$PATH" OB_GH="$state" OB_GH_FILES="$repo" OB_LOG="$TMP/ac-gh.log" \
    python3 -B tools/github_setup.py "$@" </dev/null ) 2>&1; }
ac_review() { python3 -c "
import json, sys
rs = json.load(open(sys.argv[1]))
print([r for r in rs['rules'] if r['type'] == 'pull_request'][0]['parameters']['require_code_owner_review'])" "$1/ruleset.json" 2>&1; }
ac_one="$TMP/ac-gh-one"; rm -rf "$ac_one"
out=$(ac_gh "$ac_t" "$ac_one") || true
grep -qF 'no code owner review (one decider: @acme)' <<<"$out" || miss "machine drafts: the dry run of a one-owner repository does not show the ruleset without code owner review"
grep -qF 'GitHub does not let the author of a pull request approve it' <<<"$out" || miss "machine drafts: the dry run does not say why the code owner review is off: $(tail -5 <<<"$out")"
grep -qF 'kept by word' <<<"$out" || miss "machine drafts: the dry run does not say what is then kept by word"
[ ! -e "$ac_one/ruleset.json" ] || miss "machine drafts: the dry run wrote a ruleset"
out=$(ac_gh "$ac_t" "$ac_one" --apply) || true
grep -qF 'GitHub does not let the author of a pull request approve it' <<<"$out" || miss "machine drafts: --apply on a one-owner repository does not say why the code owner review is off"
[ "$(ac_review "$ac_one")" = False ] || miss "machine drafts: --apply on a one-owner repository asks for a code owner review: $(ac_review "$ac_one")"
# (the stand-in keeps no labels, so only the ruleset line is read here)
out=$(ac_gh "$ac_t" "$ac_one" --check) || true
grep -q '^= ruleset' <<<"$out" || miss "machine drafts: --check right after --apply on a one-owner repository sees the ruleset differ: $(grep ruleset <<<"$out")"
# a ruleset from before this release asks for the review: --check sees it, --apply turns it off
python3 - "$ac_one/ruleset.json" <<'PY'
import json, sys; f = sys.argv[1]; d = json.load(open(f))
for r in d["rules"]:
    if r["type"] == "pull_request": r["parameters"]["require_code_owner_review"] = True
json.dump(d, open(f, "w"))
PY
rc=0; out=$(ac_gh "$ac_t" "$ac_one" --check) || rc=$?
[ "$rc" = 1 ] && grep -q '^~ ruleset.*pull_request' <<<"$out" || miss "machine drafts: --check does not see the code owner review an older run left on ($rc): $(grep ruleset <<<"$out")"
ac_gh "$ac_t" "$ac_one" --apply >/dev/null || true
[ "$(ac_review "$ac_one")" = False ] || miss "machine drafts: --apply does not turn off the code owner review an older run left on"
# two deciders, and a team: the review stays
for ac_owners in '"@acme", "@lan"' '"@acme/core"'; do
  ac_two="$TMP/ac-two"; rm -rf "$ac_two" "$TMP/ac-gh-two"; cp -R "$ac_t" "$ac_two"
  subst "s|^  high: \\[.*\\]$|  high: [$ac_owners]|" "$ac_two/governance/autonomy.yaml"
  grep -qF "  high: [$ac_owners]" "$ac_two/governance/autonomy.yaml" || miss "machine drafts: the fixture could not set owners.high to $ac_owners"
  out=$(ac_gh "$ac_two" "$TMP/ac-gh-two" --apply) || true
  [ "$(ac_review "$TMP/ac-gh-two")" = True ] || miss "machine drafts: owners.high [$ac_owners] lost the code owner review"
  if grep -qF 'one decider' <<<"$out"; then miss "machine drafts: owners.high [$ac_owners] is told it has one decider"; fi
done

# 53e. the upgrade: a team repository that never edited its settings loses exactly the two edit
#      walls; one that edited next to them gets conflict markers and keeps its line; a starter
#      repository keeps both. 0.0.1 stands for the release before this one (its settings template,
#      tests/fixtures/autonomy-change/pre), 0.0.2 for this one.
ac_release() { # <dir> <version> [pre]
  mkdir -p "$(dirname "$1")"; cp -R "$ROOT/plugins/repo-setup" "$1"
  find "$1" -name __pycache__ -prune -exec rm -rf {} +
  subst "s/\"version\": \"[^\"]*\"/\"version\": \"$2\"/" "$1/.claude-plugin/plugin.json"
  if [ "${3:-}" = pre ]; then cp -R "$ROOT/tests/fixtures/autonomy-change/pre/." "$1/"; fi
}
ac_old="$TMP/ac-arch/repo-setup-v0.0.1"; ac_release "$ac_old" 0.0.1 pre
ac_new="$TMP/ac-arch/repo-setup-v0.0.2"; ac_release "$ac_new" 0.0.2
ac_up() { # <repo> <apply arguments of the first install...>: install with 0.0.1; <repo>.json, .rc after the upgrade
  local repo="$1" rc=0; shift
  mkdir -p "$repo"; git -C "$repo" init -q -b main
  python3 "$ac_old/scripts/apply.py" --target "$repo" "$@" --var project_name=U --var description=x --var owner=acme >/dev/null
  cp "$repo/.claude/settings.json" "$repo.before"
  [ -z "${AC_EDIT:-}" ] || subst 's|^      "Edit(./governance/\*\*)"$|      "Edit(./governance/**)",\n      "Edit(./infra/**)"|' "$repo/.claude/settings.json"
  python3 "$ac_new/scripts/apply.py" --target "$repo" --json --base-from "$TMP/ac-arch" > "$repo.json" 2> "$repo.err" || rc=$?
  echo "$rc" > "$repo.rc"
}
ac_group() { python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
print(next((g for g, v in d.items() if isinstance(v, list) and '.claude/settings.json' in v), 'none'))" "$1.json" 2>/dev/null || echo unreadable; }
ac_u="$TMP/ac-up-team"; ac_up "$ac_u" --preset python --level team
[ "$(ac_group "$ac_u")" = updated ] || miss "machine drafts: an untouched team settings.json is '$(ac_group "$ac_u")' on upgrade, want updated ($(head -c 300 "$ac_u.err"))"
[ "$(cat "$ac_u.rc")" = 0 ] || miss "machine drafts: the upgrade of an untouched team repository ends with $(cat "$ac_u.rc")"
python3 - "$ac_u.before" "$ac_u/.claude/settings.json" <<'PY' || miss "machine drafts: the upgrade changed more than the two edit walls of an untouched team settings.json"
import sys
before, after = (open(f, encoding="utf-8").read() for f in sys.argv[1:])
walls = ',\n      "Edit(./.github/workflows/**)",\n      "Edit(./governance/**)"\n'
assert before.count(walls) == 1, "the 0.0.1 file has no walls to lose"
assert before.replace(walls, "\n") == after, after
PY
AC_EDIT=1 ac_up "$TMP/ac-up-edited" --preset python --level team
[ "$(ac_group "$TMP/ac-up-edited")" = marked ] || miss "machine drafts: a team settings.json edited next to the walls is '$(ac_group "$TMP/ac-up-edited")' on upgrade, want marked"
[ "$(cat "$TMP/ac-up-edited.rc")" = 1 ] || miss "machine drafts: a marked settings.json does not end the upgrade with exit code 1 ($(cat "$TMP/ac-up-edited.rc"))"
grep -q '^<<<<<<<' "$TMP/ac-up-edited/.claude/settings.json" || miss "machine drafts: the edited settings.json has no conflict markers"
grep -qF '"Edit(./infra/**)"' "$TMP/ac-up-edited/.claude/settings.json" || miss "machine drafts: the upgrade lost the repository's own deny line"
ac_up "$TMP/ac-up-starter" --preset python
cmp -s "$TMP/ac-up-starter.before" "$TMP/ac-up-starter/.claude/settings.json" || miss "machine drafts: the upgrade changed a starter settings.json: $(diff "$TMP/ac-up-starter.before" "$TMP/ac-up-starter/.claude/settings.json" | head -4)"

# 53f. what a one-owner repository then keeps by word is written down: the principles (Chỗ còn hở),
#      the changelog, the GitHub skill; the rows of rules 1 and 3 name these tests
out=$(python3 - "$ROOT" <<'PY' 2>&1
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
bad = []
page = (root / "docs/setup-principles.md").read_text(encoding="utf-8")
gaps = page.split("## Chỗ còn hở", 1)[-1].split("\n## ", 1)[0]
one = next((b for b in gaps.split("\n- ") if b.startswith("**Repo một chủ.**")), "")
for said in ("owners.high", "giữ bằng lời", "2026-11-22", "github-agents"):
    if said not in one:
        bad.append(f"docs/setup-principles.md, «Repo một chủ»: does not say {said}")
table = page.split("## Luật nằm ở đâu trong mã", 1)[-1].split("\n## ", 1)[0]
rows = dict(re.findall(r"(?m)^\| (\d+) \| (.*)$", table))
if "53d" not in rows.get("1", ""):
    bad.append("the row of rule 1 does not name 53d")
if "53a" not in rows.get("3", ""):
    bad.append("the row of rule 3 does not name 53a")
log = (root / "CHANGELOG.md").read_text(encoding="utf-8").split("## Unreleased", 1)[-1].split("\n## ", 1)[0]
entry = next((e for e in log.split("\n### ") if "the machine drafts a change to the rules" in e), "")
if not entry:
    bad.append("CHANGELOG.md has no entry for part 5.3 under ## Unreleased")
for said in ("**What breaks on upgrade**", "Edit(./governance/**)", "one account", "kept by word"):
    if entry and said not in entry:
        bad.append(f"the CHANGELOG entry does not say {said}")
skill = (root / "plugins/repo-setup/skills/github/SKILL.md").read_text(encoding="utf-8")
if "one decider" not in skill:
    bad.append("skills/github/SKILL.md does not say what a one-owner repository gets")
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
) || miss "machine drafts: the pages: $out"

# 53g. findings of the review of the whole branch, each pinned
# (1) the skill drafts in a worktree of its own: a refusal leaves the user's branch and tree as
#     they were, and so does a pull request. The flow below is the one the skill writes.
ac_flow="$TMP/ac-flow"; rm -rf "$ac_flow" "$ac_flow.remote"; ac_install "$ac_flow" --preset python --level team
git -C "$ac_flow" add -A && git -C "$ac_flow" -c user.name=t -c user.email=t@example.com commit -qm init
git clone -q --bare "$ac_flow" "$ac_flow.remote" && git -C "$ac_flow" remote add origin "$ac_flow.remote"
git -C "$ac_flow" fetch -q origin && git -C "$ac_flow" remote set-head origin --auto >/dev/null
git -C "$ac_flow" switch -q -c feat/work; echo 'X = 1' > "$ac_flow/work.py"   # the user's own work, not committed
out=$(cd "$ac_flow" && bash -e -c '
  wt="${TMPDIR:-/tmp}/autonomy-ac-test"; rm -rf "$wt"
  git worktree add -q "$wt" -b autonomy/ac-test origin/HEAD
  cd "$wt"
  sed "s/^default: medium$/default: low/" governance/autonomy.yaml > a.tmp && mv a.tmp governance/autonomy.yaml
  make -s codeowners >/dev/null
  if make -s governance >/dev/null 2>&1; then echo "accepted"; fi
  cd - >/dev/null
  git worktree remove --force "$wt"
  git branch -D autonomy/ac-test >/dev/null' 2>&1) || miss "machine drafts: the refusal path of the skill fails: $out"
[ "$out" = "" ] || miss "machine drafts: the refusal path of the skill: $out"
[ "$(git -C "$ac_flow" branch --show-current)" = feat/work ] || miss "machine drafts: the refusal path left the user on another branch"
[ "$(git -C "$ac_flow" status --porcelain)" = "?? work.py" ] || miss "machine drafts: the refusal path changed the user's tree: $(git -C "$ac_flow" status --porcelain | tr '\n' ' ')"
if git -C "$ac_flow" rev-parse -q --verify autonomy/ac-test >/dev/null; then miss "machine drafts: the refusal path left its branch"; fi
out=$(python3 - "$ac_t/$ac_skill" <<'PY' 2>&1
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
flat = " ".join(text.split())
bad = []
for said in ('git worktree add', 'git worktree remove --force', 'git branch -D autonomy/'):
    if said not in text:
        bad.append(f"the skill does not say {said}")
if "git switch -" in text:
    bad.append("the skill switches the user's own checkout")
# (4) a change of owners.high changes GitHub too: one decider or several, and the production approver
gh_bullet = next((b for b in (" ".join(b.split()) for b in text.split("\n- ")) if "changes GitHub too" in b), "")
if "owners.high" not in gh_bullet:
    bad.append("the skill does not say that owners.high changes GitHub")
# (5) a new decider may be both lists of owners: not "one key" when the words mean two
if "One request is one key." in flat:
    bad.append("the skill says one request is one key, and its own example is two")
print("\n".join(bad)); sys.exit(1 if bad else 0)
PY
) || miss "machine drafts: the skill: $out"
# (2) nothing generated still says a person must make a change to the rules, or that the agent may not
out=$(python3 - "$ac_t" "$ROOT/plugins/repo-setup/skills/new/references/layers/governance.md" <<'PY' 2>&1
import pathlib, sys
root = pathlib.Path(sys.argv[1])
files = [root / "AGENTS.md", *sorted((root / ".github/workflows").glob("agent-*.yml")), pathlib.Path(sys.argv[2])]
stale = (
    "left to a person",
    "is blocked for agents",
    "a person edits \x60governance/",  # \x60, a backtick, as above
    "post the spec, add spec:needs-approval, and implement the part that does not",
    "or the spec needs a change to the rules",
    "If the fix needs a high-tier change or a human decision, open an issue",
)
bad = [f"{f.name}: {s}" for f in files for s in stale if s in " ".join(f.read_text(encoding="utf-8").split())]
print("\n".join(bad)); sys.exit(1 if bad else 0)
PY
) || miss "machine drafts: generated text still keeps the rules from the machine: $out"
# (3) one decider: what is then kept by word is said whole, the merge of medium and the agents on GitHub
grep -qF 'medium' <<<"$(cd "$ac_t" && python3 -B -c 'import sys; sys.path.insert(0, "tools"); import github_setup as g; print(g.ONE_DECIDER_HELP)')" \
  || miss "machine drafts: the one-decider note does not say that medium loses its review too"
out=$(python3 - "$ROOT" <<'PY' 2>&1
import pathlib, sys
root = pathlib.Path(sys.argv[1])
gaps = (root / "docs/setup-principles.md").read_text(encoding="utf-8").split("## Chỗ còn hở", 1)[-1]
one = next((b for b in gaps.split("\n- ") if b.startswith("**Repo một chủ.**")), "")
log = (root / "CHANGELOG.md").read_text(encoding="utf-8").split("## Unreleased", 1)[-1].split("\n## ", 1)[0]
entry = next((e for e in log.split("\n### ") if "the machine drafts a change to the rules" in e), "")
bad = []
for where, text, words in (("«Repo một chủ»", one, ("medium", "claude[bot]")), ("the CHANGELOG entry", entry, ("medium", "claude[bot]"))):
    bad += [f"{where} does not say {w}" for w in words if w not in text]
print("\n".join(bad)); sys.exit(1 if bad else 0)
PY
) || miss "machine drafts: what one decider keeps by word: $out"

echo "ok  the machine drafts, a person decides (or misses reported above)"

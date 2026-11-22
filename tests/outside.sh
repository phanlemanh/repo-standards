# 52. work outside the repository (docs/superpowers/specs/2026-11-22-outside-work-and-autonomy-card-design.md, 5.1):
#     the ledger of that work, the tool that checks and applies it, and the keys only a person
#     enters. Sourced by tests/run.sh; uses its ROOT, S, TMP and miss.

ob_tools="$ROOT/plugins/repo-setup/presets/_core/team/tools"
ob_py() { python3 - "$ob_tools" "$@"; } # stdin: the program; argv[1]: the tools folder

# 52a. the ledger: what a recipe and a row must have; a bad row is refused alone
out=$(ob_py <<'PY' 2>&1 || true
import sys; sys.path.insert(0, sys.argv[1])
import outside_ledger as L
R = L.parse_recipes('''
[recipe.var]
where = "github"
kind = "setting"
check = ["probe", "{name}"]
expect_line = "{name}={value}"
apply = ["setter", "{name}", "{value}"]
[recipe.key]
where = "github"
kind = "secret"
check = ["keys"]
expect_line = "{name}"
store = ["keeper", "{name}"]
[recipe.key2]
where = "elsewhere"
kind = "secret"
check = ["keys2"]
expect_line = "{name}"
store = ["keeper2", "{name}"]
''')
items, refused = L.parse_items('''
[[item]]
recipe = "var"
name = "APP_URL"
env = "staging"
value = "https://x/{y} z"
[[item]]
recipe = "key"
name = "TOKEN"
source = "generated"
[[item]]
recipe = "var"
name = "NO_VALUE"
[[item]]
recipe = "ghost"
name = "X"
[[item]]
decision = "approve-production"
when = "each deploy to production"
[[item]]
action = "install-app"
how = "https://github.com/apps/claude"
[[item]]
recipe = ["key", "key2"]
name = "TWIN"
[[item]]
recipe = ["var", "key"]
name = "MIXED"
value = "1"
[[item]]
recipe = "key"
name = "TOKEN"
[[item]]
recipe = "key"
name = "ODD"
source = "wish"
''', R)
ids = [i.id for i in items]
want = ["var:APP_URL@staging", "key:TOKEN", "decision:approve-production", "action:install-app", "key:TWIN"]
assert ids == want, ids
assert [i.kind for i in items] == ["setting", "secret", "decision", "action", "secret"], [i.kind for i in items]
assert items[4].recipes == ("key", "key2") and items[1].source == "generated" and items[4].source == "person"
assert len(refused) == 5, refused
for line, word in zip(refused, ("NO_VALUE", "ghost", "MIXED", "TOKEN", "ODD")):
    assert word in line, (word, line)
# a value is put in once, whole, and never read again for placeholders
assert L.render(R["var"].apply, items[0].fields) == ["setter", "APP_URL", "https://x/{y} z"]
assert L.render(["a{name}b", "{name}{name}"], {"name": "{value}", "value": "no"}) == ["a{value}b", "{value}{value}"]
try:
    L.render(["{nope}"], {"name": "x"}); raise SystemExit("render accepted a placeholder without a key")
except L.LedgerError:
    pass
for bad, word in (
    ('[recipe.a]\nwhere="g"\nkind="secret"\ncheck=["c"]', "store"),
    ('[recipe.a]\nwhere="g"\nkind="secret"\ncheck=["c"]\nstore=["s"]\napply=["a"]', "apply"),
    ('[recipe.a]\nwhere="g"\nkind="setting"', "check"),
    ('[recipe.a]\nwhere="g"\nkind="action"', "check"),
    ('[recipe.a]\nwhere="g"\nkind="decision"\ncheck=["c"]', "decision"),
    ('[recipe.a]\nwhere="g"\nkind="wish"\ncheck=["c"]', "kind"),
    ('[recipe.a]\nwhere="g"\nkind="setting"\ncheck="probe x"', "list"),
    ('[recipe.a\n', "TOML"),
):
    try:
        L.parse_recipes(bad); raise SystemExit(f"accepted: {bad!r}")
    except L.LedgerError as e:
        assert word in str(e), (word, str(e))
assert L.parse_recipes("") == {} and L.parse_items("", {}) == ([], [])
print("ok")
PY
)
[ "$out" = ok ] || miss "outside: the ledger does not hold: $(tail -3 <<<"$out")"

# Stand-ins for the commands a recipe names. Each logs its arguments; none reaches a network.
#   probe NAME    prints the line NAME=<value> of $OB_STATE; exits 3 for BROKEN, 1 for DRIFT,
#                 and does not answer in time for SLOW
#   setter N V    writes N=V to $OB_STATE
#   keys, keys2   print the names in $OB_KEYS and $OB_KEYS.2
#   keeper NAME   stores standard input as $OB_STDIN.NAME and adds NAME to $OB_KEYS (keeper2: the
#                 same with .2); the one named by $OB_FAIL_STORE exits 1 and stores nothing
ob_bin="$TMP/ob-bin"; mkdir -p "$ob_bin"
export OB_LOG="$TMP/ob.log" OB_STATE="$TMP/ob-state" OB_KEYS="$TMP/ob-keys" OB_STDIN="$TMP/ob-stdin"
ob_reset() { : > "$OB_LOG"; echo "PRESENT=1" > "$OB_STATE"; : > "$OB_KEYS"; : > "$OB_KEYS.2"; rm -f "$OB_STDIN".*; }
cat > "$ob_bin/probe" <<'SH'
#!/bin/sh
echo "probe $*" >> "$OB_LOG"
case "$1" in BROKEN) exit 3 ;; DRIFT) exit 1 ;; SLOW) sleep 5 ;; esac
grep "^$1=" "$OB_STATE" || true
SH
cat > "$ob_bin/otherprobe" <<'SH'
#!/bin/sh
echo "otherprobe $*" >> "$OB_LOG"
SH
cat > "$ob_bin/setter" <<'SH'
#!/bin/sh
echo "setter $*" >> "$OB_LOG"
echo "$1=$2" >> "$OB_STATE"
SH
for ob_n in "" 2; do
  cat > "$ob_bin/keys$ob_n" <<SH
#!/bin/sh
echo "keys$ob_n \$*" >> "\$OB_LOG"
cat "\$OB_KEYS${ob_n:+.2}"
SH
  cat > "$ob_bin/keeper$ob_n" <<SH
#!/bin/sh
echo "keeper$ob_n \$*" >> "\$OB_LOG"
[ "\${OB_FAIL_STORE:-}" = "keeper$ob_n" ] && exit 1
cat > "\$OB_STDIN.\$1${ob_n:+.2}"
echo "\$1" >> "\$OB_KEYS${ob_n:+.2}"
SH
done
chmod +x "$ob_bin"/*

ob_recipes='[recipe.var]
where = "github"
kind = "setting"
check = ["probe", "{name}"]
expect_line = "{name}={value}"
apply = ["setter", "{name}", "{value}"]

[recipe.key]
where = "vault-a"
kind = "secret"
check = ["keys"]
expect_line = "{name}"
store = ["keeper", "{name}"]

[recipe.key2]
where = "vault-b"
kind = "secret"
check = ["keys2"]
expect_line = "{name}"
store = ["keeper2", "{name}"]

[recipe.watch]
where = "github"
kind = "setting"
check = ["probe", "{name}"]
missing_exit = 1'
ob_row() { printf '[[item]]\nrecipe = "%s"\nname = "%s"\n%s\n' "$1" "$2" "${3:-}"; }
ob_tail='[[item]]
action = "install-app"
how = "https://example.test/app"

[[item]]
decision = "approve-production"
when = "each deploy to production"'
ob_rows="$(ob_row var PRESENT 'value = "1"')
$(ob_row var ABSENT 'value = "2"')
$(ob_row var BROKEN 'value = "3"')
$(ob_row var SLOW 'value = "4"')
$(ob_row key GENERATED 'source = "generated"')
$(ob_row key PERSON 'how = "create it at the vault"')
$(ob_row watch DRIFT 'how = "run the setup tool"')
$ob_tail"

# a repository with the tool and a ledger; with a fourth word, the ledger is also on a remote
# whose default branch has that name
ob_repo() { # <name> <recipes> <rows> [remote branch]
  local d="$TMP/ob-$1" branch="${4:-main}"
  mkdir -p "$d/governance" "$d/ops" "$d/tools" "$d/src"
  git -C "$d" init -q -b "$branch"
  git -C "$d" config user.name t && git -C "$d" config user.email t@example.com
  cp "$ob_tools/outside.py" "$ob_tools/outside_ledger.py" "$d/tools/" 2>/dev/null || true
  [ -z "$2" ] || printf '%s\n' "$2" > "$d/governance/outside.toml"
  printf '%s\n' "$3" > "$d/ops/outside.toml"; : > "$d/src/keep"
  git -C "$d" add -A && git -C "$d" -c core.hooksPath=/dev/null commit -q -m base
  if [ -n "${4:-}" ]; then
    git init -q --bare -b "$branch" "$d.git"
    git -C "$d" remote add origin "$d.git" && git -C "$d" push -q origin "$branch"
    git -C "$d" remote set-head origin "$branch"
  fi
  printf '%s' "$d"
}
ob_put() { mkdir -p "$(dirname "$1/$2")" && printf '%s\n' "$3" > "$1/$2"; }
# the tool of the repository a folder is in, run from that folder
ob_run() { # <dir> <arguments...>
  local d="$1"; shift
  ( cd "$d" && PATH="$ob_bin:$PATH" OUTSIDE_TIMEOUT=1 python3 "$(git rev-parse --show-toplevel)/tools/outside.py" "$@" )
}
ob_status() { local d="$1"; shift; ob_run "$d" status "$@"; }
ob_field() { python3 -c 'import json,sys; print(" ".join(e["id"] for e in json.load(sys.stdin)[sys.argv[1]]))' "$1"; }
ob_ids() { ob_field "$1" <<<"$j" 2>/dev/null || echo "(no json)"; }

# 52b. status: three lists; what cannot be checked is unknown, never in place
ob_reset
ob_a=$(ob_repo a "$ob_recipes" "$ob_rows" trunk)
rc=0; j=$(ob_status "$ob_a" --json 2>/dev/null) || rc=$?
[ "$rc" = 1 ] || miss "outside: status with work left does not exit 1 ($rc)"
[ "$(ob_ids ok)" = "var:PRESENT" ] || miss "outside: in place is not exactly the row whose check matches: $(ob_ids ok)"
[ "$(ob_ids apply)" = "var:ABSENT key:GENERATED" ] || miss "outside: the machine's list is wrong: $(ob_ids apply)"
[ "$(ob_ids yours)" = "key:PERSON watch:DRIFT action:install-app" ] || miss "outside: the person's list is wrong: $(ob_ids yours)"
[ "$(ob_ids decisions)" = "decision:approve-production" ] || miss "outside: a decision is not listed as one: $(ob_ids decisions)"
[ "$(ob_ids unknown)" = "var:BROKEN var:SLOW" ] || miss "outside: a check that fails or hangs is not unknown: $(ob_ids unknown)"
[ "$(ob_ids refused)$(ob_ids unmerged)" = "" ] || miss "outside: refused or unmerged rows where there are none"
python3 -c 'import json,sys; d=json.load(sys.stdin); assert sorted(d) == sorted("base ok apply yours decisions unknown unmerged refused card".split()), sorted(d); assert d["base"] == "origin/trunk", d["base"]; assert all(sorted(e) == ["how","id","kind","value","where","why"] for k in d if k not in ("base", "card") for e in d[k])' <<<"$j" 2>/dev/null \
  || miss "outside: status --json does not have exactly the agreed keys, or the base is not origin/trunk"
ob_text=$(ob_status "$ob_a" 2>/dev/null || true)
for title in 'In place (1)' 'The machine will apply (2)' 'Yours (3)' 'Unknown (2)'; do
  grep -qF "$title" <<<"$ob_text" || miss "outside: status does not print the heading '$title'"
done
ob_out=$(grep -A3 'key:PERSON' <<<"$ob_text" || true); grep -q 'create it at the vault' <<<"$ob_out" && grep -q 'why: ' <<<"$ob_out" \
  || miss "outside: a row of the person's list does not say how and why"
grep -q 'no answer in' <<<"$ob_text" || miss "outside: a check that hangs does not say so"
# nothing left: exit 0; an action nobody can check is done when a person recorded it, and says so
ob_done=$(ob_repo done "$ob_recipes" "$(ob_row var PRESENT 'value = "1"')
[[item]]
action = \"install-app\"
done = \"2026-11-22\"

[[item]]
decision = \"approve-production\"" trunk)
rc=0; j=$(ob_status "$ob_done" --json 2>/dev/null) || rc=$?
[ "$rc" = 0 ] || miss "outside: status with nothing left does not exit 0 ($rc)"
[ "$(ob_ids ok)" = "var:PRESENT action:install-app" ] || miss "outside: an action a person recorded as done is not in place: $(ob_ids ok)"
python3 -c 'import json,sys; e=[e for e in json.load(sys.stdin)["ok"] if e["kind"] == "action"][0]; assert "not checked" in e["why"], e' <<<"$j" 2>/dev/null \
  || miss "outside: an action recorded by hand does not say it was not checked"

# 52e. both files come from the default branch of the remote, whatever its name and the folder
ob_put "$ob_a" ops/outside.toml "$ob_rows
$(ob_row var LOCAL_ONLY 'value = "9"')"
ob_reset; j=$(ob_status "$ob_a/src" --json 2>/dev/null || true)
[ "$(ob_ids unmerged)" = "var:LOCAL_ONLY" ] || miss "outside: a row that is not merged is not listed apart: $(ob_ids unmerged)"
[ "$(ob_ids ok)" = "var:PRESENT" ] || miss "outside: run from a subfolder, status does not read the same ledger"
if grep -q LOCAL_ONLY "$OB_LOG"; then miss "outside: the check of an unmerged row ran"; fi
: > "$OB_LOG"; ob_out=$(ob_status "$ob_a" --draft 2>/dev/null || true); grep -q '^probe LOCAL_ONLY$' <<<"$ob_out" || miss "outside: --draft does not print the command of the working tree"
[ ! -s "$OB_LOG" ] || miss "outside: --draft ran a command"
[ "$(ob_status "$ob_a" --draft --json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["all"][-1], d["commands"][0])' 2>/dev/null)" = "var:LOCAL_ONLY ['probe', 'PRESENT']" ] \
  || miss "outside: --draft --json does not give the ids and the commands of the working tree"
ob_put "$ob_a" governance/outside.toml "${ob_recipes//\"probe\"/\"otherprobe\"}"
: > "$OB_LOG"; ob_status "$ob_a" >/dev/null 2>&1 || true
if grep -q '^otherprobe' "$OB_LOG"; then miss "outside: a recipe that is not merged ran"; fi
git -C "$ob_a" checkout -q -- .
# a remote whose default branch nobody recorded locally (a repository pushed, never cloned)
ob_nohead=$(ob_repo nohead "$ob_recipes" "$(ob_row var PRESENT 'value = "1"')" trunk)
git -C "$ob_nohead" remote set-head origin --delete
[ "$(ob_status "$ob_nohead" --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["base"])' 2>/dev/null)" = "origin/trunk" ] \
  || miss "outside: the default branch is not asked of the remote when it is not recorded locally"
ob_noremote=$(ob_repo noremote "$ob_recipes" "$(ob_row var PRESENT 'value = "1"')")
ob_out=$(ob_status "$ob_noremote" 2>&1 || true); grep -q 'no default branch on a remote: reading the working tree' <<<"$ob_out" || miss "outside: a repository without a remote does not say what it reads"
ob_plain=$(ob_repo plain "" "")
rc=0; ob_status "$ob_plain" >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] || miss "outside: a repository without the recipes file does not exit 2 ($rc)"
ob_badtoml=$(ob_repo badtoml "[recipe.a" "")
rc=0; ob_status "$ob_badtoml" >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] || miss "outside: a recipes file that is not TOML does not exit 2 ($rc)"

# A terminal for the tool: runs a command under a pseudo-terminal and types the given lines, one
# per prompt. "^C" as a line sends an interrupt. Exit code: the command's.
ob_tty() { # <line>[<TAB><line>...] -- <command...>
  local typed="$1"; shift; [ "$1" = "--" ] && shift
  python3 - "$typed" "$@" <<'PY'
import os, pty, sys, time
typed, argv = sys.argv[1].split("\t"), sys.argv[2:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(argv[0], argv)
out, seen, answers = b"", b"", list(typed)
while True:
    try:
        chunk = os.read(fd, 1024)
    except OSError:
        break
    if not chunk:
        break
    out += chunk
    seen += chunk
    if answers and out.rstrip().endswith(b":"):
        line = answers.pop(0)
        os.write(fd, b"\x03" if line == "^C" else line.encode() + b"\r")
        out = b""
sys.stdout.buffer.write(seen)
_, status = os.waitpid(pid, 0)
sys.exit(os.waitstatus_to_exitcode(status))
PY
}
# the command line of a tool run under ob_tty, from the folder of a repository
ob_tool() { printf 'cd %q && PATH=%q OUTSIDE_TIMEOUT=1 exec python3 tools/outside.py %s' "$1" "$ob_bin:$PATH" "$2"; }

# 52c. apply: settings that are missing and generated keys, nothing of the person's
ob_put "$ob_a" ops/outside.toml "$ob_rows
$(ob_row var LOCAL_ONLY 'value = "9"')"
ob_reset
rc=0; ob_run "$ob_a" apply >"$TMP/ob-apply.out" 2>&1 || rc=$?
grep -q '^setter ABSENT 2$' "$OB_LOG" || miss "outside: apply did not apply the missing setting"
if grep -q '^setter PRESENT' "$OB_LOG"; then miss "outside: apply applied a setting that is in place"; fi
if grep -q '^setter LOCAL_ONLY' "$OB_LOG"; then miss "outside: apply applied a row that is not merged"; fi
grep -q '^keeper GENERATED$' "$OB_LOG" && [ "$(wc -c < "$OB_STDIN.GENERATED" 2>/dev/null || echo 0)" -ge 32 ] || miss "outside: apply did not generate and store the key"
if grep -q '^keeper PERSON' "$OB_LOG"; then miss "outside: apply stored a key only a person may enter"; fi
ob_value=$(cat "$OB_STDIN.GENERATED" 2>/dev/null || echo "(none)")
if grep -qF -- "$ob_value" "$OB_LOG" "$TMP/ob-apply.out"; then miss "outside: a generated value is in the arguments or the output"; fi
[ "$rc" = 0 ] || miss "outside: apply where every command worked does not exit 0 ($rc)"
grep -q 'Yours (3)' "$TMP/ob-apply.out" || miss "outside: apply does not print the lists again"
git -C "$ob_a" checkout -q -- .
# a second run has nothing of the machine's left
: > "$OB_LOG"; ob_run "$ob_a" apply >/dev/null 2>&1 || true
if grep -qE '^(setter|keeper) ' "$OB_LOG"; then miss "outside: a second apply ran a command: $(grep -E '^(setter|keeper) ' "$OB_LOG" | head -2)"; fi
# a key stored in two places, the second fails: say where it is, exit 1, never generate again
ob_twin=$(ob_repo twin "$ob_recipes" '[[item]]
recipe = ["key", "key2"]
name = "TWIN"
source = "generated"' trunk)
ob_reset; rc=0; OB_FAIL_STORE=keeper2 ob_run "$ob_twin" apply >"$TMP/ob-twin.out" 2>&1 || rc=$?
[ "$rc" = 1 ] || miss "outside: a store that fails does not exit 1 ($rc)"
grep -q 'vault-a' "$TMP/ob-twin.out" || miss "outside: apply does not say where the key already is"
: > "$OB_LOG"; ob_run "$ob_twin" apply >/dev/null 2>&1 || true
if grep -q '^keeper' "$OB_LOG"; then miss "outside: a key present in one place was generated again"; fi
j=$(ob_status "$ob_twin" --json 2>/dev/null || true)
[ "$(ob_ids yours)" = "key:TWIN" ] || miss "outside: a partial key is not the person's to decide: $(ob_ids yours)"
# a setting whose apply fails: exit 1, the list says it is still to do
ob_broken=$(ob_repo broken '[recipe.var]
where = "github"
kind = "setting"
check = ["probe", "{name}"]
expect_line = "{name}={value}"
apply = ["no-such-command-xyz", "{name}"]' "$(ob_row var ABSENT 'value = "2"')" trunk)
ob_reset; rc=0; ob_run "$ob_broken" apply >"$TMP/ob-broken.out" 2>&1 || rc=$?
[ "$rc" = 1 ] && grep -q 'no-such-command-xyz' "$TMP/ob-broken.out" || miss "outside: an apply that cannot run does not exit 1 and say so ($rc)"

# 52d. secrets: a terminal of the person's own, and the value goes nowhere but the store's stdin
ob_reset; rc=0; ob_run "$ob_a" secrets </dev/null >"$TMP/ob-notty.out" 2>&1 || rc=$?
[ "$rc" = 2 ] && grep -q 'run this in a terminal of your own' "$TMP/ob-notty.out" || miss "outside: secrets ran without a terminal ($rc)"
if grep -q '^keeper' "$OB_LOG"; then miss "outside: secrets stored something without a terminal"; fi
ob_reset; rc=0; ob_tty 's3cr3t-VALUE' -- sh -c "$(ob_tool "$ob_a" secrets)" >"$TMP/ob-tty.out" 2>&1 || rc=$?
[ "$(cat "$OB_STDIN.PERSON" 2>/dev/null)" = "s3cr3t-VALUE" ] || miss "outside: the entered value did not reach the store ($rc)"
grep -q 'create it at the vault' "$TMP/ob-tty.out" || miss "outside: secrets does not say how to create the key before asking"
if grep -qF 's3cr3t-VALUE' "$OB_LOG" "$TMP/ob-tty.out"; then miss "outside: the entered value is in the arguments or the output"; fi
if grep -q '^keeper GENERATED' "$OB_LOG"; then miss "outside: secrets asked for or stored a key the machine generates"; fi
ob_b=$(ob_repo b "$ob_recipes" "$(ob_row key PERSON2 'how = "make one"')" trunk)
ob_reset; rc=0; ob_tty '' -- sh -c "$(ob_tool "$ob_b" secrets)" >/dev/null 2>&1 || rc=$?
[ "$rc" = 1 ] && [ ! -e "$OB_STDIN.PERSON2" ] || miss "outside: an empty answer stored something or did not exit 1 ($rc)"
ob_reset; rc=0; ob_tty '^C' -- sh -c "$(ob_tool "$ob_b" secrets)" >/dev/null 2>&1 || rc=$?
[ "$rc" != 0 ] && [ ! -e "$OB_STDIN.PERSON2" ] || miss "outside: Ctrl-C at the prompt stored something or exited 0 ($rc)"

# 52g. github_setup --check: says whether a run would change anything, and writes nothing.
# A stand-in gh keeps the state of one repository, acme/sample, in $OB_GH: what --apply writes
# is what --check reads back. Every write is logged to $OB_LOG.
ob_ghbin="$TMP/ob-ghbin"; mkdir -p "$ob_ghbin"
cat > "$ob_ghbin/gh" <<'PY'
#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
state = Path(os.environ["OB_GH"]); state.mkdir(exist_ok=True)
argv = sys.argv[1:]
def load(name, default):
    f = state / name
    return json.loads(f.read_text()) if f.exists() else default
def save(name, value):
    (state / name).write_text(json.dumps(value))
def fail(text, code=1):
    print(text, file=sys.stderr); sys.exit(code)
if argv[:2] == ["repo", "view"]:
    print(json.dumps({"nameWithOwner": "acme/sample", "defaultBranchRef": {"name": "main"}})); sys.exit(0)
if argv[:1] in (["secret"], ["label"]):
    sys.exit(0)
if argv[:1] != ["api"]:
    fail("unknown call")
method, jq, pairs, path, rest = "GET", None, {}, None, argv[1:]
i = 0
while i < len(rest):
    a = rest[i]
    if a == "-X": method = rest[i + 1]; i += 2; continue
    if a == "-H": i += 2; continue
    if a == "--jq": jq = rest[i + 1]; i += 2; continue
    if a in ("-F", "-f"):
        k, v = rest[i + 1].split("=", 1); pairs[k] = {"true": True, "false": False}.get(v, v); i += 2; continue
    if a in ("--paginate",): i += 1; continue
    if a == "--input": i += 2; continue
    path = path or a; i += 1
body = json.loads(sys.stdin.read() or "null") if "--input" in rest else None
if method != "GET":
    with open(os.environ["OB_LOG"], "a") as log:
        log.write(f"gh {method} {path}\n")
base = "repos/acme/sample"
if "/rulesets" in path and (state / "down-rulesets").exists():
    fail("gh: Server Error (HTTP 502)")
if path.startswith(base + "/contents/"):
    f = Path(os.environ["OB_GH_FILES"]) / path[len(base + "/contents/"):].split("?")[0]
    print(f.read_text()) if f.is_file() else fail("gh: Not Found (HTTP 404)")
elif path == "users/acme":
    print(7)
elif path == base:
    if method == "PATCH": save("repo.json", {**load("repo.json", {}), **pairs})
    else: print(json.dumps(load("repo.json", {})))
elif path == base + "/actions/permissions/workflow":
    if method == "PUT": save("workflow.json", pairs)
    else: print(json.dumps(load("workflow.json", {})))
elif path.startswith(base + "/environments/"):
    name = path.rsplit("/", 1)[1]
    envs = load("envs.json", {})
    if method == "PUT":
        rules = [{"type": "required_reviewers", "reviewers": [{"type": r["type"], "reviewer": {"id": r["id"]}} for r in body["reviewers"]]}] if body else []
        envs[name] = {"name": name, "protection_rules": rules}; save("envs.json", envs)
    elif name in envs: print(json.dumps(envs[name]))
    else: fail("gh: Not Found (HTTP 404)")
elif path == base + "/rulesets":
    if method == "POST": save("ruleset.json", {**body, "id": 41})
    elif "ruleset.json" in os.listdir(state): print(41)
elif path == base + "/rulesets/41":
    if method == "PUT": save("ruleset.json", {**body, "id": 41})
    elif jq and "required_status_checks" in jq:
        rs = load("ruleset.json", {"rules": []})
        for rule in rs["rules"]:
            if rule["type"] == "required_status_checks":
                for c in rule["parameters"]["required_status_checks"]: print(c["context"])
    else: print(json.dumps(load("ruleset.json", {})))
elif path == base + "/actions/organization-secrets":
    pass
else:
    fail(f"not known: {method} {path}")
PY
chmod +x "$ob_ghbin/gh"
ob_t="$TMP/ob-gt"; mkdir -p "$ob_t" && git -C "$ob_t" init -q -b main
python3 "$S/apply.py" --target "$ob_t" --preset python --level team --var project_name=G --var description=x --var owner=acme >/dev/null
ob_setup() { ( cd "$ob_t" && PATH="$ob_ghbin:$PATH" OB_GH="$TMP/ob-gh" OB_GH_FILES="$ob_t" python3 -B tools/github_setup.py "$@" </dev/null ) 2>&1; }
rm -rf "$TMP/ob-gh"; : > "$OB_LOG"
rc=0; ob_out=$(ob_setup --check) || rc=$?
[ "$rc" = 1 ] && grep -q '^~ ' <<<"$ob_out" || miss "outside: --check on a repository with nothing set up does not exit 1 with '~' lines ($rc)"
[ ! -s "$OB_LOG" ] || miss "outside: --check wrote to GitHub: $(head -2 "$OB_LOG")"
ob_setup --apply >/dev/null || miss "outside: the stand-in GitHub did not take an apply: $(ob_setup --apply | tail -3)"
: > "$OB_LOG"; rc=0; ob_out=$(ob_setup --check) || rc=$?
[ "$rc" = 0 ] || miss "outside: --check right after an apply does not exit 0 ($rc): $(grep -v '^= ' <<<"$ob_out" | head -3)"
if grep -q '^[~?] ' <<<"$ob_out"; then miss "outside: --check right after an apply has a line that is not '='"; fi
[ ! -s "$OB_LOG" ] || miss "outside: --check wrote to GitHub: $(head -2 "$OB_LOG")"
python3 - "$TMP/ob-gh/repo.json" <<'PY'
import json, sys; f = sys.argv[1]; d = json.load(open(f)); d["allow_merge_commit"] = True; json.dump(d, open(f, "w"))
PY
rc=0; ob_out=$(ob_setup --check) || rc=$?
[ "$rc" = 1 ] && grep -q '^~ .*merge' <<<"$ob_out" || miss "outside: --check does not see a merge setting that differs ($rc)"
ob_setup --apply >/dev/null || true
python3 - "$TMP/ob-gh/envs.json" <<'PY'
import json, sys; f = sys.argv[1]; d = json.load(open(f)); d.pop("production"); json.dump(d, open(f, "w"))
PY
rc=0; ob_out=$(ob_setup --check) || rc=$?
[ "$rc" = 1 ] && grep -q '^~ environment production' <<<"$ob_out" || miss "outside: --check does not see a missing environment ($rc)"
ob_setup --apply >/dev/null || true
python3 - "$TMP/ob-gh/ruleset.json" <<'PY'
import json, sys; f = sys.argv[1]; d = json.load(open(f))
for r in d["rules"]:
    if r["type"] == "required_status_checks": r["parameters"]["required_status_checks"].pop()
json.dump(d, open(f, "w"))
PY
rc=0; ob_out=$(ob_setup --check) || rc=$?
[ "$rc" = 1 ] && grep -q '^~ ruleset' <<<"$ob_out" || miss "outside: --check does not see a ruleset that lost a required check ($rc)"
ob_setup --apply >/dev/null || true
touch "$TMP/ob-gh/down-rulesets"
rc=0; ob_out=$(ob_setup --check) || rc=$?
[ "$rc" = 2 ] && grep -q '^? ' <<<"$ob_out" || miss "outside: --check with a state it cannot read does not exit 2 with a '?' line ($rc)"
rm -f "$TMP/ob-gh/down-rulesets"
: > "$OB_LOG"; rc=0; ob_setup --check --apply >/dev/null || rc=$?
[ "$rc" = 2 ] && [ ! -s "$OB_LOG" ] || miss "outside: --check and --apply together are accepted ($rc)"

# 52f. what the kit seeds: every row names a recipe that exists, by layer
ob_new() { # <name> <apply.py options...>: a new repository; prints its path
  local d="$TMP/ob-new-$1"; shift
  mkdir -p "$d" && git -C "$d" init -q -b main
  python3 "$S/apply.py" --target "$d" --var project_name=O --var description=x --var owner=acme "$@" >/dev/null
  printf '%s' "$d"
}
ob_seed_problems() { # <repo>: prints every refused row and recipe; exits 1 when there is one
  python3 - "$1" "$ob_tools" <<'PY'
import sys; sys.path.insert(0, sys.argv[2])
from pathlib import Path
import outside_ledger as L
root = Path(sys.argv[1])
try:
    recipes = L.parse_recipes((root / L.RECIPES_PATH).read_text(encoding="utf-8"))
    _, refused = L.parse_items((root / L.ITEMS_PATH).read_text(encoding="utf-8"), recipes)
except (OSError, L.LedgerError) as exc:
    refused = [str(exc)]
print("\n".join(refused))
sys.exit(1 if refused else 0)
PY
}
ob_seed_ids() { python3 "$1/tools/outside.py" --root "$1" status --draft --json 2>/dev/null | python3 -c 'import json,sys; print(" ".join(json.load(sys.stdin)["all"]))'; }
ob_team=$(ob_new team --preset ts-node --level team)
ob_agents=$(ob_new agents --preset ts-api --level team --with github-agents --deploy container)
ob_plugin=$(ob_new plugin --preset claude-plugin --level team)
ob_start=$(ob_new start --preset ts-node)
[ ! -e "$ob_start/tools/outside.py" ] && [ ! -e "$ob_start/ops/outside.toml" ] && [ ! -e "$ob_start/governance/outside.toml" ] \
  || miss "outside: a starter repository got the ledger"
for d in "$ob_team" "$ob_agents" "$ob_plugin"; do
  out=$(ob_seed_problems "$d") || miss "outside: the seeded ledger of ${d##*/} does not hold: $out"
done
ob_ids_team=" $(ob_seed_ids "$ob_team" || true) "
ob_ids_agents=" $(ob_seed_ids "$ob_agents" || true) "
ob_ids_plugin=" $(ob_seed_ids "$ob_plugin" || true) "
[ "$ob_ids_team" = " github-setup:repository github-secret:RELEASE_PLEASE_TOKEN " ] \
  || miss "outside: a team repository is not seeded with the setup row and the release key:$ob_ids_team"
for want in github-setup:repository github-secret:RELEASE_PLEASE_TOKEN github-secret:CLAUDE_CODE_OAUTH_TOKEN action:install-claude-github-app decision:approve-production; do
  case "$ob_ids_agents" in *" $want "*) ;; *) miss "outside: the agent and deploy layers do not seed $want:$ob_ids_agents" ;; esac
done
[ "$ob_ids_plugin" = " github-setup:repository " ] || miss "outside: a plugin repository, which has no release-please, is seeded with more than the setup row:$ob_ids_plugin"
if grep -q '^name = "DEPLOY_ENABLED"' "$ob_agents/ops/outside.toml"; then miss "outside: DEPLOY_ENABLED is seeded"; fi
grep -q '^outside:.*## ' "$ob_team/mk/outside.mk" 2>/dev/null || miss "outside: no make target with a description"
for f in tools/outside.py tools/outside_ledger.py tools/github_check.py; do
  [ -f "$ob_team/$f" ] || miss "outside: a team repository lacks $f"
done
ob_tier() { ( cd "$1" && python3 tools/autonomy.py --files "$2" | json 'd["tier"]' ); }
[ "$(ob_tier "$ob_team" governance/outside.toml || true)" = high ] || miss "outside: the recipes file is not a rule of the game"
[ "$(ob_tier "$ob_team" ops/outside.toml || echo high)" != high ] || miss "outside: a row of the ledger is a rule of the game"

# 52h. the rule, the setup stage and the pages that say it
grep -q 'python3 tools/outside.py' "$ob_team/AGENTS.md" || miss "outside: AGENTS.md of a team repository does not name the tool"
if grep -q 'tools/outside.py' "$ob_start/AGENTS.md"; then miss "outside: a starter repository is told of a tool it does not have"; fi
ob_nw="$ROOT/plugins/repo-setup/skills/new/SKILL.md"
if grep -q 'Stop and ask for anything outside the folder' "$ob_nw"; then miss "outside: the new-repository skill still stops for everything outside the folder"; fi
grep -q '^## 7. Outside the repository$' "$ob_nw" && grep -q '^## 8. Finish$' "$ob_nw" || miss "outside: the new-repository skill has no outside stage before Finish"
ob_stage=$(awk '/^## 7\. Outside the repository$/{f=1;next} /^## 8\./{f=0} f' "$ob_nw")
for want in 'tools/outside.py status' 'tools/outside.py apply' 'tools/outside.py secrets' 'references/outside.md'; do
  grep -qF "$want" <<<"$ob_stage" || miss "outside: the outside stage does not name $want"
done
[ -s "$ROOT/plugins/repo-setup/skills/new/references/outside.md" ] || miss "outside: no page on writing recipes for a platform the kit does not generate"
for s in github adopt; do
  grep -q 'tools/outside.py status' "$ROOT/plugins/repo-setup/skills/$s/SKILL.md" || miss "outside: the $s skill does not end with the status"
done
grep -q 'make outside' "$ROOT/plugins/repo-setup/skills/new/references/tour.md" || miss "outside: the tour does not point to make outside"
grep -q 'references/outside.md' "$ROOT/plugins/repo-setup/skills/new/references/layers/delivery.md" || miss "outside: the delivery layer does not point to the page on recipes"
grep -q '^11\. \*\*Việc ngoài kho: máy làm\.\*\*' "$ROOT/docs/setup-principles.md" || miss "outside: rule 11 is not on the principles page"
grep -q '^| 11 | .*| 52b, 52c, 52d, 52e |$' "$ROOT/docs/setup-principles.md" || miss "outside: rule 11 has no row naming its tests"

# 52i. findings of the review of the whole branch, each pinned
# (1) a field cannot become a flag of the command: a row is refused when a value it puts in a
#     command starts with "-" where no option takes it
out=$(ob_py <<'PY' 2>&1 || true
import sys; sys.path.insert(0, sys.argv[1])
import outside_ledger as L
R = L.parse_recipes('''
[recipe.key]
where = "github"
kind = "secret"
check = ["keys"]
expect_line = "{name}"
store = ["gh", "secret", "set", "{name}"]
[recipe.var]
where = "github"
kind = "setting"
check = ["probe", "{name}"]
apply = ["gh", "variable", "set", "{name}", "--body", "{value}"]
''')
items, refused = L.parse_items('''
[[item]]
recipe = "key"
name = "--env-file=.env"
source = "generated"
[[item]]
recipe = "var"
name = "OFFSET"
value = "-1"
[[item]]
recipe = "var"
name = "-n"
value = "1"
''', R)
assert [i.id for i in items] == ["var:OFFSET"], [i.id for i in items]
assert len(refused) == 2 and all("flag" in r for r in refused), refused
print("ok")
PY
)
[ "$out" = ok ] || miss "outside: a row can turn a field into a flag of the command: $(tail -2 <<<"$out")"

# (2) --check that cannot read GitHub, or the policy, exits 2, never 1 ("not in place")
cat > "$ob_ghbin/gh-out" <<'SH'
#!/bin/sh
echo "To get started with GitHub CLI, please run:  gh auth login" >&2; exit 4
SH
chmod +x "$ob_ghbin/gh-out"
ob_loggedout="$TMP/ob-loggedout-bin"; mkdir -p "$ob_loggedout"; cp "$ob_ghbin/gh-out" "$ob_loggedout/gh"
rc=0; ( cd "$ob_t" && PATH="$ob_loggedout:$PATH" python3 -B tools/github_setup.py --check </dev/null ) >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || miss "outside: --check when gh is not logged in does not exit 2 ($rc)"
cp "$ob_t/governance/autonomy.yaml" "$TMP/ob-policy.orig"
subst 's/^merge_method: .*/merge_method: rebase/' "$ob_t/governance/autonomy.yaml"
rc=0; ob_setup --check >/dev/null || rc=$?
[ "$rc" = 2 ] || miss "outside: --check with a policy it cannot read does not exit 2 ($rc)"
cp "$TMP/ob-policy.orig" "$ob_t/governance/autonomy.yaml"

# (3) what --check compares: the branches a ruleset covers, the reviewers of production, labels
rm -rf "$TMP/ob-gh"; ob_setup --apply >/dev/null || true
python3 - "$TMP/ob-gh/ruleset.json" <<'PY'
import json, sys; f = sys.argv[1]; d = json.load(open(f)); d["conditions"]["ref_name"]["include"] = ["refs/heads/nothing"]; json.dump(d, open(f, "w"))
PY
rc=0; ob_out=$(ob_setup --check) || rc=$?
[ "$rc" = 1 ] && grep -q '^~ ruleset' <<<"$ob_out" || miss "outside: --check does not see a ruleset that no longer covers the default branch ($rc)"
ob_setup --apply >/dev/null || true
python3 - "$TMP/ob-gh/envs.json" <<'PY'
import json, sys; f = sys.argv[1]; d = json.load(open(f))
d["production"]["protection_rules"][0]["reviewers"].append({"type": "User", "reviewer": {"id": 99}})
d["production"]["deployment_branch_policy"] = {"protected_branches": False, "custom_branch_policies": True}
json.dump(d, open(f, "w"))
PY
rc=0; ob_out=$(ob_setup --check) || rc=$?
[ "$rc" = 1 ] && grep -q '^~ environment production' <<<"$ob_out" || miss "outside: --check does not see production with other reviewers or a branch policy ($rc)"
out=$(ob_py "$ob_t/tools" <<'PY' 2>&1 || true
import sys; sys.path.insert(0, sys.argv[2])
import github_check as C
step = {"what": "label risk:low", "args": ["label", "create", "risk:low", "--color", "0e8a16", "--description", "merges itself", "--force"]}
assert C.compare("acme/sample", step, {"risk:low": ("0E8A16", "merges itself")})[0] == "=", "same label"
assert C.compare("acme/sample", step, {"risk:low": ("ffffff", "merges itself")})[0] == "~", "other colour"
assert C.compare("acme/sample", step, {"risk:low": ("0e8a16", "other")})[0] == "~", "other description"
assert C.compare("acme/sample", step, {})[0] == "~", "missing"
print("ok")
PY
)
[ "$out" = ok ] || miss "outside: --check compares labels by name only: $(tail -2 <<<"$out")"

# (4) a ledger that is not on the default branch yet (the setup is not merged): not merged, exit 1
ob_fresh=$(ob_repo fresh "" "" trunk)
cp "$ob_a/governance/outside.toml" "$ob_fresh/governance/outside.toml"
cp "$ob_a/ops/outside.toml" "$ob_fresh/ops/outside.toml"
ob_reset; rc=0; j=$(ob_status "$ob_fresh" --json 2>/dev/null) || rc=$?
[ "$rc" = 1 ] || miss "outside: a ledger not merged yet does not exit 1 ($rc)"
[ "$(ob_ids unmerged)" = "var:PRESENT var:ABSENT var:BROKEN var:SLOW key:GENERATED key:PERSON watch:DRIFT action:install-app decision:approve-production" ] \
  || miss "outside: a ledger not merged yet does not list its rows as not merged: $(ob_ids unmerged)"
[ ! -s "$OB_LOG" ] || miss "outside: a check of a ledger that is not merged ran"
ob_stage=$(awk '/^## 7\. Outside the repository$/{f=1;next} /^## 8\./{f=0} f' "$ROOT/plugins/repo-setup/skills/new/SKILL.md")
grep -q 'not merged' <<<"$ob_stage" \
  || miss "outside: the outside stage does not say what to do while the setup is not merged"

# (5) the rule says what it does not hold: the tools run from the working tree
ob_gaps=$(awk '/^## Chỗ còn hở$/{f=1;next} /^## /{f=0} f' "$ROOT/docs/setup-principles.md")
grep -q 'tools/outside.py' <<<"$ob_gaps" \
  || miss "outside: the principles page does not list where rule 11 is kept by word"

echo "ok  work outside the repository (or misses reported above)"

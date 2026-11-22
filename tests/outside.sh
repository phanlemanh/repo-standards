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
python3 -c 'import json,sys; d=json.load(sys.stdin); assert sorted(d) == sorted("base ok apply yours decisions unknown unmerged refused".split()), sorted(d); assert d["base"] == "origin/trunk", d["base"]; assert all(sorted(e) == ["how","id","kind","where","why"] for k in d if k != "base" for e in d[k])' <<<"$j" 2>/dev/null \
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

echo "ok  work outside the repository (or misses reported above)"

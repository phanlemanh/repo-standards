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

echo "ok  work outside the repository (or misses reported above)"

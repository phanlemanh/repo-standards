# 47. the upgrade path (docs/superpowers/specs/2026-11-17-upgrade-path-design.md, RS8): a template
#     fix reaches a file edited in place, a conflict stays red until it is resolved, and doctor
#     says which files drift. Sourced by tests/run.sh; uses its S, TMP and miss.

# 47a. the templates come from a root: rendering them again gives what apply wrote
up_a="$TMP/up-a"; mkdir -p "$up_a"; git -C "$up_a" init -q -b main
python3 "$S/apply.py" --target "$up_a" --preset python --level team \
  --var project_name=Up --var description=x --var owner=acme >/dev/null
rebuilt=$(python3 - "$S" "$up_a" <<'PY' 2>&1 || true
import hashlib, json, sys
sys.path.insert(0, sys.argv[1])
import apply
m = json.load(open(f"{sys.argv[2]}/.repo-setup.json"))
choices = apply.choices_from_manifest(m)
plan = apply.planned_files(choices, apply.render_variables(m["vars"], choices))
bad = [k for k, h in m["files"].items() if k not in plan or hashlib.sha256(plan[k]["content"]).hexdigest() != h]
print("ok" if not bad else "differ: " + ", ".join(bad[:5]))
PY
)
[ "$rebuilt" = ok ] || miss "upgrade: planned_files does not rebuild what apply wrote ($rebuilt)"

# Two stand-in releases of the plugin, for every test below: 0.0.2 is today's templates, 0.0.1 is
# older in four files: (a) .editorconfig lacks its last line, (b) a line of CLAUDE.md reads
# differently, (c) tools/wiki_lint.py and the python pyproject.toml lack their last line.
arch="$TMP/arch"; mkdir -p "$arch"
PLUGIN="$ROOT/plugins/repo-setup"
for v in 0.0.1 0.0.2; do
  cp -R "$PLUGIN" "$arch/repo-setup-v$v"
  find "$arch/repo-setup-v$v" -name __pycache__ -prune -exec rm -rf {} +
  subst "s/\"version\": \"[^\"]*\"/\"version\": \"$v\"/" "$arch/repo-setup-v$v/.claude-plugin/plugin.json"
done
old="$arch/repo-setup-v0.0.1"
drop_last() { python3 -c "import sys,pathlib; p=pathlib.Path(sys.argv[1]); l=p.read_text().splitlines(True); p.write_text(''.join(l[:-1]))" "$1"; }
drop_last "$old/presets/_core/starter/dot.editorconfig"
subst 's|^- This repo keeps its procedures in `.claude/skills/`. Use them instead of improvising:$|- Procedures live in `.claude/skills/`; use them:|' "$old/presets/_core/starter/CLAUDE.md"
drop_last "$old/presets/_core/starter/tools/wiki_lint.py"
drop_last "$old/presets/python/starter/pyproject.toml.tmpl"
grep -q '^- Procedures live in' "$old/presets/_core/starter/CLAUDE.md" || miss "upgrade: the stand-in release did not change CLAUDE.md"
# up_install <dir> <plugin dir>: a python starter repository built with that release
up_install() {
  mkdir -p "$1"; git -C "$1" init -q -b main
  python3 "$2/scripts/apply.py" --target "$1" --preset python \
    --var project_name=Up --var description=x --var owner=acme >/dev/null
}
# up_find <repo> <base_from> <path> <recorded hash or ""> <recorded version>: status version reason
up_find() {
  python3 - "$S" "$@" <<'PY2'
import json, sys, tempfile
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import apply, upgrade_base
repo, base_from, path, recorded, version = sys.argv[2:7]
m = json.load(open(f"{repo}/.repo-setup.json"))
choices = apply.choices_from_manifest(m)
def render(root):
    plan = apply.planned_files(choices, apply.render_variables(m["vars"], choices, root), root)
    return {k: v["content"] for k, v in plan.items()}
with tempfile.TemporaryDirectory() as work:
    finder = upgrade_base.BaseFinder(render, apply.PLUGIN_ROOT, apply.plugin_version(),
                                     Path(base_from), Path(work))
    b = finder.find(path, recorded or m["files"][path], version)
    print(b.status, b.version or "-", b.reason or "-")
PY2
}

# 47c. a base from a release older than the one the manifest names is found
up_c="$TMP/up-c"; up_install "$up_c" "$old"
found=$(up_find "$up_c" "$arch" .editorconfig "" 0.0.2 2>&1 || true)
case "$found" in "found 0.0.1 "*) ;; *) miss "upgrade: a base from an older release is not found ($found)" ;; esac

# 47d. no release to read is "unread" with a reason; releases that do not match are "no_match"
mkdir -p "$TMP/arch-empty"
unread=$(up_find "$up_c" "$TMP/arch-empty" .editorconfig "" 0.0.1 2>&1 || true)
case "$unread" in "unread - "?*) ;; *) miss "upgrade: an unreadable base is not said to be unread ($unread)" ;; esac
case "$unread" in "unread - -") miss "upgrade: an unread base gives no reason" ;; esac
nomatch=$(up_find "$up_c" "$arch" .editorconfig "$(printf '0%.0s' $(seq 64))" 0.0.2 2>&1 || true)
case "$nomatch" in "no_match "*) ;; *) miss "upgrade: a hash no release has is not no_match ($nomatch)" ;; esac

# 47e. an archive that points outside, or is cut short, writes nothing outside the work folder
evil="$TMP/arch-evil"; mkdir -p "$evil/work"
python3 - "$evil" <<'PY2'
import io, json, sys, tarfile
from pathlib import Path
d = Path(sys.argv[1])
def add(tar, name, data=b"x"):
    info = tarfile.TarInfo(name); info.size = len(data); tar.addfile(info, io.BytesIO(data))
with tarfile.open(d / "repo-setup-v0.0.9.tar.gz", "w:gz") as tar:
    add(tar, "repo-standards-repo-setup-v0.0.9/plugins/repo-setup/.claude-plugin/plugin.json",
        json.dumps({"version": "0.0.9"}).encode())
    add(tar, "repo-standards-repo-setup-v0.0.9/plugins/repo-setup/../../evil-rs8")
    add(tar, str(d / "abs-rs8"))
    link = tarfile.TarInfo("repo-standards-repo-setup-v0.0.9/plugins/repo-setup/link-rs8")
    link.type = tarfile.SYMTYPE; link.linkname = "/etc/passwd"; tar.addfile(link)
raw = (d / "repo-setup-v0.0.9.tar.gz").read_bytes()
(d / "cut").mkdir()
(d / "cut" / "repo-setup-v0.0.9.tar.gz").write_bytes(raw[: len(raw) // 2])
PY2
python3 - "$S" "$evil" <<'PY2' >/dev/null 2>&1 || true
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import upgrade_base
d = Path(sys.argv[2])
try:
    upgrade_base.plugin_root_for("0.0.9", d, d / "work")
except upgrade_base.BaseUnreadable:
    pass
PY2
for f in "$evil/evil-rs8" "$TMP/evil-rs8" "$evil/abs-rs8"; do
  [ ! -e "$f" ] || miss "upgrade: an archive entry was written outside the work folder: $f"
done
if find "$evil/work" -type l | grep -q .; then miss "upgrade: an archive's link was extracted"; fi
cut=$(python3 - "$S" "$evil/cut" <<'PY2' 2>&1 || true
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import upgrade_base
d = Path(sys.argv[2])
try:
    upgrade_base.plugin_root_for("0.0.9", d, d / "work")
    print("read")
except upgrade_base.BaseUnreadable as exc:
    print("unreadable", exc)
PY2
)
case "$cut" in "unreadable "?*) ;; *) miss "upgrade: an archive cut short is not unreadable ($cut)" ;; esac

echo "ok  upgrade path (or misses reported above)"

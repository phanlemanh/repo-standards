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

# 47g. three-way merge: both sides kept when apart, labelled markers when they meet, an empty
#      base for a file with no matching base, and a binary file refused
merge=$(python3 - "$S" <<'PY2' 2>&1 || true
import sys
sys.path.insert(0, sys.argv[1])
import upgrade_merge as um
base = b"a\nb\nc\nd\ne\n"
out, clean = um.three_way(b"ours\n" + base, base, base + b"theirs\n", um.release_label("0.0.1"), um.release_label("0.0.2"))
print("apart", clean and b"ours\n" in out and b"theirs\n" in out)
out, clean = um.three_way(b"a\nB1\nc\nd\ne\n", base, b"a\nB2\nc\nd\ne\n", um.release_label("0.0.1"), um.release_label("0.0.2"))
labels = [b"<<<<<<< this repository", b"||||||| repo-setup 0.0.1", b"=======", b">>>>>>> repo-setup 0.0.2"]
print("meet", (not clean) and all(l in out for l in labels))
out, clean = um.three_way(b"x\ny\n", b"", b"x\nz\n", um.NO_BASE_LABEL, um.release_label("0.0.2"))
print("nobase", (not clean) and b"||||||| repo-setup: no matching base" in out)
try:
    um.three_way(b"\x00bin\n", b"\x00base\n", b"\x00new\n", um.release_label("0.0.1"), um.release_label("0.0.2"))
    print("binary False")
except um.MergeUnavailable:
    print("binary True")
PY2
)
for case in apart meet nobase binary; do
  echo "$merge" | grep -qx "$case True" || miss "upgrade: three_way case '$case' is wrong ($(echo "$merge" | tail -1))"
done

# up_apply <apply.py> <repo> [args...]: the --json result; the exit code goes to <repo>.rc
up_apply() {
  local script="$1" repo="$2"; shift 2
  local rc=0
  python3 "$script" --target "$repo" --json "$@" > "$repo.json" 2> "$repo.err" || rc=$?
  echo "$rc" > "$repo.rc"; cat "$repo.json"
}
in_group() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if sys.argv[3] in d.get(sys.argv[2], []) else 1)" "$1.json" "$2" "$3"; }
manifest_get() { python3 -c "import json,sys; m=json.load(open(sys.argv[1]+'/.repo-setup.json')); print(eval(sys.argv[2]))" "$1" "$2"; }
manifest_set() { python3 -c "
import json,sys; p=sys.argv[1]+'/.repo-setup.json'; m=json.load(open(p)); exec(sys.argv[2]); open(p,'w').write(json.dumps(m, indent=2)+'\n')" "$1" "$2"; }
tree_hash() { (cd "$1" && find . -path ./.git -prune -o -type f -print | LC_ALL=C sort | xargs shasum | shasum); }
NOW=$(python3 -c "import sys; sys.path.insert(0, '$S'); import apply; print(apply.plugin_version())")

# A repository built with 0.0.1, then edited in place: a comment on top of .editorconfig and of
# pyproject.toml (the template adds a line at their end), the line of CLAUDE.md that 0.0.1 and
# today read differently is changed a third way, tools/wiki_lint.py gets a line on top, the
# executable bit and CRLF line ends, and README.md is deleted.
up="$TMP/up"; up_install "$up" "$old"
printf '# repo note\n' | cat - "$up/.editorconfig" > "$up/x" && mv "$up/x" "$up/.editorconfig"
printf '# repo note\n' | cat - "$up/pyproject.toml" > "$up/x" && mv "$up/x" "$up/pyproject.toml"
subst 's|^- Procedures live in `.claude/skills/`; use them:$|- Our procedures are in `.claude/skills/`:|' "$up/CLAUDE.md"
python3 - "$up/tools/wiki_lint.py" <<'PY2'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
p.write_bytes(("# repo line\n" + p.read_text()).replace("\n", "\r\n").encode())
PY2
chmod +x "$up/tools/wiki_lint.py"
rm "$up/README.md"

# 47b. a dry run gives the same groups as the real run, and changes nothing, the manifest included
before=$(tree_hash "$up")
up_apply "$S/apply.py" "$up" --base-from "$arch" --dry-run --diff >/dev/null
cp "$up.json" "$TMP/up-dry.json"
[ "$(tree_hash "$up")" = "$before" ] || miss "upgrade: a dry run changed files"
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if '<<<<<<< this repository' in d['diffs'].get('CLAUDE.md','') else 1)" "$TMP/up-dry.json" \
  || miss "upgrade: --diff does not show what a marked file will hold"
up_apply "$S/apply.py" "$up" --base-from "$arch" >/dev/null
groups='["merged","marked","base_unread","removed","dropped","edited","updated","created"]'
same=$(python3 -c "import json,sys; a=json.load(open(sys.argv[1])); b=json.load(open(sys.argv[2])); g=json.loads(sys.argv[3]); print(all(sorted(a.get(k,[]))==sorted(b.get(k,[])) for k in g))" "$TMP/up-dry.json" "$up.json" "$groups")
[ "$same" = True ] || miss "upgrade: the dry run and the real run do not give the same groups"

# 47f. what does not meet is merged: both sides kept, the bit and the line ends too
for f in .editorconfig tools/wiki_lint.py pyproject.toml; do
  in_group "$up" merged "$f" || miss "upgrade: $f is not merged"
done
grep -q '^# repo note' "$up/.editorconfig" || miss "upgrade: the merge lost the repository's line in .editorconfig"
[ "$(tail -1 "$up/.editorconfig")" = "$(tail -1 "$PLUGIN/presets/_core/starter/dot.editorconfig")" ] \
  || miss "upgrade: the merge lost the template's new line in .editorconfig"
grep -q '^# repo note' "$up/pyproject.toml" || miss "upgrade: the merge lost the repository's line in pyproject.toml"
[ -x "$up/tools/wiki_lint.py" ] || miss "upgrade: the merge dropped the executable bit"
python3 - "$up/tools/wiki_lint.py" "$PLUGIN/presets/_core/starter/tools/wiki_lint.py" <<'PY2' || miss "upgrade: the merge broke CRLF line ends or lost a side"
import sys
data = open(sys.argv[1], "rb").read()
last = open(sys.argv[2], "rb").read().splitlines()[-1]
lines = data.split(b"\r\n")
assert data.startswith(b"# repo line\r\n"), "repo line"
assert b"\n" not in data.replace(b"\r\n", b""), "bare LF"
assert last in lines, "template's last line"
PY2
grep -q 'lockfile' "$up.json" || miss "upgrade: a merged pyproject.toml gives no note to update the lockfile"

# 47h. where the sides meet the file is marked; deleted files stay deleted; the run says it is not done
in_group "$up" marked CLAUDE.md || miss "upgrade: CLAUDE.md is not marked"
for label in '<<<<<<< this repository' '||||||| repo-setup 0.0.1' '=======' ">>>>>>> repo-setup $NOW"; do
  grep -qxF -- "$label" "$up/CLAUDE.md" || miss "upgrade: CLAUDE.md lacks the line: $label"
done
[ "$(cat "$up.rc")" = 1 ] || miss "upgrade: apply ends well although a file is marked"
in_group "$up" removed README.md || miss "upgrade: a deleted README.md is not reported as removed"
[ ! -e "$up/README.md" ] || miss "upgrade: a file the repository deleted was created again"
[ "$(manifest_get "$up" 'm["file_versions"][".editorconfig"]')" = "$NOW" ] || miss "upgrade: a merged file does not record the version it now follows"
[ "$(manifest_get "$up" 'm["file_versions"]["README.md"]')" = 0.0.1 ] || miss "upgrade: a removed file does not keep its version"
manifest_get "$up" 'm["vars"]["today"]' | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || miss "upgrade: the manifest does not record today"
# resolve: keep this repository's side
python3 - "$up/CLAUDE.md" <<'PY2'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); out, side = [], None
for line in p.read_text().splitlines(True):
    if line.startswith("<<<<<<< "): side = "ours"; continue
    if line.startswith("||||||| ") or line.startswith("=======") and side: side = "skip"; continue
    if line.startswith(">>>>>>> "): side = None; continue
    if side in (None, "ours"): out.append(line)
p.write_text("".join(out))
PY2
up_apply "$S/apply.py" "$up" --base-from "$arch" >/dev/null
[ "$(cat "$up.rc")" = 0 ] || miss "upgrade: the run after resolving is not clean ($(cat "$up.err" | tail -1))"
in_group "$up" marked CLAUDE.md && miss "upgrade: a resolved CLAUDE.md is marked again"
in_group "$up" edited CLAUDE.md || miss "upgrade: a resolved CLAUDE.md is not reported as edited"
# no matching base: a recorded hash no release has gives a two-way merge with markers
cp "$up/.gitattributes" "$TMP/gitattributes.template"
echo "local-only" >> "$up/.gitattributes"
manifest_set "$up" 'm["files"][".gitattributes"] = "0" * 64'
up_apply "$S/apply.py" "$up" --base-from "$arch" >/dev/null
in_group "$up" marked .gitattributes || miss "upgrade: a file with no matching base is not marked"
grep -qxF '||||||| repo-setup: no matching base' "$up/.gitattributes" || miss "upgrade: a two-way merge is not labelled as having no base"
# unread base: no release to read leaves the file as it is, with the reason, and fails
{ cat "$TMP/gitattributes.template"; echo "local-only"; } > "$up/.gitattributes"
h=$(shasum -a 256 "$TMP/gitattributes.template" | cut -d' ' -f1)
manifest_set "$up" "m['files']['.gitattributes'] = '$h'; m['file_versions']['.gitattributes'] = '0.0.1'"
before=$(shasum < "$up/.gitattributes")
up_apply "$S/apply.py" "$up" --base-from "$TMP/arch-empty" >/dev/null
in_group "$up" base_unread .gitattributes || miss "upgrade: a file whose base cannot be read is not base_unread"
[ "$(shasum < "$up/.gitattributes")" = "$before" ] || miss "upgrade: a file whose base cannot be read was changed"
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get('base_reasons',{}).get('.gitattributes') else 1)" "$up.json" || miss "upgrade: base_unread gives no reason"
[ "$(cat "$up.rc")" = 1 ] || miss "upgrade: apply ends well although a base could not be read"
# a manifest from before file_versions: the version of the whole repository is used
up3="$TMP/up3"; up_install "$up3" "$old"
manifest_set "$up3" 'm.pop("file_versions", None)'
printf '# repo note\n' | cat - "$up3/.editorconfig" > "$up3/x" && mv "$up3/x" "$up3/.editorconfig"
up_apply "$S/apply.py" "$up3" --base-from "$arch" >/dev/null
in_group "$up3" merged .editorconfig || miss "upgrade: a manifest without file_versions does not merge ($(tail -1 "$up3.err"))"
# a file the templates no longer give is dropped: left on disk, out of the manifest
drop="$TMP/arch-drop/repo-setup-v0.0.3"; mkdir -p "$TMP/arch-drop"; cp -R "$arch/repo-setup-v0.0.2" "$drop"
subst 's/"version": "0.0.2"/"version": "0.0.3"/' "$drop/.claude-plugin/plugin.json"
python3 - "$drop/presets/python/preset.toml" <<'PY2'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text()
p.write_text(t.replace('user_owned = ["pyproject.toml"]\n', 'user_owned = ["pyproject.toml"]\nexclude = [".editorconfig"]\n', 1))
PY2
up2="$TMP/up2"; up_install "$up2" "$old"
up_apply "$drop/scripts/apply.py" "$up2" --base-from "$arch" >/dev/null
in_group "$up2" dropped .editorconfig || miss "upgrade: a file the templates no longer give is not dropped"
[ -f "$up2/.editorconfig" ] || miss "upgrade: a dropped file was deleted"
[ "$(manifest_get "$up2" '".editorconfig" in m["files"] or ".editorconfig" in m.get("file_versions", {})')" = False ] \
  || miss "upgrade: a dropped file stays in the manifest"

# 47i. make check stays red while a setup file holds conflict markers, and only setup files count
up4="$TMP/up4"; up_install "$up4" "$old"
subst 's|^- Procedures live in `.claude/skills/`; use them:$|- Our procedures are in `.claude/skills/`:|' "$up4/CLAUDE.md"
up_apply "$S/apply.py" "$up4" --base-from "$arch" >/dev/null
mkdir -p "$up4/docs"; printf 'How a conflict looks:\n<<<<<<< this repository\n' > "$up4/docs/x.md"
wall=$(cd "$up4" && make upgrade 2>&1) && miss "upgrade: make upgrade is green while CLAUDE.md holds markers"
echo "$wall" | grep -q 'CLAUDE.md:' || miss "upgrade: make upgrade does not name the marked file ($wall)"
echo "$wall" | grep -q 'docs/x.md' && miss "upgrade: make upgrade reports a file that is not the setup's"
python3 - "$up4/CLAUDE.md" <<'PY2'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
p.write_text("".join(l for l in p.read_text().splitlines(True) if not l.startswith(("<<<<<<< ", "||||||| ", "=======", ">>>>>>> "))))
PY2
(cd "$up4" && make upgrade >/dev/null 2>&1) || miss "upgrade: make upgrade stays red once the markers are gone"
for preset in python ts-node claude-plugin; do
  d="$TMP/$preset-starter"
  [ -d "$d" ] || continue
  dry=$(cd "$d" && make -n check 2>&1 || true)
  echo "$dry" | grep -q 'upgrade_markers.py' || miss "upgrade: make check of $preset does not run the marker check ($(echo "$dry" | tail -2 | tr '\n' ' '))"
done

# 47j. doctor says which files drift from the plugin, and fails while an upgrade is unfinished
up5="$TMP/up5"; up_install "$up5" "$old"
subst 's|^- Procedures live in `.claude/skills/`; use them:$|- Our procedures are in `.claude/skills/`:|' "$up5/CLAUDE.md"
printf '# repo note\n' | cat - "$up5/.editorconfig" > "$up5/x" && mv "$up5/x" "$up5/.editorconfig"
rm "$up5/README.md"
up_apply "$S/apply.py" "$up5" --base-from "$arch" >/dev/null
doc() { python3 "$S/doctor.py" --target "$1" --json > "$1.doctor.json" 2>/dev/null || true; }
failed() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if sys.argv[2] in [r['id'] for r in d['failed']] else 1)" "$1.doctor.json" "$2"; }
drift() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))" "$1.doctor.json" "$2"; }
doc "$up5"
failed "$up5" setup_in_sync || miss "upgrade: doctor passes setup_in_sync while CLAUDE.md is marked"
[ "$(drift "$up5" '[p for p, n in d["upgrade"]["marked"]]' 2>&1)" = "['CLAUDE.md', 'CLAUDE.md']" ] || miss "upgrade: doctor does not list the marked file ($(drift "$up5" 'd.get("upgrade")' 2>&1 | tail -1))"
[ "$(drift "$up5" 'd["upgrade"]["removed"]' 2>&1)" = "['README.md']" ] || miss "upgrade: doctor does not list the removed file"
[ "$(drift "$up5" '".editorconfig" in d["upgrade"]["edited"]' 2>&1)" = True ] || miss "upgrade: doctor does not list a file edited in place"
python3 - "$up5/CLAUDE.md" <<'PY2'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
p.write_text("".join(l for l in p.read_text().splitlines(True) if not l.startswith(("<<<<<<< ", "||||||| ", "=======", ">>>>>>> "))))
PY2
doc "$up5"
failed "$up5" setup_in_sync && miss "upgrade: doctor fails setup_in_sync once the markers are gone"
manifest_set "$up5" 'm["file_versions"][".gitignore"] = "0.0.1"'
doc "$up5"
failed "$up5" setup_in_sync || miss "upgrade: doctor passes setup_in_sync with a file behind the release"
[ "$(drift "$up5" 'd["upgrade"]["behind"]' 2>&1)" = "[['.gitignore', '0.0.1']]" ] || miss "upgrade: doctor does not say which release a file is behind at ($(drift "$up5" 'd["upgrade"]["behind"]' 2>&1 | tail -1))"
python3 "$S/doctor.py" --target "$up5" 2>/dev/null | grep -qF "0.0.1 → $NOW" || miss "upgrade: doctor's text does not show the versions of a file behind"
rm "$up5/mk/upgrade.mk"
doc "$up5"
failed "$up5" upgrade_wall || miss "upgrade: doctor passes upgrade_wall without the marker check in make check"

echo "ok  upgrade path (or misses reported above)"

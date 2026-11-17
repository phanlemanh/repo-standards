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

echo "ok  upgrade path (or misses reported above)"

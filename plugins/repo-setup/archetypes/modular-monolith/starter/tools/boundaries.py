#!/usr/bin/env python3
"""Enforce module boundaries of a modular monolith (vendored by repo-setup).

  python3 tools/boundaries.py [--root DIR] [--json]

The map is architecture/modules.yaml:

    modules:
      - name: sales
        description: Orders and checkout
        owns: [Order]              # ontology entities this module is the owner of
        depends_on: []
      - name: loyalty
        owns: [Customer]
        depends_on: [sales]        # loyalty may use sales' public API, not the reverse

Rules (errors):
  * code in module A imports module B only if B is in A.depends_on;
  * and only through B's public API: `modules/B` / `modules/B/index` (TS) or the package
    `<pkg>.modules.B` itself (Python) — never B's internal files;
  * depends_on has no cycles and names only known modules;
  * every ontology entity has at most one owner, and owners name existing entities.
Warnings: entities without an owner; module folders missing from the map (or vice versa).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from repo_ontology import find_repo_root, load_entities, load_yaml_file

TS_IMPORT = re.compile(
    r"""(?:import|export)\s[^'"]*?from\s+['"]([^'"]+)['"]|import\(\s*['"]([^'"]+)['"]"""
)
PY_IMPORT = re.compile(r"^\s*(?:from\s+(\.*[\w.]*)\s+import|import\s+([\w.]+))", re.MULTILINE)


def module_dirs(root: Path) -> list[Path]:
    return sorted(
        p
        for p in root.glob("src/**/modules/*")
        if p.is_dir() and not p.name.startswith(("_", ".")) and "node_modules" not in p.parts
    )


def ts_target(src: Path, spec: str, modules_root: Path) -> tuple[str, bool] | None:
    """(module, via_public_api) for a relative import into modules/, else None."""
    if not spec.startswith("."):
        return None
    target = (src.parent / spec).resolve()
    try:
        rel = target.relative_to(modules_root.resolve())
    except ValueError:
        return None
    parts = rel.parts
    if not parts:
        return None
    rest = [p for p in parts[1:] if p]
    public = not rest or (
        len(rest) == 1 and re.fullmatch(r"index(\.[jt]sx?)?", rest[0]) is not None
    )
    return parts[0], public


def py_target(src: Path, spec: str, pkg_root: Path, package: str) -> tuple[str, bool] | None:
    if spec.startswith("."):
        level = len(spec) - len(spec.lstrip("."))
        base = src.parent
        for _ in range(level - 1):
            base = base.parent
        dotted = spec.lstrip(".")
        target = base.joinpath(*dotted.split(".")) if dotted else base
        try:
            rel = target.resolve().relative_to(pkg_root.resolve())
        except ValueError:
            return None
        name = ".".join((package, *rel.parts))
    else:
        name = spec
    prefix = f"{package}.modules."
    if not name.startswith(prefix):
        return None
    parts = name[len(prefix) :].split(".")
    return parts[0], len(parts) == 1


def check(root: Path) -> dict[str, list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    data = load_yaml_file(root / "architecture" / "modules.yaml") or {}
    declared: dict[str, dict[str, Any]] = {
        str(m.get("name")): m for m in (data.get("modules") or []) if isinstance(m, dict)
    }
    deps = {name: set(m.get("depends_on") or []) for name, m in declared.items()}

    for name, targets in deps.items():
        for t in sorted(targets - set(declared)):
            errors.append(f"architecture/modules.yaml: {name} depends on unknown module '{t}'")
    # cycles
    state: dict[str, int] = {}

    def visit(node: str, path: list[str]) -> None:
        state[node] = 1
        for nxt in sorted(deps.get(node, set())):
            if state.get(nxt) == 1:
                cycle = [*path[path.index(nxt) :], nxt] if nxt in path else [node, nxt]
                errors.append("architecture/modules.yaml: dependency cycle " + " -> ".join(cycle))
            elif nxt in declared and state.get(nxt) is None:
                visit(nxt, [*path, nxt])
        state[node] = 2

    for name in declared:
        if state.get(name) is None:
            visit(name, [name])

    # ownership
    entities = set(load_entities(root))
    owner: dict[str, str] = {}
    for name, m in declared.items():
        for ent in m.get("owns") or []:
            if ent not in entities:
                errors.append(f"architecture/modules.yaml: {name} owns unknown entity '{ent}'")
            elif ent in owner:
                errors.append(
                    f"architecture/modules.yaml: '{ent}' owned by {owner[ent]} and {name}"
                )
            else:
                owner[ent] = name
    for ent in sorted(entities - set(owner)):
        warnings.append(f"architecture/modules.yaml: entity '{ent}' has no owning module")

    # imports
    dirs = module_dirs(root)
    found = {d.name for d in dirs}
    for name in sorted(found - set(declared)):
        warnings.append(f"module folder '{name}' is not in architecture/modules.yaml")
    for name in sorted(set(declared) - found):
        warnings.append(f"module '{name}' is declared but has no folder under src/**/modules/")
    for mdir in dirs:
        here = mdir.name
        modules_root = mdir.parent
        pkg_root = modules_root.parent
        package = pkg_root.name
        for src in sorted(mdir.rglob("*")):
            if src.suffix not in (".ts", ".tsx", ".py") or not src.is_file():
                continue
            text = src.read_text(encoding="utf-8", errors="replace")
            rel = src.relative_to(root).as_posix()
            if src.suffix == ".py":
                specs = [a or b for a, b in PY_IMPORT.findall(text)]
                resolved = [py_target(src, s, pkg_root, package) for s in specs]
            else:
                specs = [a or b for a, b in TS_IMPORT.findall(text)]
                resolved = [ts_target(src, s, modules_root) for s in specs]
            for spec, target in zip(specs, resolved, strict=True):
                if target is None or target[0] == here:
                    continue
                other, public = target
                if other not in deps.get(here, set()):
                    errors.append(f"{rel}: module '{here}' may not use '{other}' ({spec})")
                elif not public:
                    errors.append(f"{rel}: import '{other}' through its public API, not {spec}")
    return {"errors": errors, "warnings": warnings}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--root", default=None)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    root = Path(args.root).resolve() if args.root else find_repo_root()
    result = check(root)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        for e in result["errors"]:
            print(f"ERROR {e}")
        for w in result["warnings"]:
            print(f"warn  {w}")
        n_err, n_warn = len(result["errors"]), len(result["warnings"])
        print(f"boundaries: {n_err} errors, {n_warn} warnings")
    return 1 if result["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())

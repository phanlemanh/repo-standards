#!/usr/bin/env python3
"""Check that ontology/ and wiki/ are consistent (vendored by repo-setup).

Errors (exit 1): broken structure that misleads people and agents.
Warnings: things to tidy up (use --strict to fail on them too).

  python3 tools/wiki_lint.py [--root DIR] [--strict] [--json]

Checks
  ontology  entity files parse; name matches file; property types valid; enum/ref complete;
            relations point to existing entities; entities appear in the glossary;
            referenced wiki pages and code paths exist.
  wiki      every page has front matter with a known type and a title; pages live in the
            folder of their type; filenames follow the pattern; required sections exist;
            must_link rules hold; relative links resolve; pages are reachable from index.md.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ontology_actions
from repo_ontology import (
    YamlError,
    find_repo_root,
    load_yaml_file,
    parse_yaml,
    split_front_matter,
)

PROPERTY_TYPES = {
    "string",
    "text",
    "integer",
    "number",
    "boolean",
    "date",
    "datetime",
    "uuid",
    "enum",
    "ref",
}
CARDINALITIES = {"one-to-one", "one-to-many", "many-to-one", "many-to-many"}
SPECIAL_PAGES = {"index", "log"}
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
HEADING = re.compile(r"^##\s+(.+?)\s*$", re.MULTILINE)


class Report:
    def __init__(self) -> None:
        self.errors: list[dict[str, str]] = []
        self.warnings: list[dict[str, str]] = []

    def error(self, path: str, msg: str) -> None:
        self.errors.append({"path": path, "message": msg})

    def warn(self, path: str, msg: str) -> None:
        self.warnings.append({"path": path, "message": msg})


def rel(root: Path, p: Path) -> str:
    try:
        return p.resolve().relative_to(root).as_posix()
    except ValueError:
        return p.as_posix()


def filename_regex(spec: str) -> re.Pattern[str]:
    pattern = re.escape(spec)
    pattern = pattern.replace(r"YYYY\-Www", r"\d{4}-W\d{2}")
    pattern = pattern.replace("NNNN", r"\d{4}").replace(r"YYYY\-MM\-DD", r"\d{4}-\d{2}-\d{2}")
    pattern = pattern.replace(r"short\-title", r"[a-z0-9]+(?:-[a-z0-9]+)*")
    return re.compile("^" + pattern + "$")


def check_ontology(root: Path, rep: Report) -> dict[str, dict[str, Any]]:
    entities: dict[str, dict[str, Any]] = {}
    folder = root / "ontology" / "entities"
    if not (root / "ontology").is_dir():
        rep.warn("ontology/", "no ontology/ folder")
        return entities
    files = sorted(f for f in folder.glob("*.y*ml") if not f.name.startswith("_"))
    for f in files:
        path = rel(root, f)
        try:
            data = parse_yaml(f.read_text(encoding="utf-8"))
        except YamlError as exc:
            rep.error(path, f"invalid YAML: {exc}")
            continue
        if not isinstance(data, dict):
            rep.error(path, "entity file must be a mapping")
            continue
        entities[f.stem] = data
        if data.get("name") != f.stem:
            rep.error(path, f"name '{data.get('name')}' must match the file name '{f.stem}'")
        if not data.get("description"):
            rep.warn(path, "missing description")

    for name, data in entities.items():
        path = f"ontology/entities/{name}.yaml"
        props = data.get("properties") or {}
        if not isinstance(props, dict):
            rep.error(path, "properties must be a mapping of name -> {type: ...}")
            props = {}
        for pname, spec in props.items():
            if not isinstance(spec, dict):
                rep.error(path, f"property '{pname}' must be a mapping like {{type: string}}")
                continue
            ptype = spec.get("type")
            if ptype not in PROPERTY_TYPES:
                rep.error(
                    path,
                    f"property '{pname}': unknown type '{ptype}' "
                    f"(use one of: {', '.join(sorted(PROPERTY_TYPES))})",
                )
            if ptype == "enum" and not spec.get("values"):
                rep.error(path, f"property '{pname}': enum needs values: [...]")
            if ptype == "ref" and spec.get("target") not in entities:
                rep.error(path, f"property '{pname}': ref target '{spec.get('target')}' not found")
        for sub, sspec in (data.get("subtypes") or {}).items():
            if not isinstance(sspec, dict) or not sspec.get("description"):
                rep.warn(path, f"subtype '{sub}' should have a description")
        for rule in data.get("rules") or []:
            if isinstance(rule, dict):
                target = rule.get("implemented_in")
                if target and not (root / str(target)).exists():
                    rep.warn(path, f"rule '{rule.get('id')}': implemented_in '{target}' not found")
        wiki = data.get("wiki")
        if wiki and not (root / str(wiki)).exists():
            rep.warn(path, f"wiki page '{wiki}' does not exist yet")

    relations = load_yaml_file(root / "ontology" / "relations.yaml") or {}
    for r in relations.get("relations") or [] if isinstance(relations, dict) else []:
        if not isinstance(r, dict):
            rep.error("ontology/relations.yaml", "each relation must be a mapping")
            continue
        label = f"{r.get('from')} -{r.get('name')}-> {r.get('to')}"
        for end in ("from", "to"):
            if r.get(end) not in entities:
                rep.error("ontology/relations.yaml", f"{label}: '{r.get(end)}' is not an entity")
        if r.get("cardinality") and r.get("cardinality") not in CARDINALITIES:
            rep.error(
                "ontology/relations.yaml", f"{label}: unknown cardinality '{r.get('cardinality')}'"
            )

    ontology_actions.lint(root, entities, rep.error, rep.warn)

    glossary = root / "ontology" / "glossary.md"
    gtext = glossary.read_text(encoding="utf-8") if glossary.exists() else ""
    if not glossary.exists():
        rep.error("ontology/glossary.md", "missing glossary")
    for name in entities:
        if not re.search(rf"\b{re.escape(name)}\b", gtext):
            rep.warn("ontology/glossary.md", f"entity '{name}' is not defined in the glossary")
    return entities


def check_wiki(root: Path, rep: Report, entities: dict[str, dict[str, Any]]) -> None:
    wiki = root / "wiki"
    if not wiki.is_dir():
        rep.warn("wiki/", "no wiki/ folder")
        return
    page_types = load_yaml_file(root / "ontology" / "page-types.yaml") or {}
    if not isinstance(page_types, dict) or not page_types:
        rep.error("ontology/page-types.yaml", "missing or empty: wiki pages cannot be checked")
        page_types = {}

    pages = sorted(wiki.rglob("*.md"))
    index = wiki / "index.md"
    if not index.exists():
        rep.error("wiki/index.md", "missing: agents start here")
    linked_from_index: set[Path] = set()
    reachable: set[Path] = set()

    for page in pages:
        path = rel(root, page)
        text = page.read_text(encoding="utf-8")
        try:
            fm, body = split_front_matter(text)
        except YamlError as exc:
            rep.error(path, f"invalid front matter: {exc}")
            continue
        if fm is None:
            rep.error(path, "missing front matter (--- type: ... title: ... ---)")
            fm, body = {}, text
        ptype = fm.get("type")
        if not fm.get("title"):
            rep.error(path, "front matter needs a title")
        if ptype in SPECIAL_PAGES:
            pass
        elif ptype not in page_types:
            known = ", ".join(sorted(page_types)) or "none defined"
            rep.error(path, f"unknown page type '{ptype}' (known: {known})")
        else:
            spec = page_types[ptype] or {}
            folder = spec.get("folder")
            if folder and rel(root, page.parent) != str(folder).rstrip("/"):
                rep.error(path, f"type '{ptype}' pages belong in {folder}/")
            if spec.get("filename") and not filename_regex(str(spec["filename"])).match(page.name):
                rep.error(path, f"file name should look like {spec['filename']}")
            for field in spec.get("fields") or []:
                if fm.get(field) in (None, ""):
                    rep.error(path, f"front matter needs '{field}'")
            allowed = spec.get("statuses")
            if allowed and fm.get("status") not in allowed:
                rep.error(path, f"status '{fm.get('status')}' is not one of: {', '.join(allowed)}")
            headings = {h.strip().lower() for h in HEADING.findall(body)}
            for section in spec.get("sections") or []:
                if str(section).lower() not in headings:
                    rep.error(path, f"missing section '## {section}'")
            links = [str(x) for x in (fm.get("links") or [])]
            for need in spec.get("must_link") or []:
                if need == "ontology_entity":
                    ok = any(
                        re.fullmatch(r"ontology/entities/[^/]+\.ya?ml", x) and (root / x).exists()
                        for x in links
                    )
                elif need == "entity":
                    ok = any(
                        (x.startswith(("wiki/entities/", "ontology/entities/")))
                        and (root / x).exists()
                        for x in links
                    )
                else:
                    ok = any(need in x for x in links)
                if not ok:
                    rep.error(path, f"must link to an existing {need} in front matter 'links'")
        for x in fm.get("links") or []:
            if not (root / str(x)).exists():
                rep.error(path, f"front matter link '{x}' does not exist (paths are repo-relative)")
        visible = re.sub(r"<!--.*?-->|```.*?```|`[^`\n]*`", "", body, flags=re.DOTALL)
        for target in LINK.findall(visible):
            if re.match(r"^[a-z]+:", target) or target.startswith("#"):
                continue
            dest = (page.parent / target.split("#", 1)[0]).resolve()
            if not dest.exists():
                rep.error(path, f"broken link '{target}'")
            elif dest.suffix == ".md":
                reachable.add(dest)
                if page == index:
                    linked_from_index.add(dest)

    if index.exists():
        n = len(index.read_text(encoding="utf-8").splitlines())
        if n > 80:
            rep.warn("wiki/index.md", f"{n} lines; keep the entry page short (< 80)")
    for page in pages:
        if page.name in ("index.md", "log.md"):
            continue
        if page.resolve() not in linked_from_index:
            rep.warn(rel(root, page), "not linked from wiki/index.md")
    for name, data in entities.items():
        if data.get("wiki") and (root / str(data["wiki"])).resolve() not in reachable:
            rep.warn(str(data["wiki"]), f"entity page for {name} is not linked from any wiki page")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--root", default=None, help="repository root (default: auto-detect)")
    ap.add_argument("--strict", action="store_true", help="fail on warnings too")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    root = Path(args.root).resolve() if args.root else find_repo_root()

    rep = Report()
    entities = check_ontology(root, rep)
    check_wiki(root, rep, entities)

    if args.json:
        print(
            json.dumps(
                {"errors": rep.errors, "warnings": rep.warnings}, indent=2, ensure_ascii=False
            )
        )
    else:
        for e in rep.errors:
            print(f"ERROR {e['path']}: {e['message']}")
        for w in rep.warnings:
            print(f"warn  {w['path']}: {w['message']}")
        print(
            f"wiki-lint: {len(entities)} entities, {len(rep.errors)} errors, "
            f"{len(rep.warnings)} warnings"
        )
    return 1 if rep.errors or (args.strict and rep.warnings) else 0


if __name__ == "__main__":
    sys.exit(main())

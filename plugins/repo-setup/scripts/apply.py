#!/usr/bin/env python3
"""Apply repo-setup presets to a target directory.

Layers are applied in order (later layers win on the same path):
    _core/starter -> [_core/team] -> <base preset>/... -> <preset>/starter -> [<preset>/team]
A preset can inherit another with `extends = "<name>"` in its preset.toml.

Conventions inside preset folders:
  * A path component starting with "dot." becomes "." (dot.gitignore -> .gitignore,
    dot.github/ -> .github/). This keeps preset dotfiles from affecting this repo.
  * Files ending in ".tmpl" are rendered ({{var}} placeholders) and the suffix is dropped.
  * Placeholders are also allowed in path names, e.g. src/{{package_name}}/__init__.py.
  * A path component "[var=value]" is a condition: the files below it are used only when
    the variable has that value, and the component is dropped from the output path
    (e.g. [license=MIT]/LICENSE.tmpl -> LICENSE).

Safety rules:
  * A file the plugin wrote before and the repository edited since is merged with the new
    template, three ways, against what the plugin wrote last time (rebuilt from that release's
    templates, see upgrade_base.py). Where the two meet, the file gets conflict markers
    ("marked") and `make check` stays red until they are gone; package.json, which npm writes
    again on every install, is first merged key by key, and is marked only where one key changed
    on both sides (upgrade_merge.merge_by_key). Without a base to read, the file
    is left as it is ("base_unread"). Either ends the run with exit code 1.
  * A file the repository had before repo-setup wrote it is never overwritten: it is reported as
    "conflict" (or "kept" for files the repository owns) and left untouched (--diff shows why).
    Where that file is one that joins checks to `make check` (an mk/ file that sets
    CHECK_TARGETS, HEAVY_TARGETS or DERIVED_TARGETS) and no file of the repository joins them,
    the checks never run: the run names them and ends with exit code 1 (make_wiring.py).
  * A file the plugin wrote and the repository deleted is not created again ("removed").
  * Running again is safe: identical files are reported as "unchanged".
  * A manifest (.repo-setup.json) records preset, level, vars and file hashes so a
    later run (e.g. upgrading starter -> team) knows what it created.

--adopt (for repositories that already have code):
  * sample code (preset `sample` globs) is not added, and a file of the repo's own at a sample
    path is not a conflict;
  * a preset file is skipped when the repo already has an equivalent
    (preset `equivalents`, e.g. any .eslintrc* -> skip eslint.config.js);
  * line-based files listed in `merge_lines` (.gitignore, .gitattributes) get the missing
    lines appended instead of being reported as conflicts.

A preset can declare parts of the shared core that do not fit its kind of repository
(`[[not_applicable]]` with `what`, `reason`, `paths`): those files are left out and the reason is
reported, never dropped silently. `team_only` lists core files that only team-level tools need.

Two preset keys list files the repository may already have that the manifest does not record:
  * `user_owned`: the file is kept and a note asks the person to merge what the preset puts in it
    by hand (a package.json, a pyproject.toml);
  * `kept_quietly`: the file is kept, reported under `kept`, with no note and no diff. For a file
    that became the repository's own through a command, not through a decision to merge
    (the ledger head files after `make split`): nobody has anything to merge.

Only the Python standard library is used (Python 3.11+).
"""

from __future__ import annotations

import sys

if sys.version_info < (3, 11):
    print(f"repo-setup needs Python 3.11 or newer; this is {sys.version.split()[0]}.", file=sys.stderr)
    sys.exit(2)

import argparse
import datetime as _dt
import difflib
import hashlib
import json
import re
import stat
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import blueprint  # noqa: E402
import make_wiring  # noqa: E402
import merge_choice  # noqa: E402
import rule_kinds  # noqa: E402
import upgrade_base  # noqa: E402
import upgrade_merge  # noqa: E402
from doctor import Repo  # noqa: E402

MANIFEST_NAME = ".repo-setup.json"
# Files with a lockfile beside them: after the plugin changes one, the lockfile must follow.
LOCK_SOURCES = {"package.json": "npm install", "pyproject.toml": "uv lock"}

# The plan of files is built in apply_plan.py; its names stay reachable from here (apply.planned_files).
from apply_plan import (  # noqa: E402, F401
    _read_toml,
    AI_TIERS,
    available,
    available_presets,
    build_plan,
    capabilities_for,
    check_combination,
    Choices,
    choices_from_manifest,
    CONDITION,
    derive_vars,
    layers_for,
    left_out_patterns,
    LEVELS,
    LICENSES,
    load_meta,
    map_rel_path,
    matches,
    PLACEHOLDER,
    planned_files,
    PLUGIN_ROOT,
    plugin_version,
    PLUGIN_VERSIONING,
    preset_chain,
    PRESETS_DIR,
    render,
    render_variables,
    REQUIRED_VARS,
    RULES_FILE,
    units,
    with_rule_kinds,
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_manifest(target: Path) -> dict:
    f = target / MANIFEST_NAME
    if f.exists():
        try:
            return json.loads(f.read_text())
        except json.JSONDecodeError:
            return {}
    return {}


def merge_lines(current: bytes, template: bytes) -> bytes | None:
    """Append template lines missing from current. None if nothing is missing."""
    have = {ln.strip() for ln in current.decode("utf-8", "replace").splitlines()}
    missing = [
        ln
        for ln in template.decode("utf-8").splitlines()
        if ln.strip() and not ln.lstrip().startswith("#") and ln.strip() not in have
    ]
    if not missing:
        return None
    text = current.decode("utf-8", "replace")
    if text and not text.endswith("\n"):
        text += "\n"
    return (text + "\n# Added by repo-setup\n" + "\n".join(missing) + "\n").encode("utf-8")


def unified_diff(key: str, current: bytes, content: bytes) -> str:
    try:
        return "".join(
            difflib.unified_diff(
                current.decode("utf-8").splitlines(keepends=True),
                content.decode("utf-8").splitlines(keepends=True),
                fromfile=f"{key} (current)",
                tofile=f"{key} (preset)",
            )
        )
    except UnicodeDecodeError:
        return "(binary file differs)"


def _keep(args: argparse.Namespace) -> list[str]:
    """The flags that still apply next to a blueprint."""
    kept = ["--target", args.target]
    for name in ("dry_run", "diff", "json", "adopt"):
        if getattr(args, name):
            kept.append("--" + name.replace("_", "-"))
    return kept


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--target", default=".", help="Repository directory (default: .)")
    ap.add_argument("--preset", help="Preset name, e.g. ts-node, python")
    ap.add_argument("--level", choices=LEVELS, default=None, help="starter (default) or team")
    ap.add_argument(
        "--var",
        action="append",
        default=[],
        metavar="KEY=VALUE",
        help="Template variable (repeatable). Required: "
        + ", ".join(REQUIRED_VARS)
        + ". Optional: license=MIT|Apache-2.0|Proprietary",
    )
    ap.add_argument("--archetype", default=None,
                    help="Architecture by purpose, e.g. service-api, modular-monolith (default: none)")
    ap.add_argument("--deploy", default=None, help="Deployment target, e.g. container (default: none)")
    ap.add_argument("--with", dest="caps", default=None,
                    help="Extra capabilities, comma-separated (e.g. mcp). Archetypes add their own.")
    ap.add_argument("--from-blueprint", metavar="FILE", default=None,
                    help="Take the choices from a setup-blueprint.yaml; not with --preset and co.")
    ap.add_argument("--adopt", action="store_true", help="Existing codebase: see module docs")
    ap.add_argument("--dry-run", action="store_true", help="Show the plan, write nothing")
    ap.add_argument("--diff", action="store_true", help="Print unified diffs for conflicts")
    ap.add_argument("--json", action="store_true", help="Machine-readable output")
    ap.add_argument("--base-from", metavar="DIR", default=None,
                    help="Folder with repo-setup-v<version>/ or repo-setup-v<version>.tar.gz of "
                         "earlier releases, instead of downloading them (offline, tests)")
    ap.add_argument("--list-presets", action="store_true")
    ap.add_argument("--list-options", action="store_true",
                    help="List stacks, archetypes and deploy targets with descriptions")
    args = ap.parse_args(argv)

    if args.from_blueprint:
        mixed = [args.preset, args.level, args.archetype, args.deploy, args.caps, args.var]
        if any(mixed):
            ap.error("--from-blueprint carries all the choices: do not add --preset and the like")
        try:
            plan_file = blueprint.load(Path(args.from_blueprint))
        except (OSError, ValueError) as exc:
            ap.error(f"cannot read the blueprint: {exc}")
        problems = blueprint.errors(plan_file)
        if problems:
            ap.error("the blueprint has problems: " + "; ".join(problems))
        waiting = blueprint.blocking(plan_file)
        if waiting:
            ap.error("these layers still need a decision: " + ", ".join(waiting))
        if not args.dry_run and plan_file.get("status") not in ("approved", "applied"):
            ap.error("the blueprint is not approved yet: use --dry-run to preview it")
        args = ap.parse_args([*blueprint.to_apply_args(plan_file), *_keep(args)])
        args.from_blueprint = None

    if args.list_options:
        def describe(kind: str) -> dict[str, dict]:
            return {
                n: {k: v for k, v in _read_toml(PLUGIN_ROOT / kind / n / "preset.toml").items()
                    if k in ("description", "stacks", "when", "complexity")}
                for n in available(kind)
            }
        out = {"stacks": describe("presets"), "archetypes": describe("archetypes"),
               "capabilities": describe("capabilities"), "deploy": describe("deploy")}
        print(json.dumps(out, indent=2, ensure_ascii=False))
        return 0

    if args.list_presets:
        out = {p: load_meta(p, "starter")["description"] for p in available_presets()}
        print(
            json.dumps(out, indent=2, ensure_ascii=False)
            if args.json
            else "\n".join(f"{k:12} {v}" for k, v in out.items())
        )
        return 0

    target = Path(args.target).resolve()
    target.mkdir(parents=True, exist_ok=True)
    previous = load_manifest(target)

    preset = args.preset or previous.get("preset")
    if not preset:
        ap.error("--preset is required (or a previous .repo-setup.json must exist)")
    if preset not in available_presets():
        ap.error(f"Unknown preset '{preset}'. Available: {', '.join(available_presets())}")
    level = args.level or previous.get("level", "starter")
    adopt = args.adopt or bool(previous.get("adopt"))
    archetype = args.archetype or previous.get("archetype", "none")
    deploy = args.deploy or previous.get("deploy", "none")
    caps = list(previous.get("capabilities", []))
    for c in (args.caps or "").split(","):
        if c.strip() and c.strip() not in caps:
            caps.append(c.strip())
    notes: list[str] = []
    # Repos from before github-agents was split out still have the agent workflows. Keep the
    # capability, or a re-apply would drop the agent rules from AGENTS.md and leave them running.
    agent_pipeline = ".github/workflows/pr-pipeline.yml"
    if agent_pipeline in previous.get("files", {}) and "github-agents" not in caps:
        caps.append("github-agents")
        notes.append("kept capability github-agents: this repo has agent workflows")

    raw_vars: dict[str, str] = dict(previous.get("vars", {}))
    for item in args.var:
        if "=" not in item:
            ap.error(f"--var must be KEY=VALUE, got {item!r}")
        k, val = item.split("=", 1)
        raw_vars[k.strip()] = val.strip()
    missing = [k for k in REQUIRED_VARS if not raw_vars.get(k)]
    if missing:
        ap.error("Missing required --var: " + ", ".join(missing))
    # The merge method of the policy (team level): the one the repository uses, read from its
    # policy, then asked, then remembered, then seen in its history. See merge_choice.py.
    asked_method = next(
        (item.split("=", 1)[1].strip() for item in reversed(args.var)
         if item.split("=", 1)[0].strip() == "merge_method"),
        None,
    )
    if asked_method is not None and asked_method not in merge_choice.METHODS:
        ap.error(f"--var merge_method={asked_method} is not one of "
                 f"{', '.join(merge_choice.METHODS)}")
    if level == "team":
        try:
            raw_vars["merge_method"] = merge_choice.decide(
                target, asked_method, previous.get("vars", {}).get("merge_method"))
        except ValueError as exc:
            ap.error(str(exc))
    raw_vars.setdefault("today", _dt.date.today().isoformat())
    try:
        variables = derive_vars(raw_vars)
    except ValueError as exc:
        ap.error(str(exc))
    # The agent tier builds on the MCP layer (same permission checks), which must come first.
    if "ai" in caps and variables["ai_tier"] == "agent" and "mcp" not in capabilities_for(archetype):
        if "mcp" in caps:
            caps.remove("mcp")
        caps.insert(caps.index("ai"), "mcp")
    if adopt and "design" in capabilities_for(archetype, caps):
        ap.error("adopt does not support the design capability yet: it would overwrite or skip "
                 "the screens, styles and lint setup of an existing front end. Leave out "
                 "--with design when adopting.")
    try:
        check_combination(preset, archetype, deploy, caps, level)
    except ValueError as exc:
        ap.error(str(exc))
    meta = load_meta(preset, level, archetype, deploy, caps)
    for k, val in meta["vars"].items():
        variables.setdefault(k, str(val))
    # Commands may start with a "[var=value]" condition, e.g. "[lang=ts] npm install x".
    for key in ("install", "verify"):
        kept = []
        for cmd in meta[key]:
            cond = re.match(r"^\[([a-zA-Z_][a-zA-Z0-9_]*)=([^\]]+)\]\s*(.+)$", cmd)
            if cond and variables.get(cond.group(1)) != cond.group(2):
                continue
            command = cond.group(3) if cond else cmd
            if command not in kept:
                kept.append(command)
        meta[key] = kept

    try:
        plan = build_plan(preset, level, variables, archetype, deploy, caps)
    except KeyError as exc:
        print(f"Template error: {exc}", file=sys.stderr)
        return 2
    left_out = left_out_patterns(meta, level)
    not_applicable = [
        {"what": na.get("what", ""), "reason": na.get("reason", "")}
        for na in meta["not_applicable"]
        if any(matches(k.as_posix(), na.get("paths", [])) for k in plan)
    ]
    plan = {k: v for k, v in plan.items() if not matches(k.as_posix(), left_out)}
    try:
        plan = with_rule_kinds(plan, PLUGIN_ROOT, adopt)
    except KeyError as exc:
        print(f"Template error: {rule_kinds.REGISTRY_NAME} lacks {exc}", file=sys.stderr)
        return 2

    merge_set = set(meta["merge_lines"])
    existing = Repo(target).files if adopt else []

    prev_hashes: dict[str, str] = previous.get("files", {})
    prev_versions: dict[str, str] = previous.get("file_versions", {})
    prev_version = str(previous.get("version", plugin_version()))
    now = plugin_version()
    results: dict[str, list[str]] = {
        "created": [],
        "updated": [],
        "merged": [],
        "edited": [],
        "marked": [],
        "base_unread": [],
        "removed": [],
        "dropped": [],
        "unchanged": [],
        "kept": [],
        "skipped": [],
        "conflict": [],
    }
    reasons: dict[str, str] = {}
    base_reasons: dict[str, str] = {}
    diffs: dict[str, str] = {}
    new_hashes: dict[str, str] = {}
    new_versions: dict[str, str] = {}
    pending: list[tuple[Path, bytes, bool]] = []
    workdir = tempfile.TemporaryDirectory(prefix="repo-setup-base-")
    finder: upgrade_base.BaseFinder | None = None

    def base_of(key: str) -> upgrade_base.Base:
        nonlocal finder
        if finder is None:
            old = choices_from_manifest(previous)
            old_vars = dict(previous.get("vars", {}))

            def render(root: Path) -> dict[str, bytes]:
                files = planned_files(old, render_variables(old_vars, old, root), root,
                                      bool(previous.get("adopt")))
                return {k: v["content"] for k, v in files.items()}

            finder = upgrade_base.BaseFinder(
                render, PLUGIN_ROOT, now, Path(args.base_from) if args.base_from else None,
                Path(workdir.name),
            )
        return finder.find(key, prev_hashes[key], prev_versions.get(key, prev_version))

    for rel, item in sorted(plan.items(), key=lambda kv: str(kv[0])):
        dest = target / rel
        content: bytes = item["content"]
        key = rel.as_posix()
        write: bytes | None = content
        record = True  # the file now follows this release's template

        if dest.is_symlink():
            # The repository points this path elsewhere: never write through the link.
            same = dest.exists() and dest.read_bytes() == content
            results["unchanged" if same else "conflict"].append(key)
            if not same:
                reasons[key] = "a symbolic link: repo-setup does not write through it"
            new_hashes[key], new_versions[key] = sha(content), now
            continue
        if dest.exists():
            current = dest.read_bytes()
            if current == content:
                results["unchanged"].append(key)
                new_hashes[key], new_versions[key] = sha(content), now
                continue
            if key in prev_hashes and prev_hashes[key] == sha(current):
                results["updated"].append(key)
            elif key in prev_hashes:
                base = base_of(key)
                if base.status == "unread":
                    results["base_unread"].append(key)
                    base_reasons[key] = base.reason
                    continue
                group, write, why = upgrade_merge.reconcile(
                    current, content, base.content, base.version, now,
                    by_key=upgrade_merge.merges_by_key(key),
                    tail_heading=rule_kinds.section_heading(PLUGIN_ROOT) if key == RULES_FILE else None)
                results[group].append(key)
                if group == "base_unread":
                    base_reasons[key] = why
                    continue
                if group == "marked" and args.diff and write is not None:
                    diffs[key] = write.decode("utf-8", "replace")
            elif matches(key, meta["kept_quietly"]):
                results["kept"].append(key)
                continue
            elif matches(key, meta["user_owned"]):
                results["kept"].append(key)
                what = meta["hand_merge"].get(key, "what the preset puts in it")
                notes.append(f"kept your own {key}: merge {what} into it by hand "
                             "(--diff shows the preset's version)")
                if args.diff:
                    diffs[key] = unified_diff(key, current, content)
                continue
            elif adopt and key in merge_set:
                write = merge_lines(current, content)
                if write is None:
                    results["unchanged"].append(key)
                    continue
                results["merged"].append(key)
                record = False
            elif adopt and matches(key, meta["sample"]):
                # The repo's own file sits where a sample would go: nothing to reconcile.
                results["skipped"].append(key)
                reasons[key] = "sample code (adopt mode)"
                continue
            else:
                results["conflict"].append(key)
                if args.diff:
                    diffs[key] = unified_diff(key, current, content)
                continue
            if key in results["updated"] + results["merged"] and key in LOCK_SOURCES and record:
                notes.append(f"{key} changed: run the install command again to update the "
                             f"lockfile ({LOCK_SOURCES[key]})")
        else:
            if key in prev_hashes:
                # The repository deleted a file the plugin wrote: that is its choice.
                results["removed"].append(key)
                continue
            if adopt:
                if matches(key, meta["sample"]):
                    results["skipped"].append(key)
                    reasons[key] = "sample code (adopt mode)"
                    continue
                hit = next(
                    (
                        (eq, f)
                        for eq in meta["equivalents"]
                        if key in eq.get("files", [])
                        for f in existing
                        if matches(f, eq.get("existing", []))
                    ),
                    None,
                )
                if hit:
                    results["skipped"].append(key)
                    reasons[key] = f"repo already has {hit[1]}"
                    continue
            results["created"].append(key)

        if record:
            new_hashes[key], new_versions[key] = sha(content), now
        if write is not None:
            pending.append((dest, write, bool(item["executable"])))
    workdir.cleanup()

    # Every file's outcome is known before anything is written: a failure above leaves the
    # repository and its manifest as they were.
    if not args.dry_run:
        for dest, data, executable in pending:
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            if executable:
                dest.chmod(dest.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    # Files the plugin wrote before that this release no longer gives: they are the repo's now.
    given = {r.as_posix() for r in plan}
    if LEVELS.index(level) < LEVELS.index(previous.get("level", "starter")):
        # A lower --level than recorded leaves the recorded level's files alone: still ours.
        recorded = Choices(preset, previous["level"], archetype, deploy, tuple(caps))
        given |= set(planned_files(recorded, variables, adopt=adopt))
    results["dropped"] = sorted(k for k in prev_hashes if k not in given)
    files = {k: v for k, v in {**prev_hashes, **new_hashes}.items() if k not in results["dropped"]}
    versions = {k: new_versions.get(k, prev_versions.get(k, prev_version)) for k in files}
    # The repository's own file where a layer joins its checks to `make check`: they never run.
    unjoined = {
        rel.as_posix(): make_wiring.left_out(rel.as_posix(), item["content"], target)
        for rel, item in plan.items()
        if rel.as_posix() in results["conflict"]
    }
    for key, targets in unjoined.items():
        if targets:
            said = f"not in make check: {', '.join(targets)}"
            reasons[key] = f"{reasons[key]}; {said}" if key in reasons else said
            notes.append(make_wiring.advice(key, targets))
    exit_code = 1 if results["marked"] or results["base_unread"] or any(unjoined.values()) else 0

    if not args.dry_run:
        prev_level = previous.get("level", "starter")
        manifest = {
            **{k: v for k, v in previous.items() if k not in ("files", "file_versions")},
            "tool": "repo-setup",
            "version": now,
            "preset": preset,
            "level": level if LEVELS.index(level) >= LEVELS.index(prev_level) else prev_level,
            "adopt": adopt,
            "archetype": archetype,
            "deploy": deploy,
            "capabilities": caps,
            "vars": raw_vars,
            "files": files,
            "file_versions": versions,
        }
        (target / MANIFEST_NAME).write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
        )

    summary = {
        "target": str(target),
        "preset": preset,
        "chain": preset_chain(preset),
        "archetype": archetype,
        "capabilities": capabilities_for(archetype, caps),
        "deploy": deploy,
        "level": level,
        "adopt": adopt,
        "dry_run": args.dry_run,
        **results,
        "skip_reasons": reasons,
        "not_applicable": not_applicable,
        "notes": notes,
        "next_commands": {"install": meta["install"], "verify": meta["verify"]},
        "diffs": diffs,
        "base_reasons": base_reasons,
        "exit_code": exit_code,
    }
    if args.json:
        print(json.dumps(summary, indent=2, ensure_ascii=False))
    else:
        mode = "PLAN (dry run)" if args.dry_run else "APPLIED"
        print(
            f"{mode}: preset={preset} level={level}{' adopt' if adopt else ''} target={target}"
        )
        for note in notes:
            print(f"Note: {note}")
        for label in results:
            items = results[label]
            if items:
                print(f"\n{label.upper()} ({len(items)})")
                for i in items:
                    print(f"  {i}" + (f"  — {reasons[i]}" if i in reasons else ""))
        if not_applicable:
            print(f"\nNOT APPLICABLE to a {preset} repository ({len(not_applicable)})")
            for na in not_applicable:
                print(f"  {na['what']}  — {na['reason']}")
        for k, d in diffs.items():
            print(f"\n--- diff for {k} ---\n{d}")
        for k, why in base_reasons.items():
            print(f"\nNo base for {k}: {why}")
        if results["marked"]:
            print("\nRemove the conflict markers, then run make check.")
        if results["base_unread"]:
            print("Run again with network access, or pass --base-from.")
        if meta["install"]:
            print("\nNext: install commands")
            for c in meta["install"]:
                print(f"  $ {c}")
        if meta["verify"]:
            print("Then verify:")
            for c in meta["verify"]:
                print(f"  $ {c}")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())

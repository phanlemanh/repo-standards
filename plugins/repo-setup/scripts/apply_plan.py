"""Build what repo-setup writes: the layers, the variables and the plan of files, for apply.py.

Everything here reads the plugin's own presets and capabilities, and writes nothing. apply.py
decides what to do with each planned file in a repository (write, merge, keep, report).

Only the Python standard library is used (Python 3.11+).
"""

from __future__ import annotations

import datetime as _dt
import json
import re
import stat
import sys
import tomllib
import unicodedata
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import blueprint  # noqa: E402
import rule_kinds  # noqa: E402
from doctor import glob_to_regex  # noqa: E402

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
PRESETS_DIR = PLUGIN_ROOT / "presets"
LEVELS = ["starter", "team"]
PLACEHOLDER = re.compile(r"\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}")
CONDITION = re.compile(r"^\[([a-zA-Z_][a-zA-Z0-9_]*)=([^\]]+)\]$")
REQUIRED_VARS = ["project_name", "description", "owner"]
AI_TIERS = ("call", "workflow", "agent")
PLUGIN_VERSIONING = ("lockstep", "independent")
LICENSES = {
    # license var -> (SPDX for pyproject, value for package.json)
    "MIT": ("MIT", "MIT"),
    "Apache-2.0": ("Apache-2.0", "Apache-2.0"),
    "Proprietary": ("LicenseRef-Proprietary", "UNLICENSED"),
}


def plugin_version() -> str:
    try:
        data = json.loads((PLUGIN_ROOT / ".claude-plugin" / "plugin.json").read_text())
        return str(data.get("version", "0.0.0"))
    except (OSError, json.JSONDecodeError):
        return "0.0.0"


def available_presets() -> list[str]:
    return sorted(
        p.name for p in PRESETS_DIR.iterdir() if p.is_dir() and not p.name.startswith("_")
    )


def _read_toml(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open("rb") as fh:
        return tomllib.load(fh)


def preset_chain(preset: str, root: Path = PLUGIN_ROOT) -> list[str]:
    """['_core', base..., preset] following `extends`."""
    chain: list[str] = []
    current: str | None = preset
    while current:
        if current in chain:
            raise ValueError(f"circular extends at {current}")
        chain.insert(0, current)
        current = _read_toml(root / "presets" / current / "preset.toml").get("extends")
    return ["_core", *chain]


def available(kind: str, root: Path = PLUGIN_ROOT) -> list[str]:
    folder = root / kind
    if not folder.is_dir():
        return []
    return sorted(p.name for p in folder.iterdir() if p.is_dir() and not p.name.startswith("_"))


def capabilities_for(
    archetype: str, extra: list[str] | None = None, root: Path = PLUGIN_ROOT
) -> list[str]:
    """Capabilities an archetype brings (preset.toml `capabilities`) plus requested ones."""
    caps: list[str] = []
    if archetype and archetype != "none":
        caps += _read_toml(root / "archetypes" / archetype / "preset.toml").get(
            "capabilities", []
        )
    for c in extra or []:
        if c and c not in caps:
            caps.append(c)
    return caps


def units(
    preset: str,
    archetype: str = "none",
    deploy: str = "none",
    caps: list[str] | None = None,
    root: Path = PLUGIN_ROOT,
) -> list[Path]:
    """Directories that contribute, in order: core, stack chain, archetype, capabilities,
    deploy target."""
    out = [root / "presets" / name for name in preset_chain(preset, root)]
    if archetype and archetype != "none":
        out.append(root / "archetypes" / archetype)
    for cap in capabilities_for(archetype, caps, root):
        out.append(root / "capabilities" / cap)
    if deploy and deploy != "none":
        out.append(root / "deploy" / deploy)
    return out


def check_combination(
    preset: str,
    archetype: str,
    deploy: str,
    caps: list[str] | None = None,
    level: str = "team",
) -> None:
    chain = set(preset_chain(preset))
    pairs = [("archetypes", archetype), ("deploy", deploy)]
    pairs += [("capabilities", c) for c in capabilities_for(archetype, caps)]
    for kind, name in pairs:
        if not name or name == "none":
            continue
        if name not in available(kind):
            label = {"archetypes": "archetype", "capabilities": "capability"}.get(kind, kind)
            raise ValueError(f"unknown {label} '{name}'. "
                             f"Available: {', '.join(available(kind)) or 'none'}")
        meta = _read_toml(PLUGIN_ROOT / kind / name / "preset.toml")
        allowed = meta.get("stacks", [])
        if allowed and not chain & set(allowed):
            raise ValueError(f"{name} works with stacks: {', '.join(allowed)} (not {preset})")
        refused = set(meta.get("not_stacks", []))
        if chain & refused:
            raise ValueError(f"{name} does not work with: {', '.join(sorted(chain & refused))}")
        required = meta.get("requires_level")
        if required and LEVELS.index(level) < LEVELS.index(required):
            raise ValueError(f"{name} needs level {required} (not {level})")


def load_meta(
    preset: str,
    level: str,
    archetype: str = "none",
    deploy: str = "none",
    caps: list[str] | None = None,
    root: Path = PLUGIN_ROOT,
) -> dict:
    """Merged preset.toml data for every unit and all levels up to `level`."""
    merged: dict = {
        "description": "",
        "vars": {},
        "user_owned": [],
        "kept_quietly": [],
        "sample": [],
        "merge_lines": [],
        "equivalents": [],
        "exclude": [],
        "not_applicable": [],
        "team_only": [],
        "install": [],
        "verify": [],
        "hand_merge": {},
    }
    upto = LEVELS[: LEVELS.index(level) + 1]
    for unit in units(preset, archetype, deploy, caps, root):
        data = _read_toml(unit / "preset.toml")
        if unit.name == preset and unit.parent == root / "presets":
            merged["description"] = data.get("description", "")
        merged["vars"].update(data.get("vars", {}))
        merged["hand_merge"].update(data.get("hand_merge", {}))
        for key in ("user_owned", "kept_quietly", "sample", "merge_lines", "equivalents", "exclude",
                    "not_applicable", "team_only"):
            merged[key] += data.get(key, [])
        for lv in upto:
            for key in ("install", "verify"):
                for cmd in data.get(lv, {}).get(key, []):
                    if cmd not in merged[key]:
                        merged[key].append(cmd)
    return merged


def derive_vars(raw: dict[str, str]) -> dict[str, str]:
    # Values end up inside JSON/TOML strings: keep them on one line, without
    # double quotes or backslashes, so generated files always stay valid.
    v = {
        k: " ".join(str(val).replace('"', "'").replace("\\", "/").split())
        for k, val in raw.items()
    }
    # Identifiers are ASCII: accents are removed, so a Vietnamese name gives a readable slug.
    name = v.get("project_name", "").strip().lower().replace("\u0111", "d")
    name = "".join(c for c in unicodedata.normalize("NFKD", name) if not unicodedata.combining(c))
    slug = re.sub(r"[^a-z0-9]+", "-", name).strip("-") or "app"
    v.setdefault("slug", slug)
    pkg = re.sub(r"[^a-z0-9]+", "_", name).strip("_") or "app"
    if pkg[0].isdigit():
        pkg = "app_" + pkg
    v.setdefault("package_name", pkg)
    # The manifest records `today`, so a later run renders the same files again.
    v.setdefault("today", _dt.date.today().isoformat())
    v.setdefault("year", v["today"][:4])
    v.setdefault("owner_handle", v.get("owner", "").lstrip("@"))
    # Registry/org namespace: the org part of "org/team", lowercase (container registries).
    v.setdefault("owner_org", v["owner_handle"].split("/")[0].lower())
    v.setdefault("license", "MIT")
    if v["license"] not in LICENSES:
        raise ValueError(f"license must be one of: {', '.join(LICENSES)}")
    v.setdefault("license_spdx", LICENSES[v["license"]][0])
    v.setdefault("npm_license", LICENSES[v["license"]][1])
    # Tiers of the "ai" capability. A higher tier also gets the files of the lower ones.
    v.setdefault("conversation_language", "en")
    v.setdefault("docs_language", "en")
    v.setdefault("ai_tier", "call")
    if v["ai_tier"] not in AI_TIERS:
        raise ValueError(f"ai_tier must be one of: {', '.join(AI_TIERS)}")
    v["ai_workflow"] = "yes" if v["ai_tier"] in ("workflow", "agent") else "no"
    v["ai_agent"] = "yes" if v["ai_tier"] == "agent" else "no"
    # Preset claude-plugin: the sample plugin's name, and whether plugins share one version.
    v["plugin_name"] = re.sub(r"[^a-z0-9]+", "-", v.get("plugin_name", "").lower()).strip("-") or slug
    v.setdefault("plugin_versioning", "lockstep")
    if v["plugin_versioning"] not in PLUGIN_VERSIONING:
        raise ValueError(f"plugin_versioning must be one of: {', '.join(PLUGIN_VERSIONING)}")
    # The "design" capability: the same rules as the blueprint, for values given with --var.
    surface = v.get("design_surface")
    if surface is not None and surface not in blueprint.DESIGN_SURFACES:
        surfaces = ", ".join(sorted(blueprint.DESIGN_SURFACES))
        raise ValueError(f"design_surface must be one of: {surfaces}")
    if "locale" in v and not blueprint.LOCALE.fullmatch(v["locale"]):
        raise ValueError("locale must look like vi-VN (language-COUNTRY)")
    if "currency" in v and not blueprint.CURRENCY.fullmatch(v["currency"]):
        raise ValueError("currency must be a three-letter code like VND")
    # A brand colour is optional, and a bad one stops the run.
    brand = v.get("brand_primary", "")
    if brand:
        problems = blueprint.brand_errors(brand)
        if problems:
            raise ValueError("; ".join(problems))
    v.setdefault("design_brand", "yes" if brand else "no")
    v.setdefault("brand_primary_foreground", blueprint.readable_on(brand) if brand else "")
    v.setdefault("html_lang", v.get("locale", "").split("-")[0] or "en")
    # Optional marketplace (owner/repo or git URL) so every clone gets the repo-setup plugin.
    # `plugin_settings` is what the templates of releases up to 0.10.4 read; see plugin_variables.
    v["plugin_settings"] = plugin_settings(v.get("marketplace", "").strip(), design=False)
    return v


# design-assembly writes a repository's design ledgers; this setup only calls it
# (docs/three-repo-boundaries.md). Every clone of a repository with the design floor gets it.
DESIGN_ASSEMBLY_MARKETPLACE = "phanlemanh/design-assembly"
DESIGN_ASSEMBLY_PLUGIN = "design-assembly@design-assembly"


def plugin_settings(market: str, design: bool) -> str:
    """The plugin keys .claude/settings.json ends with: the repo-standards marketplace when one is
    given, and design-assembly when the repository has the design floor. Empty when neither."""
    known: dict[str, dict] = {}
    enabled: dict[str, bool] = {}
    if market:
        source = (
            {"source": "github", "repo": market}
            if re.fullmatch(r"[\w.-]+/[\w.-]+", market)
            else {"source": "git", "url": market}
        )
        known["repo-standards"] = {"source": source}
        enabled["repo-setup@repo-standards"] = True
    if design:
        known["design-assembly"] = {"source": {"source": "github", "repo": DESIGN_ASSEMBLY_MARKETPLACE}}
        enabled[DESIGN_ASSEMBLY_PLUGIN] = True
    if not known:
        return ""
    return (',\n  "extraKnownMarketplaces": ' + json.dumps(known)
            + ',\n  "enabledPlugins": ' + json.dumps(enabled))


def plugin_variables(variables: dict[str, str], caps: list[str]) -> dict[str, str]:
    """`plugins_enabled`, the placeholder today's settings template reads: it knows the
    capabilities. The earlier placeholder, `plugin_settings`, keeps the value the earlier releases
    rendered, so that an upgrade still finds the base of a settings.json those releases wrote and
    merges the new lines in (upgrade_base.py)."""
    return {"plugins_enabled": plugin_settings(variables.get("marketplace", "").strip(),
                                               "design" in caps)}


def render(text: str, variables: dict[str, str], where: str) -> str:
    def sub(m: re.Match[str]) -> str:
        key = m.group(1)
        if key not in variables:
            raise KeyError(f"Unknown placeholder {{{{{key}}}}} in {where}")
        return variables[key]

    return PLACEHOLDER.sub(sub, text)


def map_rel_path(rel: Path, variables: dict[str, str]) -> Path | None:
    """Output path for a preset file, or None if a [var=value] condition excludes it."""
    parts = []
    for part in rel.parts:
        cond = CONDITION.match(part)
        if cond:
            if variables.get(cond.group(1)) != cond.group(2):
                return None
            continue
        if part.startswith("dot."):
            part = "." + part[4:]
        parts.append(render(part, variables, str(rel)))
    out = Path(*parts)
    if out.name.endswith(".tmpl"):
        out = out.with_name(out.name[: -len(".tmpl")])
    return out


def layers_for(
    preset: str,
    level: str,
    archetype: str = "none",
    deploy: str = "none",
    caps: list[str] | None = None,
    root: Path = PLUGIN_ROOT,
) -> list[Path]:
    # Level-major: every starter layer first, then every team layer, so a team file of a
    # base preset still overrides a starter file of a derived preset.
    upto = LEVELS[: LEVELS.index(level) + 1]
    layers: list[Path] = []
    for lv in upto:
        for unit in units(preset, archetype, deploy, caps, root):
            d = unit / lv
            if d.is_dir():
                layers.append(d)
    return layers


def build_plan(
    preset: str,
    level: str,
    variables: dict[str, str],
    archetype: str = "none",
    deploy: str = "none",
    caps: list[str] | None = None,
    root: Path = PLUGIN_ROOT,
) -> dict[Path, dict]:
    """Files to write. A directory named "+<file>" holds fragments that are concatenated
    (sorted by fragment name, across all layers) into <file>; a later layer's fragment with
    the same name replaces the earlier one."""
    plan: dict[Path, dict] = {}
    composed: dict[Path, dict[str, bytes]] = {}
    for layer in layers_for(preset, level, archetype, deploy, caps, root):
        for src in sorted(layer.rglob("*")):
            if src.is_dir() or src.name == ".DS_Store" or "__pycache__" in src.parts:
                continue
            rel = src.relative_to(layer)
            compose_at = next((i for i, part in enumerate(rel.parts) if part.startswith("+")), None)
            data = src.read_bytes()
            if src.name.endswith(".tmpl"):
                data = render(data.decode("utf-8"), variables, str(src)).encode("utf-8")
            if compose_at is not None:
                target_parts = [*rel.parts[:compose_at], rel.parts[compose_at][1:]]
                dest = map_rel_path(Path(*target_parts), variables)
                if dest is None or map_rel_path(rel, variables) is None:
                    continue
                frag = src.name[: -len(".tmpl")] if src.name.endswith(".tmpl") else src.name
                composed.setdefault(dest, {})[frag] = data
                continue
            dest_rel = map_rel_path(rel, variables)
            if dest_rel is None:
                continue
            plan[dest_rel] = {
                "content": data,
                "executable": bool(src.stat().st_mode & stat.S_IXUSR),
                "source": str(src),
            }
    for dest, frags in composed.items():
        parts = [frags[name].rstrip(b"\n") + b"\n" for name in sorted(frags)]
        joiner = b"\n" if dest.suffix == ".md" else b""
        plan[dest] = {
            "content": joiner.join(parts),
            "executable": False,
            "source": f"composed from {len(parts)} fragments",
        }
    return plan


@dataclass(frozen=True)
class Choices:
    """What a repository was set up with, as .repo-setup.json records it."""

    preset: str
    level: str
    archetype: str = "none"
    deploy: str = "none"
    caps: tuple[str, ...] = ()


def choices_from_manifest(manifest: dict) -> Choices:
    return Choices(
        preset=str(manifest["preset"]),
        level=str(manifest.get("level", "starter")),
        archetype=str(manifest.get("archetype", "none")),
        deploy=str(manifest.get("deploy", "none")),
        caps=tuple(manifest.get("capabilities", [])),
    )


# The two walls that keep a session from editing the rules (.claude/settings.json). A starter
# repository keeps them: it has no branch rule and no code owner, so no review could carry the
# decision. At team level the machine drafts such a change in a pull request of its own, and the
# high tier and the ruleset hold it (docs/setup-principles.md, rule 3). The placeholder stays as long
# as a release that wrote it may be the base of an upgrade: a later release renders that release's
# templates with its own variables, and an unknown placeholder stops the run.
EDIT_WALLS = ',\n      "Edit(./.github/workflows/**)",\n      "Edit(./governance/**)"'


def level_variables(level: str) -> dict[str, str]:
    """Variables that follow the level, for the one template both levels share."""
    return {"settings_edit_walls": EDIT_WALLS if level == "starter" else ""}


def render_variables(
    raw: dict[str, str], choices: Choices, root: Path = PLUGIN_ROOT
) -> dict[str, str]:
    """The variables templates see: derived from the raw ones, plus the presets' defaults."""
    variables = derive_vars(raw)
    meta = load_meta(choices.preset, choices.level, choices.archetype, choices.deploy,
                     list(choices.caps), root)
    for k, val in meta["vars"].items():
        variables.setdefault(k, str(val))
    variables.update(level_variables(choices.level))
    variables.update(plugin_variables(variables, capabilities_for(choices.archetype,
                                                                  list(choices.caps), root)))
    return variables


def left_out_patterns(meta: dict, level: str) -> list[str]:
    """Files a derived preset does not want from its base (e.g. a CLI entry point), core parts
    that do not fit this kind of repository, and core files only team-level tools need."""
    left_out = [*meta["exclude"], *(p for na in meta["not_applicable"] for p in na.get("paths", []))]
    if level == "starter":
        left_out += meta["team_only"]
    return left_out


RULES_FILE = "AGENTS.md"


def with_rule_kinds(plan: dict, root: Path, adopt: bool) -> dict:
    """The plan with AGENTS.md as a repository gets it (rule_kinds.finish): the kinds of the rules
    come off and, unless the repository was set up with --adopt, a section names the machines it
    has. Call it after the files a preset leaves out are gone: a machine is one of the files left.
    Keys may be paths or posix strings; the plan given is not changed."""
    paths = {Path(k).as_posix() for k in plan}

    def present(path: str) -> bool:
        return path in paths

    return {
        k: {**v, "content": rule_kinds.finish(v["content"], root, present, adopt)}
        if Path(k).as_posix() == RULES_FILE
        else v
        for k, v in plan.items()
    }


def planned_files(
    choices: Choices, variables: dict[str, str], root: Path = PLUGIN_ROOT, adopt: bool = False
) -> dict[str, dict]:
    """The files the templates under `root` give for these choices, keyed by posix path. `adopt`
    is how the repository was set up: it decides what AGENTS.md ends with (with_rule_kinds)."""
    caps = list(choices.caps)
    meta = load_meta(choices.preset, choices.level, choices.archetype, choices.deploy, caps, root)
    plan = build_plan(choices.preset, choices.level, variables, choices.archetype, choices.deploy,
                      caps, root)
    left_out = left_out_patterns(meta, choices.level)
    kept = {k.as_posix(): v for k, v in plan.items() if not matches(k.as_posix(), left_out)}
    return with_rule_kinds(kept, root, adopt)


def matches(path: str, patterns: list[str]) -> bool:
    return any(glob_to_regex(p).match(path) for p in patterns)

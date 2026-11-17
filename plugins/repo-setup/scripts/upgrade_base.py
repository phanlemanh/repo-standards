"""Find the template a file was written from, so an upgrade can merge three ways.

The base of a file is what repo-setup wrote into it last time. The manifest keeps only its hash
and the plugin version that wrote it, so the base is rebuilt: from the templates of the running
plugin when the version is the same, otherwise from that release's archive (a tag of the source
repository, downloaded, or a folder given with --base-from). A rebuilt file counts as the base only
when its hash is the recorded one. Before the upgrade path existed, every run raised the version of
the whole repository, also for files it left alone, so older releases are tried as well.

Only the templates of a downloaded release are read: none of its code runs.

Only the Python standard library is used (Python 3.11+).
"""

from __future__ import annotations

import hashlib
import re
import shutil
import subprocess
import tarfile
import urllib.error
import urllib.request
import zlib
from collections.abc import Callable, Iterator
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Literal

SOURCE_REPO = "phanlemanh/repo-standards"
TAG_PREFIX = "repo-setup-v"
ARCHIVE_URL = "https://codeload.github.com/{repo}/tar.gz/refs/tags/{tag}"
FETCH_TIMEOUT = 30  # seconds, for the archive and for the list of tags
PLUGIN_DIR = ("plugins", "repo-setup")
VERSION = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
ENTRY = re.compile(r"^" + re.escape(TAG_PREFIX) + r"(\d+\.\d+\.\d+)(\.tar\.gz)?$")


class BaseUnreadable(Exception):
    """A release's templates could not be read; the message says why."""


@dataclass(frozen=True)
class Base:
    status: Literal["found", "no_match", "unread"]
    content: bytes | None = None
    version: str | None = None
    reason: str = ""


def version_key(version: str) -> tuple[int, int, int] | None:
    m = VERSION.match(version)
    return (int(m.group(1)), int(m.group(2)), int(m.group(3))) if m else None


def _newest_first(versions: set[str]) -> list[str]:
    known = [v for v in versions if version_key(v) is not None]
    return sorted(known, key=lambda v: version_key(v) or (0, 0, 0), reverse=True)


def released_versions(base_from: Path | None) -> list[str]:
    """The released versions, newest first: those in `base_from`, or the source's tags."""
    if base_from is not None:
        if not base_from.is_dir():
            raise BaseUnreadable(f"{base_from} is not a folder")
        return _newest_first({m.group(1) for p in base_from.iterdir() if (m := ENTRY.match(p.name))})
    url = f"https://github.com/{SOURCE_REPO}.git"
    try:
        out = subprocess.run(
            ["git", "ls-remote", "--tags", url, f"refs/tags/{TAG_PREFIX}*"],
            capture_output=True, text=True, timeout=FETCH_TIMEOUT, check=True,
        ).stdout
    except (OSError, subprocess.SubprocessError) as exc:
        raise BaseUnreadable(f"cannot list the releases of {SOURCE_REPO}: {exc}") from exc
    tags = {line.split("refs/tags/")[-1].removesuffix("^{}") for line in out.splitlines()}
    return _newest_first({t.removeprefix(TAG_PREFIX) for t in tags if t.startswith(TAG_PREFIX)})


def _plugin_part(name: str) -> PurePosixPath | None:
    """The path of an archive entry inside plugins/repo-setup/, or None for anything else."""
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts:
        return None
    parts = path.parts
    for i in range(len(parts) - 1):
        if parts[i : i + 2] == PLUGIN_DIR and len(parts) > i + 2:
            return PurePosixPath(*parts[i + 2 :])
    return None


def _extract(archive: Path, dest: Path) -> None:
    """Regular files under plugins/repo-setup/ only, each checked to land inside `dest`."""
    root = dest.resolve()
    try:
        with tarfile.open(archive, "r:gz") as tar:
            for member in tar:
                if not member.isfile():
                    continue
                rel = _plugin_part(member.name)
                if rel is None:
                    continue
                target = (dest / rel).resolve()
                if not target.is_relative_to(root):
                    continue
                source = tar.extractfile(member)
                if source is None:
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.read())
    except (tarfile.TarError, EOFError, OSError, zlib.error) as exc:
        raise BaseUnreadable(f"cannot read {archive.name}: {exc}") from exc


def _download(version: str, archive: Path) -> None:
    url = ARCHIVE_URL.format(repo=SOURCE_REPO, tag=TAG_PREFIX + version)
    try:
        with urllib.request.urlopen(url, timeout=FETCH_TIMEOUT) as resp:  # noqa: S310 (fixed https URL)
            archive.write_bytes(resp.read())
    except (urllib.error.URLError, OSError, ValueError) as exc:
        raise BaseUnreadable(f"cannot download {url}: {exc}") from exc


def plugin_root_for(version: str, base_from: Path | None, workdir: Path) -> Path:
    """The plugins/repo-setup folder of a release: from `base_from` (a folder per release, or an
    archive per release), or downloaded from the source's tag into `workdir`."""
    name = TAG_PREFIX + version
    if base_from is not None and (base_from / name).is_dir():
        folder = base_from / name
    else:
        if base_from is not None:
            archive = base_from / f"{name}.tar.gz"
            if not archive.is_file():
                raise BaseUnreadable(f"{base_from} has no {name} (folder or .tar.gz)")
        else:
            workdir.mkdir(parents=True, exist_ok=True)
            archive = workdir / f"{name}.tar.gz"
            _download(version, archive)
        folder = workdir / name
        shutil.rmtree(folder, ignore_errors=True)
        folder.mkdir(parents=True)
        _extract(archive, folder)
    if not (folder / ".claude-plugin" / "plugin.json").is_file():
        raise BaseUnreadable(f"{name} has no plugins/repo-setup/.claude-plugin/plugin.json")
    return folder


class BaseFinder:
    """Finds the base of each file. Each release is read and rendered at most once."""

    def __init__(
        self,
        render: Callable[[Path], dict[str, bytes]],
        current_root: Path,
        current_version: str,
        base_from: Path | None,
        workdir: Path,
    ) -> None:
        self._render = render
        self._current_root = current_root
        self._current_version = current_version
        self._base_from = base_from
        self._workdir = workdir
        self._files: dict[str, dict[str, bytes] | str] = {}
        self._released: list[str] | str | None = None

    def _files_of(self, key: str, root: Callable[[], Path]) -> dict[str, bytes] | str:
        """The rendered files of one source, or why they could not be had."""
        if key not in self._files:
            try:
                self._files[key] = self._render(root())
            except BaseUnreadable as exc:
                self._files[key] = str(exc)
            except (KeyError, OSError, ValueError) as exc:
                self._files[key] = f"cannot render the templates of {key}: {exc}"
        return self._files[key]

    def _older(self, version: str) -> Iterator[str]:
        if self._released is None:
            try:
                self._released = released_versions(self._base_from)
            except BaseUnreadable as exc:
                self._released = str(exc)
        if isinstance(self._released, str):
            return
        floor = version_key(version)
        for v in self._released:
            key = version_key(v)
            if floor is None or (key is not None and key < floor):
                yield v

    def _candidates(self, version: str) -> Iterator[tuple[str, str, Callable[[], Path]]]:
        """(cache key, version, root) in the order they are tried."""
        if version == self._current_version:
            yield "local", version, lambda: self._current_root
        yield version, version, lambda: plugin_root_for(version, self._base_from, self._workdir)
        for v in self._older(version):
            yield v, v, lambda v=v: plugin_root_for(v, self._base_from, self._workdir)

    def find(self, path: str, recorded_hash: str, recorded_version: str) -> Base:
        reasons: list[str] = []
        read_any = False
        for key, version, root in self._candidates(recorded_version):
            files = self._files_of(key, root)
            if isinstance(files, str):
                reasons.append(files)
                continue
            read_any = True
            content = files.get(path)
            if content is not None and hashlib.sha256(content).hexdigest() == recorded_hash:
                return Base("found", content, version)
        if read_any:
            return Base("no_match", reason="no release gives the content recorded for it")
        if isinstance(self._released, str):
            reasons.append(self._released)
        return Base("unread", reason=reasons[0] if reasons else "no release to read")

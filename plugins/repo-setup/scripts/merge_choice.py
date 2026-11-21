"""The merge method a team repository's policy gets when the setup first writes the key.

`governance/autonomy.yaml` stores `merge_method`, and `tools/github_setup.py` sets that one method
on GitHub. A repository that exists already merges one way or the other, so the setup does not
choose for it. In this order:

1. the policy is where the choice is made: a method it names stays as it is, and an option that
   says otherwise is refused, as `tools/github_setup.py` refuses one;
2. `--var merge_method=...` says it for a policy that names none;
3. what an earlier run chose and the manifest kept;
4. the repository's own history: a merge commit among the last commits of the branch means it
   keeps merge commits. A repository with no commit, or a folder with no repository of its own,
   gets squash, which is what a new repository gets. A shallow history that shows no merge commit
   cannot be read (git hides the parents of its last commits): the run asks for the word.

Only the Python standard library and git are used (Python 3.11+).
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

METHODS = ("squash", "merge")
DEFAULT = "squash"
POLICY = "governance/autonomy.yaml"
# How far back the branch is read. Enough to see how a repository merges today, and short
# enough that an old habit it has left does not decide.
LOOK_BACK = 20
GIT_TIMEOUT = 30  # seconds
_STORED = re.compile(r"^merge_method:[ \t]*[\"']?([A-Za-z_-]+)[\"']?[ \t]*(?:#.*)?$", re.M)


def stored(target: Path) -> str | None:
    """The method the repository's policy names, or None: no policy, no key, or a value that is
    not a method (the policy check of the repository says that one)."""
    try:
        text = (target / POLICY).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    found = _STORED.search(text)
    return found.group(1) if found and found.group(1) in METHODS else None


def _git(target: Path, *args: str) -> str | None:
    """What git prints, or None when it cannot answer (no git, no repository, no commit)."""
    try:
        done = subprocess.run(["git", "-C", str(target), *args], capture_output=True, text=True,
                              timeout=GIT_TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout.strip() if done.returncode == 0 else None


def _is_own_repository(target: Path) -> bool:
    """The folder is the root of a repository. Inside another repository git answers for that
    one, whose history is not this folder's."""
    top = _git(target, "rev-parse", "--show-toplevel")
    try:
        return top is not None and Path(top).resolve() == target.resolve()
    except OSError:
        return False


def from_history(target: Path) -> str | None:
    """merge when one of the last commits of the branch is a merge commit, else squash. None when
    the history is shallow and shows no merge commit: it cannot be told."""
    if not _is_own_repository(target):
        return DEFAULT
    listed = _git(target, "rev-list", "--first-parent", "--parents",
                  f"--max-count={LOOK_BACK}", "HEAD")
    if listed is None:
        return DEFAULT
    # each line is a commit followed by its parents: three names or more is a merge commit
    if any(len(line.split()) > 2 for line in listed.splitlines()):
        return "merge"
    if _git(target, "rev-parse", "--is-shallow-repository") == "true":
        return None
    return DEFAULT


def decide(target: Path, asked: str | None, remembered: str | None) -> str:
    """The method for this run. `asked` is `--var merge_method` of this run, `remembered` what the
    manifest kept. Raises ValueError with what to do when the run must not go on."""
    if asked is not None and asked not in METHODS:
        raise ValueError(f"--var merge_method={asked} is not one of {', '.join(METHODS)}")
    named = stored(target)
    if named is not None:
        if asked is not None and asked != named:
            raise ValueError(
                f"{POLICY} says merge_method: {named}, and --var merge_method asks for {asked}. "
                f"The choice is stored in the policy: a person changes merge_method in {POLICY}, "
                "in a pull request of its own."
            )
        return named
    if asked is not None:
        return asked
    if remembered in METHODS:
        return str(remembered)
    seen = from_history(target)
    if seen is None:
        raise ValueError(
            "cannot tell how this repository merges pull requests: its git history is shallow "
            "and shows no merge commit. Say it: --var merge_method=squash or "
            "--var merge_method=merge (or fetch the history first: git fetch --unshallow)."
        )
    return seen

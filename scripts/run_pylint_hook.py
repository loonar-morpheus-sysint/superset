#!/usr/bin/env python3
"""Custom pylint hook runner used by pre-commit.

This script mirrors the previous shell-based hook logic but ensures pylint
runs inside a managed virtualenv with the required dependencies.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Sequence


def _run(cmd: Sequence[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(  # noqa: S603  # trusted input
        cmd,
        check=check,
        text=True,
        capture_output=True,
    )


def _print_process_output(proc: subprocess.CompletedProcess[str]) -> None:
    if proc.stdout:
        sys.stdout.write(proc.stdout)
    if proc.stderr:
        sys.stderr.write(proc.stderr)


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    target_branch = os.environ.get("GITHUB_BASE_REF", "master")

    fetch_proc = _run(["git", "fetch", "origin", target_branch], check=False)
    _print_process_output(fetch_proc)
    if fetch_proc.returncode != 0:
        return fetch_proc.returncode

    base_proc = _run(
        ["git", "merge-base", f"origin/{target_branch}", "HEAD"], check=False
    )
    _print_process_output(base_proc)
    if base_proc.returncode != 0:
        return base_proc.returncode
    base_commit = base_proc.stdout.strip()

    diff_proc = _run(
        [
            "git",
            "diff",
            "--name-only",
            "--diff-filter=ACM",
            f"{base_commit}..HEAD",
        ],
        check=False,
    )
    if diff_proc.returncode != 0:
        _print_process_output(diff_proc)
        return diff_proc.returncode

    files = [
        path
        for path in diff_proc.stdout.splitlines()
        if path.startswith("superset/") and path.endswith(".py")
    ]

    if not files:
        print("No Superset Python files to lint; skipping pylint hook.")
        return 0

    env = os.environ.copy()
    existing_path = env.get("PYTHONPATH", "")
    env["PYTHONPATH"] = (
        f"{repo_root}{os.pathsep}{existing_path}" if existing_path else str(repo_root)
    )

    pylint_cmd = [
        sys.executable,
        "-m",
        "pylint",
        "--rcfile=.pylintrc",
        "--load-plugins=superset_pylint_plugin",
        "--reports=no",
        *files,
    ]
    result = subprocess.run(  # noqa: S603  # trusted args
        pylint_cmd,
        cwd=repo_root,
        env=env,
        check=False,
    )
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())

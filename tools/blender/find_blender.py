"""Locate a Blender executable without hardcoding a user-specific version path."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parent.parent
CONFIG_NAMES = ("config.local.json", "config.json")
PATH_FILE = TOOLS_DIR / "blender.path"


def repo_root() -> Path:
    return REPO_ROOT


def find_blender() -> Path:
    """Return the Blender executable path or raise FileNotFoundError."""
    env = os.environ.get("HODL_BLENDER") or os.environ.get("BLENDER_PATH")
    if env:
        candidate = Path(env).expanduser()
        if candidate.is_file():
            return candidate.resolve()
        if candidate.is_dir():
            exe = _exe_in_dir(candidate)
            if exe:
                return exe

    for name in CONFIG_NAMES:
        cfg_path = TOOLS_DIR / name
        if not cfg_path.is_file():
            continue
        data = json.loads(cfg_path.read_text(encoding="utf-8"))
        raw = data.get("blender_exe") or data.get("blender") or ""
        if raw:
            candidate = Path(str(raw)).expanduser()
            if not candidate.is_absolute():
                candidate = (REPO_ROOT / candidate).resolve()
            if candidate.is_file():
                return candidate

    if PATH_FILE.is_file():
        line = PATH_FILE.read_text(encoding="utf-8").strip().splitlines()[0].strip()
        if line and not line.startswith("#"):
            candidate = Path(line).expanduser()
            if candidate.is_file():
                return candidate.resolve()

    which = shutil.which("blender") or shutil.which("blender.exe")
    if which:
        return Path(which).resolve()

    where = _where_blender()
    if where:
        return where

    scanned = _scan_typical_install_dirs()
    if scanned:
        return scanned

    raise FileNotFoundError(
        "Blender executable not found. Install Blender, add it to PATH, set "
        "HODL_BLENDER, or create tools/blender/config.local.json with "
        '{"blender_exe": "C:/Path/to/blender.exe"}.'
    )


def blender_version(exe: Path | None = None) -> str:
    path = exe or find_blender()
    try:
        proc = subprocess.run(
            [str(path), "--version"],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except OSError:
        return "unknown"
    line = (proc.stdout or proc.stderr or "").splitlines()
    return line[0].strip() if line else "unknown"


def _exe_in_dir(directory: Path) -> Path | None:
    for name in ("blender.exe", "blender"):
        candidate = directory / name
        if candidate.is_file():
            return candidate.resolve()
    return None


def _where_blender() -> Path | None:
    if os.name != "nt":
        return None
    try:
        proc = subprocess.run(
            ["where", "blender"],
            check=False,
            capture_output=True,
            text=True,
            timeout=15,
        )
    except OSError:
        return None
    for line in (proc.stdout or "").splitlines():
        candidate = Path(line.strip())
        if candidate.is_file():
            return candidate.resolve()
    return None


def _scan_typical_install_dirs() -> Path | None:
    roots: list[Path] = []
    for key in ("ProgramFiles", "ProgramFiles(x86)", "LOCALAPPDATA"):
        value = os.environ.get(key)
        if value:
            roots.append(Path(value))
    roots.append(Path.home() / "AppData" / "Local")

    found: list[Path] = []
    extra_roots = []
    for root in roots:
        extra_roots.append(root / "Blender Foundation")
        extra_roots.append(root / "Programs")
        extra_roots.append(root / "Programs" / "Blender Foundation")
    for root in extra_roots:
        if not root.is_dir():
            continue
        try:
            for exe in root.rglob("blender.exe"):
                found.append(exe)
        except OSError:
            continue

    if not found:
        return None
    found.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return found[0].resolve()

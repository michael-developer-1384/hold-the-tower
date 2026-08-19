"""HODL THE TOWER — Blender asset build entry.

Run from repo root or this folder:

    python tools/blender/generate_assets.py
    python tools/blender/generate_assets.py sentry

Invokes Blender in background. Does not open the UI.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from find_blender import blender_version, find_blender, repo_root  # noqa: E402

HERO_GENERATORS = {
    "sentry": HERE / "towers" / "generate_sentry.py",
    "guard_post": HERE / "towers" / "generate_guard_post.py",
    "guard": HERE / "characters" / "generate_guard.py",
    "meltdown": HERE / "towers" / "generate_meltdown.py",
    "bot": HERE / "characters" / "generate_bot.py",
}
GENERATORS = {
    **HERO_GENERATORS,
    "env": HERE / "environment" / "generate_env.py",
    "shaft": HERE / "environment" / "generate_shaft_modules.py",
}


def in_blender() -> bool:
    try:
        import bpy  # noqa: F401
        return True
    except ImportError:
        return False


def run_inside_blender(assets: list[str]) -> int:
    # Blender already launched this file; execute generators directly.
    sys.path.insert(0, str(HERE))
    if "all" in assets:
        assets = list(HERO_GENERATORS.keys())
    for name in assets:
        script = GENERATORS.get(name)
        if script is None:
            print(f"unknown asset '{name}'. known: {', '.join(GENERATORS)}")
            return 2
        ns = {"__name__": "__not_main__", "__file__": str(script)}
        code = script.read_text(encoding="utf-8")
        exec(compile(code, str(script), "exec"), ns)
        if "build" in ns:
            ns["build"]()
        else:
            print(f"{name}: no build() in generator")
            return 1
    return 0


def run_via_subprocess(assets: list[str]) -> int:
    exe = find_blender()
    print(f"Blender: {exe}")
    print(f"Version: {blender_version(exe)}")
    cmd = [str(exe), "--background", "--python", str(HERE / "generate_assets.py"), "--", *assets]
    print(" ".join(cmd))
    proc = subprocess.run(cmd, cwd=str(repo_root()))
    return int(proc.returncode)


def parse_assets(argv: list[str]) -> list[str]:
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    skip_next = False
    assets: list[str] = []
    blender_flags = {"--background", "-b", "--factory-startup", "--python-exit-code"}
    for a in argv:
        if skip_next:
            skip_next = False
            continue
        if a in {"--python", "-P"}:
            skip_next = True
            continue
        if a in blender_flags or a.startswith("-"):
            continue
        if a.endswith(".py"):
            continue
        assets.append(a)
    return assets or ["sentry"]


def main(argv: list[str]) -> int:
    assets = parse_assets(argv)
    if in_blender():
        return run_inside_blender(assets)
    return run_via_subprocess(assets)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

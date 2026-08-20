"""Shaft-specific environment modules for vertical_shaft_target_slice.

Run via: python tools/blender/generate_assets.py shaft
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from common import geometry as geo  # noqa: E402
from common import hodl_kit as kit  # noqa: E402
from common import materials as mats  # noqa: E402
from common import scene_utils as su  # noqa: E402
from environment import env_kit as ek  # noqa: E402


def build() -> dict:
    results = {}
    for name, fn in _ASSETS:
        su.reset_scene()
        pal = mats.create_env_palette()
        fn(pal)
        walk = name in {"path_ramp_3m", "core_terminus", "spawn_arch"}
        if walk:
            tri_max = ek.ENV_TRI_MAX
        elif name == "hero_machine_core":
            tri_max = ek.PROP_TRI_MAX
        else:
            tri_max = ek.BG_TRI_MAX
        results[name] = ek.export_asset(name, tri_max=tri_max, params={"kit": "shaft_environment"})
    return results


def _root(name: str = "Module") -> bpy.types.Object:
    return su.new_empty(name, location=(0.0, 0.0, 0.0), size=0.12)


def _shaft_wall_module(pal: dict) -> None:
    """20 m wide x 18 m tall machine wall. Origin at bottom center, +Y forward."""
    root = _root("ShaftWall")
    w, h, d = 20.0, 18.0, 1.4
    body = geo.chamfered_box(
        "WallBody",
        (w, d, h),
        min(w, h, d) * 0.015,
        location=(0.0, 0.0, h * 0.5),
        parent=root,
        material=pal["mass"],
    )
    ek.finish(body, 0.02, 1)
    for i, x in enumerate((-7.0, -2.5, 2.5, 7.0)):
        rib = geo.chamfered_box(
            f"Rib{i}",
            (0.28, d + 0.12, h * 0.96),
            0.03,
            location=(x, 0.0, h * 0.5),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(rib, 0.01, 1)
    for i, (x, z) in enumerate(((-5.5, 4.0), (5.5, 10.0))):
        door = geo.chamfered_box(
            f"ServiceDoor{i}",
            (2.2, 0.18, 3.4),
            0.04,
            location=(x, d * 0.52, z),
            parent=root,
            material=pal["painted"],
        )
        ek.finish(door, 0.008, 1)
        frame = geo.chamfered_box(
            f"DoorFrame{i}",
            (2.35, 0.08, 3.55),
            0.02,
            location=(x, d * 0.48, z),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(frame, 0.006, 1)
        lamp = geo.cube(
            f"DoorLamp{i}",
            (0.08, 0.06, 0.04),
            location=(x + 0.9, d * 0.55, z + 1.6),
            parent=root,
            material=pal["heat"],
        )
        su.shade_smooth(lamp, 40.0)
    for i, (x, z) in enumerate(((-8.0, 14.0), (8.0, 7.0))):
        fan = geo.cylinder(
            f"Fan{i}",
            radius=0.85,
            depth=0.22,
            segments=12,
            location=(x, d * 0.55, z),
            rotation=(math.pi * 0.5, 0.0, 0.0),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(fan, 0.008, 1)
        hub = geo.cylinder(
            f"FanHub{i}",
            radius=0.18,
            depth=0.12,
            segments=8,
            location=(x, d * 0.62, z),
            rotation=(math.pi * 0.5, 0.0, 0.0),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(hub, 0.004, 1)
    for i in range(5):
        z = 2.0 + i * 3.2
        strip = geo.cube(
            f"MaintStrip{i}",
            (w * 0.82, 0.04, 0.06),
            location=(0.0, d * 0.52, z),
            parent=root,
            material=pal["mint"] if i % 3 == 0 else pal["exposed"],
        )
        su.shade_smooth(strip, 40.0)
    tray = kit.add_pipe(
        "CableTray",
        [(-9.0, d * 0.6, 2.0), (-9.0, d * 0.6, 16.0), (9.0, d * 0.6, 16.0)],
        radius=0.06,
        parent=root,
        material=pal["rubber"],
    )
    su.shade_smooth(tray, 40.0)


def _vertical_power_spine(pal: dict) -> None:
    """25 m vertical conduit / pipe / cable block. Origin at base."""
    root = _root("PowerSpine")
    h = 25.0
    core = geo.chamfered_box(
        "SpineCore",
        (1.6, 1.2, h),
        0.06,
        location=(0.0, 0.0, h * 0.5),
        parent=root,
        material=pal["mass"],
    )
    ek.finish(core, 0.02, 1)
    for i in range(8):
        z = 1.5 + i * 2.8
        ring = geo.chamfered_box(
            f"SpineRing{i}",
            (2.0, 1.6, 0.14),
            0.02,
            location=(0.0, 0.0, z),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(ring, 0.008, 1)
    for i, (x, r) in enumerate(((-0.55, 0.22), (0.55, 0.18), (0.0, 0.14))):
        pipe = geo.cylinder(
            f"SpinePipe{i}",
            radius=r,
            depth=h * 0.88,
            segments=10,
            location=(x, 0.35 if i == 2 else 0.0, h * 0.5),
            parent=root,
            material=pal["painted"] if i % 2 else pal["structural"],
        )
        ek.finish(pipe, 0.01, 1)
    for i in range(6):
        z = 3.0 + i * 3.5
        led = geo.cube(
            f"StatusLed{i}",
            (0.06, 0.04, 0.04),
            location=(0.85, 0.62, z),
            parent=root,
            material=pal["mint"] if i % 2 == 0 else pal["heat"],
        )
        su.shade_smooth(led, 40.0)
    cable = kit.add_pipe(
        "SpineCable",
        [(0.9, 0.0, 2.0), (1.8, 0.4, 8.0), (1.2, -0.3, 18.0)],
        radius=0.05,
        parent=root,
        material=pal["rubber"],
    )
    su.shade_smooth(cable, 40.0)


def _platform_support_frame(pal: dict) -> None:
    """8 m service frame for upper platform anchoring. Origin at top walk level."""
    root = _root("PlatformSupportFrame")
    h = 8.0
    span = 3.2
    for i, x in enumerate((-span * 0.5, span * 0.5)):
        leg = geo.chamfered_box(
            f"FrameLeg{i}",
            (0.18, 0.18, h),
            0.02,
            location=(x, 0.0, -h * 0.5),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(leg, 0.008, 1)
    for i, z in enumerate((-1.5, -3.5, -5.5, -7.0)):
        beam = geo.chamfered_box(
            f"FrameBeam{i}",
            (span + 0.2, 0.12, 0.12),
            0.012,
            location=(0.0, 0.0, z),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(beam, 0.006, 1)
        brace = geo.chamfered_box(
            f"FrameBrace{i}",
            (0.08, 1.4, 0.08),
            0.008,
            location=(0.0, 0.0, z - 0.6),
            rotation=(0.35, 0.0, 0.0),
            parent=root,
            material=pal["painted"],
        )
        ek.finish(brace, 0.004, 1)
    cap = geo.chamfered_box(
        "FrameCap",
        (span + 0.5, span * 0.6, 0.14),
        0.015,
        location=(0.0, 0.0, 0.06),
        parent=root,
        material=pal["deck"],
    )
    ek.finish(cap, 0.006, 1)
    for i, sx in enumerate((-1, 1)):
        rod = geo.cylinder(
            f"HangRod{i}",
            radius=0.035,
            depth=2.2,
            segments=8,
            location=(sx * span * 0.35, 0.0, -1.1),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(rod, 0.003, 1)


def _industrial_column(pal: dict) -> None:
    """12 m modular pillar. Origin at top anchor (walk surface)."""
    root = _root("IndustrialColumn")
    h = 12.0
    shaft = geo.chamfered_box(
        "ColShaft",
        (0.55, 0.55, h),
        0.04,
        location=(0.0, 0.0, -h * 0.5),
        parent=root,
        material=pal["mass"],
    )
    ek.finish(shaft, 0.015, 1)
    for i in range(5):
        z = -1.2 - i * 2.2
        band = geo.chamfered_box(
            f"ColBand{i}",
            (0.72, 0.72, 0.12),
            0.015,
            location=(0.0, 0.0, z),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(band, 0.006, 1)
    foot = geo.chamfered_box(
        "ColFoot",
        (1.1, 1.1, 0.22),
        0.025,
        location=(0.0, 0.0, -h + 0.11),
        parent=root,
        material=pal["painted"],
    )
    ek.finish(foot, 0.01, 1)
    cap = geo.chamfered_box(
        "ColCap",
        (0.85, 0.85, 0.16),
        0.02,
        location=(0.0, 0.0, -0.08),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(cap, 0.008, 1)
    for i, sy in enumerate((-0.28, 0.28)):
        stiff = geo.chamfered_box(
            f"Stiffener{i}",
            (0.06, 0.06, h * 0.7),
            0.004,
            location=(0.0, sy, -h * 0.38),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(stiff, 0.003, 1)


def _hero_machine_core(pal: dict) -> None:
    """22 m vertical power/data column — scene-scale hero. Origin at base."""
    root = _root("HeroMachineCore")
    h = 22.0
    body = geo.chamfered_box(
        "CoreBody",
        (2.8, 2.4, h),
        0.08,
        location=(0.0, 0.0, h * 0.5),
        parent=root,
        material=pal["mass"],
    )
    ek.finish(body, 0.025, 1)
    for i in range(7):
        z = 1.8 + i * 2.8
        seg = geo.chamfered_box(
            f"CoreSeg{i}",
            (3.0, 2.6, 0.22),
            0.02,
            location=(0.0, 0.0, z),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(seg, 0.01, 1)
        if i % 2 == 0:
            glow = geo.cube(
                f"CoreGlow{i}",
                (0.08, 2.0, 0.04),
                location=(1.46, 0.0, z + 0.5),
                parent=root,
                material=pal["heat"],
            )
            su.shade_smooth(glow, 40.0)
        status = geo.cube(
            f"CoreStatus{i}",
            (0.05, 0.05, 0.05),
            location=(-1.4, 1.22, z + 0.3),
            parent=root,
            material=pal["mint"] if i % 3 == 0 else pal["exposed"],
        )
        su.shade_smooth(status, 40.0)
    coil = geo.cylinder(
        "CoreCoil",
        radius=0.65,
        depth=3.2,
        segments=16,
        location=(0.0, 1.35, 11.0),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=root,
        material=pal["heat"],
    )
    su.shade_smooth(coil, 45.0)
    collar = geo.cylinder(
        "CoreCollar",
        radius=0.95,
        depth=0.28,
        segments=16,
        location=(0.0, 1.22, 11.0),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(collar, 0.01, 1)
    for i in range(4):
        a = i * math.pi * 0.5 + 0.2
        conduit = kit.add_pipe(
            f"CoreConduit{i}",
            [
                (math.cos(a) * 1.5, math.sin(a) * 1.5, 4.0 + i * 2.0),
                (math.cos(a) * 2.8, math.sin(a) * 2.8, 8.0 + i * 1.5),
            ],
            radius=0.08,
            parent=root,
            material=pal["structural"],
        )
        su.shade_smooth(conduit, 40.0)
    crown = geo.chamfered_box(
        "CoreCrown",
        (1.8, 1.8, 0.5),
        0.04,
        location=(0.0, 0.0, h - 0.25),
        parent=root,
        material=pal["painted"],
    )
    ek.finish(crown, 0.012, 1)


def _path_ramp_3m(pal: dict) -> None:
    """3 m run, 3 m rise — matches TestLevelFactory vertical ramps. Origin at downhill end, +Y uphill."""
    root = _root("PathRamp3")
    run = 3.0
    rise = 3.0
    angle = math.atan2(rise, run)
    length = math.hypot(run, rise)
    mid_y = run * 0.5
    mid_z = rise * 0.5
    deck = geo.cube(
        "RampDeck",
        (0.98, length, 0.09),
        location=(0.0, mid_y, mid_z),
        rotation=(angle, 0.0, 0.0),
        parent=root,
        material=pal["structural"],
    )
    ek.finish(deck, 0.008, 1)
    panel = geo.cube(
        "RampPanel",
        (0.90, length * 0.96, 0.018),
        location=(0.0, mid_y, mid_z + 0.05),
        rotation=(angle, 0.0, 0.0),
        parent=root,
        material=pal["deck"],
    )
    ek.finish(panel, 0.003, 1)
    for i, sx in enumerate((-1.0, 1.0)):
        rail = geo.cube(
            f"RampRail{i}",
            (0.045, length, 0.08),
            location=(sx * 0.48, mid_y, mid_z + 0.02),
            rotation=(angle, 0.0, 0.0),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(rail, 0.0015, 1)
    for i in range(4):
        t = i / 3.0
        y = t * run
        z = t * rise - 0.18
        rib = geo.chamfered_box(
            f"RampRib{i}",
            (0.88, 0.06, 0.12),
            0.008,
            location=(0.0, y, z),
            rotation=(angle, 0.0, 0.0),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(rib, 0.004, 1)
    led = geo.cube(
        "RampLed",
        (0.012, length * 0.8, 0.006),
        location=(0.4, mid_y, mid_z + 0.04),
        rotation=(angle, 0.0, 0.0),
        parent=root,
        material=pal["mint"],
    )
    su.shade_smooth(led, 40.0)
    for i, sy in enumerate((0.4, 1.5, 2.6)):
        hang = geo.chamfered_box(
            f"RampHang{i}",
            (0.08, 0.08, 0.55),
            0.008,
            location=(0.0, sy, sy * (rise / run) - 0.45),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(hang, 0.004, 1)


def _core_terminus(pal: dict) -> None:
    """Walk-origin industrial goal. Not a glowing sphere."""
    root = _root("CoreTerminus")
    pad = geo.chamfered_box(
        "CorePad",
        (1.15, 1.15, 0.08),
        0.012,
        location=(0.0, 0.0, 0.04),
        parent=root,
        material=pal["structural"],
    )
    ek.finish(pad, 0.006, 1)
    body = geo.chamfered_box(
        "CoreBody",
        (0.72, 0.72, 0.95),
        0.03,
        location=(0.0, 0.0, 0.56),
        parent=root,
        material=pal["mass"],
    )
    ek.finish(body, 0.01, 1)
    collar = geo.cylinder(
        "CoreCollar",
        radius=0.28,
        depth=0.18,
        segments=14,
        location=(0.0, 0.0, 1.08),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(collar, 0.006, 1)
    dome = geo.cylinder(
        "CoreDome",
        radius=0.22,
        depth=0.16,
        segments=14,
        radius2=0.08,
        location=(0.0, 0.0, 1.22),
        parent=root,
        material=pal["heat"],
    )
    su.shade_smooth(dome, 45.0)
    for i in range(4):
        a = i * math.pi * 0.5
        rib = geo.chamfered_box(
            f"CoreRib{i}",
            (0.08, 0.08, 0.7),
            0.008,
            location=(math.cos(a) * 0.38, math.sin(a) * 0.38, 0.5),
            parent=root,
            material=pal["painted"],
        )
        ek.finish(rib, 0.004, 1)
    slit = geo.cube(
        "CoreSlit",
        (0.08, 0.04, 0.22),
        location=(0.0, 0.38, 0.62),
        parent=root,
        material=pal["heat"],
    )
    su.shade_smooth(slit, 40.0)
    status = geo.cube(
        "CoreStatus",
        (0.04, 0.04, 0.04),
        location=(0.28, 0.38, 0.92),
        parent=root,
        material=pal["mint"],
    )
    su.shade_smooth(status, 40.0)
    cable = kit.add_pipe(
        "CoreFeed",
        [(0.45, 0.0, 0.2), (0.85, 0.0, 0.35), (0.85, 0.0, 0.7)],
        radius=0.035,
        parent=root,
        material=pal["rubber"],
    )
    su.shade_smooth(cable, 40.0)


def _spawn_arch(pal: dict) -> None:
    """Walk-origin maintenance gate. Local +Y / Godot -Z is exit along the path."""
    root = _root("SpawnArch")
    for i, sx in enumerate((-1.0, 1.0)):
        post = geo.chamfered_box(
            f"Post{i}",
            (0.14, 0.18, 1.45),
            0.016,
            location=(sx * 0.62, 0.0, 0.72),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(post, 0.006, 1)
        foot = geo.chamfered_box(
            f"Foot{i}",
            (0.22, 0.26, 0.08),
            0.012,
            location=(sx * 0.62, 0.0, 0.04),
            parent=root,
            material=pal["painted"],
        )
        ek.finish(foot, 0.004, 1)
    lintel = geo.chamfered_box(
        "Lintel",
        (1.42, 0.18, 0.14),
        0.016,
        location=(0.0, 0.0, 1.48),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(lintel, 0.006, 1)
    lamp = geo.cube(
        "ArchLamp",
        (0.16, 0.08, 0.05),
        location=(0.0, 0.12, 1.38),
        parent=root,
        material=pal["heat"],
    )
    su.shade_smooth(lamp, 40.0)
    strip = geo.cube(
        "ArchStrip",
        (1.1, 0.03, 0.02),
        location=(0.0, 0.1, 1.55),
        parent=root,
        material=pal["mint"],
    )
    su.shade_smooth(strip, 40.0)


_ASSETS = [
    ("shaft_wall_module", _shaft_wall_module),
    ("vertical_power_spine", _vertical_power_spine),
    ("platform_support_frame", _platform_support_frame),
    ("industrial_column", _industrial_column),
    ("hero_machine_core", _hero_machine_core),
    ("path_ramp_3m", _path_ramp_3m),
    ("core_terminus", _core_terminus),
    ("spawn_arch", _spawn_arch),
]


if __name__ == "__main__":
    build()

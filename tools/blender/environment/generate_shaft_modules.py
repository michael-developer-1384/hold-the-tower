"""Shaft-specific environment modules for vertical_shaft_target_slice.

Run via: python tools/blender/generate_assets.py shaft
"""

from __future__ import annotations

import math
import os
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
    wanted = None
    extra = os.environ.get("SHAFT_ASSETS", "").strip()
    if extra:
        wanted = {n.strip() for n in extra.split(",") if n.strip()}
    results = {}
    for name, fn in _ASSETS:
        if wanted is not None and name not in wanted:
            continue
        su.reset_scene()
        pal = mats.create_env_palette()
        fn(pal)
        walk = name in {"path_ramp_3m", "core_terminus", "spawn_arch"}
        if walk:
            tri_max = ek.ENV_TRI_MAX
        elif name == "hero_machine_core":
            tri_max = ek.PROP_TRI_MAX
        elif name in {"service_light_bar", "service_light_pod"}:
            tri_max = 800
        elif name.startswith("shaft_shell_") or name in {
            "cable_trunk_vertical",
            "vent_cluster_large",
            "background_service_deck",
            "background_bridge_short",
        }:
            tri_max = ek.ENV_TRI_MAX
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


def _shaft_shell_frame_large(pal: dict) -> None:
    """Open 26 m structural frame. Origin at base center. Look-through lattice, not a wall."""
    root = _root("ShaftShellFrame")
    h = 26.0
    span = 2.6
    posts = ((-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0))
    for i, (sx, sy) in enumerate(posts):
        geo.cube(
            f"FramePost{i}",
            (0.24, 0.24, h),
            location=(sx * span * 0.5, sy * span * 0.5, h * 0.5),
            parent=root,
            material=pal["structural"],
        )
    for ri, z in enumerate((3.0, 10.0, 17.0, 24.2)):
        for j, (dx, dy, sx, sy) in enumerate((
            (0.0, -span * 0.5, span + 0.24, 0.1),
            (0.0, span * 0.5, span + 0.24, 0.1),
            (-span * 0.5, 0.0, 0.1, span + 0.24),
            (span * 0.5, 0.0, 0.1, span + 0.24),
        )):
            geo.cube(
                f"Ring{ri}_{j}",
                (sx, sy, 0.12),
                location=(dx, dy, z),
                parent=root,
                material=pal["exposed"] if ri % 2 else pal["painted"],
            )
    for bi, z in enumerate((6.5, 20.5)):
        geo.cube(
            f"Brace{bi}",
            (span * 1.2, 0.08, 0.08),
            location=(0.0, 0.0, z),
            rotation=(0.0, 0.0, 0.55),
            parent=root,
            material=pal["structural"],
        )
    geo.cube(
        "FrameFoot",
        (span + 0.55, span + 0.55, 0.2),
        location=(0.0, 0.0, 0.1),
        parent=root,
        material=pal["mass"],
    )
    geo.cube(
        "FrameCap",
        (span * 0.65, span * 0.65, 0.14),
        location=(0.0, 0.0, h - 0.07),
        parent=root,
        material=pal["painted"],
    )
    led = geo.cube(
        "FrameLed",
        (0.05, 0.04, 2.0),
        location=(span * 0.5 + 0.16, 0.0, 8.0),
        parent=root,
        material=pal["window"],
    )
    su.shade_smooth(led, 40.0)


def _shaft_shell_wall_segment(pal: dict) -> None:
    """Partial 11 x 15 m wall with large openings. Origin at base center, +Y forward."""
    root = _root("ShaftShellWall")
    w, h, d = 11.0, 15.0, 0.55
    for i, sx in enumerate((-1.0, 1.0)):
        post = geo.chamfered_box(
            f"WallPost{i}",
            (0.38, d + 0.12, h),
            0.03,
            location=(sx * (w * 0.5 - 0.2), 0.0, h * 0.5),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(post, 0.012, 1)
    for i, z in enumerate((1.1, 7.5, 14.2)):
        beam = geo.chamfered_box(
            f"WallBeam{i}",
            (w - 0.2, 0.18, 0.28),
            0.02,
            location=(0.0, -0.08, z),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(beam, 0.008, 1)
    # Two offset cladding patches — leave a large negative in the middle.
    left = geo.chamfered_box(
        "PanelLeft",
        (3.4, 0.16, 5.6),
        0.02,
        location=(-2.6, d * 0.35, 4.4),
        parent=root,
        material=pal["mass"],
    )
    ek.finish(left, 0.008, 1)
    right = geo.chamfered_box(
        "PanelRight",
        (3.6, 0.16, 6.2),
        0.02,
        location=(2.4, d * 0.35, 10.2),
        parent=root,
        material=pal["mass"],
    )
    ek.finish(right, 0.008, 1)
    door = geo.chamfered_box(
        "ServiceDoor",
        (1.8, 0.12, 2.8),
        0.03,
        location=(-2.4, d * 0.52, 3.2),
        parent=root,
        material=pal["painted"],
    )
    ek.finish(door, 0.006, 1)
    fan = geo.cylinder(
        "WallFan",
        radius=0.7,
        depth=0.16,
        segments=10,
        location=(2.6, d * 0.55, 10.4),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=root,
        material=pal["structural"],
    )
    ek.finish(fan, 0.006, 1)
    hub = geo.cylinder(
        "WallFanHub",
        radius=0.16,
        depth=0.1,
        segments=8,
        location=(2.6, d * 0.62, 10.4),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(hub, 0.004, 1)
    for i in range(3):
        rib = geo.chamfered_box(
            f"WallRib{i}",
            (0.12, d + 0.08, h * 0.72),
            0.01,
            location=(-1.2 + i * 1.4, 0.0, h * 0.48),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(rib, 0.005, 1)
    tray = kit.add_pipe(
        "WallTray",
        [(-5.0, d * 0.7, 6.0), (5.0, d * 0.7, 6.0)],
        radius=0.05,
        parent=root,
        material=pal["rubber"],
    )
    su.shade_smooth(tray, 40.0)
    strip = geo.cube(
        "WallStrip",
        (4.2, 0.03, 0.05),
        location=(0.2, d * 0.58, 7.6),
        parent=root,
        material=pal["window"],
    )
    su.shade_smooth(strip, 40.0)


def _shaft_shell_bay_open(pal: dict) -> None:
    """Open machine bay niche ~6 x 8 m. Origin at floor center, +Y is the open face."""
    root = _root("ShaftShellBay")
    w, h, depth = 6.0, 8.0, 2.4
    floor = geo.chamfered_box(
        "BayFloor",
        (w, depth, 0.16),
        0.02,
        location=(0.0, -depth * 0.35, 0.08),
        parent=root,
        material=pal["deck"],
    )
    ek.finish(floor, 0.008, 1)
    ceil = geo.chamfered_box(
        "BayCeil",
        (w, depth * 0.7, 0.12),
        0.015,
        location=(0.0, -depth * 0.4, h - 0.06),
        parent=root,
        material=pal["structural"],
    )
    ek.finish(ceil, 0.006, 1)
    back = geo.chamfered_box(
        "BayBack",
        (w - 0.4, 0.18, h * 0.72),
        0.02,
        location=(0.0, -depth * 0.82, h * 0.42),
        parent=root,
        material=pal["mass"],
    )
    ek.finish(back, 0.008, 1)
    for i, sx in enumerate((-1.0, 1.0)):
        side = geo.chamfered_box(
            f"BaySide{i}",
            (0.18, depth * 0.85, h * 0.9),
            0.02,
            location=(sx * (w * 0.5 - 0.1), -depth * 0.32, h * 0.45),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(side, 0.008, 1)
    unit = geo.chamfered_box(
        "BayUnit",
        (2.2, 1.1, 2.4),
        0.04,
        location=(0.6, -depth * 0.55, 1.4),
        parent=root,
        material=pal["painted"],
    )
    ek.finish(unit, 0.01, 1)
    coil = geo.cylinder(
        "BayCoil",
        radius=0.38,
        depth=1.1,
        segments=10,
        location=(-1.4, -depth * 0.4, 2.2),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(coil, 0.008, 1)
    lamp = geo.cube(
        "BayLamp",
        (1.6, 0.08, 0.06),
        location=(0.0, -0.2, h - 0.28),
        parent=root,
        material=pal["window"],
    )
    su.shade_smooth(lamp, 40.0)
    status = geo.cube(
        "BayStatus",
        (0.05, 0.04, 0.05),
        location=(1.55, -depth * 0.2, 2.4),
        parent=root,
        material=pal["heat"],
    )
    su.shade_smooth(status, 40.0)


def _cable_trunk_vertical(pal: dict) -> None:
    """Slim 22 m cable/pipe trunk. Origin at base."""
    root = _root("CableTrunk")
    h = 22.0
    pipes = ((-0.18, 0.0, 0.16), (0.16, 0.08, 0.22), (0.02, -0.16, 0.12))
    for i, (x, y, r) in enumerate(pipes):
        pipe = geo.cylinder(
            f"TrunkPipe{i}",
            radius=r,
            depth=h * 0.96,
            segments=8,
            location=(x, y, h * 0.48),
            parent=root,
            material=pal["painted"] if i == 1 else pal["structural"],
        )
        ek.finish(pipe, 0.008, 1)
    for i in range(6):
        z = 1.6 + i * 3.4
        clamp = geo.chamfered_box(
            f"TrunkClamp{i}",
            (0.62, 0.52, 0.12),
            0.015,
            location=(0.0, 0.0, z),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(clamp, 0.006, 1)
    cable = kit.add_pipe(
        "TrunkCable",
        [(0.32, 0.12, 1.0), (0.55, 0.28, 8.0), (0.28, -0.1, 18.0)],
        radius=0.04,
        parent=root,
        material=pal["rubber"],
    )
    su.shade_smooth(cable, 40.0)
    for i in range(4):
        led = geo.cube(
            f"TrunkLed{i}",
            (0.04, 0.03, 0.04),
            location=(0.32, 0.22, 3.0 + i * 4.5),
            parent=root,
            material=pal["mint"] if i % 2 == 0 else pal["window"],
        )
        su.shade_smooth(led, 40.0)


def _service_light_bar(pal: dict) -> None:
    """Cold maintenance LED bar. Origin at mount center, +Y faces the lit side."""
    root = _root("ServiceLightBar")
    housing = geo.chamfered_box(
        "BarHousing",
        (2.4, 0.1, 0.08),
        0.01,
        location=(0.0, -0.02, 0.0),
        parent=root,
        material=pal["structural"],
    )
    ek.finish(housing, 0.004, 1)
    lens = geo.cube(
        "BarLens",
        (2.2, 0.04, 0.045),
        location=(0.0, 0.05, 0.0),
        parent=root,
        material=pal["window"],
    )
    su.shade_smooth(lens, 40.0)
    for i, sx in enumerate((-1.0, 1.0)):
        mount = geo.chamfered_box(
            f"BarMount{i}",
            (0.08, 0.12, 0.1),
            0.008,
            location=(sx * 1.05, -0.08, 0.0),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(mount, 0.003, 1)


def _service_light_pod(pal: dict) -> None:
    """Small maintenance pod. Origin at wall mount, +Y faces out."""
    root = _root("ServiceLightPod")
    body = geo.chamfered_box(
        "PodBody",
        (0.16, 0.12, 0.12),
        0.012,
        location=(0.0, 0.0, 0.0),
        parent=root,
        material=pal["structural"],
    )
    ek.finish(body, 0.004, 1)
    lens = geo.cylinder(
        "PodLens",
        radius=0.055,
        depth=0.04,
        segments=10,
        location=(0.0, 0.08, 0.0),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=root,
        material=pal["window"],
    )
    su.shade_smooth(lens, 40.0)
    guard = geo.chamfered_box(
        "PodGuard",
        (0.2, 0.04, 0.04),
        0.006,
        location=(0.0, 0.1, 0.06),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(guard, 0.002, 1)


def _vent_cluster_large(pal: dict) -> None:
    """Larger 3-fan vent bay. Origin at face center, +Y forward."""
    root = _root("VentClusterLarge")
    plate = geo.chamfered_box(
        "VentPlate",
        (3.6, 0.12, 1.6),
        0.02,
        location=(0.0, 0.0, 0.0),
        parent=root,
        material=pal["mass"],
    )
    ek.finish(plate, 0.008, 1)
    for i, x in enumerate((-1.15, 0.0, 1.15)):
        fan = geo.cylinder(
            f"VentFan{i}",
            radius=0.48,
            depth=0.16,
            segments=10,
            location=(x, 0.1, 0.0),
            rotation=(math.pi * 0.5, 0.0, 0.0),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(fan, 0.006, 1)
        hub = geo.cylinder(
            f"VentHub{i}",
            radius=0.12,
            depth=0.08,
            segments=8,
            location=(x, 0.16, 0.0),
            rotation=(math.pi * 0.5, 0.0, 0.0),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(hub, 0.003, 1)
    grill = geo.chamfered_box(
        "VentGrill",
        (3.5, 0.04, 0.06),
        0.008,
        location=(0.0, 0.12, 0.68),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(grill, 0.003, 1)


def _background_service_deck(pal: dict) -> None:
    """Fragmentary 3.4 m catwalk niche. Origin at deck surface center."""
    root = _root("BackgroundServiceDeck")
    deck = geo.chamfered_box(
        "DeckSlab",
        (3.4, 1.35, 0.1),
        0.015,
        location=(0.0, 0.0, -0.05),
        parent=root,
        material=pal["deck"],
    )
    ek.finish(deck, 0.006, 1)
    for i, sx in enumerate((-1.0, 1.0)):
        rail = geo.chamfered_box(
            f"DeckRail{i}",
            (3.2, 0.04, 0.06),
            0.008,
            location=(0.0, sx * 0.62, 0.42),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(rail, 0.003, 1)
        for j, x in enumerate((-1.3, 0.0, 1.3)):
            post = geo.chamfered_box(
                f"DeckPost{i}_{j}",
                (0.04, 0.04, 0.48),
                0.006,
                location=(x, sx * 0.62, 0.2),
                parent=root,
                material=pal["structural"],
            )
            ek.finish(post, 0.002, 1)
    lip = geo.chamfered_box(
        "DeckLip",
        (3.5, 1.45, 0.05),
        0.008,
        location=(0.0, 0.0, -0.12),
        parent=root,
        material=pal["structural"],
    )
    ek.finish(lip, 0.004, 1)
    crate = geo.chamfered_box(
        "DeckCrate",
        (0.45, 0.38, 0.32),
        0.02,
        location=(1.1, 0.1, 0.12),
        parent=root,
        material=pal["painted"],
    )
    ek.finish(crate, 0.006, 1)


def _background_bridge_short(pal: dict) -> None:
    """Short 5 m background bridge. Origin at span center, deck at Z=0."""
    root = _root("BackgroundBridgeShort")
    span = 5.0
    deck = geo.chamfered_box(
        "BridgeDeck",
        (span, 0.85, 0.08),
        0.012,
        location=(0.0, 0.0, -0.04),
        parent=root,
        material=pal["deck"],
    )
    ek.finish(deck, 0.006, 1)
    for i, sx in enumerate((-1.0, 1.0)):
        beam = geo.chamfered_box(
            f"BridgeBeam{i}",
            (span + 0.2, 0.1, 0.16),
            0.012,
            location=(0.0, sx * 0.42, -0.18),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(beam, 0.006, 1)
        rail = geo.chamfered_box(
            f"BridgeRail{i}",
            (span, 0.04, 0.05),
            0.006,
            location=(0.0, sx * 0.4, 0.38),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(rail, 0.003, 1)
    for i in range(4):
        x = -1.8 + i * 1.2
        truss = geo.chamfered_box(
            f"BridgeTruss{i}",
            (0.06, 0.7, 0.06),
            0.006,
            location=(x, 0.0, -0.35),
            rotation=(0.4, 0.0, 0.0),
            parent=root,
            material=pal["painted"],
        )
        ek.finish(truss, 0.003, 1)
    for i, sx in enumerate((-1.0, 1.0)):
        hang = geo.cylinder(
            f"BridgeHang{i}",
            radius=0.03,
            depth=1.4,
            segments=8,
            location=(sx * 1.8, 0.0, 0.7),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(hang, 0.002, 1)


_ASSETS = [
    ("shaft_wall_module", _shaft_wall_module),
    ("vertical_power_spine", _vertical_power_spine),
    ("platform_support_frame", _platform_support_frame),
    ("industrial_column", _industrial_column),
    ("hero_machine_core", _hero_machine_core),
    ("path_ramp_3m", _path_ramp_3m),
    ("core_terminus", _core_terminus),
    ("spawn_arch", _spawn_arch),
    ("shaft_shell_frame_large", _shaft_shell_frame_large),
    ("shaft_shell_wall_segment", _shaft_shell_wall_segment),
    ("shaft_shell_bay_open", _shaft_shell_bay_open),
    ("cable_trunk_vertical", _cable_trunk_vertical),
    ("service_light_bar", _service_light_bar),
    ("service_light_pod", _service_light_pod),
    ("vent_cluster_large", _vent_cluster_large),
    ("background_service_deck", _background_service_deck),
    ("background_bridge_short", _background_bridge_short),
]


if __name__ == "__main__":
    build()

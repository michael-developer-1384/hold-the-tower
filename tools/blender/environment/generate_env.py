"""HODL environment kit — walkways, pads, supports, background modules, props.

Run via: python tools/blender/generate_assets.py env
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
        tri_max = ek.ENV_TRI_MAX
        if name.startswith(("server_", "industrial_", "utility_", "power_", "data_", "pipe_", "vent_", "support_frame")):
            tri_max = ek.BG_TRI_MAX
        if name.startswith("prop_"):
            tri_max = ek.PROP_TRI_MAX
        results[name] = ek.export_asset(name, tri_max=tri_max, params={"kit": "environment"})
    return results


def _root(name: str = "Module") -> bpy.types.Object:
    return su.new_empty(name, location=(0.0, 0.0, 0.0), size=0.12)


def _path_straight(pal: dict) -> None:
    root = _root("PathStraight")
    ek.standard_walkway("Path", size_x=1.0, size_y=1.0, pal=pal, parent=root)


def _path_corner(pal: dict) -> None:
    root = _root("PathCorner")
    ek.standard_walkway("ArmY", size_x=1.0, size_y=0.62, pal=pal, parent=root, location=(0.0, 0.19, 0.0))
    ek.standard_walkway(
        "ArmX",
        size_x=0.62,
        size_y=1.0,
        pal=pal,
        parent=root,
        location=(0.19, 0.0, 0.0),
        long_axis="x",
    )
    cap = geo.chamfered_box(
        "CornerCap",
        (0.22, 0.22, 0.07),
        0.01,
        location=(0.32, 0.32, -0.04),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(cap, 0.004, 1)


def _path_outer_corner(pal: dict) -> None:
    """1x1 convex corner: continuous L-rail on +X/+Y (drops down), open butts on -X/-Y."""
    root = _root("PathOuterCorner")
    ek.walk_surface_slab(
        "PathSlab",
        size_x=1.0,
        size_y=1.0,
        thickness=0.09,
        pal=pal,
        parent=root,
    )
    ek.deck_panels("Path", size_x=1.0, size_y=1.0, pal=pal, parent=root)
    ek.outer_corner_rail("Path", pal=pal, parent=root)
    ek.undercarriage("Path", size_x=1.0, size_y=1.0, pal=pal, parent=root)
    ek.bolt_row("Path", count=4, span=0.7, pal=pal, parent=root, location=(0.0, 0.0, 0.01))


def _path_ramp(pal: dict) -> None:
    """4 m run, 3 m rise. Origin at downhill end, +Y uphill, walk Z=0 at start."""
    root = _root("PathRamp")
    run = 4.0
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
    for i in range(5):
        t = i / 4.0
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


def _path_bridge(pal: dict) -> None:
    root = _root("PathBridge")
    ek.standard_walkway("Deck", size_x=1.0, size_y=3.0, pal=pal, parent=root)
    for i, sy in enumerate((-1.2, 0.0, 1.2)):
        truss = geo.chamfered_box(
            f"Truss{i}",
            (0.06, 0.08, 0.42),
            0.008,
            location=(0.0, sy, -0.38),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(truss, 0.004, 1)
    lower = geo.chamfered_box(
        "LowerChord",
        (0.08, 2.7, 0.07),
        0.008,
        location=(0.0, 0.0, -0.58),
        parent=root,
        material=pal["structural"],
    )
    ek.finish(lower, 0.004, 1)
    for i, sx in enumerate((-1.0, 1.0)):
        brace = geo.chamfered_box(
            f"Brace{i}",
            (0.04, 2.4, 0.04),
            0.004,
            location=(sx * 0.22, 0.0, -0.4),
            rotation=(0.35 if sx < 0 else -0.35, 0.0, 0.0),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(brace, 0.002, 1)


def _platform_large(pal: dict) -> None:
    root = _root("PlatformLarge")
    ek.standard_walkway("Plat", size_x=4.0, size_y=3.0, pal=pal, parent=root)
    # extra ribs via second undercarriage offset
    ek.undercarriage("PlatB", size_x=3.6, size_y=2.6, pal=pal, parent=root, rib_count=5)
    for i, pos in enumerate(((-1.4, -1.1), (1.4, -1.1), (-1.4, 1.1), (1.4, 1.1))):
        vent = geo.chamfered_box(
            f"Vent{i}",
            (0.28, 0.22, 0.08),
            0.01,
            location=(pos[0], pos[1], -0.04),
            parent=root,
            material=pal["painted"],
        )
        ek.finish(vent, 0.003, 1)
        kit.vent_slots(vent, (0.0, 0.0, 0.02), count=3, size=(0.18, 0.03, 0.02), dz=0.028)


def _build_pad(pal: dict, *, state: str) -> None:
    """Layered pad: slab → recessed well → raised annular ring. No coplanar tops."""
    from common import modifiers as mods

    root = _root("BuildPad")
    ek.walk_surface_slab("PadSlab", size_x=1.0, size_y=1.0, thickness=0.08, pal=pal, parent=root)
    ring_mat = pal["mint"] if state == "recommended" else pal["exposed"] if state == "empty" else pal["rubber"]
    # Dark well sits on the slab, clearly below the light ring top.
    well = geo.regular_ngon_prism(
        "PadWell",
        radius=0.36,
        height=0.008,
        sides=8,
        bottom_z=0.002,
        parent=root,
        material=pal["deck"] if state != "occupied" else pal["structural"],
    )
    # Light finish only — avoid heavy bevel that expands into the ring.
    ek.finish(well, 0.0015, 1)
    # Raised light ring as a true annulus (solid minus inner cut) so it cannot z-fight the well.
    ring = geo.regular_ngon_prism(
        "PadRing",
        radius=0.46,
        height=0.016,
        sides=8,
        bottom_z=0.012,
        parent=root,
        material=ring_mat,
    )
    cutter = geo.regular_ngon_prism(
        "PadRingCut",
        radius=0.365,
        height=0.04,
        sides=8,
        bottom_z=0.0,
        parent=root,
        material=ring_mat,
    )
    mods.boolean_difference(ring, cutter, apply_now=True, delete_cutter=True)
    ek.finish(ring, 0.002, 1)
    groove = geo.cylinder(
        "PadGroove",
        radius=0.28,
        depth=0.005,
        segments=24,
        location=(0.0, 0.0, 0.008),
        parent=root,
        material=pal["rubber"],
    )
    su.shade_smooth(groove, 40.0)
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        mount = geo.cube(
            f"Mount{i}",
            (0.08, 0.08, 0.028),
            location=(sx * 0.38, sy * 0.38, 0.02),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(mount, 0.0015, 1)
        bolt = geo.hex_bolt(
            f"PadBolt{i}",
            radius=0.012,
            height=0.008,
            location=(sx * 0.38, sy * 0.38, 0.038),
            parent=root,
            material=pal["exposed"],
        )
        su.shade_smooth(bolt, 40.0)
    if state == "recommended":
        tick = geo.cube(
            "RecommendTick",
            (0.42, 0.012, 0.006),
            location=(0.0, 0.0, 0.03),
            parent=root,
            material=pal["mint"],
        )
        su.shade_smooth(tick, 40.0)
    if state == "occupied":
        seat = geo.regular_ngon_prism(
            "OccupiedSeat",
            radius=0.22,
            height=0.01,
            sides=8,
            bottom_z=0.018,
            parent=root,
            material=pal["structural"],
        )
        ek.finish(seat, 0.002, 1)


def _build_pad_empty(pal: dict) -> None:
    _build_pad(pal, state="empty")


def _build_pad_recommended(pal: dict) -> None:
    _build_pad(pal, state="recommended")


def _build_pad_occupied(pal: dict) -> None:
    _build_pad(pal, state="occupied")


def _support_column(pal: dict) -> None:
    """Hangs down 3 m from walk surface origin. Uniform dark — no bright rings/caps."""
    root = _root("SupportColumn")
    dark = pal["structural"]
    col = geo.cylinder(
        "Column",
        radius=0.09,
        depth=2.85,
        segments=12,
        location=(0.0, 0.0, -1.5),
        parent=root,
        material=dark,
    )
    ek.finish(col, 0.008, 1)
    cap = geo.chamfered_box(
        "Cap",
        (0.28, 0.28, 0.07),
        0.01,
        location=(0.0, 0.0, -0.05),
        parent=root,
        material=dark,
    )
    ek.finish(cap, 0.004, 1)
    foot = geo.chamfered_box(
        "Foot",
        (0.32, 0.32, 0.08),
        0.012,
        location=(0.0, 0.0, -2.95),
        parent=root,
        material=dark,
    )
    ek.finish(foot, 0.006, 1)
    # Subtle same-material bands only — no exposed/bright joins.
    for i, z in enumerate((-0.55, -1.5, -2.45)):
        ring = geo.cylinder(
            f"ColRing{i}",
            radius=0.105,
            depth=0.04,
            segments=12,
            location=(0.0, 0.0, z),
            parent=root,
            material=dark,
        )
        ek.finish(ring, 0.003, 1)


def _support_suspension(pal: dict) -> None:
    root = _root("SupportSuspension")
    beam = geo.chamfered_box(
        "HangBeam",
        (0.12, 1.6, 0.12),
        0.012,
        location=(0.0, 0.0, 1.35),
        parent=root,
        material=pal["structural"],
    )
    ek.finish(beam, 0.005, 1)
    for i, sy in enumerate((-0.55, 0.55)):
        rod = geo.cylinder(
            f"Rod{i}",
            radius=0.025,
            depth=1.25,
            segments=8,
            location=(0.0, sy, 0.7),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(rod, 0.003, 1)
        clamp = geo.chamfered_box(
            f"Clamp{i}",
            (0.16, 0.16, 0.07),
            0.008,
            location=(0.0, sy, 0.08),
            parent=root,
            material=pal["painted"],
        )
        ek.finish(clamp, 0.003, 1)


def _box_building(
    name: str,
    *,
    size: tuple[float, float, float],
    pal: dict,
    parent: bpy.types.Object,
    location=(0.0, 0.0, 0.0),
    windows: int = 4,
    rows: int = 6,
    warm_every: int = 5,
) -> bpy.types.Object:
    body = geo.chamfered_box(
        name,
        size,
        min(size) * 0.02,
        location=location,
        parent=parent,
        material=pal["mass"],
    )
    ek.finish(body, 0.02, 1)
    sx, sy, sz = size
    lx, ly, lz = location
    for row in range(rows):
        zy = lz - sz * 0.42 + (row + 0.5) * (sz * 0.8 / rows)
        for col in range(windows):
            wx = lx - sx * 0.38 + (col + 0.5) * (sx * 0.76 / windows)
            warm = ((row + col) % warm_every) == 0
            ek.window_strip(
                f"{name}W{row}_{col}",
                size=(sx * 0.12, 0.04, sz * 0.06),
                pal=pal,
                parent=parent,
                location=(wx, ly + sy * 0.51, zy),
                warm=warm,
            )
    return body


def _server_block(pal: dict) -> None:
    root = _root("ServerBlock")
    _box_building("Server", size=(4.0, 3.2, 8.0), pal=pal, parent=root, location=(0.0, 0.0, 4.0), windows=5, rows=8)
    crown = geo.chamfered_box(
        "Crown",
        (3.2, 2.4, 0.4),
        0.04,
        location=(0.0, 0.0, 8.15),
        parent=root,
        material=pal["structural"],
    )
    ek.finish(crown, 0.01, 1)
    dish = geo.cylinder(
        "Array",
        radius=0.45,
        depth=0.12,
        segments=12,
        location=(0.0, 0.0, 8.45),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(dish, 0.006, 1)
    led = geo.cube("Beacon", (0.08, 0.08, 0.12), location=(0.0, 0.0, 8.6), parent=root, material=pal["mint"])
    su.shade_smooth(led, 40.0)


def _industrial_stack(pal: dict) -> None:
    root = _root("IndustrialStack")
    for i, (r, h, z, x) in enumerate(((0.7, 9.0, 4.5, -0.9), (0.5, 7.2, 3.6, 0.6), (0.35, 5.5, 2.75, 1.4))):
        stack = geo.cylinder(
            f"Stack{i}",
            radius=r,
            depth=h,
            segments=14,
            location=(x, 0.0, z),
            parent=root,
            material=pal["mass"],
        )
        ek.finish(stack, 0.02, 1)
        band = geo.cylinder(
            f"Band{i}",
            radius=r + 0.06,
            depth=0.18,
            segments=14,
            location=(x, 0.0, z + h * 0.28),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(band, 0.008, 1)
    glow = geo.cylinder(
        "StackGlow",
        radius=0.42,
        depth=0.2,
        segments=12,
        location=(-0.9, 0.0, 9.05),
        parent=root,
        material=pal["heat"],
    )
    su.shade_smooth(glow, 50.0)


def _utility_tower(pal: dict) -> None:
    root = _root("UtilityTower")
    shaft = geo.chamfered_box(
        "Shaft",
        (1.4, 1.4, 12.0),
        0.06,
        location=(0.0, 0.0, 6.0),
        parent=root,
        material=pal["mass"],
    )
    ek.finish(shaft, 0.02, 1)
    for i in range(7):
        z = 1.2 + i * 1.5
        ring = geo.chamfered_box(
            f"UtilRing{i}",
            (1.7, 1.7, 0.12),
            0.02,
            location=(0.0, 0.0, z),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(ring, 0.006, 1)
        ek.window_strip(
            f"UtilW{i}",
            size=(0.9, 0.05, 0.35),
            pal=pal,
            parent=root,
            location=(0.0, 0.73, z + 0.4),
            warm=i % 3 == 0,
        )
    mast = geo.cylinder(
        "Mast",
        radius=0.08,
        depth=2.2,
        segments=8,
        location=(0.0, 0.0, 13.1),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(mast, 0.004, 1)


def _power_core_tower(pal: dict) -> None:
    root = _root("PowerCore")
    body = geo.chamfered_box(
        "CoreBody",
        (3.2, 3.2, 7.0),
        0.08,
        location=(0.0, 0.0, 3.5),
        parent=root,
        material=pal["mass"],
    )
    ek.finish(body, 0.025, 1)
    core = geo.cylinder(
        "Core",
        radius=0.85,
        depth=2.4,
        segments=16,
        location=(0.0, 1.7, 3.6),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=root,
        material=pal["heat"],
    )
    su.shade_smooth(core, 40.0)
    collar = geo.cylinder(
        "Collar",
        radius=1.05,
        depth=0.22,
        segments=16,
        location=(0.0, 1.55, 3.6),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(collar, 0.01, 1)
    for i in range(4):
        z = 1.2 + i * 1.4
        ek.window_strip(
            f"PwrW{i}",
            size=(2.2, 0.05, 0.22),
            pal=pal,
            parent=root,
            location=(0.0, -1.64, z),
        )


def _data_center_wall(pal: dict) -> None:
    root = _root("DataWall")
    _box_building(
        "Wall",
        size=(10.0, 1.6, 7.0),
        pal=pal,
        parent=root,
        location=(0.0, 0.0, 3.5),
        windows=9,
        rows=6,
        warm_every=7,
    )
    for i, x in enumerate((-3.5, 0.0, 3.5)):
        rib = geo.chamfered_box(
            f"WallRib{i}",
            (0.22, 1.9, 7.2),
            0.03,
            location=(x, 0.0, 3.5),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(rib, 0.01, 1)


def _pipe_cluster(pal: dict) -> None:
    root = _root("PipeCluster")
    specs = [
        (0.18, 4.5, (-0.4, 0.0, 0.4), (0.0, math.pi * 0.5, 0.0)),
        (0.12, 5.2, (0.15, 0.2, 0.1), (0.0, math.pi * 0.5, 0.0)),
        (0.22, 3.4, (0.55, -0.15, 0.55), (math.pi * 0.5, 0.0, 0.0)),
        (0.1, 2.8, (-0.1, 0.4, 1.4), (0.4, 0.0, 0.2)),
    ]
    for i, (r, d, loc, rot) in enumerate(specs):
        pipe = geo.cylinder(
            f"Pipe{i}",
            radius=r,
            depth=d,
            segments=10,
            location=loc,
            rotation=rot,
            parent=root,
            material=pal["structural"] if i % 2 == 0 else pal["painted"],
        )
        ek.finish(pipe, 0.008, 1)
        flange = geo.cylinder(
            f"Flange{i}",
            radius=r + 0.06,
            depth=0.08,
            segments=10,
            location=loc,
            rotation=rot,
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(flange, 0.004, 1)


def _vent_cluster(pal: dict) -> None:
    root = _root("VentCluster")
    for i, x in enumerate((-0.7, 0.0, 0.7)):
        box = geo.chamfered_box(
            f"VentBox{i}",
            (0.55, 0.7, 0.9),
            0.02,
            location=(x, 0.0, 0.45),
            parent=root,
            material=pal["painted"],
        )
        ek.finish(box, 0.008, 1)
        kit.vent_slots(box, (0.0, 0.36, 0.1), count=4, size=(0.38, 0.05, 0.04), dz=0.12)
        cap = geo.cylinder(
            f"VentCap{i}",
            radius=0.16,
            depth=0.12,
            segments=10,
            location=(x, 0.0, 0.98),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(cap, 0.004, 1)


def _support_frame(pal: dict) -> None:
    root = _root("SupportFrame")
    for i, x in enumerate((-1.4, 1.4)):
        leg = geo.chamfered_box(
            f"Leg{i}",
            (0.16, 0.16, 8.0),
            0.02,
            location=(x, 0.0, 4.0),
            parent=root,
            material=pal["structural"],
        )
        ek.finish(leg, 0.008, 1)
    for i, z in enumerate((1.5, 4.0, 6.5)):
        beam = geo.chamfered_box(
            f"FrameBeam{i}",
            (3.0, 0.14, 0.14),
            0.016,
            location=(0.0, 0.0, z),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(beam, 0.006, 1)
        cross = geo.chamfered_box(
            f"Cross{i}",
            (0.1, 1.8, 0.1),
            0.01,
            location=(0.0, 0.0, z),
            parent=root,
            material=pal["painted"],
        )
        ek.finish(cross, 0.004, 1)


def _prop_reactor(pal: dict) -> None:
    root = _root("PropReactor")
    bowl = geo.cylinder(
        "Bowl",
        radius=1.15,
        depth=0.55,
        segments=20,
        radius2=0.72,
        location=(0.0, 0.0, 0.28),
        parent=root,
        material=pal["structural"],
    )
    ek.finish(bowl, 0.012, 2)
    melt = geo.cylinder(
        "Melt",
        radius=0.78,
        depth=0.22,
        segments=16,
        location=(0.0, 0.0, 0.42),
        parent=root,
        material=pal["heat"],
    )
    su.shade_smooth(melt, 50.0)
    rim = geo.cylinder(
        "Rim",
        radius=1.08,
        depth=0.1,
        segments=20,
        location=(0.0, 0.0, 0.55),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(rim, 0.006, 1)
    for i in range(4):
        a = i * math.pi * 0.5
        strut = geo.chamfered_box(
            f"ReactorStrut{i}",
            (0.14, 0.7, 0.14),
            0.016,
            location=(math.cos(a) * 0.95, math.sin(a) * 0.95, 0.2),
            rotation=(0.0, 0.0, a),
            parent=root,
            material=pal["painted"],
        )
        ek.finish(strut, 0.006, 1)
    pipe = kit.add_pipe(
        "HeatPipe",
        [(0.9, 0.0, 0.35), (1.4, 0.0, 0.55), (1.4, 0.0, 1.4), (0.4, 0.0, 1.7)],
        radius=0.07,
        parent=root,
        material=pal["structural"],
    )
    su.shade_smooth(pipe, 45.0)
    tank = geo.cylinder(
        "SideTank",
        radius=0.28,
        depth=1.1,
        segments=12,
        location=(1.45, 0.0, 1.0),
        parent=root,
        material=pal["painted"],
    )
    ek.finish(tank, 0.008, 1)


def _prop_tank(pal: dict) -> None:
    root = _root("PropTank")
    body = geo.cylinder(
        "TankBody",
        radius=0.85,
        depth=2.4,
        segments=16,
        location=(0.0, 0.0, 1.3),
        parent=root,
        material=pal["painted"],
    )
    ek.finish(body, 0.02, 1)
    for i, z in enumerate((0.25, 1.3, 2.35)):
        band = geo.cylinder(
            f"TankBand{i}",
            radius=0.9,
            depth=0.08,
            segments=16,
            location=(0.0, 0.0, z),
            parent=root,
            material=pal["exposed"],
        )
        ek.finish(band, 0.006, 1)
    cap = geo.cylinder(
        "TankCap",
        radius=0.7,
        depth=0.22,
        segments=16,
        radius2=0.2,
        location=(0.0, 0.0, 2.6),
        parent=root,
        material=pal["structural"],
    )
    ek.finish(cap, 0.01, 1)
    valve = geo.chamfered_box(
        "Valve",
        (0.35, 0.22, 0.28),
        0.02,
        location=(0.95, 0.0, 1.1),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(valve, 0.006, 1)


def _prop_crane(pal: dict) -> None:
    root = _root("PropCrane")
    mast = geo.chamfered_box(
        "CraneMast",
        (0.28, 0.28, 5.5),
        0.03,
        location=(0.0, 0.0, 2.75),
        parent=root,
        material=pal["structural"],
    )
    ek.finish(mast, 0.01, 1)
    boom = geo.chamfered_box(
        "Boom",
        (0.18, 4.2, 0.18),
        0.02,
        location=(0.0, 1.6, 5.35),
        parent=root,
        material=pal["painted"],
    )
    ek.finish(boom, 0.008, 1)
    cable = geo.cylinder(
        "CraneCable",
        radius=0.02,
        depth=1.8,
        segments=6,
        location=(0.0, 3.4, 4.4),
        parent=root,
        material=pal["rubber"],
    )
    su.shade_smooth(cable, 40.0)
    hook = geo.chamfered_box(
        "Hook",
        (0.16, 0.12, 0.28),
        0.02,
        location=(0.0, 3.4, 3.4),
        parent=root,
        material=pal["exposed"],
    )
    ek.finish(hook, 0.006, 1)
    house = geo.chamfered_box(
        "Cab",
        (0.7, 0.9, 0.55),
        0.03,
        location=(0.0, 0.4, 5.15),
        parent=root,
        material=pal["mass"],
    )
    ek.finish(house, 0.01, 1)
    ek.window_strip(
        "CabGlass",
        size=(0.5, 0.04, 0.22),
        pal=pal,
        parent=root,
        location=(0.0, 0.88, 5.2),
        warm=True,
    )


# standard_walkway doesn't take rib_count — wrap for small platform
def _platform_small_fixed(pal: dict) -> None:
    root = _root("PlatformSmall")
    ek.standard_walkway("Plat", size_x=2.0, size_y=2.0, pal=pal, parent=root)
    lip = geo.chamfered_box(
        "Lip",
        (2.08, 2.08, 0.04),
        0.008,
        location=(0.0, 0.0, -0.11),
        parent=root,
        material=pal["painted"],
    )
    ek.finish(lip, 0.004, 1)


_ASSETS = [
    ("path_straight", _path_straight),
    ("path_corner", _path_corner),
    ("path_outer_corner", _path_outer_corner),
    ("path_ramp", _path_ramp),
    ("path_bridge", _path_bridge),
    ("platform_small", _platform_small_fixed),
    ("platform_large", _platform_large),
    ("build_pad_empty", _build_pad_empty),
    ("build_pad_recommended", _build_pad_recommended),
    ("build_pad_occupied", _build_pad_occupied),
    ("support_column", _support_column),
    ("support_suspension", _support_suspension),
    ("server_block", _server_block),
    ("industrial_stack", _industrial_stack),
    ("utility_tower", _utility_tower),
    ("power_core_tower", _power_core_tower),
    ("data_center_wall", _data_center_wall),
    ("pipe_cluster", _pipe_cluster),
    ("vent_cluster", _vent_cluster),
    ("support_frame", _support_frame),
    ("prop_reactor", _prop_reactor),
    ("prop_tank", _prop_tank),
    ("prop_crane", _prop_crane),
]


if __name__ == "__main__":
    build()

"""Shared construction language for walkways, pads, and mega-structure modules."""

from __future__ import annotations

import json
from pathlib import Path

import bpy
from mathutils import Vector

from common import export as ex
from common import geometry as geo
from common import hodl_kit as kit
from common import materials as mats
from common import scene_utils as su

REPO = Path(__file__).resolve().parents[3]
GLB_DIR = REPO / "assets" / "generated" / "environment"
PREVIEW_DIR = REPO / "artifacts" / "visual_previews"

ENV_TRI_MAX = 8000
BG_TRI_MAX = 4000
PROP_TRI_MAX = 9000


def finish(obj: bpy.types.Object, width: float = 0.004, segments: int = 1) -> None:
    kit.finish(obj, width, segments)


def export_asset(name: str, *, tri_max: int, params: dict | None = None) -> dict:
    for obj in su.iter_mesh_objects():
        su.shade_smooth(obj, 32.0)
    stats = su.mesh_stats(su.iter_mesh_objects())
    if stats["triangle_count"] > tri_max:
        raise RuntimeError(f"{name} exceeds tri budget {tri_max}: {stats['triangle_count']}")
    glb = ex.export_glb(GLB_DIR / f"{name}.glb")
    meta = {
        "asset": name,
        "glb": str(glb),
        "params": params or {},
        "blender": bpy.app.version_string,
        **stats,
    }
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    (PREVIEW_DIR / f"{name}_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(
        json.dumps(
            {
                "asset": name,
                "glb": meta["glb"],
                "triangle_count": meta["triangle_count"],
                "vertex_count": meta["vertex_count"],
                "material_count": meta["material_count"],
            }
        )
    )
    return meta


def walk_surface_slab(
    name: str,
    *,
    size_x: float,
    size_y: float,
    thickness: float,
    pal: dict,
    parent: bpy.types.Object,
    location=(0.0, 0.0, 0.0),
) -> bpy.types.Object:
    """Top of slab sits at local Z=0 + location.z."""
    lx, ly, lz = location
    slab = geo.cube(
        name,
        (size_x, size_y, thickness),
        location=(lx, ly, lz - thickness * 0.5),
        parent=parent,
        material=pal["structural"],
    )
    finish(slab, 0.008, 1)
    return slab


def deck_panels(
    prefix: str,
    *,
    size_x: float,
    size_y: float,
    pal: dict,
    parent: bpy.types.Object,
    location=(0.0, 0.0, 0.0),
    inset: float = 0.04,
) -> None:
    lx, ly, lz = location
    inner_x = max(0.18, size_x - inset * 2)
    inner_y = max(0.18, size_y - inset * 2)
    panel = geo.cube(
        f"{prefix}Panel",
        (inner_x, inner_y, 0.018),
        location=(lx, ly, lz + 0.006),
        parent=parent,
        material=pal["deck"],
    )
    finish(panel, 0.003, 1)
    # No center groove — reads as noisy diagonals once path tiles yaw.


def _simple_trim(
    name: str,
    size: tuple[float, float, float],
    *,
    pal: dict,
    parent: bpy.types.Object,
    location,
) -> bpy.types.Object:
    """Single soft bevel — no chamfered_box+finish double facet (reads as vertical Rillen)."""
    trim = geo.cube(name, size, location=location, parent=parent, material=pal["exposed"])
    finish(trim, 0.0015, 1)
    return trim


def edge_trims(
    prefix: str,
    *,
    size_x: float,
    size_y: float,
    pal: dict,
    parent: bpy.types.Object,
    location=(0.0, 0.0, 0.0),
    long_axis: str = "y",
    sides: set[str] | None = None,
    length_scale: float = 0.92,
) -> None:
    """Light edge rails matching ramp language: sit on the outer face and drop downward.

    sides: subset of {'-x','+x','-y','+y'}. Default = both long sides for long_axis.
    length_scale < 1 leaves a small gap at cell butts so neighbor rails do not z-fight.
    """
    lx, ly, lz = location
    if sides is None:
        sides = {"-x", "+x"} if long_axis == "y" else {"-y", "+y"}
    # Same visual weight as RampRail: proud on the vertical face, not a flat top strip.
    trim_w = 0.045
    trim_h = 0.08
    z = lz - 0.02
    edge = 0.02  # outer face at size/2 - edge ≈ 0.48 on a 1 m tile
    if "-x" in sides:
        _simple_trim(
            f"{prefix}TrimNegX",
            (trim_w, size_y * length_scale, trim_h),
            pal=pal,
            parent=parent,
            location=(lx - (size_x * 0.5 - edge), ly, z),
        )
    if "+x" in sides:
        _simple_trim(
            f"{prefix}TrimPosX",
            (trim_w, size_y * length_scale, trim_h),
            pal=pal,
            parent=parent,
            location=(lx + (size_x * 0.5 - edge), ly, z),
        )
    if "-y" in sides:
        _simple_trim(
            f"{prefix}TrimNegY",
            (size_x * length_scale, trim_w, trim_h),
            pal=pal,
            parent=parent,
            location=(lx, ly - (size_y * 0.5 - edge), z),
        )
    if "+y" in sides:
        _simple_trim(
            f"{prefix}TrimPosY",
            (size_x * length_scale, trim_w, trim_h),
            pal=pal,
            parent=parent,
            location=(lx, ly + (size_y * 0.5 - edge), z),
        )


def outer_corner_rail(
    prefix: str,
    *,
    pal: dict,
    parent: bpy.types.Object,
    location=(0.0, 0.0, 0.0),
    size: float = 1.0,
) -> bpy.types.Object:
    """Continuous L-rail on +X/+Y — arms overlap at the convex corner so the frame wraps fully."""
    from common import modifiers as mods

    lx, ly, lz = location
    trim_w = 0.045
    trim_h = 0.08
    z = lz - 0.02
    edge = 0.02
    half = size * 0.5
    outer = half - edge  # 0.48
    # Open-butt inset so we don't clip into connecting tiles.
    butt_inset = 0.04
    # +Y arm: runs to the outer +X face so it owns the corner square.
    arm_y_len = (outer + trim_w * 0.5) - (-half + butt_inset)
    arm_y_cx = ((-half + butt_inset) + (outer + trim_w * 0.5)) * 0.5
    arm_y = _simple_trim(
        f"{prefix}TrimPosY",
        (arm_y_len, trim_w, trim_h),
        pal=pal,
        parent=parent,
        location=(lx + arm_y_cx, ly + outer, z),
    )
    # +X arm: runs up into the +Y arm (overlap) so boolean seals the corner — no dark gap.
    arm_x_len = (outer + trim_w * 0.5) - (-half + butt_inset)
    arm_x_cy = ((-half + butt_inset) + (outer + trim_w * 0.5)) * 0.5
    arm_x = _simple_trim(
        f"{prefix}TrimPosX",
        (trim_w, arm_x_len, trim_h),
        pal=pal,
        parent=parent,
        location=(lx + outer, ly + arm_x_cy, z),
    )
    mods.boolean_union(arm_y, arm_x, apply_now=True, delete_other=True)
    arm_y.name = f"{prefix}OuterRail"
    return arm_y


def corner_trim_caps(
    prefix: str,
    *,
    pal: dict,
    parent: bpy.types.Object,
    location=(0.0, 0.0, 0.0),
    outer_corner: tuple[float, float] | None = None,
    inner_corner: tuple[float, float] | None = None,
    size: float = 0.055,
) -> None:
    """Optional caps — prefer outer_corner_rail for continuous L frames."""
    lx, ly, lz = location
    z = lz - 0.02
    if outer_corner is not None:
        ox, oy = outer_corner
        _simple_trim(
            f"{prefix}OuterCap",
            (size, size, 0.08),
            pal=pal,
            parent=parent,
            location=(lx + ox, ly + oy, z),
        )
    if inner_corner is not None:
        ix, iy = inner_corner
        _simple_trim(
            f"{prefix}InnerCap",
            (size * 0.85, size * 0.85, 0.08),
            pal=pal,
            parent=parent,
            location=(lx + ix, ly + iy, z),
        )


def undercarriage(
    prefix: str,
    *,
    size_x: float,
    size_y: float,
    pal: dict,
    parent: bpy.types.Object,
    location=(0.0, 0.0, 0.0),
    rib_count: int = 3,
) -> None:
    lx, ly, lz = location
    beam_l = geo.chamfered_box(
        f"{prefix}BeamL",
        (0.07, size_y * 0.96, 0.11),
        0.008,
        location=(lx - size_x * 0.38, ly, lz - 0.16),
        parent=parent,
        material=pal["structural"],
    )
    finish(beam_l, 0.004, 1)
    beam_r = geo.chamfered_box(
        f"{prefix}BeamR",
        (0.07, size_y * 0.96, 0.11),
        0.008,
        location=(lx + size_x * 0.38, ly, lz - 0.16),
        parent=parent,
        material=pal["structural"],
    )
    finish(beam_r, 0.004, 1)
    span = size_y * 0.72
    for i in range(rib_count):
        t = 0.0 if rib_count == 1 else (i / (rib_count - 1) - 0.5)
        rib = geo.cube(
            f"{prefix}Rib{i}",
            (size_x * 0.82, 0.045, 0.07),
            location=(lx, ly + t * span, lz - 0.15),
            parent=parent,
            material=pal["structural"],
        )
        finish(rib, 0.002, 1)


def cable_tray(
    prefix: str,
    *,
    size_y: float,
    pal: dict,
    parent: bpy.types.Object,
    location=(0.0, 0.0, 0.0),
) -> None:
    lx, ly, lz = location
    tray = geo.chamfered_box(
        f"{prefix}Tray",
        (0.09, size_y * 0.88, 0.03),
        0.004,
        location=(lx, ly, lz - 0.09),
        parent=parent,
        material=pal["rubber"],
    )
    finish(tray, 0.002, 1)
    led = geo.cube(
        f"{prefix}Led",
        (0.012, size_y * 0.7, 0.006),
        location=(lx, ly, lz - 0.072),
        parent=parent,
        material=pal["mint"],
    )
    su.shade_smooth(led, 40.0)


def bolt_row(
    prefix: str,
    *,
    count: int,
    span: float,
    pal: dict,
    parent: bpy.types.Object,
    location=(0.0, 0.0, 0.0),
    axis: str = "y",
) -> None:
    lx, ly, lz = location
    for i in range(count):
        t = 0.0 if count == 1 else (i / (count - 1) - 0.5)
        pos = (lx, ly + t * span, lz) if axis == "y" else (lx + t * span, ly, lz)
        bolt = geo.hex_bolt(
            f"{prefix}Bolt{i}",
            radius=0.012,
            height=0.01,
            location=pos,
            parent=parent,
            material=pal["exposed"],
        )
        su.shade_smooth(bolt, 40.0)


def standard_walkway(
    prefix: str,
    *,
    size_x: float,
    size_y: float,
    pal: dict,
    parent: bpy.types.Object,
    location=(0.0, 0.0, 0.0),
    long_axis: str = "y",
    sides: set[str] | None = None,
    cable: bool = True,
    trim_length_scale: float = 0.94,
) -> None:
    walk_surface_slab(
        f"{prefix}Slab",
        size_x=size_x,
        size_y=size_y,
        thickness=0.09,
        pal=pal,
        parent=parent,
        location=location,
    )
    deck_panels(prefix, size_x=size_x, size_y=size_y, pal=pal, parent=parent, location=location)
    edge_trims(
        prefix,
        size_x=size_x,
        size_y=size_y,
        pal=pal,
        parent=parent,
        location=location,
        long_axis=long_axis,
        sides=sides,
        length_scale=trim_length_scale,
    )
    undercarriage(prefix, size_x=size_x, size_y=size_y, pal=pal, parent=parent, location=location)
    lx, ly, lz = location
    if cable:
        tray_x = lx + size_x * 0.42
        cable_tray(prefix, size_y=size_y, pal=pal, parent=parent, location=(tray_x, ly, lz))
    bolt_row(
        prefix,
        count=4,
        span=size_y * 0.7,
        pal=pal,
        parent=parent,
        location=(lx, ly, lz + 0.01),
    )


def window_strip(
    name: str,
    *,
    size: tuple[float, float, float],
    pal: dict,
    parent: bpy.types.Object,
    location,
    warm: bool = False,
) -> bpy.types.Object:
    mat = pal["warm_window"] if warm else pal["window"]
    pane = geo.cube(name, size, location=location, parent=parent, material=mat)
    su.shade_smooth(pane, 50.0)
    return pane

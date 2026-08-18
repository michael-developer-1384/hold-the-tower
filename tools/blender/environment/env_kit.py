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
    inset: float = 0.06,
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
    groove = geo.cube(
        f"{prefix}Groove",
        (0.012, inner_y * 0.92, 0.01),
        location=(lx, ly, lz + 0.014),
        parent=parent,
        material=pal["rubber"],
    )
    finish(groove, 0.001, 1)


def edge_trims(
    prefix: str,
    *,
    size_x: float,
    size_y: float,
    pal: dict,
    parent: bpy.types.Object,
    location=(0.0, 0.0, 0.0),
    long_axis: str = "y",
) -> None:
    lx, ly, lz = location
    if long_axis == "y":
        for i, sx in enumerate((-1.0, 1.0)):
            trim = geo.chamfered_box(
                f"{prefix}Trim{i}",
                (0.04, size_y * 0.98, 0.055),
                0.004,
                location=(lx + sx * (size_x * 0.5 - 0.02), ly, lz - 0.02),
                parent=parent,
                material=pal["exposed"],
            )
            finish(trim, 0.002, 1)
        hazard = geo.cube(
            f"{prefix}Hazard",
            (0.028, size_y * 0.9, 0.008),
            location=(lx - size_x * 0.5 + 0.05, ly, lz + 0.01),
            parent=parent,
            material=pal["hazard"],
        )
        finish(hazard, 0.001, 1)
    else:
        for i, sy in enumerate((-1.0, 1.0)):
            trim = geo.chamfered_box(
                f"{prefix}Trim{i}",
                (size_x * 0.98, 0.04, 0.055),
                0.004,
                location=(lx, ly + sy * (size_y * 0.5 - 0.02), lz - 0.02),
                parent=parent,
                material=pal["exposed"],
            )
            finish(trim, 0.002, 1)


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
        rib = geo.chamfered_box(
            f"{prefix}Rib{i}",
            (size_x * 0.82, 0.045, 0.07),
            0.006,
            location=(lx, ly + t * span, lz - 0.15),
            parent=parent,
            material=pal["exposed"],
        )
        finish(rib, 0.003, 1)


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
    )
    undercarriage(prefix, size_x=size_x, size_y=size_y, pal=pal, parent=parent, location=location)
    lx, ly, lz = location
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

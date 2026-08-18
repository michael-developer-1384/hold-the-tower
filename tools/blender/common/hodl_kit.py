"""Shared HODL hard-surface kit: pedestal, neck, pipes, bolts, finish, export."""

from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

from . import export as ex
from . import geometry as geo
from . import materials as mats
from . import modifiers as mods
from . import scene_utils as su

PEDESTAL = {
    "size": 0.70,
    "height": 0.125,
    "inset": 0.048,
    "recess": 0.014,
    "bevel": 0.014,
    "corner_mount": 0.058,
    "small_bevel": 0.0055,
}

TOWER_TRI_MAX = 30000
CHARACTER_TRI_MAX = 12000
ENEMY_BASE_HEIGHT = 0.82


def finish(obj: bpy.types.Object, width: float, segments: int = 3) -> None:
    mods.finish_solid(obj, bevel_width=width, bevel_segments=segments, shade_angle=30.0)


def cut(host: bpy.types.Object, cutter: bpy.types.Object) -> None:
    mods.boolean_difference(host, cutter, apply_now=True, delete_cutter=True, solver="EXACT")


def build_standard_pedestal(base: bpy.types.Object, pal: dict, cfg: dict | None = None) -> float:
    """Identical HODL pad for every tower. Returns pedestal top Z."""
    p = dict(PEDESTAL)
    if cfg:
        p.update(cfg)
    size = p["size"]
    h = p["height"]
    radius = size * 0.5

    deck = geo.regular_ngon_prism(
        "PedestalDeck",
        radius=radius,
        height=h,
        sides=8,
        bottom_z=0.0,
        parent=base,
        material=pal["structural"],
    )
    geo.inset_top_panel(deck, inset=p["inset"], depth=p["recess"])
    finish(deck, p["bevel"], 2)

    inner_r = radius - p["inset"] - 0.012
    plate = geo.regular_ngon_prism(
        "PedestalPanel",
        radius=inner_r,
        height=0.014,
        sides=8,
        bottom_z=h - p["recess"] + 0.001,
        parent=base,
        material=pal["painted"],
    )
    finish(plate, p["small_bevel"], 1)

    groove = geo.cylinder(
        "PedestalGrooveCutter",
        radius=radius * 0.78,
        depth=0.006,
        segments=24,
        location=(0.0, 0.0, h * 0.62),
        material=pal["structural"],
    )
    inner_keep = geo.cylinder(
        "PedestalGrooveKeep",
        radius=radius * 0.70,
        depth=0.02,
        segments=24,
        location=(0.0, 0.0, h * 0.62),
    )
    mods.boolean_difference(groove, inner_keep, apply_now=True, delete_cutter=True)
    cut(deck, groove)

    mount = p["corner_mount"]
    span = radius * 0.72
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        x, y = sx * span, sy * span
        block = geo.chamfered_box(
            f"CornerMount{i}",
            (mount, mount, 0.032),
            0.004,
            location=(x, y, h - 0.002),
            parent=base,
            material=pal["exposed"],
        )
        finish(block, 0.002, 1)
        well = geo.cylinder(
            f"MountWell{i}",
            radius=0.009,
            depth=0.02,
            segments=8,
            location=(x, y, h + 0.024),
        )
        cut(block, well)
        bolt = geo.hex_bolt(
            f"MountBolt{i}",
            radius=0.0075,
            height=0.006,
            location=(x, y, h + 0.018),
            parent=base,
            material=pal["exposed"],
        )
        su.shade_smooth(bolt, 40.0)

    lip = geo.regular_ngon_prism(
        "PedestalLip",
        radius=radius * 0.92,
        height=0.018,
        sides=8,
        bottom_z=0.004,
        parent=base,
        material=pal["rubber"],
    )
    finish(lip, 0.003, 1)
    return h


def build_support_neck(
    parent: bpy.types.Object,
    pal: dict,
    *,
    z0: float,
    z1: float,
    radius: float = 0.062,
    prefix: str = "Neck",
) -> None:
    """Mechanical column from pedestal deck up to yaw machinery."""
    height = max(0.04, z1 - z0)
    mid = z0 + height * 0.5
    col = geo.cylinder(
        f"{prefix}Column",
        radius=radius,
        depth=height,
        segments=16,
        location=(0.0, 0.0, mid),
        parent=parent,
        material=pal["structural"],
    )
    finish(col, 0.006, 2)
    for i, t in enumerate((0.18, 0.5, 0.82)):
        ring = geo.cylinder(
            f"{prefix}Ring{i}",
            radius=radius + 0.018,
            depth=0.018,
            segments=18,
            location=(0.0, 0.0, z0 + height * t),
            parent=parent,
            material=pal["exposed"],
        )
        finish(ring, 0.003, 2)
    for i, ang in enumerate((0.0, math.pi * 0.5, math.pi, math.pi * 1.5)):
        brace = geo.chamfered_box(
            f"{prefix}Brace{i}",
            (0.02, 0.055, height * 0.72),
            0.003,
            location=(math.cos(ang) * (radius + 0.012), math.sin(ang) * (radius + 0.012), mid),
            rotation=(0.0, 0.0, ang),
            parent=parent,
            material=pal["exposed"],
        )
        finish(brace, 0.0024, 2)


def add_pipe(name, points, *, radius, parent, material) -> bpy.types.Object:
    data = bpy.data.curves.new(name, type="CURVE")
    data.dimensions = "3D"
    data.bevel_depth = radius
    data.bevel_resolution = 2
    data.resolution_u = 8
    spline = data.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for i, p in enumerate(points):
        bp = spline.bezier_points[i]
        bp.co = Vector(p)
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"
        bp.handle_left = Vector(p)
        bp.handle_right = Vector(p)
    obj = bpy.data.objects.new(name, data)
    su.link_object(obj)
    su.parent_identity(obj, parent)
    mats.assign(obj, material)
    su.select_only(obj)
    su.object_mode()
    bpy.ops.object.convert(target="MESH")
    su.shade_smooth(obj, 50.0)
    return obj


def vent_slots(host: bpy.types.Object, origin, count: int = 3, size=(0.07, 0.04, 0.011), dz: float = 0.024) -> None:
    ox, oy, oz = origin
    sx, sy, sz = size
    for i in range(count):
        slot = geo.cube(
            f"{host.name}Vent{i}",
            (sx, sy, sz),
            location=(ox, oy, oz + i * dz),
        )
        cut(host, slot)


def finalize_asset(
    *,
    name: str,
    glb_path: Path,
    preview_dir: Path,
    preview_z: float,
    sockets: list[str],
    params: dict,
    tri_max: int,
) -> dict:
    for obj in su.iter_mesh_objects():
        su.shade_smooth(obj, 32.0)
    stats = su.mesh_stats(su.iter_mesh_objects())
    if stats["triangle_count"] > tri_max:
        raise RuntimeError(f"{name} exceeds tri budget {tri_max}: {stats['triangle_count']}")
    glb = ex.export_glb(glb_path)
    previews = ex.render_previews(preview_dir, name, target_z=preview_z)
    bmin = stats["bounds_min"]
    bmax = stats["bounds_max"]
    meta = {
        "asset": name,
        "glb": str(glb),
        "params": params,
        "blender": bpy.app.version_string,
        "previews": previews,
        **stats,
        "height": round(bmax[2] - bmin[2], 4),
        "footprint_xy": [round(max(abs(bmin[0]), abs(bmax[0])) * 2, 4), round(max(abs(bmin[1]), abs(bmax[1])) * 2, 4)],
        "sockets": sockets,
        "forward": "Blender +Y / Godot -Z",
        "up": "Blender +Z / Godot +Y",
    }
    preview_dir.mkdir(parents=True, exist_ok=True)
    (preview_dir / f"{name}_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(
        json.dumps(
            {
                "asset": name,
                "glb": meta["glb"],
                "triangle_count": meta["triangle_count"],
                "vertex_count": meta["vertex_count"],
                "material_count": meta["material_count"],
                "height": meta["height"],
                "blender": meta["blender"],
            },
            indent=2,
        )
    )
    return meta

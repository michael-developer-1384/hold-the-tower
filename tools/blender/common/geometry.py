"""bmesh primitives and authored solids. Primitives are a start; always bevel/boolean after."""

from __future__ import annotations

import math
from typing import Iterable, Sequence

import bmesh
import bpy
from mathutils import Vector

from . import materials as mats
from . import scene_utils as su


def _mesh_from_bmesh(name: str, bm: bmesh.types.BMesh) -> bpy.types.Mesh:
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return mesh


def new_mesh_object(
    name: str,
    mesh: bpy.types.Mesh,
    *,
    location: Iterable[float] = (0.0, 0.0, 0.0),
    rotation: Iterable[float] = (0.0, 0.0, 0.0),
    parent: bpy.types.Object | None = None,
    material: bpy.types.Material | None = None,
) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, mesh)
    obj.location = Vector(location)
    obj.rotation_euler = tuple(rotation)
    su.link_object(obj)
    if parent is not None:
        su.parent_identity(obj, parent)
    if material is not None:
        mats.assign(obj, material)
    return obj


def from_verts_faces(
    name: str,
    verts: Sequence[Sequence[float]],
    faces: Sequence[Sequence[int]],
    **kwargs,
) -> bpy.types.Object:
    bm = bmesh.new()
    bm_verts = [bm.verts.new(Vector(v)) for v in verts]
    bm.verts.ensure_lookup_table()
    for face in faces:
        try:
            bm.faces.new([bm_verts[i] for i in face])
        except ValueError:
            continue
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = _mesh_from_bmesh(name, bm)
    return new_mesh_object(name, mesh, **kwargs)


def cube(
    name: str,
    size: Sequence[float],
    **kwargs,
) -> bpy.types.Object:
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((sx, sy, sz)), verts=bm.verts)
    mesh = _mesh_from_bmesh(name, bm)
    return new_mesh_object(name, mesh, **kwargs)


def cylinder(
    name: str,
    radius: float,
    depth: float,
    *,
    segments: int = 16,
    radius2: float | None = None,
    **kwargs,
) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius if radius2 is None else radius2,
        depth=depth,
    )
    mesh = _mesh_from_bmesh(name, bm)
    return new_mesh_object(name, mesh, **kwargs)


def hex_bolt(
    name: str,
    *,
    radius: float = 0.007,
    height: float = 0.005,
    cap_height: float = 0.0022,
    **kwargs,
) -> bpy.types.Object:
    """Shallow hex cap + tiny shank. Low segment count on purpose."""
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=6,
        radius1=radius,
        radius2=radius,
        depth=cap_height,
    )
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((0.0, 0.0, cap_height * 0.5)))
    shank = bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=8,
        radius1=radius * 0.55,
        radius2=radius * 0.55,
        depth=height,
    )
    bmesh.ops.translate(bm, verts=shank["verts"], vec=Vector((0.0, 0.0, -height * 0.35)))
    mesh = _mesh_from_bmesh(name, bm)
    return new_mesh_object(name, mesh, **kwargs)


def torus_ring(
    name: str,
    *,
    major: float,
    minor: float,
    major_seg: int = 20,
    minor_seg: int = 8,
    **kwargs,
) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_torus(
        bm,
        major_radius=major,
        minor_radius=minor,
        major_segments=major_seg,
        minor_segments=minor_seg,
    )
    mesh = _mesh_from_bmesh(name, bm)
    return new_mesh_object(name, mesh, **kwargs)


def chamfered_box(
    name: str,
    size: Sequence[float],
    chamfer: float,
    *,
    segments: int = 2,
    **kwargs,
) -> bpy.types.Object:
    obj = cube(name, size, **kwargs)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.edges.ensure_lookup_table()
    geom = list(bm.verts) + list(bm.edges)
    offset = min(chamfer, min(size) * 0.35)
    if offset > 1e-5:
        bmesh.ops.bevel(
            bm,
            geom=geom,
            offset=offset,
            offset_type="OFFSET",
            segments=max(1, segments),
            affect="EDGES",
            profile=0.7,
        )
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return obj


def tapered_hull(
    name: str,
    *,
    y_front: float,
    y_back: float,
    half_w_front: float,
    half_w_back: float,
    z_bottom: float,
    z_top_front: float,
    z_top_back: float,
    y_front_top: float | None = None,
    half_w_front_top: float | None = None,
    half_w_back_top: float | None = None,
    **kwargs,
) -> bpy.types.Object:
    """Asymmetric hard-surface block: lower/narrower front, taller/wider rear."""
    yft = y_front if y_front_top is None else y_front_top
    wft = half_w_front if half_w_front_top is None else half_w_front_top
    wbt = half_w_back if half_w_back_top is None else half_w_back_top
    verts = [
        (-half_w_back, y_back, z_bottom),
        (half_w_back, y_back, z_bottom),
        (half_w_front, y_front, z_bottom),
        (-half_w_front, y_front, z_bottom),
        (-wbt, y_back, z_top_back),
        (wbt, y_back, z_top_back),
        (wft, yft, z_top_front),
        (-wft, yft, z_top_front),
    ]
    faces = [
        (0, 1, 2, 3),
        (4, 7, 6, 5),
        (0, 4, 5, 1),
        (3, 2, 6, 7),
        (1, 5, 6, 2),
        (0, 3, 7, 4),
    ]
    return from_verts_faces(name, verts, faces, **kwargs)


def regular_ngon_prism(
    name: str,
    *,
    radius: float,
    height: float,
    sides: int = 8,
    bottom_z: float = 0.0,
    **kwargs,
) -> bpy.types.Object:
    """Circumscribed so vertices stay inside `radius` (max |x|,|y| ≤ radius)."""
    verts = []
    for ring_z in (bottom_z, bottom_z + height):
        for i in range(sides):
            a = (math.pi / sides) + i * (2.0 * math.pi / sides)
            verts.append((math.cos(a) * radius, math.sin(a) * radius, ring_z))
    faces = []
    faces.append(list(range(sides - 1, -1, -1)))
    faces.append(list(range(sides, 2 * sides)))
    for i in range(sides):
        n = (i + 1) % sides
        faces.append((i, n, n + sides, i + sides))
    return from_verts_faces(name, verts, faces, **kwargs)


def inset_top_panel(
    host: bpy.types.Object,
    *,
    inset: float,
    depth: float,
) -> None:
    """Push the highest faces down to form a recessed deck."""
    bm = bmesh.new()
    bm.from_mesh(host.data)
    bm.faces.ensure_lookup_table()
    max_z = max(v.co.z for v in bm.verts)
    top = [f for f in bm.faces if all(v.co.z > max_z - 1e-4 for v in f.verts)]
    if not top:
        bm.free()
        return
    result = bmesh.ops.inset_region(bm, faces=top, thickness=inset, depth=0.0, use_boundary=True)
    inner = result.get("faces", top)
    bmesh.ops.translate(bm, verts=list({v for f in inner for v in f.verts}), vec=Vector((0.0, 0.0, -depth)))
    bm.to_mesh(host.data)
    bm.free()
    host.data.update()

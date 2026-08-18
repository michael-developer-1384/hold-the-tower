"""Scene reset, object linking, parenting, and transform helpers."""

from __future__ import annotations

import math
from typing import Iterable

import bpy
from mathutils import Vector


def reset_scene() -> bpy.types.Scene:
    """Clear datablocks without factory-reset (keeps the glTF addon enabled)."""
    scene = bpy.context.scene
    if bpy.context.mode != "OBJECT" and bpy.context.object is not None:
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for coll in list(bpy.data.collections):
        if coll != scene.collection:
            bpy.data.collections.remove(coll)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.cameras, bpy.data.lights, bpy.data.worlds):
        for item in list(block):
            block.remove(item)
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.fps = 30
    if hasattr(scene, "eevee"):
        try:
            scene.eevee.taa_render_samples = 16
        except Exception:
            pass
    return scene


def ensure_collection(name: str) -> bpy.types.Collection:
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def link_object(obj: bpy.types.Object, collection: bpy.types.Collection | None = None) -> None:
    col = collection or bpy.context.scene.collection
    if obj.name not in col.objects:
        col.objects.link(obj)


def new_empty(
    name: str,
    location: Iterable[float] = (0.0, 0.0, 0.0),
    parent: bpy.types.Object | None = None,
    empty_type: str = "PLAIN_AXES",
    size: float = 0.08,
) -> bpy.types.Object:
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = empty_type
    empty.empty_display_size = size
    empty.location = Vector(location)
    link_object(empty)
    if parent is not None:
        parent_keep_world(empty, parent)
    return empty


def parent_keep_world(child: bpy.types.Object, parent: bpy.types.Object) -> None:
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def parent_identity(child: bpy.types.Object, parent: bpy.types.Object) -> None:
    """Parent without baking an inverse — child local coords stay as authored."""
    child.parent = parent
    child.matrix_parent_inverse.identity()


def select_only(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def object_mode() -> None:
    if bpy.context.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")


def apply_object_transforms(obj: bpy.types.Object, location: bool = False) -> None:
    if obj.type != "MESH":
        return
    select_only(obj)
    object_mode()
    bpy.ops.object.transform_apply(location=location, rotation=True, scale=True)


def apply_all_modifiers(obj: bpy.types.Object) -> None:
    if obj.type != "MESH":
        return
    select_only(obj)
    object_mode()
    for mod in list(obj.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except RuntimeError:
            obj.modifiers.remove(mod)


def shade_smooth(obj: bpy.types.Object, angle_deg: float = 35.0) -> None:
    if obj.type != "MESH":
        return
    select_only(obj)
    object_mode()
    mesh = obj.data
    for poly in mesh.polygons:
        poly.use_smooth = True
    angle = math.radians(angle_deg)
    if hasattr(bpy.ops.object, "shade_smooth_by_angle"):
        try:
            bpy.ops.object.shade_smooth_by_angle(angle=angle)
            return
        except TypeError:
            try:
                bpy.ops.object.shade_smooth_by_angle()
                return
            except Exception:
                pass
    if hasattr(mesh, "use_auto_smooth"):
        mesh.use_auto_smooth = True
        if hasattr(mesh, "auto_smooth_angle"):
            mesh.auto_smooth_angle = angle


def mesh_stats(objects: Iterable[bpy.types.Object]) -> dict:
    verts = 0
    tris = 0
    mats: set[str] = set()
    min_c = Vector((1e9, 1e9, 1e9))
    max_c = Vector((-1e9, -1e9, -1e9))
    count = 0
    deps = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        if obj.type != "MESH":
            continue
        count += 1
        eval_obj = obj.evaluated_get(deps)
        mesh = eval_obj.to_mesh()
        try:
            verts += len(mesh.vertices)
            mesh.calc_loop_triangles()
            tris += len(mesh.loop_triangles)
            for slot in obj.material_slots:
                if slot.material:
                    mats.add(slot.material.name)
            for corner in obj.bound_box:
                world = obj.matrix_world @ Vector(corner)
                min_c.x = min(min_c.x, world.x)
                min_c.y = min(min_c.y, world.y)
                min_c.z = min(min_c.z, world.z)
                max_c.x = max(max_c.x, world.x)
                max_c.y = max(max_c.y, world.y)
                max_c.z = max(max_c.z, world.z)
        finally:
            eval_obj.to_mesh_clear()
    return {
        "mesh_objects": count,
        "vertex_count": verts,
        "triangle_count": tris,
        "material_count": len(mats),
        "materials": sorted(mats),
        "bounds_min": [round(min_c.x, 4), round(min_c.y, 4), round(min_c.z, 4)],
        "bounds_max": [round(max_c.x, 4), round(max_c.y, 4), round(max_c.z, 4)],
    }


def iter_mesh_objects() -> list[bpy.types.Object]:
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]

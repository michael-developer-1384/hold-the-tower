"""Bevel, boolean, and weighted-normal modifiers."""

from __future__ import annotations

import math

import bpy

from . import scene_utils as su


def add_bevel(
    obj: bpy.types.Object,
    width: float,
    *,
    segments: int = 2,
    angle_deg: float = 30.0,
    harden: bool = True,
        limit_method: str = "ANGLE",
) -> bpy.types.Modifier | None:
    if obj.type != "MESH" or width <= 0.0:
        return None
    mod = obj.modifiers.new(name="HODL_Bevel", type="BEVEL")
    mod.width = width
    mod.segments = max(1, segments)
    mod.limit_method = limit_method
    if hasattr(mod, "angle_limit"):
        mod.angle_limit = math.radians(angle_deg)
    if hasattr(mod, "harden_normals"):
        mod.harden_normals = harden
    if hasattr(mod, "miter_outer"):
        try:
            mod.miter_outer = "ARC"
        except TypeError:
            try:
                mod.miter_outer = "MITER_ARC"
            except TypeError:
                pass
    if hasattr(mod, "profile"):
        mod.profile = 0.72
    if hasattr(mod, "offset_type"):
        try:
            mod.offset_type = "OFFSET"
        except TypeError:
            pass
    return mod


def add_weighted_normals(obj: bpy.types.Object) -> bpy.types.Modifier | None:
    if obj.type != "MESH":
        return None
    if "WEIGHTED_NORMAL" not in dir(bpy.types.Modifier) and not _has_mod_type("WEIGHTED_NORMAL"):
        return None
    try:
        mod = obj.modifiers.new(name="HODL_WN", type="WEIGHTED_NORMAL")
    except TypeError:
        return None
    if hasattr(mod, "keep_sharp"):
        mod.keep_sharp = True
    if hasattr(mod, "mode"):
        mod.mode = "FACE_AREA"
    return mod


def _has_mod_type(name: str) -> bool:
    try:
        bpy.types.Modifier.bl_rna.properties["type"].enum_items[name]
        return True
    except Exception:
        return True


def boolean_difference(
    host: bpy.types.Object,
    cutter: bpy.types.Object,
    *,
    apply_now: bool = True,
    delete_cutter: bool = True,
    solver: str = "EXACT",
) -> None:
    if host.type != "MESH" or cutter.type != "MESH":
        return
    cutter.hide_render = True
    mod = host.modifiers.new(name=f"Bool_{cutter.name}", type="BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    if hasattr(mod, "solver"):
        try:
            mod.solver = solver
        except TypeError:
            try:
                mod.solver = "FAST"
            except TypeError:
                pass
    if apply_now:
        su.select_only(host)
        su.object_mode()
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except RuntimeError:
            if solver != "FAST":
                if hasattr(mod, "solver"):
                    try:
                        mod.solver = "FAST"
                    except TypeError:
                        pass
                try:
                    bpy.ops.object.modifier_apply(modifier=mod.name)
                except RuntimeError:
                    host.modifiers.remove(mod)
        if delete_cutter:
            bpy.data.objects.remove(cutter, do_unlink=True)


def boolean_union(
    host: bpy.types.Object,
    other: bpy.types.Object,
    *,
    apply_now: bool = True,
    delete_other: bool = True,
) -> None:
    if host.type != "MESH" or other.type != "MESH":
        return
    mod = host.modifiers.new(name=f"Union_{other.name}", type="BOOLEAN")
    mod.operation = "UNION"
    mod.object = other
    if hasattr(mod, "solver"):
        try:
            mod.solver = "EXACT"
        except TypeError:
            pass
    if apply_now:
        su.select_only(host)
        su.object_mode()
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except RuntimeError:
            host.modifiers.remove(mod)
        if delete_other:
            bpy.data.objects.remove(other, do_unlink=True)


def finish_solid(
    obj: bpy.types.Object,
    *,
    bevel_width: float,
    bevel_segments: int = 2,
    shade_angle: float = 35.0,
) -> None:
    add_bevel(obj, bevel_width, segments=bevel_segments)
    add_weighted_normals(obj)
    su.apply_all_modifiers(obj)
    su.apply_object_transforms(obj)
    su.shade_smooth(obj, shade_angle)

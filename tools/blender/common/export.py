"""glTF 2.0 / GLB export plus studio preview renders."""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector

from . import scene_utils as su


def export_glb(path: Path) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        bpy.ops.preferences.addon_enable(module="io_scene_gltf2")
    except Exception:
        pass
    su.object_mode()
    # Hide studio helpers from the asset file.
    for obj in bpy.context.scene.objects:
        if obj.type in {"CAMERA", "LIGHT"}:
            obj.select_set(False)
            obj.hide_set(True)
            obj.hide_render = True
    kwargs = {
        "filepath": str(path),
        "export_format": "GLB",
        "export_texcoords": True,
        "export_normals": True,
        "export_materials": "EXPORT",
        "export_cameras": False,
        "export_extras": True,
        "export_yup": True,
        "export_apply": False,
        "use_selection": False,
        "export_animations": False,
        "export_lights": False,
    }
    op = bpy.ops.export_scene.gltf
    try:
        op(**kwargs)
    except TypeError:
        kwargs.pop("export_lights", None)
        kwargs.pop("export_extras", None)
        op(**kwargs)
    # Unhide for subsequent preview renders.
    for obj in bpy.context.scene.objects:
        if obj.type in {"CAMERA", "LIGHT"}:
            obj.hide_set(False)
    return path


def setup_studio(scene: bpy.types.Scene) -> None:
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 960
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.film_transparent = False

    engine = "BLENDER_EEVEE_NEXT"
    if engine not in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys():
        if "BLENDER_EEVEE" in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys():
            engine = "BLENDER_EEVEE"
        else:
            engine = "CYCLES"
    scene.render.engine = engine
    if engine == "CYCLES":
        scene.cycles.samples = 32
        scene.cycles.use_denoising = True

    world = bpy.data.worlds.new("HODL_StudioWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.055, 0.058, 0.065, 1.0)
        bg.inputs[1].default_value = 0.85

    _area_light("Key", location=(1.6, -1.4, 1.8), energy=480.0, color=(1.0, 0.97, 0.93), size=0.75, look_at=(0, 0.1, 0.32))
    _area_light("Fill", location=(-1.8, -0.2, 1.2), energy=160.0, color=(0.82, 0.86, 0.95), size=2.2, look_at=(0, 0, 0.28))
    _area_light("Rim", location=(0.15, 1.85, 1.2), energy=220.0, color=(0.92, 0.94, 1.0), size=0.65, look_at=(0, 0, 0.34))
    _area_light("Top", location=(0.2, -0.3, 2.1), energy=90.0, color=(1.0, 1.0, 1.0), size=1.4, look_at=(0, 0.05, 0.2))


def _area_light(name, *, location, energy, color, size, look_at) -> bpy.types.Object:
    data = bpy.data.lights.new(name, type="AREA")
    data.energy = energy
    data.color = color
    data.size = size
    obj = bpy.data.objects.new(name, data)
    obj.location = location
    su.link_object(obj)
    direction = Vector(look_at) - Vector(location)
    if direction.length > 1e-6:
        obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return obj


def render_previews(out_dir: Path, stem: str, target_z: float = 0.32) -> dict[str, str]:
    """Perspective stills. +Y is muzzle-forward in Blender (Godot -Z)."""
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    setup_studio(scene)

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 48.0
    cam_data.clip_start = 0.01
    cam_data.clip_end = 20.0
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    su.link_object(cam)
    scene.camera = cam

    shots = {
        "front": Vector((0.05, 1.25, 0.48)),
        "3q": Vector((0.95, 1.05, 0.62)),
        "side": Vector((1.35, 0.18, 0.42)),
        "back": Vector((0.08, -1.25, 0.5)),
        "top": Vector((0.12, -0.28, 1.45)),
    }
    look = Vector((0.0, 0.12, target_z))
    written: dict[str, str] = {}
    for name, loc in shots.items():
        cam.location = loc
        direction = look - loc
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        if name == "top":
            cam.rotation_euler = (math.radians(12.0), 0.0, math.radians(18.0))
            cam.location = loc
        dest = out_dir / f"{stem}_{name}.png"
        scene.render.filepath = str(dest)
        bpy.ops.render.render(write_still=True)
        written[name] = str(dest)
    return written

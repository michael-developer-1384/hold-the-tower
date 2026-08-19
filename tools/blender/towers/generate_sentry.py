"""Procedural HODL Sentry — stylized industrial hard-surface hero tower.

Design parameters live in PARAMS. Same inputs → same GLB.

Blender space: Z up, +Y muzzle-forward (glTF Y-up → Godot Y up, -Z forward).
Pedestal stays inside 0.72×0.72, bottom at Z=0. Geometry below Z=0.20 must
not exceed that pad. Barrels/sensors may overhang above the pad.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from common import export as ex  # noqa: E402
from common import geometry as geo  # noqa: E402
from common import hodl_kit as kit  # noqa: E402
from common import materials as mats  # noqa: E402
from common import modifiers as mods  # noqa: E402
from common import scene_utils as su  # noqa: E402


# ---------------------------------------------------------------------------
# Central design knobs. Change these to iterate ("barrels 15% longer").
# ---------------------------------------------------------------------------
PARAMS = {
    "seed": 7,
    "pedestal_size": 0.70,
    "pedestal_height": 0.118,
    "pedestal_inset": 0.048,
    "pedestal_recess": 0.014,
    "pedestal_bevel": 0.014,
    "corner_mount": 0.058,
    "yaw_z": 0.52,
    "yaw_radius": 0.148,
    "yaw_height": 0.042,
    "yaw_teeth": 16,
    "turret_half_w_front": 0.078,
    "turret_half_w_back": 0.138,
    "turret_y_front": 0.155,
    "turret_y_back": -0.175,
    "turret_z_top_front": 0.30,
    "turret_z_top_back": 0.40,
    "turret_y_front_top": 0.10,
    "body_bevel": 0.011,
    "barrel_length": 0.50,
    "barrel_spacing": 0.078,
    "barrel_radius": 0.0135,
    "sleeve_radius": 0.022,
    "receiver_len": 0.12,
    "barrel_segments": 14,
    "sensor_size": 0.062,
    "sensor_offset": (0.138, 0.055, 0.44),
    "small_bevel": 0.0055,
    "medium_bevel": 0.008,
}

REPO = ROOT.parent.parent
GLB_PATH = REPO / "assets" / "generated" / "towers" / "sentry.glb"
PREVIEW_DIR = REPO / "artifacts" / "visual_previews"
META_PATH = PREVIEW_DIR / "sentry_meta.json"


def build() -> dict:
    su.reset_scene()
    pal = mats.create_hodl_palette("sentry")

    base = su.new_empty("Base", location=(0.0, 0.0, 0.0), size=0.12)
    turret = su.new_empty("Turret", location=(0.0, 0.0, PARAMS["yaw_z"]), size=0.1)
    pitch = su.new_empty("WeaponPitch", location=(0.0, 0.02, 0.26), parent=turret, size=0.07)
    recoil = su.new_empty("RecoilAssembly", location=(0.0, 0.02, 0.0), parent=pitch, size=0.06)
    weapon = su.new_empty("Weapon", location=(0.0, 0.0, 0.0), parent=recoil, size=0.05)
    sensor = su.new_empty("Sensor", location=PARAMS["sensor_offset"], parent=turret, size=0.05)
    su.new_empty("VFXSocket", location=(0.0, 0.22, 0.04), parent=recoil, size=0.04)
    su.new_empty("HitSocket", location=(0.0, 0.0, 0.08), parent=turret, size=0.04)

    top = kit.build_standard_pedestal(base, pal)
    kit.build_support_neck(base, pal, z0=top, z1=PARAMS["yaw_z"] - 0.02, radius=0.058)
    _build_yaw_assembly(base, turret, pal)
    _build_turret_body(turret, pal)
    _build_weapon(weapon, recoil, pal)
    _build_sensor(sensor, pal)
    _place_muzzles(recoil)

    return kit.finalize_asset(
        name="sentry",
        glb_path=GLB_PATH,
        preview_dir=PREVIEW_DIR,
        preview_z=0.62,
        sockets=[
            "Base", "Turret", "WeaponPitch", "RecoilAssembly", "Weapon",
            "Muzzle", "MuzzleLeft", "MuzzleRight", "Sensor", "VFXSocket",
            "HitSocket", "YawRing", "Servo",
        ],
        params=PARAMS,
        tri_max=kit.TOWER_TRI_MAX,
    )


def _finish(obj: bpy.types.Object, width: float, segments: int = 3) -> None:
    kit.finish(obj, width, segments)


def _cut(host: bpy.types.Object, cutter: bpy.types.Object) -> None:
    kit.cut(host, cutter)


def _build_yaw_assembly(base: bpy.types.Object, turret: bpy.types.Object, pal: dict) -> None:
    r = PARAMS["yaw_radius"]
    h = PARAMS["yaw_height"]
    # Static outer race on the pedestal — "this is the bearing".
    outer = geo.cylinder(
        "YawOuterRace",
        radius=r + 0.028,
        depth=0.024,
        segments=24,
        radius2=r + 0.022,
        location=(0.0, 0.0, PARAMS["yaw_z"] - 0.028),
        parent=base,
        material=pal["structural"],
    )
    bore = geo.cylinder(
        "YawOuterBore",
        radius=r - 0.012,
        depth=0.06,
        segments=20,
        location=(0.0, 0.0, PARAMS["yaw_z"] - 0.028),
    )
    _cut(outer, bore)
    _finish(outer, PARAMS["medium_bevel"], 2)

    inner = geo.cylinder(
        "YawInnerHub",
        radius=r - 0.02,
        depth=h * 0.7,
        segments=20,
        location=(0.0, 0.0, 0.0),
        parent=turret,
        material=pal["exposed"],
    )
    _finish(inner, PARAMS["small_bevel"], 2)

    ring = geo.cylinder(
        "YawRing",
        radius=r,
        depth=h * 0.42,
        segments=24,
        location=(0.0, 0.0, 0.012),
        parent=turret,
        material=pal["painted"],
    )
    _finish(ring, PARAMS["small_bevel"], 2)

    teeth = PARAMS["yaw_teeth"]
    for i in range(teeth):
        a = i * (2.0 * math.pi / teeth)
        x, y = math.cos(a) * (r + 0.006), math.sin(a) * (r + 0.006)
        tooth = geo.chamfered_box(
            f"YawTooth{i}",
            (0.018, 0.024, 0.016),
            0.003,
            location=(x, y, 0.012),
            rotation=(0.0, 0.0, a),
            parent=turret,
            material=pal["exposed"],
        )
        _finish(tooth, 0.0025, 2)

    cap = geo.cylinder(
        "YawCap",
        radius=0.055,
        depth=0.016,
        segments=16,
        location=(0.0, 0.0, h * 0.45),
        parent=turret,
        material=pal["structural"],
    )
    _finish(cap, PARAMS["small_bevel"], 1)

    # Visible servo that drives the ring — attached to turret, braced to hub.
    servo = geo.chamfered_box(
        "Servo",
        (0.07, 0.078, 0.05),
        0.004,
        location=(0.145, -0.02, 0.038),
        parent=turret,
        material=pal["painted"],
    )
    _finish(servo, PARAMS["small_bevel"], 2)
    pinion = geo.cylinder(
        "ServoPinion",
        radius=0.016,
        depth=0.028,
        segments=10,
        location=(0.112, -0.02, 0.018),
        rotation=(0.0, math.pi * 0.5, 0.0),
        parent=turret,
        material=pal["exposed"],
    )
    _finish(pinion, 0.0015, 1)
    bracket = geo.chamfered_box(
        "ServoBracket",
        (0.018, 0.05, 0.034),
        0.002,
        location=(0.108, -0.02, 0.02),
        parent=turret,
        material=pal["exposed"],
    )
    _finish(bracket, 0.0015, 1)


def _build_turret_body(turret: bpy.types.Object, pal: dict) -> None:
    p = PARAMS
    body = geo.tapered_hull(
        "TurretBody",
        y_front=p["turret_y_front"],
        y_back=p["turret_y_back"],
        half_w_front=p["turret_half_w_front"],
        half_w_back=p["turret_half_w_back"],
        z_bottom=0.028,
        z_top_front=p["turret_z_top_front"],
        z_top_back=p["turret_z_top_back"],
        y_front_top=p["turret_y_front_top"],
        half_w_front_top=p["turret_half_w_front"] * 0.86,
        half_w_back_top=p["turret_half_w_back"] * 1.04,
        location=(0.0, 0.0, 0.0),
        parent=turret,
        material=pal["painted"],
    )
    spacing = p["barrel_spacing"] * 0.5
    for sx in (-1.0, 1.0):
        cutter = geo.cube(
            f"SideRecessCut{sx}",
            (0.036, 0.17, 0.075),
            location=(sx * (p["turret_half_w_back"] + 0.004), -0.03, 0.10),
        )
        _cut(body, cutter)
        tunnel = geo.cylinder(
            f"BarrelTunnel{sx}",
            radius=p["sleeve_radius"] + 0.006,
            depth=0.22,
            segments=12,
            location=(sx * spacing, 0.10, 0.078),
            rotation=(math.pi * 0.5, 0.0, 0.0),
        )
        _cut(body, tunnel)
    hatch_cut = geo.cube(
        "HatchCut",
        (0.15, 0.034, 0.09),
        location=(0.0, p["turret_y_back"] - 0.004, 0.10),
    )
    _cut(body, hatch_cut)
    # Deep side vents so they read at gallery distance.
    for i, z in enumerate((0.06, 0.085, 0.11)):
        slot = geo.cube(
            f"BodyVent{i}",
            (0.08, 0.06, 0.011),
            location=(p["turret_half_w_back"] * 0.15, p["turret_y_back"] + 0.04, z),
        )
        _cut(body, slot)
    _finish(body, p["body_bevel"], 3)

    # Gun shroud: barrels leave through a housing, not a wall.
    shroud = geo.chamfered_box(
        "GunShroud",
        (0.175, 0.09, 0.095),
        0.008,
        location=(0.0, p["turret_y_front"] + 0.012, 0.078),
        parent=turret,
        material=pal["structural"],
    )
    for sx in (-1.0, 1.0):
        hole = geo.cylinder(
            f"ShroudBore{sx}",
            radius=p["sleeve_radius"] + 0.004,
            depth=0.16,
            segments=12,
            location=(sx * spacing, p["turret_y_front"] + 0.012, 0.078),
            rotation=(math.pi * 0.5, 0.0, 0.0),
        )
        _cut(shroud, hole)
    _finish(shroud, PARAMS["medium_bevel"], 3)

    # Armor plates that sit IN the recesses (attached, not floating).
    for sx, name in ((-1.0, "ArmorL"), (1.0, "ArmorR")):
        plate = geo.chamfered_box(
            name,
            (0.018, 0.16, 0.072),
            0.005,
            location=(sx * (p["turret_half_w_back"] - 0.012), -0.02, 0.09),
            parent=turret,
            material=pal["structural"],
        )
        _finish(plate, PARAMS["small_bevel"], 2)
        # Two panel-line cuts on each plate.
        for dy in (-0.04, 0.04):
            line = geo.cube(
                f"{name}Line{dy}",
                (0.024, 0.007, 0.055),
                location=(sx * (p["turret_half_w_back"] - 0.01), -0.02 + dy, 0.09),
            )
            _cut(plate, line)

    hatch = geo.chamfered_box(
        "RearHatch",
        (0.12, 0.014, 0.068),
        0.0025,
        location=(0.0, p["turret_y_back"] + 0.006, 0.095),
        parent=turret,
        material=pal["structural"],
    )
    _finish(hatch, PARAMS["small_bevel"], 1)
    handle = geo.chamfered_box(
        "HatchHandle",
        (0.04, 0.008, 0.01),
        0.0015,
        location=(0.0, p["turret_y_back"] - 0.004, 0.11),
        parent=turret,
        material=pal["exposed"],
    )
    _finish(handle, 0.0012, 1)

    # Rear electronics bustle — taller, offset slightly to break symmetry.
    bustle = geo.tapered_hull(
        "RearBustle",
        y_front=-0.08,
        y_back=p["turret_y_back"] - 0.055,
        half_w_front=0.07,
        half_w_back=0.05,
        z_bottom=0.04,
        z_top_front=0.148,
        z_top_back=0.12,
        location=(0.018, 0.0, 0.0),
        parent=turret,
        material=pal["structural"],
    )
    for i, z in enumerate((0.075, 0.10, 0.125)):
        slot = geo.cube(
            f"BustleVent{i}",
            (0.07, 0.05, 0.012),
            location=(0.018, p["turret_y_back"] - 0.05, z),
        )
        _cut(bustle, slot)
    _finish(bustle, PARAMS["medium_bevel"], 3)

    # Chin / magazine under the body, mechanically tied with a bracket.
    mag = geo.chamfered_box(
        "MagWell",
        (0.12, 0.14, 0.05),
        0.004,
        location=(0.0, 0.02, 0.042),
        parent=turret,
        material=pal["rubber"],
    )
    _finish(mag, PARAMS["small_bevel"], 2)
    mag_bracket = geo.chamfered_box(
        "MagBracket",
        (0.08, 0.02, 0.028),
        0.002,
        location=(0.0, -0.05, 0.05),
        parent=turret,
        material=pal["exposed"],
    )
    _finish(mag_bracket, 0.0015, 1)

    # Neck that clamps onto the yaw cap — no floating body.
    neck = geo.cylinder(
        "TurretNeck",
        radius=0.062,
        depth=0.04,
        segments=16,
        location=(0.0, 0.0, 0.018),
        parent=turret,
        material=pal["exposed"],
    )
    _finish(neck, PARAMS["small_bevel"], 2)
    collar = geo.cylinder(
        "TurretCollar",
        radius=0.078,
        depth=0.016,
        segments=20,
        radius2=0.07,
        location=(0.0, 0.0, 0.034),
        parent=turret,
        material=pal["structural"],
    )
    _finish(collar, PARAMS["small_bevel"], 2)

    # Top spine rail (gimbal / cable tray).
    spine = geo.chamfered_box(
        "SpineRail",
        (0.028, 0.18, 0.016),
        0.002,
        location=(0.0, -0.02, p["turret_z_top_back"] - 0.004),
        parent=turret,
        material=pal["exposed"],
    )
    _finish(spine, 0.0018, 1)

    # Status pip on the rear-left — spare emissive, not a meme.
    pip = geo.cylinder(
        "StatusPip",
        radius=0.006,
        depth=0.006,
        segments=8,
        location=(-0.07, p["turret_y_back"] + 0.02, 0.13),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=turret,
        material=pal["emissive"],
    )
    su.shade_smooth(pip, 50.0)

    kit.add_pipe(
        "Harness",
        [
            (0.12, -0.04, 0.05),
            (0.10, -0.10, 0.07),
            (0.04, -0.14, 0.11),
            (0.02, -0.12, 0.13),
        ],
        radius=0.01,
        parent=turret,
        material=pal["rubber"],
    )


def _add_cable(name, points, *, radius, parent, material) -> bpy.types.Object:
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


def _build_weapon(weapon: bpy.types.Object, recoil: bpy.types.Object, pal: dict) -> None:
    frame = geo.chamfered_box(
        "WeaponFrame",
        (0.155, PARAMS["receiver_len"], 0.062),
        0.007,
        location=(0.0, 0.02, 0.0),
        parent=weapon,
        material=pal["structural"],
    )
    _finish(frame, PARAMS["medium_bevel"], 3)
    for sx, tag in ((-1.0, "L"), (1.0, "R")):
        rail = geo.chamfered_box(
            f"RecoilRail{tag}",
            (0.014, 0.20, 0.012),
            0.0025,
            location=(sx * 0.046, 0.08, 0.04),
            parent=weapon,
            material=pal["exposed"],
        )
        _finish(rail, 0.002, 2)
        spring = geo.cylinder(
            f"RecoilSpring{tag}",
            radius=0.007,
            depth=0.10,
            segments=8,
            location=(sx * 0.046, 0.09, 0.052),
            rotation=(math.pi * 0.5, 0.0, 0.0),
            parent=weapon,
            material=pal["exposed"],
        )
        su.shade_smooth(spring, 40.0)

    spacing = PARAMS["barrel_spacing"] * 0.5
    for sx, tag in ((-1.0, "L"), (1.0, "R")):
        _one_barrel(tag, sx * spacing, recoil, pal)

    trunnion = geo.chamfered_box(
        "Trunnion",
        (0.15, 0.048, 0.05),
        0.005,
        location=(0.0, 0.07, 0.0),
        parent=weapon,
        material=pal["exposed"],
    )
    _finish(trunnion, PARAMS["small_bevel"], 3)


def _one_barrel(tag: str, x: float, recoil: bpy.types.Object, pal: dict) -> None:
    segs = PARAMS["barrel_segments"]
    length = PARAMS["barrel_length"]
    stub = geo.chamfered_box(
        f"BarrelReceiver{tag}",
        (0.04, 0.06, 0.04),
        0.005,
        location=(x, 0.04, 0.0),
        parent=recoil,
        material=pal["structural"],
    )
    _finish(stub, PARAMS["small_bevel"], 2)

    root = geo.cylinder(
        f"BarrelRoot{tag}",
        radius=PARAMS["sleeve_radius"] + 0.005,
        depth=0.06,
        segments=segs,
        location=(x, 0.08, 0.0),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=recoil,
        material=pal["exposed"],
    )
    _finish(root, 0.003, 2)

    sleeve = geo.cylinder(
        f"BarrelSleeve{tag}",
        radius=PARAMS["sleeve_radius"],
        depth=0.145,
        segments=segs,
        radius2=PARAMS["sleeve_radius"] * 0.9,
        location=(x, 0.175, 0.0),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=recoil,
        material=pal["structural"],
    )
    for i in range(4):
        port = geo.cylinder(
            f"SleevePort{tag}{i}",
            radius=0.005,
            depth=0.05,
            segments=8,
            location=(x, 0.14 + i * 0.028, 0.02),
            rotation=(0.0, math.pi * 0.5, 0.0),
        )
        _cut(sleeve, port)
    _finish(sleeve, 0.003, 2)

    barrel = geo.cylinder(
        f"Barrel{tag}",
        radius=PARAMS["barrel_radius"],
        depth=length * 0.52,
        segments=max(10, segs - 2),
        location=(x, 0.175 + length * 0.26, 0.0),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=recoil,
        material=pal["exposed"],
    )
    _finish(barrel, 0.0026, 2)

    muzzle = geo.cylinder(
        f"MuzzleBrake{tag}",
        radius=PARAMS["barrel_radius"] + 0.006,
        depth=0.038,
        segments=segs,
        radius2=PARAMS["barrel_radius"] + 0.002,
        location=(x, 0.175 + length * 0.50, 0.0),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=recoil,
        material=pal["exposed"],
    )
    bore = geo.cylinder(
        f"MuzzleBore{tag}",
        radius=PARAMS["barrel_radius"] * 0.5,
        depth=0.055,
        segments=8,
        location=(x, 0.175 + length * 0.50, 0.0),
        rotation=(math.pi * 0.5, 0.0, 0.0),
    )
    _cut(muzzle, bore)
    _finish(muzzle, 0.0026, 2)

    clamp = geo.chamfered_box(
        f"BarrelClamp{tag}",
        (0.032, 0.022, 0.032),
        0.003,
        location=(x, 0.115, 0.0),
        parent=recoil,
        material=pal["exposed"],
    )
    _finish(clamp, 0.0022, 2)


def _place_muzzles(recoil: bpy.types.Object) -> None:
    spacing = PARAMS["barrel_spacing"] * 0.5
    # Same local frame as MuzzleBrake*: +Y barrel-forward in Blender.
    y = 0.175 + PARAMS["barrel_length"] * 0.50 + 0.022
    for name, loc in (
        ("MuzzleLeft", (-spacing, y, 0.0)),
        ("MuzzleRight", (spacing, y, 0.0)),
        ("Muzzle", (0.0, y, 0.0)),
    ):
        empty = su.new_empty(name, location=loc, parent=recoil, empty_type="PLAIN_AXES", size=0.03)
        empty.rotation_euler = (0.0, 0.0, 0.0)


def _build_sensor(sensor: bpy.types.Object, pal: dict) -> None:
    # Arm from turret body — sensor is not glued in mid-air.
    mast = geo.chamfered_box(
        "SensorMast",
        (0.022, 0.022, 0.16),
        0.003,
        location=(-0.02, 0.0, -0.10),
        parent=sensor,
        material=pal["exposed"],
    )
    _finish(mast, 0.002, 1)
    arm = geo.chamfered_box(
        "SensorArm",
        (0.018, 0.055, 0.016),
        0.002,
        location=(-0.028, -0.01, -0.01),
        parent=sensor,
        material=pal["exposed"],
    )
    _finish(arm, 0.0015, 1)
    joint = geo.cylinder(
        "SensorJoint",
        radius=0.01,
        depth=0.022,
        segments=10,
        location=(-0.042, -0.01, -0.01),
        rotation=(0.0, math.pi * 0.5, 0.0),
        parent=sensor,
        material=pal["exposed"],
    )
    _finish(joint, 0.0012, 1)

    housing = geo.chamfered_box(
        "SensorHousing",
        (PARAMS["sensor_size"] * 1.15, PARAMS["sensor_size"] * 1.35, PARAMS["sensor_size"] * 0.85),
        0.006,
        location=(0.0, 0.02, 0.0),
        parent=sensor,
        material=pal["structural"],
    )
    well = geo.cylinder(
        "LensWell",
        radius=0.016,
        depth=0.03,
        segments=12,
        location=(0.0, 0.02 + PARAMS["sensor_size"] * 0.55, 0.0),
        rotation=(math.pi * 0.5, 0.0, 0.0),
    )
    _cut(housing, well)
    _finish(housing, PARAMS["small_bevel"], 2)

    lens = geo.cylinder(
        "SensorLens",
        radius=0.014,
        depth=0.008,
        segments=12,
        location=(0.0, 0.02 + PARAMS["sensor_size"] * 0.48, 0.0),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=sensor,
        material=pal["glass"],
    )
    su.shade_smooth(lens, 50.0)
    glass = geo.cylinder(
        "SensorGlass",
        radius=0.01,
        depth=0.004,
        segments=10,
        location=(0.0, 0.02 + PARAMS["sensor_size"] * 0.52, 0.0),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=sensor,
        material=pal["emissive"],
    )
    su.shade_smooth(glass, 50.0)

    # Secondary cheap rangefinder, smaller, offset.
    aux = geo.chamfered_box(
        "AuxSensor",
        (0.022, 0.03, 0.018),
        0.002,
        location=(0.028, 0.01, -0.016),
        parent=sensor,
        material=pal["structural"],
    )
    _finish(aux, 0.0014, 1)
    aux_lens = geo.cylinder(
        "AuxLens",
        radius=0.006,
        depth=0.008,
        segments=8,
        location=(0.028, 0.028, -0.016),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        parent=sensor,
        material=pal["emissive"],
    )
    su.shade_smooth(aux_lens, 50.0)


if __name__ == "__main__":
    build()

"""Bot runner — ENEMY_BASE_HEIGHT baseline. Light, nervous, path-follower."""

from __future__ import annotations

import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from common import geometry as geo  # noqa: E402
from common import hodl_kit as kit  # noqa: E402
from common import materials as mats  # noqa: E402
from common import scene_utils as su  # noqa: E402
from characters.rig import build_rig  # noqa: E402

PARAMS = {"hip_z": 0.36, "height": kit.ENEMY_BASE_HEIGHT}
REPO = ROOT.parent.parent


def build() -> dict:
    su.reset_scene()
    pal = mats.create_hodl_palette("bot")
    rig = build_rig(PARAMS["hip_z"])

    pelvis = geo.chamfered_box("Pelvis", (0.14, 0.10, 0.07), 0.007, parent=rig["Hip"], material=pal["structural"])
    kit.finish(pelvis, 0.003, 2)
    chassis = geo.tapered_hull(
        "Chassis",
        y_front=0.06,
        y_back=-0.08,
        half_w_front=0.09,
        half_w_back=0.11,
        z_bottom=-0.04,
        z_top_front=0.10,
        z_top_back=0.14,
        parent=rig["Torso"],
        material=pal["painted"],
    )
    kit.finish(chassis, 0.006, 3)
    chest = geo.chamfered_box("ChestPlate", (0.12, 0.04, 0.08), 0.004, location=(0, 0.06, 0.02), parent=rig["Torso"], material=pal["structural"])
    kit.finish(chest, 0.003, 2)
    pack = geo.cylinder("Pack", 0.04, 0.14, segments=10, location=(0, -0.08, 0.03), rotation=(math.pi * 0.5, 0, 0), parent=rig["Torso"], material=pal["structural"])
    kit.finish(pack, 0.003, 2)

    helm = geo.chamfered_box("HeadShell", (0.11, 0.11, 0.10), 0.01, parent=rig["Head"], material=pal["structural"])
    kit.finish(helm, 0.004, 2)
    visor = geo.chamfered_box("VisorPlate", (0.10, 0.035, 0.045), 0.004, parent=rig["Visor"], material=pal["glass"])
    kit.finish(visor, 0.002, 1)
    for sx, tag in ((-1, "L"), (1, "R")):
        eye = geo.cylinder(
            f"EyeGlow{tag}",
            0.012,
            0.016,
            segments=8,
            location=(sx * 0.028, 0.012, 0.0),
            rotation=(math.pi * 0.5, 0, 0),
            parent=rig["Visor"],
            material=pal["emissive"],
        )
        su.shade_smooth(eye, 40.0)
    ant = geo.chamfered_box("AntennaRod", (0.012, 0.012, 0.12), 0.002, location=(0.04, -0.02, 0.10), parent=rig["Head"], material=pal["exposed"])
    kit.finish(ant, 0.0015, 1)
    tip = geo.cylinder("AntennaTip", 0.008, 0.016, segments=6, location=(0.04, -0.02, 0.17), parent=rig["Head"], material=pal["emissive"])
    su.shade_smooth(tip, 40.0)

    for tag, node in (("L", rig["ArmL"]), ("R", rig["ArmR"])):
        u = geo.chamfered_box(f"UpperArm{tag}", (0.04, 0.04, 0.11), 0.005, location=(0, 0, -0.03), parent=node, material=pal["painted"])
        kit.finish(u, 0.0025, 2)
        f = geo.chamfered_box(f"Tool{tag}", (0.035, 0.045, 0.10), 0.004, location=(0, 0.02, -0.13), parent=node, material=pal["exposed"])
        kit.finish(f, 0.0025, 2)

    for tag, node in (("L", rig["LegL"]), ("R", rig["LegR"])):
        thigh = geo.chamfered_box(f"Thigh{tag}", (0.05, 0.055, 0.15), 0.006, location=(0, 0.01, -0.07), parent=node, material=pal["painted"])
        kit.finish(thigh, 0.003, 2)
        shin = geo.chamfered_box(f"Shin{tag}", (0.045, 0.05, 0.15), 0.005, location=(0, 0.02, -0.20), parent=node, material=pal["structural"])
        kit.finish(shin, 0.003, 2)
        boot = geo.chamfered_box(f"Boot{tag}", (0.055, 0.09, 0.04), 0.005, location=(0, 0.03, -0.30), parent=node, material=pal["rubber"])
        kit.finish(boot, 0.0025, 2)

    su.new_empty("EyeL", location=(-0.028, 0.05, 0.0), parent=rig["Visor"], size=0.02)
    su.new_empty("EyeR", location=(0.028, 0.05, 0.0), parent=rig["Visor"], size=0.02)
    su.new_empty("Antenna", location=(0.04, -0.02, 0.12), parent=rig["Head"], size=0.02)

    return kit.finalize_asset(
        name="bot",
        glb_path=REPO / "assets" / "generated" / "enemies" / "bot.glb",
        preview_dir=REPO / "artifacts" / "visual_previews",
        preview_z=0.42,
        sockets=["Hip", "Torso", "Head", "Visor", "EyeL", "EyeR", "Antenna", "ArmL", "ArmR", "LegL", "LegR"],
        params=PARAMS,
        tri_max=kit.CHARACTER_TRI_MAX,
    )


if __name__ == "__main__":
    build()

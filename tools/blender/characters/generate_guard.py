"""Guard character — compact industrial security blocker."""

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

PARAMS = {"hip_z": 0.40, "height": 0.92}
REPO = ROOT.parent.parent


def build() -> dict:
    su.reset_scene()
    pal = mats.create_hodl_palette("guard")
    rig = build_rig(PARAMS["hip_z"])
    rig["Head"].location.z = 0.26

    pelvis = geo.chamfered_box("Pelvis", (0.16, 0.12, 0.08), 0.008, parent=rig["Hip"], material=pal["structural"])
    kit.finish(pelvis, 0.004, 2)
    torso = geo.chamfered_box("Armor", (0.20, 0.14, 0.20), 0.01, location=(0, 0.01, 0.02), parent=rig["Torso"], material=pal["painted"])
    kit.finish(torso, 0.006, 3)
    for sx, tag in ((-1, "L"), (1, "R")):
        pad = geo.chamfered_box(
            f"Pauldron{tag}",
            (0.07, 0.10, 0.08),
            0.008,
            location=(sx * 0.12, 0.02, 0.07),
            parent=rig["Torso"],
            material=pal["structural"],
        )
        kit.finish(pad, 0.004, 2)
    helm = geo.chamfered_box("Helm", (0.13, 0.13, 0.13), 0.01, location=(0, 0.01, 0.02), parent=rig["Head"], material=pal["structural"])
    kit.finish(helm, 0.005, 2)
    visor = geo.chamfered_box("VisorPlate", (0.10, 0.04, 0.04), 0.004, parent=rig["Visor"], material=pal["glass"])
    kit.finish(visor, 0.002, 1)
    eye = geo.cylinder("VisorGlow", 0.018, 0.02, segments=8, location=(0, 0.01, 0), rotation=(math.pi * 0.5, 0, 0), parent=rig["Visor"], material=pal["emissive"])
    su.shade_smooth(eye, 40.0)

    for tag, node, sx in (("L", rig["ArmL"], -1), ("R", rig["ArmR"], 1)):
        u = geo.chamfered_box(f"UpperArm{tag}", (0.055, 0.055, 0.12), 0.006, location=(0, 0, -0.04), parent=node, material=pal["painted"])
        kit.finish(u, 0.003, 2)
        f = geo.chamfered_box(f"ForeArm{tag}", (0.07, 0.07, 0.12), 0.007, location=(0, 0.02, -0.14), parent=node, material=pal["structural"])
        kit.finish(f, 0.003, 2)
        fist = geo.chamfered_box(f"Fist{tag}", (0.06, 0.07, 0.06), 0.006, location=(0, 0.03, -0.21), parent=node, material=pal["exposed"])
        kit.finish(fist, 0.003, 2)

    for tag, node in (("L", rig["LegL"]), ("R", rig["LegR"])):
        thigh = geo.chamfered_box(f"Thigh{tag}", (0.07, 0.08, 0.16), 0.008, location=(0, 0.01, -0.08), parent=node, material=pal["painted"])
        kit.finish(thigh, 0.004, 2)
        shin = geo.chamfered_box(f"Shin{tag}", (0.06, 0.07, 0.16), 0.007, location=(0, 0.02, -0.22), parent=node, material=pal["structural"])
        kit.finish(shin, 0.004, 2)
        boot = geo.chamfered_box(f"Boot{tag}", (0.07, 0.11, 0.05), 0.006, location=(0, 0.03, -0.335), parent=node, material=pal["rubber"])
        kit.finish(boot, 0.003, 2)

    return kit.finalize_asset(
        name="guard",
        glb_path=REPO / "assets" / "generated" / "characters" / "guard.glb",
        preview_dir=REPO / "artifacts" / "visual_previews",
        preview_z=0.45,
        sockets=["Hip", "Torso", "Head", "Visor", "ArmL", "ArmR", "LegL", "LegR"],
        params=PARAMS,
        tri_max=kit.CHARACTER_TRI_MAX,
    )


if __name__ == "__main__":
    build()

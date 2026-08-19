"""Guard Post — diamond-hands security checkpoint on the shared HODL pedestal."""

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

PARAMS = {
    "core_w": 0.30,
    "core_h": 0.46,
    "bay_x": 0.38,
    "bay_w": 0.24,
    "bay_d": 0.30,
}

REPO = ROOT.parent.parent


def build() -> dict:
    su.reset_scene()
    pal = mats.create_hodl_palette("guard")
    base = su.new_empty("Base", location=(0, 0, 0), size=0.12)
    top = kit.build_standard_pedestal(base, pal)
    kit.build_support_neck(base, pal, z0=top, z1=0.28, radius=0.08, prefix="PostNeck")

    su.new_empty("Core", location=(0, 0, 0.62), size=0.06)
    su.new_empty("GuardA", location=(-PARAMS["bay_x"], 0.04, 0.30), size=0.08)
    su.new_empty("GuardB", location=(PARAMS["bay_x"], 0.04, 0.30), size=0.08)

    plinth = geo.chamfered_box(
        "Plinth",
        (0.34, 0.34, 0.10),
        0.012,
        location=(0, 0, 0.30),
        parent=base,
        material=pal["painted"],
    )
    kit.finish(plinth, 0.008, 3)

    house = geo.chamfered_box(
        "CoreHouse",
        (PARAMS["core_w"], PARAMS["core_w"], PARAMS["core_h"]),
        0.014,
        location=(0, 0.02, 0.58),
        parent=base,
        material=pal["painted"],
    )
    kit.vent_slots(house, (0.0, PARAMS["core_w"] * 0.48, 0.52), 4, (0.16, 0.04, 0.016), 0.05)
    kit.finish(house, 0.01, 3)

    core = geo.cylinder(
        "CoreGlow",
        radius=0.07,
        depth=0.22,
        segments=14,
        location=(0, 0.02, 0.64),
        parent=base,
        material=pal["emissive"],
    )
    kit.finish(core, 0.004, 2)
    cage = geo.chamfered_box(
        "CoreCage",
        (0.16, 0.16, 0.28),
        0.006,
        location=(0, 0.02, 0.64),
        parent=base,
        material=pal["exposed"],
    )
    well = geo.cube("CageCut", (0.12, 0.18, 0.22), location=(0, 0.02, 0.64))
    kit.cut(cage, well)
    kit.finish(cage, 0.004, 2)

    cap = geo.cylinder(
        "RoofCap",
        radius=0.18,
        depth=0.08,
        segments=8,
        radius2=0.10,
        location=(0, 0, 0.86),
        parent=base,
        material=pal["structural"],
    )
    kit.finish(cap, 0.008, 2)

    for side, tag in ((-1.0, "A"), (1.0, "B")):
        x = side * PARAMS["bay_x"]
        pad = geo.chamfered_box(
            f"BayPad{tag}",
            (PARAMS["bay_w"], PARAMS["bay_d"], 0.05),
            0.006,
            location=(x, 0.04, 0.30),
            parent=base,
            material=pal["structural"],
        )
        kit.finish(pad, 0.004, 2)
        wall = geo.chamfered_box(
            f"BayWall{tag}",
            (0.05, PARAMS["bay_d"] * 0.92, 0.38),
            0.006,
            location=(x + side * 0.14, 0.02, 0.50),
            parent=base,
            material=pal["painted"],
        )
        kit.finish(wall, 0.006, 2)
        roof = geo.chamfered_box(
            f"BayRoof{tag}",
            (0.22, PARAMS["bay_d"] * 0.85, 0.045),
            0.005,
            location=(x, 0.02, 0.70),
            parent=base,
            material=pal["structural"],
        )
        kit.finish(roof, 0.004, 2)
        dock = geo.cylinder(
            f"DockRing{tag}",
            radius=0.055,
            depth=0.02,
            segments=12,
            location=(x, 0.05, 0.33),
            parent=base,
            material=pal["exposed"],
        )
        kit.finish(dock, 0.003, 2)
        bar = geo.chamfered_box(
            f"GuardBar{tag}",
            (0.018, 0.20, 0.018),
            0.002,
            location=(x + side * 0.08, -0.04, 0.58),
            rotation=(0.18, 0, 0),
            parent=base,
            material=pal["exposed"],
        )
        kit.finish(bar, 0.002, 2)
        lamp = geo.cylinder(
            f"BayLamp{tag}",
            radius=0.016,
            depth=0.022,
            segments=8,
            location=(x, 0.02, 0.68),
            parent=base,
            material=pal["emissive"],
        )
        su.shade_smooth(lamp, 40.0)

    for i, ang in enumerate((0.4, 2.2, 3.8, 5.5)):
        armor = geo.chamfered_box(
            f"Armor{i}",
            (0.08, 0.05, 0.22),
            0.006,
            location=(math.cos(ang) * 0.18, math.sin(ang) * 0.16, 0.48),
            rotation=(0, 0, ang),
            parent=base,
            material=pal["structural"],
        )
        kit.finish(armor, 0.005, 2)

    kit.add_pipe(
        "Umbilical",
        [(0.12, 0.08, 0.36), (0.18, 0.14, 0.48), (0.08, 0.10, 0.62)],
        radius=0.012,
        parent=base,
        material=pal["rubber"],
    )

    return kit.finalize_asset(
        name="guard_post",
        glb_path=REPO / "assets" / "generated" / "towers" / "guard_post.glb",
        preview_dir=REPO / "artifacts" / "visual_previews",
        preview_z=0.5,
        sockets=["Base", "Core", "GuardA", "GuardB"],
        params=PARAMS,
        tri_max=kit.TOWER_TRI_MAX,
    )


if __name__ == "__main__":
    build()

"""Meltdown — industrial liquidation furnace on the shared HODL pedestal."""

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

PARAMS = {"tank_r": 0.20, "tank_h": 0.48, "spout_len": 0.55}
REPO = ROOT.parent.parent


def build() -> dict:
    su.reset_scene()
    pal = mats.create_hodl_palette("meltdown")
    base = su.new_empty("Base", location=(0, 0, 0), size=0.12)
    top = kit.build_standard_pedestal(base, pal)
    kit.build_support_neck(base, pal, z0=top, z1=0.28, radius=0.08, prefix="FurnaceNeck")

    tank = geo.cylinder(
        "Tank",
        radius=PARAMS["tank_r"],
        depth=0.56,
        segments=18,
        radius2=PARAMS["tank_r"] * 0.86,
        location=(0.0, 0.04, 0.58),
        parent=base,
        material=pal["structural"],
    )
    kit.vent_slots(tank, (0.0, PARAMS["tank_r"] * 0.7, 0.42), 5, (0.12, 0.05, 0.014), 0.04)
    kit.finish(tank, 0.01, 3)

    core = geo.cylinder(
        "Core",
        radius=0.12,
        depth=0.22,
        segments=16,
        location=(0.0, 0.04, 0.62),
        parent=base,
        material=pal["hot"],
    )
    kit.finish(core, 0.004, 2)
    glow = geo.cylinder(
        "HotGlow",
        radius=0.07,
        depth=0.09,
        segments=12,
        location=(0.0, 0.04, 0.74),
        parent=base,
        material=pal["emissive"],
    )
    su.shade_smooth(glow, 40.0)

    rim = geo.cylinder(
        "CrucibleRim",
        radius=0.17,
        depth=0.05,
        segments=16,
        radius2=0.20,
        location=(0.0, 0.04, 0.88),
        parent=base,
        material=pal["exposed"],
    )
    kit.finish(rim, 0.006, 2)

    for i, ang in enumerate((0.6, 2.5, 4.4)):
        br = geo.chamfered_box(
            f"TankBrace{i}",
            (0.05, 0.05, 0.36),
            0.006,
            location=(math.cos(ang) * 0.18, math.sin(ang) * 0.14 + 0.04, 0.48),
            rotation=(0, 0, ang),
            parent=base,
            material=pal["exposed"],
        )
        kit.finish(br, 0.004, 2)

    spout = su.new_empty("Spout", location=(0.0, 0.42, 0.64), size=0.08)
    housing = geo.cylinder(
        "SpoutHousing",
        radius=0.055,
        depth=PARAMS["spout_len"],
        segments=12,
        radius2=0.032,
        location=(0.0, 0.16, 0.0),
        rotation=(math.pi * 0.5, 0, 0),
        parent=spout,
        material=pal["structural"],
    )
    kit.finish(housing, 0.004, 2)
    lip = geo.chamfered_box(
        "SpoutLip",
        (0.12, 0.08, 0.05),
        0.006,
        location=(0.0, 0.42, -0.02),
        parent=spout,
        material=pal["hot"],
    )
    kit.finish(lip, 0.004, 2)
    drip = geo.cylinder(
        "SpoutNozzle",
        radius=0.028,
        depth=0.06,
        segments=10,
        location=(0.0, 0.46, -0.04),
        rotation=(math.pi * 0.5, 0, 0),
        parent=spout,
        material=pal["exposed"],
    )
    kit.finish(drip, 0.003, 2)

    valve = geo.chamfered_box(
        "ValveBody",
        (0.09, 0.09, 0.09),
        0.008,
        location=(-0.18, 0.12, 0.42),
        parent=base,
        material=pal["exposed"],
    )
    kit.finish(valve, 0.004, 2)
    wheel = geo.cylinder(
        "ValveWheel",
        radius=0.055,
        depth=0.018,
        segments=12,
        location=(-0.22, 0.12, 0.42),
        rotation=(0, math.pi * 0.5, 0),
        parent=base,
        material=pal["painted"],
    )
    kit.finish(wheel, 0.003, 2)

    kit.add_pipe(
        "FeedPipe",
        [(-0.12, 0.10, 0.32), (-0.20, 0.16, 0.40), (-0.14, 0.08, 0.52), (0.02, 0.10, 0.70)],
        radius=0.016,
        parent=base,
        material=pal["structural"],
    )
    kit.add_pipe(
        "ReturnPipe",
        [(0.16, -0.04, 0.30), (0.22, -0.10, 0.44), (0.12, 0.02, 0.58)],
        radius=0.012,
        parent=base,
        material=pal["rubber"],
    )

    skirt = geo.chamfered_box(
        "HeatSkirt",
        (0.38, 0.34, 0.06),
        0.01,
        location=(0.0, 0.02, 0.29),
        parent=base,
        material=pal["painted"],
    )
    kit.finish(skirt, 0.008, 2)

    return kit.finalize_asset(
        name="meltdown",
        glb_path=REPO / "assets" / "generated" / "towers" / "meltdown.glb",
        preview_dir=REPO / "artifacts" / "visual_previews",
        preview_z=0.5,
        sockets=["Base", "Core", "Spout"],
        params=PARAMS,
        tri_max=kit.TOWER_TRI_MAX,
    )


if __name__ == "__main__":
    build()

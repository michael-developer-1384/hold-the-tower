"""Shared mechanical character sockets. Hip at hip_z, feet on Z=0."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from common import scene_utils as su  # noqa: E402


def build_rig(hip_z: float) -> dict:
    hip = su.new_empty("Hip", location=(0.0, 0.0, hip_z), size=0.06)
    torso = su.new_empty("Torso", location=(0.0, 0.0, 0.11), parent=hip, size=0.05)
    head = su.new_empty("Head", location=(0.0, 0.02, 0.14), parent=torso, size=0.04)
    visor = su.new_empty("Visor", location=(0.0, 0.045, 0.01), parent=head, size=0.03)
    arm_l = su.new_empty("ArmL", location=(-0.11, 0.0, 0.08), parent=torso, size=0.04)
    arm_r = su.new_empty("ArmR", location=(0.11, 0.0, 0.08), parent=torso, size=0.04)
    leg_l = su.new_empty("LegL", location=(-0.05, 0.0, -0.04), parent=hip, size=0.04)
    leg_r = su.new_empty("LegR", location=(0.05, 0.0, -0.04), parent=hip, size=0.04)
    return {
        "Hip": hip,
        "Torso": torso,
        "Head": head,
        "Visor": visor,
        "ArmL": arm_l,
        "ArmR": arm_r,
        "LegL": leg_l,
        "LegR": leg_r,
    }

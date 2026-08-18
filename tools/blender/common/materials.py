"""Procedural HODL PBR materials (Principled BSDF → glTF/Godot)."""

from __future__ import annotations

import bpy


HODL_STRUCTURAL = "HODL_StructuralMetal"
HODL_PAINTED = "HODL_PaintedArmor"
HODL_EXPOSED = "HODL_ExposedMetal"
HODL_RUBBER = "HODL_RubberPolymer"
HODL_EMISSIVE = "HODL_EmissiveAccent"
HODL_GLASS = "HODL_GlassSensor"


def _principled(mat: bpy.types.Material):
    nt = mat.node_tree
    for node in nt.nodes:
        if node.type == "BSDF_PRINCIPLED":
            return node
    return None


def _set(node, name: str, value) -> None:
    sock = node.inputs.get(name)
    if sock is None:
        return
    sock.default_value = value


def create_material(
    name: str,
    *,
    color: tuple[float, float, float, float],
    metallic: float,
    roughness: float,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
    transmission: float = 0.0,
    ior: float = 1.45,
    alpha: float = 1.0,
) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    node = _principled(mat)
    if node is None:
        return mat
    _set(node, "Base Color", color)
    _set(node, "Metallic", metallic)
    _set(node, "Roughness", roughness)
    _set(node, "IOR", ior)
    _set(node, "Alpha", alpha)
    if transmission > 0.0:
        _set(node, "Transmission Weight", transmission)
        _set(node, "Transmission", transmission)
    if emission is not None:
        _set(node, "Emission Color", emission)
        _set(node, "Emission", emission)
        _set(node, "Emission Strength", emission_strength)
    mat.use_fake_user = True
    if alpha < 1.0 or transmission > 0.0:
        mat.blend_method = "BLEND" if hasattr(mat, "blend_method") else mat.blend_method
    return mat


HODL_HOT = "HODL_HotMaterial"


def create_hodl_palette(variant: str = "sentry") -> dict[str, bpy.types.Material]:
    """Shared family, per-asset paint bias so forms stay readable in Godot lighting."""
    painted_colors = {
        "sentry": (0.52, 0.54, 0.42, 1.0),
        "guard": (0.46, 0.34, 0.22, 1.0),
        "meltdown": (0.42, 0.22, 0.14, 1.0),
        "bot": (0.24, 0.32, 0.42, 1.0),
    }
    tag = str(variant)
    painted = create_material(
        f"{HODL_PAINTED}_{tag}",
        color=painted_colors.get(variant, painted_colors["sentry"]),
        metallic=0.22,
        roughness=0.46,
    )
    structural = create_material(
        f"{HODL_STRUCTURAL}_{tag}",
        color=(0.018, 0.020, 0.024, 1.0),
        metallic=0.72,
        roughness=0.58,
    )
    exposed = create_material(
        f"{HODL_EXPOSED}_{tag}",
        color=(0.78, 0.80, 0.82, 1.0),
        metallic=0.96,
        roughness=0.12,
    )
    rubber = create_material(
        f"{HODL_RUBBER}_{tag}",
        color=(0.05, 0.045, 0.04, 1.0),
        metallic=0.02,
        roughness=0.90,
    )
    emit_cols = {
        "sentry": ((0.25, 0.95, 0.55, 1.0), 24.0),
        "guard": ((0.35, 0.75, 1.0, 1.0), 18.0),
        "meltdown": ((1.0, 0.35, 0.08, 1.0), 28.0),
        "bot": ((0.95, 0.55, 0.15, 1.0), 20.0),
    }
    ecol, estr = emit_cols.get(variant, emit_cols["sentry"])
    emissive = create_material(
        f"{HODL_EMISSIVE}_{tag}",
        color=(0.08, 0.12, 0.10, 1.0),
        metallic=0.05,
        roughness=0.28,
        emission=ecol,
        emission_strength=estr,
    )
    glass = create_material(
        f"{HODL_GLASS}_{tag}",
        color=(0.02, 0.04, 0.035, 1.0),
        metallic=0.0,
        roughness=0.08,
        transmission=0.55,
        ior=1.52,
        alpha=0.85,
        emission=ecol,
        emission_strength=2.0,
    )
    hot = create_material(
        f"{HODL_HOT}_{tag}",
        color=(0.35, 0.08, 0.02, 1.0),
        metallic=0.15,
        roughness=0.35,
        emission=(1.0, 0.28, 0.04, 1.0),
        emission_strength=16.0,
    )
    return {
        "structural": structural,
        "painted": painted,
        "exposed": exposed,
        "rubber": rubber,
        "emissive": emissive,
        "glass": glass,
        "hot": hot,
    }


def create_env_palette() -> dict[str, bpy.types.Material]:
    """Environment kit: dark industrial mass, sparse mint/heat accents."""
    return {
        "structural": create_material(
            f"{HODL_STRUCTURAL}_env",
            color=(0.016, 0.018, 0.022, 1.0),
            metallic=0.78,
            roughness=0.62,
        ),
        "deck": create_material(
            "HODL_DeckPlate_env",
            color=(0.11, 0.12, 0.13, 1.0),
            metallic=0.42,
            roughness=0.48,
        ),
        "painted": create_material(
            f"{HODL_PAINTED}_env",
            color=(0.28, 0.30, 0.26, 1.0),
            metallic=0.18,
            roughness=0.52,
        ),
        "exposed": create_material(
            f"{HODL_EXPOSED}_env",
            color=(0.62, 0.64, 0.66, 1.0),
            metallic=0.92,
            roughness=0.22,
        ),
        "rubber": create_material(
            f"{HODL_RUBBER}_env",
            color=(0.04, 0.038, 0.035, 1.0),
            metallic=0.02,
            roughness=0.92,
        ),
        "hazard": create_material(
            "HODL_HazardStrip_env",
            color=(0.42, 0.22, 0.08, 1.0),
            metallic=0.12,
            roughness=0.55,
        ),
        "window": create_material(
            "HODL_WindowEmissive_env",
            color=(0.04, 0.06, 0.08, 1.0),
            metallic=0.05,
            roughness=0.22,
            emission=(0.35, 0.72, 0.95, 1.0),
            emission_strength=6.5,
        ),
        "mint": create_material(
            f"{HODL_EMISSIVE}_env",
            color=(0.06, 0.10, 0.08, 1.0),
            metallic=0.04,
            roughness=0.30,
            emission=(0.30, 0.92, 0.55, 1.0),
            emission_strength=10.0,
        ),
        "heat": create_material(
            f"{HODL_HOT}_env",
            color=(0.28, 0.06, 0.02, 1.0),
            metallic=0.12,
            roughness=0.38,
            emission=(1.0, 0.32, 0.05, 1.0),
            emission_strength=14.0,
        ),
        "mass": create_material(
            "HODL_MegaMass_env",
            color=(0.028, 0.030, 0.036, 1.0),
            metallic=0.35,
            roughness=0.72,
        ),
        "warm_window": create_material(
            "HODL_WarmWindow_env",
            color=(0.08, 0.05, 0.03, 1.0),
            metallic=0.04,
            roughness=0.28,
            emission=(1.0, 0.55, 0.22, 1.0),
            emission_strength=4.0,
        ),
    }


def assign(obj: bpy.types.Object, mat: bpy.types.Material) -> None:
    if obj.data is None or not hasattr(obj.data, "materials"):
        return
    obj.data.materials.clear()
    obj.data.materials.append(mat)

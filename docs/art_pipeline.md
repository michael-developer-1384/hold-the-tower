# HODL THE TOWER — Art Pipeline

Ridiculously serious tower defense. Visuals must read as **stylized industrial hard-surface**, not graybox primitives.

Godot PrimitiveMeshes got us the functional silhouette. They are not the shipping look. From here on, **Blender is a programmable mesh factory**: Cursor/Python authors `bpy` generators, Blender builds real geometry, GLB lands in Godot as the single visual truth.

Manual sculpting in the Blender UI is not part of this pipeline.

## Pipeline

```
tools/blender/*.py
        │
        ▼
Blender  (--background --python)
        │
        ├─ assets/generated/towers/<name>.glb
        └─ artifacts/visual_previews/<name>_*.png
                │
                ▼
scenes/towers/visuals/<name>_visual.tscn   (instances the GLB)
                │
                ▼
TowerCatalog.visual_scene  →  Gallery / Detail / Placement / Runtime
```

`runtime_scene` stays the gameplay actor. `visual_scene` is the canonical mesh. Do not fork a second gallery or placement model.

Combat fires events (`play_fire_feedback`, `play_visual_event`). Visuals own recoil, muzzle flash, gait, and death posing. Gameplay must not store combat-relevant state on the visual tree.

## Finding Blender

`tools/blender/find_blender.py` searches, in order:

1. `HODL_BLENDER` or `BLENDER_PATH` (file or folder)
2. `tools/blender/config.local.json` then `config.json` (`blender_exe`)
3. `tools/blender/blender.path` (single line)
4. `PATH` / `where blender`
5. Typical `Blender Foundation` folders under Program Files

No production script hardcodes a personal Blender version path. Copy `config.example.json` to `config.local.json` if auto-detect fails (`config.local.json` is gitignored).

## Generate assets

From the repo root:

A command can generate one or all hero assets:

```
python tools/blender/generate_assets.py sentry
python tools/blender/generate_assets.py guard_post
python tools/blender/generate_assets.py guard
python tools/blender/generate_assets.py meltdown
python tools/blender/generate_assets.py bot
python tools/blender/generate_assets.py env
```

or

```
powershell -File tools/blender/build_assets.ps1 sentry
```

After generating a new GLB, let Godot import it once:

```
godot --headless --path . --import
```

or open the project in the editor. `assets/generated/towers/sentry.glb.import` is committed so CI/editor stay in sync.

## Layout

| Path | Role |
| --- | --- |
| `tools/blender/towers/` | Sentry, Guard Post, Meltdown generators |
| `tools/blender/characters/` | Guard + Bot generators + shared rig |
| `tools/blender/common/hodl_kit.py` | Pedestal, neck, pipes, vents, finalize/validate |
| `assets/generated/towers/` | sentry / guard_post / meltdown GLBs |
| `assets/generated/characters/guard.glb` | Guard enforcer |
| `assets/generated/enemies/bot.glb` | Baseline enemy (`ENEMY_BASE_HEIGHT` ≈ 0.82) |
| `tools/blender/environment/` | Walkway / pad / megastructure generators (`generate_assets.py env`) |
| `assets/generated/environment/` | Modular map kit GLBs |
| `scenes/environment/modules/` | Instanced kit scenes |
| `scenes/prototypes/visual_target_slice.tscn` | Target-look vertical slice (open in editor; not in menus) |
| `artifacts/visual_previews/` | studio stills + slice screenshots (not imported by Godot) |
| `scenes/dev/visual_showcase.tscn` | Dev scale/art QA lineup (not in menus) |

Temporary `.blend` files are not required in git.

## Naming

- Generator: `generate_<asset>.py`
- GLB: `assets/generated/<folder>/<asset>.glb`
- Visual scene: `scenes/<domain>/visuals/<asset>_visual.tscn`
- Previews: `<asset>_front.png`, `_3q.png`, `_side.png`, optional `_back.png` `_top.png`

## Coordinate system

Author in **Blender Z-up**, **+Y muzzle-forward**.

glTF export uses `export_yup=True`. In Godot that becomes **Y-up**, **-Z forward** (same as `look_at`).

- Origin at world 0,0,0
- Pedestal underside at Y = 0 (Godot)
- No compensatory scale on the Godot visual scene

## Tower footprint

Shared by every future tower:

| Rule | Value |
| --- | --- |
| Logical build spot | 1.0 × 1.0 |
| Visible pedestal | ≈ 0.72 × 0.72 (max ±0.36 X/Z) |
| Pedestal bottom | Y = 0 |
| Origin | X = 0, Z = 0 |
| Below Y ≈ 0.20 | stay inside the pad |
| Above the pad | weapons, sensors, arms may overhang |

The Sentry pedestal is the shared HODL pad. It must not scream “Sentry”.

## Visual contract

Runtime combat resolves **semantic sockets**, not frozen mesh paths.

| Socket | Canonical node | Aliases |
| --- | --- | --- |
| base | `Base` | `Pedestal` |
| turret (yaw) | `Turret` | `TurretYaw` |
| weapon pitch | `WeaponPitch` | |
| recoil | `RecoilAssembly` | `Recoil` |
| muzzle | `Muzzle` | `MuzzleLeft` |
| muzzle_left / muzzle_right | `MuzzleLeft` / `MuzzleRight` | `Muzzle` |
| sensor | `Sensor` | |

Fire API on the visual (optional): `muzzle_count()`, `get_muzzle_socket(index)`, `play_fire_feedback()`. One attack still spawns one projectile; dual barrels only alternate the spawn socket.

Sentry hierarchy (Blender / GLB):

```
Base
Turret
  WeaponPitch
    RecoilAssembly
      Weapon
      Muzzle / MuzzleLeft / MuzzleRight
      VFXSocket
  Sensor
  HitSocket
```

`scenes/towers/visuals/sentry_visual.tscn` instances the GLB and attaches presentation motion. `TowerCatalog` continues to point at that scene.

## Materials

Procedural Principled BSDF, no external textures yet. Keep the set small:

- `HODL_StructuralMetal` — dark, rough, slightly metallic
- `HODL_PaintedArmor` — main shells
- `HODL_ExposedMetal` — barrels, joints, teeth
- `HODL_RubberPolymer` — gaskets, mag well
- `HODL_EmissiveAccent` — sensor / status (spare)
- `HODL_GlassSensor` — recessed lens

Form and material contrast first. No random color soup. No meme decals.

## Adding a new tower later

1. Copy the Sentry generator pattern under `tools/blender/towers/generate_<id>.py`.
2. Reuse the pedestal language; change only the payload above the yaw.
3. Register the name in `GENERATORS` inside `generate_assets.py`.
4. Export `assets/generated/towers/<id>.glb`.
5. Point `scenes/towers/visuals/<id>_visual.tscn` at that GLB.
6. Keep `TowerCatalog.visual_scene` on that one scene.
7. Implement sockets from the contract table. Do not retune damage, range, or economy for art.

Guard Post, Guard, Meltdown, and Bot share this pipeline. `python tools/blender/generate_assets.py all` regenerates every hero GLB plus studio previews.

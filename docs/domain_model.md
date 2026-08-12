# Domain model (v0.10)

## Towers

`TowerDefinition` holds identity, copy, cost, `runtime_scene`, `visual_scene`, `feature_ids`, combat bases, research keys, and statistics metric keys.

| ID | Display | Role |
|---|---|---|
| `basic_tower` | Sentry | Ranged, paper-hands retarget |
| `guard_post` | Guard Post | Melee blockers, diamond-hands engages |

`TowerCatalog` registers unlockable towers plus coming-soon placeholders.

Resolve path:

`TowerDefinition + tower_research params → BlueprintResolver → configure_built`

## Enemies

`EnemyDefinition` + `EnemyCatalog`. Prototype enemy id: `bot`.

Runtime `enemy.gd` configures from definition and instances `visual_scene`.

## Features

`GameplayFeatureDefinition` / `FeatureCatalog`. UI resolves chips by id; meanings match existing runtime (no new gag mechanics).

## Research vs blueprints vs in-run upgrades

- **Research** (`profile.tower_research[tower_id]`): source of truth for the next match. Apply spends/refunds RP via delta vs committed cost.
- **Blueprints**: optional named saves under `tower_blueprints` (max 8). Activate loads params into research.
- **In-run upgrades**: Sentry L2 range `+1.5` only (`can_in_run_upgrade`). Guard count stays fixed at 2.

## Shared visuals

Visual PackedScenes live under `scenes/**/visuals/`. Runtime scenes keep scripts/markers and instance `Visual`. UI uses `EntityPreview3D` (SubViewport) with visual-only instances.

## Waves

`WaveCatalog` → `WaveDefinition` groups (`enemy_id`, count, HP/speed multipliers, interval). Current 5 waves are bot-only with prior counts `10/12/14/16/20`.

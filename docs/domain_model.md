# Domain model (v0.12)

## Towers

`TowerDefinition` holds identity, copy, cost, `runtime_scene`, `visual_scene`, `feature_ids`, combat bases, research keys, and statistics metric keys.

| ID | Display | Role |
|---|---|---|
| `basic_tower` | Sentry | Ranged, paper-hands retarget |
| `guard_post` | Guard Post | Melee blockers, diamond-hands engages |

Resolve path:

`TowerDefinition + research allocations (+ player level per-stat cap + tower capacity) → ResearchResolver → BlueprintResolver → configure_built`

## Enemies

`EnemyDefinition` + `EnemyCatalog`. Prototype enemy id: `bot`.

## Features

`GameplayFeatureDefinition` / `FeatureCatalog`. UI resolves chips by id.

## Research vs capacity vs blueprints

- **Allocations**: integer RP invested per stat (source of truth).
- **Per-stat level cap**: fraction of `max_investment_rp` by player level (V2: 15%→100%).
- **Tower capacity**: total RP budget for one tower’s active research (Sentry/Guard tables by level). Apply rejects over-capacity; no auto-redistribute.
- **Resolved params**: `progress^0.70` lerp base→best.
- **Player Level / XP**: slower V2 curve; gameplay grants RP+XP; refunds never grant XP.
- **Blueprints**: optional named allocation saves; active on exact match.
- **In-run upgrades**: Sentry L2 range `+1.5` after research stats.

## Session + Time Machine

- **SessionStore** (`user://session.json`): wave-/pause-safe continue of gold, core HP, wave, towers, optional living enemies.
- **TimelineRecorder**: 5 Hz ring buffer; dump `user://timeline_last_run.json`; inspect-only scrubber in post-game / debug pause (no live resume from rewind in V1).

## Shared visuals / waves

Visual PackedScenes under `scenes/**/visuals/`. `WaveCatalog` bot waves `10/12/14/16/20`.

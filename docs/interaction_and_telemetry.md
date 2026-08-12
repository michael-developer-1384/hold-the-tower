# Interaction, Range, Upgrade & Telemetry (v0.6–v0.10)

Domain overview (towers/enemies/features/research/visuals/waves): see [domain_model.md](domain_model.md).

## Interaction model

`SelectionManager` owns hover, focus, and selection. `BuildManager` handles build/upgrade economy only.

### Hover vs focus

- **Hover** (spot / tower / path picker `mouse_entered`): updates `FloorVisualController.set_hover_floor`. Never moves the camera pivot.
- **Focus** (click spot / tower / path, or keys `1`/`2`/`3`): updates floor visuals/HUD. Orbit pivot stays fixed at the map center (no height tween).

Floor visual priority:

1. Hovered floor above focus → `HOVER_GHOST` (still translucent, alpha ~0.30, brighter + slight emission)
2. Hovered floor at/below focus (≠ focus) → opaque hover brighten
3. Floors above focus → normal `GHOST` (alpha ~0.08) with shadow-only proxies
4. Focus and lower floors → same normal look

Hover never changes camera focus. Entities (towers/enemies/core) on a hovered ghost floor use a matching brighter translucent state and restore cleanly when hover ends.

### Collision layers

| Layer | Use |
|---|---|
| 2 | BuildSpot |
| 4 | Tower pick body |
| 8 | Path picker (input only) |

Empty world LMB clears spot + tower selection. MMB orbit ignores selection clicks. HUD controls use `mouse_filter=STOP`.

## Range origin & shapes

Towers expose:

- `get_range_origin()`
- `get_range_shape()` → `SPHERE_3D` (Sentry) or `FLOOR_DISC` (Guard Post)
- `get_range_value()`

No external magic Y offsets outside the tower.

**Sentry (`SPHERE_3D`):** targeting, sphere, and coverage use 3D distance from `RangeOrigin` (cross-floor OK).

**Guard Post (`FLOOR_DISC`):** targeting and coverage use XZ distance only, and only enemies/segments with the same `floor_id`. Range viz is a thin horizontal disc — never a sphere.

**Coverage rule:** whole path segments count as covered if the shape-specific distance ≤ range value (and floor filter for discs).

## Damage accounting

`Enemy.take_damage(amount, source)` is authoritative:

- `actual_damage = min(amount, health_before)` (no overkill in stats)
- updates source tower hit/damage counters with `actual_damage`
- on kill: `record_kill()` + telemetry `enemy_killed` **before** `died` is emitted
- GameManager only handles gold + `enemies_alive` on `died`, then wave completion

Invariant for completed waves/runs:

```text
enemies_spawned = enemies_killed + enemies_leaked
```

Telemetry warns (does not rewrite) on violations, and checks `same_floor_damage + cross_floor_damage ≈ total_damage`.

## Tower types

Build dock iterates unlocked `TowerCatalog` entries via `TowerCard(BUILD)`:

- **Sentry** (`basic_tower`) — 100g, 3D sphere range, projectiles, `PAPER HANDS`. In-match L2 adds **+1.5 range** on current research range for 150g
- **Guard Post** — 120g, floor-local disc, two melee guards (`DIAMOND HANDS`); combat stats from research params; no in-match upgrades; no slow aura

**Guard blocking model:** each Guard engages **one** enemy at a time (1:1). A post can therefore block at most 2 enemies; any additional enemies in the disc keep moving. Engagement pauses enemy pathing until the enemy dies, the guard dies, or disengage. Dead guards respawn independently (default **8s**). Out-of-combat guards heal (default **10 HP/s after 2s**).

Guards attribute damage/kills to the owning Guard Post via `enemy.take_damage(amount, owner_tower)`. Guard Post telemetry also aggregates `enemies_blocked`, `total_block_time_ms`, `guards_died`, `guards_respawned`, `guard_damage_taken`, `guard_healing_done`, and `peak_simultaneous_blocks`.

## App shell, profile, research (v0.9–v0.10)

`run/main_scene` is `scenes/app.tscn` (Main Menu). Gameplay remains `scenes/main.tscn`.

Autoloads:

- `ProfileManager` → persistent `user://profile.json` (not committed)
- `RunManager` → level/difficulty + `research_snapshot` + `last_run`

Flow: Main Menu → Play → Game → Post-Game. Gallery → Tower/Enemy Detail.

**Difficulty** multiplies enemy HP, move speed, melee damage; divides melee interval. Clear reward: `ceil(50 * difficulty_multiplier)` research points.

**Research** is the match source of truth (`tower_research`). Optional named blueprints can save/load params. Build path:

```text
TowerDefinition + research params → BlueprintResolver → resolved_stats → configure_built
```

Research cost uses curved normalized upgrades (`pow(n, 1.7)`). Apply / activate spends/refunds `cost(new) - cost(committed)` RP.

Enemy events stamp `enemy_id` (prototype: `bot`). Lifetime enemy stats live under `lifetime_stats.enemies`.

## Telemetry

`TelemetryManager` writes:

- `res://telemetry/last_run_events.jsonl`
- `res://telemetry/last_run_summary.json`

Summaries include difficulty, research snapshot, and per-tower `resolved_stats` when present. See `telemetry/README.md`. Write failures only `push_warning`. No per-shot JSONL events.

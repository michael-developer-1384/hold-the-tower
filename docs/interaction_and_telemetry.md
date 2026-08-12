# Interaction, Range, Upgrade & Telemetry (v0.6 / v0.6.1)

## Interaction model

`SelectionManager` owns hover, focus, and selection. `BuildManager` handles build/upgrade economy only.

### Hover vs focus

- **Hover** (spot / tower / path picker `mouse_entered`): updates `FloorVisualController.set_hover_floor`. Never moves the camera pivot.
- **Focus** (click spot / tower / path, or keys `1`/`2`/`3`): `OrbitCameraController.set_focus_floor` soft-tweens the pivot to that floor’s `focus_point`.

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
- `get_range_shape()` → `SPHERE_3D` (Basic Tower) or `FLOOR_DISC` (Guard Post)
- `get_range_value()`

No external magic Y offsets outside the tower.

**Basic Tower (`SPHERE_3D`):** targeting, sphere, and coverage use 3D distance from `RangeOrigin` (cross-floor OK).

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

Build panel offers:

- **Basic Tower** — 100g, 3D sphere range, projectiles, L2 range upgrade 4→5.5 for 150g
- **Guard Post** — 120g, floor-local disc radius 2.5, two melee guards (damage 20 / 0.7s), no upgrades
- Enemies inside the Guard Post disc are slowed (~45% speed) while they remain in range

Guards attribute damage/kills to the owning Guard Post via `enemy.take_damage(amount, owner_tower)`.

## Telemetry

`TelemetryManager` writes:

- `res://telemetry/last_run_events.jsonl`
- `res://telemetry/last_run_summary.json`

See `telemetry/README.md`. Write failures only `push_warning`. Restart calls `end_run("restarted")` before scene reload. No per-shot JSONL events.

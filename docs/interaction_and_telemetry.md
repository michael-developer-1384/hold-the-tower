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

## Range origin

Every Basic Tower has a `Marker3D` named `RangeOrigin` (turret height). `BasicTower.get_range_origin()` is the single source of truth for:

- targeting distance
- range sphere center
- path coverage
- upgrade preview sphere / coverage delta
- coverage snapshots in telemetry

No external magic Y offsets outside the tower.

**Coverage rule:** a whole path segment counts as covered if the shortest 3D distance from `RangeOrigin` to that segment is ≤ `attack_range`.

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

## Tower upgrade

Basic Tower:

- L1 range `4.0`, damage `25`, fire interval `0.8`, cost `100`
- L2 range upgrade `5.5` for `150` gold (`max_level=2`)

HUD tower panel shows stats, coverage by floor, and upgrade / MAX LEVEL. Upgrade hover previews outer sphere + newly covered path segments in gold.

## Telemetry

`TelemetryManager` writes:

- `res://telemetry/last_run_events.jsonl`
- `res://telemetry/last_run_summary.json`

See `telemetry/README.md`. Write failures only `push_warning`. Restart calls `end_run("restarted")` before scene reload. No per-shot JSONL events.

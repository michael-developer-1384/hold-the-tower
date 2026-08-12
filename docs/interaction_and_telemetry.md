# Interaction, Range, Upgrade & Telemetry (v0.6)

## Interaction model

`SelectionManager` owns hover, focus, and selection. `BuildManager` handles build/upgrade economy only.

### Hover vs focus

- **Hover** (spot / tower / path picker `mouse_entered`): brightens that floor via `FloorVisualController.set_hover_floor`. Never moves the camera pivot.
- **Focus** (click spot / tower / path, or keys `1`/`2`/`3`): `OrbitCameraController.set_focus_floor` soft-tweens the pivot to that floor’s `focus_point`. Floors above focus stay ghosted (semi-transparent) but still cast shadows via shadow-only proxies. Floors at/below focus always keep the same normal look (no dim/emphasize).

All visible floors stay pickable while building is enabled (not gated to the focused floor). Interaction disables on game over / level complete.

### Collision layers

| Layer | Use |
|---|---|
| 2 | BuildSpot |
| 4 | Tower pick body |
| 8 | Path picker (input only) |

Empty world LMB clears spot + tower selection. MMB orbit ignores selection clicks. HUD controls use `mouse_filter=STOP`.

## Range sphere & path coverage

Selecting a tower shows a translucent unshaded range sphere (`attack_range`) and path coverage overlays.

**Coverage rule:** a whole path segment counts as covered if the shortest 3D distance from the tower origin to that segment is ≤ `attack_range`. Covered segment lengths are summed per `floor_id` (including ramp connector segments tagged by `EnemyPathBuilder`).

Recalc on select / upgrade / path change. Upgrade-button hover shows a second translucent outer sphere at upgraded range (5.5) and highlights newly covered path segments in gold (current coverage stays green).

## Tower upgrade

Basic Tower:

- L1 range `4.0`, damage `25`, fire interval `0.8`, cost `100`
- L2 range upgrade `5.5` for `150` gold (`max_level=2`)

HUD tower panel shows stats, coverage by floor, and upgrade / MAX LEVEL.

## Telemetry

`TelemetryManager` writes:

- `res://telemetry/last_run_events.jsonl`
- `res://telemetry/last_run_summary.json`

See `telemetry/README.md`. Write failures only `push_warning`. Restart calls `end_run("restarted")` before scene reload. No per-shot JSONL events.

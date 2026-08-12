# Telemetry (prototype)

Last-run gameplay telemetry for HoldTheTower prototyping.

## Files

- `last_run_events.jsonl` — one JSON object per line (events)
- `last_run_summary.json` — aggregate summary for the most recent run

## Paths

Files are written under `res://telemetry/` on purpose for the prototype so they stay next to the project and are easy to open in the editor.

**Change this before release** (e.g. `user://` or an external analytics sink). Overwriting last-run files is intentional; there is no history retention yet.

## Events

Includes: `run_started`, `floor_focused`, `wave_started`, `wave_completed`, `tower_built`, `tower_selected`, `tower_upgraded`, `enemy_killed`, `enemy_reached_core`, `game_over`, `level_completed`, `run_ended`.

Combat shot spam is intentionally omitted. Towers aggregate `shots_fired` / hits / damage / kills; those appear in the summary and on build/upgrade coverage snapshots.

`enemy_killed` includes `final_hit_damage` and `enemy_hp_before` (actual damage, not overkill).

## Invariants

For completed waves and finished runs:

```text
enemies_spawned = enemies_killed + enemies_leaked
```

Also expected:

```text
waves_completed <= waves_started
same_floor_damage + cross_floor_damage ≈ total_damage
```

Violations emit `push_warning` only; data is not silently rewritten.

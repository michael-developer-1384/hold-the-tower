# Simulation Observatory

Internal developer cockpit for watching, inspecting, and comparing headless simulation runs. Not a player feature.

## 1. Purpose

The Sim Lab records agent runs into a `ReplayPackage`, then the Observatory watches that package on the **same gameplay graph** used by PLAY and headless SIM. There is no second combat engine and no second Time Machine.

Visible only in debug builds, or when the existing Debug HUD setting is on.

## 2. Architecture (reuse, do not duplicate)

```text
Sim Lab  --RUN DEEP-->  BatchRunner + GameSimulation
                              ↓
                        ReplayPackage  (user://sim/replays)
                              ↓
              WATCH → sim_watch.tscn + PlaybackController
              SEEK  → nearest keyframe ≤ t → SimSnapshot.restore
                      → replay_due_actions + 1/60 ticks
```

| Existing | Role |
|---|---|
| `SimSnapshot.capture` / `restore` | Exact rewind (same path as `validate_sim_clone`) |
| `GameSimulation.set_replay` / `replay_due_actions` | Command replay |
| `SimRunner` | Speed = more 1/60 ticks (`time_scale=N`, `physics_ticks=60*N`) |
| `action_log` `{time, action}` | Commands (WAIT omitted) |
| PLAY `timeline_recorder` + `SessionStore` | Unchanged. Human PLAY only |
| Command Center tokens | Lab + Observatory HUD |

New: `keyframe_buffer.gd` (sim-clock + `SimSnapshot.capture`). Not a second PLAY recorder.

## 3. Recording modes

Batch default is **NONE**. Lab 5-seed runs use **DEEP**. Clones never record.

| Mode | Writes |
|---|---|
| `none` | Result only. No extra disk, no keyframes, no event JSONL |
| `summary` | Result + `action_log` |
| `replay` | + keyframes (every 2s sim-time and after PLACE / UPGRADE / START_WAVE / wave / leak / end) + compact `event_log` |
| `deep` | + full agent decisions (no 64-cap), Top-K places, all upgrades/waves, lookahead projection of the chosen action |

CLI: `--record none|summary|replay|deep` on `simulate_batch.gd`.

Telemetry JSONL is not opened per event in NONE/SUMMARY (`TelemetryManager.write_disk`).

## 4. ReplayPackage schema

Path: `user://sim/replays/<run_id>.json`. `schema_version = 1`. Incompatible schema → message, no crash.

Fields: `run_id`, `created_at`, `level_id`, `difficulty_id`, `seed`, `world_seed`, `decision_seed`, `agent_id`, `player_profile`, `agent_config`, `simulation_config`, `initial_snapshot`, `action_log`, `agent_decisions`, `event_log`, `keyframes`, `final_result`, `metrics` (includes `behavior`: best-action rate, ranks, regret), `storage` (bytes, keyframe/action/decision/event counts). Schema stays 1; new fields are optional.

Retention: `ReplayStore` keeps `max_retained` (40) plus delete/clear from the Lab library tab.

Vector3 values are sanitized for JSON and restored on load.

## 5. Seek and keyframes

Seek is **not** reverse physics.

1. Nearest keyframe with `t <= target` (or `initial_snapshot`).
2. `SimSnapshot.restore`.
3. `set_replay(action_log, keyframe_t)` so earlier commands are not re-applied.
4. Tick forward at 1/60 until `target`.

Slider drag previews the keyframe only. Release does an exact seek. Scrub mutates gameplay only via restore.

## 6. Watch host

`scenes/sim/sim_watch.tscn` = sim host + WorldEnvironment / Light + CameraRig + SelectionManager + RangeVisualization + Observatory HUD.

Headless `HOST_SCENE` remains `scenes/sim/sim_host.tscn`.

Watch sets `SimContext.presentation = true` and `persist_profile = false`. Audio is on at speed ≤ 2×, muted above (manual override on the HUD).

The agent **never** re-decides. Watch only calls `set_replay(action_log)`.

Return from Watch remounts the Command Center with `pending_route_on_boot = sim_lab`.

## 7. Playback controls

`PlaybackController`: pause (tree paused; camera / selection `PROCESS_MODE_ALWAYS`), speeds 0.25–40 + MAX via `SimRunner`, event prev/next, +1 / +10 tick, +1s.

The renderer is sampled; every 1/60 gameplay tick still runs.

## 8. Developer UI

Hidden `SIM LAB` nav in the Command Center (`NavDev`). Route `ROUTE_SIM_LAB`.

`ui/pages/simulation_lab_page.tscn`: level / difficulty / agent / **player profile** / temperature label / seeds / lookahead / speed / record + RUN + run list + inspect + compare + replay library (delete / clear).

List columns: seed, agent, profile, WIN/LOSS, core, duration, best-action %, avg regret, Sentry/Guard. Tags when they apply: PERFECT POLICY, FIRST LOSS, LOWEST CORE, HIGHEST REGRET, MOST DIVERGENT BUILD, STRATEGIC DUPLICATE. Sort: seed / result / core / duration.

Actions: WATCH, INSPECT (overview panel), COMPARE (two runs, text).

Watch is its own host, not a shell page.

## 9. Inspectors

- **Run overview** before Watch: seed / agent / result / metrics + WATCH.
- **Event timeline** with markers (wave, build, leak, kill, guard, agent, end). Filters: ALL / AGENT / BUILD / WAVE / LEAK / KILL / GUARD.
- **Agent decision**: `SMART · COMPETENT  DECISION #14`, chosen / rank of N / best / scores / regret. Badge `BEST ACTION CHOSEN` or `SUBOPTIMAL · RANK 2 · REGRET 1.0`. No “bad player” labels. Options + breakdown + lookahead projection as data (no VIEW FUTURE).
- **Tower click**: existing `get_ui_stat_lines` + telemetry fields.
- **Enemy click** (Watch only): HP, floor, progress, combat, runtime_id.

Overlays default OFF: WORLD DEBUG (range, target line, IDs), SHOW ACTION SCORES at spots on decision events.

Observatory UI does not change sim state except playback / seek.

## 10. Compare V1

Action-log diff plus **FIRST DECISION DIVERGENCE** (time, decision #, actions, scores, regret). WATCH FROM HERE A / B opens Watch at `t`. No side-by-side 3D. Outcome-divergence is not in V1.

## 11. Determinism CLI

```text
godot --headless --path . --script res://scripts/tools/validate_replay.gd
```

1. Scripted run → save ReplayPackage.
2. Load → replay to end → assert won / kills / leaks / core / damage / gold / tower composition.
3. Seek 30 → end; seek 60 → end; seek 60 → 20 → end. Same finals.

Existing `validate_sim` / `validate_v06` / `validate_sim_fidelity` / `validate_sim_clone` stay green. Batch without `--record` must not write extra keyframes, decisions, or replay files.

## 12. How to run

In a debug build (or with Debug HUD on): Command Center → **SIM LAB**.

```text
# Headless batch with optional recording
godot --headless --path . --script res://scripts/tools/simulate_batch.gd -- --agent smart --runs 5 --seed 1 --record deep
```

## 13. Prepared, not built

Branch preview (`SHOW ALTERNATE FUTURE`) is not in V1. The package already stores `initial_snapshot` + action log + keyframes so a later restore + different action is possible.

## 14. Not in V1

Video, cloud, side-by-side 3D, heatmaps, MCTS / RL visualization, manually rewriting a run.

## 15. Limits

- Seek jumps to a keyframe then plays forward. There is no reverse-physics scrub.
- DEEP packages are large (full snapshots every 2s).
- Lab RUN blocks the Command Center until the batch finishes.
- Enemy inspect exists only in Watch, not in PLAY.
- `level_id` still does not swap geometry.
- After a mid-run seek, `START_WAVE` is held until the restored wave finishes (a few ticks of slack). No reverse physics.

## Acceptance snapshot

Measured 2026-08-13, `vertical_test` / normal / 0 research / 40× unless noted.

| Check | Result |
|---|---|
| `validate_replay` | PASS (load→end, seek 30, seek 60, seek 60→20→end) |
| `validate_sim` | OK |
| `validate_sim_clone` | PASS |
| `validate_sim_fidelity` | OK (1/5/10/20/40×) |
| `validate_v06` | OK |

Headless wall for one smart seed (~120s sim): NONE 3.71s, REPLAY 3.91s, DEEP 3.89s. Replay file ~830 KB; DEEP ~1.27 MB.

Five-seed DEEP (`--agent smart --runs 5 --seed 1 --record deep`, no lookahead): all WIN, core 20, ~120s, 10 sentries, 16.85s wall.

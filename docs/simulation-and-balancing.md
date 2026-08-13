# Simulation & Balancing Lab (V1)

Headless simulation, auto-players, and batch balance tooling for HODL THE TOWER.

## 1. Architecture

```text
Catalogs / Level / Waves
        ↓
Gameplay graph (same nodes as PLAY)
        ↓
GameSimulation host (sim_host.tscn)
   ├── Presentation optional (no HUD/camera/audio)
   ├── SimActions (PLACE / UPGRADE / START_WAVE / WAIT)
   ├── Agents (Random / Basic / Smart)
   └── SimMetrics → BatchRunner / ParameterSearch
```

**One truth:** humans and agents issue the same `SimActions`. There is no second combat engine. Projectiles remain real flying nodes with travel time and target loss.

Key modules:

| Path | Role |
|---|---|
| `scripts/sim/sim_context.gd` | Sim flags, overrides, sim-time clock access |
| `scripts/sim/sim_clock.gd` | Fixed 1/60 step + delayed callbacks |
| `scripts/sim/seeded_rng.gd` | Deterministic RNG for agents |
| `scripts/sim/game_simulation.gd` | Host API: step / run / execute / clone hook |
| `scripts/sim/sim_actions.gd` | Shared command surface |
| `scripts/sim/agents/*` | Random / Basic / Smart |
| `scripts/sim/balance/*` | Batch runner, report, parameter search |
| `scenes/sim/sim_host.tscn` | Gameplay-only scene (`current_scene` for projectiles) |

## 2. Headless Simulation

```text
godot --headless --path . --script res://scripts/tools/simulate_batch.gd -- --agent basic --runs 100 --seed 1
```

- Host scene has TowerLevel, WaveManager, BuildManager, Telemetry, GameManager — no HUD/camera/selection/range viz.
- `SimContext.skip_presentation()` disables death tweens, hit flashes, floating text, attack-lunge visuals.
- Wave spawns use a physics-frame accumulator (not `SceneTreeTimer`).
- Combat ticks on `_physics_process` (Sentry + Guard Post respawn moved off `_process`).
- Profile XP/RP and session saves are disabled during simulation.

## 3. Determinism / Seeds

A run is defined by `{ level_id, difficulty_id, seed, agent/strategy, config }`.

- Agents use `SeededRng` only.
- Combat currently has no gameplay RNG (audio pitch excluded).
- Same seed + same scripted/agent decisions → same `won`, kills, leaks, lives, waves.
- `clone()` / lookahead restore is **not** bit-exact yet (session snapshot gaps: projectiles, cooldowns, spawn queue).

## 4. Agent System

```gdscript
agent.decide(ctx) -> { action, score, breakdown }
```

Context includes public state, legal actions, seeded RNG, path meta, and the simulation handle.

Decision points: interval (default 0.5s sim), leaks, and whenever the agent is polled. Agents must not mutate internal combat state — only `SimActions.execute`.

Temperature / `decision_noise` supports synthetic player profiles (`beginner` … `optimizer` presets on `game_agent.gd` `profile_temperature`).

## 5. Available Agents

| Id | Behavior |
|---|---|
| `random` | Uniform legal action (baseline) |
| `basic` | Transparent `scoreAction` weights (coverage, upgrade, wave timing) |
| `smart` | Extensible scoring + lookahead **hook** (heuristic-backed in V1) |

## 6. Balance Runner

```text
godot --headless --path . --script res://scripts/tools/simulate_batch.gd -- --agent smart --runs 100
godot --headless --path . --script res://scripts/tools/simulate_batch.gd -- --compare --runs 50
godot --headless --path . --script res://scripts/tools/simulate_search.gd -- --param enemy_health --target-winrate 0.5 --agent smart --runs 20
```

Outputs stdout report + `user://sim/last_batch.json`.

## 7. Metrics

`SimulationResult`: seed, level, difficulty, won, duration (sim seconds), waves, lives, spawned/killed/leaked, credits earned/spent, towers placed, total damage, same/cross-floor damage, tower_stats, action_log, agent_metrics, wall_clock, sim_speed.

Tower stats reuse live combat counters (shots, hits, overkill, idle/active time, gold invested). No invented crit/miss rates.

Warnings (thresholds): possible dominant / underused towers.

## 8. Add a new agent

1. Create `scripts/sim/agents/my_agent.gd` extending `game_agent.gd`.
2. Implement `decide(ctx)` (and optionally `score_action`).
3. Register in `BatchRunner.make_agent`.
4. Pass `--agent my_id`.

## 9. Add a new metric

1. Prefer reading existing tower/telemetry fields in `SimMetrics.build_result`.
2. For trait-specific stats, have the trait record on the tower/enemy, then aggregate in metrics.
3. Extend `aggregate` / `format_report` as needed.

## 10. Difficulty Parameters

PLAY still uses `DifficultyCatalog`’s single multiplier.

Sim `config` overrides (defaults = current behavior):

| Key | Effect |
|---|---|
| `enemy_health` | HP multiplier at spawn |
| `enemy_speed` | Speed multiplier |
| `enemy_damage` | Melee damage up / interval down |
| `enemy_count` | Wave count scale |
| `spawn_rate` | Shorter spawn intervals when > 1 |
| `starting_gold` | Replace starting gold |

`ParameterSearch` binary-searches one monotonic param toward a target winrate.

## 11. Current Limitations

- Attack lunge is visual-only (combat transform no longer moves). Death tween skipped in sim; targeting ignores dead enemies in both modes.
- `clone()` / lookahead is architectural — not a full combat restore (`sim_snapshot.gd` placeholders).
- Fast batches use `Engine.time_scale`; SimClock advances by `(1/60)*time_scale` so metrics match scaled game time. Very large deltas can diverge slightly from 60 Hz PLAY for discontinuous events.
- `level_id` does not swap geometry yet (always `TestLevelFactory`).
- No Sell / in-match Research / targeting modes (they do not exist in PLAY).
- Smart lookahead does not fork a live clone; it boosts heuristic scores.
- Batch is single-threaded.
- No Dev UI / Watch Run yet.
- Winrate ≠ “fun”; reports are a baseline for human judgment.

## 12. Next sensible upgrades

1. Complete combat snapshot (projectiles, cooldowns, spawn queue, guard engage) for real `clone()`.
2. Small-horizon lookahead on true clones.
3. Dev Simulation Lab page + optional Watch Run replay from `action_log`.
4. Parallel workers for batch seeds.
5. Trait-registered analytics hooks.
6. Broader difficulty axes without collapsing to one global multiplier.

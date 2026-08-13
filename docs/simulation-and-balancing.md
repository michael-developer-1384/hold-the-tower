# Simulation & Balancing Lab

Headless simulation, auto-players, and batch balance tooling for HODL THE TOWER.

## 1. Architecture

```text
Catalogs / Level / Waves
        ↓
Gameplay graph (same nodes as PLAY)
        ↓
GameSimulation host (sim_host.tscn)
   ├── SimRunner (fixed 1/60 gameplay step)
   ├── SimActions (PLACE / UPGRADE / START_WAVE / WAIT)
   ├── Agents (Random / Basic / Smart)
   └── SimMetrics → BatchRunner / ParameterSearch
```

**One truth:** humans and agents issue the same `SimActions`. There is no second combat engine.

## 2. Simulation Fidelity

A simulated second is the same discrete gameplay as PLAY: `GAMEPLAY_STEP = 1/60`.

```text
GAMEPLAY TIME  !=  WALL CLOCK TIME
```

Fast-sim means more 1/60 ticks per wall-second, never a fatter delta.

## 3. Fast Simulation Model

[`scripts/sim/sim_runner.gd`](../scripts/sim/sim_runner.gd):

```text
Engine.time_scale = N
Engine.physics_ticks_per_second = 60 * N
SimClock step = 1/60
```

Effective `delta` stays `1/60`. Default batch speed is **40×** (fastest mode that passed `validate_sim_fidelity`).

Telemetry timestamps use `SimContext.sim_time_ms` while simulating.

## 4. Speed Validation

```text
godot --headless --path . --script res://scripts/tools/validate_sim_fidelity.gd
```

Phase A records a scripted action log at 1×. Phase B replays that exact log at 1 / 5 / 10 / 20 / 40×. No agent re-decides.

Report: Speed | Wall | Sim Time | Effective Speed | PASS/FAIL, plus first divergence time/field.

## 5. Agent Bias vs Mechanical Utility

Score parts are tagged:

| type | meaning |
|---|---|
| `mechanical` | Catalog DPS, coverage, upgrade efficiency |
| `behavioral_bias` | Human-like preference (Basic only) |
| `lookahead` | Future-state score from a live clone |
| `known` | Public wave-catalog threat (not hidden future waves) |

Reports split Mechanical / Behavior Bias / Lookahead / Final.

## 6. Human-like vs Optimizer Agents

| Id | Role |
|---|---|
| `random` | Uniform legal action |
| `basic` | Human-like. Explicit sentry/guard/floor/hoard biases, tagged `behavioral_bias` |
| `smart` | Optimizer. No tower-id bonuses. Stats from `TowerDefinition`. True clone lookahead when `--lookahead` |

Tower damage, fire interval, range, shape, cost, unit count come from [`tower_catalog.gd`](../scripts/towers/tower_catalog.gd) / action payload — not hardcoded 25/0.8 or 4.0/2.5.

## 7. Snapshot / Clone Guarantees

[`sim_snapshot.gd`](../scripts/sim/sim_snapshot.gd) captures and restores:

- match (gold, core, waves, spawn_finished)
- wave queue / spawn timer
- enemies (runtime id, HP, path, melee CD, engage id)
- towers (runtime id, cooldown, level)
- guards (HP, state, CDs, respawn timers)
- projectiles (position, target, source, speed, damage)
- SimClock / SeededRng / decision cursor

PLAY `SessionStore` is unchanged.

```text
godot --headless --path . --script res://scripts/tools/validate_sim_clone.gd
```

Roundtrip: run to 60s → capture → continue +30s vs restore → +30s.

## 8. True Lookahead

`evaluate_action_with_lookahead()` clones via snapshot, applies the action, simulates `lookahead_horizon_seconds` (default 3s) with no agent, scores lives / leaks / enemy HP / damage / gold, then destroys the clone.

Enable on batch: `--lookahead`. Off by default so large batches stay cheap.

Wave catalog used in scoring is **known** public info. No hidden future waves.

## 9. Balance Warning Confidence

High pick rate alone is not a nerf signal.

| Severity | When |
|---|---|
| `OBSERVATION` | High pick rate while the agent has an explicit bias → `INCONCLUSIVE` |
| `SUSPICIOUS` | Optimizer, no declared bias, high pick rate, small sample |
| `STRONG_SIGNAL` | Optimizer, no bias, high pick rate, large sample (n ≥ 200) |

No automatic nerf recommendations.

## 10. CLI

```text
godot --headless --path . --script res://scripts/tools/validate_sim.gd
godot --headless --path . --script res://scripts/tools/validate_v06.gd
godot --headless --path . --script res://scripts/tools/validate_sim_fidelity.gd
godot --headless --path . --script res://scripts/tools/validate_sim_clone.gd
godot --headless --path . --script res://scripts/tools/simulate_batch.gd -- --agent basic --runs 10 --seed 1
godot --headless --path . --script res://scripts/tools/simulate_batch.gd -- --compare --runs 5
godot --headless --path . --script res://scripts/tools/simulate_search.gd -- --param enemy_health --target-winrate 0.5 --agent smart --runs 10
```

## 11. Known Limitations

- Attack lunge is visual-only. Death tween skipped in sim; targeting ignores dead enemies in both modes.
- Clone is gameplay-equal, not bit-identical floats / tree order.
- Lookahead clones are sequential and expensive.
- `level_id` does not swap geometry yet (always `TestLevelFactory`).
- Batch is single-threaded.
- Winrate ≠ “fun”. Reports are not a license to nerf.

## 12. Next

1. Parallel workers for batch seeds.
2. Dev Simulation Lab / Watch Run.
3. Omniscient optimizer (explicit hidden-future flag).
4. Balancing only after fidelity stays green.

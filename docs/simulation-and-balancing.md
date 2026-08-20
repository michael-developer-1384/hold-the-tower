# Simulation & Balancing Lab

Headless simulation, auto-players, replay tooling, and batch balance analysis for HODL THE TOWER (v0.19.0).

## 1. Architecture

```text
Catalogs / Level / Waves
        ↓
Gameplay graph (same nodes as PLAY)
        ↓
GameSimulation host (sim_host.tscn)
   ├── SimRunner (fixed 1/60 gameplay step)
   ├── SimActions (PLACE / UPGRADE / START_WAVE / WAIT)
   ├── Agents (Random / Basic / Smart + Balance BuildSearchAgent)
   └── SimMetrics → BatchRunner / Balance Lab / Parameter Search
```

**One truth:** humans, generic agents, Balance Lab agents, and replays use the same gameplay action surface. There is no second combat or market engine. Meltdown runs on that same graph with seeded simulation RNG.

SIM never persists gameplay or progression state. `SimContext.begin()` suppresses profile persistence and normal scene/session side effects. Diagnostic replay/telemetry output is not player-profile persistence.

## 2. Simulation fidelity

A simulated second uses the same discrete gameplay step as PLAY:

```text
GAMEPLAY STEP = 1/60 s
GAMEPLAY TIME != WALL CLOCK TIME
```

Fast simulation increases how many 1/60 physics ticks are processed per wall-clock second; it does not increase the gameplay delta.

## 3. Fast simulation model

[`scripts/sim/sim_runner.gd`](../scripts/sim/sim_runner.gd) applies:

```text
Engine.time_scale = N
Engine.physics_ticks_per_second = 60 * N
SimClock step = 1/60
```

Default batch speed remains **40×**.

Telemetry timestamps use simulation time rather than wall time while SIM is active.

## 4. Speed validation

```text
godot --headless --path . --script res://scripts/tools/validate_sim_fidelity.gd
```

The dedicated simulation-fidelity tooling compares the same scripted behavior at normal and accelerated speeds. Balance Lab 2.0 also exposes a shorter `fidelity` suite that records at 1× and replays the same log at 40×.

The v0.19 fidelity probe compares spawn count, damage, kills, leaks, blocking, projectile hits, cross-floor hits, fire count, Core HP, economy, duration, and enemy path progress.

Speed fidelity and replay-seek fidelity are separate contracts. Use `validate_replay.gd` for persistence/seek behavior.

## 5. Agent bias vs mechanical utility

Score parts remain tagged by meaning:

| type | meaning |
|---|---|
| `mechanical` | Catalog stats, coverage, upgrade efficiency |
| `behavioral_bias` | Human-like preference |
| `lookahead` | Future-state score from a live clone |
| `known` | Public wave information rather than hidden future state |

Reports should keep mechanical evidence separate from behavioral preference and clone lookahead.

## 6. Generic agents and player profiles

Generic SIM agents (`random` / `basic` / `smart`) are distinct from player profiles. A player profile controls how reliably an agent follows its ranking.

| Agent | Role |
|---|---|
| `random` | Uniform affordable action selection with simple wave-start behavior. |
| `basic` | Human-like heuristic with explicit behavioral biases. |
| `smart` | Mechanical utility; optional clone lookahead. |

| Profile | Temperature | Band | early_call_skill | Meaning |
|---|---:|---:|---:|---|
| `optimizer` | 0 | 0 | 1.0 | Always rank 1. |
| `expert` | 1.0 | 5 | 0.9 | Near-best decisions. |
| `competent` | 6.0 | 22 | 0.55 | Usually strong but imperfect. |
| `casual` | 10.0 | 40 | 0.25 | Wider choice band. |
| `beginner` | 18.0 | 80 | 0.0 | Broadly imperfect. |

Two deterministic RNG streams derive from the master seed: world RNG and decision RNG. World simulation randomness is separated from agent choice randomness.

## 7. Balance Lab 2.0 build-search agents

The v0.19 Balance Lab adds a dedicated [`BuildSearchAgent`](../scripts/balance/agents/build_search_agent.gd) for generated full-build fixtures:

- **COMPETENT:** beam width 2, heuristic scoring, no clone lookahead.
- **OPTIMIZER:** beam width 4. The agent class supports clone lookahead, but the Balance Lab runner explicitly disables it by default for runtime performance.
- `--optimizer-lookahead` enables the expensive path; Balance Lab recording then bounds it to two candidate actions and a two-second horizon per decision.

This is a deliberate performance/quality switch. The default OPTIMIZER is a deterministic strong heuristic baseline, not an exhaustive search.

For broad Balance Lab runs this is one of the main reasons v0.19 can be substantially faster than a naïve “look ahead on every optimizer choice” implementation.

## 8. Snapshot / clone guarantees

[`sim_snapshot.gd`](../scripts/sim/sim_snapshot.gd) captures/restores gameplay state needed by SIM, replay, and clone workflows, including match state, economy/market state, waves, enemies, towers, projectiles, simulation clock, and RNG state.

PLAY `SessionStore` remains a separate persistence concern.

Clone validation:

```text
godot --headless --path . --script res://scripts/tools/validate_sim_clone.gd
```

Clones are intended to preserve gameplay behavior closely enough for lookahead and analysis; they are not promised to be bit-identical in every float/tree-order detail.

## 9. Clone lookahead

`evaluate_action_with_lookahead()`:

1. snapshots the parent simulation;
2. boots a clone;
3. applies one candidate action;
4. simulates a short future horizon with no agent decisions;
5. scores lives, leaks, enemy pressure, damage, and Buying Power;
6. destroys the clone and restores parent processing/context.

Clones are sequential and expensive. Generic smart-agent batches therefore keep lookahead optional, and Balance Lab 2.0 keeps optimizer lookahead off by default unless `--optimizer-lookahead` is explicitly requested.

## 10. Replay and seek

Replay packages freeze action logs and deterministic context. Current JSON seek deliberately uses a conservative path:

- restore the initial snapshot;
- reset replay cursor / finish state;
- fast-forward through the action log to the requested simulation time.

Mid-combat JSON keyframe restore is **not yet trusted** for spawn/combat restore.

Validation:

```text
godot --headless --path . --script res://scripts/tools/validate_replay.gd
```

The validator covers load→end, seek-zero early placement replay, seek30→end, seek60→end, and seek60→20→end.

### Balance Lab reporting caveat

The current v0.19 `balance_analysis_runner.gd` sets its report-level `replay_fidelity` field to PASS after running the speed-fidelity suite, without invoking the standalone replay validator in that same execution. Therefore a Balance Lab report's `replay_fidelity: PASS` is not standalone evidence that the seek suite ran on that commit.

Treat `validate_replay.gd` as the replay/seek gate until the report contract is hardened.

## 11. Counterfactual replay caveat

Counterfactual and Shapley analysis intentionally keep the recorded action log frozen while removing selected tower actions. However, replayed actions still execute through the live `SimActions` / build path.

Historical PLACE entries contain their recorded quote, but the current execution path calls live placement again. Removing an earlier purchase can therefore alter later Buying Power / HODL quote state, and a later action that still exists in the frozen log can fail.

This matters most for marginal attribution. A counterfactual result should be treated cautiously if later action legality diverges. See [deterministic-balancing-lab.md](deterministic-balancing-lab.md) and [balance-lab.md](balance-lab.md).

## 12. Balance Lab suite/runtime model

The canonical v0.19 entry point is:

```text
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite <suite>
```

Suites:

```text
isolated
full-build
counterfactual
shapley
meltdown-search
defense-margin
difficulty-frontier
fidelity
all
```

The default is `isolated`.

`--suite all` uses the fast-default optimizer and also forces the Meltdown parameter search into quick mode. Use `--optimizer-lookahead` when deeper optimizer quality is more important than wall time.

## 13. Balance warning confidence

High pick rate alone remains insufficient evidence for a nerf. Separate:

- agent preference / behavioral bias;
- mechanical utility;
- realized marginal value;
- placement sensitivity;
- level/difficulty pressure;
- measurement fidelity.

A balance report is diagnosis, not authorization to automatically alter tower numbers.

## 14. CLI

Core simulation validation:

```text
godot --headless --path . --script res://scripts/tools/validate_sim.gd
godot --headless --path . --script res://scripts/tools/validate_sim_fidelity.gd
godot --headless --path . --script res://scripts/tools/validate_sim_clone.gd
godot --headless --path . --script res://scripts/tools/validate_replay.gd
godot --headless --path . --script res://scripts/tools/validate_balance.gd
```

Generic agent batches:

```text
godot --headless --path . --script res://scripts/tools/simulate_batch.gd -- --agent basic --runs 10 --seed 1
godot --headless --path . --script res://scripts/tools/simulate_batch.gd -- --agent smart --profile competent --runs 5 --seed 1 --record deep
godot --headless --path . --script res://scripts/tools/simulate_batch.gd -- --compare --runs 5
```

Balance Lab:

```text
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite isolated
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite all --difficulty normal --seed 7
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite all --optimizer-lookahead --difficulty normal --seed 7
```

## 15. Known limitations

- Attack lunge is visual-only; simulation measures combat state rather than presentation animation.
- Clone is gameplay-equal within validation tolerances, not guaranteed bit-identical in every implementation detail.
- Clone lookahead is sequential and expensive.
- `level_id` does not yet imply arbitrary production geometry in every SIM path.
- Batch execution is single-threaded.
- Winrate is not equivalent to fun or good balance.
- The fast Balance Lab default intentionally trades optimizer search depth for wall-clock performance.
- Replay-seek PASS must currently come from the standalone replay validator, not merely the Balance Lab report field.
- Counterfactual frozen-log analysis still needs stronger enforcement that later replay actions remain executable after economy-changing removals.

## 16. Related documentation

- Combat value, placement, counterfactuals, Shapley, difficulty: [deterministic-balancing-lab.md](deterministic-balancing-lab.md)
- Report suites, artifacts, runtime profile, current v0.19 caveats: [balance-lab.md](balance-lab.md)
- Simulation watch / inspect / compare: [simulation-observatory.md](simulation-observatory.md)


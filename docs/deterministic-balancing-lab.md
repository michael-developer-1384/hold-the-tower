# Deterministic Balancing Lab (v0.19.0)

HODL THE TOWER measures combat value on the **same gameplay graph as PLAY** instead of trying to balance the game from winrate alone. The lab combines exact analytical path math where possible with deterministic gameplay replays where interactions matter.

Balance Lab 2.0 adds generated full-build agents, realized counterfactual value, exact/sampled Shapley attribution, simulation fidelity, defense-margin/frontier analysis, and Meltdown parameter search.

See [balance-lab.md](balance-lab.md) for suite selection, runtime tradeoffs, report contracts, and current v0.19 caveats.

## Potential vs actual

| Layer | Meaning |
|---|---|
| **Potential** | Analytical: range ∩ path, catalog DPS, lava fill rates. An upper / idealized bound. |
| **Actual** | Isolated or full `GameSimulation`: real targeting, overkill, downtime, blocking, lava flow. |
| **Marginal / realized** | Frozen-log counterfactual: what the build loses when a tower is removed, including indirect effects. |

`theoretical_damage` vs `actual_damage` exposes poor placement, downtime, overkill, density, or kill stealing.

Winrate is **not** a tower-balance criterion. A win can hide a 2× over-defended map or a single dominant placement.

## Tower balance vs difficulty

Sentry vs Guard vs Meltdown is **tower balance**.

Whether Normal is too easy or too hard is **level / difficulty pressure**: incoming HP, speed, spawn pressure, count, and economy.

If Sentry and Guard are economically close, do **not** nerf both merely because Normal feels easy. Change waves or difficulty pressure instead.

## Path exposure

[`PathCoverageCalculator`](../scripts/level/path_coverage_calculator.gd) returns covered segment indices for UI.

Lengths come from [`PathExposureCalculator`](../scripts/level/path_exposure_calculator.gd):

- **SPHERE_3D:** exact line-segment ∩ sphere.
- **FLOOR_DISC:** exact XZ circle ∩ segment, matching `floor_id` only.

```text
enemy_exposure_seconds = covered_path_length / enemy_speed
```

A segment that merely clips range contributes its chord, not its complete length.

## Archetype valuation

One dispatcher, [`combat_value_model.gd`](../scripts/balance/combat_value_model.gd), owns the analytical tower formulas.

- **Sentry:** damage / fire interval, scaled by exposure / uptime potential.
- **Guard:** melee DPS × `unit_count` plus potential extra exposure from blocking. Real blocking synergy is measured by counterfactuals.
- **Meltdown:** lava damage, pour rate, lifetime, flow, mass scales, occupancy, cross-floor behavior. It is **never** reduced to `base_damage / base_fire_interval`.

## Build timing and placement sensitivity

Isolated runs place one tower at one spot and play the remaining waves. Leaks are allowed because the purpose is local tower measurement.

Timing matrix: tower placed before waves 1–5.

```text
early_build_multiplier = value_if_built_wave_1 / median_build_value
```

Across spots, isolated `value_per_gold` uses catalog cost rather than the run-relative market quote:

```text
placement_sensitivity = stdev / max(mean, ε)
```

Sensitivity bands are design labels from [`balance_targets.gd`](../scripts/balance/balance_targets.gd), not automatic nerf recommendations.

## Full-build agents

v0.19 generates two deterministic build baselines before replaying them:

- **COMPETENT:** beam-2 heuristic search, no clone lookahead.
- **OPTIMIZER:** beam-4 scoring. Clone lookahead is **off by default** for performance and can be enabled with `--optimizer-lookahead`.

With lookahead enabled in the Balance Lab runner, the expensive clone path is deliberately bounded to two candidates and a two-second future horizon per decision.

This distinction matters when reading reports: the fast default OPTIMIZER is a strong deterministic heuristic baseline, not proof of globally optimal play.

## Counterfactuals and realized value

A counterfactual replays the same seed and frozen action log with one tower's PLACE and UPGRADE actions removed. The agent does not re-decide.

Realized tower value can include:

- direct damage;
- damage enabled for other towers;
- leak prevention;
- Core HP preservation;
- measured utility.

This gives Guard blocking and other interaction-heavy effects a measurable value instead of guessing them from theoretical DPS.

### Frozen-log invariant caveat

The intended invariant is “all non-target decisions stay fixed”. Current replay still executes actions through the live `SimActions` / build path. Removing an earlier purchase can change later economy / market state, so a later replayed PLACE can become unaffordable or otherwise fail.

The one-target counterfactual path exposes an `other_actions_unchanged` check, but build-wide counterfactual/Shapley analysis does not currently reject every failed later replay action. Treat surprising marginal values as diagnostic until replay action legality is hardened.

## Shapley attribution

Shapley distributes coalition value across placed tower spots:

- **N ≤ 5:** exact `2^N` subset replay.
- **N > 5:** deterministic seeded sampled Shapley (default 24 samples), reported with lower confidence.

For exact runs, the Shapley sum should match grand coalition minus empty coalition within tolerance. Sampled runs are an approximation and should be interpreted accordingly.

## Difficulty pressure

Difficulty presets expose:

`health_multiplier`, `speed_multiplier`, `damage_multiplier`, `spawn_rate_multiplier`, `enemy_count_multiplier`

Stock presets currently keep spawn-rate and count at 1.0.

HP × speed is super-linear pressure for ranged defense. Example: Hard at 1.25 HP × 1.25 speed is roughly 1.56× ranged pressure, not merely +25%.

Difficulty analysis can add:

- a competent/optimizer full-build baseline;
- defense-margin binary search;
- a health × speed frontier.

Tower balance and difficulty pressure remain separate questions.

## Simulation fidelity

The v0.19 fidelity probe records a short scripted fixture at `1×`, replays the same log at `40×`, and compares gameplay metrics. This validates accelerated simulation against normal-speed simulation.

It is **not** the same as replay seek validation.

Run persistence/seek validation separately:

```text
godot --headless --path . --script res://scripts/tools/validate_replay.gd
```

Current JSON replay seek restores the initial snapshot and fast-forwards. Mid-combat JSON keyframe restore is intentionally not trusted yet.

Also note the current v0.19 report caveat documented in [balance-lab.md](balance-lab.md): the Balance Lab runner can stamp `replay_fidelity: PASS` after its speed-fidelity suite without executing the standalone replay validator in that same run.

## Meltdown parameter search

Balance Lab 2.0 ships a multi-objective Meltdown search using the declared design targets. It can evaluate and recommend a candidate without modifying gameplay values.

Applying a recommendation requires the explicit write flag:

```text
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite meltdown-search --apply-recommended
```

Normal analysis remains read-only with respect to combat catalog values.

## CLI

```text
# Isolated economic / placement baseline
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite isolated

# Generated full build
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite full-build

# Realized interaction value
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite counterfactual
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite shapley

# Broad fast-default report
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite all --difficulty normal --seed 7

# Deeper optimizer search
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite all --optimizer-lookahead --difficulty normal --seed 7

# Validation
godot --headless --path . --script res://scripts/tools/validate_balance.gd
godot --headless --path . --script res://scripts/tools/validate_replay.gd
godot --headless --path . --script res://scripts/tools/validate_sim_fidelity.gd
```

JSON: `res://balance_reports/latest_balance_report.json`.

HTML and AI export are written by default unless explicitly disabled. Detailed artifact/report behavior lives in [balance-lab.md](balance-lab.md).

## Interpretation rule

Warnings and recommendations are **diagnosis**, not permission to blindly change numbers. A balance change should be based on the relevant evidence layer:

- isolated measurements for local tower economy / placement;
- counterfactual/Shapley for interaction value;
- competent/optimizer full builds for level viability;
- fidelity validators for trust in the measurement path.

A fast report is useful only if the suite actually measured the claim being made.

# Deterministic Balancing Lab (v0.18 / v0.18.1)

HODL THE TOWER can measure combat value instead of averaging thousands of random runs.

Simulation still uses the **same** tower, enemy, wave, lava, and combat graph as PLAY. The lab adds analysis around that graph: exact path math where closed-form is possible, and deterministic replays where interactions matter.

## Potential vs actual

| Layer | Meaning |
|---|---|
| **Potential** | Analytical: range ∩ path, catalog DPS, lava fill rates. An upper / idealized bound. |
| **Actual** | Isolated or full GameSimulation: real targeting, overkill, downtime, blocking, lava flow. |

`theoretical_damage` vs `actual_damage` is how we see bad placement, overkill, density, or other towers stealing kills.

Winrate is **not** a balance criterion. A win can hide a 2× over-defended map or a single broken spot.

## Tower balance vs difficulty

Sentry vs Guard vs Meltdown is **tower balance**.

Whether Normal is too easy is **level / difficulty pressure** (incoming HP, speed, spawn, economy).

If Sentry and Guard are close economically, do **not** nerf both because Normal feels easy. Change waves or difficulty components instead.

## Path exposure

[`PathCoverageCalculator`](../scripts/level/path_coverage_calculator.gd) still returns covered segment indices for UI.

Lengths now come from [`PathExposureCalculator`](../scripts/level/path_exposure_calculator.gd):

- **SPHERE_3D:** exact line-segment ∩ sphere.
- **FLOOR_DISC:** exact XZ circle ∩ segment, matching `floor_id` only.

```text
enemy_exposure_seconds = covered_path_length / enemy_speed
```

Coverage windows, entry, and exit are path-distance intervals. A segment that only clips the range contributes its **chord**, not its full length.

## Archetype valuation

One dispatcher: [`combat_value_model.gd`](../scripts/balance/combat_value_model.gd). Agents, telemetry, and reports call the same formulas.

- **Sentry:** `damage / fire_interval`, scaled by exposure / uptime potential. Projectile travel is not fudged — this is an upper bound.
- **Guard:** melee DPS × `unit_count` plus **potential** extra exposure from blocking. Realized synergy is measured with counterfactuals, not guessed here.
- **Meltdown:** lava_damage, pour_rate, lifetime, flow, mass scales, occupancy. **Never** `base_damage / base_fire_interval`.

## Build timing and placement sensitivity

Isolated runs place **one** tower at a spot, then play the remaining waves (leaks allowed).

Timing matrix: before waves 1–5.

```text
early_build_multiplier = value_if_built_wave_1 / median_build_value
```

Across spots, for isolated `value_per_gold` (catalog cost, not live HODL quotes):

```text
placement_sensitivity = stdev / max(mean, ε)   # coefficient of variation
```

Bands (LOW / MEDIUM / MEDIUM/HIGH / HIGH) are design labels in [`balance_targets.gd`](../scripts/balance/balance_targets.gd), not auto-warnings to nerf.

Sentry may be placement-robust. Guard is choke-dependent. Meltdown may be highly sensitive. That can be intended.

## Counterfactuals, synergy, Shapley

**Counterfactual:** replay the same seed and action log with one PLACE (and its UPGRADE) removed. No agent re-decides.

**Synergy:** leave-one-out. Extra damage other towers deal when T is present is `indirect_damage_enabled`. This is **not** additive and can double-count shared value.

**Shapley (optional):** exact `2^N` subset replays for **N ≤ 5**. Sum of Shapley values equals the grand coalition minus the empty coalition (float tolerance). Larger N is skipped.

Outcome scores: enemy HP removed, core HP preserved, leaks prevented.

## Difficulty pressure

Presets still expose a single `multiplier` (Easy 0.80 … Brutal 1.50) applied to HP, speed, and melee as before. Internally each preset also has:

`health_multiplier`, `speed_multiplier`, `damage_multiplier`, `spawn_rate_multiplier`, `enemy_count_multiplier`

Spawn and count stay 1.0 on stock presets.

HP × speed is **super-linear** for ranged defense: Hard 1.25 × 1.25 ≈ 1.56 effective ranged pressure, not +25%.

Level report: incoming HP, counts, spawn density, path travel time, minimum sustained DPS, kill economy vs starting Buying Power.

## CLI

```text
godot --headless --path . --script res://scripts/tools/analyze_balance.gd
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --quick --difficulty normal
godot --headless --path . --script res://scripts/tools/validate_balance.gd
```

JSON: `res://balance_reports/latest_balance_report.json`.

v0.18.1 also writes `latest_balance_report.html` and `latest_balance_ai_export.json`. Designer HTML, AI export, full-build, defense margin, and difficulty frontier: [balance-lab.md](balance-lab.md).

Warnings are **diagnosis** (below-anchor, outlier spot, high defense margin). They do not recommend “change damage from X to Y”. Parameter search can consume these metrics later; v0.18 does not ship a multi-objective optimizer.

`validate_replay` seek30 / seek-chain is a known failure. Do not treat a green Balance Lab report as a replay-seek fix.

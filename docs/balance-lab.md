# Balance Lab Reports (v0.19.0)

Designer-facing reports on top of the Deterministic Balancing Lab. Balance Lab 2.0 keeps analysis on the same gameplay graph as PLAY and adds selectable analysis suites, agent-generated full builds, realized counterfactual/Shapley value, simulation fidelity, and Meltdown parameter search.

Analysis does **not** change combat values by default. The only write path is the explicit `--apply-recommended` option for a Meltdown search result.

See also [deterministic-balancing-lab.md](deterministic-balancing-lab.md) and [simulation-and-balancing.md](simulation-and-balancing.md).

## Artifacts

Written under `balance_reports/`:

| File | Role |
|---|---|
| `latest_balance_report.json` | Full canonical schema `0.19.0` |
| `latest_balance_ai_export.json` | Compact `hodl_balance_ai_export` v1 |
| `latest_balance_report.html` | Offline designer HTML |

`--archive` copies a timestamped trio into `balance_reports/history/`. Latest files are overwritten. The previous latest JSON is read before overwrite for comparison.

The committed `latest_balance_report.json` is a sample artifact, not release certification. In particular, an isolated report does not prove full-build, counterfactual, Shapley, defense-margin, frontier, or fidelity coverage.

## Suite model

`--suite` is the canonical v0.19 selector:

| Suite | What it measures |
|---|---|
| `isolated` | Tower × spot matrix, build timing, Meltdown ramp |
| `full-build` | Records COMPETENT and OPTIMIZER agent builds, then freezes and replays them |
| `counterfactual` | Full-build recording plus leave-one-out realized value and synergy |
| `shapley` | Counterfactual path plus Shapley attribution |
| `meltdown-search` | Multi-objective Meltdown parameter search |
| `defense-margin` | Full-build plus binary-search pressure margin |
| `difficulty-frontier` | Full-build plus health × speed frontier |
| `fidelity` | Short 1× vs 40× same-log simulation fidelity probe |
| `all` | Isolated + full-build + counterfactual + Shapley + margin + frontier + fidelity + a quick Meltdown search |

The default suite is `isolated`.

## Performance profile: fast default vs deep optimizer

The simulation still advances the gameplay graph in fixed `1/60` gameplay steps and normally runs at `40×` wall-clock acceleration.

Balance Lab 2.0 deliberately keeps the default full-build search cheap:

- COMPETENT uses the beam-2 heuristic agent without clone lookahead.
- OPTIMIZER uses beam-4 scoring, but **clone lookahead is off by default** in `analyze_balance.gd`.
- `--optimizer-lookahead` enables the expensive clone-based future-state evaluation. Agent recording then uses a bounded two-candidate / two-second lookahead.
- `--suite all` forces the Meltdown parameter search into its quick mode even when `--quick` was not supplied.

This is the main reason a broad analysis can feel dramatically faster. The tradeoff is important: the default OPTIMIZER label means “best deterministic beam search under the current heuristic”, not “deep lookahead search”. Use `--optimizer-lookahead` when optimizer quality matters more than wall time.

## Counterfactual and Shapley

Counterfactual analysis freezes an action log and removes the PLACE/UPGRADE actions for one spot. Other decisions are intended to remain fixed; the agent does not re-decide.

Shapley is exact for builds with up to five placed spots. Larger builds use a deterministic seeded sampled Shapley approximation instead of being skipped.

Realized combat value combines measured direct damage, damage enabled for other towers, leak prevention, and Core HP preservation. It is intentionally different from isolated theoretical potential.

### Current replay caveat

Replay actions currently execute through the live `SimActions` path. Historical PLACE payloads contain the quote, but replayed placement calls the live build path again rather than locking the historic quote. A counterfactual that removes an earlier purchase can therefore change later Buying Power / market state; a later replayed action can fail even though it still exists in the frozen log.

The single-target counterfactual path exposes an `other_actions_unchanged` check. Build-wide counterfactual/Shapley currently does not reject a result when a later replay action failed. Treat suspicious marginal values as diagnostic until this invariant is hardened.

## Simulation fidelity

The `fidelity` suite records a short scripted run at `1×`, replays the same action log at `40×`, and compares spawn count, damage, kills, leaks, blocking, projectile hits, cross-floor hits, fire count, Core HP, economy, duration, and enemy path progress.

This tests **speed fidelity**, not persistence seek fidelity.

Run replay validation separately:

```text
godot --headless --path . --script res://scripts/tools/validate_replay.gd
```

`validate_replay.gd` covers load→end, seek0 placement replay, seek30→end, seek60→end, and seek60→20→end. The current JSON seek implementation restores the initial snapshot and fast-forwards; mid-combat JSON keyframe restore is deliberately not trusted yet.

### Known v0.19 reporting bug

`balance_analysis_runner.gd` currently stamps `replay_fidelity = PASS` after the speed-fidelity suite without invoking `validate_replay.gd` in that run. Therefore **do not use `replay_fidelity: PASS` in a Balance Lab report as proof that replay seek validation actually ran**. The standalone replay validator remains the source of evidence.

## Meltdown parameter search

`meltdown-search` evaluates candidate parameter sets against the Balance Lab targets and reports a recommended candidate. It is analysis-only unless `--apply-recommended` is explicitly supplied.

```text
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite meltdown-search
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite meltdown-search --apply-recommended
```

The second command is intentionally a write operation; normal analysis never writes tower catalog values.

## Nulls, status, confidence, comparison

Missing measurements are JSON `null` (or `"NOT_MEASURED"`), never sentinel gameplay values.

One status vocabulary is computed in `scripts/balance/report/balance_status.gd` and presentation layers must not reclassify it:

`WITHIN_TARGET` / `BELOW_TARGET` / `SEVERELY_BELOW_TARGET` / `ABOVE_TARGET` / `NOT_MEASURED`

Warnings carry severity in the canonical report. `confidence` describes which conclusions have enough measurement behind them.

`previous_delta` compares reports only when the relevant level/difficulty/seed/fingerprint context is compatible.

## CLI

Recommended v0.19 commands:

```text
# Fast isolated baseline
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite isolated

# Broad fast-default report
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite all --difficulty normal --seed 7

# Broad report with expensive optimizer lookahead
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite all --optimizer-lookahead --difficulty normal --seed 7

# Dedicated suites
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite fidelity
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite counterfactual
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite shapley
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite defense-margin
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite difficulty-frontier

# Parameter override stays analysis-local
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --suite isolated --set lava_tower.damage_full_mass=10
```

`--quick` reduces the isolated matrix and selected search work. `--no-html` / `--no-ai-export` skip those artifacts. `--archive` keeps timestamped copies. `--open-report` opens the generated HTML.

## Compatibility caveats in the v0.19 CLI

Prefer `--suite ...` over the old flag-combination syntax.

- `--full-build <value>` still parses a value, but the current v0.19 runner does not consume a supplied replay/JSON path; it records agent builds instead. This is a regression from v0.18.1 behavior.
- Old combinations such as `--full-build scripted --defense-margin` are not compositional under the single-suite selector and can run only the first selected suite. Use `--suite all` or run the dedicated suites separately.
- `--shapley` by itself is only a legacy boolean helper; use `--suite shapley` for a complete generated-build Shapley run.

## Report metadata caveats

Two v0.19 metadata fields currently overstate analysis depth:

- `report_meta.agent_configuration.optimizer` is written as `build_search_beam4_lookahead` even when `--optimizer-lookahead` was not enabled.
- `report_meta.search_configuration.quick` reflects the CLI `--quick` flag, while `--suite all` internally forces the Meltdown search into quick mode.

Until those fields are fixed, derive optimizer/search depth from the command used, not those labels alone.

## In-game debug page

Route `balance_lab`, visible with SIM LAB in the debug surface, invokes the same shared analysis runner and report writers. It should not reimplement balance calculations in UI code.

## Validation before trusting a release result

A useful local gate is:

```text
godot --headless --path . --script res://scripts/tools/validate_balance.gd
godot --headless --path . --script res://scripts/tools/validate_replay.gd
godot --headless --path . --script res://scripts/tools/validate_sim_fidelity.gd
```

A fast successful `analyze_balance.gd` run is evidence that the selected suite completed; it is not by itself proof that every validator above passed on the same commit.

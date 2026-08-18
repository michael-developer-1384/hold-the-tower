# Balance Lab Reports (v0.18.1)

Designer-facing reports on top of the Deterministic Balancing Lab. This release is **visibility and export only**. Combat numbers are not changed by the lab.

See also [deterministic-balancing-lab.md](deterministic-balancing-lab.md).

## Artifacts

Written under `balance_reports/`:

| File | Role |
|---|---|
| `latest_balance_report.json` | Full schema `0.18.1` |
| `latest_balance_ai_export.json` | Compact `hodl_balance_ai_export` v1 |
| `latest_balance_report.html` | Offline designer HTML |

`--archive` copies a timestamped trio into `balance_reports/history/`. Latest files are always overwritten. The previous latest JSON is read **before** overwrite for comparison.

## Nulls and status

Missing measurements are JSON `null` (or `"NOT_MEASURED"`), never `0` or `-1`.

Ramp times that were stored as `-1` in v0.18 become `null` with `t_25_reached: false` in the model.

One status vocabulary (computed once in `scripts/balance/report/balance_status.gd`):

`WITHIN_TARGET` / `BELOW_TARGET` / `SEVERELY_BELOW_TARGET` / `ABOVE_TARGET` / `NOT_MEASURED`

Warnings carry `INFO|NOTICE|WARNING|CRITICAL` in the JSON. HTML does not reclassify them.

## Confidence and comparison

`confidence` explains what the default isolated run can and cannot claim (Guard indirect value, Normal headroom, Shapley).

`previous_delta` is computed only when level, difficulty, seed, and `parameter_fingerprint` match. Otherwise: `"Previous report not directly comparable."`

## CLI overrides

`--set lava_tower.damage_full_mass=10` goes into `SimContext` config and `report_meta.parameter_overrides`. Catalogs are not written.

## Optional full-build / margin / frontier

Default analyze leaves `full_builds: []`, `defense_margin: null`, `difficulty_frontier: null`.

| Flag | Meaning |
|---|---|
| `--full-build scripted` or a JSON path | Replay a frozen `action_log` (fixture / player replay / agent). Roles exist in the data model (`BEGINNER`…`OPTIMIZER`, `PLAYER_REPLAY`). v0.18.1 ships a `scripted` fixture from `scripted_policy.gd`. |
| `--defense-margin` | Binary-search one SimContext axis at a time: `enemy_health`, `enemy_speed`, `spawn_rate`, `enemy_count`. |
| `--difficulty-frontier` | Health × speed grid (default 0.9–1.5 step 0.1). Cells: `WIN_CLEAN` / `WIN_WITH_LEAKS` / `LOSS`. |

Replay uses the existing `CounterfactualRunner.replay` path. No second combat engine.

## Meltdown series

When `SimContext` override `balance_ramp_series` is true (isolated ramp probe only), lava samples every 0.25s: `time, total_mass, active_cells, damage_cells, peak_cell_dps, aggregate_field_dps`. Full JSON may include the array. **AI export omits it.**

## CLI

```text
godot --headless --path . --script res://scripts/tools/analyze_balance.gd
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --quick
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --archive --open-report
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --full-build scripted --defense-margin
godot --headless --path . --script res://scripts/tools/analyze_balance.gd -- --set lava_tower.damage_full_mass=10
```

`--no-html` / `--no-ai-export` skip those artifacts. `--open-report` calls `OS.shell_open` on the HTML file.

## In-game debug page

Route `balance_lab`, visible with SIM LAB (debug build or debug HUD). Buttons run the same pipeline, open the HTML, re-export AI JSON, and copy path + designer summary. The page does not reimplement the HTML report.

## Known replay issue (unchanged)

`validate_replay.gd` seek30 / seek-chain still fails. v0.18.1 does not patch that. Load→end remains the trusted replay path for frozen logs used here.

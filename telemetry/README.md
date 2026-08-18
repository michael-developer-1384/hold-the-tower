# Telemetry (v0.18 prototype)

Last-run gameplay and market telemetry for HODL THE TOWER prototyping.

## Files

- `last_run_events.jsonl` — one JSON object per line (events)
- `last_run_summary.json` — aggregate summary for the most recent run

## Paths

Files are written under `res://telemetry/` on purpose for the prototype so they stay next to the project and are easy to open in the editor.

**Change this before release** (e.g. `user://` or an external analytics sink). Overwriting last-run files is intentional; there is no history retention yet.

## Events

Includes: `run_started`, `floor_focused`, `wave_started`, `wave_completed`, `hodl_candle_closed`, `tower_built`, `tower_selected`, `tower_upgraded`, `enemy_killed`, `enemy_reached_core`, `game_over`, `level_completed`, `run_ended`.

Combat shot spam is intentionally omitted. Towers aggregate `shots_fired` / hits / damage / kills; those appear in the summary and on build/upgrade coverage snapshots. Coverage lengths use exact path exposure. Summaries may include `theoretical_damage`, `exact_exposure`, `target_uptime_fraction`, Guard block fields, and Meltdown field metrics (`emitted_mass`, ramp timestamps, active cells) when the lava system is present.

Deep isolated-benchmark / relative-anchor values are produced by the Balancing Lab (`analyze_balance.gd`), not by every PLAY run.

`hodl_candle_closed` is emitted once per Opening-Bell session (at the next bell or run resolution, never at spawn-complete). Its implemented payload is:

- `wave`
- `hodl_open`, `hodl_high`, `hodl_low`, `hodl_close`
- cumulative run-to-date `spawn_pressure_total`, `carry_pressure_total`, `advance_pressure_total`, `damage_recovery_total`, `kill_gain_total`, `buy_impact_total`, and `core_loss_total`

Open is the HODL price at Opening Bell. On rollover, close equals the next session's open. Price comes from deterministic weighted market flows; 10 Hz samples are not written as telemetry events. The canonical event-level history is the `market_tape` in the run snapshot/profile's retained recent ranked tapes, not the JSONL event stream.

`enemy_killed` includes `final_hit_damage` and `enemy_hp_before` (actual damage, not overkill).

## Final summary

`last_run_summary.json` includes `hodl_candles` plus run-level fields copied from the finalized `RunManager.last_run`:

- `hodl_open`, `hodl_high`, `hodl_low`, `hodl_close`
- `session_return`, `max_drawdown`, `market_attribution`
- `risk_notional_cents`, fixed `leverage`
- `portfolio_pnl_cents`, `portfolio_before_cents`, `portfolio_after_cents`
- `previous_ath`, `new_ath`, `ath_thresholds_crossed`
- `ath_rp_earned`, `ath_xp_earned`

Settlement happens before `TelemetryManager.end_run`, so ranked results contain committed values. Assisted Time Machine resumes are non-ranked and contain zero P/L/rewards. SIM never commits profile, global market, or active-session state; any explicitly recorded SIM telemetry/replay file is a diagnostic artifact only.

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

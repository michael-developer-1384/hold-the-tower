# Domain model (v0.16.3)

Player-facing labels, units and precision for stats and catalog IDs are formatted by `StatPresentation` (see `docs/ui_architecture.md`). Domain math below is unchanged.

## Towers

`TowerDefinition` holds identity, copy, cost, `runtime_scene`, `visual_scene`, `feature_ids`, combat bases, research keys, and statistics metric keys.

| ID | Display | Role |
|---|---|---|
| `basic_tower` | Sentry | Ranged, paper-hands retarget |
| `guard_post` | Guard Post | Melee blockers, diamond-hands engages |
| `lava_tower` | Meltdown | Area DCA liquidation, contagion to lower floors |

Resolve path:

`TowerDefinition + research allocations (+ player level per-stat cap + tower capacity) → ResearchResolver → BlueprintResolver → configure_built`

## Enemies

`EnemyDefinition` + `EnemyCatalog`. Prototype enemy id: `bot`.

## Features

`GameplayFeatureDefinition` / `FeatureCatalog`. UI resolves chips by id.

## Research vs capacity vs blueprints

- **Allocations**: integer RP invested per stat (source of truth).
- **Per-stat level cap**: fraction of `max_investment_rp` by player level (V2: 15%→100%).
- **Tower capacity**: total RP budget for one tower’s active research (Sentry/Guard tables by level). Apply rejects over-capacity; no auto-redistribute.
- **Resolved params**: `progress^0.70` lerp base→best. Meltdown `lava_lifetime` is finite (base 8s → best 24s); higher is better. Engine sentinel `0` still means no decay, but research never starts there.
- **Player Level / XP**: slower V2 curve; gameplay grants RP+XP; refunds never grant XP.
- **Blueprints**: optional named allocation saves; active on exact match.
- **In-run upgrades**: Sentry L2 range `+1.5` after research stats.

## Session + Time Machine

- **SessionStore** (`user://session.json`): wave-/pause-safe continue of gold, core HP, wave, towers, optional living enemies.
- **TimelineRecorder**: 5 Hz ring buffer of session-compatible snapshots; dump `user://timeline_last_run.json`. In-match V2 supports preview scrub + Resume Here / Return to Live; post-game scrubber remains inspect-only.

## Shared visuals / waves

Visual PackedScenes under `scenes/**/visuals/`. `WaveCatalog` bot waves `10/12/14/16/20`.

### Wave phase + early call

- Each started wave opens a **phase clock**: theoretical unblocked duration `D` (spawn stagger + path length / move speed) plus a **5s pause**.
- **Call bonus** starts at **30** gold when the wave starts and decays linearly to **0** at `t = D + 5`.
- **NEXT WAVE** can be pressed anytime (overlap allowed). Manual call awards `floor(remaining bonus)`. Auto-start at end of pause awards **0**.
- Wave 1 is still a manual first press (no prior bonus). Index advances on start; level clears when all waves are started, the spawn queue is empty, and no enemies remain.
- SIM exposes `call_bonus` / `phase_remaining` / `can_start_wave`; player profiles carry `early_call_skill` (optimizer 1.0 → beginner 0.0).

## HODL Index

THE FIGHT WRITES THE CHART. HODL Index is a **continuous combat-derived market price**, not a 0–100 health score. Pressure and price are separate mechanisms:

- **Defensive Pressure** (`hodl_index_model.evaluate`): state indicator only (debug, later RSI-like tools, telemetry). Health fraction × proximity `lerp(0.35, 1.35, path progress)`, divided by `max(expected_wave_count, 12)`, scaled by 30. Guard weight **0.0**. Core HP is **not** baked into pressure. Pressure deltas do **not** move price.
- **Price** (`hodl_market_session.gd`): starts at 100, floor 0, no upper cap. Each 10 Hz tick applies explicit combat flows: `price += damage_recovery + kill_gain - spawn_pressure - advance_pressure - core_hp_delta * 4`. Idle combat ⇒ price is exactly unchanged. Spawn pressure is `2.0 / expected_wave_count` once per enemy. Advancement is `forward_progress × hp_fraction × (0.4 + 1.6 progress²) × 5` and is never bullish. Damage recovery is lost HP fraction × 0.4. Kill gain is `1.0 / expected_wave_count`. Enemy removal by itself has no economic meaning.
- One OHLC candle per **Opening-Bell session**: Bell N opens at **current price** and stays live through spawn, MARKET OPEN, spawn-complete, PRE-MARKET cleanup, leftover overlap, kills, and leaks. Bell N+1 flushes pending market state, closes candle N at that price, and opens candle N+1 at the **same** price (`next.open == previous.close`). Spawn-complete does **not** close a candle. PRE-MARKET is an extended-hours presentation on the live candle; remaining combat still trades. Empty PRE-MARKET is flat. The final candle closes when the run resolves (level complete or game over). Historical candles stay immutable.
- Session / timeline / SIM snapshots store `hodl_market` (price, pending flow buffers, previous core HP, book). Restore rebuilds per-enemy HP/progress baselines from live enemies and does not recompute price, re-charge spawn, or replay past damage/kills.
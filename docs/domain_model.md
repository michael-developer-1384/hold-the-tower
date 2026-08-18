# Domain model (v0.18.1)

Player-facing labels, units and precision for stats and catalog IDs are formatted by `StatPresentation` (see `docs/ui_architecture.md`). Exact market formulas and persistence contracts are documented in [market_system.md](market_system.md).

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

- **SessionStore v2** (`user://session.json`): wave-/pause-safe continue of Buying Power, Core HP, wave, towers, optional living enemies, `RunEconomy`, and complete market state.
- **TimelineRecorder**: 5 Hz ring buffer of session-compatible snapshots; dump `user://timeline_last_run.json`. In-match V2 supports preview scrub + Resume Here / Return to Live; post-game scrubber remains inspect-only.
- **Assisted contract**: Resume Here marks the run assisted. It may finish and appear in run history, but it is non-ranked: no portfolio P/L, global market commit, or ATH RP/XP.
- **SIM contract**: SIM runs share gameplay and market logic but never save `session.json` or settle into `profile.json`.

## Shared visuals / waves

Visual PackedScenes under `scenes/**/visuals/`. `WaveCatalog` bot waves `10/12/14/16/20`.

### Wave phase + early call

- Each started wave opens a **phase clock**: theoretical unblocked duration `D` (spawn stagger + path length / move speed) plus a **5s pause**.
- **Call bonus** starts at **30** gold when the wave starts and decays linearly to **0** at `t = D + 5`.
- **NEXT WAVE** can be pressed anytime (overlap allowed). Manual call awards `floor(remaining bonus)`. Auto-start at end of pause awards **0**.
- Wave 1 is still a manual first press (no prior bonus). Index advances on start; level clears when all waves are started, the spawn queue is empty, and no enemies remain.
- SIM exposes `call_bonus` / `phase_remaining` / `can_start_wave`; player profiles carry `early_call_skill` (optimizer 1.0 → beginner 0.0).

## THE MARKET

THE FIGHT WRITES THE CHART. HODL is a continuous combat-derived market price, not a 0–100 health score.

### Canonical run model

`MarketSession` connects gameplay to `MarketEngine`. `MarketEngine` appends normalized component events to the canonical `MarketTape`; `CandleAggregator` and `MarketStatistics` derive views from that tape.

For enemy weight share `w`, HP fraction `h`, progress `p`, and `danger(p) = 0.4 + 1.6p²`:

```text
spawn   = -2.0w
carry   = -dt × h × danger(p) × w × 0.15
advance = -forward_progress × h × danger(p) × w × 5.0
damage  = +lost_hp_fraction × w × 4.0
kill    = +w
buy     = +0.90 × executed_price / 300
core    = -4.0 × core_hp_lost
```

`w = enemy_weight / expected_total_wave_weight`; expected weight is the configured sum of `count × group weight`. Price samples at 10 Hz, is floored at `0.01`, has no upper cap, and remains exactly flat when no component changes. Forward progress cannot become a bullish reversal. Enemy disappearance has no economic meaning; leaks are represented by Core HP loss.

### Buying Power and quotes

`RunEconomy` owns integer Buying Power and quote-locked transactions. Tower and upgrade quotes are:

```text
max(1, round(base_price × clamp(current_hodl / run_open_hodl, 0.25, 4.0)))
```

A purchase executes at the locked quote; successful commit then writes its bullish buy impact. Tower-instantiation failure rolls back the debit.

### Candles

- In-run: fixed `5s`, `15s` (default), `1m`, and Opening-Bell `WAVE`.
- Global profile: wall-time `1m`, `1h`, `1D`, plus one `RUN` candle per ranked settlement.
- Spawn-complete does not close a wave candle. The candle closes when combat ends (PRE-MARKET / EXT between waves). The next Opening Bell opens the next candle at the current price. Final resolution closes the last candle if it is still live.

### Portfolio and progression

`PortfolioAccount` stores integer cents: $4,000 initial balance, lifetime P/L, account ATH, and runs settled. Settlement uses fixed `1.0×` leverage and difficulty risk notionals:

```text
easy $250 | normal $500 | hard $1,000 | brutal $1,500
P/L = round(risk_notional_cents × (hodl_close / hodl_open - 1))
```

Leverage is not selectable. A ranked close becomes the next global open. Global ATH uses the run high; each newly crossed multiplicative 1% threshold from the reward anchor grants `1 RP + 1 XP`. Profile settlement stages replacement portfolio/market/run values and commits once; `settled_run_ids` prevents duplicate P/L, rewards, or history.

Profile schema is v13 and active-session schema is v2. See [market_system.md](market_system.md) for event fields, caps, persistence, and formulas.
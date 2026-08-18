# Market system (v0.17.0)

THE MARKET turns deterministic run events into a continuous global HODL price. `MarketTape` is the canonical event ledger; candles, statistics, tower quotes, settlement, and profile history are derived from it.

## Runtime ownership

- `MarketConfig`: constants and difficulty risk notionals.
- `MarketEngine`: deterministic spawn, carry, advance, damage, kill, buy, and Core flows.
- `MarketTape`: ordered immutable event entries and current/high/low queries.
- `MarketSession`: gameplay adapter, 10 Hz sampling, phase, run-relative quotes, wave boundaries, capture/restore, and chart feeds.
- `MarketPricing`: quote ratio and post-execution buy impact.
- `CandleAggregator`: fixed-time and wave OHLC derivation.
- `MarketStatistics`: run OHLC, return, maximum drawdown, and attribution totals.
- `RunEconomy`: integer Buying Power ledger and quote-locked purchase transactions.
- `PortfolioAccount` / `PortfolioSettlement`: integer-cent account state and end-of-run settlement.

## Price and event ledger

A new profile starts at HODL `100.0`; every run opens at the last committed global close. Price has no upper cap and is floored at `0.01`:

```text
price_after = max(0.01, price_before + sum(components))
```

Each tape entry stores `run_time_ms`, `wall_time_ms`, `event_type`, `price_before`, `delta`, `price_after`, normalized components (`spawn`, `carry`, `advance`, `damage`, `kill`, `buy`, `core`), and metadata. Idle flushes create no event. Opening-bell, market-close, and other markers may be flat entries.

Sampling runs every `0.10s`. For enemy `i`:

```text
w_i = max(weight_i, 0.001) / max(expected_total_wave_weight, max(weight_i, 0.001))
h_i = clamp(health_i / max_health_i, 0, 1)
p_i = clamp(path_progress_i, 0, 1)
danger(p) = 0.4 + 1.6p²
```

The expected wave weight is the sum of `count × group weight`, with a minimum of `1.0`. Therefore heterogeneous waves remain deterministic and are normalized by configured weight, not enemy count.

### Flow formulas

All values below are HODL-price deltas:

```text
spawn_i  = -2.0 × w_i                         (once at registration)
carry_i  = -dt × h_i × danger(p_i) × w_i × 0.15
advance_i= -max(p_i - p_i_prev, 0) × h_i × danger(p_i) × w_i × 5.0
damage_i =  max(h_i_prev - h_i, 0) × w_i × 4.0
kill_i   = +w_i × 1.0                         (once after final damage reconciliation)
core     = -core_hp_lost × 4.0                (charged from Core HP delta)
buy      = +0.90 × executed_price / 300.0     (after purchase execution)
```

Forward progress is bearish; backward movement is not bullish. Damage and kills are bullish. A leak's disappearance has no price effect by itself—the Core HP delta is charged separately. Enemy baselines and pending components are captured so restore does not replay spawn, damage, kill, or Core effects.

## Dynamic Buying Power quotes

Tower and upgrade prices are relative to the current run open, not the absolute global HODL price:

```text
ratio = clamp(current_hodl / run_open_hodl, 0.25, 4.0)
executed_price = max(1, round(base_price × ratio))
```

The quote is locked and Buying Power is debited before instantiation. A failed tower instantiation rolls the transaction back. A successful build/upgrade commits the transaction and then applies buy market impact, so the purchase executes at the pre-impact quote and only the next quote sees that impact. Transaction IDs are deterministic within a run (`BUY-000001`, ...).

Buying Power remains an integer in-run resource; the default starting amount is `300`. This is separate from the persistent portfolio, which is stored in cents.

## Candles and statistics

In-run chart choices are fixed and complete:

- `5s` (`5,000ms`)
- `15s` (`15,000ms`, default)
- `1m` (`60,000ms`)
- `WAVE` (Opening Bell until combat ends)

Fixed-time buckets use run-relative milliseconds. Spawn-complete does not close a wave candle; leftover combat keeps MARKET OPEN. The candle closes when the board is clear (PRE-MARKET). EXT is the interstitial column after that close, not a shade over the live candle. The next Opening Bell opens the next wave at the then-current price.

The global Market page shows **account equity**, not HODL candles. Equity only changes when a ranked run settles. The in-run HUD still uses tape-derived OHLC (`5s / 15s / 1m / WAVE`).

Global tape history remains stored for persistence and diagnostics:

- `1m` (`60,000ms`, cap `10,080`)
- `1h` (`3,600,000ms`, cap `8,760`)
- `1D` (`86,400,000ms`, cap `3,650`)
- `RUN` (one OHLC record per ranked settled run, cap `1,000`)

Global fixed-time buckets use wall time and merge adjacent committed run candles that share a bucket. The profile retains the 10 most recent ranked run tapes. Run statistics include OHLC, `close / open - 1`, peak-to-trough maximum drawdown, and component attribution.

Those buckets are not the Market page chart. The page plots starting capital plus each settled `portfolio_after_cents` as a dollar equity curve, with session P/L coloring. Assisted runs do not move equity.

## Portfolio and settlement

Portfolio money is integer cents. A new account starts at `400000` cents ($4,000.00) and tracks balance, lifetime P/L, account ATH, and settled-run count.

Risk notional is fixed by difficulty:

| Difficulty | Notional |
|---|---:|
| Easy | $250.00 (`25000` cents) |
| Normal | $500.00 (`50000` cents) |
| Hard | $1,000.00 (`100000` cents) |
| Brutal | $1,500.00 (`150000` cents) |

Leverage is fixed at `1.0`; there is no selectable leverage.

```text
session_return = hodl_close / hodl_open - 1
portfolio_pnl_cents = round(risk_notional_cents × session_return × 1.0)
account_after_cents = account_before_cents + portfolio_pnl_cents
```

Settlement is staged: calculate the financial result, derive portfolio and global-market replacements, then commit them together to profile state and save. `settled_run_ids` makes the profile commit idempotent; settling an existing `run_id` returns its recorded result instead of applying P/L, history, or rewards again.

## Global HODL, ATH, and research

A ranked run's close becomes the next global HODL/open. The global ATH is the maximum of the previous ATH and run high. Research milestones are multiplicative 1% steps from `ath_reward_anchor`:

```text
next_threshold = anchor × 1.01
```

Every newly crossed threshold grants exactly `1 RP` and `1 XP`; multiple thresholds can be crossed in one run. The anchor advances once per crossed step. Profile v13 migration anchors rewards at the migrated ATH, so historical highs do not grant retroactive research.

## Persistence, Time Machine, and SIM

- Profile schema is v13 (`user://profile.json`); active-session schema is v2 (`user://session.json`).
- Session capture includes the market engine/tape, pending flow state, wave boundaries, selected timeframe, phase, and economy transaction cursor.
- Resuming from a Time Machine snapshot marks the run assisted. Assisted runs are non-ranked: settlement records zero portfolio P/L and zero ATH RP/XP and does not commit global market history.
- SIM uses the same gameplay and market contracts but never writes session checkpoints or profile settlement. Optional simulation recording/telemetry artifacts are diagnostic output, not progression or market persistence.


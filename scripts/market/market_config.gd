class_name MarketConfig
extends RefCounted

## One source of truth for v0.17 market and progression tuning.

const INITIAL_HODL_PRICE := 100.0
const MIN_HODL_PRICE := 0.01
const SAMPLE_INTERVAL_SECONDS := 0.10

const TARGET_FULL_WAVE_SPAWN_LOSS := 2.0
const TARGET_FULL_WAVE_DAMAGE_RECOVERY := 4.0
const TARGET_FULL_WAVE_KILL_GAIN := 1.0
const CARRY_FACTOR := 0.15
const ADVANCE_FACTOR := 5.0
const CORE_DAMAGE_PRICE_FACTOR := 4.0
const BUY_MARKET_IMPACT_FACTOR := 0.90
const REFERENCE_BUYING_POWER := 300.0
const STARTING_BUYING_POWER := 300

const DANGER_BASE := 0.4
const DANGER_QUADRATIC := 1.6

const MIN_TOWER_PRICE_MULTIPLIER := 0.25
const MAX_TOWER_PRICE_MULTIPLIER := 4.0

const IN_RUN_TIMEFRAMES_MS := {
	"5s": 5000,
	"15s": 15000,
	"1m": 60000,
}
const DEFAULT_IN_RUN_TIMEFRAME := "15s"
const GLOBAL_TIMEFRAMES_MS := {
	"1m": 60000,
	"1h": 3600000,
	"1D": 86400000,
}

const INITIAL_ACCOUNT_BALANCE_CENTS := 400000
const DEFAULT_LEVERAGE := 1.0
const RISK_NOTIONAL_CENTS := {
	"easy": 25000,
	"normal": 50000,
	"hard": 100000,
	"brutal": 150000,
}

const ATH_REWARD_STEP := 0.01
const ATH_RP_PER_STEP := 1
const ATH_XP_PER_STEP := 1

const RECENT_RUN_TAPE_CAP := 10
const CANDLES_1M_CAP := 10080
const CANDLES_1H_CAP := 8760
const CANDLES_1D_CAP := 3650
const RUN_CANDLES_CAP := 1000


static func danger(progress: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	return DANGER_BASE + DANGER_QUADRATIC * p * p


static func risk_notional_cents(difficulty_id: String) -> int:
	return int(RISK_NOTIONAL_CENTS.get(difficulty_id, RISK_NOTIONAL_CENTS["normal"]))

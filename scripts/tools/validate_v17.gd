extends SceneTree

const EngineScript := preload("res://scripts/market/market_engine.gd")
const EventScript := preload("res://scripts/market/market_event.gd")
const PricingScript := preload("res://scripts/market/market_pricing.gd")
const AggregatorScript := preload("res://scripts/market/candle_aggregator.gd")
const PhaseScript := preload("res://scripts/market/market_phase.gd")
const SettlementScript := preload("res://scripts/economy/portfolio_settlement.gd")
const AccountScript := preload("res://scripts/economy/portfolio_account.gd")
const MarketConfigScript := preload("res://scripts/market/market_config.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_test_flows()
	_test_pricing_and_buy()
	_test_aggregation_and_phase()
	_test_settlement_and_ath()
	_test_restore()
	_test_sim_does_not_touch_player_account()
	if failures.is_empty():
		print("v0.17 market validate: OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_flows() -> void:
	var engine = EngineScript.new(100.0)
	_eq(engine.current_price, 100.0, "A idle price")
	_check(engine.flush(100, 1000).is_empty(), "A idle creates no tape event")

	var full := {"health": 100.0, "max_health": 100.0, "progress": 0.0, "weight": 1.0}
	engine.register_enemy("E1", full, 10.0)
	engine.flush(200, 1100)
	_check(engine.current_price < 100.0, "B spawn is bearish")
	var after_spawn: float = engine.current_price

	engine.sample_enemy("E1", full, 1.0)
	engine.flush(1200, 2100)
	_check(engine.current_price < after_spawn, "C stationary live enemy has bearish carry")
	var after_carry: float = engine.current_price

	var advanced := full.duplicate(true)
	advanced["progress"] = 0.8
	engine.sample_enemy("E1", advanced, 0.0)
	engine.flush(1300, 2200)
	_check(engine.current_price < after_carry, "D forward movement is bearish")
	var after_advance: float = engine.current_price

	var damaged := advanced.duplicate(true)
	damaged["health"] = 40.0
	engine.sample_enemy("E1", damaged, 0.0)
	engine.flush(1400, 2300)
	_check(engine.current_price > after_advance, "E damage is bullish")
	var before_kill: float = engine.current_price
	engine.kill_enemy("E1", damaged)
	engine.flush(1500, 2400)
	_check(engine.current_price > before_kill, "F kill reconciles final damage and gain")
	var after_kill: float = engine.current_price
	engine.kill_enemy("E1", damaged)
	engine.flush(1600, 2500)
	_eq(engine.current_price, after_kill, "F kill applies exactly once")

	var leak_engine = EngineScript.new(100.0)
	leak_engine.register_enemy("L1", full, 10.0)
	leak_engine.flush(100, 1000)
	leak_engine.remove_enemy_without_market_effect("L1")
	var before_core: float = leak_engine.current_price
	leak_engine.flush(200, 1100)
	_eq(leak_engine.current_price, before_core, "G disappearance has no fake recovery")
	leak_engine.apply_core_loss(1, 200, 1100)
	_check(leak_engine.current_price <= before_core - 3.99, "G core loss is strongly bearish")


func _test_pricing_and_buy() -> void:
	_eq(float(PricingScript.quote(100, 90.0, 100.0)), 90.0, "I dip quote")
	_eq(float(PricingScript.quote(100, 500.0, 500.0)), 100.0, "J global open preserves base quote")
	_eq(float(PricingScript.quote(100, 450.0, 500.0)), 90.0, "J relative global dip quote")

	var engine = EngineScript.new(100.0)
	var executed := PricingScript.quote(100, engine.current_price, engine.run_open_price)
	engine.apply_buy(executed, 100, 1000, {"tower_id": "basic_tower"})
	_eq(float(executed), 100.0, "H executed price equals pre-impact quote")
	_check(engine.current_price > 100.0, "H buy impact occurs after execution")
	_check(
		PricingScript.quote(100, engine.current_price, engine.run_open_price) > executed,
		"H next quote rises"
	)


func _test_aggregation_and_phase() -> void:
	var engine = EngineScript.new(100.0)
	for i in 12:
		var components := EventScript.empty_components()
		components["damage"] = 0.25 if i % 2 == 0 else 0.0
		components["spawn"] = -0.1 if i % 2 == 1 else 0.0
		engine.pending_components = components
		engine.flush(i * 5000, 1000 + i * 5000)
	var c5 := AggregatorScript.fixed_time(engine.tape, 5000, 60000)
	var c15 := AggregatorScript.fixed_time(engine.tape, 15000, 60000)
	var c60 := AggregatorScript.fixed_time(engine.tape, 60000, 60000)
	var o5 := AggregatorScript.aggregate_ohlc(c5)
	var o15 := AggregatorScript.aggregate_ohlc(c15)
	var o60 := AggregatorScript.aggregate_ohlc(c60)
	for key in ["open", "high", "low", "close"]:
		_eq(float(o5[key]), float(o15[key]), "K 5s/15s %s consistency" % key)
		_eq(float(o5[key]), float(o60[key]), "K 5s/1m %s consistency" % key)

	_check(
		PhaseScript.resolve(false, 1, false, true, 1) == PhaseScript.Phase.MARKET_OPEN,
		"L enemy alive keeps market open"
	)
	_check(
		PhaseScript.resolve(false, 1, false, true, 0) == PhaseScript.Phase.PRE_MARKET,
		"L last enemy starts pre-market"
	)
	var idle = EngineScript.new(100.0)
	idle.flush(20000, 20000)
	_eq(idle.current_price, 100.0, "M pre-market idle is exactly flat")
	idle.apply_buy(100, 20000, 20000, {})
	_check(idle.current_price > 100.0, "N pre-market purchase is a real move")

	var boundaries := [
		{"wave": 1, "start_ms": 0, "open": 100.0},
		{"wave": 2, "start_ms": 30000, "open": engine.tape.entries_between(0, 30001).back().price_after},
	]
	var waves := AggregatorScript.wave_candles(engine.tape, boundaries, 60000, engine.current_price)
	_eq(float(waves[0]["close"]), float(waves[1]["open"]), "O wave candle continuity")


func _test_settlement_and_ath() -> void:
	var plus := SettlementScript.calculate(100.0, 110.0, 50000, 1.0)
	_eq(float(plus["portfolio_pnl_cents"]), 5000.0, "P +10% of $500")
	var loss := SettlementScript.calculate(100.0, 90.0, 50000, 1.0)
	_eq(float(loss["portfolio_pnl_cents"]), -5000.0, "Q -10% of $500")
	var collapse := SettlementScript.calculate(0.01, 10.0, 50000, 1.0)
	_eq(float(collapse["session_return"]), 3.0, "P2 collapsed open/close return is 4x cap")
	_eq(float(collapse["portfolio_pnl_cents"]), 150000.0, "P2 collapsed P/L is +300% of $500")
	_eq(float(PricingScript.sanitize_persisted_price(0.01)), 100.0, "P2 reconstitutes pinned 0.01")
	_eq(float(PricingScript.sanitize_persisted_price(2.9)), 100.0, "P2 reconstitutes sub-floor HODL")
	_eq(float(PricingScript.sanitize_persisted_price(40.0)), 40.0, "P2 keeps a real 0.40x close")
	var reconstituted := EngineScript.new(0.01)
	_eq(reconstituted.run_open_price, 100.0, "P2 new run does not open at 0.01")

	var market := {
		"current_price": 100.0,
		"all_time_high": 100.0,
		"ath_reward_anchor": 100.0,
	}
	var result := SettlementScript.settle(
		AccountScript.default_state(),
		market,
		{"hodl_open": 100.0, "hodl_close": 102.1, "hodl_high": 102.1, "difficulty_id": "normal"}
	)
	_check(int(result.run.ath_thresholds_crossed) == 2, "R multiplicative ATH thresholds grant once each")
	var repeated := SettlementScript.settle(result.portfolio, result.market, {
		"hodl_open": 102.1,
		"hodl_close": 100.0,
		"hodl_high": 102.1,
		"difficulty_id": "normal",
	})
	_check(int(repeated.run.ath_thresholds_crossed) == 0, "R repeated threshold grants nothing")
	_eq(float(result.market.current_price), 102.1, "S committed close is next global open")
	var collapsed_settle := SettlementScript.settle(
		AccountScript.default_state(),
		{"current_price": 0.01, "all_time_high": 9.82, "ath_reward_anchor": 9.82},
		{"hodl_open": 0.01, "hodl_close": 9.82, "hodl_high": 9.82, "difficulty_id": "normal"}
	)
	_eq(float(collapsed_settle.market.current_price), 100.0, "S2 persist reconstitutes pinned HODL")
	_eq(float(collapsed_settle.run.portfolio_pnl_cents), 150000.0, "S2 collapsed settle P/L is +300% of $500")

	var curve: Array = AccountScript.equity_curve([
		{"portfolio_before_cents": 405000, "portfolio_after_cents": 395000, "portfolio_pnl_cents": -10000},
		{"portfolio_before_cents": 400000, "portfolio_after_cents": 405000, "portfolio_pnl_cents": 5000},
	], 395000)
	_eq(float(curve.size()), 3.0, "equity curve includes opening capital")
	_eq(float(curve[0]["equity_cents"]), 400000.0, "equity open")
	_eq(float(curve[1]["equity_cents"]), 405000.0, "equity after gain")
	_eq(float(curve[2]["equity_cents"]), 395000.0, "equity after loss")


func _test_restore() -> void:
	var engine = EngineScript.new(113.0)
	engine.apply_buy(100, 100, 1000, {"runtime_id": "T0001"})
	engine.register_enemy("E1", {"health": 50.0, "max_health": 100.0, "progress": 0.4}, 10.0)
	var captured: Dictionary = engine.capture()
	var restored = EngineScript.new()
	restored.restore(captured)
	_eq(restored.current_price, engine.current_price, "T restore price")
	_eq(restored.run_open_price, 113.0, "T restore run open")
	_check(restored.tape.entries == engine.tape.entries, "T restore tape")
	_check(restored.enemy_baselines == engine.enemy_baselines, "T restore enemy baselines")


func _test_sim_does_not_touch_player_account() -> void:
	var pm = root.get_node_or_null("ProfileManager")
	if pm == null:
		failures.append("U ProfileManager autoload missing")
		return
	var SimContextScript := load("res://scripts/sim/sim_context.gd")
	var cents := int(pm.call("get_account_balance_cents"))
	SimContextScript.begin(1, {})
	pm.call("settle_run", {
		"run_id": "sim_isolation_v17",
		"hodl_open": 100.0,
		"hodl_close": 400.0,
		"hodl_high": 400.0,
		"difficulty_id": "normal",
	})
	_eq(float(pm.call("get_account_balance_cents")), float(cents), "U sim settle leaves player cash")
	SimContextScript.end()


func _eq(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: expected %.8f, got %.8f" % [label, expected, actual])


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

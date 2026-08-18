class_name MarketEngine
extends RefCounted

const MarketConfig := preload("res://scripts/market/market_config.gd")
const MarketEvent := preload("res://scripts/market/market_event.gd")
const MarketTapeScript := preload("res://scripts/market/market_tape.gd")
const MarketPricing := preload("res://scripts/market/market_pricing.gd")

signal price_changed(price: float, entry: Dictionary)

var tape: RefCounted
var current_price: float
var run_open_price: float
var enemy_baselines: Dictionary = {}
var pending_components: Dictionary = MarketEvent.empty_components()
var attribution_totals: Dictionary = MarketEvent.empty_components()
var last_components: Dictionary = MarketEvent.empty_components()


func _init(open_price: float = MarketConfig.INITIAL_HODL_PRICE) -> void:
	run_open_price = MarketPricing.sanitize_persisted_price(maxf(open_price, MarketConfig.MIN_HODL_PRICE))
	current_price = run_open_price
	tape = MarketTapeScript.new(run_open_price)


func register_enemy(
	enemy_id: String,
	facts: Dictionary,
	expected_total_wave_weight: float
) -> void:
	var baseline := _normalize_facts(facts, expected_total_wave_weight)
	enemy_baselines[enemy_id] = baseline
	pending_components["spawn"] = (
		float(pending_components["spawn"])
		- MarketConfig.TARGET_FULL_WAVE_SPAWN_LOSS * float(baseline["wave_weight"])
	)


func restore_enemy_baseline(
	enemy_id: String,
	facts: Dictionary,
	expected_total_wave_weight: float
) -> void:
	enemy_baselines[enemy_id] = _normalize_facts(facts, expected_total_wave_weight)


func sample_enemy(enemy_id: String, facts: Dictionary, dt: float) -> void:
	if not enemy_baselines.has(enemy_id):
		restore_enemy_baseline(enemy_id, facts, float(facts.get("weight", 1.0)))
		return
	var previous: Dictionary = enemy_baselines[enemy_id]
	var current := _normalize_facts(
		facts,
		float(previous.get("expected_total_wave_weight", 1.0))
	)
	var wave_weight := float(current.get("wave_weight", 0.0))
	var hp_fraction := float(current.get("hp_fraction", 0.0))
	var progress := float(current.get("progress", 0.0))
	var previous_hp := float(previous.get("hp_fraction", hp_fraction))
	var previous_progress := float(previous.get("progress", progress))

	var damage_fraction := maxf(previous_hp - hp_fraction, 0.0)
	var forward_progress := maxf(progress - previous_progress, 0.0)
	pending_components["damage"] = (
		float(pending_components["damage"])
		+ damage_fraction * wave_weight * MarketConfig.TARGET_FULL_WAVE_DAMAGE_RECOVERY
	)
	pending_components["advance"] = (
		float(pending_components["advance"])
		- forward_progress
		* hp_fraction
		* MarketConfig.danger(progress)
		* wave_weight
		* MarketConfig.ADVANCE_FACTOR
	)
	pending_components["carry"] = (
		float(pending_components["carry"])
		- maxf(dt, 0.0)
		* hp_fraction
		* MarketConfig.danger(progress)
		* wave_weight
		* MarketConfig.CARRY_FACTOR
	)
	enemy_baselines[enemy_id] = current


func kill_enemy(enemy_id: String, final_facts: Dictionary = {}) -> void:
	if not enemy_baselines.has(enemy_id):
		return
	var previous: Dictionary = enemy_baselines[enemy_id]
	var facts := final_facts.duplicate(true)
	if facts.is_empty():
		facts = previous.duplicate(true)
	facts["health"] = 0.0
	facts["hp_fraction"] = 0.0
	sample_enemy(enemy_id, facts, 0.0)
	pending_components["kill"] = (
		float(pending_components["kill"])
		+ float(previous.get("wave_weight", 0.0))
		* MarketConfig.TARGET_FULL_WAVE_KILL_GAIN
	)
	enemy_baselines.erase(enemy_id)


func remove_enemy_without_market_effect(enemy_id: String) -> void:
	enemy_baselines.erase(enemy_id)


func apply_core_loss(
	core_hp_lost: int,
	run_time_ms: int,
	wall_time_ms: int,
	metadata: Dictionary = {}
) -> Dictionary:
	if core_hp_lost <= 0:
		return {}
	flush(run_time_ms, wall_time_ms)
	var components := MarketEvent.empty_components()
	components["core"] = -float(core_hp_lost) * MarketConfig.CORE_DAMAGE_PRICE_FACTOR
	return _record("core_loss", components, run_time_ms, wall_time_ms, metadata)


func apply_buy(
	executed_price: int,
	run_time_ms: int,
	wall_time_ms: int,
	metadata: Dictionary
) -> Dictionary:
	flush(run_time_ms, wall_time_ms)
	var components := MarketEvent.empty_components()
	components["buy"] = MarketPricing.buy_market_impact(executed_price)
	var enriched := metadata.duplicate(true)
	enriched["executed_price"] = executed_price
	enriched["run_price_ratio"] = MarketPricing.price_ratio(current_price, run_open_price)
	enriched["market_impact"] = float(components["buy"])
	return _record("buy", components, run_time_ms, wall_time_ms, enriched)


func record_marker(
	event_type: String,
	run_time_ms: int,
	wall_time_ms: int,
	metadata: Dictionary = {}
) -> Dictionary:
	flush(run_time_ms, wall_time_ms)
	var entry := MarketEvent.make(
		run_time_ms,
		wall_time_ms,
		event_type,
		current_price,
		MarketEvent.empty_components(),
		metadata
	)
	tape.append(entry, true)
	return entry


func flush(run_time_ms: int, wall_time_ms: int) -> Dictionary:
	var components := pending_components.duplicate(true)
	pending_components = MarketEvent.empty_components()
	if is_zero_approx(MarketEvent.net_delta(components)):
		last_components = MarketEvent.empty_components()
		return {}
	return _record("market_tick", components, run_time_ms, wall_time_ms)


func _record(
	event_type: String,
	components: Dictionary,
	run_time_ms: int,
	wall_time_ms: int,
	metadata: Dictionary = {}
) -> Dictionary:
	var entry := MarketEvent.make(
		run_time_ms,
		wall_time_ms,
		event_type,
		current_price,
		components,
		metadata
	)
	entry = tape.append(entry, true)
	var floor_px := MarketPricing.in_run_floor(run_open_price)
	var after := maxf(floor_px, float(entry.get("price_after", current_price)))
	entry["price_after"] = after
	entry["delta"] = after - float(entry.get("price_before", current_price))
	current_price = after
	last_components = entry.get("components", {}).duplicate(true)
	for key in MarketEvent.COMPONENT_KEYS:
		attribution_totals[key] = (
			float(attribution_totals.get(key, 0.0))
			+ float(last_components.get(key, 0.0))
		)
	price_changed.emit(current_price, entry)
	return entry


func capture() -> Dictionary:
	return {
		"current_price": current_price,
		"run_open_price": run_open_price,
		"tape": tape.capture(),
		"enemy_baselines": enemy_baselines.duplicate(true),
		"pending_components": pending_components.duplicate(true),
		"attribution_totals": attribution_totals.duplicate(true),
		"last_components": last_components.duplicate(true),
	}


func restore(data: Dictionary) -> void:
	run_open_price = maxf(
		float(data.get("run_open_price", data.get("current_price", MarketConfig.INITIAL_HODL_PRICE))),
		MarketConfig.MIN_HODL_PRICE
	)
	tape = MarketTapeScript.new(run_open_price)
	tape.restore(data.get("tape", {"opening_price": run_open_price, "entries": []}))
	current_price = maxf(
		float(data.get("current_price", tape.current_price())),
		MarketPricing.in_run_floor(run_open_price)
	)
	enemy_baselines = data.get("enemy_baselines", {}).duplicate(true)
	pending_components = MarketEvent.normalize_components(data.get("pending_components", {}))
	attribution_totals = MarketEvent.normalize_components(data.get("attribution_totals", {}))
	last_components = MarketEvent.normalize_components(data.get("last_components", {}))


func _normalize_facts(facts: Dictionary, expected_total_wave_weight: float) -> Dictionary:
	var max_health := maxf(float(facts.get("max_health", 1.0)), 0.001)
	var health := clampf(float(facts.get("health", max_health)), 0.0, max_health)
	var hp_fraction := float(facts.get("hp_fraction", health / max_health))
	var weight := maxf(float(facts.get("weight", 1.0)), 0.001)
	var total_weight := maxf(expected_total_wave_weight, weight)
	return {
		"health": health,
		"max_health": max_health,
		"hp_fraction": clampf(hp_fraction, 0.0, 1.0),
		"progress": clampf(float(facts.get("progress", 0.0)), 0.0, 1.0),
		"weight": weight,
		"expected_total_wave_weight": total_weight,
		"wave_weight": weight / total_weight,
	}

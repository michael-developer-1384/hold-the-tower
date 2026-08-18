class_name MarketSession
extends Node

signal hodl_index_changed(value: float, snapshot: Dictionary)
signal price_changed(value: float, entry: Dictionary)
signal candle_started(wave: int, candle: Dictionary)
signal candle_updated(candle: Dictionary)
signal candle_closed(candle: Dictionary)
signal market_phase_changed(phase: int)

const WaveCatalogScript := preload("res://scripts/waves/wave_catalog.gd")
const HodlCandleBookScript := preload("res://scripts/market/hodl_candle_book.gd")
const MarketConfig := preload("res://scripts/market/market_config.gd")
const MarketEngineScript := preload("res://scripts/market/market_engine.gd")
const MarketEvent := preload("res://scripts/market/market_event.gd")
const MarketPhase := preload("res://scripts/market/market_phase.gd")
const MarketPricing := preload("res://scripts/market/market_pricing.gd")
const CandleAggregator := preload("res://scripts/market/candle_aggregator.gd")
const MarketStatistics := preload("res://scripts/market/market_statistics.gd")

var engine: RefCounted
var book = HodlCandleBookScript.new() # Compatibility view; MarketTape remains canonical.
var current_price: float = MarketConfig.INITIAL_HODL_PRICE
var current_index: float = MarketConfig.INITIAL_HODL_PRICE
var run_open_price: float = MarketConfig.INITIAL_HODL_PRICE
var last_snapshot: Dictionary = {}
var current_phase: int = MarketPhase.Phase.PRE_MARKET
var selected_timeframe: String = MarketConfig.DEFAULT_IN_RUN_TIMEFRAME

var _game: Node
var _wave_manager: Node
var _core: Node
var _telemetry: Node
var _enemies: Array = []
var _accum: float = 0.0
var _run_elapsed_ms: int = 0
var _previous_core_hp: int = 20
var _expected_total_wave_weight: float = 1.0
var _wave_boundaries: Array = []
var _restoring: bool = false


func _ready() -> void:
	if engine == null:
		_initialize_engine(_committed_open_price())


func setup(game: Node, wave_manager: Node, core: Node, telemetry: Node) -> void:
	_game = game
	_wave_manager = wave_manager
	_core = core
	_telemetry = telemetry
	if engine == null:
		_initialize_engine(_committed_open_price())
	_previous_core_hp = _core_hp()
	if _wave_manager != null and _wave_manager.has_signal("enemy_spawned"):
		if not _wave_manager.enemy_spawned.is_connected(_on_enemy_spawned):
			_wave_manager.enemy_spawned.connect(_on_enemy_spawned)
	_refresh_phase()
	_emit_state({})


func _initialize_engine(open_price: float) -> void:
	run_open_price = maxf(open_price, MarketConfig.MIN_HODL_PRICE)
	engine = MarketEngineScript.new(run_open_price)
	engine.price_changed.connect(_on_engine_price_changed)
	current_price = engine.current_price
	current_index = current_price


func rollover_to_wave(next_wave: int) -> void:
	if _restoring:
		return
	flush_pending()
	if book.has_live():
		var closed: Dictionary = book.close_candle(current_price)
		if not closed.is_empty():
			_close_last_boundary()
			_emit_candle_telemetry(closed)
			candle_closed.emit(closed)
	_expected_total_wave_weight = _wave_total_weight(next_wave)
	engine.record_marker(
		"opening_bell",
		_run_elapsed_ms,
		_wall_time_ms(),
		{"wave": next_wave}
	)
	var boundary := {
		"wave": next_wave,
		"start_ms": _run_elapsed_ms,
		"start_entry_index": engine.tape.entries.size(),
		"open": current_price,
	}
	_wave_boundaries.append(boundary)
	var opened: Dictionary = book.open_candle(next_wave, current_price)
	candle_started.emit(next_wave, opened)
	_refresh_phase()
	_emit_state({})


func begin_wave_candle(wave: int) -> void:
	rollover_to_wave(wave)


func close_run_candle() -> void:
	if _restoring:
		return
	flush_pending()
	if not book.has_live():
		return
	var closed: Dictionary = book.close_candle(current_price)
	if closed.is_empty():
		return
	_close_last_boundary()
	engine.record_marker("market_close", _run_elapsed_ms, _wall_time_ms())
	_emit_candle_telemetry(closed)
	candle_closed.emit(closed)
	set_phase(MarketPhase.Phase.CLOSED)
	_emit_state({})


func set_phase(phase: int) -> void:
	if current_phase == phase:
		return
	current_phase = phase
	market_phase_changed.emit(current_phase)


func refresh_phase() -> void:
	_refresh_phase()


func set_timeframe(timeframe: String) -> void:
	if timeframe != "WAVE" and not MarketConfig.IN_RUN_TIMEFRAMES_MS.has(timeframe):
		return
	selected_timeframe = timeframe
	var candles := visible_candles()
	if not candles.is_empty():
		candle_updated.emit(candles.back())


func quote_tower(definition: Resource) -> int:
	return MarketPricing.quote_tower(definition, current_price, run_open_price)


func quote_upgrade(definition: Resource) -> int:
	return MarketPricing.quote_upgrade(definition, current_price, run_open_price)


func apply_purchase(transaction: Dictionary) -> Dictionary:
	var executed_price := int(transaction.get("executed_price", 0))
	if executed_price <= 0:
		return {}
	var entry: Dictionary = engine.apply_buy(
		executed_price,
		_run_elapsed_ms,
		_wall_time_ms(),
		transaction
	)
	_sync_price()
	return entry


func flush_pending() -> Dictionary:
	if engine == null:
		return {}
	var dt := float(_accum)
	_accum = 0.0
	for enemy in _enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
			continue
		engine.sample_enemy(_enemy_key(enemy), _read_enemy_facts(enemy), dt)
	_prune_enemies()
	var entry: Dictionary = engine.flush(_run_elapsed_ms, _wall_time_ms())
	var core_now := _core_hp()
	var core_lost := maxi(_previous_core_hp - core_now, 0)
	if core_lost > 0:
		entry = engine.apply_core_loss(
			core_lost,
			_run_elapsed_ms,
			_wall_time_ms(),
			{"core_hp_before": _previous_core_hp, "core_hp_after": core_now}
		)
	_previous_core_hp = core_now
	_sync_price()
	return entry


func _physics_process(delta: float) -> void:
	if _restoring:
		return
	if _game != null and (
		bool(_game.get("timeline_previewing"))
		or bool(_game.get("game_over"))
		or bool(_game.get("level_complete"))
	):
		return
	_run_elapsed_ms += int(round(delta * 1000.0))
	_accum += delta
	if _accum + 0.0001 < MarketConfig.SAMPLE_INTERVAL_SECONDS:
		return
	flush_pending()
	_refresh_phase()
	_emit_state(engine.last_components)


func _on_enemy_spawned(enemy: Node3D) -> void:
	if _restoring or enemy == null or not is_instance_valid(enemy):
		return
	if _enemies.has(enemy):
		return
	_enemies.append(enemy)
	if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	if enemy.has_signal("reached_core") and not enemy.reached_core.is_connected(_on_enemy_leaked):
		enemy.reached_core.connect(_on_enemy_leaked)
	engine.register_enemy(_enemy_key(enemy), _read_enemy_facts(enemy), _expected_total_wave_weight)


func _on_enemy_died(enemy: Node3D) -> void:
	if _restoring:
		return
	engine.kill_enemy(_enemy_key(enemy), _read_enemy_facts(enemy))
	_untrack_enemy(enemy)


func _on_enemy_leaked(enemy: Node3D) -> void:
	if _restoring:
		return
	# Disappearance has no economic meaning. Core HP delta is charged separately.
	engine.remove_enemy_without_market_effect(_enemy_key(enemy))
	_untrack_enemy(enemy)


func _on_engine_price_changed(value: float, entry: Dictionary) -> void:
	current_price = value
	current_index = value
	if book.has_live():
		var candle: Dictionary = book.sample(value)
		candle_updated.emit(candle)
	price_changed.emit(value, entry)


func _sync_price() -> void:
	current_price = engine.current_price
	current_index = current_price


func _emit_state(components: Dictionary) -> void:
	var normalized := MarketEvent.normalize_components(components)
	var threat := _threat_indicator()
	last_snapshot = {
		"index": current_price,
		"current_price": current_price,
		"run_open_price": run_open_price,
		"price_ratio": MarketPricing.price_ratio(current_price, run_open_price),
		"threat_indicator": threat,
		"spawn_pressure": float(normalized["spawn"]),
		"carry_pressure": float(normalized["carry"]),
		"advance_pressure": float(normalized["advance"]),
		"damage_recovery": float(normalized["damage"]),
		"kill_gain": float(normalized["kill"]),
		"buy_impact": float(normalized["buy"]),
		"core_loss": float(normalized["core"]),
		"last_price_delta": MarketEvent.net_delta(normalized),
		"attribution_totals": engine.attribution_totals.duplicate(true),
		"market_phase": current_phase,
	}
	hodl_index_changed.emit(current_price, last_snapshot)


func visible_candles() -> Array:
	if engine == null:
		return []
	if selected_timeframe == "WAVE":
		return CandleAggregator.wave_candles(
			engine.tape,
			_wave_boundaries,
			_run_elapsed_ms,
			current_price
		)
	var interval := int(MarketConfig.IN_RUN_TIMEFRAMES_MS.get(
		selected_timeframe,
		MarketConfig.IN_RUN_TIMEFRAMES_MS[MarketConfig.DEFAULT_IN_RUN_TIMEFRAME]
	))
	return CandleAggregator.fixed_time(engine.tape, interval, _run_elapsed_ms)


func wave_candles() -> Array:
	return CandleAggregator.wave_candles(
		engine.tape,
		_wave_boundaries,
		_run_elapsed_ms,
		current_price
	)


func statistics() -> Dictionary:
	return MarketStatistics.from_tape(engine.tape) if engine != null else {}


func get_run_elapsed_ms() -> int:
	return _run_elapsed_ms


func capture() -> Dictionary:
	return {
		"schema_version": 2,
		"current_price": current_price,
		"current_index": current_price,
		"run_open_price": run_open_price,
		"run_elapsed_ms": _run_elapsed_ms,
		"previous_core_hp": _previous_core_hp,
		"expected_total_wave_weight": _expected_total_wave_weight,
		"selected_timeframe": selected_timeframe,
		"market_phase": current_phase,
		"wave_boundaries": _wave_boundaries.duplicate(true),
		"engine": engine.capture() if engine != null else {},
		"book": book.capture(),
		"last_snapshot": last_snapshot.duplicate(true),
	}


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	_restoring = true
	if engine == null:
		_initialize_engine(float(data.get("run_open_price", data.get("current_price", _committed_open_price()))))
	if data.has("engine"):
		engine.restore(data.get("engine", {}))
	else:
		var legacy_price := float(data.get("current_price", data.get("current_index", run_open_price)))
		engine = MarketEngineScript.new(float(data.get("run_open_price", legacy_price)))
		engine.current_price = legacy_price
		engine.tape.opening_price = float(data.get("run_open_price", legacy_price))
		engine.price_changed.connect(_on_engine_price_changed)
	run_open_price = engine.run_open_price
	_sync_price()
	_run_elapsed_ms = int(data.get("run_elapsed_ms", 0))
	_previous_core_hp = int(data.get("previous_core_hp", _core_hp()))
	_expected_total_wave_weight = float(data.get("expected_total_wave_weight", 1.0))
	selected_timeframe = str(data.get("selected_timeframe", MarketConfig.DEFAULT_IN_RUN_TIMEFRAME))
	current_phase = int(data.get("market_phase", MarketPhase.Phase.PRE_MARKET))
	_wave_boundaries = data.get("wave_boundaries", []).duplicate(true)
	book.restore(data.get("book", {}))
	last_snapshot = data.get("last_snapshot", {}).duplicate(true)
	_enemies.clear()
	engine.enemy_baselines.clear()
	if _game != null and is_instance_valid(_game) and _game.is_inside_tree():
		for enemy in _game.get_tree().get_nodes_in_group("enemies"):
			if enemy == null or not is_instance_valid(enemy):
				continue
			_enemies.append(enemy)
			engine.restore_enemy_baseline(
				_enemy_key(enemy),
				_read_enemy_facts(enemy),
				_expected_total_wave_weight
			)
			if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
				enemy.died.connect(_on_enemy_died)
			if enemy.has_signal("reached_core") and not enemy.reached_core.is_connected(_on_enemy_leaked):
				enemy.reached_core.connect(_on_enemy_leaked)
	_accum = 0.0
	_restoring = false
	_emit_state({})
	if book.has_live():
		candle_updated.emit(book.live.duplicate(true))


func _read_enemy_facts(enemy: Node3D) -> Dictionary:
	var max_hp := maxf(float(enemy.get("max_health")) if "max_health" in enemy else 1.0, 0.001)
	var hp := float(enemy.get("health")) if "health" in enemy else max_hp
	var progress := 0.0
	if enemy.has_method("get_normalized_path_progress"):
		progress = float(enemy.call("get_normalized_path_progress"))
	elif enemy.has_method("get_path_progress"):
		progress = clampf(float(enemy.call("get_path_progress")) / 8.0, 0.0, 1.0)
	var weight := float(enemy.get("weight")) if "weight" in enemy else 1.0
	return {
		"health": hp,
		"max_health": max_hp,
		"hp_fraction": clampf(hp / max_hp, 0.0, 1.0),
		"progress": clampf(progress, 0.0, 1.0),
		"weight": weight,
	}


func _enemy_key(enemy: Node3D) -> String:
	if enemy != null and "runtime_id" in enemy and not str(enemy.get("runtime_id")).is_empty():
		return str(enemy.get("runtime_id"))
	return str(enemy.get_instance_id()) if enemy != null else ""


func _untrack_enemy(enemy: Node3D) -> void:
	_enemies.erase(enemy)


func _prune_enemies() -> void:
	var kept: Array = []
	for enemy in _enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
			continue
		kept.append(enemy)
	_enemies = kept


func _wave_total_weight(wave: int) -> float:
	var definition: Dictionary = WaveCatalogScript.get_wave(wave)
	var total := 0.0
	for group in definition.get("groups", []):
		total += float(group.get("count", 0)) * float(group.get("weight", 1.0))
	return maxf(total, 1.0)


func _threat_indicator() -> float:
	var threat := 0.0
	for enemy in _enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var facts := _read_enemy_facts(enemy)
		threat += (
			float(facts["hp_fraction"])
			* float(facts["weight"])
			* MarketConfig.danger(float(facts["progress"]))
		)
	return threat


func _refresh_phase() -> void:
	if _game == null:
		return
	var spawning := false
	if _wave_manager != null and _wave_manager.has_method("is_spawning"):
		spawning = bool(_wave_manager.call("is_spawning"))
	var phase := MarketPhase.resolve(
		bool(_game.get("game_over")) or bool(_game.get("level_complete")),
		int(_game.get("waves_started")),
		spawning,
		bool(_game.call("is_active_spawn_complete")) if _game.has_method("is_active_spawn_complete") else false,
		int(_game.get("enemies_alive"))
	)
	if (
		phase == MarketPhase.Phase.PRE_MARKET
		and current_phase == MarketPhase.Phase.MARKET_OPEN
	):
		_close_session_candle()
	set_phase(phase)


func _close_session_candle() -> void:
	if _restoring or not book.has_live():
		return
	flush_pending()
	if not book.has_live():
		return
	var closed: Dictionary = book.close_candle(current_price)
	if closed.is_empty():
		return
	_close_last_boundary()
	_emit_candle_telemetry(closed)
	candle_closed.emit(closed)


func _core_hp() -> int:
	if _game != null:
		return int(_game.get("core_hp"))
	if _core != null:
		return int(_core.get("health"))
	return 20


func _close_last_boundary() -> void:
	if _wave_boundaries.is_empty():
		return
	var last: Dictionary = _wave_boundaries.back()
	last["end_ms"] = _run_elapsed_ms
	last["end_entry_index"] = engine.tape.entries.size()
	last["close"] = current_price
	_wave_boundaries[_wave_boundaries.size() - 1] = last


func _emit_candle_telemetry(closed: Dictionary) -> void:
	if _telemetry == null or not _telemetry.has_method("on_hodl_candle_closed"):
		return
	var totals: Dictionary = engine.attribution_totals
	_telemetry.call("on_hodl_candle_closed", {
		"wave": int(closed.get("wave", 0)),
		"hodl_open": float(closed.get("open", current_price)),
		"hodl_high": float(closed.get("high", current_price)),
		"hodl_low": float(closed.get("low", current_price)),
		"hodl_close": float(closed.get("close", current_price)),
		"spawn_pressure_total": float(totals.get("spawn", 0.0)),
		"carry_pressure_total": float(totals.get("carry", 0.0)),
		"advance_pressure_total": float(totals.get("advance", 0.0)),
		"damage_recovery_total": float(totals.get("damage", 0.0)),
		"kill_gain_total": float(totals.get("kill", 0.0)),
		"buy_impact_total": float(totals.get("buy", 0.0)),
		"core_loss_total": float(totals.get("core", 0.0)),
	})


func _committed_open_price() -> float:
	if typeof(ProfileManager) != TYPE_NIL and ProfileManager.has_method("get_global_hodl_price"):
		return float(ProfileManager.get_global_hodl_price())
	return MarketConfig.INITIAL_HODL_PRICE


func _wall_time_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

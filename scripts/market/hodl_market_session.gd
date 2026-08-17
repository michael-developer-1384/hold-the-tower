extends Node

## Persistent combat-derived HODL Price. Presentation-only; never drives combat.

signal hodl_index_changed(value: float, snapshot: Dictionary)
signal candle_started(wave: int, candle: Dictionary)
signal candle_updated(candle: Dictionary)
signal candle_closed(candle: Dictionary)

const HodlIndexModelScript := preload("res://scripts/market/hodl_index_model.gd")
const HodlCandleBookScript := preload("res://scripts/market/hodl_candle_book.gd")
const WaveCatalogScript := preload("res://scripts/waves/wave_catalog.gd")
const SAMPLE_INTERVAL := 0.10

var current_price: float = 100.0
var current_index: float = 100.0
var last_snapshot: Dictionary = {}
var book = HodlCandleBookScript.new()
var previous_pressure: float = 0.0
var realized_gain_total: float = 0.0
var realized_loss_total: float = 0.0
var last_price_delta: float = 0.0
var last_pressure_delta: float = 0.0
var last_pressure_price_delta: float = 0.0

var _game: Node
var _core: Node
var _wave_manager: Node
var _telemetry: Node
var _enemies: Array = []
var _accum: float = 0.0
var _expected_wave_count: float = 12.0
var _previous_core_hp: int = 20
var pending_realized_gain: float = 0.0
var pending_realized_loss: float = 0.0
var _candle_realized_gain: float = 0.0
var _candle_realized_loss: float = 0.0
var _candle_kills: int = 0
var _core_hp_at_candle_open: int = 20
var _restoring: bool = false


func setup(game: Node, wave_manager: Node, core: Node, telemetry: Node) -> void:
	_game = game
	_wave_manager = wave_manager
	_core = core
	_telemetry = telemetry
	_previous_core_hp = _core_hp()
	_core_hp_at_candle_open = _previous_core_hp
	if _wave_manager != null and _wave_manager.has_signal("enemy_spawned"):
		if not _wave_manager.enemy_spawned.is_connected(_on_enemy_spawned):
			_wave_manager.enemy_spawned.connect(_on_enemy_spawned)
	_flush_market_state()
	hodl_index_changed.emit(current_price, last_snapshot)


func rollover_to_wave(next_wave: int) -> void:
	if _restoring:
		return
	_flush_market_state()
	var rollover_price := current_price
	if book.has_live():
		var closed: Dictionary = book.close_candle(rollover_price)
		if not closed.is_empty():
			_emit_telemetry(closed)
			candle_closed.emit(closed)
	_candle_realized_gain = 0.0
	_candle_realized_loss = 0.0
	_candle_kills = 0
	_expected_wave_count = _wave_enemy_count(next_wave)
	previous_pressure = float(_compute().get("pressure", previous_pressure))
	_core_hp_at_candle_open = _core_hp()
	var opened: Dictionary = book.open_candle(next_wave, rollover_price)
	candle_started.emit(next_wave, opened)
	hodl_index_changed.emit(current_price, last_snapshot)


func begin_wave_candle(wave: int) -> void:
	rollover_to_wave(wave)


func close_run_candle() -> void:
	if _restoring:
		return
	_flush_market_state()
	if not book.has_live():
		return
	var closed: Dictionary = book.close_candle(current_price)
	if closed.is_empty():
		return
	_emit_telemetry(closed)
	candle_closed.emit(closed)
	hodl_index_changed.emit(current_price, last_snapshot)


func _physics_process(delta: float) -> void:
	if _game != null and (
		bool(_game.get("timeline_previewing"))
		or bool(_game.get("game_over"))
		or bool(_game.get("level_complete"))
	):
		return
	_accum += delta
	if _accum + 0.0001 < SAMPLE_INTERVAL:
		return
	_accum = 0.0
	_flush_market_state()
	hodl_index_changed.emit(current_price, last_snapshot)


func _flush_market_state() -> void:
	_prune_enemies()
	var snap := _compute()
	var current_pressure := float(snap.get("pressure", 0.0))
	var prev_pressure := previous_pressure
	var pressure_delta := prev_pressure - current_pressure
	var pressure_price := pressure_delta * HodlIndexModelScript.PRESSURE_TO_PRICE_FACTOR
	var core_now := _core_hp()
	var core_loss_hp := maxi(_previous_core_hp - core_now, 0)
	var core_loss_price := float(core_loss_hp) * HodlIndexModelScript.CORE_DAMAGE_PRICE_FACTOR
	var gain := pending_realized_gain
	var loss := pending_realized_loss + core_loss_price
	pending_realized_gain = 0.0
	pending_realized_loss = 0.0
	realized_gain_total += gain
	realized_loss_total += loss
	_candle_realized_gain += gain
	_candle_realized_loss += loss
	last_pressure_delta = pressure_delta
	last_pressure_price_delta = pressure_price
	last_price_delta = pressure_price + gain - loss
	current_price = maxf(
		HodlIndexModelScript.MIN_HODL_PRICE,
		current_price + last_price_delta
	)
	current_index = current_price
	previous_pressure = current_pressure
	_previous_core_hp = core_now
	snap["index"] = current_price
	snap["current_price"] = current_price
	snap["previous_pressure"] = prev_pressure
	snap["pressure_delta"] = last_pressure_delta
	snap["pressure_price_delta"] = last_pressure_price_delta
	snap["pending_realized_gain"] = 0.0
	snap["pending_realized_loss"] = 0.0
	snap["realized_gain_total"] = realized_gain_total
	snap["realized_loss_total"] = realized_loss_total
	snap["last_price_delta"] = last_price_delta
	last_snapshot = snap
	if book.has_live():
		candle_updated.emit(book.sample(current_price))


func _compute() -> Dictionary:
	return HodlIndexModelScript.evaluate({
		"enemies": _enemy_snapshots(),
		"expected_wave_count": _expected_wave_count,
		"guard_damage_fraction": 0.0,
	})


func _enemy_snapshots() -> Array:
	var out: Array = []
	for enemy in _enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
			continue
		var max_hp := float(enemy.get("max_health")) if "max_health" in enemy else 1.0
		var hp := float(enemy.get("health")) if "health" in enemy else 0.0
		var progress := 0.0
		if enemy.has_method("get_normalized_path_progress"):
			progress = float(enemy.call("get_normalized_path_progress"))
		elif enemy.has_method("get_path_progress"):
			progress = clampf(float(enemy.call("get_path_progress")) / 8.0, 0.0, 1.0)
		out.append({
			"health": hp,
			"max_health": max_hp,
			"progress": progress,
			"weight": 1.0,
		})
	return out


func _on_enemy_spawned(enemy: Node3D) -> void:
	if _restoring:
		return
	_register_enemy(enemy)


func _register_enemy(enemy: Node3D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if _enemies.has(enemy):
		return
	_enemies.append(enemy)
	if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	if enemy.has_signal("reached_core") and not enemy.reached_core.is_connected(_on_enemy_leaked):
		enemy.reached_core.connect(_on_enemy_leaked)


func _on_enemy_died(enemy: Node3D) -> void:
	_enemies.erase(enemy)
	if _restoring:
		return
	var gain := HodlIndexModelScript.kill_gain(_expected_wave_count)
	pending_realized_gain += gain
	_candle_kills += 1


func _on_enemy_leaked(enemy: Node3D) -> void:
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


func _emit_telemetry(closed: Dictionary) -> void:
	if _telemetry == null or not _telemetry.has_method("on_hodl_candle_closed"):
		return
	_telemetry.call("on_hodl_candle_closed", {
		"wave": int(closed.get("wave", 0)),
		"hodl_open": float(closed.get("open", 0.0)),
		"hodl_high": float(closed.get("high", 0.0)),
		"hodl_low": float(closed.get("low", 0.0)),
		"hodl_close": float(closed.get("close", 0.0)),
		"hodl_min": float(closed.get("low", 0.0)),
		"price_change": float(closed.get("close", 0.0)) - float(closed.get("open", 0.0)),
		"realized_gain": _candle_realized_gain,
		"realized_loss": _candle_realized_loss,
		"kills": _candle_kills,
		"core_damage_this_wave": maxi(_core_hp_at_candle_open - _core_hp(), 0),
	})


func _wave_enemy_count(wave: int) -> float:
	var def: Dictionary = WaveCatalogScript.get_wave(wave)
	var total := 0.0
	for group in def.get("groups", []):
		total += float(group.get("count", 0))
	return total if total > 0.0 else 12.0


func _core_hp() -> int:
	if _game != null:
		return int(_game.get("core_hp"))
	if _core != null:
		return int(_core.get("health"))
	return 20


func capture() -> Dictionary:
	return {
		"current_price": current_price,
		"current_index": current_price,
		"previous_pressure": previous_pressure,
		"previous_core_hp": _previous_core_hp,
		"pending_realized_gain": pending_realized_gain,
		"pending_realized_loss": pending_realized_loss,
		"realized_gain_total": realized_gain_total,
		"realized_loss_total": realized_loss_total,
		"last_snapshot": last_snapshot.duplicate(true),
		"expected_wave_count": _expected_wave_count,
		"core_hp_at_candle_open": _core_hp_at_candle_open,
		"candle_realized_gain": _candle_realized_gain,
		"candle_realized_loss": _candle_realized_loss,
		"candle_kills": _candle_kills,
		"book": book.capture(),
	}


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	_restoring = true
	current_price = float(data.get("current_price", data.get("current_index", 100.0)))
	current_index = current_price
	previous_pressure = float(data.get("previous_pressure", 0.0))
	_previous_core_hp = int(data.get("previous_core_hp", _core_hp()))
	pending_realized_gain = float(data.get("pending_realized_gain", 0.0))
	pending_realized_loss = float(data.get("pending_realized_loss", 0.0))
	realized_gain_total = float(data.get("realized_gain_total", 0.0))
	realized_loss_total = float(data.get("realized_loss_total", 0.0))
	last_snapshot = data.get("last_snapshot", {}).duplicate(true)
	_expected_wave_count = float(data.get("expected_wave_count", 12.0))
	_core_hp_at_candle_open = int(data.get("core_hp_at_candle_open", _previous_core_hp))
	_candle_realized_gain = float(data.get("candle_realized_gain", 0.0))
	_candle_realized_loss = float(data.get("candle_realized_loss", 0.0))
	_candle_kills = int(data.get("candle_kills", 0))
	book.restore(data.get("book", {}))
	_enemies.clear()
	if _game != null and is_instance_valid(_game) and _game.is_inside_tree():
		for enemy in _game.get_tree().get_nodes_in_group("enemies"):
			_register_enemy(enemy)
	_prune_enemies()
	_restoring = false
	hodl_index_changed.emit(current_price, last_snapshot)
	if book.has_live():
		candle_updated.emit(book.live.duplicate(true))


func visible_candles() -> Array:
	return book.visible_candles()

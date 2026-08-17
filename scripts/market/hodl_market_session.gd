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
var last_spawn_pressure: float = 0.0
var last_advance_pressure: float = 0.0
var last_damage_recovery: float = 0.0
var last_kill_gain: float = 0.0
var last_core_loss: float = 0.0

var _game: Node
var _core: Node
var _wave_manager: Node
var _telemetry: Node
var _enemies: Array = []
var _enemy_market: Dictionary = {}
var _accum: float = 0.0
var _expected_wave_count: float = 12.0
var _previous_core_hp: int = 20
var pending_realized_gain: float = 0.0
var pending_realized_loss: float = 0.0
var pending_spawn_pressure: float = 0.0
var pending_advance_loss: float = 0.0
var pending_damage_recovery: float = 0.0
var _candle_realized_gain: float = 0.0
var _candle_realized_loss: float = 0.0
var _candle_kills: int = 0
var _candle_spawn_pressure: float = 0.0
var _candle_advance_pressure: float = 0.0
var _candle_damage_recovery: float = 0.0
var _candle_kill_gain: float = 0.0
var _candle_core_loss: float = 0.0
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
	_reset_candle_totals()
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
	var sampled := _sample_enemy_flows()
	_prune_enemies()
	var snap := _compute()
	var current_pressure := float(snap.get("pressure", 0.0))
	var spawn_amt := pending_spawn_pressure
	var advance_amt := pending_advance_loss + float(sampled.get("advance", 0.0))
	var damage_amt := pending_damage_recovery + float(sampled.get("damage", 0.0))
	var kill_amt := pending_realized_gain
	pending_spawn_pressure = 0.0
	pending_advance_loss = 0.0
	pending_damage_recovery = 0.0
	pending_realized_gain = 0.0
	var core_now := _core_hp()
	var core_loss_hp := maxi(_previous_core_hp - core_now, 0)
	var core_loss_price := float(core_loss_hp) * HodlIndexModelScript.CORE_DAMAGE_PRICE_FACTOR
	var extra_loss := pending_realized_loss
	pending_realized_loss = 0.0
	var gain := damage_amt + kill_amt
	var loss := spawn_amt + advance_amt + core_loss_price + extra_loss
	realized_gain_total += gain
	realized_loss_total += loss
	_candle_realized_gain += gain
	_candle_realized_loss += loss
	_candle_spawn_pressure += spawn_amt
	_candle_advance_pressure += advance_amt
	_candle_damage_recovery += damage_amt
	_candle_kill_gain += kill_amt
	_candle_core_loss += core_loss_price
	last_spawn_pressure = spawn_amt
	last_advance_pressure = advance_amt
	last_damage_recovery = damage_amt
	last_kill_gain = kill_amt
	last_core_loss = core_loss_price
	last_price_delta = gain - loss
	current_price = maxf(
		HodlIndexModelScript.MIN_HODL_PRICE,
		current_price + last_price_delta
	)
	current_index = current_price
	previous_pressure = current_pressure
	_previous_core_hp = core_now
	snap["index"] = current_price
	snap["current_price"] = current_price
	snap["threat_indicator"] = current_pressure
	snap["previous_pressure"] = current_pressure
	snap["spawn_pressure"] = last_spawn_pressure
	snap["advance_pressure"] = last_advance_pressure
	snap["damage_recovery"] = last_damage_recovery
	snap["kill_gain"] = last_kill_gain
	snap["core_loss"] = last_core_loss
	snap["pending_realized_gain"] = 0.0
	snap["pending_realized_loss"] = 0.0
	snap["realized_gain_total"] = realized_gain_total
	snap["realized_loss_total"] = realized_loss_total
	snap["last_price_delta"] = last_price_delta
	last_snapshot = snap
	if book.has_live():
		candle_updated.emit(book.sample(current_price))


func _sample_enemy_flows() -> Dictionary:
	var damage := 0.0
	var advance := 0.0
	for enemy in _enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var key := _enemy_key(enemy)
		if not _enemy_market.has(key):
			_enemy_market[key] = _snapshot_enemy(enemy)
			continue
		var prev: Dictionary = _enemy_market[key]
		var cur := _snapshot_enemy(enemy)
		damage += HodlIndexModelScript.damage_recovery(
			maxf(float(prev.get("hp_fraction", 0.0)) - float(cur.get("hp_fraction", 0.0)), 0.0),
			float(cur.get("weight", 1.0))
		)
		advance += HodlIndexModelScript.advance_loss(
			maxf(float(cur.get("progress", 0.0)) - float(prev.get("progress", 0.0)), 0.0),
			float(cur.get("hp_fraction", 0.0)),
			float(cur.get("progress", 0.0))
		)
		_enemy_market[key] = cur
	return {"damage": damage, "advance": advance}


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
		var facts := _read_enemy_facts(enemy)
		out.append({
			"health": float(facts.get("health", 0.0)),
			"max_health": float(facts.get("max_health", 1.0)),
			"progress": float(facts.get("progress", 0.0)),
			"weight": float(facts.get("weight", 1.0)),
		})
	return out


func _on_enemy_spawned(enemy: Node3D) -> void:
	if _restoring:
		return
	_register_enemy(enemy, true)


func _register_enemy(enemy: Node3D, charge_spawn: bool) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if _enemies.has(enemy):
		return
	_enemies.append(enemy)
	if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	if enemy.has_signal("reached_core") and not enemy.reached_core.is_connected(_on_enemy_leaked):
		enemy.reached_core.connect(_on_enemy_leaked)
	var snap := _snapshot_enemy(enemy)
	_enemy_market[_enemy_key(enemy)] = snap
	if charge_spawn and not _restoring:
		pending_spawn_pressure += HodlIndexModelScript.spawn_pressure(
			float(snap.get("expected_count", _expected_wave_count)),
			float(snap.get("weight", 1.0))
		)


func _on_enemy_died(enemy: Node3D) -> void:
	if _restoring:
		_untrack_enemy(enemy)
		return
	_reconcile_enemy(enemy, 0.0, -1.0)
	var expected := _expected_wave_count
	var key := _enemy_key(enemy) if enemy != null and is_instance_valid(enemy) else 0
	if _enemy_market.has(key):
		expected = float(_enemy_market[key].get("expected_count", expected))
	pending_realized_gain += HodlIndexModelScript.kill_gain(expected)
	_candle_kills += 1
	_untrack_enemy(enemy)


func _on_enemy_leaked(enemy: Node3D) -> void:
	if _restoring:
		_untrack_enemy(enemy)
		return
	_reconcile_enemy(enemy, -1.0, 1.0)
	_untrack_enemy(enemy)


func _reconcile_enemy(enemy: Node3D, final_hp_fraction: float, final_progress: float) -> void:
	var key := _enemy_key(enemy) if enemy != null and is_instance_valid(enemy) else 0
	if key == 0 or not _enemy_market.has(key):
		return
	var prev: Dictionary = _enemy_market[key]
	var hp_frac := final_hp_fraction
	var progress := final_progress
	if enemy != null and is_instance_valid(enemy):
		var facts := _read_enemy_facts(enemy)
		if hp_frac < 0.0:
			hp_frac = float(facts.get("hp_fraction", float(prev.get("hp_fraction", 0.0))))
		if progress < 0.0:
			progress = float(facts.get("progress", float(prev.get("progress", 0.0))))
	else:
		if hp_frac < 0.0:
			hp_frac = float(prev.get("hp_fraction", 0.0))
		if progress < 0.0:
			progress = float(prev.get("progress", 0.0))
	hp_frac = clampf(hp_frac, 0.0, 1.0)
	progress = clampf(progress, 0.0, 1.0)
	pending_damage_recovery += HodlIndexModelScript.damage_recovery(
		maxf(float(prev.get("hp_fraction", 0.0)) - hp_frac, 0.0),
		float(prev.get("weight", 1.0))
	)
	pending_advance_loss += HodlIndexModelScript.advance_loss(
		maxf(progress - float(prev.get("progress", 0.0)), 0.0),
		hp_frac if final_hp_fraction < 0.0 else maxf(hp_frac, float(prev.get("hp_fraction", 0.0))),
		progress
	)


func _prune_enemies() -> void:
	var kept: Array = []
	for enemy in _enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
			continue
		kept.append(enemy)
	_enemies = kept
	var live_keys: Dictionary = {}
	for enemy in _enemies:
		live_keys[_enemy_key(enemy)] = true
	var stale: Array = []
	for key in _enemy_market.keys():
		if not live_keys.has(key):
			stale.append(key)
	for key in stale:
		_enemy_market.erase(key)


func _untrack_enemy(enemy: Node3D) -> void:
	_enemies.erase(enemy)
	if enemy != null and is_instance_valid(enemy):
		_enemy_market.erase(_enemy_key(enemy))


func _snapshot_enemy(enemy: Node3D) -> Dictionary:
	var facts := _read_enemy_facts(enemy)
	facts["expected_count"] = _expected_wave_count
	return facts


func _read_enemy_facts(enemy: Node3D) -> Dictionary:
	var max_hp := float(enemy.get("max_health")) if "max_health" in enemy else 1.0
	var hp := float(enemy.get("health")) if "health" in enemy else 0.0
	max_hp = maxf(max_hp, 0.001)
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


func _enemy_key(enemy: Node3D) -> int:
	return enemy.get_instance_id()


func _reset_candle_totals() -> void:
	_candle_realized_gain = 0.0
	_candle_realized_loss = 0.0
	_candle_kills = 0
	_candle_spawn_pressure = 0.0
	_candle_advance_pressure = 0.0
	_candle_damage_recovery = 0.0
	_candle_kill_gain = 0.0
	_candle_core_loss = 0.0


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
		"spawn_pressure_total": _candle_spawn_pressure,
		"advance_pressure_total": _candle_advance_pressure,
		"damage_recovery_total": _candle_damage_recovery,
		"kill_gain_total": _candle_kill_gain,
		"core_loss_total": _candle_core_loss,
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
		"pending_spawn_pressure": pending_spawn_pressure,
		"pending_advance_loss": pending_advance_loss,
		"pending_damage_recovery": pending_damage_recovery,
		"realized_gain_total": realized_gain_total,
		"realized_loss_total": realized_loss_total,
		"last_snapshot": last_snapshot.duplicate(true),
		"expected_wave_count": _expected_wave_count,
		"core_hp_at_candle_open": _core_hp_at_candle_open,
		"candle_realized_gain": _candle_realized_gain,
		"candle_realized_loss": _candle_realized_loss,
		"candle_kills": _candle_kills,
		"candle_spawn_pressure": _candle_spawn_pressure,
		"candle_advance_pressure": _candle_advance_pressure,
		"candle_damage_recovery": _candle_damage_recovery,
		"candle_kill_gain": _candle_kill_gain,
		"candle_core_loss": _candle_core_loss,
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
	pending_spawn_pressure = float(data.get("pending_spawn_pressure", 0.0))
	pending_advance_loss = float(data.get("pending_advance_loss", 0.0))
	pending_damage_recovery = float(data.get("pending_damage_recovery", 0.0))
	realized_gain_total = float(data.get("realized_gain_total", 0.0))
	realized_loss_total = float(data.get("realized_loss_total", 0.0))
	last_snapshot = data.get("last_snapshot", {}).duplicate(true)
	_expected_wave_count = float(data.get("expected_wave_count", 12.0))
	_core_hp_at_candle_open = int(data.get("core_hp_at_candle_open", _previous_core_hp))
	_candle_realized_gain = float(data.get("candle_realized_gain", 0.0))
	_candle_realized_loss = float(data.get("candle_realized_loss", 0.0))
	_candle_kills = int(data.get("candle_kills", 0))
	_candle_spawn_pressure = float(data.get("candle_spawn_pressure", 0.0))
	_candle_advance_pressure = float(data.get("candle_advance_pressure", 0.0))
	_candle_damage_recovery = float(data.get("candle_damage_recovery", 0.0))
	_candle_kill_gain = float(data.get("candle_kill_gain", 0.0))
	_candle_core_loss = float(data.get("candle_core_loss", 0.0))
	book.restore(data.get("book", {}))
	_enemies.clear()
	_enemy_market.clear()
	_accum = 0.0
	if _game != null and is_instance_valid(_game) and _game.is_inside_tree():
		for enemy in _game.get_tree().get_nodes_in_group("enemies"):
			_register_enemy(enemy, false)
	_prune_enemies()
	_restoring = false
	hodl_index_changed.emit(current_price, last_snapshot)
	if book.has_live():
		candle_updated.emit(book.live.duplicate(true))


func visible_candles() -> Array:
	return book.visible_candles()

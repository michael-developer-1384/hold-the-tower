extends Node

## Samples the HODL Index at 10 Hz. Presentation-only; never drives combat.

signal hodl_index_changed(value: float, snapshot: Dictionary)
signal candle_started(wave: int, candle: Dictionary)
signal candle_updated(candle: Dictionary)
signal candle_closed(candle: Dictionary)

const HodlIndexModelScript := preload("res://scripts/market/hodl_index_model.gd")
const HodlCandleBookScript := preload("res://scripts/market/hodl_candle_book.gd")
const WaveCatalogScript := preload("res://scripts/waves/wave_catalog.gd")
const SAMPLE_INTERVAL := 0.10
const THREAT_EPSILON := 0.001

var current_index: float = 100.0
var last_snapshot: Dictionary = {}
var book = HodlCandleBookScript.new()

var _game: Node
var _core: Node
var _wave_manager: Node
var _telemetry: Node
var _enemies: Array = []
var _accum: float = 0.0
var _expected_wave_count: float = 12.0
var _core_max_hp: float = 20.0
var _core_hp_at_candle_open: int = 20
var _restoring: bool = false


func setup(game: Node, wave_manager: Node, core: Node, telemetry: Node) -> void:
	_game = game
	_wave_manager = wave_manager
	_core = core
	_telemetry = telemetry
	if _core != null and "max_health" in _core:
		_core_max_hp = float(_core.get("max_health"))
	_core_hp_at_candle_open = _core_hp()
	if _wave_manager != null and _wave_manager.has_signal("enemy_spawned"):
		if not _wave_manager.enemy_spawned.is_connected(_on_enemy_spawned):
			_wave_manager.enemy_spawned.connect(_on_enemy_spawned)
	_sample()


func begin_wave_candle(wave: int) -> void:
	if _restoring:
		return
	_expected_wave_count = _wave_enemy_count(wave)
	_core_hp_at_candle_open = _core_hp()
	book.arm_candle(wave)
	var snap := _compute()
	current_index = float(snap.get("index", 100.0))
	last_snapshot = snap
	hodl_index_changed.emit(current_index, snap)
	_maybe_open_from_snapshot(snap)


func _physics_process(delta: float) -> void:
	if _game != null and bool(_game.get("timeline_previewing")):
		return
	_accum += delta
	if _accum + 0.0001 < SAMPLE_INTERVAL:
		return
	_accum = 0.0
	_sample()


func _sample() -> void:
	_prune_enemies()
	var snap := _compute()
	current_index = float(snap.get("index", 100.0))
	last_snapshot = snap
	_maybe_open_from_snapshot(snap)
	if book.has_live():
		candle_updated.emit(book.sample(current_index))
	hodl_index_changed.emit(current_index, snap)


func _maybe_open_from_snapshot(snap: Dictionary) -> void:
	if not book.is_armed() or book.has_live():
		return
	if float(snap.get("active_threat", 0.0)) <= THREAT_EPSILON:
		return
	var candle: Dictionary = book.open_armed(current_index)
	if not candle.is_empty():
		candle_started.emit(int(candle.get("wave", 0)), candle)


func _compute() -> Dictionary:
	return HodlIndexModelScript.evaluate({
		"enemies": _enemy_snapshots(),
		"expected_wave_count": _expected_wave_count,
		"core_hp": float(_core_hp()),
		"core_max_hp": _core_max_hp,
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
	if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_gone):
		enemy.died.connect(_on_enemy_gone)
	if enemy.has_signal("reached_core") and not enemy.reached_core.is_connected(_on_enemy_gone):
		enemy.reached_core.connect(_on_enemy_gone)


func _on_enemy_gone(enemy: Node3D) -> void:
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


func close_wave_candle() -> void:
	if _restoring:
		return
	if not book.has_live() and not book.is_armed():
		return
	_sample()
	if book.is_armed() and not book.has_live():
		book.open_armed(current_index)
	var closed: Dictionary = book.close_live(current_index)
	if closed.is_empty():
		return
	_emit_telemetry(closed)
	candle_closed.emit(closed)


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
		"current_index": current_index,
		"last_snapshot": last_snapshot.duplicate(true),
		"expected_wave_count": _expected_wave_count,
		"core_max_hp": _core_max_hp,
		"core_hp_at_candle_open": _core_hp_at_candle_open,
		"book": book.capture(),
	}


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	_restoring = true
	current_index = float(data.get("current_index", 100.0))
	last_snapshot = data.get("last_snapshot", {}).duplicate(true)
	_expected_wave_count = float(data.get("expected_wave_count", 12.0))
	_core_max_hp = float(data.get("core_max_hp", _core_max_hp))
	_core_hp_at_candle_open = int(data.get("core_hp_at_candle_open", _core_hp()))
	book.restore(data.get("book", {}))
	_enemies.clear()
	if _game != null:
		for enemy in _game.get_tree().get_nodes_in_group("enemies"):
			_register_enemy(enemy)
	_prune_enemies()
	_restoring = false
	var snap := _compute()
	current_index = float(snap.get("index", current_index))
	last_snapshot = snap
	hodl_index_changed.emit(current_index, last_snapshot)
	_maybe_open_from_snapshot(snap)
	if book.has_live():
		candle_updated.emit(book.live.duplicate(true))


func visible_candles() -> Array:
	return book.visible_candles()

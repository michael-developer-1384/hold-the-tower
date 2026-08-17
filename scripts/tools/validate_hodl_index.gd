extends SceneTree

## HODL Index model, OHLC freeze, capture/restore, SceneTree pause.
## godot --headless --path . --script res://scripts/tools/validate_hodl_index.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	print("validate_hodl_index: starting")
	var ok := true
	ok = _test_empty_full() and ok
	ok = _test_spawn_damage_proximity_death() and ok
	ok = _test_leak_not_rally() and ok
	ok = _test_repeated_leaks() and ok
	ok = _test_ohlc_finalize_once() and ok
	ok = _test_capture_restore() and ok
	ok = _test_premarket_freeze() and ok
	ok = _test_arm_before_open() and ok
	ok = _test_strong_defense_green() and ok
	ok = _test_weak_defense_red() and ok
	ok = _test_fast_defense_not_forced_red() and ok
	ok = _test_no_threat_flat_close() and ok
	ok = _test_armed_capture_restore() and ok
	ok = _test_leak_gap_next_open() and ok
	ok = (await _test_pause_freezes()) and ok
	if ok:
		print("validate_hodl_index: PASS")
		quit(0)
	else:
		print("validate_hodl_index: FAIL")
		quit(1)


func _model():
	return load("res://scripts/market/hodl_index_model.gd")


func _book():
	return load("res://scripts/market/hodl_candle_book.gd").new()


func _eval(enemies: Array, core_hp: float, expected: float = 10.0, core_max: float = 20.0) -> Dictionary:
	return _model().evaluate({
		"enemies": enemies,
		"expected_wave_count": expected,
		"core_hp": core_hp,
		"core_max_hp": core_max,
		"guard_damage_fraction": 0.0,
	})


func _enemy(hp_frac: float, progress: float, max_hp: float = 100.0) -> Dictionary:
	return {
		"health": max_hp * hp_frac,
		"max_health": max_hp,
		"progress": progress,
		"weight": 1.0,
	}


func _test_empty_full() -> bool:
	var snap: Dictionary = _eval([], 20.0)
	var idx := float(snap.get("index", 0.0))
	if idx < 99.9 or idx > 100.01:
		print("  empty FAIL  index=%.3f" % idx)
		return false
	print("  empty PASS  index=%.2f" % idx)
	return true


func _test_spawn_damage_proximity_death() -> bool:
	var spawn: Dictionary = _eval([_enemy(1.0, 0.0)], 20.0)
	var hurt: Dictionary = _eval([_enemy(0.4, 0.0)], 20.0)
	var close: Dictionary = _eval([_enemy(1.0, 1.0)], 20.0)
	var dead: Dictionary = _eval([], 20.0)
	var i_spawn := float(spawn.get("index"))
	var i_hurt := float(hurt.get("index"))
	var i_close := float(close.get("index"))
	var i_dead := float(dead.get("index"))
	if i_spawn >= 99.9:
		print("  spawn FAIL  did not drop %.3f" % i_spawn)
		return false
	if i_hurt <= i_spawn:
		print("  damage FAIL  spawn=%.3f hurt=%.3f" % [i_spawn, i_hurt])
		return false
	if i_close >= i_spawn:
		print("  proximity FAIL  spawn=%.3f close=%.3f" % [i_spawn, i_close])
		return false
	if i_dead < 99.9:
		print("  death FAIL  %.3f" % i_dead)
		return false
	print("  spawn/damage/proximity/death PASS  %.1f > %.1f > close %.1f" % [i_hurt, i_spawn, i_close])
	return true


func _test_leak_not_rally() -> bool:
	var alive_close: Dictionary = _eval([_enemy(1.0, 1.0)], 20.0)
	var leaked: Dictionary = _eval([], 19.0)
	var killed: Dictionary = _eval([], 20.0)
	var i_alive := float(alive_close.get("index"))
	var i_leak := float(leaked.get("index"))
	var i_kill := float(killed.get("index"))
	if i_leak >= i_kill:
		print("  leak FAIL  leak looked like a kill rally leak=%.3f kill=%.3f" % [i_leak, i_kill])
		return false
	if i_leak > i_alive + 0.05:
		print("  leak FAIL  leak rallied vs near-core enemy leak=%.3f alive=%.3f" % [i_leak, i_alive])
		return false
	print("  leak PASS  leak=%.2f alive=%.2f kill=%.2f" % [i_leak, i_alive, i_kill])
	return true


func _test_repeated_leaks() -> bool:
	var one: Dictionary = _eval([], 19.0)
	var two: Dictionary = _eval([], 18.0)
	if float(two.get("index")) >= float(one.get("index")) - 0.01:
		print("  repeated leak FAIL")
		return false
	print("  repeated leak PASS  %.2f -> %.2f" % [float(one.get("index")), float(two.get("index"))])
	return true


func _test_ohlc_finalize_once() -> bool:
	var book = _book()
	book.start_candle(1, 100.0)
	book.sample(90.0)
	book.sample(95.0)
	var closed: Dictionary = book.close_live(95.0)
	book.sample(80.0)
	if absf(float(closed.get("close", 0.0)) - 95.0) > 0.001:
		print("  ohlc FAIL close mutated %.3f" % float(closed.get("close", 0.0)))
		return false
	if book.has_live():
		print("  ohlc FAIL still live")
		return false
	var again: Dictionary = book.close_live(70.0)
	if not again.is_empty():
		print("  ohlc FAIL closed twice")
		return false
	print("  ohlc PASS  O/H/L/C %.1f/%.1f/%.1f/%.1f" % [
		float(closed.get("open")), float(closed.get("high")), float(closed.get("low")), float(closed.get("close"))
	])
	return true


func _test_capture_restore() -> bool:
	var book = _book()
	book.start_candle(1, 100.0)
	book.sample(92.0)
	var cap: Dictionary = book.capture()
	var other = _book()
	other.restore(cap)
	if absf(float(other.live.get("close", 0.0)) - 92.0) > 0.001:
		print("  restore FAIL")
		return false
	print("  capture/restore PASS")
	return true


func _test_premarket_freeze() -> bool:
	var book = _book()
	book.start_candle(1, 100.0)
	book.sample(88.0)
	var closed: Dictionary = book.close_live()
	var frozen_low := float(closed.get("low", 0.0))
	# PRE-MARKET ticker may move, but the completed candle must not.
	var after := _eval([_enemy(1.0, 1.0)], 19.0)
	if absf(float(closed.get("low")) - frozen_low) > 0.0001:
		print("  premarket FAIL candle mutated")
		return false
	if float(after.get("index")) >= 99.0:
		print("  premarket FAIL ticker should still move")
		return false
	print("  premarket freeze PASS  closed low=%.1f ticker=%.1f" % [frozen_low, float(after.get("index"))])
	return true


func _apply_threat_open(book, snap: Dictionary) -> void:
	if not book.is_armed():
		return
	if float(snap.get("active_threat", 0.0)) <= 0.001:
		return
	book.open_armed(float(snap.get("index", 100.0)))


func _test_arm_before_open() -> bool:
	var book = _book()
	book.arm_candle(1)
	if not book.is_armed() or book.has_live():
		print("  arm FAIL  should wait for threat")
		return false
	var empty: Dictionary = _eval([], 20.0)
	_apply_threat_open(book, empty)
	if book.has_live():
		print("  arm FAIL  opened without threat")
		return false
	print("  arm-before-open PASS")
	return true


func _test_strong_defense_green() -> bool:
	var book = _book()
	book.arm_candle(1)
	var first: Dictionary = _eval([_enemy(1.0, 0.0)], 20.0)
	_apply_threat_open(book, first)
	var open_v := float(first.get("index"))
	book.sample(open_v - 7.0)
	book.sample(open_v + 0.5)
	var closed: Dictionary = book.close_live(open_v + 0.5)
	if float(closed.get("close")) + 0.0001 < float(closed.get("open")):
		print("  strong FAIL  expected green O=%.2f C=%.2f" % [
			float(closed.get("open")), float(closed.get("close"))
		])
		return false
	print("  strong defense PASS  O=%.2f C=%.2f green" % [
		float(closed.get("open")), float(closed.get("close"))
	])
	return true


func _test_weak_defense_red() -> bool:
	var book = _book()
	book.arm_candle(1)
	var first: Dictionary = _eval([_enemy(1.0, 0.0)], 20.0)
	_apply_threat_open(book, first)
	var worse: Dictionary = _eval([_enemy(1.0, 0.0), _enemy(1.0, 0.4), _enemy(1.0, 0.8)], 20.0)
	book.sample(float(worse.get("index")))
	var closed: Dictionary = book.close_live(float(worse.get("index")))
	if float(closed.get("close")) >= float(closed.get("open")):
		print("  weak FAIL  expected red O=%.2f C=%.2f" % [
			float(closed.get("open")), float(closed.get("close"))
		])
		return false
	print("  weak defense PASS  O=%.2f C=%.2f red" % [
		float(closed.get("open")), float(closed.get("close"))
	])
	return true


func _test_fast_defense_not_forced_red() -> bool:
	var book = _book()
	book.arm_candle(1)
	var first: Dictionary = _eval([_enemy(1.0, 0.0)], 20.0)
	_apply_threat_open(book, first)
	var cleared: Dictionary = _eval([], 20.0)
	var closed: Dictionary = book.close_live(float(cleared.get("index")))
	if absf(float(closed.get("open")) - 100.0) < 0.001 and float(closed.get("close")) < 100.0:
		print("  fast FAIL  artificial 100-open red")
		return false
	if float(closed.get("close")) + 0.0001 < float(closed.get("open")):
		print("  fast FAIL  systematic red O=%.2f C=%.2f" % [
			float(closed.get("open")), float(closed.get("close"))
		])
		return false
	print("  fast defense PASS  O=%.2f C=%.2f not forced red" % [
		float(closed.get("open")), float(closed.get("close"))
	])
	return true


func _test_no_threat_flat_close() -> bool:
	var book = _book()
	book.arm_candle(2)
	var closed: Dictionary = book.close_live(96.5)
	if closed.is_empty():
		print("  flat FAIL  lost wave candle")
		return false
	if int(closed.get("wave")) != 2:
		print("  flat FAIL  wave")
		return false
	for key in ["open", "high", "low", "close"]:
		if absf(float(closed.get(key)) - 96.5) > 0.001:
			print("  flat FAIL  %s=%.3f" % [key, float(closed.get(key))])
			return false
	if book.has_live() or book.is_armed():
		print("  flat FAIL  still live/armed")
		return false
	print("  no-threat flat PASS")
	return true


func _test_armed_capture_restore() -> bool:
	var book = _book()
	book.arm_candle(3)
	var cap: Dictionary = book.capture()
	if int(cap.get("armed_wave", 0)) != 3:
		print("  armed restore FAIL  capture missing armed_wave")
		return false
	var other = _book()
	other.restore(cap)
	if not other.is_armed() or other.has_live():
		print("  armed restore FAIL  armed=%s live=%s" % [str(other.is_armed()), str(other.has_live())])
		return false
	var first: Dictionary = _eval([_enemy(1.0, 0.0)], 20.0)
	_apply_threat_open(other, first)
	if not other.has_live():
		print("  armed restore FAIL  did not open after restore")
		return false
	print("  armed capture/restore PASS")
	return true


func _test_leak_gap_next_open() -> bool:
	var book = _book()
	book.arm_candle(1)
	var first: Dictionary = _eval([_enemy(1.0, 0.0)], 20.0)
	_apply_threat_open(book, first)
	var closed: Dictionary = book.close_live(float(_eval([], 20.0).get("index")))
	var leak: Dictionary = _eval([], 19.0)
	book.arm_candle(2)
	var leftover: Dictionary = _eval([_enemy(1.0, 0.0)], 19.0)
	_apply_threat_open(book, leftover)
	var next_open := float(book.live.get("open", 0.0))
	if next_open + 0.05 >= float(closed.get("close")):
		print("  leak gap FAIL  next open %.2f vs prev close %.2f leak_index=%.2f" % [
			next_open, float(closed.get("close")), float(leak.get("index"))
		])
		return false
	print("  leak gap PASS  C1=%.2f O2=%.2f" % [float(closed.get("close")), next_open])
	return true


func _test_pause_freezes() -> bool:
	var ticker := _PauseProbe.new()
	root.add_child(ticker)
	for _i in 3:
		await physics_frame
	var before := ticker.ticks
	if before <= 0:
		print("  pause FAIL  probe never ticked")
		ticker.queue_free()
		return false
	paused = true
	for _j in 8:
		await process_frame
	var mid := ticker.ticks
	paused = false
	ticker.queue_free()
	if mid != before:
		print("  pause FAIL  ticks advanced while paused %d -> %d" % [before, mid])
		return false
	print("  pause PASS  ticks frozen at %d" % mid)
	return true


class _PauseProbe extends Node:
	var ticks: int = 0

	func _physics_process(_delta: float) -> void:
		ticks += 1

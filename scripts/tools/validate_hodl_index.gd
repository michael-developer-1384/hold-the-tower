extends SceneTree

## Continuous HODL Price: pressure deltas, kill gains, core-loss once, candle continuity.
## godot --headless --path . --script res://scripts/tools/validate_hodl_index.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	print("validate_hodl_index: starting")
	var ok := true
	ok = _test_idle() and ok
	ok = _test_spawn_proximity_damage() and ok
	ok = _test_kill_gain() and ok
	ok = _test_perfect_wave_green() and ok
	ok = _test_leak_once() and ok
	ok = _test_candle_continuity() and ok
	ok = _test_premarket_gap_down() and ok
	ok = _test_premarket_gap_up() and ok
	ok = _test_ohlc_immutable() and ok
	ok = _test_restore_no_jump() and ok
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


func _enemy(hp_frac: float, progress: float, max_hp: float = 100.0) -> Dictionary:
	return {
		"health": max_hp * hp_frac,
		"max_health": max_hp,
		"progress": progress,
		"weight": 1.0,
	}


func _pressure(enemies: Array, expected: float = 10.0) -> float:
	var snap: Dictionary = _model().evaluate({
		"enemies": enemies,
		"expected_wave_count": expected,
	})
	return float(snap.get("pressure", 0.0))


func _tick(state: Dictionary, enemies: Array, core_hp: int, pending_gain: float = 0.0, expected: float = 10.0) -> Dictionary:
	var p := _pressure(enemies, expected)
	var d_pressure := float(state.get("prev_p", 0.0)) - p
	var core_loss := float(maxi(int(state.get("prev_core", 20)) - core_hp, 0)) * float(_model().CORE_DAMAGE_PRICE_FACTOR)
	var d_price := d_pressure * float(_model().PRESSURE_TO_PRICE_FACTOR) + pending_gain - core_loss
	var price := maxf(float(_model().MIN_HODL_PRICE), float(state.get("price", 100.0)) + d_price)
	return {
		"price": price,
		"prev_p": p,
		"prev_core": core_hp,
		"d_price": d_price,
	}


func _test_idle() -> bool:
	var a := _tick({"price": 100.0, "prev_p": 0.0, "prev_core": 20}, [], 20)
	var b := _tick(a, [], 20)
	if absf(float(b.get("price")) - 100.0) > 0.0001:
		print("  idle FAIL  drifted to %.4f" % float(b.get("price")))
		return false
	print("  idle PASS  price=100.00")
	return true


func _test_spawn_proximity_damage() -> bool:
	var s0 := {"price": 100.0, "prev_p": 0.0, "prev_core": 20}
	var spawn := _tick(s0, [_enemy(1.0, 0.0)], 20)
	var close := _tick(spawn, [_enemy(1.0, 1.0)], 20)
	var hurt := _tick(spawn, [_enemy(0.4, 0.0)], 20)
	if float(spawn.get("price")) >= 99.99:
		print("  spawn FAIL  price=%.3f" % float(spawn.get("price")))
		return false
	if float(close.get("price")) >= float(spawn.get("price")):
		print("  proximity FAIL")
		return false
	if float(hurt.get("price")) <= float(spawn.get("price")):
		print("  damage FAIL")
		return false
	print("  spawn/proximity/damage PASS  %.2f > hurt %.2f > close %.2f" % [
		float(hurt.get("price")), float(spawn.get("price")), float(close.get("price"))
	])
	return true


func _test_kill_gain() -> bool:
	var spawn := _tick({"price": 100.0, "prev_p": 0.0, "prev_core": 20}, [_enemy(1.0, 0.0)], 20)
	var cleared := _tick(spawn, [], 20, 0.0)
	var killed := _tick(spawn, [], 20, float(_model().kill_gain(10.0)))
	if float(killed.get("price")) <= float(cleared.get("price")) + 0.001:
		print("  kill FAIL  no extra gain  clear=%.3f kill=%.3f" % [
			float(cleared.get("price")), float(killed.get("price"))
		])
		return false
	print("  kill gain PASS  %.2f vs clear %.2f" % [float(killed.get("price")), float(cleared.get("price"))])
	return true


func _test_perfect_wave_green() -> bool:
	var book = _book()
	var st := {"price": 100.0, "prev_p": 0.0, "prev_core": 20}
	book.start_candle(1, float(st.get("price")))
	var wave: Array = []
	for _i in 10:
		wave.append(_enemy(1.0, 0.0))
		st = _tick(st, wave, 20)
		book.sample(float(st.get("price")))
	var gain := float(_model().kill_gain(10.0))
	while wave.size() > 0:
		wave.pop_back()
		st = _tick(st, wave, 20, gain)
		book.sample(float(st.get("price")))
	var closed: Dictionary = book.close_live(float(st.get("price")))
	var change := float(closed.get("close")) - float(closed.get("open"))
	if change <= 0.0:
		print("  perfect FAIL  not green O=%.2f C=%.2f" % [
			float(closed.get("open")), float(closed.get("close"))
		])
		return false
	if change < 1.0 or change > 4.5:
		print("  perfect FAIL  gain out of band %.2f" % change)
		return false
	print("  perfect wave PASS  O=%.2f C=%.2f +%.2f" % [
		float(closed.get("open")), float(closed.get("close")), change
	])
	return true


func _test_leak_once() -> bool:
	var a := _tick({"price": 100.0, "prev_p": 0.0, "prev_core": 20}, [], 19)
	var b := _tick(a, [], 19)
	var drop := 100.0 - float(a.get("price"))
	if drop < 3.5 or drop > 4.5:
		print("  leak FAIL  first drop %.3f" % drop)
		return false
	if absf(float(b.get("price")) - float(a.get("price"))) > 0.0001:
		print("  leak FAIL  charged twice")
		return false
	print("  leak once PASS  drop=%.2f then stable" % drop)
	return true


func _test_candle_continuity() -> bool:
	var book = _book()
	book.start_candle(1, 100.0)
	book.sample(102.4)
	var c1: Dictionary = book.close_live(102.4)
	book.start_candle(2, float(c1.get("close")))
	if absf(float(book.live.get("open")) - float(c1.get("close"))) > 0.0001:
		print("  continuity FAIL  O2=%.4f C1=%.4f" % [
			float(book.live.get("open")), float(c1.get("close"))
		])
		return false
	print("  continuity PASS  C1=O2=%.2f" % float(c1.get("close")))
	return true


func _test_premarket_gap_down() -> bool:
	var book = _book()
	var st := {"price": 100.0, "prev_p": 0.0, "prev_core": 20}
	book.start_candle(1, 100.0)
	var c1: Dictionary = book.close_live(float(st.get("price")))
	st = _tick(st, [], 19)
	book.start_candle(2, float(st.get("price")))
	if float(book.live.get("open")) >= float(c1.get("close")) - 0.05:
		print("  gap down FAIL")
		return false
	print("  PRE-MARKET gap down PASS  C1=%.2f O2=%.2f" % [
		float(c1.get("close")), float(book.live.get("open"))
	])
	return true


func _test_premarket_gap_up() -> bool:
	var book = _book()
	var st := _tick({"price": 100.0, "prev_p": 0.0, "prev_core": 20}, [_enemy(1.0, 0.0)], 20)
	book.start_candle(1, float(st.get("price")))
	var c1: Dictionary = book.close_live(float(st.get("price")))
	st = _tick(st, [], 20, float(_model().kill_gain(10.0)))
	book.start_candle(2, float(st.get("price")))
	if float(book.live.get("open")) <= float(c1.get("close")) + 0.001:
		print("  gap up FAIL  C1=%.3f O2=%.3f" % [
			float(c1.get("close")), float(book.live.get("open"))
		])
		return false
	print("  PRE-MARKET gap up PASS  C1=%.2f O2=%.2f" % [
		float(c1.get("close")), float(book.live.get("open"))
	])
	return true


func _test_ohlc_immutable() -> bool:
	var book = _book()
	book.start_candle(1, 100.0)
	book.sample(90.0)
	var closed: Dictionary = book.close_live(95.0)
	book.sample(80.0)
	if absf(float(closed.get("close")) - 95.0) > 0.001:
		print("  immutable FAIL")
		return false
	print("  immutable PASS")
	return true


func _test_restore_no_jump() -> bool:
	var book = _book()
	book.start_candle(1, 103.4)
	book.sample(103.4)
	var cap: Dictionary = book.capture()
	cap["current_price"] = 103.4
	cap["previous_pressure"] = 2.5
	cap["previous_core_hp"] = 20
	var other = _book()
	other.restore(cap)
	if absf(float(other.live.get("close", 0.0)) - 103.4) > 0.001:
		print("  restore FAIL  live jumped")
		return false
	print("  restore PASS  price held 103.4")
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

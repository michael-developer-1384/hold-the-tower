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
	ok = _test_first_open_at_initial_price() and ok
	ok = _test_spawn_complete_keeps_live() and ok
	ok = _test_live_red_then_green() and ok
	ok = _test_candle_continuity() and ok
	ok = _test_pending_flush_before_rollover() and ok
	ok = _test_no_double_pending() and ok
	ok = _test_ohlc_immutable() and ok
	ok = _test_restore_live_premarket() and ok
	ok = _test_final_close_once() and ok
	ok = _test_lifecycle_source_contract() and ok
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
	book.open_candle(1, float(st.get("price")))
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
	if not book.has_live():
		print("  perfect FAIL  candle closed before session end")
		return false
	var closed: Dictionary = book.close_candle(float(st.get("price")))
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


func _test_first_open_at_initial_price() -> bool:
	var session := _make_session()
	if absf(session.current_price - 100.0) > 0.0001:
		print("  first open FAIL  session not 100")
		_free_session(session)
		return false
	session.rollover_to_wave(1)
	if not session.book.has_live():
		print("  first open FAIL  not live")
		_free_session(session)
		return false
	if absf(float(session.book.live.get("open")) - 100.0) > 0.0001:
		print("  first open FAIL  O=%.4f" % float(session.book.live.get("open")))
		_free_session(session)
		return false
	_free_session(session)
	print("  first open PASS  W1 O=100")
	return true


func _test_spawn_complete_keeps_live() -> bool:
	var book = _book()
	book.open_candle(1, 100.0)
	book.sample(94.0)
	if not book.has_live():
		print("  spawn-complete live FAIL")
		return false
	if book.candles.size() != 0:
		print("  spawn-complete FAIL  historical close too early")
		return false
	print("  spawn-complete keeps live PASS")
	return true


func _test_live_red_then_green() -> bool:
	var book = _book()
	book.open_candle(1, 100.0)
	book.sample(95.0)
	var red: Dictionary = book.live.duplicate(true)
	if float(red.get("close")) >= float(red.get("open")):
		print("  color FAIL  expected red")
		return false
	book.sample(102.0)
	var green: Dictionary = book.live.duplicate(true)
	if not book.has_live():
		print("  color FAIL  closed during recovery")
		return false
	if float(green.get("close")) < float(green.get("open")):
		print("  color FAIL  expected green")
		return false
	if int(green.get("wave")) != 1:
		print("  color FAIL  wave changed")
		return false
	print("  live red→green PASS")
	return true


func _test_candle_continuity() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	session.current_price = 104.0
	session.book.sample(104.0)
	session.rollover_to_wave(2)
	var hist: Dictionary = session.book.candles[0]
	var opened: Dictionary = session.book.live
	if absf(float(opened.get("open")) - float(hist.get("close"))) > 0.0:
		print("  continuity FAIL  O2=%.8f C1=%.8f" % [
			float(opened.get("open")), float(hist.get("close"))
		])
		_free_session(session)
		return false
	if float(opened.get("open")) != float(hist.get("close")):
		print("  continuity FAIL  not identical float")
		_free_session(session)
		return false
	_free_session(session)
	print("  continuity PASS  C1=O2=%.2f exactly" % float(hist.get("close")))
	return true


func _test_pending_flush_before_rollover() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	session.pending_realized_gain = 0.3
	session.rollover_to_wave(2)
	var closed: Dictionary = session.book.candles[0]
	if absf(float(closed.get("close")) - 100.3) > 0.0001:
		print("  pending flush FAIL  C1=%.4f" % float(closed.get("close")))
		_free_session(session)
		return false
	if absf(float(session.book.live.get("open")) - float(closed.get("close"))) > 0.0:
		print("  pending flush FAIL  open mismatch")
		_free_session(session)
		return false
	if absf(session.pending_realized_gain) > 0.0001:
		print("  pending flush FAIL  leftover pending")
		_free_session(session)
		return false
	_free_session(session)
	print("  pending flush PASS  kill gain closed into W1")
	return true


func _test_no_double_pending() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	session.pending_realized_gain = 0.3
	session.rollover_to_wave(2)
	var after_first := float(session.current_price)
	session.rollover_to_wave(3)
	if absf(session.current_price - after_first) > 0.0001:
		print("  double pending FAIL  %.4f -> %.4f" % [after_first, session.current_price])
		_free_session(session)
		return false
	_free_session(session)
	print("  no double pending PASS")
	return true


func _test_ohlc_immutable() -> bool:
	var book = _book()
	book.open_candle(1, 100.0)
	book.sample(90.0)
	var closed: Dictionary = book.close_candle(95.0)
	book.sample(80.0)
	if absf(float(closed.get("close")) - 95.0) > 0.001:
		print("  immutable FAIL")
		return false
	if book.has_live():
		print("  immutable FAIL  still live")
		return false
	print("  immutable PASS")
	return true


func _test_restore_live_premarket() -> bool:
	var session := _make_session()
	session.rollover_to_wave(2)
	session.current_price = 97.5
	session.book.sample(97.5)
	var cap: Dictionary = session.capture()
	_free_session(session)
	var other := _make_session()
	other.restore(cap)
	if not other.book.has_live():
		print("  restore FAIL  live candle lost")
		_free_session(other)
		return false
	if int(other.book.live.get("wave")) != 2:
		print("  restore FAIL  wave")
		_free_session(other)
		return false
	if absf(other.current_price - 97.5) > 0.001:
		print("  restore FAIL  price jumped")
		_free_session(other)
		return false
	_free_session(other)
	print("  restore live PRE-MARKET PASS")
	return true


func _test_final_close_once() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	session.pending_realized_gain = 0.3
	session.close_run_candle()
	if session.book.has_live():
		print("  final close FAIL  still live")
		_free_session(session)
		return false
	if session.book.candles.size() != 1:
		print("  final close FAIL  count=%d" % session.book.candles.size())
		_free_session(session)
		return false
	session.close_run_candle()
	if session.book.candles.size() != 1:
		print("  final close FAIL  closed twice")
		_free_session(session)
		return false
	if absf(float(session.book.candles[0].get("close")) - 100.3) > 0.0001:
		print("  final close FAIL  missed last gain")
		_free_session(session)
		return false
	_free_session(session)
	print("  final close once PASS")
	return true


func _test_lifecycle_source_contract() -> bool:
	var gm := FileAccess.get_file_as_string("res://scripts/game_manager.gd")
	var spawn_i := gm.find("func _on_wave_spawn_finished")
	var spawn_n := gm.find("\nfunc ", spawn_i + 8)
	var spawn_body := gm.substr(spawn_i, spawn_n - spawn_i)
	if spawn_body.contains("close_wave_candle") or spawn_body.contains("close_run_candle") or spawn_body.contains("rollover_to_wave"):
		print("  contract FAIL  spawn_finished still owns candles")
		return false
	if not gm.contains("rollover_to_wave"):
		print("  contract FAIL  missing rollover_to_wave")
		return false
	if not gm.contains("close_run_candle"):
		print("  contract FAIL  missing close_run_candle")
		return false
	print("  lifecycle source contract PASS")
	return true


func _make_session() -> Node:
	var game := _DummyGame.new()
	var session: Node = load("res://scripts/market/hodl_market_session.gd").new()
	session.set_meta("dummy_game", game)
	session.setup(game, null, null, null)
	return session


func _free_session(session: Node) -> void:
	if session == null:
		return
	var game: Node = session.get_meta("dummy_game") if session.has_meta("dummy_game") else null
	session.free()
	if game != null and is_instance_valid(game):
		game.free()


class _DummyGame extends Node:
	var core_hp: int = 20
	var timeline_previewing: bool = false
	var game_over: bool = false
	var level_complete: bool = false


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

extends SceneTree

## Directional HODL combat flows, candle continuity, restore, pause.
## godot --headless --path . --script res://scripts/tools/validate_hodl_index.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	print("validate_hodl_index: starting")
	var ok := true
	ok = _test_idle() and ok
	ok = _test_spawn_proximity_damage() and ok
	ok = _test_untouched_never_bullish() and ok
	ok = _test_stationary_flat() and ok
	ok = _test_kill_gain() and ok
	ok = _test_perfect_wave_green() and ok
	ok = _test_leak_once() and ok
	ok = _test_leak_no_removal_rally() and ok
	ok = _test_spawn_normalized() and ok
	ok = _test_first_open_at_initial_price() and ok
	ok = _test_spawn_complete_keeps_live() and ok
	ok = _test_live_red_then_green() and ok
	ok = _test_candle_continuity() and ok
	ok = _test_pending_flush_before_rollover() and ok
	ok = _test_no_double_pending() and ok
	ok = _test_ohlc_immutable() and ok
	ok = _test_empty_premarket_flat() and ok
	ok = _test_restore_live_premarket() and ok
	ok = _test_restore_baselines() and ok
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


func _px(session: Node) -> float:
	return float(session.get("current_price"))


func _test_idle() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	var a := _px(session)
	session.call("_flush_market_state")
	session.call("_flush_market_state")
	if absf(session.current_price - a) > 0.0001:
		print("  idle FAIL  drifted to %.4f" % session.current_price)
		_free_session(session)
		return false
	_free_session(session)
	print("  idle PASS  price=100.00")
	return true


func _test_spawn_proximity_damage() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	var enemy := _spawn_enemy(session)
	session.call("_flush_market_state")
	var spawn_px := _px(session)
	if spawn_px >= 99.99:
		print("  spawn FAIL  price=%.3f" % spawn_px)
		_free_session(session)
		return false
	enemy.progress = 1.0
	session.call("_flush_market_state")
	var close_px := _px(session)
	if close_px >= spawn_px:
		print("  proximity FAIL")
		_free_session(session)
		return false
	_free_session(session)
	var other := _make_session()
	other.rollover_to_wave(1)
	var hurt := _spawn_enemy(other)
	other.call("_flush_market_state")
	var after_spawn := _px(other)
	hurt.health = 40.0
	other.call("_flush_market_state")
	if other.current_price <= after_spawn:
		print("  damage FAIL")
		_free_session(other)
		return false
	print("  spawn/proximity/damage PASS  hurt %.2f > spawn %.2f > close %.2f" % [
		other.current_price, spawn_px, close_px
	])
	_free_session(other)
	return true


func _test_untouched_never_bullish() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	var enemy := _spawn_enemy(session)
	session.call("_flush_market_state")
	var prev := _px(session)
	for step in 10:
		enemy.progress = float(step + 1) / 10.0
		session.call("_flush_market_state")
		if session.current_price > prev + 0.0000001:
			print("  untouched FAIL  bullish at p=%.2f  %.4f -> %.4f" % [
				enemy.progress, prev, session.current_price
			])
			_free_session(session)
			return false
		prev = session.current_price
	_free_session(session)
	print("  untouched never bullish PASS")
	return true


func _test_stationary_flat() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	var enemy := _spawn_enemy(session)
	session.call("_flush_market_state")
	var after_spawn := _px(session)
	enemy.progress = 0.0
	session.call("_flush_market_state")
	session.call("_flush_market_state")
	if absf(session.current_price - after_spawn) > 0.0001:
		print("  stationary FAIL  %.4f -> %.4f" % [after_spawn, session.current_price])
		_free_session(session)
		return false
	_free_session(session)
	print("  stationary PASS")
	return true


func _test_kill_gain() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	var enemy := _spawn_enemy(session)
	session.call("_flush_market_state")
	var spawn_px := _px(session)
	enemy.kill()
	session.call("_flush_market_state")
	var killed := _px(session)
	_free_session(session)
	var other := _make_session()
	other.rollover_to_wave(1)
	var leftover := _spawn_enemy(other)
	other.call("_flush_market_state")
	leftover.health = 0.0
	leftover._alive = false
	other.call("_flush_market_state")
	var cleared_no_kill := _px(other)
	if killed <= cleared_no_kill + 0.001:
		print("  kill FAIL  no extra gain  clear=%.3f kill=%.3f" % [cleared_no_kill, killed])
		_free_session(other)
		return false
	if killed <= spawn_px:
		print("  kill FAIL  no recovery  spawn=%.3f kill=%.3f" % [spawn_px, killed])
		_free_session(other)
		return false
	_free_session(other)
	print("  kill gain PASS  %.2f vs vanish %.2f" % [killed, cleared_no_kill])
	return true


func _test_perfect_wave_green() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	var pack: Array = []
	for _i in 10:
		pack.append(_spawn_enemy(session))
	session.call("_flush_market_state")
	for enemy in pack:
		enemy.kill()
	session.call("_flush_market_state")
	if not session.book.has_live():
		print("  perfect FAIL  candle closed before session end")
		_free_session(session)
		return false
	var closed: Dictionary = session.book.close_candle(session.current_price)
	var change := float(closed.get("close")) - float(closed.get("open"))
	if change <= 0.0:
		print("  perfect FAIL  not green O=%.2f C=%.2f" % [
			float(closed.get("open")), float(closed.get("close"))
		])
		_free_session(session)
		return false
	if change < 1.0 or change > 4.5:
		print("  perfect FAIL  gain out of band %.2f" % change)
		_free_session(session)
		return false
	print("  perfect wave PASS  O=%.2f C=%.2f +%.2f" % [
		float(closed.get("open")), float(closed.get("close")), change
	])
	_free_session(session)
	return true


func _test_leak_once() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	session.get_meta("dummy_game").core_hp = 19
	session.call("_flush_market_state")
	var after := _px(session)
	var drop := 100.0 - after
	if drop < 3.5 or drop > 4.5:
		print("  leak FAIL  first drop %.3f" % drop)
		_free_session(session)
		return false
	session.call("_flush_market_state")
	if absf(session.current_price - after) > 0.0001:
		print("  leak FAIL  charged twice")
		_free_session(session)
		return false
	_free_session(session)
	print("  leak once PASS  drop=%.2f then stable" % drop)
	return true


func _test_leak_no_removal_rally() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	var enemy := _spawn_enemy(session)
	session.call("_flush_market_state")
	enemy.progress = 0.95
	session.call("_flush_market_state")
	var before := _px(session)
	enemy.leak()
	session.get_meta("dummy_game").core_hp = 19
	session.call("_flush_market_state")
	if session.current_price >= before:
		print("  leak rally FAIL  %.4f -> %.4f" % [before, session.current_price])
		_free_session(session)
		return false
	if session.last_kill_gain > 0.0001:
		print("  leak rally FAIL  kill gain on leak")
		_free_session(session)
		return false
	if session.last_core_loss < 3.5:
		print("  leak rally FAIL  missing core loss")
		_free_session(session)
		return false
	_free_session(session)
	print("  leak no removal rally PASS")
	return true


func _test_spawn_normalized() -> bool:
	var ten := _make_session()
	ten._expected_wave_count = 10.0
	ten.rollover_to_wave(1)
	ten._expected_wave_count = 10.0
	_spawn_enemy(ten)
	ten.call("_flush_market_state")
	var drop10 := 100.0 - _px(ten)
	_free_session(ten)
	var thirty := _make_session()
	thirty.rollover_to_wave(1)
	thirty._expected_wave_count = 30.0
	_spawn_enemy(thirty)
	thirty.call("_flush_market_state")
	var drop30 := 100.0 - _px(thirty)
	_free_session(thirty)
	if absf(drop10 * 10.0 - drop30 * 30.0) > 0.05:
		print("  spawn normalize FAIL  10=%.4f 30=%.4f" % [drop10, drop30])
		return false
	print("  spawn normalized PASS")
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
	var after_first := _px(session)
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


func _test_empty_premarket_flat() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	var enemy := _spawn_enemy(session)
	session.call("_flush_market_state")
	enemy.kill()
	session.call("_flush_market_state")
	var settled := _px(session)
	for _i in 12:
		session.call("_flush_market_state")
	if absf(session.current_price - settled) > 0.0:
		print("  empty PRE-MARKET FAIL  drifted %.8f -> %.8f" % [settled, session.current_price])
		_free_session(session)
		return false
	_free_session(session)
	print("  empty PRE-MARKET PASS")
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


func _test_restore_baselines() -> bool:
	var session := _make_session()
	session.rollover_to_wave(1)
	var enemy := _spawn_enemy(session)
	session.call("_flush_market_state")
	enemy.progress = 0.7
	enemy.health = 40.0
	session.call("_flush_market_state")
	var cap: Dictionary = session.capture()
	var price := _px(session)
	var other := _make_session()
	var restored_enemy := _spawn_enemy(other)
	restored_enemy.progress = 0.7
	restored_enemy.health = 40.0
	other.restore(cap)
	other.call("_flush_market_state")
	if absf(other.current_price - price) > 0.0001:
		print("  restore baseline FAIL  %.4f -> %.4f" % [price, other.current_price])
		_free_session(session)
		_free_session(other)
		return false
	_free_session(session)
	_free_session(other)
	print("  restore baselines PASS")
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
	var start_i := gm.find("func start_next_wave")
	var start_n := gm.find("\nfunc ", start_i + 8)
	var start_body := gm.substr(start_i, start_n - start_i)
	var rollover_i := start_body.find("rollover_to_wave")
	var enqueue_i := start_body.find("enqueue_wave")
	if rollover_i < 0 or enqueue_i < 0 or rollover_i > enqueue_i:
		print("  contract FAIL  rollover must precede enqueue_wave")
		return false
	if not gm.contains("close_run_candle"):
		print("  contract FAIL  missing close_run_candle")
		return false
	print("  lifecycle source contract PASS")
	return true


func _make_session() -> Node:
	var game := _DummyGame.new()
	var waves := _DummyWaves.new()
	game.add_child(waves)
	root.add_child(game)
	var session: Node = load("res://scripts/market/hodl_market_session.gd").new()
	session.set_meta("dummy_game", game)
	session.set_meta("dummy_waves", waves)
	session.setup(game, waves, null, null)
	return session


func _spawn_enemy(session: Node) -> _DummyEnemy:
	var game: Node = session.get_meta("dummy_game")
	var waves: Node = session.get_meta("dummy_waves")
	var enemy := _DummyEnemy.new()
	game.add_child(enemy)
	enemy.add_to_group("enemies")
	waves.spawn(enemy)
	return enemy


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


class _DummyWaves extends Node:
	signal enemy_spawned(enemy: Node3D)

	func spawn(enemy: Node3D) -> void:
		enemy_spawned.emit(enemy)


class _DummyEnemy extends Node3D:
	signal died(enemy: Node3D)
	signal reached_core(enemy: Node3D)

	var health: float = 100.0
	var max_health: float = 100.0
	var progress: float = 0.0
	var _alive: bool = true

	func is_alive() -> bool:
		return _alive

	func get_normalized_path_progress() -> float:
		return progress

	func kill() -> void:
		health = 0.0
		_alive = false
		died.emit(self)

	func leak() -> void:
		progress = 1.0
		_alive = false
		reached_core.emit(self)


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

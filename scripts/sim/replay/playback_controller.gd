extends Node

## Watch playback: pause, speed, seek, event/tick steps. Agent never re-decides.

signal time_changed(sim_time: float)
signal playing_changed(playing: bool)
signal speed_changed(speed: float)
signal finished

const SPEEDS: Array = [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 40.0]
const AUDIO_MUTE_ABOVE := 2.0

var sim = null
var package: Dictionary = {}
var playing: bool = false
var speed: float = 1.0
var audio_override: int = 0 # -1 mute, 0 auto, 1 force on
var duration: float = 0.0
var _speed_applied: bool = false
var _dragging: bool = false
var _preview_t: float = -1.0


func bind(p_sim, pkg: Dictionary) -> void:
	sim = p_sim
	package = pkg
	duration = float(pkg.get("metrics", {}).get("duration", 0.0))
	if duration <= 0.0 and sim != null and sim.clock:
		duration = maxf(sim.clock.sim_time, 1.0)
	_set_always_process()


func play() -> void:
	if sim == null:
		return
	playing = true
	get_tree().paused = false
	_apply_speed()
	_apply_audio()
	playing_changed.emit(true)


func pause() -> void:
	playing = false
	get_tree().paused = true
	playing_changed.emit(false)


func toggle() -> void:
	if playing:
		pause()
	else:
		play()


func set_speed(v: float) -> void:
	speed = maxf(v, 0.01)
	if playing:
		_apply_speed()
	_apply_audio()
	speed_changed.emit(speed)


func cycle_speed() -> void:
	var idx := 0
	var best := 999.0
	for i in SPEEDS.size():
		var d := absf(float(SPEEDS[i]) - speed)
		if d < best:
			best = d
			idx = i
	set_speed(float(SPEEDS[(idx + 1) % SPEEDS.size()]))


func set_max_speed() -> void:
	set_speed(40.0)


func set_audio_override(mode: int) -> void:
	audio_override = mode
	_apply_audio()


func begin_scrub() -> void:
	_dragging = true
	if playing:
		pause()


func preview_scrub(t: float) -> void:
	if sim == null:
		return
	_preview_t = t
	var Seek = load("res://scripts/sim/replay/replay_seek.gd")
	Seek.apply_seek(sim, package, t)
	time_changed.emit(_current_sim_time() if sim.clock else t)


func end_scrub(t: float) -> void:
	_dragging = false
	await seek_exact(t)


func seek_exact(target: float) -> void:
	if sim == null:
		return
	var was_playing := playing
	pause()
	var Seek = load("res://scripts/sim/replay/replay_seek.gd")
	var t0: float = Seek.apply_seek(sim, package, target)
	get_tree().paused = false
	await Seek.tick_toward(get_tree(), sim, maxf(target, t0))
	get_tree().paused = true
	time_changed.emit(_current_sim_time() if sim.clock else target)
	if was_playing:
		play()


func step_ticks(count: int) -> void:
	if sim == null:
		return
	var was := playing
	pause()
	get_tree().paused = false
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	for _i in count:
		if sim.is_finished():
			break
		sim.replay_due_actions()
		await get_tree().physics_frame
		sim.clock.step(SimRunner.STEP)
		if sim.has_method("after_tick"):
			sim.after_tick()
	get_tree().paused = true
	time_changed.emit(sim.clock.sim_time)
	if was:
		play()


func step_seconds(seconds: float) -> void:
	await seek_exact(_current_sim_time() + seconds)


func jump_event(delta: int) -> void:
	if sim == null:
		return
	var now: float = _current_sim_time()
	var events: Array = package.get("event_log", [])
	var times: Array = []
	for e in events:
		var ev: Dictionary = e
		var et: float = float(ev.get("time", 0.0))
		if times.is_empty() or absf(float(times[times.size() - 1]) - et) > 0.01:
			times.append(et)
	if times.is_empty():
		return
	var idx: int = 0
	for i in times.size():
		if float(times[i]) <= now + 0.02:
			idx = i
	idx = clampi(idx + delta, 0, times.size() - 1)
	await seek_exact(float(times[idx]))


func _current_sim_time() -> float:
	if sim == null or sim.clock == null:
		return 0.0
	return float(sim.clock.sim_time)


func shutdown() -> void:
	playing = false
	if _speed_applied:
		load("res://scripts/sim/sim_runner.gd").restore()
		_speed_applied = false
	get_tree().paused = false
	load("res://scripts/app/audio_bridge.gd").set_suppressed(false)


func _physics_process(_delta: float) -> void:
	if not playing or sim == null or _dragging:
		return
	if sim.is_finished():
		playing = false
		playing_changed.emit(false)
		finished.emit()
		time_changed.emit(_current_sim_time() if sim.clock else duration)
		return
	sim.replay_due_actions()
	if sim.clock:
		sim.clock.step(1.0 / 60.0)
	if sim.has_method("after_tick"):
		sim.after_tick()
	time_changed.emit(_current_sim_time())


func _apply_speed() -> void:
	var SimRunner = load("res://scripts/sim/sim_runner.gd")
	if _speed_applied:
		SimRunner.restore()
		_speed_applied = false
	SimRunner.apply_speed(speed)
	_speed_applied = true


func _apply_audio() -> void:
	var mute := false
	if audio_override < 0:
		mute = true
	elif audio_override > 0:
		mute = false
	else:
		mute = speed > AUDIO_MUTE_ABOVE
	load("res://scripts/app/audio_bridge.gd").set_suppressed(mute)


func _set_always_process() -> void:
	if sim == null or sim.root == null:
		return
	for path in ["CameraRig", "SelectionManager"]:
		var n: Node = sim.root.get_node_or_null(path)
		if n != null:
			n.process_mode = Node.PROCESS_MODE_ALWAYS
	process_mode = Node.PROCESS_MODE_ALWAYS

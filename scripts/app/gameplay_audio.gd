extends Node

## Central gameplay SFX. Bus: SFX. Never drives game logic.

const CatalogScript := preload("res://scripts/app/gameplay_audio_catalog.gd")
const BUS_SFX := "SFX"
const META_EVENT_ID := "event_id"

var _suppressed: bool = false
var _streams: Dictionary = {} # event_id -> AudioStream
var _active_3d: Dictionary = {} # event_id -> Array[AudioStreamPlayer3D]
var _active_global: Dictionary = {} # event_id -> Array[AudioStreamPlayer]
var _pool_3d: Array = []
var _pool_global: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus()
	for id in CatalogScript.all().keys():
		var ev: Dictionary = CatalogScript.get_event(id)
		var path := str(ev.get("path", ""))
		if ResourceLoader.exists(path):
			_streams[id] = load(path)


func set_suppressed(suppressed: bool) -> void:
	_suppressed = suppressed


func is_suppressed() -> bool:
	return _suppressed


func stop_all() -> void:
	for id in _active_3d.keys():
		for p in _active_3d[id]:
			if is_instance_valid(p):
				p.stop()
				_recycle_3d(p)
		_active_3d[id] = []
	for id in _active_global.keys():
		for p in _active_global[id]:
			if is_instance_valid(p):
				p.stop()
				_recycle_global(p)
		_active_global[id] = []


func play_3d(event_id: String, world_position: Vector3) -> void:
	if _suppressed:
		return
	var ev: Dictionary = CatalogScript.get_event(event_id)
	if ev.is_empty() or int(ev.get("kind", 0)) != CatalogScript.Kind.SPATIAL:
		return
	if not _streams.has(event_id):
		return
	_trim_voices(event_id, int(ev.get("max_voices", 6)), true)
	var player := _acquire_3d()
	player.stream = _streams[event_id]
	player.volume_db = float(ev.get("volume_db", -8.0))
	player.pitch_scale = _pitch(float(ev.get("pitch_variance", 0.0)))
	player.max_distance = float(ev.get("max_distance", 18.0))
	player.unit_size = float(ev.get("unit_size", 2.5))
	player.bus = BUS_SFX
	player.global_position = world_position
	player.set_meta(META_EVENT_ID, event_id)
	if not _active_3d.has(event_id):
		_active_3d[event_id] = []
	(_active_3d[event_id] as Array).append(player)
	player.play()


func play_global(event_id: String) -> void:
	if _suppressed:
		return
	var ev: Dictionary = CatalogScript.get_event(event_id)
	if ev.is_empty() or int(ev.get("kind", 0)) != CatalogScript.Kind.GLOBAL:
		return
	if not _streams.has(event_id):
		return
	_trim_voices(event_id, int(ev.get("max_voices", 2)), false)
	var player := _acquire_global()
	player.stream = _streams[event_id]
	player.volume_db = float(ev.get("volume_db", -6.0))
	player.pitch_scale = _pitch(float(ev.get("pitch_variance", 0.0)))
	player.bus = BUS_SFX
	player.set_meta(META_EVENT_ID, event_id)
	if not _active_global.has(event_id):
		_active_global[event_id] = []
	(_active_global[event_id] as Array).append(player)
	player.play()


func _pitch(variance: float) -> float:
	if variance <= 0.0:
		return 1.0
	return 1.0 + randf_range(-variance, variance)


func _trim_voices(event_id: String, max_voices: int, spatial: bool) -> void:
	var list: Array = _active_3d.get(event_id, []) if spatial else _active_global.get(event_id, [])
	while list.size() >= max_voices:
		var oldest = list.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.stop()
			if spatial:
				_recycle_3d(oldest)
			else:
				_recycle_global(oldest)
	if spatial:
		_active_3d[event_id] = list
	else:
		_active_global[event_id] = list


func _acquire_3d() -> AudioStreamPlayer3D:
	var scene := get_tree().current_scene
	while not _pool_3d.is_empty():
		var p = _pool_3d.pop_back()
		if p != null and is_instance_valid(p):
			if p.get_parent() != scene and scene != null:
				if p.get_parent() != null:
					p.get_parent().remove_child(p)
				scene.add_child(p)
			return p
	var player := AudioStreamPlayer3D.new()
	player.max_polyphony = 1
	player.finished.connect(_on_3d_finished.bind(player))
	if scene != null:
		scene.add_child(player)
	else:
		add_child(player)
	return player


func _acquire_global() -> AudioStreamPlayer:
	while not _pool_global.is_empty():
		var p = _pool_global.pop_back()
		if p != null and is_instance_valid(p):
			return p
	var player := AudioStreamPlayer.new()
	player.finished.connect(_on_global_finished.bind(player))
	add_child(player)
	return player


func _recycle_3d(player: AudioStreamPlayer3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	if _pool_3d.has(player):
		return
	if _pool_3d.size() < 24:
		_pool_3d.append(player)
	else:
		player.queue_free()


func _recycle_global(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player):
		return
	if _pool_global.has(player):
		return
	if _pool_global.size() < 8:
		_pool_global.append(player)
	else:
		player.queue_free()


func _on_3d_finished(player: AudioStreamPlayer3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	var event_id := str(player.get_meta(META_EVENT_ID, ""))
	if not event_id.is_empty():
		var list: Array = _active_3d.get(event_id, [])
		list.erase(player)
		_active_3d[event_id] = list
	_recycle_3d(player)


func _on_global_finished(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player):
		return
	var event_id := str(player.get_meta(META_EVENT_ID, ""))
	if not event_id.is_empty():
		var list: Array = _active_global.get(event_id, [])
		list.erase(player)
		_active_global[event_id] = list
	_recycle_global(player)


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_SFX) < 0:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, "Master")

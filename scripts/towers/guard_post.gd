extends Node3D

signal tower_clicked(tower: Node3D)
signal tower_hovered(tower: Node3D, hovered: bool)

const GuardScript := preload("res://scripts/towers/guard.gd")
const GuardVisualScene := preload("res://scenes/towers/visuals/guard_visual.tscn")
const RESPAWN_SECONDS := 8.0
const GUARD_MAX_HP := 100.0
const HEALING_RATE := 10.0

@export var floor_radius: float = 2.5
@export var guard_count: int = 2
@export var guard_damage: float = 20.0
@export var attack_interval: float = 0.8
@export var respawn_time: float = RESPAWN_SECONDS
@export var guard_max_hp: float = GUARD_MAX_HP
@export var healing_rate: float = HEALING_RATE
@export var healing_delay: float = 2.0

var runtime_id: String = ""
var tower_type: String = "guard_post"
var level: int = 1
var floor_id: String = ""
var floor_index: int = 0
var build_spot_id: String = ""
var selected: bool = false
var blueprint_id: String = ""
var resolved_stats: Dictionary = {}
var gold_invested: int = 0

var shots_fired: int = 0 # guard attacks
var hits: int = 0
var damage_dealt: float = 0.0
var kills: int = 0
var same_floor_damage: float = 0.0
var cross_floor_damage: float = 0.0
var damage_by_target_floor: Dictionary = {}
var guard_attacks: int = 0
var guard_returns: int = 0

var enemies_blocked: int = 0
var total_block_time_ms: int = 0
var guards_died: int = 0
var guards_respawned: int = 0
var guard_damage_taken: float = 0.0
var guard_healing_done: float = 0.0
var peak_simultaneous_blocks: int = 0

var _range_origin: Marker3D
var _pick_body: StaticBody3D
var _guards: Array = [] # slot_index -> Guard or null
var _respawn_timers: Array = [] # float seconds remaining; 0 = ready/alive
var _home_offsets: Array = [
	Vector3(-0.55, 0.0, 0.15),
	Vector3(0.55, 0.0, 0.15),
]
var _guards_root: Node3D


func _ready() -> void:
	add_to_group("towers")
	_hide_preview_guards()
	_ensure_range_origin()
	_ensure_pick_body()
	_ensure_guards_root()


func _process(delta: float) -> void:
	_tick_respawns(delta)
	_update_peak_blocks()


func get_range_origin() -> Vector3:
	_ensure_range_origin()
	return _range_origin.global_position


func get_range_origin_node() -> Node3D:
	_ensure_range_origin()
	return _range_origin


func get_range_shape() -> String:
	return "FLOOR_DISC"


func get_range_value() -> float:
	return floor_radius


func get_guards() -> Array:
	var out: Array = []
	for g in _guards:
		if g != null and is_instance_valid(g):
			out.append(g)
	return out


func get_disc_radius() -> float:
	return floor_radius


func get_floor_id() -> String:
	return floor_id


func get_alive_guard_count() -> int:
	var n := 0
	for g in _guards:
		if g != null and is_instance_valid(g) and g.has_method("is_alive") and bool(g.call("is_alive")):
			n += 1
	return n


func get_next_respawn_eta() -> float:
	var best := INF
	for t in _respawn_timers:
		var remaining := float(t)
		if remaining > 0.0 and remaining < best:
			best = remaining
	if best == INF:
		return 0.0
	return best


func get_ui_stat_lines() -> PackedStringArray:
	var alive := get_alive_guard_count()
	var lines := PackedStringArray([
		"Guards %d / %d" % [alive, guard_count],
		"HP %s" % get_guard_hp_summary(),
		"Damage %.0f" % guard_damage,
		"Attack %.1fs" % attack_interval,
		"Radius %.1f" % get_range_value(),
	])
	var respawn_eta := get_next_respawn_eta()
	if respawn_eta > 0.0:
		lines.append("Respawning %.0fs" % ceil(respawn_eta))
	return lines


func can_in_run_upgrade() -> bool:
	return false


func get_guard_hp_summary() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i in guard_count:
		if i < _guards.size() and _guards[i] != null and is_instance_valid(_guards[i]):
			var g = _guards[i]
			parts.append("%d/%d" % [int(round(float(g.get("health")))), int(round(float(g.get("max_health"))))])
		elif i < _respawn_timers.size() and float(_respawn_timers[i]) > 0.0:
			parts.append("dead")
		else:
			parts.append("--")
	return ", ".join(parts)


## Untyped so callers can safely pass potentially freed refs.
func is_enemy_in_range(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not (enemy is Node3D):
		return false
	var node := enemy as Node3D
	var enemy_floor := ""
	if node.has_method("get_current_floor_id"):
		enemy_floor = str(node.call("get_current_floor_id"))
	elif "floor_id" in node:
		enemy_floor = str(node.get("floor_id"))
	if enemy_floor != floor_id:
		return false
	var origin := get_range_origin()
	var dist := Vector2(
		node.global_position.x - origin.x,
		node.global_position.z - origin.z
	).length()
	return dist <= floor_radius


func configure_built(
	p_runtime_id: String,
	def: Resource,
	p_floor_id: String,
	p_floor_index: int,
	p_spot_id: String,
	resolved: Dictionary = {}
) -> void:
	runtime_id = p_runtime_id
	tower_type = str(def.tower_id) if def else "guard_post"
	floor_id = p_floor_id
	floor_index = p_floor_index
	build_spot_id = p_spot_id
	level = 1
	resolved_stats = resolved.duplicate(true) if not resolved.is_empty() else {}
	blueprint_id = str(resolved_stats.get("blueprint_id", ""))
	if resolved_stats.is_empty():
		floor_radius = float(def.base_range) if def else 2.5
		guard_damage = float(def.base_damage) if def else 20.0
		attack_interval = float(def.base_fire_interval) if def else 0.8
		guard_max_hp = GUARD_MAX_HP
		healing_rate = HEALING_RATE
		healing_delay = 2.0
		respawn_time = RESPAWN_SECONDS
	else:
		floor_radius = float(resolved_stats.get("defense_radius", def.base_range if def else 2.5))
		guard_damage = float(resolved_stats.get("guard_damage", def.base_damage if def else 20.0))
		attack_interval = float(resolved_stats.get("guard_attack_interval", def.base_fire_interval if def else 0.8))
		guard_max_hp = float(resolved_stats.get("guard_hp", GUARD_MAX_HP))
		healing_rate = float(resolved_stats.get("healing_rate", HEALING_RATE))
		healing_delay = float(resolved_stats.get("healing_delay", 2.0))
		respawn_time = float(resolved_stats.get("respawn_time", RESPAWN_SECONDS))
		guard_count = int(resolved_stats.get("guard_count", 2))
	set_meta("floor_index", floor_index)
	set_meta("floor_id", floor_id)
	_ensure_range_origin()
	_ensure_pick_body()
	_spawn_guards()


func set_selected(value: bool) -> void:
	selected = value
	var base := get_node_or_null("Base")
	if base:
		base.scale = Vector3.ONE * (1.08 if selected else 1.0)


func record_shot() -> void:
	shots_fired += 1
	guard_attacks += 1


func record_hit(amount: float, target_floor_id: String, target_floor_index: int) -> void:
	hits += 1
	damage_dealt += amount
	if not damage_by_target_floor.has(target_floor_id):
		damage_by_target_floor[target_floor_id] = 0.0
	damage_by_target_floor[target_floor_id] = float(damage_by_target_floor[target_floor_id]) + amount
	if target_floor_index == floor_index:
		same_floor_damage += amount
	else:
		cross_floor_damage += amount


func record_kill() -> void:
	kills += 1


func record_guard_return() -> void:
	guard_returns += 1


func record_block_start() -> void:
	enemies_blocked += 1
	_update_peak_blocks()


func record_block_end(elapsed_ms: int) -> void:
	total_block_time_ms += maxi(elapsed_ms, 0)


func _update_peak_blocks() -> void:
	var n := 0
	for g in _guards:
		if g != null and is_instance_valid(g) and g.has_method("is_engaged") and bool(g.call("is_engaged")):
			n += 1
	peak_simultaneous_blocks = maxi(peak_simultaneous_blocks, n)


func record_guard_damage_taken(amount: float) -> void:
	if amount > 0.0:
		guard_damage_taken += amount


func record_guard_healing_done(amount: float) -> void:
	if amount > 0.0:
		guard_healing_done += amount


func on_guard_died(slot_index: int) -> void:
	guards_died += 1
	if slot_index >= 0 and slot_index < _guards.size():
		_guards[slot_index] = null
	if slot_index >= 0 and slot_index < _respawn_timers.size():
		_respawn_timers[slot_index] = respawn_time
	_log_telemetry("guard_died", {
		"tower_runtime_id": runtime_id,
		"slot_index": slot_index,
		"respawn_s": respawn_time,
	})


func _tick_respawns(delta: float) -> void:
	for i in _respawn_timers.size():
		var remaining := float(_respawn_timers[i])
		if remaining <= 0.0:
			continue
		remaining = maxf(remaining - delta, 0.0)
		_respawn_timers[i] = remaining
		if remaining <= 0.0:
			_spawn_guard_slot(i)
			guards_respawned += 1
			_log_telemetry("guard_respawned", {
				"tower_runtime_id": runtime_id,
				"slot_index": i,
			})


func _spawn_guards() -> void:
	_ensure_guards_root()
	for g in _guards:
		if g != null and is_instance_valid(g):
			g.queue_free()
	_guards.clear()
	_respawn_timers.clear()
	for i in guard_count:
		_guards.append(null)
		_respawn_timers.append(0.0)
		_spawn_guard_slot(i)


func _spawn_guard_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= guard_count:
		return
	if slot_index < _guards.size() and _guards[slot_index] != null and is_instance_valid(_guards[slot_index]):
		return
	_ensure_guards_root()
	var offset: Vector3 = _home_offsets[slot_index] if slot_index < _home_offsets.size() else Vector3.ZERO
	var guard := Node3D.new()
	guard.name = "Guard_%d" % (slot_index + 1)
	guard.set_script(GuardScript)
	guard.set("max_health", guard_max_hp)
	guard.set("melee_damage", guard_damage)
	guard.set("melee_interval", attack_interval)
	guard.set("healing_rate", healing_rate)
	guard.set("healing_delay", healing_delay)
	_guards_root.add_child(guard)
	var visual := GuardVisualScene.instantiate()
	visual.name = "Visual"
	guard.add_child(visual)
	guard.call("setup", offset, self, slot_index)
	while _guards.size() <= slot_index:
		_guards.append(null)
	while _respawn_timers.size() <= slot_index:
		_respawn_timers.append(0.0)
	_guards[slot_index] = guard
	_respawn_timers[slot_index] = 0.0


func _hide_preview_guards() -> void:
	var visual := get_node_or_null("Visual")
	if visual == null:
		return
	for child_name in ["GuardA", "GuardB"]:
		var n := visual.get_node_or_null(child_name)
		if n != null:
			n.visible = false


func _log_telemetry(event_name: String, data: Dictionary) -> void:
	if not is_inside_tree():
		return
	var telemetry := get_tree().root.find_child("TelemetryManager", true, false)
	if telemetry != null and telemetry.has_method("log_event"):
		telemetry.call("log_event", event_name, data)


func _ensure_guards_root() -> void:
	if _guards_root != null and is_instance_valid(_guards_root):
		return
	_guards_root = get_node_or_null("Guards") as Node3D
	if _guards_root == null:
		_guards_root = Node3D.new()
		_guards_root.name = "Guards"
		add_child(_guards_root)


func _ensure_range_origin() -> void:
	if _range_origin != null and is_instance_valid(_range_origin):
		return
	_range_origin = get_node_or_null("RangeOrigin") as Marker3D
	if _range_origin != null:
		return
	_range_origin = Marker3D.new()
	_range_origin.name = "RangeOrigin"
	_range_origin.position = Vector3(0.0, 0.05, 0.0)
	add_child(_range_origin)


func _ensure_pick_body() -> void:
	if _pick_body != null:
		return
	_pick_body = StaticBody3D.new()
	_pick_body.name = "PickBody"
	_pick_body.collision_layer = 4
	_pick_body.collision_mask = 0
	_pick_body.input_ray_pickable = true
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.55
	cyl.height = 0.9
	shape.shape = cyl
	shape.position = Vector3(0.0, 0.45, 0.0)
	_pick_body.add_child(shape)
	add_child(_pick_body)
	_pick_body.mouse_entered.connect(func() -> void: tower_hovered.emit(self, true))
	_pick_body.mouse_exited.connect(func() -> void: tower_hovered.emit(self, false))
	_pick_body.input_event.connect(_on_pick_input)


func _on_pick_input(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
				return
			tower_clicked.emit(self)
			get_viewport().set_input_as_handled()

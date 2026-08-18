extends Node3D

signal reached_core(enemy: Node3D)
signal died(enemy: Node3D)
signal enemy_clicked(enemy: Node3D)

enum CombatState { MOVING, ENGAGED, DEAD, REACHED_CORE }

const HealthBarScript := preload("res://scripts/combat/health_bar_3d.gd")
const FloatingTextScript := preload("res://scripts/combat/floating_text_3d.gd")
const AudioBridgeScript := preload("res://scripts/app/audio_bridge.gd")
const SimContextScript := preload("res://scripts/sim/sim_context.gd")

@export var max_health: float = 100.0
@export var speed: float = 2.2
@export var melee_damage: float = 15.0
@export var melee_interval: float = 1.0

## Reserved for future enemy healing (inactive in v0.8).
@export var healing_delay: float = 0.0
@export var healing_rate: float = 0.0

var enemy_id: String = "bot"
var runtime_id: String = ""
var reward: int = 10
var health: float = 100.0
var floor_id: String = ""
var floor_index: int = 0
var combat_state: int = CombatState.MOVING
var damage_taken_total: float = 0.0
var was_blocked: bool = false

var _path: PackedVector3Array = PackedVector3Array()
var _waypoint_floors: PackedStringArray = PackedStringArray()
var _floor_index_by_id: Dictionary = {}
var _waypoint_index: int = 0
var _alive: bool = true
var _kill_attributed: bool = false
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0
var _engaged_guard: Node = null
var _melee_cooldown: float = 0.0
var _hp_bar: Node3D
var _visual_root: Node3D
var _base_scale: Vector3 = Vector3.ONE
var _pick_body: StaticBody3D


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	_ensure_visual_root()
	_ensure_hp_bar()
	_ensure_pick_body()


func is_alive() -> bool:
	return _alive and combat_state != CombatState.DEAD and combat_state != CombatState.REACHED_CORE


func configure_from_definition(def: Resource) -> void:
	if def == null:
		return
	enemy_id = str(def.enemy_id)
	max_health = float(def.base_max_health)
	speed = float(def.base_move_speed)
	melee_damage = float(def.base_melee_damage)
	melee_interval = float(def.base_melee_interval)
	reward = int(def.reward)
	var reward_override = SimContextScript.get_override("reward", null)
	if reward_override != null:
		reward = int(reward_override)
	health = max_health


func setup(
	path: PackedVector3Array,
	hp: float = -1.0,
	waypoint_floors: PackedStringArray = PackedStringArray(),
	floor_index_by_id: Dictionary = {},
	p_enemy_id: String = ""
) -> void:
	_path = path
	_waypoint_floors = waypoint_floors
	_floor_index_by_id = floor_index_by_id
	_waypoint_index = 0
	_kill_attributed = false
	_slow_factor = 1.0
	_slow_timer = 0.0
	_engaged_guard = null
	_melee_cooldown = 0.0
	combat_state = CombatState.MOVING
	_alive = true
	damage_taken_total = 0.0
	was_blocked = false
	if not p_enemy_id.is_empty():
		enemy_id = p_enemy_id
	if hp > 0.0:
		max_health = hp
	health = max_health
	if _path.size() > 0:
		global_position = _path[0]
	_update_floor_from_waypoint()
	_ensure_visual_root()
	_ensure_hp_bar()
	_ensure_pick_body()
	_refresh_hp_bar()


func get_inspect_lines() -> PackedStringArray:
	var combat := "moving"
	match combat_state:
		CombatState.ENGAGED:
			combat = "engaged"
		CombatState.DEAD:
			combat = "dead"
		CombatState.REACHED_CORE:
			combat = "reached_core"
	return PackedStringArray([
		"ID  %s" % runtime_id,
		"TYPE  %s" % enemy_id,
		"HP  %.0f / %.0f" % [health, max_health],
		"FLOOR  %s" % floor_id,
		"PROGRESS  %.2f" % get_path_progress(),
		"COMBAT  %s" % combat,
	])


func get_path_progress() -> float:
	if _path.is_empty():
		return 0.0
	if _waypoint_index <= 0:
		return 0.0
	if _waypoint_index >= _path.size():
		return float(maxi(_path.size() - 1, 0))
	var a := _path[_waypoint_index - 1]
	var b := _path[_waypoint_index]
	var seg := b - a
	var seg_len_sq := seg.length_squared()
	if seg_len_sq < 0.000001:
		return float(_waypoint_index - 1)
	var t := clampf((global_position - a).dot(seg) / seg_len_sq, 0.0, 1.0)
	return float(_waypoint_index - 1) + t


func get_waypoint_index() -> int:
	return _waypoint_index


func get_normalized_path_progress() -> float:
	if _path.size() <= 1:
		return 0.0
	return clampf(get_path_progress() / float(_path.size() - 1), 0.0, 1.0)


## Session/timeline restore: place along path by fractional progress and set HP.
func restore_at_progress(progress: float, hp: float = -1.0) -> void:
	if _path.is_empty():
		return
	var max_p := float(maxi(_path.size() - 1, 0))
	var p := clampf(progress, 0.0, max_p)
	var idx := clampi(int(floor(p)), 0, maxi(_path.size() - 1, 0))
	var frac := p - float(idx)
	if idx >= _path.size() - 1:
		global_position = _path[_path.size() - 1]
		_waypoint_index = _path.size()
	else:
		global_position = _path[idx].lerp(_path[idx + 1], frac)
		_waypoint_index = idx + 1
	if hp > 0.0:
		health = minf(hp, max_health)
	_update_floor_from_waypoint()
	_refresh_hp_bar()


func restore_from_snapshot(data: Dictionary) -> void:
	var wp := int(data.get("waypoint_index", -1))
	if wp >= 0:
		_waypoint_index = clampi(wp, 0, _path.size())
	if data.has("path_progress"):
		restore_at_progress(float(data.get("path_progress", 0.0)), -1.0)
	if typeof(data.get("position")) == TYPE_VECTOR3:
		global_position = data.get("position")
	elif typeof(data.get("position")) == TYPE_DICTIONARY:
		var pos: Dictionary = data.get("position")
		global_position = Vector3(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)), float(pos.get("z", 0.0)))
	var mx := float(data.get("max_health", 0.0))
	if mx > 0.0:
		max_health = mx
	health = clampf(float(data.get("health", health)), 0.0, max_health)
	combat_state = int(data.get("combat_state", CombatState.MOVING))
	_alive = health > 0.0 and combat_state != CombatState.DEAD and combat_state != CombatState.REACHED_CORE
	if not _alive and combat_state != CombatState.REACHED_CORE:
		combat_state = CombatState.DEAD
	_kill_attributed = not _alive
	if data.has("runtime_id"):
		runtime_id = str(data.get("runtime_id"))
	if data.has("speed"):
		speed = float(data.get("speed"))
	if data.has("melee_damage"):
		melee_damage = float(data.get("melee_damage"))
	if data.has("melee_interval"):
		melee_interval = float(data.get("melee_interval"))
	if data.has("melee_cooldown"):
		_melee_cooldown = float(data.get("melee_cooldown"))
	_update_floor_from_waypoint()
	_refresh_hp_bar(true)
	if not _alive:
		if _hp_bar != null and is_instance_valid(_hp_bar):
			_hp_bar.visible = false
		if _visual_root != null:
			_visual_root.scale = _base_scale * 0.22


func get_current_floor_id() -> String:
	return floor_id


func get_current_floor_index() -> int:
	return floor_index


func is_engaged() -> bool:
	return combat_state == CombatState.ENGAGED and _engaged_guard != null and is_instance_valid(_engaged_guard)


func engage(guard: Node) -> bool:
	if not _alive or combat_state == CombatState.DEAD:
		return false
	if is_engaged() and _engaged_guard != guard:
		return false
	if guard == null or not is_instance_valid(guard):
		return false
	_engaged_guard = guard
	combat_state = CombatState.ENGAGED
	_melee_cooldown = 0.15
	was_blocked = true
	_refresh_hp_bar(true)
	return true


func capture_combat() -> Dictionary:
	var guard_id := ""
	if _engaged_guard != null and is_instance_valid(_engaged_guard):
		if "runtime_id" in _engaged_guard:
			guard_id = str(_engaged_guard.get("runtime_id"))
		elif _engaged_guard.get("owner_tower") != null:
			var ot = _engaged_guard.get("owner_tower")
			guard_id = "%s:g%d" % [str(ot.get("runtime_id")), int(_engaged_guard.get("slot_index"))]
	return {
		"runtime_id": runtime_id,
		"enemy_id": enemy_id,
		"health": health,
		"max_health": max_health,
		"path_progress": get_path_progress(),
		"waypoint_index": _waypoint_index,
		"position": global_position,
		"floor_id": floor_id,
		"combat_state": combat_state,
		"melee_cooldown": _melee_cooldown,
		"engaged_guard_id": guard_id,
		"speed": speed,
		"melee_damage": melee_damage,
		"melee_interval": melee_interval,
		"alive": _alive,
	}


func relink_guard(guard: Node) -> void:
	_engaged_guard = guard
	if guard != null:
		combat_state = CombatState.ENGAGED


func disengage(guard: Node = null) -> void:
	if guard != null and _engaged_guard != null and is_instance_valid(_engaged_guard) and _engaged_guard != guard:
		return
	_engaged_guard = null
	if _alive and combat_state == CombatState.ENGAGED:
		combat_state = CombatState.MOVING
	_refresh_hp_bar()


## Kept for future towers; Guard Post no longer uses this.
func apply_slow(factor: float, duration: float) -> void:
	if not _alive or factor <= 0.0 or duration <= 0.0:
		return
	_slow_factor = minf(_slow_factor, clampf(factor, 0.05, 1.0))
	_slow_timer = maxf(_slow_timer, duration)


func take_damage(amount: float, source: Node = null) -> Dictionary:
	var result := {
		"actual_damage": 0.0,
		"killed": false,
		"remaining_health": health,
		"hp_before": health,
	}
	if not _alive or amount <= 0.0 or combat_state == CombatState.DEAD:
		return result

	var hp_before := health
	var actual := minf(amount, hp_before)
	health = maxf(hp_before - actual, 0.0)
	var killed := health <= 0.0
	result["actual_damage"] = actual
	result["killed"] = killed
	result["remaining_health"] = health
	result["hp_before"] = hp_before
	damage_taken_total += actual

	_spawn_damage_number(actual)
	_play_hit_flash()
	# Guard melee impact (projectile has its own cue in basic_projectile).
	if source != null and source.has_method("get_guards") and is_inside_tree():
		AudioBridgeScript.play_3d("melee_hit", global_position)
	_refresh_hp_bar(true)

	if source != null and is_instance_valid(source) and source.has_method("record_hit"):
		source.call("record_hit", actual, floor_id, floor_index)

	if killed and not _kill_attributed:
		_kill_attributed = true
		_alive = false
		combat_state = CombatState.DEAD
		var guard := _engaged_guard
		_engaged_guard = null
		if guard != null and is_instance_valid(guard) and guard.has_method("disengage"):
			guard.call("disengage")
		if source != null and is_instance_valid(source) and source.has_method("record_kill"):
			source.call("record_kill")
		_notify_telemetry_kill(source, actual, hp_before)
		var source_id := str(source.get("runtime_id")) if source != null and is_instance_valid(source) else "?"
		SimContextScript.log_msg("Enemy killed by %s: actual_damage=%.1f" % [source_id, actual])
		if is_inside_tree():
			AudioBridgeScript.play_3d("enemy_death", global_position)
		died.emit(self)
		_play_death_then_free()

	return result


func _notify_telemetry_kill(source: Node, final_hit_damage: float, hp_before: float) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var telemetry := tree.root.find_child("TelemetryManager", true, false)
	if telemetry == null:
		return
	if telemetry.has_method("on_enemy_killed"):
		telemetry.call(
			"on_enemy_killed",
			source,
			self,
			final_hit_damage,
			hp_before,
			floor_id,
			floor_index
		)


func _update_floor_from_waypoint() -> void:
	var idx := mini(_waypoint_index, maxi(_waypoint_floors.size() - 1, 0))
	if _waypoint_floors.size() > 0:
		floor_id = _waypoint_floors[idx]
	if _floor_index_by_id.has(floor_id):
		floor_index = int(_floor_index_by_id[floor_id])
	set_meta("floor_index", floor_index)
	set_meta("floor_id", floor_id)


func _physics_process(delta: float) -> void:
	if not _alive or combat_state == CombatState.DEAD:
		return
	if _slow_timer > 0.0:
		_slow_timer = maxf(_slow_timer - delta, 0.0)
		if _slow_timer <= 0.0:
			_slow_factor = 1.0

	if combat_state == CombatState.ENGAGED:
		_process_engaged(delta)
		return

	if combat_state != CombatState.MOVING or _path.is_empty():
		return
	if _waypoint_index >= _path.size():
		_alive = false
		combat_state = CombatState.REACHED_CORE
		reached_core.emit(self)
		queue_free()
		return

	var target := _path[_waypoint_index]
	var to_target := target - global_position
	var distance := to_target.length()
	var step := speed * _slow_factor * delta
	if distance <= step:
		global_position = target
		_waypoint_index += 1
		_update_floor_from_waypoint()
	else:
		var direction := to_target.normalized()
		global_position += direction * step
		if absf(direction.dot(Vector3.UP)) < 0.98:
			look_at(global_position + direction, Vector3.UP)


func _process_engaged(delta: float) -> void:
	if _engaged_guard == null or not is_instance_valid(_engaged_guard):
		disengage()
		return
	_face_partner(_engaged_guard)
	_melee_cooldown = maxf(_melee_cooldown - delta, 0.0)
	if _melee_cooldown > 0.0:
		return
	_melee_cooldown = melee_interval
	_play_attack_lunge()
	AudioBridgeScript.play_3d("enemy_attack", global_position)
	if _engaged_guard.has_method("take_damage"):
		_engaged_guard.call("take_damage", melee_damage, self)


func _face_partner(partner: Node) -> void:
	if partner == null or not is_instance_valid(partner) or not (partner is Node3D):
		return
	var p := (partner as Node3D).global_position
	var flat := Vector3(p.x, global_position.y, p.z)
	if global_position.distance_to(flat) < 0.001:
		return
	look_at(flat, Vector3.UP)


func _ensure_pick_body() -> void:
	if not (SimContextScript.active and SimContextScript.presentation):
		return
	if _pick_body != null and is_instance_valid(_pick_body):
		return
	_pick_body = StaticBody3D.new()
	_pick_body.name = "PickBody"
	_pick_body.collision_layer = 4
	_pick_body.collision_mask = 0
	_pick_body.input_ray_pickable = true
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.45
	shape.shape = sph
	shape.position = Vector3(0.0, 0.5, 0.0)
	_pick_body.add_child(shape)
	add_child(_pick_body)
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
			enemy_clicked.emit(self)
			get_viewport().set_input_as_handled()


func _ensure_visual_root() -> void:
	_visual_root = get_node_or_null("Visual") as Node3D
	if _visual_root == null:
		_visual_root = self
	_base_scale = _visual_root.scale if _visual_root != null else scale


func _ensure_hp_bar() -> void:
	if SimContextScript.skip_presentation():
		return
	if _hp_bar != null and is_instance_valid(_hp_bar):
		return
	_hp_bar = Node3D.new()
	_hp_bar.set_script(HealthBarScript)
	_hp_bar.name = "HealthBar"
	_hp_bar.position = Vector3(0.0, 1.15, 0.0)
	add_child(_hp_bar)


func _refresh_hp_bar(force: bool = false) -> void:
	if _hp_bar == null or not is_instance_valid(_hp_bar):
		return
	if _hp_bar.has_method("set_health"):
		_hp_bar.call("set_health", health, max_health, force or is_engaged())


func _spawn_damage_number(amount: float) -> void:
	if SimContextScript.skip_presentation():
		return
	if not is_inside_tree():
		return
	var label := FloatingTextScript.damage_label(amount)
	if label.is_empty():
		return
	FloatingTextScript.spawn(
		get_parent() if get_parent() else self,
		global_position,
		label,
		Color(1.0, 0.45, 0.35)
	)


func _play_hit_flash() -> void:
	if SimContextScript.skip_presentation():
		return
	if not is_inside_tree() or _visual_root == null:
		return
	var tween := create_tween()
	tween.tween_property(_visual_root, "scale", _base_scale * 1.12, 0.06)
	tween.tween_property(_visual_root, "scale", _base_scale, 0.08)


func _play_attack_lunge() -> void:
	# Visual-only: never move the combat node's global_position.
	if SimContextScript.skip_presentation():
		return
	if not is_inside_tree() or _visual_root == null:
		return
	var forward := -global_transform.basis.z
	var origin := _visual_root.position
	var tween := create_tween()
	tween.tween_property(_visual_root, "position", origin + forward * 0.12, 0.07)
	tween.tween_property(_visual_root, "position", origin, 0.09)


func _play_death_then_free() -> void:
	if SimContextScript.skip_presentation() or not is_inside_tree():
		queue_free()
		return
	var target := _visual_root if _visual_root != null else self
	var tween := create_tween()
	tween.tween_property(target, "scale", Vector3(0.05, 0.05, 0.05), 0.35)
	tween.tween_callback(queue_free)

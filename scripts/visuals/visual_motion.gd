extends Node3D

## Presentation-only motion. Never writes combat state, never moves the runtime root.

enum Kind { AUTO, SENTRY, GUARD, MELTDOWN, BOT }

const SimContextScript := preload("res://scripts/sim/sim_context.gd")

@export var kind: Kind = Kind.AUTO

var _kind: Kind = Kind.AUTO
var _t: float = 0.0
var _phase: float = 0.0
var _sensor: Node3D
var _servo: Node3D
var _yaw_ring: Node3D
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _core_base_energy: float = 2.4
var _visor: Node3D
var _hip: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _head: Node3D
var _walk_amp: float = 1.0


func _ready() -> void:
	_phase = float(get_instance_id() % 97) * 0.07
	_resolve_kind()
	_cache_nodes()
	if not _should_animate():
		set_process(false)


func _process(delta: float) -> void:
	if not _should_animate():
		return
	_t += delta
	match _kind:
		Kind.SENTRY:
			_tick_sentry()
		Kind.GUARD:
			_tick_guard()
		Kind.MELTDOWN:
			_tick_meltdown()
		Kind.BOT:
			_tick_bot(delta)
		_:
			pass


func _should_animate() -> bool:
	if SimContextScript.skip_presentation():
		return false
	var tree := get_tree()
	if tree != null:
		var sm := tree.root.get_node_or_null("SettingsManager")
		if sm != null and sm.has_method("reduced_motion") and bool(sm.call("reduced_motion")):
			return false
	return true


func _resolve_kind() -> void:
	if kind != Kind.AUTO:
		_kind = kind
		return
	var n := String(name)
	if n.findn("Sentry") >= 0 or has_node("Turret"):
		_kind = Kind.SENTRY
	elif n.findn("GuardPost") >= 0:
		_kind = Kind.GUARD
	elif n.findn("Guard") >= 0:
		_kind = Kind.GUARD
	elif n.findn("Lava") >= 0 or n.findn("Meltdown") >= 0 or has_node("Spout"):
		_kind = Kind.MELTDOWN
	elif n.findn("Bot") >= 0 or has_node("Hip"):
		_kind = Kind.BOT
	else:
		_kind = Kind.AUTO


func _cache_nodes() -> void:
	_sensor = _find_named("Sensor") as Node3D
	_servo = _find_named("Servo") as Node3D
	_yaw_ring = _find_named("YawRing") as Node3D
	var core_n := _find_named("Core")
	if core_n is MeshInstance3D:
		_core = core_n as MeshInstance3D
		var src := _core.get_active_material(0)
		if src is StandardMaterial3D:
			_core_mat = (src as StandardMaterial3D).duplicate()
			_core_base_energy = _core_mat.emission_energy_multiplier
			_core.material_override = _core_mat
	_visor = _find_named("Visor") as Node3D
	_hip = _find_named("Hip") as Node3D
	_leg_l = _find_named("LegL") as Node3D
	_leg_r = _find_named("LegR") as Node3D
	_arm_l = _find_named("ArmL") as Node3D
	_arm_r = _find_named("ArmR") as Node3D
	_head = _find_named("Head") as Node3D


func _find_named(node_name: String) -> Node:
	if has_node(node_name):
		return get_node(node_name)
	var stack: Array = []
	for child in get_children():
		if String(child.name) == "GuardA" or String(child.name) == "GuardB":
			continue
		stack.append(child)
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name == node_name:
			return n
		for child in n.get_children():
			stack.append(child)
	return null


func _tick_sentry() -> void:
	var wobble := sin(_t * 2.1 + _phase) * 0.035
	var scan := sin(_t * 1.15 + _phase) * 0.12
	if _yaw_ring != null:
		_yaw_ring.rotation.y = wobble * 0.4
	if _servo != null:
		_servo.rotation.z = wobble
	if _sensor != null:
		_sensor.rotation.y = scan
		_sensor.rotation.x = sin(_t * 1.7 + _phase) * 0.08


func _tick_guard() -> void:
	var sway := sin(_t * 1.4 + _phase) * 0.03
	if _hip != null:
		_hip.rotation.z = sway
		_hip.rotation.x = sin(_t * 0.9 + _phase) * 0.015
	if _visor != null:
		_visor.rotation.y = sin(_t * 0.8 + _phase) * 0.06
	if _head != null and _visor == null:
		_head.rotation.y = sin(_t * 0.8 + _phase) * 0.05
	if _arm_l != null:
		_arm_l.rotation.x = sway * 0.6
	if _arm_r != null:
		_arm_r.rotation.x = -sway * 0.6
	_tick_meltdown()


func _tick_meltdown() -> void:
	if _core_mat == null:
		return
	var pulse := 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 2.6 + _phase))
	_core_mat.emission_energy_multiplier = _core_base_energy * pulse
	if _core != null:
		var s := 1.0 + 0.04 * sin(_t * 2.6 + _phase)
		_core.scale = Vector3(s, s, s)


func _tick_bot(delta: float) -> void:
	var moving := _bot_should_walk()
	_walk_amp = move_toward(_walk_amp, 1.0 if moving else 0.18, delta * 3.5)
	var gait := _t * 7.2
	var swing := sin(gait + _phase) * 0.42 * _walk_amp
	if _hip != null:
		_hip.position.y = sin(gait * 2.0 + _phase) * 0.012 * _walk_amp
		_hip.rotation.y = sin(gait + _phase) * 0.05 * _walk_amp
	if _leg_l != null:
		_leg_l.rotation.x = swing
	if _leg_r != null:
		_leg_r.rotation.x = -swing
	if _arm_l != null:
		_arm_l.rotation.x = -swing * 0.55
	if _arm_r != null:
		_arm_r.rotation.x = swing * 0.55
	if _head != null:
		_head.rotation.y = sin(_t * 1.3 + _phase) * 0.08


func _bot_should_walk() -> bool:
	var host := get_parent()
	if host == null:
		return true
	if "combat_state" in host:
		# Enemy.CombatState.MOVING == 0
		return int(host.get("combat_state")) == 0
	return true

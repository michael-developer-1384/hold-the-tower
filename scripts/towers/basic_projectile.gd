extends Node3D

const AudioBridgeScript := preload("res://scripts/app/audio_bridge.gd")
const ImpactScene := preload("res://scenes/visuals/fx/impact_burst.tscn")
const SimContextScript := preload("res://scripts/sim/sim_context.gd")

@export var speed: float = 28.0
@export var damage: float = 25.0

var _target: Node3D = null
var _source_tower: Node3D = null
var _alive: bool = true


func _ready() -> void:
	add_to_group("projectiles")


func setup(target: Node3D, dmg: float, source_tower: Node3D = null, proj_speed: float = -1.0) -> void:
	_target = target
	damage = dmg
	_source_tower = source_tower
	if proj_speed > 0.0:
		speed = proj_speed
	if not is_in_group("projectiles"):
		add_to_group("projectiles")
	_fit_tracer()


func capture_state() -> Dictionary:
	var target_id := ""
	if _target != null and is_instance_valid(_target) and "runtime_id" in _target:
		target_id = str(_target.get("runtime_id"))
	var source_id := ""
	if _source_tower != null and is_instance_valid(_source_tower):
		source_id = str(_source_tower.get("runtime_id"))
	return {
		"position": global_position,
		"speed": speed,
		"damage": damage,
		"target_id": target_id,
		"source_id": source_id,
		"alive": _alive,
	}


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if _target == null or not is_instance_valid(_target):
		_alive = false
		queue_free()
		return

	var aim: Vector3 = _target.global_position + Vector3(0.0, 0.45, 0.0)
	var to_target := aim - global_position
	var dist := to_target.length()
	var step := speed * delta
	if dist > 0.0001:
		var dir := to_target / dist
		look_at(global_position + dir, Vector3.UP)
		_fit_tracer()
	if dist <= step:
		global_position = aim
		_apply_hit()
		_alive = false
		queue_free()
		return

	global_position += to_target.normalized() * step


func _fit_tracer() -> void:
	var tracer := get_node_or_null("Tracer") as MeshInstance3D
	var length := clampf(speed * 0.012, 0.22, 0.55)
	if tracer != null:
		tracer.scale = Vector3(1.0, length / 0.28, 1.0)
		tracer.position.z = length * 0.42
	var trail := get_node_or_null("Trail") as MeshInstance3D
	if trail != null:
		trail.scale = Vector3(1.0, 1.0, length / 0.18)
		trail.position.z = length * 0.85


func _spawn_impact() -> void:
	if SimContextScript.skip_presentation() or not is_inside_tree():
		return
	var fx := ImpactScene.instantiate() as Node3D
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	host.add_child(fx)
	fx.global_position = global_position


func _apply_hit() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	if _target.has_method("take_damage"):
		var result: Dictionary = _target.call("take_damage", damage, _source_tower)
		AudioBridgeScript.play_3d("projectile_hit", global_position)
		_spawn_impact()
		if _source_tower != null and is_instance_valid(_source_tower) and _source_tower.has_method("record_overkill"):
			var actual := float(result.get("actual_damage", 0.0))
			var over := maxf(damage - actual, 0.0)
			if over > 0.0:
				_source_tower.call("record_overkill", over)

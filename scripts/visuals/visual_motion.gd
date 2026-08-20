extends Node3D

## Presentation-only motion. Never writes combat state, never moves the runtime root.

enum Kind { AUTO, SENTRY, GUARD, MELTDOWN, BOT, GUARD_POST }

const VisualSocketsScript := preload("res://scripts/visuals/visual_sockets.gd")
const MuzzleFlashScene := preload("res://scenes/visuals/fx/muzzle_flash.tscn")
const SimContextScript := preload("res://scripts/sim/sim_context.gd")

var _recoil: Node3D
var _recoil_rest: Transform3D = Transform3D.IDENTITY
var _recoil_tween: Tween
var _hit_wobble_tween: Tween
var _muzzle_cycle: int = 0
var _look_target: Node3D = null
@export var look_max_yaw: float = PI * 0.5
@export var look_turn_speed: float = 7.0
## Antenna / status-pip blink rate while idle or locked.
@export var antenna_blink_hz: float = 1.35
@export var antenna_blink_dim: float = 0.35
@export var antenna_blink_bright: float = 2.8
@export var antenna_lock_energy: float = 4.2

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
var _hip_rest_y: float = 0.0
var _gait_phase: float = 0.0
var _stride_driven: bool = false
## Meters per full left+right gait cycle when stride-driven.
@export var bot_stride_length: float = 0.42
var _antenna_mats: Array[StandardMaterial3D] = []
var _antenna_base_energy: Array[float] = []
var _aim_locking: bool = false
var _aim_locked: bool = false


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
		Kind.GUARD_POST:
			_tick_guard_post()
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
		_kind = Kind.GUARD_POST
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
	if _hip != null:
		_hip_rest_y = _hip.position.y
	_leg_l = _find_named("LegL") as Node3D
	_leg_r = _find_named("LegR") as Node3D
	_arm_l = _find_named("ArmL") as Node3D
	_arm_r = _find_named("ArmR") as Node3D
	_head = _find_named("Head") as Node3D
	_recoil = VisualSocketsScript.resolve(self, "recoil")
	if _recoil != null:
		_recoil_rest = _recoil.transform
	if _kind == Kind.SENTRY:
		_cache_antenna_mats()


func _cache_antenna_mats() -> void:
	_antenna_mats.clear()
	_antenna_base_energy.clear()
	var names := ["StatusPip", "SensorGlass", "AuxLens", "SensorLens"]
	for n in names:
		var node := _find_named(n)
		if node is MeshInstance3D:
			_adopt_emissive(node as MeshInstance3D)
	## Fallback: any emissive mesh under the Sensor mast / antenna.
	if _antenna_mats.is_empty() and _sensor != null:
		_collect_emissives_under(_sensor)


func _adopt_emissive(mi: MeshInstance3D) -> void:
	var src := mi.get_active_material(0)
	if not (src is StandardMaterial3D):
		return
	var mat := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.emission_enabled = true
	mi.material_override = mat
	_antenna_mats.append(mat)
	_antenna_base_energy.append(mat.emission_energy_multiplier)


func _collect_emissives_under(root: Node) -> void:
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		var src := mi.get_active_material(0)
		if src is StandardMaterial3D and (src as StandardMaterial3D).emission_enabled:
			_adopt_emissive(mi)
	for child in root.get_children():
		_collect_emissives_under(child)


func set_aim_lock_state(locking: bool, locked: bool) -> void:
	_aim_locking = locking
	_aim_locked = locked


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
		## Freeze the antenna scan while acquiring lock so the red pip reads clearly.
		if _aim_locking:
			_sensor.rotation.y = move_toward(_sensor.rotation.y, 0.0, 0.08)
			_sensor.rotation.x = move_toward(_sensor.rotation.x, 0.0, 0.05)
		else:
			_sensor.rotation.y = scan
			_sensor.rotation.x = sin(_t * 1.7 + _phase) * 0.08
	_tick_antenna_light()


func _tick_antenna_light() -> void:
	if _antenna_mats.is_empty():
		return
	var energy: float
	var color := Color(1.0, 0.22, 0.12)
	if _aim_locking:
		## Solid red while slewing onto a new target.
		energy = antenna_lock_energy
		color = Color(1.0, 0.08, 0.05)
	else:
		## Idle / locked: bright↔dim blink. Lock complete returns to blink.
		var wave := 0.5 + 0.5 * sin(_t * TAU * antenna_blink_hz + _phase)
		energy = lerpf(antenna_blink_dim, antenna_blink_bright, wave)
		color = Color(1.0, 0.35, 0.18) if _aim_locked else Color(1.0, 0.45, 0.22)
	for i in range(_antenna_mats.size()):
		var mat := _antenna_mats[i]
		mat.emission = color
		mat.emission_energy_multiplier = energy
		mat.albedo_color = Color(color.r, color.g, color.b, mat.albedo_color.a)


func _tick_guard() -> void:
	var host := get_parent()
	var state := 0
	if host != null and "combat_state" in host:
		state = int(host.get("combat_state"))
	var moving := state == 1 or state == 3
	var gait := _t * 8.0
	var swing := sin(gait + _phase) * (0.38 if moving else 0.04)
	if _hip != null:
		_hip.position.y = _hip_rest_y + sin(gait * 2.0 + _phase) * (0.014 if moving else 0.004)
		_hip.rotation.z = sin(_t * 1.4 + _phase) * 0.02
	if _leg_l != null:
		_leg_l.rotation.x = swing
	if _leg_r != null:
		_leg_r.rotation.x = -swing
	if _arm_l != null:
		_arm_l.rotation.x = -swing * 0.45
	if _arm_r != null:
		_arm_r.rotation.x = swing * 0.45
	if _visor != null:
		_visor.rotation.y = sin(_t * 0.8 + _phase) * 0.06
	if _head != null and _visor == null:
		_head.rotation.y = sin(_t * 0.8 + _phase) * 0.05


func _tick_guard_post() -> void:
	_tick_meltdown()
	if _yaw_ring != null:
		_yaw_ring.rotation.y = sin(_t * 0.35 + _phase) * 0.02


func _tick_meltdown() -> void:
	if _core_mat == null:
		return
	var pulse := 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 2.6 + _phase))
	_core_mat.emission_energy_multiplier = _core_base_energy * pulse
	if _core != null:
		var s := 1.0 + 0.04 * sin(_t * 2.6 + _phase)
		_core.scale = Vector3(s, s, s)


func report_move_distance(meters: float) -> void:
	if _kind != Kind.BOT and _kind != Kind.GUARD:
		_resolve_kind()
	_stride_driven = true
	var stride := maxf(bot_stride_length, 0.05)
	_gait_phase += (meters / stride) * TAU
	_walk_amp = 1.0


func _tick_bot(delta: float) -> void:
	var moving := _bot_should_walk()
	if _stride_driven:
		moving = true
	_walk_amp = move_toward(_walk_amp, 1.0 if moving else 0.18, delta * 3.5)
	var gait: float
	if _stride_driven:
		gait = _gait_phase
	else:
		gait = _t * 7.2
	var swing := sin(gait + _phase) * 0.42 * _walk_amp
	if _hip != null:
		_hip.position.y = _hip_rest_y + sin(gait * 2.0 + _phase) * 0.012 * _walk_amp
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
		_tick_bot_head_look(delta)


func set_look_target(target: Node3D) -> void:
	_look_target = target


func _tick_bot_head_look(delta: float) -> void:
	if _head == null:
		return
	var desired := 0.0
	if _look_target != null and is_instance_valid(_look_target):
		var to := _look_target.global_position - _head.global_position
		to.y = 0.0
		var forward := -global_transform.basis.z
		forward.y = 0.0
		if to.length_squared() > 0.04 and forward.length_squared() > 0.0001:
			forward = forward.normalized()
			## Only track while the tower is still ahead / beside — drop once passed.
			if forward.dot(to) > 0.05:
				var parent_n := _head.get_parent() as Node3D
				var local := to
				if parent_n != null:
					local = parent_n.global_transform.basis.inverse() * to
				local.y = 0.0
				if local.length_squared() > 0.0001:
					## Head faces local -Z; Godot Yaw uses atan2(-x, -z).
					desired = clampf(atan2(-local.x, -local.z), -look_max_yaw, look_max_yaw)
	_head.rotation.y = lerp_angle(_head.rotation.y, desired, clampf(delta * look_turn_speed, 0.0, 1.0))


func _bot_should_walk() -> bool:
	var host := get_parent()
	if host == null:
		return true
	if "combat_state" in host:
		# Enemy.CombatState.MOVING == 0
		return int(host.get("combat_state")) == 0
	return true


func play_visual_event(event_name: String) -> void:
	if event_name == "attack" and _arm_r != null:
		var rest := _arm_r.rotation.x
		var tw := create_tween()
		tw.tween_property(_arm_r, "rotation:x", rest - 0.9, 0.07)
		tw.tween_property(_arm_r, "rotation:x", rest, 0.12)
	elif event_name == "hit":
		play_hit_feedback(global_position + Vector3(0.0, 0.4, 0.0), -global_transform.basis.z)
	elif event_name == "death":
		if _kind == Kind.BOT or _kind == Kind.GUARD:
			var tw := create_tween()
			tw.tween_property(self, "rotation:x", 1.05, 0.3)


func play_hit_feedback(hit_pos: Vector3, hit_dir: Vector3) -> void:
	## Readable stagger / wobble on hit. Lookdev only — no combat state.
	## Lean the hip (root X is reserved for ramp pitch each frame).
	if SimContextScript.skip_presentation():
		return
	var dir := hit_dir
	if dir.length_squared() < 0.0001:
		dir = -global_transform.basis.z
	else:
		dir = dir.normalized()
	var target: Node3D = _hip if _hip != null else self
	var side := clampf(dir.dot(global_transform.basis.x), -1.0, 1.0)
	var back := clampf(-dir.dot(global_transform.basis.z), -1.0, 1.0)
	var lean_z := side * 0.38
	var lean_x := back * 0.24
	if _hit_wobble_tween != null and is_instance_valid(_hit_wobble_tween):
		_hit_wobble_tween.kill()
	_hit_wobble_tween = create_tween()
	var tw := _hit_wobble_tween
	var base_z := 0.0
	var base_x := 0.0
	tw.tween_property(target, "rotation:z", base_z + lean_z, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(target, "rotation:x", base_x + lean_x, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(target, "rotation:z", base_z - lean_z * 0.6, 0.09).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(target, "rotation:x", base_x - lean_x * 0.45, 0.09)
	tw.tween_property(target, "rotation:z", base_z + lean_z * 0.25, 0.1)
	tw.parallel().tween_property(target, "rotation:x", base_x + lean_x * 0.18, 0.1)
	tw.tween_property(target, "rotation:z", base_z, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(target, "rotation:x", base_x, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	## Soft surface pop — kept small so the wobble reads first.
	if is_inside_tree():
		var spark := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.05
		sph.height = 0.1
		sph.radial_segments = 8
		sph.rings = 4
		spark.mesh = sph
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.4)
		mat.emission_energy_multiplier = 8.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.9, 0.55, 0.9)
		spark.material_override = mat
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spark)
		spark.global_position = hit_pos
		var tws := create_tween()
		tws.tween_property(spark, "scale", Vector3(1.4, 1.4, 1.4), 0.05)
		tws.tween_property(spark, "scale", Vector3(0.1, 0.1, 0.1), 0.1)
		tws.tween_callback(spark.queue_free)


func muzzle_count() -> int:
	var left := VisualSocketsScript.resolve(self, "muzzle_left")
	var right := VisualSocketsScript.resolve(self, "muzzle_right")
	if left != null and right != null:
		return 2
	if VisualSocketsScript.resolve(self, "muzzle") != null:
		return 1
	return 0


func get_muzzle_socket(index: int = -1) -> Node3D:
	var left := VisualSocketsScript.resolve(self, "muzzle_left")
	var right := VisualSocketsScript.resolve(self, "muzzle_right")
	var single := VisualSocketsScript.resolve(self, "muzzle")
	if left == null and right == null:
		return single
	if index < 0:
		index = _muzzle_cycle
	if index % 2 == 0:
		return left if left != null else single
	return right if right != null else (left if left != null else single)


func play_fire_feedback(muzzle_index: int = -1) -> int:
	var count := muzzle_count()
	var idx := muzzle_index
	if idx < 0:
		idx = _muzzle_cycle
		if count > 1:
			_muzzle_cycle = (_muzzle_cycle + 1) % count
	var muzzle := get_muzzle_socket(idx)
	_play_recoil()
	if muzzle != null and is_inside_tree() and not SimContextScript.skip_presentation():
		var fx := MuzzleFlashScene.instantiate() as Node3D
		muzzle.add_child(fx)
		fx.transform = Transform3D.IDENTITY
		if fx.has_method("play"):
			fx.call("play")
	return idx


func _play_recoil() -> void:
	if _recoil == null or not is_instance_valid(_recoil):
		_recoil = VisualSocketsScript.resolve(self, "recoil")
		if _recoil != null:
			_recoil_rest = _recoil.transform
	if _recoil == null or SimContextScript.skip_presentation():
		return
	if _recoil_tween != null and is_instance_valid(_recoil_tween):
		_recoil_tween.kill()
	_recoil.transform = _recoil_rest
	var kick := _recoil_rest.translated(_recoil_rest.basis.z * 0.055)
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(_recoil, "transform", kick, 0.035).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(_recoil, "transform", _recoil_rest, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

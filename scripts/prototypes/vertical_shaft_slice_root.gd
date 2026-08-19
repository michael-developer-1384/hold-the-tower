extends Node3D

## Vertical shaft lookdev: real vertical_test level inside industrial infrastructure.
## Level geometry comes from TestLevelFactory — no hardcoded second map.

const TestLevelFactoryScript := preload("res://scripts/level/test_level_factory.gd")
const EnemyPathBuilderScript := preload("res://scripts/level/enemy_path_builder.gd")
const SentryScene := preload("res://scenes/towers/visuals/sentry_visual.tscn")
const BotScene := preload("res://scenes/enemies/visuals/bot_visual.tscn")

const MOD := {
	"col": preload("res://scenes/environment/modules/industrial_column.tscn"),
	"frame": preload("res://scenes/environment/modules/platform_support_frame.tscn"),
	"spine": preload("res://scenes/environment/modules/vertical_power_spine.tscn"),
	"wall": preload("res://scenes/environment/modules/shaft_wall_module.tscn"),
	"hero": preload("res://scenes/environment/modules/hero_machine_core.tscn"),
	"hang": preload("res://scenes/environment/modules/support_suspension.tscn"),
	"support_col": preload("res://scenes/environment/modules/support_column.tscn"),
	"path": preload("res://scenes/environment/modules/path_straight.tscn"),
	"ramp3": preload("res://scenes/environment/modules/path_ramp_3m.tscn"),
	"pad_e": preload("res://scenes/environment/modules/build_pad_empty.tscn"),
	"pad_o": preload("res://scenes/environment/modules/build_pad_occupied.tscn"),
	"plat_s": preload("res://scenes/environment/modules/platform_small.tscn"),
	"core": preload("res://scenes/environment/modules/core_terminus.tscn"),
	"spawn": preload("res://scenes/environment/modules/spawn_arch.tscn"),
}

const SENTRY_SPOT := "F1_C"

const MAP_FOCUS := Vector3(0.0, 3.0, 0.0)

@export var capture_on_ready: bool = false
@export var camera_speed: float = 8.0
@export var camera_fast_mul: float = 2.4
@export var camera_look_sens: float = 0.0032
@export var orbit_sensitivity: float = 0.008
@export var orbit_min_distance: float = 6.0
@export var orbit_max_distance: float = 52.0

enum CamMode { ORBIT, FLY }

var _level: Resource
var _enemy_path: PackedVector3Array = PackedVector3Array()
var _near: Node3D
var _mid: Node3D
var _far: Node3D
var _map_root: Node3D
var _capture_done: bool = false
var _hero_home_pos: Vector3 = Vector3.ZERO
var _hero_home_basis: Basis = Basis.IDENTITY
var _cam_mode: CamMode = CamMode.ORBIT
var _orbiting: bool = false
var _looking: bool = false
var _orbit_pivot: Vector3 = MAP_FOCUS
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = deg_to_rad(48.0)
var _orbit_dist: float = 22.0


func _ready() -> void:
	_level = TestLevelFactoryScript.create_level()
	_enemy_path = EnemyPathBuilderScript.build(_level)
	_setup_cameras()
	_near = _group("Near")
	_mid = _group("Midground")
	_far = _group("Far")
	_map_root = _group("Map")
	_build_real_level()
	_build_structural_supports()
	_build_shaft_environment()
	_build_scene_units()
	_build_map_lighting()
	_build_void_atmosphere()
	_dim_emissives(_far, 0.55)
	_disable_shadows(_far)
	_refresh_cam_hint()
	set_process(true)
	set_process_input(true)
	var args := OS.get_cmdline_user_args()
	if capture_on_ready or args.has("--capture-shaft"):
		_run_capture()


func _process(delta: float) -> void:
	_move_camera(delta)


func _setup_cameras() -> void:
	# A) Gameplay target — elevated top-down, map dominates frame.
	var hero := get_node_or_null("HeroCamera") as Camera3D
	if hero:
		hero.fov = 30.0
		hero.position = Vector3(11.5, 16.8, 14.2)
		hero.look_at(Vector3(0.0, 3.2, 0.5), Vector3.UP)
		hero.current = true
		hero.far = 240.0
		hero.near = 0.15
		hero.attributes = null
		_hero_home_pos = hero.position
		_hero_home_basis = hero.basis
		_orbit_pivot = MAP_FOCUS
		_sync_orbit_from_camera(hero)
		_apply_orbit(hero)
	# B) Beauty — cine but believable.
	var beauty := get_node_or_null("BeautyCameraA") as Camera3D
	if beauty:
		beauty.fov = 28.0
		beauty.position = Vector3(9.2, 14.6, 16.8)
		beauty.look_at(Vector3(0.1, 3.4, 0.0), Vector3.UP)
		beauty.current = false
		beauty.far = 240.0
		beauty.attributes = _make_dof(38.0, 24.0, 0.016)
	# C) Top-down QA — all three floors readable.
	var qa := get_node_or_null("TopDownCamera") as Camera3D
	if qa:
		qa.fov = 42.0
		qa.position = Vector3(0.5, 24.0, 0.8)
		qa.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
		qa.current = false
		qa.far = 240.0


func _make_dof(far_dist: float, far_trans: float, amount: float) -> CameraAttributesPractical:
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = far_dist
	attr.dof_blur_far_transition = far_trans
	attr.dof_blur_amount = amount
	return attr


func _group(p_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = p_name
	add_child(n)
	return n


func _inst(kind: String, parent: Node3D, pos: Vector3, yaw_deg: float = 0.0, scale := 1.0) -> Node3D:
	var packed: PackedScene = MOD[kind]
	var node := packed.instantiate() as Node3D
	parent.add_child(node)
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_deg)
	if not is_equal_approx(scale, 1.0):
		node.scale = Vector3.ONE * scale
	return node


func _build_real_level() -> void:
	var walk := Node3D.new()
	walk.name = "Walkways"
	_map_root.add_child(walk)
	var ramp_keys := _ramp_cell_keys()
	for floor_def in _level.floors:
		_dress_floor_walk(walk, floor_def, ramp_keys)
		_dress_build_spots(walk, floor_def)
	_dress_ramps(walk)
	_dress_spawn_and_core(walk)


func _ramp_cell_keys() -> Dictionary:
	var keys := {}
	for connector in _level.connectors:
		if connector == null or not connector.has_method("get_waypoints"):
			continue
		var wps: PackedVector3Array = connector.call("get_waypoints")
		# Rising cells only — landing belongs to the upper floor path.
		for i in range(maxi(wps.size() - 1, 0)):
			keys[_cell_key(wps[i].x, wps[i].z)] = true
	return keys


func _cell_key(x: float, z: float) -> String:
	return "%d:%d" % [roundi(x), roundi(z)]


func _yaw_neg_z(dir: Vector3) -> float:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return 0.0
	flat = flat.normalized()
	return rad_to_deg(atan2(-flat.x, -flat.z))


func _dress_floor_walk(parent: Node3D, floor_def: Resource, ramp_keys: Dictionary) -> void:
	var pts: PackedVector3Array = floor_def.path_points
	var elev: float = float(floor_def.elevation)
	for i in pts.size():
		var p: Vector3 = pts[i]
		if ramp_keys.has(_cell_key(p.x, p.z)):
			continue
		var dir := Vector3(1.0, 0.0, 0.0)
		if i + 1 < pts.size():
			dir = pts[i + 1] - p
		elif i > 0:
			dir = p - pts[i - 1]
		_inst("path", parent, Vector3(p.x, elev, p.z), _yaw_neg_z(dir))
	for plat in floor_def.platforms:
		if plat == null:
			continue
		var sz: Vector3 = plat.size
		if sz.x > 1.05 and sz.x <= 1.35 and sz.z > 1.05 and sz.z <= 1.35:
			var o: Vector3 = plat.transform.origin
			_inst("plat_s", parent, Vector3(o.x, elev, o.z), 0.0, 0.55)


func _dress_build_spots(parent: Node3D, floor_def: Resource) -> void:
	var elev: float = float(floor_def.elevation)
	for spot in floor_def.build_spots:
		if spot == null:
			continue
		var id := str(spot.id)
		var kind := "pad_o" if id == SENTRY_SPOT else "pad_e"
		var o: Vector3 = spot.transform.origin
		_inst(kind, parent, Vector3(o.x, elev, o.z), 0.0)


func _dress_ramps(parent: Node3D) -> void:
	for connector in _level.connectors:
		if connector == null or not connector.has_method("get_waypoints"):
			continue
		var wps: PackedVector3Array = connector.call("get_waypoints")
		if wps.size() < 2:
			continue
		var from_floor = _level.get_floor_by_id(str(connector.from_floor_id))
		var elev: float = float(from_floor.elevation) if from_floor else (wps[0].y - TestLevelFactoryScript.PATH_Y)
		var start := wps[0]
		var landing := wps[wps.size() - 1]
		var uphill := Vector3(landing.x - start.x, 0.0, landing.z - start.z)
		_inst("ramp3", parent, Vector3(start.x, elev, start.z), _yaw_neg_z(uphill))


func _dress_spawn_and_core(parent: Node3D) -> void:
	var floor_1 = _level.get_floor_by_index(0)
	var spawn: Vector3 = _level.spawn_transform.origin
	var ahead := spawn + Vector3(1.0, 0.0, 0.0)
	if floor_1 != null and floor_1.path_points.size() >= 2:
		spawn = floor_1.path_points[0]
		ahead = floor_1.path_points[1]
	var elev_1 := float(floor_1.elevation) if floor_1 else 0.0
	_inst("spawn", parent, Vector3(spawn.x, elev_1, spawn.z), _yaw_neg_z(ahead - spawn))
	var floor_3 = _level.get_floor_by_index(2)
	var core_xz: Vector3 = _level.core_transform.origin
	var elev_3 := float(floor_3.elevation) if floor_3 else 6.0
	if floor_3 != null and floor_3.path_points.size() > 0:
		core_xz = floor_3.path_points[floor_3.path_points.size() - 1]
	_inst("core", parent, Vector3(core_xz.x, elev_3, core_xz.z), 0.0)


func _walk_y(path_point: Vector3) -> float:
	return path_point.y - TestLevelFactoryScript.PATH_Y


func _plant_on_walk(node: Node3D, walk: Vector3) -> void:
	node.global_position = walk
	var min_y := _global_mesh_min_y(node)
	if min_y < 100000.0:
		node.global_position.y += walk.y - min_y + 0.02


func _global_mesh_min_y(node: Node) -> float:
	var lowest := 100000.0
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var aabb := mi.get_aabb()
		for cx in [0.0, 1.0]:
			for cy in [0.0, 1.0]:
				for cz in [0.0, 1.0]:
					var local := aabb.position + aabb.size * Vector3(cx, cy, cz)
					lowest = minf(lowest, mi.to_global(local).y)
	for c in node.get_children():
		lowest = minf(lowest, _global_mesh_min_y(c))
	return lowest


func _build_structural_supports() -> void:
	# Anchor platforms to shaft structure — columns at platform corners / path joints.
	var anchors := [
		Vector3(-4.0, 0.0, -4.0),
		Vector3(4.0, 0.0, -4.0),
		Vector3(4.0, 0.0, 0.0),
		Vector3(0.0, 3.0, 0.0),
		Vector3(-4.0, 3.0, 0.0),
		Vector3(-4.0, 3.0, 4.0),
		Vector3(2.0, 3.0, 3.0),
		Vector3(2.0, 6.0, -1.0),
		Vector3(-4.0, 6.0, -1.0),
		Vector3(-4.0, 6.0, 4.0),
		Vector3(4.0, 6.0, -4.0),
	]
	for p in anchors:
		_inst("col", _near, p, 0.0)
	# Service frames under upper floors — explain why they float.
	_inst("frame", _near, Vector3(0.0, 3.0, 0.0), 0.0)
	_inst("frame", _near, Vector3(-2.0, 6.0, 1.0), 90.0)
	# Suspension for bridge-like spans.
	_inst("hang", _near, Vector3(-4.0, 3.0, 2.0), 90.0)
	_inst("hang", _near, Vector3(2.0, 6.0, 2.0), 0.0)
	# Thin support columns under ramp landings.
	for p in [Vector3(3.0, 0.0, 0.0), Vector3(2.0, 3.0, 2.0)]:
		_inst("support_col", _near, p, 0.0)


func _build_shaft_environment() -> void:
	_inst("wall", _mid, Vector3(0.0, 0.0, -9.0), 0.0)
	_inst("spine", _mid, Vector3(-8.5, 0.0, 2.0), 6.0)
	_inst("spine", _mid, Vector3(8.5, 0.0, -0.5), -8.0)
	_inst("hero", _far, Vector3(-10.5, 0.0, 3.5), 18.0, 1.0)


func _build_scene_units() -> void:
	var sentry_pos := Vector3(1.0, 0.0, -3.0)
	for floor_def in _level.floors:
		for spot in floor_def.build_spots:
			if spot == null or str(spot.id) != SENTRY_SPOT:
				continue
			var o: Vector3 = spot.transform.origin
			sentry_pos = Vector3(o.x, float(floor_def.elevation), o.z)
			break
	var sentry := SentryScene.instantiate() as Node3D
	_near.add_child(sentry)
	_plant_on_walk(sentry, sentry_pos)
	var bot_wp := Vector3(1.0, 0.0, -4.0)
	if _enemy_path.size() > 5:
		bot_wp = _enemy_path[5]
	var bot := BotScene.instantiate() as Node3D
	_near.add_child(bot)
	bot.set_process(false)
	var face := sentry_pos - Vector3(bot_wp.x, sentry_pos.y, bot_wp.z)
	if face.length_squared() > 0.01:
		bot.rotation.y = atan2(-face.x, -face.z)
		sentry.rotation.y = atan2(face.x, face.z)
	_plant_on_walk(bot, Vector3(bot_wp.x, _walk_y(bot_wp), bot_wp.z))


func _build_map_lighting() -> void:
	# Maintenance strip along floor 1 south path.
	for x in range(-3, 4):
		var strip := OmniLight3D.new()
		strip.light_color = Color(0.72, 0.82, 0.94)
		strip.light_energy = 0.35
		strip.omni_range = 2.8
		strip.shadow_enabled = false
		strip.position = Vector3(float(x), 0.6, -4.2)
		_near.add_child(strip)
	# Warm pad spot over sentry build area.
	var pad_spot := SpotLight3D.new()
	pad_spot.name = "PadSpot"
	pad_spot.light_color = Color(1.0, 0.78, 0.52)
	pad_spot.light_energy = 4.2
	pad_spot.spot_range = 6.5
	pad_spot.spot_angle = 28.0
	pad_spot.shadow_enabled = true
	pad_spot.light_volumetric_fog_energy = 0.55
	pad_spot.position = Vector3(1.0, 3.2, -1.5)
	add_child(pad_spot)
	pad_spot.look_at(Vector3(1.0, 0.0, -3.0), Vector3.UP)
	# Floor 2 / 3 fill.
	var f2 := OmniLight3D.new()
	f2.light_color = Color(0.68, 0.76, 0.88)
	f2.light_energy = 1.8
	f2.omni_range = 7.5
	f2.position = Vector3(-1.0, 4.5, 2.0)
	add_child(f2)
	var f3 := OmniLight3D.new()
	f3.light_color = Color(0.65, 0.74, 0.86)
	f3.light_energy = 1.6
	f3.omni_range = 7.0
	f3.position = Vector3(0.0, 7.5, 1.0)
	add_child(f3)


func _build_void_atmosphere() -> void:
	for i in 4:
		var p := OmniLight3D.new()
		p.light_color = Color(0.18, 0.28, 0.42)
		p.light_energy = 0.32
		p.omni_range = 11.0
		p.shadow_enabled = false
		p.light_volumetric_fog_energy = 0.9
		p.position = Vector3(-3.0 + float(i) * 2.5, -10.0 - float(i) * 2.0, 0.5)
		add_child(p)


func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(node as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for c in node.get_children():
		_disable_shadows(c)


func _dim_emissives(node: Node, mul: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		var surfaces := mesh.get_surface_count() if mesh else 0
		for i in surfaces:
			var src := mi.get_active_material(i)
			if src == null:
				continue
			var mat := src.duplicate() as Material
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				if sm.emission_enabled:
					sm.emission_energy_multiplier *= mul
					sm.emission = sm.emission.lerp(Color(0.14, 0.22, 0.32), 0.4)
			mi.set_surface_override_material(i, mat)
	for c in node.get_children():
		_dim_emissives(c, mul)


func _is_capturing() -> bool:
	return capture_on_ready or OS.get_cmdline_user_args().has("--capture-shaft")


func _hero_cam() -> Camera3D:
	return get_node_or_null("HeroCamera") as Camera3D


func _refresh_cam_hint() -> void:
	var hud := get_node_or_null("Hud")
	if hud == null or not hud.has_method("set_cam_hint"):
		return
	if _cam_mode == CamMode.ORBIT:
		hud.call("set_cam_hint", "RMB orbit  ·  WASD pan  ·  O fly  ·  R reset")
	else:
		hud.call("set_cam_hint", "RMB look  ·  WASD fly  ·  O orbit  ·  R reset")


func _sync_orbit_from_camera(cam: Camera3D) -> void:
	var offset: Vector3 = cam.global_position - _orbit_pivot
	_orbit_dist = clampf(offset.length(), orbit_min_distance, orbit_max_distance)
	if _orbit_dist < 0.05:
		_orbit_dist = 22.0
		offset = Vector3(0.0, 0.7, 1.0)
	_orbit_yaw = atan2(offset.x, offset.z)
	var flat := Vector2(offset.x, offset.z).length()
	_orbit_pitch = clampf(atan2(offset.y, maxf(flat, 0.01)), deg_to_rad(12.0), deg_to_rad(82.0))


func _apply_orbit(cam: Camera3D) -> void:
	var cp := cos(_orbit_pitch)
	var offset := Vector3(
		sin(_orbit_yaw) * cp,
		sin(_orbit_pitch),
		cos(_orbit_yaw) * cp
	) * _orbit_dist
	cam.global_position = _orbit_pivot + offset
	cam.look_at(_orbit_pivot, Vector3.UP)
	cam.current = true


func _toggle_cam_mode() -> void:
	var cam := _hero_cam()
	if cam == null:
		return
	if _cam_mode == CamMode.ORBIT:
		_cam_mode = CamMode.FLY
		_orbiting = false
	else:
		_cam_mode = CamMode.ORBIT
		_looking = false
		_sync_orbit_from_camera(cam)
		_apply_orbit(cam)
	_refresh_cam_hint()


func _reset_camera() -> void:
	var cam := _hero_cam()
	if cam == null:
		return
	cam.position = _hero_home_pos
	cam.basis = _hero_home_basis
	cam.current = true
	_orbit_pivot = MAP_FOCUS
	_looking = false
	_orbiting = false
	_sync_orbit_from_camera(cam)
	if _cam_mode == CamMode.ORBIT:
		_apply_orbit(cam)


func _move_camera(delta: float) -> void:
	if _is_capturing():
		return
	var cam := _hero_cam()
	if cam == null:
		return
	var ix := Input.get_axis("ui_left", "ui_right")
	var iz := Input.get_axis("ui_down", "ui_up")
	var iy := 0.0
	if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE):
		iy += 1.0
	if Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_CTRL):
		iy -= 1.0
	if is_zero_approx(ix) and is_zero_approx(iz) and is_zero_approx(iy):
		return
	cam.current = true
	var speed := camera_speed * (camera_fast_mul if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var flat_fwd := Vector3(cam.global_transform.basis.z.x, 0.0, cam.global_transform.basis.z.z)
	if flat_fwd.length_squared() < 0.0001:
		flat_fwd = Vector3(0.0, 0.0, 1.0)
	flat_fwd = flat_fwd.normalized()
	var right := Vector3.UP.cross(flat_fwd).normalized()
	var move := (right * ix - flat_fwd * iz + Vector3.UP * iy) * speed * delta
	if _cam_mode == CamMode.ORBIT:
		_orbit_pivot += move
		_apply_orbit(cam)
	else:
		cam.global_position += move


func _input(event: InputEvent) -> void:
	if _is_capturing():
		return
	var cam := _hero_cam()
	if cam == null:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_R or k.physical_keycode == KEY_R:
			_reset_camera()
			get_viewport().set_input_as_handled()
			return
		if k.keycode == KEY_O or k.physical_keycode == KEY_O:
			_toggle_cam_mode()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if _cam_mode == CamMode.ORBIT:
				_orbiting = mb.pressed
			else:
				_looking = mb.pressed
			cam.current = true
			get_viewport().set_input_as_handled()
			return
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var inward := mb.button_index == MOUSE_BUTTON_WHEEL_UP
			if _cam_mode == CamMode.ORBIT:
				var step := 1.25 if inward else -1.25
				_orbit_dist = clampf(_orbit_dist - step, orbit_min_distance, orbit_max_distance)
				_apply_orbit(cam)
			else:
				cam.global_position += -cam.global_transform.basis.z * (1.15 if inward else -1.15)
			cam.current = true
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _cam_mode == CamMode.ORBIT and _orbiting:
			_orbit_yaw -= mm.relative.x * orbit_sensitivity
			_orbit_pitch = clampf(
				_orbit_pitch + mm.relative.y * orbit_sensitivity,
				deg_to_rad(12.0),
				deg_to_rad(82.0)
			)
			_apply_orbit(cam)
			get_viewport().set_input_as_handled()
		elif _cam_mode == CamMode.FLY and _looking:
			cam.rotate_y(-mm.relative.x * camera_look_sens)
			cam.rotate_object_local(Vector3.RIGHT, -mm.relative.y * camera_look_sens)
			var e := cam.rotation
			e.x = clampf(e.x, deg_to_rad(-85.0), deg_to_rad(25.0))
			cam.rotation = e
			cam.current = true
			get_viewport().set_input_as_handled()


func _run_capture() -> void:
	if _capture_done:
		return
	_capture_done = true
	var hud := get_node_or_null("Hud")
	if hud and hud.has_method("set_capture_mode"):
		hud.call("set_capture_mode", true)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(2.4).timeout
	await RenderingServer.frame_post_draw
	var dir := "res://artifacts/visual_previews"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	await _shot("HeroCamera", dir.path_join("shaft_gameplay.png"))
	await _shot("BeautyCameraA", dir.path_join("shaft_beauty.png"))
	await _shot("TopDownCamera", dir.path_join("shaft_topdown_qa.png"))
	print("vertical_shaft_slice: captured screenshots")
	if capture_on_ready or OS.get_cmdline_user_args().has("--capture-shaft"):
		await get_tree().create_timer(0.2).timeout
		get_tree().quit()


func _shot(cam_name: String, path: String) -> void:
	var cam := get_node_or_null(cam_name) as Camera3D
	if cam == null:
		push_error("vertical_shaft_slice: missing camera %s" % cam_name)
		return
	cam.current = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_error("vertical_shaft_slice: no viewport image")
		return
	var abs_path := ProjectSettings.globalize_path(path)
	img.save_png(abs_path)
	print("vertical_shaft_slice: wrote %s" % abs_path)

extends Node3D

## Visual target slice: lookdev composition of an industrial vertical map.

const SentryScene := preload("res://scenes/towers/visuals/sentry_visual.tscn")
const BotScene := preload("res://scenes/enemies/visuals/bot_visual.tscn")
const ImpactScene := preload("res://scenes/visuals/fx/impact_burst.tscn")
const VisualSocketsScript := preload("res://scripts/visuals/visual_sockets.gd")

const MOD := {
	"path": preload("res://scenes/environment/modules/path_straight.tscn"),
	"corner": preload("res://scenes/environment/modules/path_corner.tscn"),
	"ramp": preload("res://scenes/environment/modules/path_ramp.tscn"),
	"bridge": preload("res://scenes/environment/modules/path_bridge.tscn"),
	"plat_s": preload("res://scenes/environment/modules/platform_small.tscn"),
	"pad_e": preload("res://scenes/environment/modules/build_pad_empty.tscn"),
	"pad_r": preload("res://scenes/environment/modules/build_pad_recommended.tscn"),
	"pad_o": preload("res://scenes/environment/modules/build_pad_occupied.tscn"),
	"col": preload("res://scenes/environment/modules/support_column.tscn"),
	"hang": preload("res://scenes/environment/modules/support_suspension.tscn"),
	"server": preload("res://scenes/environment/modules/server_block.tscn"),
	"stack": preload("res://scenes/environment/modules/industrial_stack.tscn"),
	"util": preload("res://scenes/environment/modules/utility_tower.tscn"),
	"wall": preload("res://scenes/environment/modules/data_center_wall.tscn"),
	"pipes": preload("res://scenes/environment/modules/pipe_cluster.tscn"),
	"reactor": preload("res://scenes/environment/modules/prop_reactor.tscn"),
}

@export var capture_on_ready: bool = false
@export var camera_speed: float = 8.0
@export var camera_fast_mul: float = 2.4
@export var camera_look_sens: float = 0.0032

var _foreground: Node3D
var _midground: Node3D
var _background: Node3D
var _sentry: Node3D
var _bots: Array[Node3D] = []
var _fire_acc: float = 0.0
var _bot_index: int = 0
var _capture_done: bool = false
var _cam_user: bool = false
var _looking: bool = false
var _hero_home_pos: Vector3 = Vector3.ZERO
var _hero_home_basis: Basis = Basis.IDENTITY


func _ready() -> void:
	_setup_cameras()
	_foreground = _group("Foreground")
	_midground = _group("Midground")
	_background = _group("Background")
	_build_paths()
	_build_pads_and_heroes()
	_build_supports()
	_build_hotspot()
	_build_mid_dressing()
	_build_city_modules()
	_disable_shadows(_background)
	_dim_emissives(_background, 0.42)
	_build_city_masses()
	_build_abyss_lights()
	_build_atmosphere_fx()
	set_process(true)
	var args := OS.get_cmdline_user_args()
	if capture_on_ready or args.has("--capture-slice"):
		_run_capture()


func _process(delta: float) -> void:
	_aim_sentry()
	_move_camera(delta)
	_fire_acc += delta
	if _fire_acc >= 2.8:
		_fire_acc = 0.0
		_fire_once()


func _setup_cameras() -> void:
	var hero := get_node_or_null("HeroCamera") as Camera3D
	if hero:
		hero.fov = 28.0
		hero.position = Vector3(12.8, 15.4, 16.6)
		hero.look_at(Vector3(0.2, 3.35, 5.2), Vector3.UP)
		hero.current = true
		hero.far = 220.0
		hero.near = 0.18
		hero.attributes = null
		_hero_home_pos = hero.position
		_hero_home_basis = hero.basis
	var a := get_node_or_null("BeautyCameraA") as Camera3D
	if a:
		a.fov = 28.0
		a.position = Vector3(9.4, 12.2, 17.6)
		a.look_at(Vector3(0.15, 3.2, 5.0), Vector3.UP)
		a.current = false
		a.far = 220.0
		a.attributes = _make_dof(42.0, 28.0, 0.018)
	var b := get_node_or_null("BeautyCameraB") as Camera3D
	if b:
		b.fov = 30.0
		b.position = Vector3(8.6, 18.8, 14.2)
		b.look_at(Vector3(0.0, 3.6, 4.4), Vector3.UP)
		b.current = false
		b.far = 220.0
		b.attributes = null


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


func _along_x(x0: int, x1: int, z: int, y: float) -> void:
	var step := 1 if x1 >= x0 else -1
	var x := x0
	while true:
		_inst("path", _foreground, Vector3(float(x), y, float(z)), 90.0)
		if x == x1:
			break
		x += step


func _along_z(z0: int, z1: int, x: int, y: float) -> void:
	var step := 1 if z1 >= z0 else -1
	var z := z0
	while true:
		_inst("path", _foreground, Vector3(float(x), y, float(z)), 180.0 if step > 0 else 0.0)
		if z == z1:
			break
		z += step


func _build_paths() -> void:
	_along_x(-2, 1, -3, 0.0)
	_inst("corner", _foreground, Vector3(2.0, 0.0, -3.0), 0.0)
	_along_z(-2, -1, 2, 0.0)
	_inst("ramp", _foreground, Vector3(2.0, 0.0, 0.0), 180.0)
	_inst("plat_s", _foreground, Vector3(2.0, 3.0, 4.0), 0.0)
	_along_x(1, -2, 4, 3.0)
	_inst("bridge", _foreground, Vector3(0.0, 3.0, 6.0), 180.0)
	_inst("plat_s", _foreground, Vector3(0.0, 3.0, 8.0), 0.0)


func _build_pads_and_heroes() -> void:
	_inst("pad_o", _foreground, Vector3(0.0, 3.0, 8.0), 0.0)
	_sentry = SentryScene.instantiate() as Node3D
	_foreground.add_child(_sentry)
	_sentry.position = Vector3(0.0, 3.0, 8.0)
	_sentry.rotation.y = deg_to_rad(180.0)
	for p in [Vector3(0.6, 3.0, 4.0), Vector3(-0.7, 3.0, 4.0), Vector3(-1.9, 3.0, 4.0)]:
		var bot := BotScene.instantiate() as Node3D
		_foreground.add_child(bot)
		bot.position = p
		bot.rotation.y = deg_to_rad(-90.0)
		_bots.append(bot)


func _build_supports() -> void:
	for p in [
		Vector3(2.0, 0.0, -3.0), Vector3(2.0, 0.0, -1.0), Vector3(2.0, 3.0, 4.0),
		Vector3(-2.0, 3.0, 4.0), Vector3(0.0, 3.0, 8.0)
	]:
		_inst("col", _midground, p, 0.0)
	_inst("hang", _midground, Vector3(0.0, 3.0, 6.0), 0.0)


func _build_hotspot() -> void:
	_inst("reactor", _midground, Vector3(-5.8, 0.0, 1.6), 20.0, 0.85)
	var heat := OmniLight3D.new()
	heat.name = "ReactorHeat"
	heat.light_color = Color(1.0, 0.42, 0.16)
	heat.light_energy = 2.1
	heat.omni_range = 6.2
	heat.light_volumetric_fog_energy = 1.35
	heat.shadow_enabled = true
	heat.position = Vector3(-5.4, 1.8, 1.8)
	add_child(heat)


func _build_mid_dressing() -> void:
	_inst("pipes", _midground, Vector3(3.6, -0.2, -3.2), 90.0, 0.85)
	var deck_spot := SpotLight3D.new()
	deck_spot.name = "DeckKey"
	deck_spot.light_color = Color(1.0, 0.76, 0.52)
	deck_spot.light_energy = 5.4
	deck_spot.spot_range = 11.0
	deck_spot.spot_angle = 26.0
	deck_spot.shadow_enabled = true
	deck_spot.light_volumetric_fog_energy = 0.7
	deck_spot.position = Vector3(0.4, 11.4, 11.6)
	add_child(deck_spot)
	deck_spot.look_at(Vector3(0.0, 3.25, 7.6), Vector3.UP)
	var lane := OmniLight3D.new()
	lane.name = "LaneFill"
	lane.light_color = Color(0.70, 0.80, 0.94)
	lane.light_energy = 2.15
	lane.omni_range = 8.0
	lane.shadow_enabled = false
	lane.light_volumetric_fog_energy = 0.35
	lane.position = Vector3(0.2, 5.8, 4.2)
	add_child(lane)


func _build_city_modules() -> void:
	var specs := [
		["wall", Vector3(-7.0, 2.2, -14.0), 170.0, 2.6],
		["server", Vector3(10.5, 2.4, -13.0), 8.0, 2.1],
		["stack", Vector3(-15.5, 1.6, -8.0), 198.0, 2.0],
	]
	for s in specs:
		_inst(String(s[0]), _background, s[1], float(s[2]), float(s[3]))


func _build_city_masses() -> void:
	_dark_mass(Vector3(-3.0, 9.0, -16.5), Vector3(52.0, 34.0, 8.0), 8.0, Color(0.09, 0.11, 0.15))
	_dark_mass(Vector3(16.5, 10.0, -12.0), Vector3(14.0, 38.0, 10.0), -18.0, Color(0.07, 0.085, 0.12))
	_dark_mass(Vector3(-16.5, 8.0, -4.5), Vector3(10.0, 30.0, 16.0), 24.0, Color(0.08, 0.095, 0.13))
	_dark_mass(Vector3(7.0, 4.5, -20.0), Vector3(24.0, 24.0, 6.0), 4.0, Color(0.055, 0.07, 0.10))
	_window_band(Vector3(-14.0, 5.5, -12.2), 11, 6, 2.6, 2.3, Color(0.55, 0.72, 0.92), 2.4)
	_window_band(Vector3(2.0, 7.0, -12.4), 7, 5, 2.4, 2.2, Color(0.92, 0.58, 0.28), 1.35)
	_window_band(Vector3(14.0, 6.0, -8.2), 4, 8, 2.1, 2.4, Color(0.48, 0.66, 0.86), 1.8)
	_window_band(Vector3(-11.3, 1.8, 3.5), 7, 10, 2.15, 2.2, Color(0.52, 0.70, 0.90), 2.2, 90.0)
	var rim := DirectionalLight3D.new()
	rim.name = "CityRim"
	rim.light_color = Color(0.45, 0.58, 0.78)
	rim.light_energy = 0.28
	rim.shadow_enabled = false
	rim.light_volumetric_fog_energy = 0.15
	add_child(rim)
	rim.global_position = Vector3(-6.0, 18.0, -22.0)
	rim.look_at(Vector3(-2.0, 8.0, -14.0), Vector3.UP)


func _build_abyss_lights() -> void:
	for i in 4:
		var p := OmniLight3D.new()
		p.light_color = Color(0.22, 0.34, 0.48)
		p.light_energy = 0.55
		p.omni_range = 9.0
		p.shadow_enabled = false
		p.light_volumetric_fog_energy = 0.85
		p.position = Vector3(-4.0 + float(i) * 3.2, -8.5, 1.0 + float(i) * 1.4)
		add_child(p)


func _build_atmosphere_fx() -> void:
	_steam(Vector3(-5.6, 1.1, 1.7), Color(0.42, 0.20, 0.08), 8)
	var sparks := GPUParticles3D.new()
	sparks.name = "HotSparks"
	sparks.amount = 8
	sparks.lifetime = 1.1
	sparks.position = Vector3(-5.5, 0.7, 1.6)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, -1.0, 0)
	pm.scale_min = 0.015
	pm.scale_max = 0.035
	pm.color = Color(1.0, 0.5, 0.16)
	sparks.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	sm.radial_segments = 6
	sm.rings = 3
	sparks.draw_pass_1 = sm
	add_child(sparks)


func _steam(pos: Vector3, color: Color, amount: int) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 3.2
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.18
	pm.initial_velocity_max = 0.45
	pm.gravity = Vector3(0, 0.12, 0)
	pm.scale_min = 0.12
	pm.scale_max = 0.32
	pm.color = Color(color.r, color.g, color.b, 0.28)
	p.process_material = pm
	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	mesh.radial_segments = 6
	mesh.rings = 3
	p.draw_pass_1 = mesh
	add_child(p)


func _dark_mass(pos: Vector3, size: Vector3, yaw_deg: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.94
	mat.metallic = 0.08
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_background.add_child(mi)
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw_deg)


func _window_band(origin: Vector3, cols: int, rows: int, sx: float, sy: float, color: Color, energy: float, yaw_deg: float = 0.0) -> void:
	var holder := Node3D.new()
	_background.add_child(holder)
	holder.position = origin
	holder.rotation.y = deg_to_rad(yaw_deg)
	for r in rows:
		for c in cols:
			if ((r + c) % 3) == 0:
				continue
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1.35, 0.85, 0.12)
			mi.mesh = box
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = color * 0.35
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = energy * (0.45 if (c + r) % 5 == 0 else 1.0)
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
			mi.position = Vector3(float(c) * sx, float(r) * sy, 0.04)


func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(node as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if node is Light3D:
		(node as Light3D).shadow_enabled = false
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
					sm.emission = sm.emission.lerp(Color(0.18, 0.28, 0.38), 0.35)
			mi.set_surface_override_material(i, mat)
	for c in node.get_children():
		_dim_emissives(c, mul)


func _aim_sentry() -> void:
	if _sentry == null or _bots.is_empty():
		return
	var turret := _sentry.get_node_or_null("Turret") as Node3D
	if turret == null:
		turret = VisualSocketsScript.resolve(_sentry, "turret")
	var target := _bots[_bot_index % _bots.size()]
	if turret == null or target == null:
		return
	var look := target.global_position + Vector3(0, 0.4, 0)
	var origin := turret.global_position
	var flat := Vector3(look.x - origin.x, 0.0, look.z - origin.z)
	if flat.length() < 0.05:
		return
	turret.global_rotation.y = lerp_angle(turret.global_rotation.y, atan2(-flat.x, -flat.z), 0.06)


func _fire_once() -> void:
	if _sentry == null or _bots.is_empty():
		return
	if _sentry.has_method("play_fire_feedback"):
		_sentry.call("play_fire_feedback")
	var target := _bots[_bot_index % _bots.size()]
	_bot_index += 1
	if target == null:
		return
	var muzzle := VisualSocketsScript.resolve(_sentry, "muzzle")
	var from := _sentry.global_position + Vector3(0, 0.7, -0.4)
	if muzzle != null:
		from = muzzle.global_position
	var to := target.global_position + Vector3(0, 0.35, 0)
	_spawn_tracer(from, to)
	var impact := ImpactScene.instantiate() as Node3D
	add_child(impact)
	impact.global_position = to


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var mesh_i := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.01
	cap.height = maxf(0.1, from.distance_to(to))
	mesh_i.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.42)
	mat.emission_energy_multiplier = 3.2
	mat.albedo_color = Color(1.0, 0.85, 0.55, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_i.material_override = mat
	add_child(mesh_i)
	mesh_i.global_position = (from + to) * 0.5
	mesh_i.look_at(to, Vector3.UP)
	mesh_i.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tw := create_tween()
	tw.tween_property(mesh_i, "scale", Vector3(0.15, 0.15, 0.15), 0.1)
	tw.tween_callback(mesh_i.queue_free)


func _move_camera(delta: float) -> void:
	if capture_on_ready or OS.get_cmdline_user_args().has("--capture-slice"):
		return
	var cam := get_node_or_null("HeroCamera") as Camera3D
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
	_cam_user = true
	cam.current = true
	var flat_fwd := Vector3(cam.global_transform.basis.z.x, 0.0, cam.global_transform.basis.z.z)
	if flat_fwd.length_squared() < 0.0001:
		flat_fwd = Vector3(0.0, 0.0, 1.0)
	flat_fwd = flat_fwd.normalized()
	var right := Vector3.UP.cross(flat_fwd).normalized()
	var speed := camera_speed * (camera_fast_mul if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	cam.global_position += (right * ix - flat_fwd * iz + Vector3.UP * iy) * speed * delta


func _unhandled_input(event: InputEvent) -> void:
	if capture_on_ready or OS.get_cmdline_user_args().has("--capture-slice"):
		return
	var cam := get_node_or_null("HeroCamera") as Camera3D
	if cam == null:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_R or k.physical_keycode == KEY_R):
			cam.position = _hero_home_pos
			cam.basis = _hero_home_basis
			cam.current = true
			_cam_user = true
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_looking = mb.pressed
			_cam_user = true
			get_viewport().set_input_as_handled()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			cam.global_position += -cam.global_transform.basis.z * (1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.15)
			_cam_user = true
			cam.current = true
			get_viewport().set_input_as_handled()
	elif _looking and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
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
	await get_tree().create_timer(2.2).timeout
	await RenderingServer.frame_post_draw
	var dir := "res://artifacts/visual_previews"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	await _shot("HeroCamera", dir.path_join("slice_hero.png"))
	await _shot("HeroCamera", dir.path_join("slice_lookdev.png"))
	await _shot("BeautyCameraA", dir.path_join("slice_beauty_a.png"))
	await _shot("BeautyCameraB", dir.path_join("slice_beauty_b.png"))
	await _shot("HeroCamera", dir.path_join("slice_hero.png"))
	print("visual_slice: captured screenshots")
	if capture_on_ready or OS.get_cmdline_user_args().has("--capture-slice"):
		await get_tree().create_timer(0.2).timeout
		get_tree().quit()


func _shot(cam_name: String, path: String) -> void:
	var cam := get_node_or_null(cam_name) as Camera3D
	if cam == null:
		push_error("visual_slice: missing camera %s" % cam_name)
		return
	cam.current = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_error("visual_slice: no viewport image")
		return
	var abs_path := ProjectSettings.globalize_path(path)
	img.save_png(abs_path)
	print("visual_slice: wrote %s" % abs_path)

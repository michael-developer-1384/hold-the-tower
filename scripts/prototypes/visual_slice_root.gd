extends Node3D

## Visual target slice: composed industrial vertical map. No gameplay systems.

const SentryScene := preload("res://scenes/towers/visuals/sentry_visual.tscn")
const BotScene := preload("res://scenes/enemies/visuals/bot_visual.tscn")
const LavaScene := preload("res://scenes/towers/visuals/lava_tower_visual.tscn")
const GuardPostScene := preload("res://scenes/towers/visuals/guard_post_visual.tscn")
const ImpactScene := preload("res://scenes/visuals/fx/impact_burst.tscn")
const VisualSocketsScript := preload("res://scripts/visuals/visual_sockets.gd")

const MOD := {
	"path": preload("res://scenes/environment/modules/path_straight.tscn"),
	"corner": preload("res://scenes/environment/modules/path_corner.tscn"),
	"ramp": preload("res://scenes/environment/modules/path_ramp.tscn"),
	"bridge": preload("res://scenes/environment/modules/path_bridge.tscn"),
	"plat_s": preload("res://scenes/environment/modules/platform_small.tscn"),
	"plat_l": preload("res://scenes/environment/modules/platform_large.tscn"),
	"pad_e": preload("res://scenes/environment/modules/build_pad_empty.tscn"),
	"pad_r": preload("res://scenes/environment/modules/build_pad_recommended.tscn"),
	"pad_o": preload("res://scenes/environment/modules/build_pad_occupied.tscn"),
	"col": preload("res://scenes/environment/modules/support_column.tscn"),
	"hang": preload("res://scenes/environment/modules/support_suspension.tscn"),
	"server": preload("res://scenes/environment/modules/server_block.tscn"),
	"stack": preload("res://scenes/environment/modules/industrial_stack.tscn"),
	"util": preload("res://scenes/environment/modules/utility_tower.tscn"),
	"power": preload("res://scenes/environment/modules/power_core_tower.tscn"),
	"wall": preload("res://scenes/environment/modules/data_center_wall.tscn"),
	"pipes": preload("res://scenes/environment/modules/pipe_cluster.tscn"),
	"vents": preload("res://scenes/environment/modules/vent_cluster.tscn"),
	"frame": preload("res://scenes/environment/modules/support_frame.tscn"),
	"reactor": preload("res://scenes/environment/modules/prop_reactor.tscn"),
	"tank": preload("res://scenes/environment/modules/prop_tank.tscn"),
	"crane": preload("res://scenes/environment/modules/prop_crane.tscn"),
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
var _t: float = 0.0
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
	_build_city()
	_build_abyss_lights()
	_build_atmosphere_fx()
	_disable_shadows(_background)
	set_process(true)
	var args := OS.get_cmdline_user_args()
	if capture_on_ready or args.has("--capture-slice"):
		_run_capture()


func _process(delta: float) -> void:
	_t += delta
	_aim_sentry()
	_move_camera(delta)
	_idle_camera(delta)
	_fire_acc += delta
	if _fire_acc >= 1.35:
		_fire_acc = 0.0
		_fire_once()
	_nudge_bots(delta)


func _setup_cameras() -> void:
	var hero := get_node_or_null("HeroCamera") as Camera3D
	if hero:
		hero.fov = 34.0
		hero.position = Vector3(9.2, 10.4, 14.6)
		hero.look_at(Vector3(-0.4, 3.15, 5.4), Vector3.UP)
		hero.current = true
		hero.far = 140.0
		hero.near = 0.12
		_hero_home_pos = hero.position
		_hero_home_basis = hero.basis
	var a := get_node_or_null("BeautyCameraA") as Camera3D
	if a:
		a.fov = 34.0
		a.position = Vector3(3.2, 5.4, 13.2)
		a.look_at(Vector3(-0.4, 2.6, 4.2), Vector3.UP)
		a.current = false
		a.far = 140.0
	var b := get_node_or_null("BeautyCameraB") as Camera3D
	if b:
		b.fov = 42.0
		b.position = Vector3(-1.5, 16.5, 7.2)
		b.look_at(Vector3(-0.5, 2.8, 2.4), Vector3.UP)
		b.current = false
		b.far = 140.0


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
	# Floor 0: south run then east climb approach.
	_along_x(-4, 1, -3, 0.0)
	_inst("corner", _foreground, Vector3(2.0, 0.0, -3.0), 0.0)
	_along_z(-2, -1, 2, 0.0)
	# Ramp 0 -> 1: +Z, 4 m run, 3 m rise. Origin at downhill end.
	_inst("ramp", _foreground, Vector3(2.0, 0.0, 0.0), 180.0)
	# Floor 1: west run (combat lane).
	_inst("plat_s", _foreground, Vector3(2.0, 3.0, 4.0), 0.0)
	_along_x(1, -2, 4, 3.0)
	_inst("corner", _foreground, Vector3(-3.0, 3.0, 4.0), 90.0)
	_along_z(3, 2, -3, 3.0)
	# Bridge across a gap on floor 1 toward camera.
	_inst("bridge", _foreground, Vector3(0.0, 3.0, 6.0), 180.0)
	_inst("plat_s", _foreground, Vector3(0.0, 3.0, 8.0), 0.0)
	# Ramp 1 -> 2: -Z up to high deck.
	_inst("ramp", _foreground, Vector3(-3.0, 3.0, 1.5), 0.0)
	_inst("plat_l", _foreground, Vector3(-1.0, 6.0, -1.5), 0.0)


func _build_pads_and_heroes() -> void:
	_inst("pad_e", _foreground, Vector3(-2.0, 0.0, -2.0), 0.0)
	_inst("pad_r", _foreground, Vector3(0.0, 0.0, -2.0), 0.0)
	_inst("pad_e", _foreground, Vector3(-1.0, 0.0, -4.0), 0.0)
	# Hero sentry on floor 1, camera-side of the combat lane.
	_inst("pad_o", _foreground, Vector3(0.0, 3.0, 8.0), 0.0)
	_sentry = SentryScene.instantiate() as Node3D
	_foreground.add_child(_sentry)
	_sentry.position = Vector3(0.0, 3.0, 8.0)
	_sentry.rotation.y = deg_to_rad(180.0)
	_inst("pad_r", _foreground, Vector3(2.0, 3.0, 5.5), 0.0)
	_inst("pad_e", _foreground, Vector3(-2.0, 3.0, 5.5), 0.0)
	var gp := GuardPostScene.instantiate() as Node3D
	_foreground.add_child(gp)
	gp.position = Vector3(2.0, 3.0, 5.5)
	_inst("pad_e", _foreground, Vector3(0.5, 6.0, -1.5), 0.0)
	_inst("pad_r", _foreground, Vector3(-2.2, 6.0, -0.6), 0.0)
	var bots_xz := [
		Vector3(1.0, 3.0, 4.0),
		Vector3(0.0, 3.0, 4.0),
		Vector3(-1.0, 3.0, 4.0),
		Vector3(-2.0, 3.0, 4.0),
		Vector3(-3.0, 3.0, 3.0),
	]
	for p in bots_xz:
		var bot := BotScene.instantiate() as Node3D
		_foreground.add_child(bot)
		bot.position = p
		bot.rotation.y = deg_to_rad(-90.0)
		_bots.append(bot)


func _build_supports() -> void:
	var cols := [
		Vector3(-4.0, 0.0, -3.0), Vector3(-1.0, 0.0, -3.0), Vector3(2.0, 0.0, -3.0),
		Vector3(2.0, 0.0, -1.0), Vector3(2.0, 3.0, 4.0), Vector3(-3.0, 3.0, 4.0),
		Vector3(0.0, 3.0, 8.0), Vector3(-1.0, 6.0, -1.5), Vector3(1.0, 3.0, 4.0),
	]
	for p in cols:
		_inst("col", _midground, p, 0.0)
	for p in [Vector3(0.0, 3.0, 6.5), Vector3(2.0, 3.0, 4.0), Vector3(-3.0, 6.0, -1.5)]:
		_inst("hang", _midground, p, 45.0)


func _build_hotspot() -> void:
	_inst("reactor", _midground, Vector3(-6.2, 0.0, 1.2), 25.0)
	var lava := LavaScene.instantiate() as Node3D
	_midground.add_child(lava)
	lava.position = Vector3(-5.4, 0.55, 2.1)
	lava.scale = Vector3.ONE * 0.85
	_inst("tank", _midground, Vector3(-7.4, 0.0, -1.6), -20.0, 1.15)
	_inst("vents", _midground, Vector3(-4.6, 0.0, -2.8), 15.0)
	var heat := OmniLight3D.new()
	heat.name = "ReactorHeat"
	heat.light_color = Color(1.0, 0.38, 0.12)
	heat.light_energy = 3.4
	heat.omni_range = 7.0
	heat.shadow_enabled = true
	heat.position = Vector3(-6.0, 2.2, 1.4)
	add_child(heat)


func _build_mid_dressing() -> void:
	_inst("pipes", _midground, Vector3(4.5, 1.2, -2.0), 90.0, 1.4)
	_inst("pipes", _midground, Vector3(-4.0, 4.0, 6.0), 0.0, 1.2)
	_inst("vents", _midground, Vector3(3.6, 3.0, 6.8), -30.0)
	_inst("frame", _midground, Vector3(5.5, 0.0, 3.0), 20.0, 0.85)
	_inst("crane", _midground, Vector3(6.8, 0.0, -4.5), -40.0, 1.1)
	var deck_spot := SpotLight3D.new()
	deck_spot.name = "DeckKey"
	deck_spot.light_color = Color(1.0, 0.82, 0.62)
	deck_spot.light_energy = 5.4
	deck_spot.spot_range = 16.0
	deck_spot.spot_angle = 42.0
	deck_spot.shadow_enabled = true
	deck_spot.position = Vector3(1.5, 9.5, 7.5)
	add_child(deck_spot)
	deck_spot.look_at(Vector3(0.0, 3.0, 4.5), Vector3.UP)
	var cool := SpotLight3D.new()
	cool.name = "CoolRim"
	cool.light_color = Color(0.45, 0.72, 0.95)
	cool.light_energy = 2.4
	cool.spot_range = 18.0
	cool.spot_angle = 50.0
	cool.shadow_enabled = false
	cool.position = Vector3(-8.0, 11.0, 10.0)
	add_child(cool)
	cool.look_at(Vector3(0.0, 3.0, 3.0), Vector3.UP)
	var lane := OmniLight3D.new()
	lane.name = "LaneFill"
	lane.light_color = Color(0.85, 0.9, 1.0)
	lane.light_energy = 2.8
	lane.omni_range = 9.0
	lane.shadow_enabled = false
	lane.position = Vector3(0.0, 6.4, 4.2)
	add_child(lane)


func _build_city() -> void:
	# Windowed faces are authored on Blender +Y (Godot -Z). Yaw ~180 to face the camera.
	var specs := [
		["wall", Vector3(-7.0, -1.2, -12.0), 180.0, 2.2],
		["wall", Vector3(-16.0, -3.0, -4.0), 240.0, 2.0],
		["server", Vector3(-13.0, -2.0, -8.0), 195.0, 1.7],
		["server", Vector3(-11.0, -1.0, 7.0), 140.0, 1.5],
		["util", Vector3(-18.0, -4.0, 4.0), 200.0, 1.5],
		["util", Vector3(8.0, -5.0, -12.0), 20.0, 1.6],
		["stack", Vector3(-12.0, -1.5, 1.5), 175.0, 1.35],
		["stack", Vector3(7.0, -3.0, 12.0), 200.0, 1.5],
		["power", Vector3(-15.0, -2.5, -10.0), 8.0, 1.55],
		["power", Vector3(11.0, -4.0, -8.0), -40.0, 1.7],
		["frame", Vector3(-6.0, -0.5, -9.0), 15.0, 1.35],
		["server", Vector3(16.0, -8.0, 14.0), 210.0, 2.1],
		["wall", Vector3(4.0, -6.0, -16.0), 165.0, 2.4],
		["util", Vector3(-4.0, -7.0, -18.0), 180.0, 2.0],
	]
	for s in specs:
		_inst(String(s[0]), _background, s[1], float(s[2]), float(s[3]))
	for i in 10:
		var omni := OmniLight3D.new()
		omni.light_color = Color(0.45, 0.7, 1.0) if i % 3 else Color(1.0, 0.55, 0.25)
		omni.light_energy = 3.2
		omni.omni_range = 10.0
		omni.shadow_enabled = false
		omni.position = Vector3(-10.0 - float(i % 4) * 3.0, -1.0 + float(i) * 0.8, -6.0 + float(i) * 1.7)
		_background.add_child(omni)


func _build_abyss_lights() -> void:
	for i in 6:
		var p := OmniLight3D.new()
		p.light_color = Color(0.2, 0.35, 0.45)
		p.light_energy = 0.7
		p.omni_range = 5.0
		p.shadow_enabled = false
		p.position = Vector3(-2.0 + float(i) * 1.6, -8.0 - float(i % 3), 1.0 + float(i % 2) * 3.0)
		add_child(p)


func _build_atmosphere_fx() -> void:
	_steam(Vector3(-6.1, 1.3, 1.3), Color(0.45, 0.22, 0.08), 18)
	_steam(Vector3(-7.2, 2.6, -1.5), Color(0.55, 0.6, 0.62), 12)
	_steam(Vector3(2.0, 0.4, -3.0), Color(0.5, 0.55, 0.58), 8)
	var sparks := GPUParticles3D.new()
	sparks.name = "HotSparks"
	sparks.amount = 24
	sparks.lifetime = 1.4
	sparks.position = Vector3(-6.0, 0.8, 1.2)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 50.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(0, -1.2, 0)
	pm.scale_min = 0.02
	pm.scale_max = 0.05
	pm.color = Color(1.0, 0.55, 0.18)
	sparks.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	sm.radial_segments = 6
	sm.rings = 3
	sparks.draw_pass_1 = sm
	add_child(sparks)


func _steam(pos: Vector3, color: Color, amount: int) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 2.8
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 18.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, 0.15, 0)
	pm.scale_min = 0.15
	pm.scale_max = 0.45
	pm.color = Color(color.r, color.g, color.b, 0.35)
	p.process_material = pm
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 6
	mesh.rings = 3
	p.draw_pass_1 = mesh
	add_child(p)


func _disable_shadows(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is Light3D:
		(node as Light3D).shadow_enabled = false
	for c in node.get_children():
		_disable_shadows(c)


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
	var yaw := atan2(-flat.x, -flat.z)
	turret.global_rotation.y = lerp_angle(turret.global_rotation.y, yaw, 0.08)


func _nudge_bots(delta: float) -> void:
	for i in _bots.size():
		var bot := _bots[i]
		if bot == null:
			continue
		bot.position.x += sin(_t * 0.7 + float(i)) * delta * 0.15


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
	var dist := from.distance_to(to)
	cap.radius = 0.018
	cap.height = maxf(0.12, dist)
	mesh_i.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.82, 0.45)
	mat.emission_energy_multiplier = 8.0
	mat.albedo_color = Color(1.0, 0.9, 0.6)
	mesh_i.material_override = mat
	add_child(mesh_i)
	mesh_i.global_position = (from + to) * 0.5
	mesh_i.look_at(to, Vector3.UP)
	mesh_i.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tw := create_tween()
	tw.tween_property(mesh_i, "scale", Vector3(0.2, 0.2, 0.2), 0.12)
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
			var dir := -cam.global_transform.basis.z
			var step := 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.15
			cam.global_position += dir * step
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


func _idle_camera(delta: float) -> void:
	if _cam_user or capture_on_ready or OS.get_cmdline_user_args().has("--capture-slice"):
		return
	var hero := get_node_or_null("HeroCamera") as Camera3D
	if hero == null or not hero.current:
		return
	hero.position.x += sin(_t * 0.15) * delta * 0.02
	hero.position.y += cos(_t * 0.11) * delta * 0.015


func _run_capture() -> void:
	if _capture_done:
		return
	_capture_done = true
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	var dir := "res://artifacts/visual_previews"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	await _shot("HeroCamera", dir.path_join("slice_hero.png"))
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

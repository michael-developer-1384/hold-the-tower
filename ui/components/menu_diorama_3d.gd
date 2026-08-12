class_name MenuDiorama3D
extends Control

## Lightweight ambient 3D diorama for the main menu. Presentation only.

const SENTRY := preload("res://scenes/towers/visuals/sentry_visual.tscn")
const GUARD := preload("res://scenes/towers/visuals/guard_post_visual.tscn")
const BOT := preload("res://scenes/enemies/visuals/bot_visual.tscn")

var _viewport: SubViewport
var _camera: Camera3D
var _yaw: float = 0.35
var _enabled: bool = true


func _ready() -> void:
	custom_minimum_size = Vector2(420, 360)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.style_card_panel(panel)
	add_child(panel)
	var host := SubViewportContainer.new()
	host.stretch = true
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(host)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.size = Vector2i(720, 540)
	host.add_child(_viewport)
	_build_world()
	if typeof(SettingsManager) != TYPE_NIL:
		_enabled = not SettingsManager.reduced_motion()
		SettingsManager.settings_changed.connect(func(section: String) -> void:
			if section == "accessibility":
				_enabled = not SettingsManager.reduced_motion()
		)
	set_process(true)


func _process(delta: float) -> void:
	if not _enabled or _camera == null:
		return
	_yaw += delta * 0.10
	_camera.position = Vector3(sin(_yaw) * 9.5, 6.4, cos(_yaw) * 9.5)
	_camera.look_at(Vector3(0, 1.6, 0))


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035, 0.04, 0.055)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.22, 0.26, 0.30)
	e.ambient_light_energy = 0.38
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	_viewport.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 28, 0)
	light.light_color = Color(0.95, 0.97, 1.0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	_viewport.add_child(light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 4.5, 2.0)
	fill.light_color = UiTokens.ACCENT
	fill.light_energy = 0.35
	fill.omni_range = 12.0
	_viewport.add_child(fill)

	# Silhouette floors — darker, thinner, less "debug plate".
	for i in 3:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(5.8, 0.18, 3.8)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		var shade := 0.14 + i * 0.035
		mat.albedo_color = Color(shade, shade + 0.02, shade + 0.05)
		mat.roughness = 0.92
		mat.metallic = 0.08
		mesh.material_override = mat
		mesh.position = Vector3(0, i * 1.55, 0)
		_viewport.add_child(mesh)
		# Soft edge accent line
		var edge := MeshInstance3D.new()
		var edge_box := BoxMesh.new()
		edge_box.size = Vector3(5.85, 0.02, 0.06)
		edge.mesh = edge_box
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(0.2, 0.35, 0.28)
		em.emission_enabled = true
		em.emission = UiTokens.ACCENT * 0.35
		em.emission_energy_multiplier = 0.4
		edge.material_override = em
		edge.position = Vector3(0, i * 1.55 + 0.1, 1.9)
		_viewport.add_child(edge)

	_spawn(SENTRY, Vector3(-1.5, 0.28, 0.35), 1.05)
	_spawn(GUARD, Vector3(1.6, 1.82, -0.45), 1.0)
	_spawn(BOT, Vector3(0.15, 3.25, 0.55), 0.95)

	# Subtle dust particles
	var particles := GPUParticles3D.new()
	particles.amount = 18
	particles.lifetime = 6.0
	particles.position = Vector3(0, 2.0, 0)
	var mat_p := ParticleProcessMaterial.new()
	mat_p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat_p.emission_box_extents = Vector3(3.0, 2.5, 2.0)
	mat_p.gravity = Vector3(0, 0.02, 0)
	mat_p.initial_velocity_min = 0.02
	mat_p.initial_velocity_max = 0.08
	mat_p.scale_min = 0.02
	mat_p.scale_max = 0.05
	mat_p.color = Color(0.55, 0.7, 0.65, 0.25)
	particles.process_material = mat_p
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.03
	particle_mesh.height = 0.06
	particles.draw_pass_1 = particle_mesh
	_viewport.add_child(particles)

	_camera = Camera3D.new()
	_camera.fov = 36.0
	_viewport.add_child(_camera)
	_camera.position = Vector3(7.2, 6.0, 8.0)
	_camera.look_at(Vector3(0, 1.6, 0))


func _spawn(scene: PackedScene, pos: Vector3, scale_f: float = 1.0) -> void:
	if scene == null:
		return
	var n := scene.instantiate()
	if n is Node3D:
		var n3 := n as Node3D
		n3.position = pos
		n3.scale = Vector3.ONE * scale_f
	_viewport.add_child(n)

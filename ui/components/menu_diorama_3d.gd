class_name MenuDiorama3D
extends Control

## Lightweight ambient 3D diorama for the main menu.

const SENTRY := preload("res://scenes/towers/visuals/sentry_visual.tscn")
const GUARD := preload("res://scenes/towers/visuals/guard_post_visual.tscn")
const BOT := preload("res://scenes/enemies/visuals/bot_visual.tscn")

var _viewport: SubViewport
var _camera: Camera3D
var _yaw: float = 0.35
var _enabled: bool = true


func _ready() -> void:
	custom_minimum_size = Vector2(520, 420)
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
	_viewport.size = Vector2i(640, 480)
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
	_yaw += delta * 0.12
	_camera.position = Vector3(sin(_yaw) * 7.5, 5.2, cos(_yaw) * 7.5)
	_camera.look_at(Vector3(0, 1.2, 0))


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.4, 0.45)
	e.ambient_light_energy = 0.7
	env.environment = e
	_viewport.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, 35, 0)
	light.light_energy = 1.1
	_viewport.add_child(light)

	for i in 3:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(6.5, 0.25, 4.5)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.28 + i * 0.05, 0.30 + i * 0.04, 0.34)
		mesh.material_override = mat
		mesh.position = Vector3(0, i * 1.6, 0)
		_viewport.add_child(mesh)

	_spawn(SENTRY, Vector3(-1.6, 0.35, 0.4))
	_spawn(GUARD, Vector3(1.8, 1.95, -0.6))
	_spawn(BOT, Vector3(0.2, 3.45, 0.8))

	_camera = Camera3D.new()
	_camera.fov = 42.0
	_viewport.add_child(_camera)
	_camera.position = Vector3(5.5, 5.0, 6.5)
	_camera.look_at(Vector3(0, 1.2, 0))


func _spawn(scene: PackedScene, pos: Vector3) -> void:
	if scene == null:
		return
	var n := scene.instantiate()
	if n is Node3D:
		(n as Node3D).position = pos
	_viewport.add_child(n)

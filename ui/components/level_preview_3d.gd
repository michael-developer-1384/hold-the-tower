class_name LevelPreview3D
extends Control

## Presentation-only level preview. No GameManager / WaveManager / BuildSpots.

const TestLevelFactoryScript := preload("res://scripts/level/test_level_factory.gd")
const FloorRendererScript := preload("res://scripts/level/floor_renderer.gd")
const ConnectorRendererScript := preload("res://scripts/level/connector_renderer.gd")
const SENTRY := preload("res://scenes/towers/visuals/sentry_visual.tscn")
const GUARD := preload("res://scenes/towers/visuals/guard_post_visual.tscn")
const LAVA := preload("res://scenes/towers/visuals/lava_tower_visual.tscn")
const BOT := preload("res://scenes/enemies/visuals/bot_visual.tscn")

var _viewport: SubViewport
var _camera: Camera3D
var _world_root: Node3D
var _yaw: float = 0.55
var _enabled: bool = true
var _locked_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(320, 240)
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
	_viewport.size = Vector2i(640, 400)
	host.add_child(_viewport)
	_locked_label = Label.new()
	_locked_label.text = "?"
	_locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_locked_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_locked_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_locked_label.add_theme_font_size_override("font_size", 48)
	_locked_label.add_theme_color_override("font_color", UiTokens.MUTED)
	_locked_label.visible = false
	panel.add_child(_locked_label)
	if typeof(SettingsManager) != TYPE_NIL:
		_enabled = not SettingsManager.reduced_motion()
		SettingsManager.settings_changed.connect(func(section: String) -> void:
			if section == "accessibility":
				_enabled = not SettingsManager.reduced_motion()
		)
	set_process(true)


func _process(delta: float) -> void:
	if not _enabled or _camera == null or _locked_label.visible:
		return
	_yaw += delta * 0.18
	_camera.position = Vector3(sin(_yaw) * 14.0, 10.5, cos(_yaw) * 14.0)
	_camera.look_at(Vector3(0.0, 3.0, 0.0))


func show_level(level_id: String) -> void:
	_clear_world()
	# Future: resolve preview via LevelCatalog / a preview definition — do not grow if level_id == ...
	if level_id != "vertical_test":
		_locked_label.visible = true
		return
	_locked_label.visible = false
	_build_world()


func show_locked() -> void:
	_clear_world()
	_locked_label.visible = true


func _clear_world() -> void:
	if _viewport == null:
		return
	for c in _viewport.get_children():
		c.queue_free()
	_camera = null
	_world_root = null


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.04, 0.05, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.28, 0.32, 0.38)
	e.ambient_light_energy = 0.45
	env.environment = e
	_viewport.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, 40, 0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	_viewport.add_child(light)

	_world_root = Node3D.new()
	_world_root.name = "PreviewRoot"
	_viewport.add_child(_world_root)

	var path_mat := _mat(Color(0.32, 0.34, 0.38))
	var ramp_mat := _mat(Color(0.42, 0.36, 0.28))
	var level = TestLevelFactoryScript.create_level()

	var floors_root := Node3D.new()
	floors_root.name = "Floors"
	_world_root.add_child(floors_root)
	for floor_def in level.floors:
		var floor_node := Node3D.new()
		floor_node.name = str(floor_def.floor_id)
		floors_root.add_child(floor_node)
		FloorRendererScript.render(floor_node, floor_def, path_mat, false)

	var connectors_root := Node3D.new()
	connectors_root.name = "Connectors"
	_world_root.add_child(connectors_root)
	ConnectorRendererScript.render_all(connectors_root, level.connectors, ramp_mat)

	_spawn_core_proxy(level.core_transform)
	_spawn(SENTRY, Vector3(-2.2, 0.4, 0.5))
	_spawn(GUARD, Vector3(2.4, 3.4, -0.8))
	_spawn(LAVA, Vector3(0.0, 6.4, 3.8))
	_spawn(BOT, Vector3(0.0, 6.4, 0.6))

	_camera = Camera3D.new()
	_camera.fov = 38.0
	_viewport.add_child(_camera)
	_camera.position = Vector3(10.0, 10.5, 12.0)
	_camera.look_at(Vector3(0.0, 3.0, 0.0))


func _spawn_core_proxy(xform: Transform3D) -> void:
	var root := Node3D.new()
	root.name = "CoreProxy"
	root.transform = xform
	_world_root.add_child(root)
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	body.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.22, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.08, 0.08)
	mat.emission_energy_multiplier = 0.6
	body.material_override = mat
	root.add_child(body)


func _spawn(scene: PackedScene, pos: Vector3) -> void:
	if scene == null:
		return
	var n := scene.instantiate()
	if n is Node3D:
		(n as Node3D).position = pos
	_world_root.add_child(n)


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	return mat

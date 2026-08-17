extends Node3D

## Spawn gate: enemies walk through the arch. Timer and gold live on 2D face plates.

signal start_requested

const SimContextScript := preload("res://scripts/sim/sim_context.gd")
const StatIconsScript := preload("res://scripts/app/stat_icons.gd")
const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const MoneyDisplayScript := preload("res://scripts/app/money_display.gd")

const PILLAR_H := 1.42
const PATH_WAYPOINT_LIFT := 0.35

var _game: Node
var _timer_label: Label
var _button_label: Label
var _timer_icon: TextureRect
var _button_icon: TextureRect
var _button_body: StaticBody3D
var _button_mesh: MeshInstance3D
var _button_mat: StandardMaterial3D
var _hovering: bool = false


func setup_pose(spawn: Vector3, ahead: Vector3, surface_y: float = -9999.0) -> void:
	var along := ahead - spawn
	along.y = 0.0
	if along.length_squared() < 0.0001:
		along = Vector3(1.0, 0.0, 0.0)
	along = along.normalized()
	var planted_y := spawn.y - PATH_WAYPOINT_LIFT
	if surface_y > -9000.0:
		planted_y = surface_y
	# Local to TowerLevel: path points are authored in parent space.
	position = Vector3(spawn.x, planted_y, spawn.z) - along * 0.2
	look_at(global_position + along, Vector3.UP)
	_ensure_visuals()


func bind_game(game: Node) -> void:
	_game = game
	if _game != null and _game.has_signal("call_bonus_changed") and not _game.call_bonus_changed.is_connected(_on_clock):
		_game.call_bonus_changed.connect(_on_clock)
	if _game != null and _game.has_signal("wave_state_changed") and not _game.wave_state_changed.is_connected(_on_wave_state):
		_game.wave_state_changed.connect(_on_wave_state)
	_refresh_labels()


func _ready() -> void:
	_ensure_visuals()
	if Engine.is_editor_hint():
		_set_board(MoneyDisplayScript.PRE_MARKET, false, "START", false)
		return
	set_process(not SimContextScript.skip_presentation())


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or SimContextScript.skip_presentation():
		return
	_refresh_labels()


func _on_clock(_bonus: int, _remaining: float) -> void:
	_refresh_labels()


func _on_wave_state(_running: bool) -> void:
	_refresh_labels()


func _ensure_visuals() -> void:
	if get_node_or_null("PillarL") != null:
		_bind_face_refs()
		return

	var stone := _mat(Color(0.38, 0.36, 0.34))
	_add_box("PillarL", Vector3(0.16, PILLAR_H, 0.16), Vector3(-0.62, PILLAR_H * 0.5, 0.0), stone)
	_add_box("PillarR", Vector3(0.16, PILLAR_H, 0.16), Vector3(0.62, PILLAR_H * 0.5, 0.0), stone)
	var lintel_y := PILLAR_H + 0.08
	_add_box("Lintel", Vector3(1.52, 0.16, 0.2), Vector3(0.0, lintel_y, 0.0), stone)

	var plaque := _add_box("TimerPlaque", Vector3(1.20, 0.30, 0.05), Vector3(0.0, lintel_y, -0.13), _mat(Color(0.16, 0.17, 0.2)))
	var timer_face := _add_face_board(
		plaque,
		Vector2i(512, 128),
		Vector2(1.16, 0.29),
		StatIconsScript.clock_texture(),
		Color(0.95, 0.90, 0.70)
	)
	_timer_icon = timer_face["icon"]
	_timer_label = timer_face["label"]

	_button_mat = _mat(Color(0.22, 0.55, 0.38))
	_button_mat.emission_enabled = true
	_button_mat.emission = Color(0.12, 0.4, 0.22)
	_button_mat.emission_energy_multiplier = 0.8

	_button_body = StaticBody3D.new()
	_button_body.name = "Button"
	_button_body.position = Vector3(0.0, PILLAR_H * 0.52, -0.14)
	_button_body.collision_layer = 4
	_button_body.collision_mask = 0
	_button_body.input_ray_pickable = true
	add_child(_button_body)

	_button_mesh = MeshInstance3D.new()
	_button_mesh.name = "Plate"
	var plate := BoxMesh.new()
	plate.size = Vector3(0.92, 0.42, 0.07)
	_button_mesh.mesh = plate
	_button_mesh.material_override = _button_mat
	_button_body.add_child(_button_mesh)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.92, 0.42, 0.1)
	shape.shape = box
	_button_body.add_child(shape)

	var button_face := _add_face_board(
		_button_body,
		Vector2i(448, 192),
		Vector2(0.88, 0.40),
		StatIconsScript.coin_texture(),
		Color(1.0, 0.95, 0.80)
	)
	_button_icon = button_face["icon"]
	_button_label = button_face["label"]
	_set_board(MoneyDisplayScript.PRE_MARKET, false, "START", false)

	if not Engine.is_editor_hint():
		_button_body.mouse_entered.connect(_on_mouse_entered)
		_button_body.mouse_exited.connect(_on_mouse_exited)
		_button_body.input_event.connect(_on_input_event)


func _add_box(node_name: String, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _add_face_board(
	parent: Node3D,
	pixels: Vector2i,
	world_size: Vector2,
	icon_tex: Texture2D,
	font_color: Color
) -> Dictionary:
	var vp := SubViewport.new()
	vp.name = "FaceVP"
	vp.size = pixels
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.msaa_2d = Viewport.MSAA_2X
	vp.handle_input_locally = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(vp)

	var glyph := maxi(pixels.y - 12, 48)
	var font_size := int(float(glyph) * 0.72)

	var root := CenterContainer.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.custom_minimum_size = Vector2(pixels)
	vp.add_child(root)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(float(glyph) * 0.16))
	root.add_child(row)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = icon_tex
	icon.custom_minimum_size = Vector2(glyph, glyph)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var label := Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if UiStyleScript.THEME != null:
		label.theme = UiStyleScript.THEME
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", maxi(int(float(font_size) * 0.14), 8))
	row.add_child(label)

	var spr := Sprite3D.new()
	spr.name = "Face"
	spr.texture = vp.get_texture()
	spr.pixel_size = world_size.x / float(pixels.x)
	spr.position = Vector3(0.0, 0.0, -0.04)
	spr.rotation.y = PI
	spr.shaded = false
	spr.double_sided = true
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	spr.centered = true
	parent.add_child(spr)
	return {"icon": icon, "label": label}


func _bind_face_refs() -> void:
	_timer_label = get_node_or_null("TimerPlaque/FaceVP/Root/Row/Label") as Label
	_timer_icon = get_node_or_null("TimerPlaque/FaceVP/Root/Row/Icon") as TextureRect
	_button_label = get_node_or_null("Button/FaceVP/Root/Row/Label") as Label
	_button_icon = get_node_or_null("Button/FaceVP/Root/Row/Icon") as TextureRect
	_button_body = get_node_or_null("Button") as StaticBody3D
	_button_mesh = get_node_or_null("Button/Plate") as MeshInstance3D
	if _button_mesh:
		_button_mat = _button_mesh.material_override as StandardMaterial3D


func _set_board(timer_text: String, show_clock: bool, button_text: String, show_coin: bool) -> void:
	if _timer_label:
		_timer_label.text = timer_text
	if _timer_icon:
		_timer_icon.visible = show_clock
	if _button_label:
		_button_label.text = button_text
	if _button_icon:
		_button_icon.visible = show_coin
	_bump_face("TimerPlaque/FaceVP")
	_bump_face("Button/FaceVP")


func _bump_face(path: String) -> void:
	var vp := get_node_or_null(path) as SubViewport
	if vp:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	return mat


func _on_mouse_entered() -> void:
	_hovering = true
	_refresh_labels()


func _on_mouse_exited() -> void:
	_hovering = false
	_refresh_labels()


func _on_input_event(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if Engine.is_editor_hint() or _game == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
				return
			if _game.has_method("can_start_next_wave") and not bool(_game.call("can_start_next_wave")):
				return
			start_requested.emit()
			get_viewport().set_input_as_handled()


func _refresh_labels() -> void:
	if _timer_label == null or _button_label == null:
		return
	if _game == null or Engine.is_editor_hint():
		return
	var can_start := false
	if _game.has_method("can_start_next_wave"):
		can_start = bool(_game.call("can_start_next_wave"))
	var bonus := 0
	if _game.has_method("current_call_bonus"):
		bonus = int(_game.call("current_call_bonus"))
	var waves_started := int(_game.get("waves_started"))
	var ended := bool(_game.get("game_over")) or bool(_game.get("level_complete"))
	if ended:
		_set_board("", false, "", false)
		_set_button_lit(false)
		return
	if waves_started <= 0:
		_set_board(MoneyDisplayScript.PRE_MARKET, false, "START", false)
	elif can_start:
		if bonus > 0:
			_set_board(MoneyDisplayScript.PRE_MARKET, false, MoneyDisplayScript.usd_delta(bonus), true)
		else:
			_set_board(MoneyDisplayScript.PRE_MARKET, false, "NEXT", false)
	else:
		_set_board(MoneyDisplayScript.MARKET_OPEN, false, "WAIT", false)
	if _hovering and can_start:
		_set_board(
			_timer_label.text if _timer_label else MoneyDisplayScript.PRE_MARKET,
			_timer_icon.visible if _timer_icon else false,
			MoneyDisplayScript.OPENING_BELL,
			false
		)
	_set_button_lit(can_start, _hovering)


func _set_button_lit(enabled: bool, hover: bool = false) -> void:
	if _button_mat == null:
		return
	if enabled and hover:
		_button_mat.albedo_color = Color(0.38, 0.85, 0.52)
		_button_mat.emission_energy_multiplier = 1.4
	elif enabled:
		_button_mat.albedo_color = Color(0.22, 0.62, 0.4)
		_button_mat.emission_energy_multiplier = 0.9
	else:
		_button_mat.albedo_color = Color(0.28, 0.3, 0.32)
		_button_mat.emission_energy_multiplier = 0.15

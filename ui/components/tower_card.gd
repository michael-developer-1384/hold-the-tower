class_name TowerCard
extends PanelContainer

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const MoneyDisplayScript := preload("res://scripts/app/money_display.gd")
const FeatureCatalogScript := preload("res://scripts/meta/feature_catalog.gd")
const PreviewScene := preload("res://ui/components/entity_preview_3d.tscn")

enum Mode { GALLERY, BUILD, COMPACT }
enum EntityKind { TOWER, ENEMY }

signal card_pressed(entity_id: String)
signal card_selected(entity_id: String)
signal build_pressed(tower_id: String)

var entity_id: String = ""
var tower_id: String = ""
var _mode: int = Mode.GALLERY
var _kind: int = EntityKind.TOWER
var _def: Resource
var _build_btn: Button
var _quote_label: Label
var _quote: int = -1


func setup(
	def: Resource,
	mode: int = Mode.GALLERY,
	can_build: bool = true,
	live_quote: int = -1
) -> void:
	_def = def
	_mode = mode
	_quote = live_quote
	_kind = EntityKind.TOWER
	entity_id = str(def.tower_id) if def else ""
	tower_id = entity_id
	_rebuild(can_build)


func setup_enemy(def: Resource) -> void:
	_def = def
	_mode = Mode.GALLERY
	_kind = EntityKind.ENEMY
	entity_id = str(def.enemy_id) if def else ""
	tower_id = ""
	_rebuild(true)


func set_build_enabled(enabled: bool) -> void:
	if _build_btn != null:
		_build_btn.disabled = not enabled


func update_quote(live_quote: int, can_build: bool) -> void:
	_quote = live_quote
	if _quote_label != null and _def != null:
		var base := int(_def.cost)
		var pct := (float(live_quote) / float(base) - 1.0) * 100.0 if base > 0 else 0.0
		var move := "%+.1f%%" % pct
		_quote_label.text = "%s  ·  Base %s  ·  %s" % [
			MoneyDisplayScript.usd(live_quote),
			MoneyDisplayScript.usd(base),
			move,
		]
		_quote_label.add_theme_color_override(
			"font_color",
			UiTokens.SUCCESS if pct < -0.05 else UiTokens.DANGER if pct > 0.05 else UiTokens.MUTED
		)
	set_build_enabled(can_build)


func _rebuild(can_build: bool) -> void:
	for c in get_children():
		c.queue_free()
	if _def == null:
		return

	var coming_soon := bool(_def.get("coming_soon")) if "coming_soon" in _def else false
	var unlocked := not coming_soon
	if _kind == EntityKind.TOWER:
		unlocked = bool(_def.unlocked) and not coming_soon
		if typeof(ProfileManager) != TYPE_NIL:
			unlocked = unlocked and ProfileManager.is_tower_unlocked(entity_id)

	mouse_filter = Control.MOUSE_FILTER_STOP
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	UiStyleScript.style_card_panel(self, false, coming_soon or not unlocked)

	match _mode:
		Mode.BUILD, Mode.COMPACT:
			custom_minimum_size = Vector2(280, 84)
			size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_build_row(unlocked, can_build)
		_:
			custom_minimum_size = Vector2(220, 360)
			size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_gallery_column(unlocked, coming_soon)


func _preview(preview_size: Vector2) -> Control:
	var host := PanelContainer.new()
	host.custom_minimum_size = preview_size
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.13, 1.0)
	sb.set_corner_radius_all(6)
	host.add_theme_stylebox_override("panel", sb)
	var preview := PreviewScene.instantiate()
	preview.preview_size = Vector2i(int(preview_size.x), int(preview_size.y))
	preview.custom_minimum_size = preview_size
	preview.zoom = 1.55
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.auto_rotate = false
	host.add_child(preview)
	if _def != null:
		var scene: PackedScene = null
		if _def.has_method("preview_scene"):
			scene = _def.preview_scene(_use_kit_preview())
		elif _def.visual_scene != null:
			scene = _def.visual_scene
		if scene != null:
			preview.call_deferred("set_visual_scene", scene)
	return host


func _use_kit_preview() -> bool:
	if typeof(SettingsManager) == TYPE_NIL:
		return false
	return bool(SettingsManager.preview_uses_kit())


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not entity_id.is_empty():
			card_selected.emit(entity_id)


func set_gallery_selected(selected: bool) -> void:
	var coming_soon := bool(_def.get("coming_soon")) if _def != null and "coming_soon" in _def else false
	UiStyleScript.style_card_panel(self, selected, coming_soon)


func _feature_row() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	for feature in FeatureCatalogScript.resolve_ids(_def.feature_ids):
		row.add_child(UiStyleScript.make_feature_chip(str(feature.display_name)))
	return row


func _gallery_column(unlocked: bool, coming_soon: bool) -> void:
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(cv)

	cv.add_child(_preview(Vector2(200, 200)))
	cv.add_child(UiStyleScript.make_flat_label(str(_def.display_name), 18))
	cv.add_child(UiStyleScript.make_flat_label(str(_def.role), 12, true))
	var desc := UiStyleScript.make_label(str(_def.short_description), 12, true)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(desc)
	cv.add_child(_feature_row())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(spacer)

	if _kind == EntityKind.ENEMY:
		var stats: Dictionary = ProfileManager.get_enemy_lifetime(entity_id) if typeof(ProfileManager) != TYPE_NIL else {}
		cv.add_child(UiStyleScript.make_flat_label(
			"Seen %d · Killed %d · Leaks %d" % [
				int(stats.get("encountered", 0)),
				int(stats.get("killed", 0)),
				int(stats.get("leaks", 0)),
			],
			12,
			true
		))
		var open := UiStyleScript.make_button("OPEN DETAIL", 40)
		open.pressed.connect(func() -> void: card_pressed.emit(entity_id))
		cv.add_child(open)
	elif coming_soon:
		cv.add_child(UiStyleScript.make_flat_label("Coming soon", 12, true))
		var locked := UiStyleScript.make_button("LOCKED", 40)
		locked.disabled = true
		cv.add_child(locked)
	else:
		var stats: Dictionary = ProfileManager.get_tower_lifetime(entity_id) if typeof(ProfileManager) != TYPE_NIL else {}
		cv.add_child(UiStyleScript.make_flat_label(
			"Games %d · Dmg %d · Kills %d" % [
				int(stats.get("games_used", 0)),
				int(round(float(stats.get("damage_dealt", 0.0)))),
				int(stats.get("kills", 0)),
			],
			12,
			true
		))
		var open := UiStyleScript.make_button("OPEN DETAIL" if unlocked else "LOCKED", 40)
		open.disabled = not unlocked
		if unlocked:
			open.pressed.connect(func() -> void: card_pressed.emit(entity_id))
		cv.add_child(open)


func _build_row(unlocked: bool, can_build: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	row.add_child(_preview(Vector2(96, 64)))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	info.add_child(UiStyleScript.make_flat_label(str(_def.display_name), 15))
	info.add_child(UiStyleScript.make_flat_label(str(_def.role), 12, true))
	_quote_label = UiStyleScript.make_flat_label("", 12, true)
	info.add_child(_quote_label)
	update_quote(_quote if _quote > 0 else int(_def.cost), can_build)

	_build_btn = UiStyleScript.make_button("BUILD" if unlocked else "LOCKED", 40)
	_build_btn.custom_minimum_size = Vector2(96, 40)
	_build_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_build_btn.disabled = (not unlocked) or (not can_build)
	if unlocked:
		_build_btn.pressed.connect(func() -> void: build_pressed.emit(entity_id))
	row.add_child(_build_btn)

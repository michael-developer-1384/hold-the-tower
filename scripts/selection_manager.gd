extends Node

signal spot_selection_changed(spot: Node)
signal tower_selection_changed(tower: Node3D)
signal hover_floor_changed(floor_index: int)

var selected_build_spot: Node = null
var selected_tower: Node3D = null
var hovered_floor: int = -1

var _camera_rig: Node3D
var _tower_level: Node3D
var _build_manager: Node
var _range_viz: Node3D
var _telemetry: Node
var _interaction_enabled: bool = true
var _path_pickers: Array = []


func setup(
	camera_rig: Node3D,
	tower_level: Node3D,
	build_manager: Node,
	range_viz: Node3D,
	telemetry: Node
) -> void:
	_camera_rig = camera_rig
	_tower_level = tower_level
	_build_manager = build_manager
	_range_viz = range_viz
	_telemetry = telemetry

	if tower_level.has_method("get_path_pickers"):
		_path_pickers = tower_level.call("get_path_pickers")
	_wire_path_pickers()

	if build_manager and build_manager.has_method("get_spots"):
		for spot in build_manager.call("get_spots"):
			_wire_spot(spot)

	if build_manager and build_manager.has_signal("tower_built"):
		build_manager.tower_built.connect(_on_tower_built)


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if not enabled:
		clear_all()
		set_hover_floor(-1)


func _wire_spot(spot: Node) -> void:
	if spot.has_signal("spot_clicked") and not spot.spot_clicked.is_connected(_on_spot_clicked):
		spot.spot_clicked.connect(_on_spot_clicked)
	if spot.has_signal("spot_hovered") and not spot.spot_hovered.is_connected(_on_spot_hovered):
		spot.spot_hovered.connect(_on_spot_hovered)


func _wire_path_pickers() -> void:
	for picker in _path_pickers:
		if not is_instance_valid(picker):
			continue
		if picker.has_signal("path_clicked") and not picker.path_clicked.is_connected(_on_path_clicked):
			picker.path_clicked.connect(_on_path_clicked)
		if picker.has_signal("path_hovered") and not picker.path_hovered.is_connected(_on_path_hovered):
			picker.path_hovered.connect(_on_path_hovered)


func _wire_tower(tower: Node3D) -> void:
	if tower.has_signal("tower_clicked") and not tower.tower_clicked.is_connected(_on_tower_clicked):
		tower.tower_clicked.connect(_on_tower_clicked)
	if tower.has_signal("tower_hovered") and not tower.tower_hovered.is_connected(_on_tower_hovered):
		tower.tower_hovered.connect(_on_tower_hovered)


func _on_tower_built(_spot: Node, tower: Node3D) -> void:
	_wire_tower(tower)
	selected_build_spot = null
	spot_selection_changed.emit(null)


func focus_floor(index: int) -> void:
	if _camera_rig and _camera_rig.has_method("set_focus_floor"):
		_camera_rig.call("set_focus_floor", index)


func set_hover_floor(index: int) -> void:
	if hovered_floor == index:
		return
	hovered_floor = index
	if _tower_level and _tower_level.has_method("set_hover_floor"):
		_tower_level.call("set_hover_floor", index)
	hover_floor_changed.emit(index)


func select_build_spot(spot: Node) -> void:
	if not _interaction_enabled or spot == null:
		return
	clear_tower_selection()
	var floor_index: int = int(spot.get("floor_index"))
	focus_floor(floor_index)
	if _build_manager and _build_manager.has_method("set_selected_spot"):
		_build_manager.call("set_selected_spot", spot)
	selected_build_spot = spot
	print("Build spot selected: %s" % spot.get("spot_id"))
	spot_selection_changed.emit(spot)


func select_tower(tower: Node3D) -> void:
	if not _interaction_enabled or tower == null:
		return
	clear_spot_selection()
	var floor_index: int = int(tower.get("floor_index"))
	focus_floor(floor_index)
	if selected_tower != null and is_instance_valid(selected_tower) and selected_tower.has_method("set_selected"):
		selected_tower.call("set_selected", false)
	selected_tower = tower
	if tower.has_method("set_selected"):
		tower.call("set_selected", true)
	if _range_viz and _range_viz.has_method("show_for_tower"):
		_range_viz.call("show_for_tower", tower)
	if _telemetry and _telemetry.has_method("log_event"):
		_telemetry.call("log_event", "tower_selected", {
			"tower_runtime_id": tower.get("runtime_id"),
			"floor_id": tower.get("floor_id"),
		})
	tower_selection_changed.emit(tower)


func clear_spot_selection() -> void:
	if _build_manager and _build_manager.has_method("clear_selected_spot"):
		_build_manager.call("clear_selected_spot")
	selected_build_spot = null
	spot_selection_changed.emit(null)


func clear_tower_selection() -> void:
	if selected_tower != null and is_instance_valid(selected_tower) and selected_tower.has_method("set_selected"):
		selected_tower.call("set_selected", false)
	selected_tower = null
	if _range_viz and _range_viz.has_method("hide_all"):
		_range_viz.call("hide_all")
	tower_selection_changed.emit(null)


func clear_all() -> void:
	clear_spot_selection()
	clear_tower_selection()


func refresh_range() -> void:
	if selected_tower != null and is_instance_valid(selected_tower) and _range_viz:
		_range_viz.call("show_for_tower", selected_tower)


func _on_spot_clicked(spot: Node) -> void:
	if not _interaction_enabled:
		return
	if _camera_rig and _camera_rig.has_method("is_orbiting") and _camera_rig.call("is_orbiting"):
		return
	if bool(spot.get("occupied")):
		var tower = spot.get("tower_instance")
		if tower != null and is_instance_valid(tower):
			select_tower(tower)
		return
	select_build_spot(spot)


func _on_spot_hovered(spot: Node, hovered: bool) -> void:
	if hovered:
		set_hover_floor(int(spot.get("floor_index")))
	else:
		set_hover_floor(-1)


func _on_tower_clicked(tower: Node3D) -> void:
	if not _interaction_enabled:
		return
	if _camera_rig and _camera_rig.has_method("is_orbiting") and _camera_rig.call("is_orbiting"):
		return
	select_tower(tower)


func _on_tower_hovered(tower: Node3D, hovered: bool) -> void:
	if hovered:
		set_hover_floor(int(tower.get("floor_index")))
	else:
		set_hover_floor(-1)


func _on_path_clicked(picker: Node) -> void:
	if not _interaction_enabled:
		return
	if _camera_rig and _camera_rig.has_method("is_orbiting") and _camera_rig.call("is_orbiting"):
		return
	var floor_index: int = int(picker.get_meta("floor_index", 0))
	focus_floor(floor_index)
	clear_all()


func _on_path_hovered(picker: Node, hovered: bool) -> void:
	if hovered:
		set_hover_floor(int(picker.get_meta("floor_index", -1)))
	else:
		set_hover_floor(-1)


func _unhandled_input(event: InputEvent) -> void:
	if not _interaction_enabled:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _camera_rig and _camera_rig.has_method("is_orbiting") and _camera_rig.call("is_orbiting"):
		return
	clear_all()

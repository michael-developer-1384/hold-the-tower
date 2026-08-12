extends Node

signal selection_changed(spot: Node)
signal build_failed(reason: String)
signal tower_built(spot: Node, tower: Node3D)

const BASIC_TOWER_SCENE := preload("res://scenes/towers/basic_tower.tscn")
const TowerDefScript := preload("res://scripts/towers/tower_definition.gd")

var selected_spot: Node = null
var build_enabled: bool = true

var _spots: Array = []
var _focus_floor: int = 0
var _basic_tower: Resource
var _game_manager: Node
var _tower_parent: Node3D


func _ready() -> void:
	get_viewport().physics_object_picking = true
	_basic_tower = TowerDefScript.new()
	_basic_tower.tower_id = "basic_tower"
	_basic_tower.display_name = "Basic Tower"
	_basic_tower.cost = 100
	_basic_tower.scene = BASIC_TOWER_SCENE


func setup(game_manager: Node, tower_parent: Node3D) -> void:
	_game_manager = game_manager
	_tower_parent = tower_parent


func register_spots(spots: Array) -> void:
	_spots = spots
	for spot in _spots:
		if spot.has_signal("spot_clicked"):
			if not spot.spot_clicked.is_connected(_on_spot_clicked):
				spot.spot_clicked.connect(_on_spot_clicked)
	set_focus_floor(_focus_floor)


func set_focus_floor(index: int) -> void:
	_focus_floor = index
	for spot in _spots:
		if not is_instance_valid(spot):
			continue
		var interactive: bool = build_enabled and int(spot.get("floor_index")) == _focus_floor
		if spot.has_method("set_interactive"):
			spot.call("set_interactive", interactive)
	if selected_spot != null and is_instance_valid(selected_spot):
		if int(selected_spot.get("floor_index")) != _focus_floor:
			clear_selection()


func set_build_enabled(enabled: bool) -> void:
	build_enabled = enabled
	set_focus_floor(_focus_floor)
	if not enabled:
		clear_selection()


func get_basic_tower_def() -> Resource:
	return _basic_tower


func can_build() -> bool:
	if not build_enabled or selected_spot == null or not is_instance_valid(selected_spot):
		return false
	if bool(selected_spot.get("occupied")):
		return false
	if _game_manager == null or _basic_tower == null:
		return false
	return int(_game_manager.get("gold")) >= int(_basic_tower.cost)


func build_selected() -> bool:
	if not can_build():
		if _game_manager and int(_game_manager.get("gold")) < int(_basic_tower.cost):
			build_failed.emit("Not enough gold")
			print("Build failed: Not enough gold")
		return false
	var spot := selected_spot
	if not _game_manager.call("spend_gold", int(_basic_tower.cost)):
		build_failed.emit("Not enough gold")
		return false

	var tower := (_basic_tower.scene as PackedScene).instantiate() as Node3D
	_tower_parent.add_child(tower)
	tower.global_transform = spot.global_transform
	tower.add_to_group("towers")
	if spot.has_method("set_occupied"):
		spot.call("set_occupied", true, tower)
	print("Built %s at %s for %d gold" % [_basic_tower.display_name, spot.get("spot_id"), _basic_tower.cost])
	tower_built.emit(spot, tower)
	clear_selection()
	return true


func clear_selection() -> void:
	if selected_spot != null and is_instance_valid(selected_spot) and selected_spot.has_method("set_selected"):
		selected_spot.call("set_selected", false)
	selected_spot = null
	selection_changed.emit(null)


func _on_spot_clicked(spot: Node) -> void:
	if not build_enabled:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		return
	if bool(spot.get("occupied")):
		return
	if selected_spot == spot:
		return
	if selected_spot != null and is_instance_valid(selected_spot) and selected_spot.has_method("set_selected"):
		selected_spot.call("set_selected", false)
	selected_spot = spot
	if spot.has_method("set_selected"):
		spot.call("set_selected", true)
	print("Build spot selected: %s" % spot.get("spot_id"))
	selection_changed.emit(spot)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		return
	# Deselect when clicking empty world (spot clicks are handled / marked handled).
	if selected_spot != null:
		clear_selection()

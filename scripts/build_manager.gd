extends Node

signal build_failed(reason: String)
signal tower_built(spot: Node, tower: Node3D)

const BASIC_TOWER_SCENE := preload("res://scenes/towers/basic_tower.tscn")
const TowerDefScript := preload("res://scripts/towers/tower_definition.gd")

var build_enabled: bool = true
var selected_spot: Node = null

var _spots: Array = []
var _basic_tower: Resource
var _game_manager: Node
var _tower_parent: Node3D
var _next_tower_id: int = 1
var _selection_manager: Node


func _ready() -> void:
	get_viewport().physics_object_picking = true
	_basic_tower = TowerDefScript.new()
	_basic_tower.tower_id = "basic_tower"
	_basic_tower.display_name = "Basic Tower"
	_basic_tower.cost = 100
	_basic_tower.scene = BASIC_TOWER_SCENE
	_basic_tower.base_range = 4.0
	_basic_tower.base_damage = 25.0
	_basic_tower.base_fire_interval = 0.8
	_basic_tower.upgrade_cost = 150
	_basic_tower.upgraded_range = 5.5
	_basic_tower.max_level = 2


func setup(game_manager: Node, tower_parent: Node3D, selection_manager: Node = null) -> void:
	_game_manager = game_manager
	_tower_parent = tower_parent
	_selection_manager = selection_manager


func register_spots(spots: Array) -> void:
	_spots = spots
	for spot in _spots:
		if spot.has_method("set_interactive"):
			spot.call("set_interactive", build_enabled)


func set_build_enabled(enabled: bool) -> void:
	build_enabled = enabled
	for spot in _spots:
		if is_instance_valid(spot) and spot.has_method("set_interactive"):
			spot.call("set_interactive", enabled)
	if not enabled:
		clear_selected_spot()


func get_basic_tower_def() -> Resource:
	return _basic_tower


func get_spots() -> Array:
	return _spots


func set_selected_spot(spot: Node) -> void:
	if selected_spot != null and is_instance_valid(selected_spot) and selected_spot.has_method("set_selected"):
		selected_spot.call("set_selected", false)
	selected_spot = spot
	if spot != null and is_instance_valid(spot) and spot.has_method("set_selected"):
		spot.call("set_selected", true)


func clear_selected_spot() -> void:
	set_selected_spot(null)


func can_build() -> bool:
	if not build_enabled or selected_spot == null or not is_instance_valid(selected_spot):
		return false
	if bool(selected_spot.get("occupied")):
		return false
	if _game_manager == null or _basic_tower == null:
		return false
	return int(_game_manager.get("gold")) >= int(_basic_tower.cost)


func build_selected() -> Node3D:
	if not can_build():
		if _game_manager and int(_game_manager.get("gold")) < int(_basic_tower.cost):
			build_failed.emit("Not enough gold")
			print("Build failed: Not enough gold")
		return null
	var spot := selected_spot
	if not _game_manager.call("spend_gold", int(_basic_tower.cost)):
		build_failed.emit("Not enough gold")
		return null

	var tower := (_basic_tower.scene as PackedScene).instantiate() as Node3D
	_tower_parent.add_child(tower)
	tower.global_transform = spot.global_transform
	var runtime_id := "T%04d" % _next_tower_id
	_next_tower_id += 1
	if tower.has_method("configure_built"):
		tower.call(
			"configure_built",
			runtime_id,
			_basic_tower,
			str(spot.get("floor_id")),
			int(spot.get("floor_index")),
			str(spot.get("spot_id"))
		)
	else:
		tower.set("runtime_id", runtime_id)
		tower.set("floor_id", spot.get("floor_id"))
		tower.set("floor_index", spot.get("floor_index"))
		tower.set("build_spot_id", spot.get("spot_id"))
		tower.set_meta("floor_index", spot.get("floor_index"))
	tower.add_to_group("towers")
	if spot.has_method("set_occupied"):
		spot.call("set_occupied", true, tower)
	print("Built %s at %s for %d gold" % [_basic_tower.display_name, spot.get("spot_id"), _basic_tower.cost])
	tower_built.emit(spot, tower)
	clear_selected_spot()
	return tower


func can_upgrade(tower: Node3D) -> bool:
	if not build_enabled or tower == null or not is_instance_valid(tower):
		return false
	var level: int = int(tower.get("level"))
	if level >= int(_basic_tower.max_level):
		return false
	return int(_game_manager.get("gold")) >= int(_basic_tower.upgrade_cost)


func upgrade_tower(tower: Node3D) -> bool:
	if not can_upgrade(tower):
		return false
	var before: float = float(tower.get("attack_range"))
	var from_level: int = int(tower.get("level"))
	if not _game_manager.call("spend_gold", int(_basic_tower.upgrade_cost)):
		return false
	if tower.has_method("apply_range_upgrade"):
		tower.call("apply_range_upgrade", float(_basic_tower.upgraded_range))
	else:
		tower.set("level", from_level + 1)
		tower.set("attack_range", float(_basic_tower.upgraded_range))
	print("Upgraded %s to level %d (range %.1f -> %.1f)" % [
		tower.get("runtime_id"), tower.get("level"), before, tower.get("attack_range")
	])
	return true

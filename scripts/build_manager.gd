extends Node

signal build_failed(reason: String)
signal tower_built(spot: Node, tower: Node3D)

const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")

var build_enabled: bool = true
var selected_spot: Node = null

var _spots: Array = []
var _defs: Array = []
var _basic_tower: Resource
var _game_manager: Node
var _tower_parent: Node3D
var _next_tower_id: int = 1
var _selection_manager: Node


func _ready() -> void:
	get_viewport().physics_object_picking = true
	_defs = TowerCatalogScript.create_all()
	_basic_tower = TowerCatalogScript.find_by_id(_defs, "basic_tower")


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


func get_tower_defs() -> Array:
	return _defs


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


func can_build(def: Resource = null) -> bool:
	if not build_enabled or selected_spot == null or not is_instance_valid(selected_spot):
		return false
	if bool(selected_spot.get("occupied")):
		return false
	if _game_manager == null:
		return false
	if def == null:
		def = _basic_tower
	if def == null:
		return false
	return int(_game_manager.get("gold")) >= int(def.cost)


func build_selected(def: Resource = null) -> Node3D:
	if def == null:
		def = _basic_tower
	if not can_build(def):
		if _game_manager and def and int(_game_manager.get("gold")) < int(def.cost):
			build_failed.emit("Not enough gold")
			print("Build failed: Not enough gold")
		return null
	var spot := selected_spot
	if not _game_manager.call("spend_gold", int(def.cost)):
		build_failed.emit("Not enough gold")
		return null

	var tower := (def.scene as PackedScene).instantiate() as Node3D
	_tower_parent.add_child(tower)
	tower.global_transform = spot.global_transform
	var runtime_id := "T%04d" % _next_tower_id
	_next_tower_id += 1
	if tower.has_method("configure_built"):
		tower.call(
			"configure_built",
			runtime_id,
			def,
			str(spot.get("floor_id")),
			int(spot.get("floor_index")),
			str(spot.get("spot_id"))
		)
	else:
		tower.set("runtime_id", runtime_id)
		tower.set("tower_type", def.tower_id)
		tower.set("floor_id", spot.get("floor_id"))
		tower.set("floor_index", spot.get("floor_index"))
		tower.set("build_spot_id", spot.get("spot_id"))
		tower.set_meta("floor_index", spot.get("floor_index"))
	tower.add_to_group("towers")
	if spot.has_method("set_occupied"):
		spot.call("set_occupied", true, tower)
	print("Built %s at %s for %d gold" % [def.display_name, spot.get("spot_id"), def.cost])
	tower_built.emit(spot, tower)
	clear_selected_spot()
	return tower


func can_upgrade(tower: Node3D) -> bool:
	if not build_enabled or tower == null or not is_instance_valid(tower):
		return false
	if str(tower.get("tower_type")) != "basic_tower":
		return false
	if _basic_tower == null:
		return false
	var level: int = int(tower.get("level"))
	if level >= int(_basic_tower.max_level):
		return false
	return int(_game_manager.get("gold")) >= int(_basic_tower.upgrade_cost)


func upgrade_tower(tower: Node3D) -> bool:
	if not can_upgrade(tower):
		return false
	var before: float = float(tower.get("attack_range")) if "attack_range" in tower else float(tower.call("get_range_value"))
	var from_level: int = int(tower.get("level"))
	if not _game_manager.call("spend_gold", int(_basic_tower.upgrade_cost)):
		return false
	if tower.has_method("apply_range_upgrade"):
		tower.call("apply_range_upgrade", float(_basic_tower.upgraded_range))
	else:
		tower.set("level", from_level + 1)
		tower.set("attack_range", float(_basic_tower.upgraded_range))
	print("Upgraded %s to level %d (range %.1f -> %.1f)" % [
		tower.get("runtime_id"), tower.get("level"), before, tower.call("get_range_value") if tower.has_method("get_range_value") else tower.get("attack_range")
	])
	return true

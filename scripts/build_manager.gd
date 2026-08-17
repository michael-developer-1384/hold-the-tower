extends Node

signal build_failed(reason: String)
signal tower_built(spot: Node, tower: Node3D)

const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
const BlueprintResolverScript := preload("res://scripts/meta/blueprint_resolver.gd")
const AudioBridgeScript := preload("res://scripts/app/audio_bridge.gd")
const SimContextScript := preload("res://scripts/sim/sim_context.gd")

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
			build_failed.emit("Insufficient funds")
			SimContextScript.log_msg("Build failed: Insufficient funds")
		return null
	var spot := selected_spot
	if not _game_manager.call("spend_gold", int(def.cost)):
		build_failed.emit("Insufficient funds")
		return null
	if typeof(RunManager) != TYPE_NIL:
		RunManager.note_gold_spent(int(def.cost))

	var tower := _instantiate_tower(def, spot, false)
	if tower == null:
		return null
	SimContextScript.log_msg("Built %s at %s for %d gold (bp=%s)" % [
		def.display_name, spot.get("spot_id"), def.cost, str(tower.get("blueprint_id"))
	])
	clear_selected_spot()
	return tower


func build_at_spot(spot_id: String, tower_id: String) -> Node3D:
	var spot := find_spot_by_id(spot_id)
	if spot == null:
		return null
	var def = TowerCatalogScript.find_by_id(_defs, tower_id)
	if def == null:
		return null
	var prev := selected_spot
	selected_spot = spot
	var tower := build_selected(def)
	if tower == null:
		selected_spot = prev
	return tower


func find_tower_by_runtime_id(runtime_id: String) -> Node3D:
	if _tower_parent == null:
		return null
	for t in _tower_parent.get_tree().get_nodes_in_group("towers"):
		if t != null and is_instance_valid(t) and str(t.get("runtime_id")) == runtime_id:
			return t as Node3D
	return null


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


func get_upgrade_range_bonus() -> float:
	if _basic_tower and "upgrade_range_bonus" in _basic_tower:
		return float(_basic_tower.upgrade_range_bonus)
	return 1.5


func find_spot_by_id(spot_id: String) -> Node:
	for spot in _spots:
		if is_instance_valid(spot) and str(spot.get("spot_id")) == spot_id:
			return spot
	return null


func set_next_tower_id(value: int) -> void:
	_next_tower_id = maxi(value, 1)


func get_next_tower_id() -> int:
	return _next_tower_id


func clear_all_towers() -> void:
	if _tower_parent == null:
		return
	for t in _tower_parent.get_tree().get_nodes_in_group("towers"):
		if t != null and is_instance_valid(t):
			t.free()
	for spot in _spots:
		if spot != null and is_instance_valid(spot):
			if spot.has_method("set_occupied"):
				spot.call("set_occupied", false)
			elif "occupied" in spot:
				spot.set("occupied", false)
			if "tower" in spot:
				spot.set("tower", null)


## Rebuild a tower without charging gold (session restore).
func restore_tower_free(spot_id: String, tower_type: String, tower_level: int = 1, gold_invested: int = 0, runtime_id: String = "") -> Node3D:
	var spot := find_spot_by_id(spot_id)
	if spot == null or bool(spot.get("occupied")):
		return null
	var def = TowerCatalogScript.find_by_id(_defs, tower_type)
	if def == null:
		return null
	var prev_spot := selected_spot
	selected_spot = spot
	if not runtime_id.is_empty():
		def.set_meta("forced_runtime_id", runtime_id)
	var tower := _instantiate_tower(def, spot, true)
	if def.has_meta("forced_runtime_id"):
		def.remove_meta("forced_runtime_id")
	selected_spot = prev_spot
	if tower == null:
		return null
	if gold_invested > 0:
		tower.set("gold_invested", gold_invested)
	if tower_type == "basic_tower" and tower_level >= 2:
		var bonus := get_upgrade_range_bonus()
		var before: float = float(tower.get("attack_range")) if "attack_range" in tower else float(tower.call("get_range_value"))
		var new_range := before + bonus
		if tower.has_method("apply_range_upgrade"):
			tower.call("apply_range_upgrade", new_range)
		else:
			tower.set("level", 2)
			tower.set("attack_range", new_range)
	return tower


func _instantiate_tower(def: Resource, spot: Node, free: bool) -> Node3D:
	if spot == null or def == null:
		return null
	var tower_id := str(def.tower_id)
	var allocations := {}
	var blueprint_id := "research"
	var blueprint_name := "Research"
	if typeof(RunManager) != TYPE_NIL:
		allocations = RunManager.get_research_allocations(tower_id)
		var labeled := RunManager.get_active_blueprint_id(tower_id)
		if not labeled.is_empty() and labeled != "research":
			blueprint_id = labeled
			blueprint_name = RunManager.get_active_blueprint_name(tower_id)
	elif typeof(ProfileManager) != TYPE_NIL:
		allocations = ProfileManager.get_tower_research_allocations(tower_id)
	var resolved: Dictionary = BlueprintResolverScript.resolve(tower_id, {
		"id": blueprint_id,
		"display_name": blueprint_name,
		"allocations": allocations,
	})
	var runtime_scene: PackedScene = def.runtime_scene if def.runtime_scene != null else def.scene
	var tower := runtime_scene.instantiate() as Node3D
	_tower_parent.add_child(tower)
	tower.global_transform = spot.global_transform
	var runtime_id := str(def.get_meta("forced_runtime_id", "")) if def != null and def.has_meta("forced_runtime_id") else ""
	if runtime_id.is_empty():
		runtime_id = "T%04d" % _next_tower_id
		_next_tower_id += 1
	else:
		var n := int(runtime_id.trim_prefix("T"))
		_next_tower_id = maxi(_next_tower_id, n + 1)
	if tower.has_method("configure_built"):
		tower.call(
			"configure_built",
			runtime_id,
			def,
			str(spot.get("floor_id")),
			int(spot.get("floor_index")),
			str(spot.get("spot_id")),
			resolved
		)
	tower.set("blueprint_id", blueprint_id)
	tower.set("resolved_stats", resolved)
	tower.set("gold_invested", 0 if free else int(def.cost))
	tower.add_to_group("towers")
	if spot.has_method("set_occupied"):
		spot.call("set_occupied", true, tower)
	tower_built.emit(spot, tower)
	# Live placement only — restore_tower_free passes free=true.
	if not free:
		AudioBridgeScript.play_3d("tower_build", tower.global_position)
	return tower


func upgrade_tower(tower: Node3D) -> bool:
	if not can_upgrade(tower):
		return false
	var before: float = float(tower.get("attack_range")) if "attack_range" in tower else float(tower.call("get_range_value"))
	var from_level: int = int(tower.get("level"))
	var cost := int(_basic_tower.upgrade_cost)
	if not _game_manager.call("spend_gold", cost):
		return false
	if typeof(RunManager) != TYPE_NIL:
		RunManager.note_gold_spent(cost)
	var bonus := get_upgrade_range_bonus()
	var new_range := before + bonus
	if tower.has_method("apply_range_upgrade"):
		tower.call("apply_range_upgrade", new_range)
	else:
		tower.set("level", from_level + 1)
		tower.set("attack_range", new_range)
	if "gold_invested" in tower:
		tower.set("gold_invested", int(tower.get("gold_invested")) + cost)
	SimContextScript.log_msg("Upgraded %s to level %d (range %.1f -> %.1f)" % [
		tower.get("runtime_id"), tower.get("level"), before,
		tower.call("get_range_value") if tower.has_method("get_range_value") else tower.get("attack_range")
	])
	return true

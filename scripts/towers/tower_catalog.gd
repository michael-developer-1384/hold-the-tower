class_name TowerCatalog
extends RefCounted

## Builds the prototype tower definitions.

const TowerDefScript := preload("res://scripts/towers/tower_definition.gd")


static func create_all() -> Array:
	var defs: Array = []
	defs.append(_basic())
	defs.append(_guard_post())
	return defs


static func find_by_id(defs: Array, tower_id: String) -> Resource:
	for def in defs:
		if str(def.tower_id) == tower_id:
			return def
	return null


static func _basic() -> Resource:
	var def = TowerDefScript.new()
	def.tower_id = "basic_tower"
	def.display_name = "Basic Tower"
	def.cost = 100
	def.description = "3D ranged tower"
	def.scene = preload("res://scenes/towers/basic_tower.tscn")
	def.base_range = 4.0
	def.base_damage = 25.0
	def.base_fire_interval = 0.8
	def.upgrade_cost = 150
	def.upgraded_range = 5.5
	def.max_level = 2
	return def


static func _guard_post() -> Resource:
	var def = TowerDefScript.new()
	def.tower_id = "guard_post"
	def.display_name = "Guard Post"
	def.cost = 120
	def.description = "Local melee blockers"
	def.scene = preload("res://scenes/towers/guard_post.tscn")
	def.base_range = 2.5
	def.base_damage = 20.0
	def.base_fire_interval = 0.8
	def.upgrade_cost = 0
	def.upgraded_range = 2.5
	def.max_level = 1
	return def

class_name EnemyCatalog
extends RefCounted

const EnemyDefScript := preload("res://scripts/enemies/enemy_definition.gd")


static func create_all() -> Array:
	var defs: Array = []
	defs.append(_bot())
	return defs


static func find_by_id(defs: Array, enemy_id: String) -> Resource:
	for def in defs:
		if str(def.enemy_id) == enemy_id:
			return def
	return null


static func get_bot() -> Resource:
	return find_by_id(create_all(), "bot")


static func _bot() -> Resource:
	var def = EnemyDefScript.new()
	def.enemy_id = "bot"
	def.display_name = "Bot"
	def.short_description = "Graybox path follower"
	def.long_description = "The prototype lane runner. Follows the path, fights guards in melee, and leaks core HP if it reaches the end."
	def.role = "Runner"
	def.runtime_scene = preload("res://scenes/enemies/enemy.tscn")
	def.visual_scene = preload("res://scenes/enemies/visuals/bot_visual.tscn")
	def.feature_ids = PackedStringArray(["path_follower", "melee", "leaker"])
	def.base_max_health = 100.0
	def.base_move_speed = 2.2
	def.base_melee_damage = 12.0
	def.base_melee_interval = 0.85
	def.reward = 10
	def.stat_metric_keys = PackedStringArray(["encountered", "killed", "leaks", "damage_taken", "blocked"])
	def.unlocked = true
	def.coming_soon = false
	return def

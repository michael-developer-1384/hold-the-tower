class_name TowerCatalog
extends RefCounted

## Builds the prototype tower definitions.

const TowerDefScript := preload("res://scripts/towers/tower_definition.gd")


static func create_all() -> Array:
	var defs: Array = []
	defs.append(_sentry())
	defs.append(_guard_post())
	defs.append(_lava_tower())
	return defs


static func find_by_id(defs: Array, tower_id: String) -> Resource:
	for def in defs:
		if str(def.tower_id) == tower_id:
			return def
	return null


static func unlocked_buildable(defs: Array = []) -> Array:
	var source: Array = defs if not defs.is_empty() else create_all()
	var out: Array = []
	for def in source:
		if bool(def.unlocked) and not bool(def.coming_soon) and def.runtime_scene != null:
			out.append(def)
	return out


static func _sentry() -> Resource:
	var def = TowerDefScript.new()
	def.tower_id = "basic_tower"
	def.display_name = "Sentry"
	def.short_description = "Paper-hands ranged turret"
	def.long_description = "A 3D ranged sentry that retargets the highest-progress enemy every shot cycle. Upgrade once in-match for more range."
	def.role = "Ranged"
	def.cost = 100
	def.runtime_scene = preload("res://scenes/towers/basic_tower.tscn")
	def.visual_scene = preload("res://scenes/towers/visuals/sentry_visual.tscn")
	def.feature_ids = PackedStringArray(["paper_hands", "3d_targeting", "projectile"])
	def.base_range = 4.0
	def.base_damage = 25.0
	def.base_fire_interval = 0.8
	def.upgrade_cost = 150
	def.upgrade_range_bonus = 1.5
	def.upgraded_range = 5.5
	def.max_level = 2
	def.can_in_run_upgrade = true
	def.research_stat_ids = PackedStringArray(["damage", "range", "fire_interval", "projectile_speed"])
	def.stat_metric_keys = PackedStringArray([
		"times_built", "kills", "damage_dealt", "shots", "hits", "buying_power_invested"
	])
	def.unlocked = true
	def.coming_soon = false
	def.range_shape = "SPHERE_3D"
	def.unit_count = 1
	return def


static func _guard_post() -> Resource:
	var def = TowerDefScript.new()
	def.tower_id = "guard_post"
	def.display_name = "Guard Post"
	def.short_description = "Diamond-hands melee blockers"
	def.long_description = "Spawns two guards that hold 1:1 melee engages, block path progress, and respawn after falling."
	def.role = "Melee"
	def.cost = 120
	def.runtime_scene = preload("res://scenes/towers/guard_post.tscn")
	def.visual_scene = preload("res://scenes/towers/visuals/guard_post_visual.tscn")
	def.feature_ids = PackedStringArray(["diamond_hands", "blocker", "melee", "respawn", "regeneration"])
	def.base_range = 2.5
	def.base_damage = 20.0
	def.base_fire_interval = 0.8
	def.upgrade_cost = 0
	def.upgrade_range_bonus = 0.0
	def.upgraded_range = 2.5
	def.max_level = 1
	def.can_in_run_upgrade = false
	def.research_stat_ids = PackedStringArray([
		"guard_hp", "guard_damage", "guard_attack_interval", "defense_radius",
		"healing_rate", "healing_delay", "respawn_time"
	])
	def.stat_metric_keys = PackedStringArray([
		"times_built", "kills", "damage_dealt", "guards_died", "guards_respawned",
		"enemies_blocked", "buying_power_invested"
	])
	def.unlocked = true
	def.coming_soon = false
	def.range_shape = "FLOOR_DISC"
	def.unit_count = 2
	return def


static func _lava_tower() -> Resource:
	var def = TowerDefScript.new()
	def.tower_id = "lava_tower"
	def.display_name = "Meltdown"
	def.short_description = "DCA liquidation that contagions downward"
	def.long_description = "Keeps pouring onto the path in front of it. Liquidation spreads, slips off the book, and can infect lower floors."
	def.role = "Area"
	def.cost = 130
	def.runtime_scene = preload("res://scenes/towers/lava_tower.tscn")
	def.visual_scene = preload("res://scenes/towers/visuals/lava_tower_visual.tscn")
	def.feature_ids = PackedStringArray(["lava_flow", "cross_floor", "always_on"])
	def.base_range = 2.5
	def.base_damage = 10.0
	def.base_fire_interval = 1.0
	def.upgrade_cost = 0
	def.upgrade_range_bonus = 0.0
	def.upgraded_range = 2.5
	def.max_level = 1
	def.can_in_run_upgrade = false
	def.research_stat_ids = PackedStringArray(["lava_damage", "pour_rate", "flow_rate", "lava_lifetime"])
	def.stat_metric_keys = PackedStringArray([
		"times_built", "kills", "damage_dealt", "buying_power_invested"
	])
	def.unlocked = true
	def.coming_soon = false
	def.range_shape = "FLOOR_DISC"
	def.unit_count = 1
	return def

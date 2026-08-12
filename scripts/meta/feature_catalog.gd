class_name FeatureCatalog
extends RefCounted

const FeatureDef := preload("res://scripts/meta/gameplay_feature_definition.gd")

static var _cache: Dictionary = {}


static func get_all() -> Array:
	_ensure()
	var out: Array = []
	for feature_id in _cache.keys():
		out.append(_cache[feature_id])
	return out


static func get_feature(feature_id: String) -> Resource:
	_ensure()
	return _cache.get(feature_id, null)


static func resolve_ids(feature_ids: PackedStringArray) -> Array:
	var out: Array = []
	for feature_id in feature_ids:
		var def := get_feature(str(feature_id))
		if def != null:
			out.append(def)
	return out


static func _ensure() -> void:
	if not _cache.is_empty():
		return
	_register("paper_hands", "PAPER HANDS", "Retargets the highest-progress enemy each shot cycle.", "targeting")
	_register("diamond_hands", "DIAMOND HANDS", "Guards hold a 1:1 engage until the fight ends.", "targeting")
	_register("3d_targeting", "3D TARGETING", "Aims in full 3D space, not only on the floor plane.", "targeting")
	_register("projectile", "PROJECTILE", "Fires a physical projectile that travels to the target.", "combat")
	_register("blocker", "BLOCKER", "Stops path followers while engaged in melee.", "combat")
	_register("melee", "MELEE", "Deals close-range damage in contact fights.", "combat")
	_register("respawn", "RESPAWN", "Fallen units return after a short delay.", "sustain")
	_register("regeneration", "REGENERATION", "Recovers health while out of combat.", "sustain")
	_register("path_follower", "PATH FOLLOWER", "Moves along the lane toward the core.", "movement")
	_register("leaker", "LEAKER", "Damages the core if it reaches the end.", "threat")


static func _register(feature_id: String, display_name: String, short_description: String, category: String) -> void:
	var def := FeatureDef.new()
	def.feature_id = feature_id
	def.display_name = display_name
	def.short_description = short_description
	def.category = category
	_cache[feature_id] = def

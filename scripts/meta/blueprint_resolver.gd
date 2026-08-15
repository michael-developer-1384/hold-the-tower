class_name BlueprintResolver
extends RefCounted

const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
const ResearchConfigScript := preload("res://scripts/meta/research_config.gd")
const ResearchResolverScript := preload("res://scripts/meta/research_resolver.gd")


## Resolve catalog base + research allocations into runtime tower stats. Does not mutate catalog.
static func resolve(tower_id: String, blueprint: Dictionary = {}) -> Dictionary:
	var allocations: Dictionary = blueprint.get("allocations", {})
	if allocations.is_empty() and blueprint.has("params"):
		allocations = ResearchResolverScript.allocations_from_params(tower_id, blueprint.get("params", {}))
	if allocations.is_empty():
		allocations = ResearchConfigScript.zero_allocations(tower_id)
	allocations = ResearchResolverScript.normalize_allocations(tower_id, allocations)
	var params: Dictionary = ResearchResolverScript.params_from_allocations(tower_id, allocations)

	var defs: Array = TowerCatalogScript.create_all()
	var def = TowerCatalogScript.find_by_id(defs, tower_id)
	var resolved := {}

	match tower_id:
		"basic_tower":
			resolved = {
				"damage": float(params.get("damage", 25.0)),
				"range": float(params.get("range", 4.0)),
				"fire_interval": float(params.get("fire_interval", 0.8)),
				"projectile_speed": float(params.get("projectile_speed", 28.0)),
				"cost": int(def.cost) if def else 100,
			}
		"guard_post":
			resolved = {
				"guard_hp": float(params.get("guard_hp", 100.0)),
				"guard_damage": float(params.get("guard_damage", 20.0)),
				"guard_attack_interval": float(params.get("guard_attack_interval", 0.8)),
				"defense_radius": float(params.get("defense_radius", 2.5)),
				"healing_rate": float(params.get("healing_rate", 10.0)),
				"healing_delay": float(params.get("healing_delay", 2.0)),
				"respawn_time": float(params.get("respawn_time", 8.0)),
				"guard_count": 2,
				"cost": int(def.cost) if def else 120,
			}
		"lava_tower":
			resolved = {
				"lava_damage": float(params.get("lava_damage", 10.0)),
				"pour_rate": float(params.get("pour_rate", 1.2)),
				"flow_rate": float(params.get("flow_rate", 0.45)),
				"lava_lifetime": float(params.get("lava_lifetime", 8.0)),
				"range": float(def.base_range) if def else 2.5,
				"cost": int(def.cost) if def else 130,
			}
		_:
			resolved = params.duplicate(true)

	resolved["tower_id"] = tower_id
	resolved["blueprint_id"] = str(blueprint.get("id", ""))
	resolved["blueprint_name"] = str(blueprint.get("display_name", ""))
	resolved["allocations"] = allocations.duplicate(true)
	return resolved


static func catalog_base_snapshot(tower_id: String) -> Dictionary:
	return resolve(tower_id, {
		"id": "base",
		"display_name": "Base",
		"allocations": ResearchConfigScript.zero_allocations(tower_id),
	})

class_name TowerDefinition
extends Resource

@export var tower_id: String = ""
@export var display_name: String = ""
@export var short_description: String = ""
@export var long_description: String = ""
@export var role: String = ""
@export var cost: int = 0
@export var runtime_scene: PackedScene
@export var visual_scene: PackedScene
@export var feature_ids: PackedStringArray = PackedStringArray()
@export var base_range: float = 4.0
@export var base_damage: float = 25.0
@export var base_fire_interval: float = 0.8
@export var upgrade_cost: int = 0
@export var upgrade_range_bonus: float = 0.0
@export var upgraded_range: float = 0.0
@export var max_level: int = 1
@export var can_in_run_upgrade: bool = false
@export var research_stat_ids: PackedStringArray = PackedStringArray()
@export var stat_metric_keys: PackedStringArray = PackedStringArray()
@export var unlocked: bool = true
@export var coming_soon: bool = false

## Deprecated alias for runtime_scene (one-release compatibility).
var scene: PackedScene:
	get:
		return runtime_scene
	set(value):
		runtime_scene = value

## Short description alias used by older UI.
var description: String:
	get:
		return short_description
	set(value):
		short_description = value

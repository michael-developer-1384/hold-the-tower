class_name EnemyDefinition
extends Resource

@export var enemy_id: String = ""
@export var display_name: String = ""
@export var short_description: String = ""
@export var long_description: String = ""
@export var role: String = ""
@export var runtime_scene: PackedScene
@export var visual_scene: PackedScene
@export var feature_ids: PackedStringArray = PackedStringArray()
@export var base_max_health: float = 100.0
@export var base_move_speed: float = 2.2
@export var base_melee_damage: float = 12.0
@export var base_melee_interval: float = 0.85
@export var reward: int = 10
@export var stat_metric_keys: PackedStringArray = PackedStringArray()
@export var unlocked: bool = true
@export var coming_soon: bool = false

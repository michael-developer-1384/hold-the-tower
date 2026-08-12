class_name TowerDefinition
extends Resource

@export var tower_id: String = "basic_tower"
@export var display_name: String = "Basic Tower"
@export var cost: int = 100
@export var scene: PackedScene
@export var base_range: float = 4.0
@export var base_damage: float = 25.0
@export var base_fire_interval: float = 0.8
@export var upgrade_cost: int = 150
@export var upgraded_range: float = 5.5
@export var max_level: int = 2

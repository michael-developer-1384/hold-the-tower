extends Node

@onready var tower_level: Node3D = $"../TowerLevel"
@onready var wave_manager: Node = $"../WaveManager"
@onready var camera_rig: Node3D = $"../CameraRig"
@onready var hud: CanvasLayer = $"../HUD"

var _core: Node3D
var _alive_enemies: int = 0


func _ready() -> void:
	print("HoldTheTower prototype started")
	await get_tree().process_frame

	if tower_level.has_method("get_enemy_path"):
		var path: PackedVector3Array = tower_level.get_enemy_path()
		wave_manager.setup(path, tower_level.get_enemy_container())
	if tower_level.has_method("get_core"):
		_core = tower_level.get_core()
		if _core and _core.has_signal("health_changed"):
			_core.health_changed.connect(_on_core_health_changed)
			if hud.has_method("set_core_health"):
				hud.set_core_health(int(_core.get("health")))

	if camera_rig.has_signal("view_changed"):
		camera_rig.view_changed.connect(_on_view_changed)
		if tower_level.has_method("update_wall_visibility"):
			tower_level.update_wall_visibility(camera_rig.view_index)

	wave_manager.enemy_spawned.connect(_on_enemy_spawned)
	wave_manager.start_wave()
	_update_enemy_hud()


func _on_view_changed(view_index: int) -> void:
	if tower_level.has_method("update_wall_visibility"):
		tower_level.update_wall_visibility(view_index)


func _on_enemy_spawned(enemy: Node3D) -> void:
	_alive_enemies += 1
	_update_enemy_hud()
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
	if enemy.has_signal("reached_core"):
		enemy.reached_core.connect(_on_enemy_reached_core)


func _on_enemy_died(_enemy: Node3D) -> void:
	_alive_enemies = max(_alive_enemies - 1, 0)
	_update_enemy_hud()


func _on_enemy_reached_core(_enemy: Node3D) -> void:
	_alive_enemies = max(_alive_enemies - 1, 0)
	_update_enemy_hud()
	if _core and _core.has_method("take_hit"):
		_core.take_hit(1)


func _on_core_health_changed(current_health: int) -> void:
	if hud.has_method("set_core_health"):
		hud.set_core_health(current_health)


func _update_enemy_hud() -> void:
	if hud.has_method("set_enemy_count"):
		hud.set_enemy_count(_alive_enemies)

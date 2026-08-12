extends Node

signal gold_changed(value: int)
signal core_hp_changed(value: int)
signal enemies_alive_changed(value: int)
signal wave_changed(value: int)
signal wave_state_changed(running: bool)
signal game_over_changed(active: bool)
signal level_complete_changed(active: bool)

@export var starting_gold: int = 300
@export var enemy_kill_reward: int = 20

@onready var tower_level: Node3D = $"../TowerLevel"
@onready var wave_manager: Node = $"../WaveManager"
@onready var camera_rig: Node3D = $"../CameraRig"
@onready var hud: CanvasLayer = $"../HUD"
@onready var build_manager: Node = $"../BuildManager"

var gold: int = 0
var core_hp: int = 20
var current_wave: int = 1
var active_wave: int = 0
var enemies_alive: int = 0
var wave_running: bool = false
var game_over: bool = false
var level_complete: bool = false

var _core: Node3D
var _spawn_finished: bool = false


func _ready() -> void:
	print("HoldTheTower prototype started")
	await get_tree().process_frame

	gold = starting_gold
	gold_changed.emit(gold)

	if tower_level.has_method("get_enemy_path"):
		wave_manager.setup(tower_level.get_enemy_path(), tower_level.get_enemy_container())

	if tower_level.has_method("get_core"):
		_core = tower_level.get_core()
		if _core and _core.has_signal("health_changed"):
			_core.health_changed.connect(_on_core_health_changed)
			core_hp = int(_core.get("health"))
			core_hp_changed.emit(core_hp)
		if _core and _core.has_signal("destroyed"):
			_core.destroyed.connect(_on_core_destroyed)

	if camera_rig.has_method("setup_floors") and tower_level.has_method("get_focus_points"):
		camera_rig.call("setup_floors", tower_level.get_floor_count(), tower_level.get_focus_points())

	if camera_rig.has_signal("focus_changed"):
		camera_rig.focus_changed.connect(_on_focus_changed)
		_on_focus_changed(int(camera_rig.get("focus_floor")))

	var towers_root: Node3D = tower_level
	if tower_level.has_method("get_towers_root"):
		towers_root = tower_level.call("get_towers_root")
	if build_manager and build_manager.has_method("setup"):
		build_manager.call("setup", self, towers_root)
	if tower_level.has_method("get_build_spots") and build_manager.has_method("register_spots"):
		build_manager.call("register_spots", tower_level.call("get_build_spots"))

	wave_manager.enemy_spawned.connect(_on_enemy_spawned)
	if wave_manager.has_signal("wave_spawn_finished"):
		wave_manager.wave_spawn_finished.connect(_on_wave_spawn_finished)

	if hud.has_method("bind_game"):
		hud.call("bind_game", self, build_manager)

	wave_changed.emit(current_wave)
	wave_state_changed.emit(false)
	enemies_alive_changed.emit(0)
	print("Wave %d ready" % current_wave)


func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


func start_next_wave() -> void:
	if game_over or level_complete or wave_running:
		return
	if current_wave > wave_manager.call("get_wave_count"):
		return
	_spawn_finished = false
	active_wave = current_wave
	if wave_manager.call("start_wave", current_wave):
		wave_running = true
		wave_state_changed.emit(true)


func restart() -> void:
	get_tree().reload_current_scene()


func _on_focus_changed(floor_index: int) -> void:
	if tower_level.has_method("set_focus_floor"):
		tower_level.set_focus_floor(floor_index)
	if build_manager and build_manager.has_method("set_focus_floor"):
		build_manager.call("set_focus_floor", floor_index)
	if hud.has_method("set_focus_floor"):
		hud.set_focus_floor(floor_index + 1)


func _on_enemy_spawned(enemy: Node3D) -> void:
	enemies_alive += 1
	enemies_alive_changed.emit(enemies_alive)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
	if enemy.has_signal("reached_core"):
		enemy.reached_core.connect(_on_enemy_reached_core)


func _on_enemy_died(_enemy: Node3D) -> void:
	enemies_alive = max(enemies_alive - 1, 0)
	enemies_alive_changed.emit(enemies_alive)
	if not game_over:
		add_gold(enemy_kill_reward)
		print("Enemy killed, +%d gold" % enemy_kill_reward)
	_try_complete_wave()


func _on_enemy_reached_core(_enemy: Node3D) -> void:
	enemies_alive = max(enemies_alive - 1, 0)
	enemies_alive_changed.emit(enemies_alive)
	if _core and _core.has_method("take_hit"):
		_core.take_hit(1)
	_try_complete_wave()


func _on_wave_spawn_finished(_wave_number: int) -> void:
	_spawn_finished = true
	_try_complete_wave()


func _try_complete_wave() -> void:
	if not wave_running or game_over or level_complete:
		return
	if not _spawn_finished or enemies_alive > 0:
		return
	wave_running = false
	wave_state_changed.emit(false)
	print("Wave %d complete" % active_wave)
	var total_waves: int = int(wave_manager.call("get_wave_count"))
	if active_wave >= total_waves:
		_set_level_complete()
		return
	current_wave = active_wave + 1
	wave_changed.emit(current_wave)
	print("Wave %d ready" % current_wave)


func _on_core_health_changed(current_health: int) -> void:
	core_hp = current_health
	core_hp_changed.emit(core_hp)
	if current_health <= 0:
		_set_game_over()


func _on_core_destroyed() -> void:
	_set_game_over()


func _set_game_over() -> void:
	if game_over or level_complete:
		return
	game_over = true
	wave_running = false
	wave_state_changed.emit(false)
	if wave_manager.has_method("stop_all"):
		wave_manager.call("stop_all")
	_clear_enemies()
	if build_manager and build_manager.has_method("set_build_enabled"):
		build_manager.call("set_build_enabled", false)
	game_over_changed.emit(true)
	print("GAME OVER")


func _set_level_complete() -> void:
	if level_complete or game_over:
		return
	level_complete = true
	wave_running = false
	wave_state_changed.emit(false)
	if build_manager and build_manager.has_method("set_build_enabled"):
		build_manager.call("set_build_enabled", false)
	level_complete_changed.emit(true)
	print("LEVEL COMPLETE")


func _clear_enemies() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	enemies_alive = 0
	enemies_alive_changed.emit(0)

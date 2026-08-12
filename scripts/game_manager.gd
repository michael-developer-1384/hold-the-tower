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
@onready var selection_manager: Node = $"../SelectionManager"
@onready var telemetry: Node = $"../TelemetryManager"
@onready var range_viz: Node3D = $"../RangeVisualization"

const PathCoverageCalc := preload("res://scripts/level/path_coverage_calculator.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")

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

	if typeof(RunManager) != TYPE_NIL:
		if str(RunManager.level_id).is_empty():
			RunManager.prepare_defaults_from_profile()
		RunManager.begin_run(starting_gold)

	gold = starting_gold
	gold_changed.emit(gold)

	var path_meta: Dictionary = {}
	if tower_level.has_method("get_path_meta"):
		path_meta = tower_level.call("get_path_meta")
	if tower_level.has_method("get_enemy_path"):
		wave_manager.setup(tower_level.get_enemy_path(), tower_level.get_enemy_container(), path_meta)

	if range_viz and range_viz.has_method("setup_path"):
		range_viz.call(
			"setup_path",
			path_meta.get("path", PackedVector3Array()),
			path_meta.get("segment_floors", PackedStringArray())
		)

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
		build_manager.call("setup", self, towers_root, selection_manager)
	if tower_level.has_method("get_build_spots") and build_manager.has_method("register_spots"):
		build_manager.call("register_spots", tower_level.call("get_build_spots"))

	if selection_manager and selection_manager.has_method("setup"):
		selection_manager.call(
			"setup",
			camera_rig,
			tower_level,
			build_manager,
			range_viz,
			telemetry
		)

	if build_manager and build_manager.has_signal("tower_built"):
		build_manager.tower_built.connect(_on_tower_built)

	wave_manager.enemy_spawned.connect(_on_enemy_spawned)
	if wave_manager.has_signal("wave_started"):
		wave_manager.wave_started.connect(_on_wave_started)
	if wave_manager.has_signal("wave_spawn_finished"):
		wave_manager.wave_spawn_finished.connect(_on_wave_spawn_finished)

	if hud.has_method("bind_game"):
		hud.call("bind_game", self, build_manager, selection_manager, range_viz)

	var level_id := "vertical_test"
	if typeof(RunManager) != TYPE_NIL and not str(RunManager.level_id).is_empty():
		level_id = str(RunManager.level_id)
	elif tower_level.has_method("get_level_id"):
		level_id = str(tower_level.call("get_level_id"))
	if telemetry and telemetry.has_method("start_run"):
		telemetry.call("start_run", level_id, gold, core_hp)
		if telemetry.has_method("on_floor_focused"):
			telemetry.call("on_floor_focused", int(camera_rig.get("focus_floor")))

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
	if typeof(RunManager) != TYPE_NIL:
		RunManager.note_gold_earned(amount)


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
	# Retry keeps current RunManager config.
	AppRouterScript.go_game(get_tree())


func upgrade_selected_tower() -> bool:
	if selection_manager == null:
		return false
	var tower: Node3D = selection_manager.get("selected_tower")
	if tower == null or not is_instance_valid(tower):
		return false
	var range_before: float = float(tower.get("attack_range"))
	var cost := 150
	if build_manager and build_manager.has_method("get_basic_tower_def"):
		var def = build_manager.call("get_basic_tower_def")
		if def:
			cost = int(def.upgrade_cost)
	if not build_manager.call("upgrade_tower", tower):
		return false
	if selection_manager.has_method("refresh_range"):
		selection_manager.call("refresh_range")
	var coverage := _coverage_for_tower(tower)
	if telemetry and telemetry.has_method("on_tower_upgraded"):
		telemetry.call("on_tower_upgraded", tower, cost, gold, range_before, coverage)
	return true


func _on_focus_changed(floor_index: int) -> void:
	if tower_level.has_method("set_focus_floor"):
		tower_level.set_focus_floor(floor_index)
	if hud.has_method("set_focus_floor"):
		hud.set_focus_floor(floor_index + 1)
	if telemetry and telemetry.has_method("on_floor_focused"):
		telemetry.call("on_floor_focused", floor_index)


func _on_tower_built(_spot: Node, tower: Node3D) -> void:
	var cost := 100
	var tower_type := str(tower.get("tower_type"))
	if build_manager and build_manager.has_method("get_tower_defs"):
		for def in build_manager.call("get_tower_defs"):
			if str(def.tower_id) == tower_type:
				cost = int(def.cost)
				break
	var coverage := _coverage_for_tower(tower)
	if telemetry and telemetry.has_method("on_tower_built"):
		telemetry.call("on_tower_built", tower, cost, gold, active_wave if wave_running else current_wave, coverage)


func _coverage_for_tower(tower: Node3D) -> Dictionary:
	if range_viz and range_viz.has_method("get_last_coverage"):
		if selection_manager and selection_manager.get("selected_tower") == tower:
			var last: Dictionary = range_viz.call("get_last_coverage")
			if not last.is_empty():
				return last
	var path_meta: Dictionary = {}
	if tower_level.has_method("get_path_meta"):
		path_meta = tower_level.call("get_path_meta")
	var origin: Vector3 = tower.global_position
	if tower.has_method("get_range_origin"):
		origin = tower.call("get_range_origin")
	var shape := "SPHERE_3D"
	if tower.has_method("get_range_shape"):
		shape = str(tower.call("get_range_shape"))
	var range_value := float(tower.get("attack_range")) if "attack_range" in tower else 0.0
	if tower.has_method("get_range_value"):
		range_value = float(tower.call("get_range_value"))
	return PathCoverageCalc.compute_for_tower(
		origin,
		range_value,
		shape,
		str(tower.get("floor_id")),
		path_meta.get("path", PackedVector3Array()),
		path_meta.get("segment_floors", PackedStringArray())
	)


func _on_wave_started(wave_number: int, enemy_count: int) -> void:
	if telemetry and telemetry.has_method("on_wave_started"):
		telemetry.call("on_wave_started", wave_number, enemy_count, gold, core_hp)


func _on_enemy_spawned(enemy: Node3D) -> void:
	enemies_alive += 1
	enemies_alive_changed.emit(enemies_alive)
	if telemetry and telemetry.has_method("on_enemy_spawned"):
		telemetry.call("on_enemy_spawned", enemy)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
	if enemy.has_signal("reached_core"):
		enemy.reached_core.connect(_on_enemy_reached_core)


func _on_enemy_died(enemy: Node3D) -> void:
	enemies_alive = max(enemies_alive - 1, 0)
	enemies_alive_changed.emit(enemies_alive)
	if not game_over:
		var reward := enemy_kill_reward
		if enemy != null and is_instance_valid(enemy) and "reward" in enemy:
			reward = int(enemy.get("reward"))
		add_gold(reward)
		print("Enemy killed, +%d gold" % reward)
	_try_complete_wave()


func _on_enemy_reached_core(enemy: Node3D) -> void:
	enemies_alive = max(enemies_alive - 1, 0)
	enemies_alive_changed.emit(enemies_alive)
	if telemetry and telemetry.has_method("on_enemy_reached_core"):
		telemetry.call("on_enemy_reached_core", enemy, active_wave)
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
	if telemetry and telemetry.has_method("on_wave_completed"):
		telemetry.call("on_wave_completed", active_wave, gold, core_hp)
	else:
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
	if selection_manager and selection_manager.has_method("set_interaction_enabled"):
		selection_manager.call("set_interaction_enabled", false)
	if range_viz and range_viz.has_method("hide_all"):
		range_viz.call("hide_all")
	game_over_changed.emit(true)
	_finalize_run("game_over")
	print("GAME OVER")


func _set_level_complete() -> void:
	if level_complete or game_over:
		return
	level_complete = true
	wave_running = false
	wave_state_changed.emit(false)
	if build_manager and build_manager.has_method("set_build_enabled"):
		build_manager.call("set_build_enabled", false)
	if selection_manager and selection_manager.has_method("set_interaction_enabled"):
		selection_manager.call("set_interaction_enabled", false)
	if range_viz and range_viz.has_method("hide_all"):
		range_viz.call("hide_all")
	level_complete_changed.emit(true)
	_finalize_run("level_complete")
	print("LEVEL COMPLETE")


func _finalize_run(result: String) -> void:
	var towers: Array = get_tree().get_nodes_in_group("towers")
	if telemetry and telemetry.has_method("end_run"):
		telemetry.call("end_run", result, gold, core_hp, towers)

	var research_earned := 0
	if result == "level_complete" and typeof(RunManager) != TYPE_NIL:
		research_earned = DifficultyCatalogScript.research_reward(RunManager.difficulty_id)
		if typeof(ProfileManager) != TYPE_NIL:
			ProfileManager.add_research(research_earned)

	var snapshot := _build_run_snapshot(result, towers, research_earned)
	if typeof(RunManager) != TYPE_NIL:
		RunManager.finalize_run(snapshot)
	if typeof(ProfileManager) != TYPE_NIL:
		ProfileManager.record_run(RunManager.last_run if typeof(RunManager) != TYPE_NIL else snapshot)

	# Defer scene change so current frame/signal handlers finish cleanly.
	call_deferred("_go_post_game")


func _go_post_game() -> void:
	AppRouterScript.go_post_game(get_tree())


func _build_run_snapshot(result: String, towers: Array, research_earned: int) -> Dictionary:
	var total_damage := 0.0
	var instances: Array = []
	var by_type: Dictionary = {}

	for t in towers:
		if t == null or not is_instance_valid(t):
			continue
		# Skip nested combat units that might share the group incorrectly.
		var tower_type := str(t.get("tower_type"))
		if tower_type.is_empty():
			continue
		var dmg := float(t.get("damage_dealt")) if "damage_dealt" in t else 0.0
		total_damage += dmg
		var gold_inv := int(t.get("gold_invested")) if "gold_invested" in t else 0
		var bp_id := str(t.get("blueprint_id")) if "blueprint_id" in t else ""
		var resolved: Dictionary = t.get("resolved_stats") if "resolved_stats" in t else {}
		var inst := {
			"tower_runtime_id": str(t.get("runtime_id")),
			"tower_type": tower_type,
			"build_spot_id": str(t.get("build_spot_id")),
			"floor_id": str(t.get("floor_id")),
			"level": int(t.get("level")) if "level" in t else 1,
			"blueprint_id": bp_id,
			"resolved_stats": resolved.duplicate(true) if typeof(resolved) == TYPE_DICTIONARY else {},
			"damage_dealt": dmg,
			"kills": int(t.get("kills")) if "kills" in t else 0,
			"hits": int(t.get("hits")) if "hits" in t else 0,
			"shots": int(t.get("shots_fired")) if "shots_fired" in t else 0,
			"same_floor_damage": float(t.get("same_floor_damage")) if "same_floor_damage" in t else 0.0,
			"cross_floor_damage": float(t.get("cross_floor_damage")) if "cross_floor_damage" in t else 0.0,
			"overkill_damage": float(t.get("overkill_damage")) if "overkill_damage" in t else 0.0,
			"target_time": float(t.get("target_time")) if "target_time" in t else 0.0,
			"no_target_time": float(t.get("no_target_time")) if "no_target_time" in t else 0.0,
			"enemies_blocked": int(t.get("enemies_blocked")) if "enemies_blocked" in t else 0,
			"total_block_time_ms": int(t.get("total_block_time_ms")) if "total_block_time_ms" in t else 0,
			"guards_died": int(t.get("guards_died")) if "guards_died" in t else 0,
			"guards_respawned": int(t.get("guards_respawned")) if "guards_respawned" in t else 0,
			"guard_damage_taken": float(t.get("guard_damage_taken")) if "guard_damage_taken" in t else 0.0,
			"guard_healing_done": float(t.get("guard_healing_done")) if "guard_healing_done" in t else 0.0,
			"peak_simultaneous_blocks": int(t.get("peak_simultaneous_blocks")) if "peak_simultaneous_blocks" in t else 0,
			"gold_invested": gold_inv,
		}
		instances.append(inst)

		if not by_type.has(tower_type):
			by_type[tower_type] = {
				"tower_type": tower_type,
				"blueprint_id": bp_id,
				"times_built": 0,
				"gold_invested": 0.0,
				"damage_dealt": 0.0,
				"kills": 0,
				"hits": 0,
				"shots": 0,
				"overkill_damage": 0.0,
				"same_floor_damage": 0.0,
				"cross_floor_damage": 0.0,
				"total_path_coverage": 0.0,
				"target_time": 0.0,
				"no_target_time": 0.0,
				"enemies_blocked": 0,
				"total_block_time_ms": 0,
				"guards_died": 0,
				"guards_respawned": 0,
				"guard_damage_taken": 0.0,
				"guard_healing_done": 0.0,
				"peak_simultaneous_blocks": 0,
			}
		var agg: Dictionary = by_type[tower_type]
		agg["times_built"] = int(agg["times_built"]) + 1
		agg["gold_invested"] = float(agg["gold_invested"]) + float(gold_inv)
		agg["damage_dealt"] = float(agg["damage_dealt"]) + dmg
		agg["kills"] = int(agg["kills"]) + int(inst["kills"])
		agg["hits"] = int(agg["hits"]) + int(inst["hits"])
		agg["shots"] = int(agg["shots"]) + int(inst["shots"])
		agg["overkill_damage"] = float(agg["overkill_damage"]) + float(inst["overkill_damage"])
		agg["same_floor_damage"] = float(agg["same_floor_damage"]) + float(inst["same_floor_damage"])
		agg["cross_floor_damage"] = float(agg["cross_floor_damage"]) + float(inst["cross_floor_damage"])
		agg["target_time"] = float(agg["target_time"]) + float(inst["target_time"])
		agg["no_target_time"] = float(agg["no_target_time"]) + float(inst["no_target_time"])
		agg["enemies_blocked"] = int(agg["enemies_blocked"]) + int(inst["enemies_blocked"])
		agg["total_block_time_ms"] = int(agg["total_block_time_ms"]) + int(inst["total_block_time_ms"])
		agg["guards_died"] = int(agg["guards_died"]) + int(inst["guards_died"])
		agg["guards_respawned"] = int(agg["guards_respawned"]) + int(inst["guards_respawned"])
		agg["guard_damage_taken"] = float(agg["guard_damage_taken"]) + float(inst["guard_damage_taken"])
		agg["guard_healing_done"] = float(agg["guard_healing_done"]) + float(inst["guard_healing_done"])
		agg["peak_simultaneous_blocks"] = maxi(
			int(agg["peak_simultaneous_blocks"]), int(inst["peak_simultaneous_blocks"])
		)
		by_type[tower_type] = agg

	var killed := 0
	var leaked := 0
	if telemetry:
		killed = int(telemetry.get("enemies_killed")) if "enemies_killed" in telemetry else 0
		leaked = int(telemetry.get("enemies_leaked")) if "enemies_leaked" in telemetry else 0

	var level_id := "vertical_test"
	var diff_id := "normal"
	var diff_m := 1.0
	if typeof(RunManager) != TYPE_NIL:
		level_id = RunManager.level_id
		diff_id = RunManager.difficulty_id
		diff_m = RunManager.difficulty_multiplier

	var enemy_type_stats: Array = []
	if telemetry and telemetry.has_method("get_enemy_type_stats"):
		enemy_type_stats = telemetry.call("get_enemy_type_stats")

	return {
		"result": result,
		"level_id": level_id,
		"difficulty_id": diff_id,
		"difficulty_multiplier": diff_m,
		"ending_gold": gold,
		"ending_core_hp": core_hp,
		"starting_gold": starting_gold,
		"enemies_killed": killed,
		"enemies_leaked": leaked,
		"total_damage": total_damage,
		"research_earned": research_earned,
		"research_total": ProfileManager.get_research_points() if typeof(ProfileManager) != TYPE_NIL else 0,
		"towers": instances,
		"tower_type_stats": by_type.values(),
		"enemy_type_stats": enemy_type_stats,
	}


func _clear_enemies() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	enemies_alive = 0
	enemies_alive_changed.emit(0)

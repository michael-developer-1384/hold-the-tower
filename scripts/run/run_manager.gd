extends Node

## Current run configuration + last finished run snapshot.

const LevelCatalogScript := preload("res://scripts/meta/level_catalog.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")
const SimContextScript := preload("res://scripts/sim/sim_context.gd")
const PortfolioConfigScript := preload("res://scripts/economy/portfolio_config.gd")

var level_id: String = "vertical_test"
var difficulty_id: String = "normal"
var difficulty_multiplier: float = 1.0
var research_snapshot: Dictionary = {} # tower_id -> resolved params
var research_allocation_snapshot: Dictionary = {} # tower_id -> allocations
var active_blueprints: Dictionary = {} # tower_id -> blueprint_id ("research" if none)
var active_blueprint_names: Dictionary = {} # tower_id -> display_name
var player_level_start: int = 1
var research_xp_total_start: int = 0

var last_run: Dictionary = {}
var run_id: String = ""
var run_started_ms: int = 0
var run_started_wall_ms: int = 0
var buying_power_earned: int = 0
var buying_power_spent: int = 0
var starting_buying_power: int = 0
# Explicit compatibility aliases for pre-v0.17 callers and payloads.
var gold_earned: int = 0
var gold_spent: int = 0
var starting_gold: int = 0
var assisted: bool = false


func prepare_defaults_from_profile() -> void:
	level_id = LevelCatalogScript.default_id()
	difficulty_id = DifficultyCatalogScript.default_id()
	difficulty_multiplier = float(DifficultyCatalogScript.find(difficulty_id).get("multiplier", 1.0))
	_snapshot_research()


func configure(p_level_id: String, p_difficulty_id: String) -> void:
	level_id = p_level_id
	difficulty_id = p_difficulty_id
	var diff := DifficultyCatalogScript.find(difficulty_id)
	difficulty_multiplier = float(diff.get("multiplier", 1.0))
	_snapshot_research()


func begin_run(p_starting_buying_power: int) -> void:
	run_started_ms = Time.get_ticks_msec()
	run_started_wall_ms = int(Time.get_unix_time_from_system() * 1000.0)
	run_id = "run_%d_%06d" % [run_started_wall_ms, randi_range(0, 999999)]
	starting_buying_power = p_starting_buying_power
	buying_power_earned = 0
	buying_power_spent = 0
	starting_gold = p_starting_buying_power
	gold_earned = 0
	gold_spent = 0
	assisted = false
	last_run.clear()
	if SimContextScript.is_simulating():
		# Loadout is owned by GameSimulation (base stats unless profile research requested).
		return
	_snapshot_research()


func note_gold_earned(amount: int) -> void:
	note_buying_power_earned(amount)


func note_buying_power_earned(amount: int) -> void:
	if amount > 0:
		buying_power_earned += amount
		gold_earned += amount


func note_gold_spent(amount: int) -> void:
	note_buying_power_spent(amount)


func note_buying_power_spent(amount: int) -> void:
	if amount > 0:
		buying_power_spent += amount
		gold_spent += amount


func mark_assisted() -> void:
	assisted = true


func get_research_params(tower_id: String) -> Dictionary:
	if research_snapshot.has(tower_id):
		return (research_snapshot[tower_id] as Dictionary).duplicate(true)
	if typeof(ProfileManager) != TYPE_NIL:
		return ProfileManager.get_tower_research_params(tower_id)
	return {}


func get_research_allocations(tower_id: String) -> Dictionary:
	if research_allocation_snapshot.has(tower_id):
		return (research_allocation_snapshot[tower_id] as Dictionary).duplicate(true)
	if typeof(ProfileManager) != TYPE_NIL:
		return ProfileManager.get_tower_research_allocations(tower_id)
	return {}


func get_active_blueprint_id(tower_id: String) -> String:
	return str(active_blueprints.get(tower_id, "research"))


func get_active_blueprint_name(tower_id: String) -> String:
	return str(active_blueprint_names.get(tower_id, "Research"))


func get_risk_notional_cents() -> int:
	return PortfolioConfigScript.risk_notional_cents(difficulty_id)


func get_leverage() -> float:
	return PortfolioConfigScript.DEFAULT_LEVERAGE


func finalize_run(snapshot: Dictionary) -> void:
	last_run = snapshot.duplicate(true)
	if run_id.is_empty():
		run_started_wall_ms = int(Time.get_unix_time_from_system() * 1000.0)
		run_id = "run_%d_%06d" % [run_started_wall_ms, randi_range(0, 999999)]
	last_run["run_id"] = run_id
	last_run["wall_time_ms"] = run_started_wall_ms
	last_run["level_id"] = level_id
	last_run["difficulty_id"] = difficulty_id
	last_run["difficulty_multiplier"] = difficulty_multiplier
	last_run["research_snapshot"] = research_snapshot.duplicate(true)
	last_run["research_allocation_snapshot"] = research_allocation_snapshot.duplicate(true)
	last_run["player_level_start"] = player_level_start
	last_run["research_xp_total_start"] = research_xp_total_start
	last_run["active_blueprints"] = active_blueprints.duplicate(true)
	if SimContextScript.is_simulating():
		last_run["duration_ms"] = int(SimContextScript.sim_time_ms)
	elif snapshot.has("run_elapsed_ms"):
		last_run["duration_ms"] = int(snapshot.get("run_elapsed_ms", 0))
	else:
		last_run["duration_ms"] = Time.get_ticks_msec() - run_started_ms
	last_run["starting_buying_power"] = starting_buying_power
	last_run["buying_power_earned"] = buying_power_earned
	last_run["buying_power_spent"] = buying_power_spent
	last_run["assisted"] = assisted


func clear_last_run() -> void:
	last_run.clear()


func _snapshot_research() -> void:
	research_snapshot.clear()
	research_allocation_snapshot.clear()
	active_blueprints.clear()
	active_blueprint_names.clear()
	player_level_start = 1
	research_xp_total_start = 0
	if typeof(ProfileManager) == TYPE_NIL:
		return
	player_level_start = ProfileManager.get_player_level()
	research_xp_total_start = ProfileManager.get_research_xp_total()
	for tid in ["basic_tower", "guard_post", "lava_tower"]:
		research_allocation_snapshot[tid] = ProfileManager.get_tower_research_allocations(tid)
		research_snapshot[tid] = ProfileManager.get_tower_research_params(tid)
		var match_bp: Dictionary = ProfileManager.get_matching_blueprint(tid)
		if match_bp.is_empty():
			active_blueprints[tid] = "research"
			active_blueprint_names[tid] = "Research"
		else:
			active_blueprints[tid] = str(match_bp.get("id", "research"))
			active_blueprint_names[tid] = str(match_bp.get("display_name", "Research"))

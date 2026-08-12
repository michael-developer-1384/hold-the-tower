extends Node

## Current run configuration + last finished run snapshot.

const LevelCatalogScript := preload("res://scripts/meta/level_catalog.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")

var level_id: String = "vertical_test"
var difficulty_id: String = "normal"
var difficulty_multiplier: float = 1.0
var active_blueprints: Dictionary = {} # tower_id -> blueprint_id

var last_run: Dictionary = {}
var run_started_ms: int = 0
var gold_earned: int = 0
var gold_spent: int = 0
var starting_gold: int = 0


func prepare_defaults_from_profile() -> void:
	level_id = LevelCatalogScript.default_id()
	difficulty_id = DifficultyCatalogScript.default_id()
	difficulty_multiplier = float(DifficultyCatalogScript.find(difficulty_id).get("multiplier", 1.0))
	active_blueprints.clear()
	if typeof(ProfileManager) != TYPE_NIL:
		for tid in ["basic_tower", "guard_post"]:
			active_blueprints[tid] = ProfileManager.get_active_blueprint_id(tid)


func configure(p_level_id: String, p_difficulty_id: String) -> void:
	level_id = p_level_id
	difficulty_id = p_difficulty_id
	var diff := DifficultyCatalogScript.find(difficulty_id)
	difficulty_multiplier = float(diff.get("multiplier", 1.0))
	active_blueprints.clear()
	if typeof(ProfileManager) != TYPE_NIL:
		for tid in ["basic_tower", "guard_post"]:
			active_blueprints[tid] = ProfileManager.get_active_blueprint_id(tid)


func begin_run(p_starting_gold: int) -> void:
	run_started_ms = Time.get_ticks_msec()
	starting_gold = p_starting_gold
	gold_earned = 0
	gold_spent = 0
	last_run.clear()


func note_gold_earned(amount: int) -> void:
	if amount > 0:
		gold_earned += amount


func note_gold_spent(amount: int) -> void:
	if amount > 0:
		gold_spent += amount


func get_active_blueprint_id(tower_id: String) -> String:
	return str(active_blueprints.get(tower_id, ""))


func finalize_run(snapshot: Dictionary) -> void:
	last_run = snapshot.duplicate(true)
	last_run["level_id"] = level_id
	last_run["difficulty_id"] = difficulty_id
	last_run["difficulty_multiplier"] = difficulty_multiplier
	last_run["active_blueprints"] = active_blueprints.duplicate(true)
	last_run["duration_ms"] = Time.get_ticks_msec() - run_started_ms
	last_run["gold_earned"] = gold_earned
	last_run["gold_spent"] = gold_spent


func clear_last_run() -> void:
	last_run.clear()

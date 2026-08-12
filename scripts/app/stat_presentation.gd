class_name StatPresentation
extends RefCounted

## Central player-facing formatting for stats, IDs, units and precision.
## Domain math stays elsewhere — this is display only.

const LevelCatalogScript := preload("res://scripts/meta/level_catalog.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")
const TowerCatalogScript := preload("res://scripts/towers/tower_catalog.gd")
const EnemyCatalogScript := preload("res://scripts/enemies/enemy_catalog.gd")
const ResearchConfigScript := preload("res://scripts/meta/research_config.gd")

static var _tower_defs_cache: Array = []


static func spec(stat_key: String) -> Dictionary:
	var key := str(stat_key)
	var research := ResearchConfigScript.get_stat(key)
	if not research.is_empty():
		return _from_research(research)
	return _registry().get(key, _fallback(key))


static func label(stat_key: String) -> String:
	return str(spec(stat_key).get("label", stat_key))


static func description(stat_key: String) -> String:
	return str(spec(stat_key).get("description", ""))


static func unit(stat_key: String) -> String:
	return str(spec(stat_key).get("unit", ""))


static func is_lower_better(stat_key: String) -> bool:
	return bool(spec(stat_key).get("lower_is_better", false))


static func format_value(stat_key: String, value: float) -> String:
	var s := spec(stat_key)
	var prec := int(s.get("precision", 2))
	var u := str(s.get("unit", ""))
	var num := _format_number(value, prec)
	if u.is_empty():
		return num
	return "%s %s" % [num, u]


static func format_value_from_spec(research_spec: Dictionary, value: float) -> String:
	if research_spec.is_empty():
		return _format_number(value, 2)
	return format_value(str(research_spec.get("id", "")), value)


static func format_delta(stat_key: String, before: float, after: float) -> String:
	if is_equal_approx(before, after):
		return "unchanged"
	var s := spec(stat_key)
	var prec := int(s.get("precision", 2))
	var u := str(s.get("unit", ""))
	var delta := after - before
	var sign_prefix := "+" if delta > 0.0 else "−"
	var abs_delta := absf(delta)
	var num := _format_number(abs_delta, prec)
	var body := "%s%s" % [sign_prefix, num]
	if not u.is_empty():
		body = "%s %s" % [body, u]
	return body


static func format_delta_label(stat_key: String, before: float, after: float) -> String:
	## Percent-style research draft label (keeps ResearchResolver semantics).
	if is_equal_approx(before, after):
		return "unchanged"
	if is_equal_approx(before, 0.0):
		return ""
	var pct := absf((after - before) / absf(before) * 100.0)
	if is_lower_better(stat_key):
		if after < before:
			return "%.0f%% faster" % pct
		return "%.0f%% slower" % pct
	if after > before:
		return "+%.1f %%" % ((after - before) / absf(before) * 100.0)
	return "%.1f %%" % ((after - before) / absf(before) * 100.0)


static func format_multiplier(mult: float) -> String:
	return "×%.2f" % mult


static func format_difficulty_modifiers(difficulty_id: String) -> Array:
	## Returns [{label, value}] using real difficulty application rules.
	var entry := DifficultyCatalogScript.find(difficulty_id)
	var m := float(entry.get("multiplier", 1.0))
	var interval_mult := 1.0 / maxf(m, 0.0001)
	return [
		{"key": "enemy_hp", "label": "Enemy HP", "value": format_multiplier(m)},
		{"key": "movement_speed", "label": "Movement Speed", "value": format_multiplier(m)},
		{"key": "melee_damage", "label": "Melee Damage", "value": format_multiplier(m)},
		{"key": "attack_interval", "label": "Attack Interval", "value": format_multiplier(interval_mult)},
	]


static func display_level(level_id: String) -> String:
	var entry := LevelCatalogScript.find(level_id)
	if not entry.is_empty():
		return str(entry.get("display_name", level_id))
	return str(level_id)


static func display_difficulty(difficulty_id: String) -> String:
	var entry := DifficultyCatalogScript.find(difficulty_id)
	if not entry.is_empty():
		return str(entry.get("display_name", difficulty_id))
	return str(difficulty_id)


static func display_tower(tower_id: String) -> String:
	var def = _find_tower(tower_id)
	if def != null:
		return str(def.display_name)
	return str(tower_id)


static func display_enemy(enemy_id: String) -> String:
	var defs := EnemyCatalogScript.create_all()
	var def = EnemyCatalogScript.find_by_id(defs, enemy_id)
	if def != null:
		return str(def.display_name)
	return str(enemy_id)


static func display_blueprint(blueprint_id: String, blueprint_name: String = "") -> String:
	if not blueprint_name.is_empty() and blueprint_name != "research":
		return blueprint_name
	if blueprint_id.is_empty() or blueprint_id == "research":
		return "Research"
	return str(blueprint_id)


static func session_summary_line(session: Dictionary) -> String:
	var level := display_level(str(session.get("level_id", "?")))
	var diff := display_difficulty(str(session.get("difficulty_id", "?")))
	var wave := int(session.get("current_wave", 1))
	return "%s · %s · Wave %d" % [level, diff, wave]


static func _from_research(research: Dictionary) -> Dictionary:
	var id := str(research.get("id", ""))
	var unit_s := _unit_for_research(id)
	var prec := _precision_for_research(id, str(research.get("value_format", "%.2f")))
	return {
		"id": id,
		"label": str(research.get("display_name", research.get("label", id))),
		"description": str(research.get("description", "")),
		"unit": unit_s,
		"precision": prec,
		"lower_is_better": bool(research.get("lower_is_better", false)),
		"category": "research",
	}


static func _unit_for_research(id: String) -> String:
	match id:
		"range", "defense_radius":
			return "m"
		"fire_interval", "guard_attack_interval", "healing_delay", "respawn_time":
			return "s"
		"projectile_speed":
			return "m/s"
		"cost":
			return "g"
		_:
			return ""


static func _precision_for_research(id: String, value_format: String) -> int:
	# Prefer explicit knowledge; fall back to digits in value_format.
	match id:
		"damage", "guard_damage", "healing_rate", "projectile_speed":
			return 1
		"range", "fire_interval", "guard_attack_interval", "defense_radius", "healing_delay":
			return 2
		"guard_hp", "respawn_time":
			return 0 if id == "guard_hp" else 1
		"cost":
			return 0
	if "%.0f" in value_format:
		return 0
	if "%.1f" in value_format:
		return 1
	return 2


static func _registry() -> Dictionary:
	return {
		"cost": {
			"id": "cost", "label": "Build Cost", "unit": "g", "precision": 0,
			"lower_is_better": false, "description": "Gold required to place this tower.",
			"category": "economy",
		},
		"upgrade_cost": {
			"id": "upgrade_cost", "label": "Upgrade Cost", "unit": "g", "precision": 0,
			"lower_is_better": false, "description": "Gold required for the in-match upgrade.",
			"category": "economy",
		},
		"times_built": {
			"id": "times_built", "label": "Times Built", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Lifetime placements of this tower.",
			"category": "lifetime",
		},
		"kills": {
			"id": "kills", "label": "Kills", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Lifetime kills attributed to this tower.",
			"category": "lifetime",
		},
		"damage_dealt": {
			"id": "damage_dealt", "label": "Damage Dealt", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Lifetime damage dealt.",
			"category": "lifetime",
		},
		"shots": {
			"id": "shots", "label": "Shots", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Lifetime shots fired.",
			"category": "lifetime",
		},
		"hits": {
			"id": "hits", "label": "Hits", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Lifetime projectile hits.",
			"category": "lifetime",
		},
		"gold_invested": {
			"id": "gold_invested", "label": "Gold Invested", "unit": "g", "precision": 0,
			"lower_is_better": false, "description": "Lifetime gold spent on this tower type.",
			"category": "lifetime",
		},
		"guards_died": {
			"id": "guards_died", "label": "Guards Died", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Lifetime guard deaths.",
			"category": "lifetime",
		},
		"guards_respawned": {
			"id": "guards_respawned", "label": "Guards Respawned", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Lifetime guard respawns.",
			"category": "lifetime",
		},
		"enemies_blocked": {
			"id": "enemies_blocked", "label": "Enemies Blocked", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Lifetime enemies blocked in melee.",
			"category": "lifetime",
		},
		"games_used": {
			"id": "games_used", "label": "Games Used", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Runs where this tower was built.",
			"category": "lifetime",
		},
		"encountered": {
			"id": "encountered", "label": "Encountered", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Lifetime times this enemy spawned.",
			"category": "lifetime",
		},
		"killed": {
			"id": "killed", "label": "Killed", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Lifetime kills of this enemy.",
			"category": "lifetime",
		},
		"leaks": {
			"id": "leaks", "label": "Leaks", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Lifetime core leaks by this enemy.",
			"category": "lifetime",
		},
		"damage_taken": {
			"id": "damage_taken", "label": "Damage Taken", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Lifetime damage taken.",
			"category": "lifetime",
		},
		"blocked": {
			"id": "blocked", "label": "Blocked", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Lifetime times blocked by guards.",
			"category": "lifetime",
		},
		"base_max_health": {
			"id": "base_max_health", "label": "HP", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Base maximum health.",
			"category": "combat",
		},
		"base_move_speed": {
			"id": "base_move_speed", "label": "Speed", "unit": "m/s", "precision": 1,
			"lower_is_better": false, "description": "Base movement speed along the path.",
			"category": "combat",
		},
		"base_melee_damage": {
			"id": "base_melee_damage", "label": "Melee Damage", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Base melee damage per hit.",
			"category": "combat",
		},
		"base_melee_interval": {
			"id": "base_melee_interval", "label": "Melee Interval", "unit": "s", "precision": 2,
			"lower_is_better": true, "description": "Seconds between melee attacks.",
			"category": "combat",
		},
		"reward": {
			"id": "reward", "label": "Kill Reward", "unit": "g", "precision": 0,
			"lower_is_better": false, "description": "Gold granted on kill.",
			"category": "economy",
		},
		"guard_count": {
			"id": "guard_count", "label": "Guards", "unit": "", "precision": 0,
			"lower_is_better": false, "description": "Number of guards spawned by the post.",
			"category": "combat",
		},
	}


static func _fallback(key: String) -> Dictionary:
	var pretty := str(key).replace("_", " ").capitalize()
	return {
		"id": key,
		"label": pretty,
		"description": "",
		"unit": "",
		"precision": 2,
		"lower_is_better": false,
		"category": "misc",
	}


static func _format_number(value: float, precision: int) -> String:
	match clampi(precision, 0, 4):
		0:
			return "%d" % int(round(value))
		1:
			return "%.1f" % value
		2:
			return "%.2f" % value
		3:
			return "%.3f" % value
		_:
			return "%.4f" % value


static func _find_tower(tower_id: String) -> Resource:
	if _tower_defs_cache.is_empty():
		_tower_defs_cache = TowerCatalogScript.create_all()
	return TowerCatalogScript.find_by_id(_tower_defs_cache, tower_id)

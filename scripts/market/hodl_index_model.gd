class_name HodlIndexModel
extends RefCounted

## Deterministic HODL Index: defensive stability, not cash and not raw HP.

const INDEX_MIN := 0.0
const INDEX_MAX := 100.0
const CAPACITY_FLOOR := 12.0
const PROXIMITY_NEAR_SPAWN := 0.35
const PROXIMITY_NEAR_CORE := 1.35
const ACTIVE_THREAT_POINTS := 30.0
const CORE_LOSS_POINTS := 70.0
const GUARD_LOSS_POINTS := 0.0


static func evaluate(input: Dictionary) -> Dictionary:
	var capacity := maxf(float(input.get("expected_wave_count", CAPACITY_FLOOR)), CAPACITY_FLOOR)
	var active := 0.0
	for enemy in input.get("enemies", []):
		if typeof(enemy) != TYPE_DICTIONARY:
			continue
		active += _enemy_threat(enemy)
	var active_component := ACTIVE_THREAT_POINTS * clampf(active / capacity, 0.0, 4.0)
	var core_hp := float(input.get("core_hp", 20.0))
	var core_max := maxf(float(input.get("core_max_hp", 20.0)), 0.001)
	var core_loss_frac := clampf(1.0 - core_hp / core_max, 0.0, 1.0)
	var core_component := CORE_LOSS_POINTS * core_loss_frac
	var guard_component := GUARD_LOSS_POINTS * clampf(float(input.get("guard_damage_fraction", 0.0)), 0.0, 1.0)
	var pressure := active_component + core_component + guard_component
	var index := clampf(INDEX_MAX - pressure, INDEX_MIN, INDEX_MAX)
	return {
		"index": index,
		"active_threat": active_component,
		"core_loss": core_component,
		"guard_component": guard_component,
		"pressure": pressure,
	}


static func proximity_weight(progress: float) -> float:
	return lerpf(PROXIMITY_NEAR_SPAWN, PROXIMITY_NEAR_CORE, clampf(progress, 0.0, 1.0))


static func _enemy_threat(enemy: Dictionary) -> float:
	var max_hp := maxf(float(enemy.get("max_health", 0.0)), 0.001)
	var hp := clampf(float(enemy.get("health", 0.0)), 0.0, max_hp)
	var hp_frac := hp / max_hp
	var progress := clampf(float(enemy.get("progress", 0.0)), 0.0, 1.0)
	var weight := float(enemy.get("weight", 1.0))
	return hp_frac * weight * proximity_weight(progress)

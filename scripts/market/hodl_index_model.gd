class_name HodlIndexModel
extends RefCounted

## Defensive Pressure is a state indicator.
## HODL Price is written by directional combat flows.

const CAPACITY_FLOOR := 12.0
const PROXIMITY_NEAR_SPAWN := 0.35
const PROXIMITY_NEAR_CORE := 1.35
const ACTIVE_THREAT_POINTS := 30.0
const GUARD_LOSS_POINTS := 0.0
const TARGET_FULL_WAVE_SPAWN_PRESSURE := 2.0
const TARGET_PERFECT_WAVE_KILL_GAIN := 1.0
const DAMAGE_RECOVERY_FACTOR := 0.4
const ADVANCE_PRICE_FACTOR := 5.0
const DANGER_BASE := 0.4
const DANGER_QUAD := 1.6
const CORE_DAMAGE_PRICE_FACTOR := 4.0
const MIN_HODL_PRICE := 0.0


static func evaluate(input: Dictionary) -> Dictionary:
	var capacity := maxf(float(input.get("expected_wave_count", CAPACITY_FLOOR)), CAPACITY_FLOOR)
	var active := 0.0
	for enemy in input.get("enemies", []):
		if typeof(enemy) != TYPE_DICTIONARY:
			continue
		active += _enemy_threat(enemy)
	var active_component := ACTIVE_THREAT_POINTS * clampf(active / capacity, 0.0, 4.0)
	var guard_component := GUARD_LOSS_POINTS * clampf(float(input.get("guard_damage_fraction", 0.0)), 0.0, 1.0)
	var pressure := active_component + guard_component
	return {
		"pressure": pressure,
		"active_threat": active_component,
		"guard_component": guard_component,
	}


static func spawn_pressure(expected_enemy_count: float, weight: float = 1.0) -> float:
	return TARGET_FULL_WAVE_SPAWN_PRESSURE / maxf(expected_enemy_count, 1.0) * weight


static func danger(progress: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	return DANGER_BASE + DANGER_QUAD * p * p


static func advance_loss(forward_progress: float, hp_fraction: float, progress: float) -> float:
	return maxf(forward_progress, 0.0) * maxf(hp_fraction, 0.0) * danger(progress) * ADVANCE_PRICE_FACTOR


static func damage_recovery(damage_fraction: float, weight: float = 1.0) -> float:
	return maxf(damage_fraction, 0.0) * weight * DAMAGE_RECOVERY_FACTOR


static func kill_gain(expected_enemy_count: float) -> float:
	return TARGET_PERFECT_WAVE_KILL_GAIN / maxf(expected_enemy_count, 1.0)


static func proximity_weight(progress: float) -> float:
	return lerpf(PROXIMITY_NEAR_SPAWN, PROXIMITY_NEAR_CORE, clampf(progress, 0.0, 1.0))


static func _enemy_threat(enemy: Dictionary) -> float:
	var max_hp := maxf(float(enemy.get("max_health", 0.0)), 0.001)
	var hp := clampf(float(enemy.get("health", 0.0)), 0.0, max_hp)
	var hp_frac := hp / max_hp
	var progress := clampf(float(enemy.get("progress", 0.0)), 0.0, 1.0)
	var weight := float(enemy.get("weight", 1.0))
	return hp_frac * weight * proximity_weight(progress)

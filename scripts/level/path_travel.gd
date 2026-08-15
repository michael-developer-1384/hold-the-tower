class_name PathTravel
extends RefCounted

## Theoretical unblocked path travel helpers for wave phase duration.


static func path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	if path.size() < 2:
		return total
	for i in range(path.size() - 1):
		total += path[i].distance_to(path[i + 1])
	return total


static func enemy_base_speed(enemy_id: String = "bot") -> float:
	var EnemyCatalogScript = load("res://scripts/enemies/enemy_catalog.gd")
	var def = EnemyCatalogScript.find_by_id(EnemyCatalogScript.create_all(), enemy_id)
	if def == null:
		return 2.2
	return float(def.base_move_speed)


static func difficulty_speed_mult() -> float:
	var m := 1.0
	if typeof(RunManager) != TYPE_NIL:
		m = float(RunManager.difficulty_multiplier)
	var SimContextScript = load("res://scripts/sim/sim_context.gd")
	return float(SimContextScript.get_override("enemy_speed", m))


static func spawn_rate_mult() -> float:
	var SimContextScript = load("res://scripts/sim/sim_context.gd")
	var rate := float(SimContextScript.get_override("spawn_rate", 1.0))
	return maxf(rate, 0.0001)


static func wave_phase_duration(path: PackedVector3Array, wave_def: Dictionary, speed_mult_override: float = -1.0) -> float:
	## Time until the last enemy of this wave would reach the core if unblocked.
	var length := path_length(path)
	if length <= 0.0 or wave_def.is_empty():
		return 1.0
	var diff_speed := speed_mult_override if speed_mult_override > 0.0 else difficulty_speed_mult()
	var count_m := 1.0
	var SimContextScript = load("res://scripts/sim/sim_context.gd")
	count_m = float(SimContextScript.get_override("enemy_count", 1.0))
	var rate := spawn_rate_mult()
	var stagger := 0.0
	var last_travel := 0.0
	var last_interval := 0.0
	var spawned := 0
	for group in wave_def.get("groups", []):
		var enemy_id := str(group.get("enemy_id", "bot"))
		var count := int(round(float(group.get("count", 0)) * count_m))
		if count <= 0:
			continue
		var interval := float(group.get("spawn_interval", 0.8)) / rate
		var group_speed := float(group.get("speed_multiplier", 1.0))
		var move := maxf(enemy_base_speed(enemy_id) * group_speed * diff_speed, 0.05)
		var travel := length / move
		for _i in count:
			if spawned > 0:
				stagger += last_interval
			last_interval = interval
			last_travel = travel
			spawned += 1
	if spawned <= 0:
		return 1.0
	return maxf(stagger + last_travel, 0.25)

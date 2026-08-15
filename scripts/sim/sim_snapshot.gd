extends RefCounted

## Sim-only combat snapshot. PLAY SessionStore is unchanged.


static func capture(sim) -> Dictionary:
	var game = sim.game
	var snap := {
		"sim_time": sim.clock.sim_time if sim.clock else 0.0,
		"action_log": sim.action_log.duplicate(true),
		"next_decision_at": sim._next_decision_at,
		"rng_state": sim.rng.get_state() if sim.rng and sim.rng.has_method("get_state") else 0,
		"run_seed": sim.run_seed,
		"level_id": sim.level_id,
		"difficulty_id": sim.difficulty_id,
		"config": sim.config.duplicate(true),
	}
	if game != null:
		snap["match"] = {
			"gold": int(game.get("gold")),
			"core_hp": int(game.get("core_hp")),
			"current_wave": int(game.get("current_wave")),
			"active_wave": int(game.get("active_wave")),
			"wave_running": bool(game.get("wave_running")),
			"enemies_alive": int(game.get("enemies_alive")),
			"game_over": bool(game.get("game_over")),
			"level_complete": bool(game.get("level_complete")),
			"spawn_finished": bool(game.get("_spawn_finished")),
			"waves_started": int(game.get("waves_started")) if "waves_started" in game else 0,
		}
	if game != null and game.has_method("capture_phase_state"):
		snap["phase"] = game.call("capture_phase_state")
	if sim.wave_manager != null and sim.wave_manager.has_method("capture_spawn_state"):
		snap["spawn"] = sim.wave_manager.call("capture_spawn_state")
	if sim.build_manager != null and sim.build_manager.has_method("get_next_tower_id"):
		snap["next_tower_id"] = int(sim.build_manager.call("get_next_tower_id"))
	snap["towers"] = _capture_towers(game)
	snap["enemies"] = _capture_enemies(game)
	snap["projectiles"] = _capture_projectiles(game)
	snap["lava"] = _capture_lava(game)
	if sim.telemetry != null:
		snap["telemetry"] = {
			"enemies_spawned": int(sim.telemetry.get("enemies_spawned")),
			"enemies_killed": int(sim.telemetry.get("enemies_killed")),
			"enemies_leaked": int(sim.telemetry.get("enemies_leaked")),
			"towers_built": int(sim.telemetry.get("towers_built")),
		}
	return snap


static func restore(sim, snap: Dictionary) -> bool:
	if sim == null or sim.game == null or snap.is_empty():
		return false
	_clear_combat(sim)
	var game = sim.game
	if sim.build_manager != null and snap.has("next_tower_id"):
		sim.build_manager.call("set_next_tower_id", int(snap.get("next_tower_id")))
	_restore_towers(sim, snap.get("towers", []))
	_restore_enemies(sim, snap.get("enemies", []))
	if sim.wave_manager != null and snap.has("spawn") and sim.wave_manager.has_method("apply_spawn_state"):
		sim.wave_manager.call("apply_spawn_state", snap.get("spawn"))
	_relink_engage(sim, snap)
	_restore_projectiles(sim, snap.get("projectiles", []))
	_restore_lava(sim, snap.get("lava", {}))
	_apply_match(game, snap.get("match", {}))
	if game.has_method("apply_phase_state") and snap.has("phase"):
		game.call("apply_phase_state", snap.get("phase"))
	if sim.clock:
		sim.clock.sim_time = float(snap.get("sim_time", 0.0))
		var SimContextScript = load("res://scripts/sim/sim_context.gd")
		SimContextScript.sim_time_ms = sim.clock.sim_time * 1000.0
	sim._next_decision_at = float(snap.get("next_decision_at", 0.0))
	if sim.rng and sim.rng.has_method("set_state") and int(snap.get("rng_state", 0)) != 0:
		sim.rng.set_state(int(snap.get("rng_state")))
	if sim.telemetry != null and snap.has("telemetry"):
		var tel: Dictionary = snap.get("telemetry")
		sim.telemetry.set("enemies_spawned", int(tel.get("enemies_spawned", 0)))
		sim.telemetry.set("enemies_killed", int(tel.get("enemies_killed", 0)))
		sim.telemetry.set("enemies_leaked", int(tel.get("enemies_leaked", 0)))
		sim.telemetry.set("towers_built", int(tel.get("towers_built", 0)))
	sim.action_log = snap.get("action_log", []).duplicate(true)
	return true


static func _owned(sim, node: Node) -> bool:
	if node == null or not is_instance_valid(node) or sim.root == null:
		return false
	return sim.root == node or sim.root.is_ancestor_of(node)


static func _group(sim, group: String) -> Array:
	var out: Array = []
	if sim.tree == null:
		return out
	for n in sim.tree.get_nodes_in_group(group):
		if _owned(sim, n):
			out.append(n)
	return out


static func _clear_combat(sim) -> void:
	for p in _group(sim, "projectiles"):
		p.free()
	for e in _group(sim, "enemies"):
		e.free()
	if sim.build_manager != null and sim.build_manager.has_method("clear_all_towers"):
		sim.build_manager.call("clear_all_towers")
	for t in _group(sim, "towers"):
		if is_instance_valid(t):
			t.free()
	var lava = _find_lava(sim.game if sim else null)
	if lava != null and lava.has_method("apply_state"):
		lava.call("apply_state", {"cells": [], "airborne": []})


static func _group_from_game(game: Node, group: String) -> Array:
	var out: Array = []
	if game == null or game.get_tree() == null:
		return out
	var host := game.get_parent()
	for n in game.get_tree().get_nodes_in_group(group):
		if n != null and is_instance_valid(n) and (host == null or host == n or host.is_ancestor_of(n)):
			out.append(n)
	return out


static func _capture_towers(game: Node) -> Array:
	var out: Array = []
	if game == null:
		return out
	for t in _group_from_game(game, "towers"):
		if t == null or not is_instance_valid(t):
			continue
		var entry := {
			"runtime_id": str(t.get("runtime_id")),
			"tower_type": str(t.get("tower_type")),
			"spot_id": str(t.get("build_spot_id")),
			"level": int(t.get("level")) if "level" in t else 1,
			"gold_invested": int(t.get("gold_invested")) if "gold_invested" in t else 0,
			"cooldown": float(t.call("get_fire_cooldown")) if t.has_method("get_fire_cooldown") else 0.0,
			"damage_dealt": float(t.get("damage_dealt")) if "damage_dealt" in t else 0.0,
			"kills": int(t.get("kills")) if "kills" in t else 0,
			"shots_fired": int(t.get("shots_fired")) if "shots_fired" in t else 0,
			"hits": int(t.get("hits")) if "hits" in t else 0,
			"overkill_damage": float(t.get("overkill_damage")) if "overkill_damage" in t else 0.0,
		}
		if t.has_method("capture_guards"):
			entry["guards"] = t.call("capture_guards")
		if t.has_method("get_emit_acc"):
			entry["emit_acc"] = float(t.call("get_emit_acc"))
			entry["emit_seq"] = int(t.call("get_emit_seq")) if t.has_method("get_emit_seq") else 0
		out.append(entry)
	return out


static func _capture_enemies(game: Node) -> Array:
	var out: Array = []
	if game == null:
		return out
	for e in _group_from_game(game, "enemies"):
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("is_alive") and not bool(e.call("is_alive")):
			continue
		if e.has_method("capture_combat"):
			out.append(e.call("capture_combat"))
	return out


static func _find_lava(game: Node) -> Node:
	if game == null:
		return null
	var tl = game.get("tower_level") if "tower_level" in game else null
	if tl != null and tl.has_method("get_lava_system"):
		return tl.call("get_lava_system")
	if game.get_tree() != null:
		return game.get_tree().root.find_child("LavaSystem", true, false)
	return null


static func _capture_lava(game: Node) -> Dictionary:
	var lava := _find_lava(game)
	if lava != null and lava.has_method("capture_state"):
		return lava.call("capture_state")
	return {"cells": [], "airborne": []}


static func _restore_lava(sim, snap) -> void:
	var lava = _find_lava(sim.game if sim else null)
	if lava == null or not lava.has_method("apply_state"):
		return
	var data: Dictionary = {}
	if typeof(snap) == TYPE_DICTIONARY:
		data = snap
	lava.call("apply_state", data)


static func _capture_projectiles(game: Node) -> Array:
	var out: Array = []
	if game == null:
		return out
	for p in _group_from_game(game, "projectiles"):
		if p == null or not is_instance_valid(p):
			continue
		if p.has_method("capture_state"):
			out.append(p.call("capture_state"))
	return out


static func _restore_towers(sim, towers: Array) -> void:
	if sim.build_manager == null:
		return
	for entry in towers:
		var tower = sim.build_manager.call(
			"restore_tower_free",
			str(entry.get("spot_id")),
			str(entry.get("tower_type")),
			int(entry.get("level", 1)),
			int(entry.get("gold_invested", 0)),
			str(entry.get("runtime_id", ""))
		)
		if tower == null:
			continue
		if tower.has_method("set_fire_cooldown"):
			tower.call("set_fire_cooldown", float(entry.get("cooldown", 0.0)))
		if "damage_dealt" in tower:
			tower.set("damage_dealt", float(entry.get("damage_dealt", 0.0)))
		if "kills" in tower:
			tower.set("kills", int(entry.get("kills", 0)))
		if "shots_fired" in tower:
			tower.set("shots_fired", int(entry.get("shots_fired", 0)))
		if "hits" in tower:
			tower.set("hits", int(entry.get("hits", 0)))
		if "overkill_damage" in tower:
			tower.set("overkill_damage", float(entry.get("overkill_damage", 0.0)))
		if tower.has_method("apply_guard_snapshot") and entry.has("guards"):
			tower.call("apply_guard_snapshot", entry.get("guards"))
		if tower.has_method("set_emit_acc") and entry.has("emit_acc"):
			tower.call("set_emit_acc", float(entry.get("emit_acc", 0.0)))
		if tower.has_method("set_emit_seq") and entry.has("emit_seq"):
			tower.call("set_emit_seq", int(entry.get("emit_seq", 0)))


static func _restore_enemies(sim, enemies: Array) -> void:
	if sim.wave_manager == null:
		return
	for entry in enemies:
		var packed: Dictionary = entry.duplicate(true)
		if typeof(packed.get("position")) == TYPE_VECTOR3:
			var p: Vector3 = packed.get("position")
			packed["position"] = {"x": p.x, "y": p.y, "z": p.z}
		sim.wave_manager.call("restore_enemy_from_snapshot", packed)


static func _relink_engage(sim, snap: Dictionary) -> void:
	var enemies_by_id := {}
	var guards_by_id := {}
	for e in _group(sim, "enemies"):
		enemies_by_id[str(e.get("runtime_id"))] = e
	for t in _group(sim, "towers"):
		if t == null or not t.has_method("get_guards"):
			continue
		for g in t.call("get_guards"):
			if g == null:
				continue
			var gid := "%s:g%d" % [str(t.get("runtime_id")), int(g.get("slot_index"))]
			guards_by_id[gid] = g
	for entry in snap.get("enemies", []):
		var e = enemies_by_id.get(str(entry.get("runtime_id")), null)
		var gid := str(entry.get("engaged_guard_id", ""))
		if e != null and not gid.is_empty() and guards_by_id.has(gid) and e.has_method("relink_guard"):
			e.call("relink_guard", guards_by_id[gid])
	for t_entry in snap.get("towers", []):
		var guards_data: Dictionary = t_entry.get("guards", {})
		for slot in guards_data.get("slots", []):
			var combat: Dictionary = slot.get("combat", {})
			var tid := str(combat.get("target_id", ""))
			if tid.is_empty():
				continue
			var gid2 := "%s:g%d" % [str(t_entry.get("runtime_id")), int(slot.get("slot_index", 0))]
			var g2 = guards_by_id.get(gid2, null)
			var enemy = enemies_by_id.get(tid, null)
			if g2 != null and enemy != null and g2.has_method("relink_target"):
				g2.call("relink_target", enemy)


static func _restore_projectiles(sim, projectiles: Array) -> void:
	var scene: PackedScene = load("res://scenes/towers/basic_projectile.tscn")
	if scene == null:
		return
	var enemies_by_id := {}
	var towers_by_id := {}
	for e in _group(sim, "enemies"):
		enemies_by_id[str(e.get("runtime_id"))] = e
	for t in _group(sim, "towers"):
		towers_by_id[str(t.get("runtime_id"))] = t
	for entry in projectiles:
		var target = enemies_by_id.get(str(entry.get("target_id")), null)
		if target == null:
			continue
		var proj := scene.instantiate() as Node3D
		sim.root.add_child(proj)
		if typeof(entry.get("position")) == TYPE_VECTOR3:
			proj.global_position = entry.get("position")
		elif typeof(entry.get("position")) == TYPE_DICTIONARY:
			var pd: Dictionary = entry.get("position")
			proj.global_position = Vector3(float(pd.get("x", 0.0)), float(pd.get("y", 0.0)), float(pd.get("z", 0.0)))
		var source = towers_by_id.get(str(entry.get("source_id")), null)
		if proj.has_method("setup"):
			proj.call("setup", target, float(entry.get("damage", 25.0)), source, float(entry.get("speed", 28.0)))


static func _apply_match(game: Node, match: Dictionary) -> void:
	if game == null or match.is_empty():
		return
	game.set("gold", int(match.get("gold", 0)))
	game.set("current_wave", int(match.get("current_wave", 1)))
	game.set("active_wave", int(match.get("active_wave", 0)))
	game.set("wave_running", bool(match.get("wave_running", false)))
	game.set("enemies_alive", int(match.get("enemies_alive", 0)))
	game.set("game_over", bool(match.get("game_over", false)))
	game.set("level_complete", bool(match.get("level_complete", false)))
	game.set("_spawn_finished", bool(match.get("spawn_finished", false)))
	if match.has("waves_started"):
		game.set("waves_started", int(match.get("waves_started", 0)))
	var hp := int(match.get("core_hp", 20))
	game.set("core_hp", hp)
	var core = game.get("_core")
	if core != null and is_instance_valid(core):
		core.set("health", hp)

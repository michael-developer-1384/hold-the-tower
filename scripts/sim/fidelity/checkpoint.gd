extends RefCounted

const FLOAT_EPS := 0.05


static func capture(sim) -> Dictionary:
	var st: Dictionary = sim.state()
	var enemies: Array = []
	for e in st.get("enemies", []):
		enemies.append({
			"id": str(e.get("runtime_id", e.get("enemy_id", ""))),
			"hp": snappedf(float(e.get("health", 0.0)), 0.01),
			"progress": snappedf(float(e.get("path_progress", 0.0)), 0.01),
		})
	enemies.sort_custom(func(a, b): return str(a.id) < str(b.id))
	var towers: Array = []
	for t in st.get("towers", []):
		towers.append({
			"spot": str(t.get("spot_id")),
			"type": str(t.get("tower_type")),
			"level": int(t.get("level", 1)),
			"damage": snappedf(float(t.get("damage_dealt", 0.0)), 0.1),
		})
	towers.sort_custom(func(a, b): return str(a.spot) < str(b.spot))
	var proj := 0
	if sim.tree:
		proj = sim.tree.get_nodes_in_group("projectiles").size()
	var queue_len := 0
	if sim.wave_manager and sim.wave_manager.has_method("capture_spawn_state"):
		queue_len = (sim.wave_manager.call("capture_spawn_state").get("queue", []) as Array).size()
	return {
		"t": snappedf(float(sim.clock.sim_time), 0.001),
		"gold": int(st.get("gold", 0)),
		"core": int(st.get("core_hp", 0)),
		"wave": int(st.get("active_wave", 0)),
		"alive": int(st.get("enemies_alive", 0)),
		"queue": queue_len,
		"projectiles": proj,
		"enemies": enemies,
		"towers": towers,
	}


static func first_diff(a: Dictionary, b: Dictionary) -> Dictionary:
	for key in ["gold", "core", "wave", "alive", "queue", "projectiles"]:
		if a.get(key) != b.get(key):
			return {"field": key, "a": a.get(key), "b": b.get(key)}
	var ea: Array = a.get("enemies", [])
	var eb: Array = b.get("enemies", [])
	if ea.size() != eb.size():
		return {"field": "enemy_count", "a": ea.size(), "b": eb.size()}
	for i in ea.size():
		for k in ["id", "hp", "progress"]:
			if str(ea[i].get(k)) != str(eb[i].get(k)):
				if k in ["hp", "progress"] and absf(float(ea[i].get(k)) - float(eb[i].get(k))) <= FLOAT_EPS:
					continue
				return {"field": "enemy_%s_%s" % [str(ea[i].get("id")), k], "a" : ea[i].get(k), "b": eb[i].get(k)}
	var ta: Array = a.get("towers", [])
	var tb: Array = b.get("towers", [])
	if ta.size() != tb.size():
		return {"field": "tower_count", "a": ta.size(), "b": tb.size()}
	for i in ta.size():
		for k in ["spot", "type", "level", "damage"]:
			if str(ta[i].get(k)) != str(tb[i].get(k)):
				if k == "damage" and absf(float(ta[i].get(k)) - float(tb[i].get(k))) <= 0.5:
					continue
				return {"field": "tower_%s_%s" % [str(ta[i].get("spot")), k], "a": ta[i].get(k), "b": tb[i].get(k)}
	return {}

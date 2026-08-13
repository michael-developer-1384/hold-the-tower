extends RefCounted

## Deterministic in-match policy used by fidelity / clone tests (no agent).


static func opening_actions() -> Array:
	return [
		{"type": "PLACE_TOWER", "tower_id": "basic_tower", "spot_id": "F1_C"},
		{"type": "PLACE_TOWER", "tower_id": "basic_tower", "spot_id": "F1_B"},
		{"type": "PLACE_TOWER", "tower_id": "basic_tower", "spot_id": "F1_A"},
		{"type": "START_WAVE"},
	]


static func maybe_act(sim) -> void:
	if sim == null or sim.is_finished():
		return
	var st: Dictionary = sim.state()
	if bool(st.get("wave_running")) or bool(st.get("game_over")) or bool(st.get("level_complete")):
		return
	if int(st.get("gold", 0)) >= 150:
		var upgraded := false
		for a in sim.get_available_actions():
			if str(a.get("type")) == "UPGRADE_TOWER" and str(a.get("runtime_id")) == "T0001":
				sim.execute(a)
				upgraded = true
				break
		if not upgraded:
			for a2 in sim.get_available_actions():
				if str(a2.get("type")) == "PLACE_TOWER" and str(a2.get("tower_id")) == "basic_tower":
					sim.execute(a2)
					break
	sim.execute({"type": "START_WAVE"})

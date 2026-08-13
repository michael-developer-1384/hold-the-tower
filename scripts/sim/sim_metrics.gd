class_name SimMetrics
extends RefCounted

## Build SimulationResult + aggregate balance reports.


static func build_result(sim, wall_ms: int) -> Dictionary:
	var game = sim.game
	var telemetry = sim.telemetry
	var won := game != null and bool(game.get("level_complete"))
	var core_hp := int(game.get("core_hp")) if game else 0
	var spawned := int(telemetry.get("enemies_spawned")) if telemetry and "enemies_spawned" in telemetry else 0
	var killed := int(telemetry.get("enemies_killed")) if telemetry and "enemies_killed" in telemetry else 0
	var leaked := int(telemetry.get("enemies_leaked")) if telemetry and "enemies_leaked" in telemetry else 0
	var towers_built := int(telemetry.get("towers_built")) if telemetry and "towers_built" in telemetry else 0
	var total_damage := 0.0
	var same_floor := 0.0
	var cross_floor := 0.0
	var tower_stats: Array = []
	if game != null:
		for t in game.get_tree().get_nodes_in_group("towers"):
			if t == null or not is_instance_valid(t):
				continue
			var tid := str(t.get("tower_type"))
			if tid.is_empty():
				continue
			var dmg := float(t.get("damage_dealt")) if "damage_dealt" in t else 0.0
			total_damage += dmg
			same_floor += float(t.get("same_floor_damage")) if "same_floor_damage" in t else 0.0
			cross_floor += float(t.get("cross_floor_damage")) if "cross_floor_damage" in t else 0.0
			tower_stats.append({
				"tower_type": tid,
				"runtime_id": str(t.get("runtime_id")),
				"spot_id": str(t.get("build_spot_id")),
				"floor_id": str(t.get("floor_id")),
				"damage": dmg,
				"kills": int(t.get("kills")) if "kills" in t else 0,
				"shots": int(t.get("shots_fired")) if "shots_fired" in t else 0,
				"hits": int(t.get("hits")) if "hits" in t else 0,
				"overkill": float(t.get("overkill_damage")) if "overkill_damage" in t else 0.0,
				"gold_invested": int(t.get("gold_invested")) if "gold_invested" in t else 0,
				"target_time": float(t.get("target_time")) if "target_time" in t else 0.0,
				"no_target_time": float(t.get("no_target_time")) if "no_target_time" in t else 0.0,
				"same_floor_damage": float(t.get("same_floor_damage")) if "same_floor_damage" in t else 0.0,
				"cross_floor_damage": float(t.get("cross_floor_damage")) if "cross_floor_damage" in t else 0.0,
				"level": int(t.get("level")) if "level" in t else 1,
			})
	var sim_seconds := float(sim.clock.sim_time) if sim.clock else 0.0
	var wall_seconds := float(wall_ms) / 1000.0
	var speed := sim_seconds / maxf(wall_seconds, 0.0001)
	var gold_earned := 0
	var gold_spent := 0
	if typeof(RunManager) != TYPE_NIL:
		gold_earned = int(RunManager.gold_earned)
		gold_spent = int(RunManager.gold_spent)
	var waves_reached := int(game.get("active_wave")) if game else 0
	if won and game != null:
		waves_reached = int(game.get("active_wave"))
	return {
		"seed": sim.run_seed,
		"level_id": sim.level_id,
		"difficulty": sim.difficulty_id,
		"won": won,
		"duration": sim_seconds,
		"waves_reached": waves_reached,
		"lives_remaining": core_hp,
		"enemies_spawned": spawned,
		"enemies_killed": killed,
		"enemies_leaked": leaked,
		"credits_earned": gold_earned,
		"credits_spent": gold_spent,
		"towers_placed": towers_built,
		"total_damage": total_damage,
		"same_floor_damage": same_floor,
		"cross_floor_damage": cross_floor,
		"tower_stats": tower_stats,
		"action_log": sim.action_log.duplicate(true),
		"agent_metrics": sim.agent_metrics.duplicate(true),
		"lookahead_stats": sim.lookahead_stats.duplicate(true) if "lookahead_stats" in sim else {},
		"wall_clock": wall_seconds,
		"sim_speed": speed,
		"total_shots": _sum_field(tower_stats, "shots"),
		"total_hits": _sum_field(tower_stats, "hits"),
		"total_overkill": _sum_field(tower_stats, "overkill"),
		"tower_levels": _tower_levels(tower_stats),
	}


static func _sum_field(rows: Array, key: String) -> float:
	var s := 0.0
	for r in rows:
		s += float(r.get(key, 0.0))
	return s


static func _tower_levels(rows: Array) -> Dictionary:
	var out := {}
	for r in rows:
		out[str(r.get("runtime_id", ""))] = int(r.get("level", 1))
	return out


static func aggregate(results: Array, agent_id: String = "") -> Dictionary:
	var n := results.size()
	if n == 0:
		return {"runs": 0, "agent": agent_id}
	var wins := 0
	var lives := 0.0
	var waves := 0.0
	var damage := 0.0
	var duration := 0.0
	var towers := 0.0
	var spent := 0.0
	var wall := 0.0
	var sim_s := 0.0
	var pick: Dictionary = {}
	var dmg_by_type: Dictionary = {}
	for r in results:
		if bool(r.get("won", false)):
			wins += 1
		lives += float(r.get("lives_remaining", 0))
		waves += float(r.get("waves_reached", 0))
		damage += float(r.get("total_damage", 0))
		duration += float(r.get("duration", 0))
		towers += float(r.get("towers_placed", 0))
		spent += float(r.get("credits_spent", 0))
		wall += float(r.get("wall_clock", 0))
		sim_s += float(r.get("duration", 0))
		var seen_types := {}
		for ts in r.get("tower_stats", []):
			var tid := str(ts.get("tower_type", ""))
			if tid.is_empty():
				continue
			seen_types[tid] = true
			dmg_by_type[tid] = float(dmg_by_type.get(tid, 0.0)) + float(ts.get("damage", 0.0))
		for tid in seen_types.keys():
			pick[tid] = int(pick.get(tid, 0)) + 1
	var winrate := float(wins) / float(n)
	var bias_map: Dictionary = {}
	if not results.is_empty():
		var am: Dictionary = results[0].get("agent_metrics", {})
		bias_map = am.get("explicit_biases", {})
	var agent_has_bias := not bias_map.is_empty() or agent_id in ["basic"]
	var is_optimizer := agent_id in ["smart", "optimizer"]
	var warnings: Array = []
	for tid in pick.keys():
		var rate := float(pick[tid]) / float(n)
		var biased := float(bias_map.get(tid, 0.0)) > 0.01 or (agent_has_bias and not is_optimizer)
		if rate >= 0.90:
			if biased:
				warnings.append({
					"severity": "OBSERVATION",
					"type": "HIGH_PICK_RATE",
					"tower_id": tid,
					"pick_rate": rate,
					"interpretation": "INCONCLUSIVE",
					"note": "Agent has explicit preference for this tower.",
				})
			elif is_optimizer and n < 200:
				warnings.append({
					"severity": "SUSPICIOUS",
					"type": "HIGH_PICK_RATE",
					"tower_id": tid,
					"pick_rate": rate,
					"interpretation": "No explicit preference; sample still small.",
				})
			elif is_optimizer and n >= 200:
				warnings.append({
					"severity": "STRONG_SIGNAL",
					"type": "HIGH_PICK_RATE",
					"tower_id": tid,
					"pick_rate": rate,
					"interpretation": "Optimizer over-picks without declared bias.",
				})
			else:
				warnings.append({
					"severity": "OBSERVATION",
					"type": "HIGH_PICK_RATE",
					"tower_id": tid,
					"pick_rate": rate,
					"interpretation": "INCONCLUSIVE",
				})
		if rate <= 0.05:
			warnings.append({
				"severity": "OBSERVATION",
				"type": "LOW_PICK_RATE",
				"tower_id": tid,
				"pick_rate": rate,
			})
	var pick_rates := {}
	for tid in pick.keys():
		pick_rates[tid] = float(pick[tid]) / float(n)
	var dmg_share := {}
	var dmg_total := 0.0
	for v in dmg_by_type.values():
		dmg_total += float(v)
	for tid in dmg_by_type.keys():
		dmg_share[tid] = float(dmg_by_type[tid]) / maxf(dmg_total, 0.0001)
	return {
		"agent": agent_id,
		"runs": n,
		"winrate": winrate,
		"avg_lives_remaining": lives / float(n),
		"avg_waves_reached": waves / float(n),
		"avg_damage": damage / float(n),
		"avg_duration": duration / float(n),
		"avg_towers_built": towers / float(n),
		"avg_credits_spent": spent / float(n),
		"tower_pick_rates": pick_rates,
		"damage_share": dmg_share,
		"avg_sim_speed": (sim_s / maxf(wall, 0.0001)),
		"total_wall_clock": wall,
		"warnings": warnings,
	}


static func format_report(agg: Dictionary, title: String = "HODL THE TOWER – BALANCE REPORT") -> String:
	var lines: PackedStringArray = []
	lines.append(title)
	lines.append("")
	lines.append("Agent: %s" % str(agg.get("agent", "?")))
	lines.append("Runs: %d" % int(agg.get("runs", 0)))
	lines.append("")
	lines.append("Win Rate:             %.1f %%" % (float(agg.get("winrate", 0.0)) * 100.0))
	lines.append("Avg Lives Remaining:  %.2f" % float(agg.get("avg_lives_remaining", 0.0)))
	lines.append("Avg Waves Reached:    %.2f" % float(agg.get("avg_waves_reached", 0.0)))
	lines.append("Avg Duration:         %.1fs" % float(agg.get("avg_duration", 0.0)))
	lines.append("Avg Towers Built:     %.2f" % float(agg.get("avg_towers_built", 0.0)))
	lines.append("Avg Credits Spent:    %.0f" % float(agg.get("avg_credits_spent", 0.0)))
	lines.append("Avg Damage:           %.0f" % float(agg.get("avg_damage", 0.0)))
	lines.append("Sim Speed:            %.0fx realtime" % float(agg.get("avg_sim_speed", 0.0)))
	lines.append("")
	lines.append("Tower Pick Rates:")
	var picks: Dictionary = agg.get("tower_pick_rates", {})
	for tid in picks.keys():
		lines.append("  %-20s %.0f %%" % [tid, float(picks[tid]) * 100.0])
	lines.append("")
	lines.append("Damage Distribution:")
	var share: Dictionary = agg.get("damage_share", {})
	for tid in share.keys():
		lines.append("  %-20s %.0f %%" % [tid, float(share[tid]) * 100.0])
	var warnings: Array = agg.get("warnings", [])
	if not warnings.is_empty():
		lines.append("")
		lines.append("Warnings:")
		for w in warnings:
			lines.append("  [%s] %s %s (%.0f%%) %s" % [
				str(w.get("severity", "OBSERVATION")),
				str(w.get("type")),
				str(w.get("tower_id")),
				float(w.get("pick_rate", 0)) * 100.0,
				str(w.get("interpretation", "")),
			])
	return "\n".join(lines)

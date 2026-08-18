extends RefCounted

## Leave-one-out synergy. Not additive — Shapley is the consistent allocation.

const Counterfactual := preload("res://scripts/balance/counterfactual_runner.gd")


static func analyze(tree: SceneTree, opts: Dictionary) -> Dictionary:
	var log: Array = opts.get("action_log", [])
	var spots: PackedStringArray = Counterfactual.placed_spots(log)
	var baseline: Dictionary = await Counterfactual.replay(tree, opts)
	var by_spot := {}
	var synergy_by_other := {}
	for sid in spots:
		var one := opts.duplicate(true)
		one["spot_id"] = str(sid)
		var cf: Dictionary = await Counterfactual.run(tree, one)
		var without: Dictionary = cf.get("without", {})
		var tower := _row_for_spot(baseline, str(sid))
		var direct := float(tower.get("damage", 0.0))
		var others_base := float(baseline.get("total_damage", 0.0)) - direct
		var others_without := float(without.get("total_damage", 0.0))
		var indirect := others_base - others_without
		var displaced := maxf(-indirect, 0.0)
		var enabled := maxf(indirect, 0.0)
		by_spot[sid] = {
			"spot_id": sid,
			"tower_type": str(tower.get("tower_type", "")),
			"direct_damage": direct,
			"indirect_damage_enabled": enabled,
			"damage_displaced_from_others": displaced,
			"synergy_total": enabled,
			"delta": cf.get("delta", {}),
		}
		for other in baseline.get("tower_stats", []):
			var oid := str(other.get("spot_id", ""))
			if oid == sid:
				continue
			var other_without := _row_for_spot(without, oid)
			var d := float(other.get("damage", 0.0)) - float(other_without.get("damage", 0.0))
			if not synergy_by_other.has(sid):
				synergy_by_other[sid] = {}
			synergy_by_other[sid][oid] = d
		if by_spot.has(sid):
			by_spot[sid]["synergy_by_other_tower"] = synergy_by_other.get(sid, {})
	return {
		"baseline_total_damage": float(baseline.get("total_damage", 0.0)),
		"by_spot": by_spot,
		"limits": "Leave-one-out marginals are not additive and can double-count shared value. Use Shapley for a partition of the grand coalition.",
	}


static func _row_for_spot(result: Dictionary, spot_id: String) -> Dictionary:
	for row in result.get("tower_stats", []):
		if str(row.get("spot_id")) == spot_id:
			return row
	return {}

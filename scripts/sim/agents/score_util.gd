extends RefCounted

const TYPE_MECH := "mechanical"
const TYPE_BIAS := "behavioral_bias"
const TYPE_LOOK := "lookahead"
const TYPE_KNOWN := "known"


static func part(value: float, kind: String) -> Dictionary:
	return {"value": value, "type": kind}


static func finalize(parts: Dictionary) -> Dictionary:
	var mech := 0.0
	var bias := 0.0
	var look := 0.0
	for k in parts.keys():
		if k in ["mechanical_total", "behavioral_total", "lookahead_total", "total"]:
			continue
		var item = parts[k]
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var v := float(item.get("value", 0.0))
		match str(item.get("type", TYPE_MECH)):
			TYPE_BIAS:
				bias += v
			TYPE_LOOK:
				look += v
			_:
				mech += v
	parts["mechanical_total"] = mech
	parts["behavioral_total"] = bias
	parts["lookahead_total"] = look
	parts["total"] = mech + bias + look
	return parts


static func def_from_action(action: Dictionary) -> Dictionary:
	return {
		"tower_id": str(action.get("tower_id", "")),
		"cost": float(action.get("cost", 100)),
		"base_range": float(action.get("base_range", 4.0)),
		"base_damage": float(action.get("base_damage", 25.0)),
		"base_fire_interval": float(action.get("base_fire_interval", 0.8)),
		"range_shape": str(action.get("range_shape", "SPHERE_3D")),
		"unit_count": int(action.get("unit_count", 1)),
		"feature_ids": action.get("feature_ids", PackedStringArray()),
		"role": str(action.get("role", "")),
		"upgrade_range_bonus": float(action.get("upgrade_range_bonus", 0.0)),
	}


static func has_feature(action: Dictionary, feature_id: String) -> bool:
	var ids = action.get("feature_ids", PackedStringArray())
	if typeof(ids) == TYPE_PACKED_STRING_ARRAY:
		return feature_id in ids
	if typeof(ids) == TYPE_ARRAY:
		return feature_id in ids
	return false


static func estimated_dps(action: Dictionary) -> float:
	var Combat = load("res://scripts/balance/combat_value_model.gd")
	return float(Combat.theoretical_dps(action))


static func mechanical_score(action: Dictionary, ctx: Dictionary = {}) -> float:
	var Combat = load("res://scripts/balance/combat_value_model.gd")
	return float(Combat.mechanical_score(action, ctx))

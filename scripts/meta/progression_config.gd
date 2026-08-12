class_name ProgressionConfig
extends RefCounted

## Player level XP thresholds, research investment unlock fractions, and tower capacity.


static func max_level() -> int:
	return 10


static func xp_thresholds() -> PackedInt32Array:
	return PackedInt32Array([0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200])


static func investment_cap_fractions() -> PackedFloat32Array:
	return PackedFloat32Array([0.15, 0.22, 0.30, 0.38, 0.46, 0.55, 0.65, 0.77, 0.90, 1.00])


static func sentry_capacity_by_level() -> PackedInt32Array:
	return PackedInt32Array([120, 170, 220, 280, 340, 410, 480, 540, 595, 650])


static func guard_capacity_by_level() -> PackedInt32Array:
	return PackedInt32Array([190, 270, 350, 450, 545, 655, 770, 865, 955, 1040])


static func xp_for_level(level: int) -> int:
	var t := xp_thresholds()
	var idx := clampi(level, 1, max_level()) - 1
	return int(t[idx])


static func level_from_xp(xp: int) -> int:
	var t := xp_thresholds()
	var lvl := 1
	for i in range(t.size()):
		if xp >= int(t[i]):
			lvl = i + 1
		else:
			break
	return mini(lvl, max_level())


## XP progress within the current level toward the next (capped at max level).
static func xp_into_level(xp: int) -> Dictionary:
	var lvl := level_from_xp(xp)
	var cur := xp_for_level(lvl)
	if lvl >= max_level():
		return {
			"level": lvl,
			"xp_in_level": maxi(0, xp - cur),
			"xp_to_next": 0,
			"xp_need": 0,
			"at_cap": true,
		}
	var nxt := xp_for_level(lvl + 1)
	return {
		"level": lvl,
		"xp_in_level": maxi(0, xp - cur),
		"xp_to_next": maxi(0, nxt - xp),
		"xp_need": nxt - cur,
		"at_cap": false,
		"xp_next_total": nxt,
	}


static func investment_cap_fraction(level: int) -> float:
	var fracs := investment_cap_fractions()
	var idx := clampi(level, 1, max_level()) - 1
	return float(fracs[idx])


static func investment_cap_rp(max_investment_rp: int, level: int) -> int:
	return int(floor(float(max_investment_rp) * investment_cap_fraction(level)))


static func fraction_label(level: int) -> String:
	return "%d %%" % int(round(investment_cap_fraction(level) * 100.0))


static func tower_capacity(tower_id: String, level: int) -> int:
	var idx := clampi(level, 1, max_level()) - 1
	match tower_id:
		"basic_tower":
			return int(sentry_capacity_by_level()[idx])
		"guard_post":
			return int(guard_capacity_by_level()[idx])
		_:
			return 0


static func theoretical_max_investment(tower_id: String) -> int:
	match tower_id:
		"basic_tower":
			return 960
		"guard_post":
			return 1540
		_:
			return 0


## Unlock summary for a given player level (roadmap / next-level UI).
static func unlocks_for_level(level: int) -> Dictionary:
	var lvl := clampi(level, 1, max_level())
	var prev := maxi(1, lvl - 1)
	var out := {
		"level": lvl,
		"research_cap_fraction": investment_cap_fraction(lvl),
		"research_cap_label": fraction_label(lvl),
		"prev_research_cap_label": fraction_label(prev),
		"sentry_capacity": tower_capacity("basic_tower", lvl),
		"guard_capacity": tower_capacity("guard_post", lvl),
		"prev_sentry_capacity": tower_capacity("basic_tower", prev),
		"prev_guard_capacity": tower_capacity("guard_post", prev),
		"placeholder_unlocks": [],
	}
	var placeholders: Array = []
	if lvl == 6:
		placeholders.append("Tower unlock (placeholder)")
	elif lvl == 8:
		placeholders.append("Tower unlock (placeholder)")
	out["placeholder_unlocks"] = placeholders
	return out


static func roadmap() -> Array:
	var out: Array = []
	for lvl in range(1, max_level() + 1):
		var entry := unlocks_for_level(lvl)
		entry["xp_required"] = xp_for_level(lvl)
		out.append(entry)
	return out

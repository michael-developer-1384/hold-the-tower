class_name ProgressionConfig
extends RefCounted

## Player level XP thresholds and research investment unlock fractions.


static func max_level() -> int:
	return 10


static func xp_thresholds() -> PackedInt32Array:
	return PackedInt32Array([0, 50, 150, 300, 500, 750, 1050, 1400, 1800, 2250])


static func investment_cap_fractions() -> PackedFloat32Array:
	return PackedFloat32Array([0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 0.95, 1.00])


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

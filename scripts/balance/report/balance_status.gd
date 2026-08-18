extends RefCounted

## Single classification + warning rules. HTML/AI/CLI must not reimplement this.

const Targets := preload("res://scripts/balance/balance_targets.gd")

const WITHIN := "WITHIN_TARGET"
const BELOW := "BELOW_TARGET"
const SEVERELY := "SEVERELY_BELOW_TARGET"
const ABOVE := "ABOVE_TARGET"
const NOT_MEASURED := "NOT_MEASURED"


static func tower_status(tower_id: String, relative_anchor: Variant) -> String:
	if relative_anchor == null:
		return NOT_MEASURED
	var rel := float(relative_anchor)
	var t: Dictionary = Targets.for_tower(tower_id)
	if t.is_empty():
		return NOT_MEASURED
	var lo := float(t.get("relative_value_gold_min", 0.85))
	var hi := float(t.get("relative_value_gold_max", 1.15))
	if rel < lo * 0.35:
		return SEVERELY
	if rel < lo:
		return BELOW
	if rel > hi * 1.25:
		return ABOVE
	if rel > hi:
		return ABOVE
	return WITHIN


static func difficulty_status(ctx: Dictionary = {}) -> String:
	var has_fb := bool(ctx.get("has_full_build", false))
	var has_fid := str(ctx.get("fidelity_status", "")) == "PASS"
	var has_margin := ctx.get("defense_margin") != null
	if not has_fb or not has_fid or not has_margin:
		if not has_fb:
			return "NEEDS_FULL_BUILD_MEASUREMENT"
		return "NOT_MEASURED"
	var competent = ctx.get("competent_build")
	var optimizer = ctx.get("optimizer_build")
	var opt_loss := typeof(optimizer) == TYPE_DICTIONARY and not bool(optimizer.get("won", true))
	var bands: Dictionary = Targets.difficulty_bands()
	if opt_loss and bool(bands.get("unsolvable_if_optimizer_loss", true)):
		return "UNSOLVABLE"
	var margin_v = null
	var dm = ctx.get("defense_margin")
	if typeof(dm) == TYPE_DICTIONARY:
		margin_v = dm.get("margin")
	if margin_v == null:
		return "NOT_MEASURED"
	var m := float(margin_v)
	if m < float(bands.get("too_hard_margin_max", 1.02)):
		return "TOO_HARD"
	if m < float(bands.get("hard_margin_max", 1.08)):
		return "HARD"
	if m < float(bands.get("balanced_margin_max", 1.22)):
		return "BALANCED"
	if m < float(bands.get("easy_margin_max", 1.40)):
		return "EASY"
	return "TOO_EASY"


static func display_status(code: String) -> String:
	match code:
		WITHIN:
			return "WITHIN TARGET"
		BELOW:
			return "BELOW TARGET"
		SEVERELY:
			return "SEVERELY BELOW TARGET"
		ABOVE:
			return "ABOVE TARGET"
		NOT_MEASURED:
			return "NOT MEASURED"
		"NEEDS_FULL_BUILD_MEASUREMENT":
			return "NEEDS FULL-BUILD MEASUREMENT"
		"TOO_EASY":
			return "TOO EASY"
		"EASY":
			return "EASY"
		"BALANCED":
			return "BALANCED"
		"HARD":
			return "HARD"
		"TOO_HARD":
			return "TOO HARD"
		"UNSOLVABLE":
			return "UNSOLVABLE"
		_:
			return code.replace("_", " ")


static func sensitivity_band(cv: float) -> String:
	return Targets.sensitivity_band(cv)


static func warnings(ctx: Dictionary) -> Array:
	var out: Array = []
	var towers: Dictionary = ctx.get("towers", {})
	var melt: Dictionary = ctx.get("meltdown", {})
	var pressure: Dictionary = ctx.get("level", {})
	var has_cf := ctx.get("counterfactual") != null
	var has_fb := bool(ctx.get("has_full_build", false))
	for tid in ["basic_tower", "guard_post", "lava_tower"]:
		var row: Dictionary = towers.get(tid, {})
		var st := str(row.get("status", NOT_MEASURED))
		if st == SEVERELY:
			out.append(_w("CRITICAL", "MELTDOWN_BELOW_TARGET" if tid == "lava_tower" else "TOWER_SEVERELY_BELOW_TARGET",
				"%s median value/gold is far below the anchor band." % str(row.get("display_name", tid)),
				{"relative_anchor": row.get("relative_to_anchor_median")}))
		elif st == BELOW:
			out.append(_w("WARNING", "TOWER_BELOW_TARGET",
				"%s is below the target value/gold band." % str(row.get("display_name", tid)),
				{"relative_anchor": row.get("relative_to_anchor_median")}))
		elif st == WITHIN:
			out.append(_w("INFO", "TOWER_WITHIN_TARGET",
				"%s isolated value/gold is within target." % str(row.get("display_name", tid)),
				{"relative_anchor": row.get("relative_to_anchor_median")}))
	var sentry: Dictionary = towers.get("basic_tower", {})
	if float(sentry.get("max_value_per_gold", 0.0)) > float(sentry.get("median_value_per_gold", 1.0)) * 1.4:
		out.append(_w("NOTICE", "PLACEMENT_OUTLIER",
			"%s is an unusually strong Sentry placement." % str(sentry.get("best_spot", "")),
			{"best_spot": sentry.get("best_spot")}))
	if not has_cf:
		out.append(_w("NOTICE", "GUARD_COUNTERFACTUAL_REQUIRED",
			"Guard isolated value excludes some realized blocking synergy.", {}))
	if not has_fb:
		out.append(_w("WARNING", "NORMAL_FULL_BUILD_NOT_MEASURED",
			"No representative full-build benchmark exists for this difficulty.", {}))
	var peak_frac = melt.get("peak_damage_fraction")
	if peak_frac != null and float(peak_frac) < 0.25:
		out.append(_w("CRITICAL", "MELTDOWN_RAMP_NOT_REACHED",
			"Meltdown does not reach 25% of nominal cell damage during the benchmark.",
			{"peak_damage_fraction": peak_frac, "t_25": melt.get("t_25")}))
	var min_dps := float(pressure.get("theoretical_minimum_sustained_dps", 0.0))
	if min_dps < 20.0 and min_dps > 0.0:
		out.append(_w("WARNING", "NORMAL_FULL_BUILD_MARGIN_HIGH",
			"Isolated pressure window implies a very high defense margin vs incoming HP.",
			{"min_sustained_dps": min_dps}))
	return out


static func _w(severity: String, code: String, message: String, evidence: Dictionary) -> Dictionary:
	return {"severity": severity, "code": code, "message": message, "evidence": evidence}


static func findings(warnings_list: Array) -> Array:
	var out: Array = []
	for w in warnings_list:
		if str(w.get("severity", "")) in ["CRITICAL", "WARNING", "NOTICE"]:
			out.append(w)
	return out

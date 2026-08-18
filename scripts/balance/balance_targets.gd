extends RefCounted

## Descriptive + numeric design bands. Diagnosis only — never auto-tunes combat.


static func combat_value_weights() -> Dictionary:
	## Realized combat value is in enemy-HP units. Blocking seconds have weight 0.
	## A prevented leak is priced at typical remaining enemy HP; a preserved core HP
	## is priced as a full leak of a standard bot.
	return {
		"direct_damage": 1.0,
		"indirect_damage": 1.0,
		"leak_prevention": 120.0,
		"core_hp_preservation": 120.0,
		"other_utility": 1.0,
	}


static func difficulty_bands() -> Dictionary:
	## Margin = max survivable combined health×speed pressure on the optimizer build.
	return {
		"unsolvable_if_optimizer_loss": true,
		"too_hard_margin_max": 1.02,
		"hard_margin_max": 1.08,
		"balanced_margin_max": 1.22,
		"easy_margin_max": 1.40,
		"too_easy_margin_max": 1.80,
	}


static func meltdown_search_weights() -> Dictionary:
	return {
		"economic_target_fit": 1.0,
		"placement_target_fit": 0.8,
		"early_roi_target_fit": 0.7,
		"cross_floor_target_fit": 0.9,
		"ramp_health": 1.1,
		"excessive_void_loss_penalty": 0.6,
		"excessive_decay_penalty": 0.35,
		"degenerate_behavior_penalty": 1.2,
	}


static func all() -> Dictionary:
	return {
		"basic_tower": {
			"display_name": "Sentry",
			"role": "reliable baseline, immediate power",
			"placement_sensitivity": "low_medium",
			"relative_value_gold_min": 0.85,
			"relative_value_gold_max": 1.15,
			"placement_sensitivity_min": 0.0,
			"placement_sensitivity_max": 0.28,
			"early_late_ratio_min": 0.90,
			"early_late_ratio_max": 1.25,
		},
		"guard_post": {
			"display_name": "Guard",
			"role": "similar economic efficiency, high indirect value, choke-dependent",
			"placement_sensitivity": "medium_high",
			"relative_value_gold_min": 0.85,
			"relative_value_gold_max": 1.20,
			"placement_sensitivity_min": 0.18,
			"placement_sensitivity_max": 0.55,
			"early_late_ratio_min": 0.85,
			"early_late_ratio_max": 1.30,
		},
		"lava_tower": {
			"display_name": "Meltdown",
			"role": "weaker immediate output, strong early ROI, high placement sensitivity, persistent area, long-run ROI, cross-floor",
			"placement_sensitivity": "high",
			"relative_value_gold_min": 0.70,
			"relative_value_gold_max": 1.40,
			"placement_sensitivity_min": 0.30,
			"placement_sensitivity_max": 0.90,
			"early_late_ratio_min": 1.10,
			"early_late_ratio_max": 2.50,
			"cross_floor_min": 0.08,
		},
		"combat_value_weights": combat_value_weights(),
		"difficulty_bands": difficulty_bands(),
		"meltdown_search_weights": meltdown_search_weights(),
	}


static func for_tower(tower_id: String) -> Dictionary:
	return all().get(tower_id, {})


static func sensitivity_band(cv: float) -> String:
	if cv < 0.15:
		return "LOW"
	if cv < 0.35:
		return "MEDIUM"
	if cv < 0.55:
		return "MEDIUM/HIGH"
	return "HIGH"

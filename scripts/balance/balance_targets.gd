extends RefCounted

## Descriptive + numeric design bands. Diagnosis only — never auto-tunes combat.


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

class_name MarketEvent
extends RefCounted

const MarketConfig := preload("res://scripts/market/market_config.gd")

const COMPONENT_KEYS := [
	"spawn",
	"carry",
	"advance",
	"damage",
	"kill",
	"buy",
	"core",
]


static func empty_components() -> Dictionary:
	var out := {}
	for key in COMPONENT_KEYS:
		out[key] = 0.0
	return out


static func normalize_components(value: Dictionary) -> Dictionary:
	var out := empty_components()
	for key in COMPONENT_KEYS:
		out[key] = float(value.get(key, 0.0))
	return out


static func net_delta(components: Dictionary) -> float:
	var total := 0.0
	for key in COMPONENT_KEYS:
		total += float(components.get(key, 0.0))
	return total


static func make(
	run_time_ms: int,
	wall_time_ms: int,
	event_type: String,
	price_before: float,
	components: Dictionary,
	metadata: Dictionary = {}
) -> Dictionary:
	var normalized := normalize_components(components)
	var delta := net_delta(normalized)
	return {
		"run_time_ms": run_time_ms,
		"wall_time_ms": wall_time_ms,
		"event_type": event_type,
		"price_before": price_before,
		"delta": delta,
		"price_after": maxf(MarketConfig.MIN_HODL_PRICE, price_before + delta),
		"components": normalized,
		"metadata": metadata.duplicate(true),
	}

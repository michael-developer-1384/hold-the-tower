class_name MarketTape
extends RefCounted

const MarketConfig := preload("res://scripts/market/market_config.gd")

var opening_price: float = MarketConfig.INITIAL_HODL_PRICE
var entries: Array = []


func _init(price: float = MarketConfig.INITIAL_HODL_PRICE) -> void:
	opening_price = maxf(price, MarketConfig.MIN_HODL_PRICE)


func append(entry: Dictionary, allow_flat: bool = false) -> Dictionary:
	var copy := entry.duplicate(true)
	var delta := float(copy.get("delta", 0.0))
	if is_zero_approx(delta) and not allow_flat:
		return {}
	entries.append(copy)
	return copy


func current_price() -> float:
	if entries.is_empty():
		return opening_price
	return float(entries.back().get("price_after", opening_price))


func high() -> float:
	var value := opening_price
	for entry in entries:
		value = maxf(value, float(entry.get("price_before", value)))
		value = maxf(value, float(entry.get("price_after", value)))
	return value


func low() -> float:
	var value := opening_price
	for entry in entries:
		value = minf(value, float(entry.get("price_before", value)))
		value = minf(value, float(entry.get("price_after", value)))
	return value


func entries_between(start_ms: int, end_ms: int = -1) -> Array:
	var out: Array = []
	for entry in entries:
		var t := int(entry.get("run_time_ms", 0))
		if t < start_ms:
			continue
		if end_ms >= 0 and t >= end_ms:
			continue
		out.append(entry.duplicate(true))
	return out


func capture() -> Dictionary:
	return {
		"opening_price": opening_price,
		"entries": entries.duplicate(true),
	}


func restore(data: Dictionary) -> void:
	opening_price = maxf(
		float(data.get("opening_price", MarketConfig.INITIAL_HODL_PRICE)),
		MarketConfig.MIN_HODL_PRICE
	)
	entries = data.get("entries", []).duplicate(true)

class_name MarketStatistics
extends RefCounted

const MarketEvent := preload("res://scripts/market/market_event.gd")


static func from_tape(tape: RefCounted) -> Dictionary:
	if tape == null:
		return {}
	var open_price: float = float(tape.opening_price)
	var close_price: float = float(tape.current_price())
	var high_price: float = float(tape.high())
	var low_price: float = float(tape.low())
	var peak: float = open_price
	var max_drawdown := 0.0
	var attribution := MarketEvent.empty_components()
	for entry in tape.entries:
		var after := float(entry.get("price_after", open_price))
		peak = maxf(peak, after)
		if peak > 0.0:
			max_drawdown = maxf(max_drawdown, (peak - after) / peak)
		var components: Dictionary = entry.get("components", {})
		for key in MarketEvent.COMPONENT_KEYS:
			attribution[key] = float(attribution[key]) + float(components.get(key, 0.0))
	return {
		"hodl_open": open_price,
		"hodl_close": close_price,
		"hodl_high": high_price,
		"hodl_low": low_price,
		"session_return": MarketPricing.session_return(close_price, open_price),
		"max_drawdown": max_drawdown,
		"market_attribution": attribution,
		"buy_market_impact": float(attribution.get("buy", 0.0)),
	}

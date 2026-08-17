class_name HodlCandleBook
extends RefCounted

## Simple OHLC store. Session owns open/close timing. History never recomputes.

const MAX_VISIBLE_CANDLES := 50

var candles: Array = []
var live: Dictionary = {}
var live_wave: int = 0


func open_candle(wave: int, price: float) -> Dictionary:
	if has_live():
		push_warning("HodlCandleBook.open_candle(%d) while wave %d is still live" % [wave, live_wave])
		return live.duplicate(true)
	var v := float(price)
	live_wave = wave
	live = {
		"wave": wave,
		"open": v,
		"high": v,
		"low": v,
		"close": v,
		"is_live": true,
	}
	return live.duplicate(true)


func sample(price: float) -> Dictionary:
	if not has_live():
		return {}
	var v := float(price)
	live["high"] = maxf(float(live.get("high", v)), v)
	live["low"] = minf(float(live.get("low", v)), v)
	live["close"] = v
	return live.duplicate(true)


func close_candle(price: float) -> Dictionary:
	if not has_live():
		return {}
	sample(price)
	var closed: Dictionary = live.duplicate(true)
	closed["is_live"] = false
	candles.append(closed)
	while candles.size() > MAX_VISIBLE_CANDLES:
		candles.pop_front()
	live = {}
	live_wave = 0
	return closed


func has_live() -> bool:
	return not live.is_empty()


func visible_candles() -> Array:
	var out: Array = candles.duplicate(true)
	if has_live():
		out.append(live.duplicate(true))
	return out


func capture() -> Dictionary:
	return {
		"candles": candles.duplicate(true),
		"live": live.duplicate(true),
		"live_wave": live_wave,
	}


func restore(data: Dictionary) -> void:
	candles.clear()
	for entry in data.get("candles", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		candles.append(_normalize_candle(entry, false))
	live = {}
	live_wave = int(data.get("live_wave", 0))
	var live_data = data.get("live", {})
	if typeof(live_data) == TYPE_DICTIONARY and not live_data.is_empty():
		live = _normalize_candle(live_data, true)
		live_wave = int(live.get("wave", live_wave))


func _normalize_candle(entry: Dictionary, is_live: bool) -> Dictionary:
	return {
		"wave": int(entry.get("wave", 0)),
		"open": float(entry.get("open", 0.0)),
		"high": float(entry.get("high", 0.0)),
		"low": float(entry.get("low", 0.0)),
		"close": float(entry.get("close", 0.0)),
		"is_live": is_live,
	}

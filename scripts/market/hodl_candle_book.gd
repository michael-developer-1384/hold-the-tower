class_name HodlCandleBook
extends RefCounted

## One OHLC candle per combat wave. Historical candles never recompute.
## Opening Bell arms a wave; first real threat sample opens OHLC.

const MAX_VISIBLE_CANDLES := 50

var candles: Array = []
var live: Dictionary = {}
var live_wave: int = 0
var armed_wave: int = 0


func arm_candle(wave: int) -> void:
	if has_live():
		close_live()
	armed_wave = wave
	live_wave = 0
	live = {}


func open_armed(index: float) -> Dictionary:
	if has_live():
		return live.duplicate(true)
	var wave := armed_wave if armed_wave > 0 else live_wave
	if wave <= 0:
		return {}
	var v := float(index)
	live_wave = wave
	armed_wave = 0
	live = {
		"wave": wave,
		"open": v,
		"high": v,
		"low": v,
		"close": v,
		"is_live": true,
	}
	return live.duplicate(true)


func start_candle(wave: int, index: float) -> Dictionary:
	arm_candle(wave)
	return open_armed(index)


func sample(index: float) -> Dictionary:
	if not has_live():
		return {}
	var v := float(index)
	live["high"] = maxf(float(live.get("high", v)), v)
	live["low"] = minf(float(live.get("low", v)), v)
	live["close"] = v
	return live.duplicate(true)


func close_live(index: float = NAN) -> Dictionary:
	if is_armed() and not has_live():
		var v := 100.0 if is_nan(index) else float(index)
		open_armed(v)
	if not has_live():
		return {}
	if not is_nan(index):
		sample(index)
	var closed: Dictionary = live.duplicate(true)
	closed["is_live"] = false
	candles.append(closed)
	while candles.size() > MAX_VISIBLE_CANDLES:
		candles.pop_front()
	live = {}
	live_wave = 0
	armed_wave = 0
	return closed


func has_live() -> bool:
	return not live.is_empty()


func is_armed() -> bool:
	return armed_wave > 0 and not has_live()


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
		"armed_wave": armed_wave,
	}


func restore(data: Dictionary) -> void:
	candles.clear()
	for entry in data.get("candles", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		candles.append(_normalize_candle(entry, false))
	live = {}
	live_wave = int(data.get("live_wave", 0))
	armed_wave = int(data.get("armed_wave", 0))
	var live_data = data.get("live", {})
	if typeof(live_data) == TYPE_DICTIONARY and not live_data.is_empty():
		live = _normalize_candle(live_data, true)
		live_wave = int(live.get("wave", live_wave))
		armed_wave = 0


func _normalize_candle(entry: Dictionary, is_live: bool) -> Dictionary:
	return {
		"wave": int(entry.get("wave", 0)),
		"open": float(entry.get("open", 0.0)),
		"high": float(entry.get("high", 0.0)),
		"low": float(entry.get("low", 0.0)),
		"close": float(entry.get("close", 0.0)),
		"is_live": is_live,
	}

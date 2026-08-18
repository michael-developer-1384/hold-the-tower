class_name CandleAggregator
extends RefCounted


static func fixed_time(
	tape: RefCounted,
	interval_ms: int,
	end_time_ms: int = -1
) -> Array:
	if tape == null or interval_ms <= 0:
		return []
	var candles: Array = []
	var by_bucket := {}
	for entry in tape.entries:
		var run_ms := int(entry.get("run_time_ms", 0))
		if end_time_ms >= 0 and run_ms > end_time_ms:
			continue
		var bucket := int(floor(float(run_ms) / float(interval_ms))) * interval_ms
		if not by_bucket.has(bucket):
			by_bucket[bucket] = {
				"start_ms": bucket,
				"end_ms": bucket + interval_ms,
				"open": float(entry.get("price_before", tape.opening_price)),
				"high": maxf(
					float(entry.get("price_before", tape.opening_price)),
					float(entry.get("price_after", tape.opening_price))
				),
				"low": minf(
					float(entry.get("price_before", tape.opening_price)),
					float(entry.get("price_after", tape.opening_price))
				),
				"close": float(entry.get("price_after", tape.opening_price)),
				"events": 0,
				"is_live": end_time_ms >= 0 and bucket <= end_time_ms and end_time_ms < bucket + interval_ms,
			}
		var candle: Dictionary = by_bucket[bucket]
		candle["high"] = maxf(
			float(candle["high"]),
			maxf(float(entry.get("price_before", 0.0)), float(entry.get("price_after", 0.0)))
		)
		candle["low"] = minf(
			float(candle["low"]),
			minf(float(entry.get("price_before", 0.0)), float(entry.get("price_after", 0.0)))
		)
		candle["close"] = float(entry.get("price_after", candle["close"]))
		candle["events"] = int(candle["events"]) + 1
		by_bucket[bucket] = candle
	var keys: Array = by_bucket.keys()
	keys.sort()
	for key in keys:
		candles.append((by_bucket[key] as Dictionary).duplicate(true))
	return candles


static func wave_candles(
	tape: RefCounted,
	boundaries: Array,
	end_time_ms: int,
	current_price: float
) -> Array:
	if tape == null:
		return []
	var out: Array = []
	for i in boundaries.size():
		var boundary: Dictionary = boundaries[i]
		var start_ms := int(boundary.get("start_ms", 0))
		var finish_ms := end_time_ms
		var is_live := true
		if i + 1 < boundaries.size():
			finish_ms = int((boundaries[i + 1] as Dictionary).get("start_ms", end_time_ms))
			is_live = false
		elif boundary.has("end_ms"):
			finish_ms = int(boundary.get("end_ms", end_time_ms))
			is_live = false
		var open_price := float(boundary.get("open", tape.opening_price))
		var candle := {
			"wave": int(boundary.get("wave", i + 1)),
			"start_ms": start_ms,
			"end_ms": finish_ms,
			"open": open_price,
			"high": open_price,
			"low": open_price,
			"close": open_price,
			"events": 0,
			"is_live": is_live,
		}
		var interval_entries: Array = []
		if boundary.has("start_entry_index"):
			var start_index := int(boundary.get("start_entry_index", 0))
			var end_index := int(boundary.get("end_entry_index", tape.entries.size()))
			if i + 1 < boundaries.size():
				end_index = int((boundaries[i + 1] as Dictionary).get(
					"start_entry_index",
					end_index
				))
			for entry_index in range(start_index, mini(end_index, tape.entries.size())):
				interval_entries.append(tape.entries[entry_index])
		else:
			interval_entries = tape.entries_between(start_ms, finish_ms)
		for entry in interval_entries:
			var before := float(entry.get("price_before", open_price))
			var after := float(entry.get("price_after", open_price))
			candle["high"] = maxf(float(candle["high"]), maxf(before, after))
			candle["low"] = minf(float(candle["low"]), minf(before, after))
			candle["close"] = after
			candle["events"] = int(candle["events"]) + 1
		if is_live:
			candle["close"] = current_price
			candle["high"] = maxf(float(candle["high"]), current_price)
			candle["low"] = minf(float(candle["low"]), current_price)
		elif boundary.has("close"):
			var boundary_close := float(boundary.get("close", candle["close"]))
			candle["close"] = boundary_close
			candle["high"] = maxf(float(candle["high"]), boundary_close)
			candle["low"] = minf(float(candle["low"]), boundary_close)
		elif i + 1 < boundaries.size():
			var next_open := float((boundaries[i + 1] as Dictionary).get("open", candle["close"]))
			candle["close"] = next_open
			candle["high"] = maxf(float(candle["high"]), next_open)
			candle["low"] = minf(float(candle["low"]), next_open)
		out.append(candle)
	return out


static func aggregate_ohlc(candles: Array) -> Dictionary:
	if candles.is_empty():
		return {}
	var first: Dictionary = candles.front()
	var last: Dictionary = candles.back()
	var high := float(first.get("high", first.get("open", 0.0)))
	var low := float(first.get("low", first.get("open", 0.0)))
	for candle in candles:
		high = maxf(high, float(candle.get("high", high)))
		low = minf(low, float(candle.get("low", low)))
	return {
		"open": float(first.get("open", 0.0)),
		"high": high,
		"low": low,
		"close": float(last.get("close", 0.0)),
	}

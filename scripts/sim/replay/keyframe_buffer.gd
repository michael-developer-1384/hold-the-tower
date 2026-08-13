extends RefCounted

## Sim-clock keyframe list. Capture function is injected (SimSnapshot, not SessionStore).

var interval: float = 2.0
var _items: Array = []
var _next_at: float = 0.0
var _capture_fn: Callable = Callable()
var _time_fn: Callable = Callable()


func setup(capture_fn: Callable, time_fn: Callable, p_interval: float = 2.0) -> void:
	_capture_fn = capture_fn
	_time_fn = time_fn
	interval = maxf(p_interval, 0.25)
	_items.clear()
	_next_at = 0.0


func maybe_capture(force: bool = false) -> void:
	if not _capture_fn.is_valid():
		return
	var t: float = _now()
	if not force and t + 0.0001 < _next_at:
		return
	var snap = _capture_fn.call()
	if typeof(snap) != TYPE_DICTIONARY:
		return
	_items.append({"t": t, "snapshot": snap})
	_next_at = t + interval


func all() -> Array:
	return _items


func nearest_at_or_before(target: float) -> Dictionary:
	var best: Dictionary = {}
	for item in _items:
		if float(item.get("t", 0.0)) <= target + 0.0001:
			best = item
		else:
			break
	return best


func count() -> int:
	return _items.size()


func _now() -> float:
	if _time_fn.is_valid():
		return float(_time_fn.call())
	return 0.0

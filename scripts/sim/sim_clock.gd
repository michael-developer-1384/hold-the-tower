class_name SimClock
extends RefCounted

## Fixed-step simulation clock with delayed callbacks (replaces SceneTreeTimer in sim).

const SimContextScript := preload("res://scripts/sim/sim_context.gd")
const STEP := 1.0 / 60.0

var sim_time: float = 0.0
var _pending: Array = [] # {at: float, cb: Callable}


func reset() -> void:
	sim_time = 0.0
	_pending.clear()
	SimContextScript.sim_time_ms = 0.0


func schedule(delay: float, cb: Callable) -> void:
	if not cb.is_valid():
		return
	_pending.append({"at": sim_time + maxf(delay, 0.0), "cb": cb})


func step(dt: float = STEP) -> float:
	sim_time += dt
	SimContextScript.sim_time_ms = sim_time * 1000.0
	if _pending.is_empty():
		return dt
	var due: Array = []
	var keep: Array = []
	for item in _pending:
		if float(item.get("at", 0.0)) <= sim_time + 0.000001:
			due.append(item)
		else:
			keep.append(item)
	_pending = keep
	for item in due:
		var cb: Callable = item.get("cb", Callable())
		if cb.is_valid():
			cb.call()
	return dt


func run_ticks(count: int) -> void:
	for _i in count:
		step()

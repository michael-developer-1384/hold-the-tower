extends Node

## World lava field: viscous mass on platforms, gravity drips, void despawn.

const IndexScript := preload("res://scripts/level/platform_surface_index.gd")
const SimContextScript := preload("res://scripts/sim/sim_context.gd")
const LavaConfigScript := preload("res://scripts/world/lava_config.gd")

const CELL_CAP := 200
const AIR_CAP := 64
const MASS_EPS := 0.5
const DROPS_FULL := 100.0
const MASS_MAX := 100.0
const DRIP_SPAWN := 1.0
const DRIP_START_MASS := 2.0
const DAMAGE_THRESHOLD := 2.0
const STAND_INTERVAL := 1.0
const GRAVITY := 18.0
const AIR_DRAG := 0.22
const FLIGHT_SPEED := 1.85
const STICK_RADIUS := 0.85
const IDLE_GRACE := 1.5
const DEFAULT_DAMAGE := 10.0
const DEFAULT_FLOW := 0.45
const DEFAULT_LIFETIME := 8.0
const SURFACE_LIFT := 0.11
const HEIGHT_MIN := 0.016
const HEIGHT_MAX := 0.022
const BLOB_R_MIN := 0.05
const BLOB_R_MAX := 0.36
const BLOB_HIT_FRAC := 0.72
const BLOB_MERGE_FRAC := 0.48
const BLOB_CAP := 12
const BLOB_SEPARATE := 0.16
const PLATE_JITTER := 0.40

var _index = null
var _cells: Dictionary = {}
var _airborne: Array = []
var _contact: Dictionary = {}
var _dwell: Dictionary = {}
var _blobs: Array = []
var _visual_root: Node3D
var _drip_root: Node3D
var _blob_meshes: Array = []
var _drip_meshes: Array = []
var _lava_mat: StandardMaterial3D
var _drip_mat: StandardMaterial3D
var emitted_mass: float = 0.0
var landed_mass: float = 0.0
var same_floor_mass: float = 0.0
var cross_floor_mass: float = 0.0
var void_lost_mass: float = 0.0
var decayed_mass: float = 0.0
var peak_active_cells: int = 0
var peak_damage_cells: int = 0
var _damage_cell_samples: float = 0.0
var _damage_cell_ticks: int = 0
var _sim_age: float = 0.0
var t_first_damage: float = -1.0
var t_25_percent_damage: float = -1.0
var t_50_percent_damage: float = -1.0
var t_90_percent_damage: float = -1.0
var peak_cell_dps: float = 0.0


func setup(level: Resource) -> void:
	_index = IndexScript.from_level(level)
	_cells.clear()
	_airborne.clear()
	_blobs.clear()
	emitted_mass = 0.0
	landed_mass = 0.0
	same_floor_mass = 0.0
	cross_floor_mass = 0.0
	void_lost_mass = 0.0
	decayed_mass = 0.0
	peak_active_cells = 0
	peak_damage_cells = 0
	_damage_cell_samples = 0.0
	_damage_cell_ticks = 0
	_sim_age = 0.0
	t_first_damage = -1.0
	t_25_percent_damage = -1.0
	t_50_percent_damage = -1.0
	t_90_percent_damage = -1.0
	peak_cell_dps = 0.0
	_ensure_visuals()


func surface_index():
	return _index


func cell_count() -> int:
	return _cells.size()


func airborne_count() -> int:
	return _airborne.size()


func _rand_range(from_v: float, to_v: float) -> float:
	if SimContextScript.rng != null and SimContextScript.rng.has_method("randf_range"):
		return float(SimContextScript.rng.randf_range(from_v, to_v))
	return randf_range(from_v, to_v)


func _in_own_level(node: Node) -> bool:
	var host := get_parent()
	if host == null or node == null:
		return host == null
	return host == node or host.is_ancestor_of(node)


func mass_at(ix: int, iz: int, floor_id: String) -> float:
	if _index == null:
		return 0.0
	var cell: Dictionary = _cells.get(_index.cell_key(ix, iz, floor_id), {})
	return float(cell.get("mass", 0.0))


func dps_at(ix: int, iz: int, floor_id: String) -> float:
	if _index == null:
		return 0.0
	return _dps_for_key(_index.cell_key(ix, iz, floor_id))


func apply_burn(enemy: Node3D, slice: float, source: Node = null) -> float:
	if enemy == null or slice <= 0.0 or _index == null:
		return 0.0
	var key := _cell_key_for_enemy(enemy)
	var dps := _dps_for_key(key)
	if dps <= 0.0:
		return 0.0
	var amount := dps * slice
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", amount, source)
	return amount


func emit_drop(
	pos: Vector3,
	vel: Vector3,
	mass: float,
	source_id: String,
	stats: Dictionary = {}
) -> void:
	emitted_mass += mass
	_spawn_drip(pos, vel, mass, source_id, stats)


func emit_toward(
	from: Vector3,
	to: Vector3,
	mass: float,
	source_id: String,
	stats: Dictionary = {}
) -> void:
	emitted_mass += mass
	var dist := from.distance_to(to)
	var t := clampf(dist / FLIGHT_SPEED, 0.80, 2.0)
	var d := to - from
	var vy := clampf(d.y / t + 0.5 * GRAVITY * t, -2.5, 2.8)
	var vel := Vector3(d.x / t, vy, d.z / t)
	_spawn_drip(from, vel, mass, source_id, stats)


func slip_dirs(ix: int, iz: int, floor_id: String) -> Array:
	if _index == null:
		return [Vector2i(1, 0), Vector2i(-1, 0)]
	var edges: Array = []
	for n in _index.neighbor_cells(ix, iz):
		if not _index.is_supported(n.x, n.y, floor_id):
			edges.append(Vector2i(n.x - ix, n.y - iz))
	if edges.size() >= 2:
		for i in edges.size():
			for j in range(i + 1, edges.size()):
				var a: Vector2i = edges[i]
				var b: Vector2i = edges[j]
				if a + b == Vector2i.ZERO:
					return [a, b]
		return [edges[0], edges[1]]
	if edges.size() == 1:
		var a: Vector2i = edges[0]
		return [a, Vector2i(-a.x, -a.y)]
	return [Vector2i(1, 0), Vector2i(-1, 0)]


func field_metrics() -> Dictionary:
	var total_mass := 0.0
	var active := 0
	var damage_cells := 0
	var cross_cells := 0
	var floors := {}
	var tower_floor := ""
	for key in _cells.keys():
		var cell: Dictionary = _cells[key]
		var mass := float(cell.get("mass", 0.0))
		if mass < MASS_EPS:
			continue
		active += 1
		total_mass += mass
		var fid := str(cell.get("floor_id", ""))
		floors[fid] = true
		if _dps_for_key(key) > 0.0:
			damage_cells += 1
		if tower_floor.is_empty():
			tower_floor = fid
	for key2 in _cells.keys():
		var cell2: Dictionary = _cells[key2]
		if float(cell2.get("mass", 0.0)) < MASS_EPS:
			continue
		if str(cell2.get("floor_id", "")) != tower_floor and not tower_floor.is_empty():
			cross_cells += 1
	return {
		"total_lava_mass": total_mass,
		"active_damage_cells": damage_cells,
		"active_cells": active,
		"cross_floor_cells": cross_cells,
		"emitted_mass": emitted_mass,
		"landed_mass": landed_mass,
		"same_floor_mass": same_floor_mass,
		"cross_floor_mass": cross_floor_mass,
		"void_lost_mass": void_lost_mass,
		"decayed_mass": decayed_mass,
		"peak_active_cells": peak_active_cells,
		"peak_damage_cells": peak_damage_cells,
		"average_damage_cells": _damage_cell_samples / float(maxi(_damage_cell_ticks, 1)),
		"peak_cell_dps": peak_cell_dps,
		"t_first_damage": t_first_damage,
		"t_25_percent_damage": t_25_percent_damage,
		"t_50_percent_damage": t_50_percent_damage,
		"t_90_percent_damage": t_90_percent_damage,
		"effective_damage_area": float(damage_cells),
	}


func pour(
	ix: int,
	iz: int,
	floor_id: String,
	mass: float,
	source_id: String,
	stats: Dictionary = {}
) -> void:
	if _index == null or mass <= 0.0:
		return
	emitted_mass += mass
	var sup: Dictionary = _index.support_at(ix, iz, floor_id)
	if sup.is_empty():
		_spawn_drip(
			Vector3(float(ix), 0.4, float(iz)),
			Vector3(0.0, -0.5, 0.0),
			mass,
			source_id,
			stats
		)
		return
	_add_mass(sup, mass, source_id, stats)


func capture_state() -> Dictionary:
	var cells: Array = []
	for key in _cells.keys():
		var c: Dictionary = _cells[key]
		cells.append(c.duplicate(true))
	var air: Array = []
	for d in _airborne:
		var e: Dictionary = d.duplicate(true)
		var p: Vector3 = e.get("pos", Vector3.ZERO)
		var v: Vector3 = e.get("vel", Vector3.ZERO)
		e["pos"] = {"x": p.x, "y": p.y, "z": p.z}
		e["vel"] = {"x": v.x, "y": v.y, "z": v.z}
		air.append(e)
	var blobs: Array = []
	for b in _blobs:
		blobs.append((b as Dictionary).duplicate(true))
	return {"cells": cells, "airborne": air, "blobs": blobs}


func apply_state(snap: Dictionary) -> void:
	_cells.clear()
	_airborne.clear()
	_blobs.clear()
	if _index == null:
		return
	for raw in snap.get("cells", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var c: Dictionary = raw.duplicate(true)
		var key: String = _index.cell_key(int(c.get("ix", 0)), int(c.get("iz", 0)), str(c.get("floor_id", "")))
		_cells[key] = c
	for raw in snap.get("airborne", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = raw.duplicate(true)
		d["pos"] = _vec3(d.get("pos", {}))
		d["vel"] = _vec3(d.get("vel", {}))
		_airborne.append(d)
	for raw in snap.get("blobs", []):
		if typeof(raw) == TYPE_DICTIONARY:
			_blobs.append((raw as Dictionary).duplicate(true))
	if not SimContextScript.skip_presentation():
		_sync_visuals()


func simulate(delta: float) -> void:
	if _index == null:
		return
	_sim_age += delta
	_tick_flow(delta)
	_tick_airborne(delta)
	_tick_decay(delta)
	_tick_damage(delta)
	_enforce_caps()
	_sample_field()


func _physics_process(delta: float) -> void:
	simulate(delta)
	if not SimContextScript.skip_presentation():
		_sync_visuals()


func _add_mass(sup: Dictionary, mass: float, source_id: String, stats: Dictionary) -> void:
	var key: String = _index.cell_key(int(sup.ix), int(sup.iz), str(sup.floor_id))
	var params: Dictionary = LavaConfigScript.resolve(stats, _cells.get(key, {}))
	var cap := float(params.cell_mass_capacity)
	var dmg := float(params.lava_damage)
	var flow := float(params.flow_rate)
	var life := float(params.lava_lifetime)
	if _cells.has(key):
		var cell: Dictionary = _cells[key]
		var old := float(cell.mass)
		var added := minf(mass, cap - old)
		var leftover := mass - added
		if added > 0.0:
			var total := old + added
			cell["mass"] = total
			cell["damage"] = (float(cell.damage) * old + dmg * added) / total
			cell["flow_rate"] = (float(cell.flow_rate) * old + flow * added) / total
			cell["lifetime"] = (float(cell.lifetime) * old + life * added) / total
			_mix_mass_param(cell, "cell_mass_capacity", cap, old, added)
			_mix_mass_param(cell, "damage_full_mass", float(params.damage_full_mass), old, added)
			_mix_mass_param(cell, "damage_threshold_mass", float(params.damage_threshold_mass), old, added)
			_mix_mass_param(cell, "flow_start_mass", float(params.flow_start_mass), old, added)
			if added >= old:
				cell["source_id"] = source_id
			cell["age"] = 0.0
			_cells[key] = cell
			_note_landed(added, stats, str(sup.floor_id))
			_splat_visual(key, sup, added, stats)
		if leftover > MASS_EPS:
			_spill(key, leftover, source_id, stats, false)
		return
	var first := minf(mass, cap)
	_cells[key] = {
		"ix": int(sup.ix),
		"iz": int(sup.iz),
		"floor_id": str(sup.floor_id),
		"floor_index": int(sup.get("floor_index", 0)),
		"elevation": float(sup.get("elevation", 0.0)),
		"mass": first,
		"age": 0.0,
		"source_id": source_id,
		"damage": dmg,
		"flow_rate": flow,
		"lifetime": life,
		"cell_mass_capacity": cap,
		"damage_full_mass": float(params.damage_full_mass),
		"damage_threshold_mass": float(params.damage_threshold_mass),
		"flow_start_mass": float(params.flow_start_mass),
		"drip_acc": {},
	}
	_note_landed(first, stats, str(sup.floor_id))
	_splat_visual(key, sup, first, stats)
	var extra := mass - first
	if extra > MASS_EPS:
		_spill(key, extra, source_id, stats, false)


func _mix_mass_param(cell: Dictionary, key: String, incoming: float, old: float, added: float) -> void:
	var total := old + added
	if total <= 0.0:
		cell[key] = incoming
		return
	var prev := float(cell.get(key, incoming))
	cell[key] = (prev * old + incoming * added) / total


func _note_landed(amount: float, stats: Dictionary, floor_id: String) -> void:
	landed_mass += amount
	var skip := str(stats.get("skip_floor", ""))
	if skip != "" and skip != floor_id:
		cross_floor_mass += amount
	else:
		same_floor_mass += amount


func _tick_flow(delta: float) -> void:
	var transfers: Array = []
	for key in _cells.keys():
		var cell: Dictionary = _cells[key]
		var mass := float(cell.mass)
		var params: Dictionary = LavaConfigScript.resolve({}, cell)
		if mass < float(params.flow_start_mass):
			continue
		var flow := maxf(float(cell.get("flow_rate", DEFAULT_FLOW)), 0.05)
		var fill := clampf(mass / float(params.cell_mass_capacity), 0.0, 1.0)
		var pressure := 1.0 + maxf(fill - 0.25, 0.0) * 1.6
		var movable := mass * flow * pressure * delta
		if movable < 0.0004:
			continue
		var share := movable * 0.25
		var ix := int(cell.ix)
		var iz := int(cell.iz)
		var fid := str(cell.floor_id)
		for n in _index.neighbor_cells(ix, iz):
			if _index.is_supported(n.x, n.y, fid):
				var nk: String = _index.cell_key(n.x, n.y, fid)
				var nmass := 0.0
				if _cells.has(nk):
					nmass = float(_cells[nk].mass)
				if nmass >= mass - 0.04:
					continue
				var amt := minf(share, (mass - nmass) * 0.40)
				if amt > 0.0004:
					transfers.append({
						"from": key,
						"to_ix": n.x,
						"to_iz": n.y,
						"floor_id": fid,
						"mass": amt,
					})
			elif mass >= DRIP_START_MASS:
				_queue_drip(cell, n.x, n.y, share * 0.85, true)
		_cells[key] = cell
		_flush_drips(str(key))
	for t in transfers:
		_move_mass(str(t.from), float(t.mass), int(t.to_ix), int(t.to_iz), str(t.floor_id))


func _spill(key: String, leftover: float, source_id: String, stats: Dictionary, deduct: bool) -> void:
	if not _cells.has(key) or leftover <= MASS_EPS:
		return
	var cell: Dictionary = _cells[key]
	var ix := int(cell.ix)
	var iz := int(cell.iz)
	var fid := str(cell.floor_id)
	var edges: Array = []
	var sinks: Array = []
	for n in _index.neighbor_cells(ix, iz):
		if _index.is_supported(n.x, n.y, fid):
			sinks.append(n)
		else:
			edges.append(n)
	if not edges.is_empty():
		var share := leftover / float(edges.size())
		for n in edges:
			_queue_drip(cell, n.x, n.y, share, deduct)
		_cells[key] = cell
		_flush_drips(key)
		return
	if not sinks.is_empty():
		var pushed := 0.0
		var share := leftover / float(sinks.size())
		for n in sinks:
			var nk: String = _index.cell_key(n.x, n.y, fid)
			var nmass := 0.0
			if _cells.has(nk):
				nmass = float(_cells[nk].mass)
			var ncap := float(LavaConfigScript.resolve({}, _cells.get(nk, {})).cell_mass_capacity)
			if nmass >= ncap - 1.0:
				continue
			var sup: Dictionary = _index.support_at(n.x, n.y, fid)
			if sup.is_empty():
				continue
			_add_mass(sup, share, source_id, stats)
			pushed += share
		leftover -= pushed
		if leftover <= MASS_EPS:
			return
	_spawn_drip(
		Vector3(float(ix), float(cell.elevation) + 0.12, float(iz)),
		Vector3(0.0, -0.8, 0.0),
		leftover,
		source_id,
		stats
	)


func _queue_drip(cell: Dictionary, nx: int, nz: int, amount: float, deduct: bool) -> void:
	if amount <= 0.0:
		return
	var take := amount
	if deduct:
		take = minf(amount, float(cell.mass))
		cell["mass"] = float(cell.mass) - take
	if take <= 0.0:
		return
	var acc: Dictionary = cell.get("drip_acc", {})
	var k := "%d,%d" % [nx, nz]
	acc[k] = float(acc.get(k, 0.0)) + take
	cell["drip_acc"] = acc


func _flush_drips(key: String) -> void:
	if not _cells.has(key):
		return
	var cell: Dictionary = _cells[key]
	var acc: Dictionary = cell.get("drip_acc", {})
	if acc.is_empty():
		return
	var ix := int(cell.ix)
	var iz := int(cell.iz)
	var elev := float(cell.elevation)
	var params: Dictionary = LavaConfigScript.resolve({}, cell)
	var stats := {
		"lava_damage": float(cell.get("damage", DEFAULT_DAMAGE)),
		"flow_rate": float(cell.get("flow_rate", DEFAULT_FLOW)),
		"lava_lifetime": float(cell.get("lifetime", DEFAULT_LIFETIME)),
		"cell_mass_capacity": float(params.cell_mass_capacity),
		"damage_full_mass": float(params.damage_full_mass),
		"damage_threshold_mass": float(params.damage_threshold_mass),
		"flow_start_mass": float(params.flow_start_mass),
		"skip_floor": str(cell.floor_id),
	}
	for k in acc.keys():
		var parts := str(k).split(",")
		if parts.size() < 2:
			continue
		var nx := int(parts[0])
		var nz := int(parts[1])
		while float(acc[k]) >= DRIP_SPAWN:
			acc[k] = float(acc[k]) - DRIP_SPAWN
			var mid := Vector3(
				(float(ix) + float(nx)) * 0.5 + _rand_range(-0.25, 0.25),
				elev + 0.08,
				(float(iz) + float(nz)) * 0.5 + _rand_range(-0.25, 0.25)
			)
			var vel := Vector3(float(nx) - float(ix), -0.45, float(nz) - float(iz)) * 0.85
			vel.x += _rand_range(-1.1, 1.1)
			vel.z += _rand_range(-1.1, 1.1)
			_spawn_drip(mid, vel, DRIP_SPAWN, str(cell.source_id), stats)
	cell["drip_acc"] = acc
	_cells[key] = cell


func _pending_drip(cell: Dictionary) -> float:
	var acc: Dictionary = cell.get("drip_acc", {})
	var total := 0.0
	for k in acc.keys():
		total += float(acc[k])
	return total


func _move_mass(from_key: String, amount: float, to_ix: int, to_iz: int, floor_id: String) -> void:
	if not _cells.has(from_key):
		return
	var src: Dictionary = _cells[from_key]
	var take := minf(amount, float(src.mass))
	if take < 0.001:
		return
	src["mass"] = float(src.mass) - take
	_cells[from_key] = src
	var sup: Dictionary = _index.support_at(to_ix, to_iz, floor_id)
	if sup.is_empty():
		return
	var src_params: Dictionary = LavaConfigScript.resolve({}, src)
	_add_mass(sup, take, str(src.source_id), {
		"lava_damage": float(src.damage),
		"flow_rate": float(src.flow_rate),
		"lava_lifetime": float(src.lifetime),
		"cell_mass_capacity": float(src_params.cell_mass_capacity),
		"damage_full_mass": float(src_params.damage_full_mass),
		"damage_threshold_mass": float(src_params.damage_threshold_mass),
		"flow_start_mass": float(src_params.flow_start_mass),
	})


func _tick_airborne(delta: float) -> void:
	var next: Array = []
	for d in _airborne:
		var pos: Vector3 = d.pos
		var vel: Vector3 = d.vel
		var prev_y := pos.y
		vel.y -= GRAVITY * delta
		vel *= maxf(1.0 - AIR_DRAG * delta, 0.15)
		pos += vel * delta
		d["age"] = float(d.get("age", 0.0)) + delta
		if pos.y < _index.void_y() or float(d.age) > 8.0:
			void_lost_mass += float(d.get("mass", 0.0))
			continue
		var hit: Dictionary = _index.hit_below(pos.x, pos.z, prev_y + 0.02)
		var skip := str(d.get("skip_floor", ""))
		if skip != "" and not hit.is_empty() and str(hit.floor_id) == skip:
			hit = {}
		if not hit.is_empty() and pos.y <= float(hit.top_y) + 0.10:
			var fid := str(hit.floor_id)
			var sup: Dictionary = {}
			if d.has("stick_ix") and d.has("stick_iz") and str(d.get("skip_floor", "")) == "":
				var sx := int(d.stick_ix)
				var sz := int(d.stick_iz)
				if Vector2(pos.x - float(sx), pos.z - float(sz)).length() <= STICK_RADIUS:
					sup = _index.support_at(sx, sz, fid)
			if sup.is_empty():
				sup = _index.nearest_support(pos.x, pos.z, fid)
			if sup.is_empty():
				continue
			var land := {
				"lava_damage": float(d.get("damage", DEFAULT_DAMAGE)),
				"flow_rate": float(d.get("flow_rate", DEFAULT_FLOW)),
				"lava_lifetime": float(d.get("lifetime", DEFAULT_LIFETIME)),
				"cell_mass_capacity": float(d.get("cell_mass_capacity", LavaConfigScript.CELL_MASS_CAPACITY)),
				"damage_full_mass": float(d.get("damage_full_mass", LavaConfigScript.DAMAGE_FULL_MASS)),
				"damage_threshold_mass": float(d.get("damage_threshold_mass", LavaConfigScript.DAMAGE_THRESHOLD_MASS)),
				"flow_start_mass": float(d.get("flow_start_mass", LavaConfigScript.FLOW_START_MASS)),
			}
			if str(d.get("skip_floor", "")) != "":
				land["skip_floor"] = str(d.get("skip_floor", ""))
			var splat := _clamp_on_plate(pos.x, pos.z, int(sup.ix), int(sup.iz))
			if str(d.get("skip_floor", "")) == "" and d.has("splat_x"):
				splat = _clamp_on_plate(float(d.splat_x), float(d.splat_z), int(sup.ix), int(sup.iz))
			land["splat_x"] = splat.x
			land["splat_z"] = splat.y
			_add_mass(sup, float(d.mass), str(d.source_id), land)
			continue
		d["pos"] = pos
		d["vel"] = vel
		next.append(d)
	_airborne = next


func _tick_decay(delta: float) -> void:
	var dead: Array = []
	for key in _cells.keys():
		var cell: Dictionary = _cells[key]
		var life := float(cell.get("lifetime", DEFAULT_LIFETIME))
		cell["age"] = float(cell.get("age", 0.0)) + delta
		if life > 0.0 and float(cell.age) > IDLE_GRACE:
			var before := float(cell.mass)
			cell["mass"] = before * exp(-delta / life)
			decayed_mass += maxf(before - float(cell.mass), 0.0)
		if float(cell.mass) < MASS_EPS and _pending_drip(cell) < MASS_EPS:
			dead.append(key)
		else:
			_cells[key] = cell
	for key in dead:
		_cells.erase(key)
		_drop_blobs_for(str(key))


func _enforce_caps() -> void:
	if _cells.size() > CELL_CAP:
		var keys: Array = _cells.keys()
		keys.sort_custom(func(a, b) -> bool:
			return float(_cells[a].mass) < float(_cells[b].mass)
		)
		var extra := _cells.size() - CELL_CAP
		for i in extra:
			_drop_blobs_for(str(keys[i]))
			_cells.erase(keys[i])
	if _airborne.size() > AIR_CAP:
		_airborne = _airborne.slice(_airborne.size() - AIR_CAP, _airborne.size())


func _enemy_pos(enemy: Node3D) -> Vector3:
	if enemy.is_inside_tree():
		return enemy.global_position
	return enemy.position


func _dps_for_key(key: String) -> float:
	if key.is_empty() or not _cells.has(key):
		return 0.0
	var cell: Dictionary = _cells[key]
	var params: Dictionary = LavaConfigScript.resolve({}, cell)
	return LavaConfigScript.cell_dps(
		float(cell.mass),
		float(cell.get("damage", DEFAULT_DAMAGE)),
		params
	)


func _sample_field() -> void:
	var damage_cells := 0
	var active := 0
	var best_dps := 0.0
	var peak_ref := 0.0
	for key in _cells.keys():
		var cell: Dictionary = _cells[key]
		if float(cell.get("mass", 0.0)) < MASS_EPS:
			continue
		active += 1
		var dps := _dps_for_key(key)
		if dps > 0.0:
			damage_cells += 1
		if dps > best_dps:
			best_dps = dps
		peak_ref = maxf(peak_ref, float(cell.get("damage", DEFAULT_DAMAGE)))
	peak_active_cells = maxi(peak_active_cells, active)
	peak_damage_cells = maxi(peak_damage_cells, damage_cells)
	peak_cell_dps = maxf(peak_cell_dps, best_dps)
	_damage_cell_samples += float(damage_cells)
	_damage_cell_ticks += 1
	if best_dps > 0.0 and t_first_damage < 0.0:
		t_first_damage = _sim_age
	if peak_ref > 0.0:
		var frac := best_dps / peak_ref
		if frac >= 0.25 and t_25_percent_damage < 0.0:
			t_25_percent_damage = _sim_age
		if frac >= 0.50 and t_50_percent_damage < 0.0:
			t_50_percent_damage = _sim_age
		if frac >= 0.90 and t_90_percent_damage < 0.0:
			t_90_percent_damage = _sim_age


func _cell_key_for_enemy(enemy: Node3D) -> String:
	var pos := _enemy_pos(enemy)
	var xz: Vector2i = _index.world_to_cell(pos)
	var fid := str(enemy.get("floor_id")) if "floor_id" in enemy else ""
	if not fid.is_empty():
		var keyed: String = _index.cell_key(xz.x, xz.y, fid)
		if _cells.has(keyed):
			return keyed
	var best := ""
	var best_dy := 1.25
	for key in _cells.keys():
		var cell: Dictionary = _cells[key]
		if int(cell.ix) != xz.x or int(cell.iz) != xz.y:
			continue
		var dy := absf(pos.y - float(cell.elevation))
		if dy < best_dy:
			best_dy = dy
			best = str(key)
	return best


func _tick_damage(delta: float) -> void:
	if not is_inside_tree():
		return
	var towers := {}
	for t in get_tree().get_nodes_in_group("towers"):
		if t != null and is_instance_valid(t) and _in_own_level(t):
			towers[str(t.get("runtime_id"))] = t
	var seen := {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node3D):
			continue
		if not _in_own_level(enemy):
			continue
		if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
			continue
		var eid := enemy.get_instance_id()
		seen[eid] = true
		var key := _cell_key_for_enemy(enemy)
		if key.is_empty() or not _cells.has(key) or _dps_for_key(key) <= 0.0:
			_contact.erase(eid)
			_dwell.erase(eid)
			continue
		var src = towers.get(str(_cells[key].get("source_id", "")), null)
		if str(_contact.get(eid, "")) != key:
			_contact[eid] = key
			_dwell[eid] = 0.0
			apply_burn(enemy, 1.0, src)
			continue
		_dwell[eid] = float(_dwell.get(eid, 0.0)) + delta
		if float(_dwell[eid]) >= STAND_INTERVAL:
			_dwell[eid] = float(_dwell[eid]) - STAND_INTERVAL
			apply_burn(enemy, 1.0, src)
	for eid in _contact.keys():
		if not seen.has(eid):
			_contact.erase(eid)
			_dwell.erase(eid)


func _blob_radius(mass: float) -> float:
	return clampf(BLOB_R_MIN + (BLOB_R_MAX - BLOB_R_MIN) * sqrt(maxf(mass, 0.0) / 80.0), BLOB_R_MIN, BLOB_R_MAX)


func _clamp_on_plate(x: float, z: float, ix: int, iz: int) -> Vector2:
	return Vector2(
		clampf(x, float(ix) - PLATE_JITTER, float(ix) + PLATE_JITTER),
		clampf(z, float(iz) - PLATE_JITTER, float(iz) + PLATE_JITTER)
	)


func _splat_visual(key: String, sup: Dictionary, amount: float, stats: Dictionary) -> void:
	if SimContextScript.skip_presentation() or amount <= 0.0:
		return
	var ix := int(sup.ix)
	var iz := int(sup.iz)
	var x := float(ix)
	var z := float(iz)
	if stats.has("splat_x") and stats.has("splat_z"):
		x = float(stats.splat_x)
		z = float(stats.splat_z)
	else:
		x += _rand_range(-PLATE_JITTER, PLATE_JITTER)
		z += _rand_range(-PLATE_JITTER, PLATE_JITTER)
	var clamped := _clamp_on_plate(x, z, ix, iz)
	_add_blob(key, clamped.x, clamped.y, amount, float(sup.get("elevation", 0.0)))


func _add_blob(key: String, x: float, z: float, amount: float, elevation: float) -> void:
	var best := -1
	var best_d := INF
	var on_cell := 0
	for i in _blobs.size():
		var b: Dictionary = _blobs[i]
		if str(b.cell_key) != key:
			continue
		on_cell += 1
		var d := Vector2(x - float(b.x), z - float(b.z)).length()
		if d < best_d:
			best_d = d
			best = i
	var inside := false
	if best >= 0:
		inside = best_d <= _blob_radius(float(_blobs[best].mass)) * BLOB_HIT_FRAC
	if inside:
		_blobs[best]["mass"] = float(_blobs[best].mass) + amount
	elif on_cell >= BLOB_CAP and best >= 0:
		_blobs[best]["mass"] = float(_blobs[best].mass) + amount
	else:
		if best >= 0 and best_d < BLOB_SEPARATE:
			var away := Vector2(x - float(_blobs[best].x), z - float(_blobs[best].z))
			if away.length_squared() < 0.0001:
				away = Vector2(_rand_range(-1.0, 1.0), _rand_range(-1.0, 1.0))
			away = away.normalized() * BLOB_SEPARATE
			x = float(_blobs[best].x) + away.x
			z = float(_blobs[best].z) + away.y
		var parts := key.split(",")
		if parts.size() >= 2:
			var plate := _clamp_on_plate(x, z, int(parts[0]), int(parts[1]))
			x = plate.x
			z = plate.y
		_blobs.append({
			"x": x,
			"z": z,
			"mass": amount,
			"cell_key": key,
			"elevation": elevation,
		})
	_merge_blobs()


func _merge_blobs() -> void:
	var guard := 0
	while guard < 24:
		guard += 1
		var merged := false
		for i in _blobs.size():
			var a: Dictionary = _blobs[i]
			var ra := _blob_radius(float(a.mass))
			for j in range(i + 1, _blobs.size()):
				var b: Dictionary = _blobs[j]
				if str(a.cell_key) != str(b.cell_key):
					continue
				var rb := _blob_radius(float(b.mass))
				var d := Vector2(float(a.x) - float(b.x), float(a.z) - float(b.z)).length()
				if d > (ra + rb) * BLOB_MERGE_FRAC:
					continue
				var ma := float(a.mass)
				var mb := float(b.mass)
				var tot := ma + mb
				if tot <= 0.0:
					continue
				a["x"] = (float(a.x) * ma + float(b.x) * mb) / tot
				a["z"] = (float(a.z) * ma + float(b.z) * mb) / tot
				a["mass"] = tot
				_blobs[i] = a
				_blobs.remove_at(j)
				merged = true
				break
			if merged:
				break
		if not merged:
			break


func _drop_blobs_for(key: String) -> void:
	var next: Array = []
	for b in _blobs:
		if str(b.cell_key) != key:
			next.append(b)
	_blobs = next


func _scale_blobs_to_cells() -> void:
	var sums := {}
	for b in _blobs:
		var k := str(b.cell_key)
		sums[k] = float(sums.get(k, 0.0)) + float(b.mass)
	var next: Array = []
	for b in _blobs:
		var k := str(b.cell_key)
		if not _cells.has(k):
			continue
		var cell_mass := float(_cells[k].mass)
		var summed := float(sums.get(k, 0.0))
		if summed > 0.0 and absf(summed - cell_mass) > 0.05:
			b["mass"] = float(b.mass) * (cell_mass / summed)
		if float(b.mass) >= MASS_EPS * 0.4:
			next.append(b)
	_blobs = next
	_merge_blobs()


func _spawn_drip(pos: Vector3, vel: Vector3, mass: float, source_id: String, stats: Dictionary) -> void:
	if mass < MASS_EPS:
		return
	var params: Dictionary = LavaConfigScript.resolve(stats)
	var blob := {
		"pos": pos,
		"vel": vel,
		"mass": mass,
		"source_id": source_id,
		"age": 0.0,
		"damage": float(stats.get("lava_damage", DEFAULT_DAMAGE)),
		"flow_rate": float(stats.get("flow_rate", DEFAULT_FLOW)),
		"lifetime": float(stats.get("lava_lifetime", DEFAULT_LIFETIME)),
		"cell_mass_capacity": float(params.cell_mass_capacity),
		"damage_full_mass": float(params.damage_full_mass),
		"damage_threshold_mass": float(params.damage_threshold_mass),
		"flow_start_mass": float(params.flow_start_mass),
		"skip_floor": str(stats.get("skip_floor", "")),
	}
	if stats.has("stick_ix") and stats.has("stick_iz"):
		blob["stick_ix"] = int(stats.stick_ix)
		blob["stick_iz"] = int(stats.stick_iz)
	if stats.has("splat_x") and stats.has("splat_z"):
		blob["splat_x"] = float(stats.splat_x)
		blob["splat_z"] = float(stats.splat_z)
	if str(stats.get("skip_floor", "")) != "":
		var v: Vector3 = blob.vel
		v.x += _rand_range(-1.4, 1.4)
		v.z += _rand_range(-1.4, 1.4)
		blob["vel"] = v
	_airborne.append(blob)


func _ensure_visuals() -> void:
	if SimContextScript.skip_presentation():
		return
	if _visual_root != null:
		return
	_visual_root = Node3D.new()
	_visual_root.name = "LavaPuddles"
	add_child(_visual_root)
	_drip_root = Node3D.new()
	_drip_root.name = "LavaDrips"
	add_child(_drip_root)
	_lava_mat = StandardMaterial3D.new()
	_lava_mat.albedo_color = Color(0.85, 0.22, 0.06, 0.92)
	_lava_mat.emission_enabled = true
	_lava_mat.emission = Color(1.0, 0.35, 0.05)
	_lava_mat.emission_energy_multiplier = 2.4
	_lava_mat.roughness = 0.35
	_lava_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drip_mat = _lava_mat.duplicate()
	_drip_mat.emission_energy_multiplier = 3.0


func _sync_visuals() -> void:
	_ensure_visuals()
	if _visual_root == null:
		return
	_scale_blobs_to_cells()
	while _blob_meshes.size() < _blobs.size():
		var mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = BLOB_R_MIN
		cyl.bottom_radius = BLOB_R_MIN
		cyl.height = HEIGHT_MIN
		cyl.radial_segments = 14
		mesh.mesh = cyl
		mesh.material_override = _lava_mat
		_visual_root.add_child(mesh)
		_blob_meshes.append(mesh)
	for i in _blob_meshes.size():
		var node: MeshInstance3D = _blob_meshes[i]
		if i >= _blobs.size():
			node.visible = false
			continue
		var blob: Dictionary = _blobs[i]
		var mass := float(blob.mass)
		var fill := clampf(mass / 80.0, 0.0, 1.0)
		var h := HEIGHT_MIN + (HEIGHT_MAX - HEIGHT_MIN) * fill
		var radius := _blob_radius(mass)
		var cyl_mesh := node.mesh as CylinderMesh
		if cyl_mesh:
			cyl_mesh.top_radius = radius
			cyl_mesh.bottom_radius = radius
			cyl_mesh.height = h
		node.visible = true
		node.position = Vector3(
			float(blob.x),
			float(blob.elevation) + SURFACE_LIFT + h * 0.5,
			float(blob.z)
		)
	while _drip_meshes.size() < _airborne.size():
		var drip := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.07
		sph.height = 0.14
		drip.mesh = sph
		drip.material_override = _drip_mat
		_drip_root.add_child(drip)
		_drip_meshes.append(drip)
	for i in _drip_meshes.size():
		var node: MeshInstance3D = _drip_meshes[i]
		if i >= _airborne.size():
			node.visible = false
			continue
		var d: Dictionary = _airborne[i]
		node.visible = true
		node.global_position = d.pos
		var scale_m := clampf(0.70 + 0.12 * float(d.mass), 0.55, 1.15)
		node.scale = Vector3(scale_m, scale_m, scale_m)


func _vec3(v) -> Vector3:
	if typeof(v) == TYPE_VECTOR3:
		return v
	if typeof(v) == TYPE_DICTIONARY:
		return Vector3(float(v.get("x", 0.0)), float(v.get("y", 0.0)), float(v.get("z", 0.0)))
	return Vector3.ZERO

class_name PlatformSurfaceIndex
extends RefCounted

## Walkable platform query on the authored 1 m cell grid. Absence = void.

const CELL := 1.0
const EDGE_EPS := 0.001

var _supports: Dictionary = {}
var _floors: Array = []
var _void_y: float = -2.0


static func from_level(level: Resource) -> PlatformSurfaceIndex:
	var idx := PlatformSurfaceIndex.new()
	idx._build(level)
	return idx


func cell_key(ix: int, iz: int, floor_id: String) -> String:
	return "%d,%d,%s" % [ix, iz, floor_id]


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(int(round(pos.x / CELL)), int(round(pos.z / CELL)))


func is_supported(ix: int, iz: int, floor_id: String) -> bool:
	return _supports.has(cell_key(ix, iz, floor_id))


func support_at(ix: int, iz: int, floor_id: String) -> Dictionary:
	return _supports.get(cell_key(ix, iz, floor_id), {})


func nearest_support(x: float, z: float, floor_id: String) -> Dictionary:
	var xz := world_to_cell(Vector3(x, 0.0, z))
	var direct: Dictionary = support_at(xz.x, xz.y, floor_id)
	if not direct.is_empty():
		return direct
	var best := {}
	var best_d := 1.25
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			var s: Dictionary = support_at(xz.x + dx, xz.y + dz, floor_id)
			if s.is_empty():
				continue
			var d := Vector2(x - float(s.ix), z - float(s.iz)).length()
			if d < best_d:
				best_d = d
				best = s
	return best


func neighbor_cells(ix: int, iz: int) -> Array:
	return [
		Vector2i(ix + 1, iz),
		Vector2i(ix - 1, iz),
		Vector2i(ix, iz + 1),
		Vector2i(ix, iz - 1),
	]


func hit_below(x: float, z: float, from_y: float) -> Dictionary:
	for floor_rec in _floors:
		for plat in floor_rec.platforms:
			if float(plat.top_y) >= from_y - 0.08:
				continue
			if x < float(plat.min_x) - EDGE_EPS or x > float(plat.max_x) + EDGE_EPS:
				continue
			if z < float(plat.min_z) - EDGE_EPS or z > float(plat.max_z) + EDGE_EPS:
				continue
			return {
				"floor_id": str(floor_rec.floor_id),
				"floor_index": int(floor_rec.floor_index),
				"elevation": float(floor_rec.elevation),
				"platform_id": str(plat.id),
				"top_y": float(plat.top_y),
			}
	return {}


func void_y() -> float:
	return _void_y


func _build(level: Resource) -> void:
	_supports.clear()
	_floors.clear()
	if level == null:
		return
	var min_elev := INF
	for floor_def in level.floors:
		var elev := float(floor_def.elevation)
		min_elev = minf(min_elev, elev)
		var plats: Array = []
		for plat in floor_def.platforms:
			if plat == null:
				continue
			if "walkable" in plat and not bool(plat.walkable):
				continue
			var c: Vector3 = plat.transform.origin
			var s: Vector3 = plat.size
			var rec := {
				"id": str(plat.id),
				"min_x": c.x - s.x * 0.5,
				"max_x": c.x + s.x * 0.5,
				"min_z": c.z - s.z * 0.5,
				"max_z": c.z + s.z * 0.5,
				"top_y": c.y + s.y * 0.5,
			}
			plats.append(rec)
			var ix0 := int(floor(float(rec.min_x) + EDGE_EPS))
			var ix1 := int(ceil(float(rec.max_x) - EDGE_EPS))
			var iz0 := int(floor(float(rec.min_z) + EDGE_EPS))
			var iz1 := int(ceil(float(rec.max_z) - EDGE_EPS))
			for ix in range(ix0, ix1 + 1):
				for iz in range(iz0, iz1 + 1):
					if not _point_in_rect(float(ix), float(iz), rec):
						continue
					var key := cell_key(ix, iz, str(floor_def.floor_id))
					_supports[key] = {
						"ix": ix,
						"iz": iz,
						"floor_id": str(floor_def.floor_id),
						"floor_index": int(floor_def.floor_index),
						"elevation": elev,
						"platform_id": rec.id,
						"top_y": rec.top_y,
					}
		_floors.append({
			"floor_id": str(floor_def.floor_id),
			"floor_index": int(floor_def.floor_index),
			"elevation": elev,
			"platforms": plats,
		})
	_floors.sort_custom(func(a, b) -> bool:
		return float(a.elevation) > float(b.elevation)
	)
	if min_elev < INF:
		_void_y = min_elev - 2.0


func _point_in_rect(x: float, z: float, rec: Dictionary) -> bool:
	return (
		x >= float(rec.min_x) - EDGE_EPS
		and x <= float(rec.max_x) + EDGE_EPS
		and z >= float(rec.min_z) - EDGE_EPS
		and z <= float(rec.max_z) + EDGE_EPS
	)

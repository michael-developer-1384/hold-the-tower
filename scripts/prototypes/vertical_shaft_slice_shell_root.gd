extends Node3D

## Vertical shaft lookdev SHELL variant: real vertical_test level inside an open megastructure frame.
## Duplicate of vertical_shaft_slice_root — do not merge lighting/shell changes back into the original.

const TestLevelFactoryScript := preload("res://scripts/level/test_level_factory.gd")
const EnemyPathBuilderScript := preload("res://scripts/level/enemy_path_builder.gd")
const SentryScene := preload("res://scenes/towers/visuals/sentry_visual.tscn")
const BotScene := preload("res://scenes/enemies/visuals/bot_visual.tscn")
const ImpactScene := preload("res://scenes/visuals/fx/impact_burst.tscn")
const VisualSocketsScript := preload("res://scripts/visuals/visual_sockets.gd")
const TurretAimScript := preload("res://scripts/towers/turret_aim.gd")

const MOD := {
	"spine": preload("res://scenes/environment/modules/vertical_power_spine.tscn"),
	"wall": preload("res://scenes/environment/modules/shaft_wall_module.tscn"),
	"hero": preload("res://scenes/environment/modules/hero_machine_core.tscn"),
	"support_col": preload("res://scenes/environment/modules/support_column.tscn"),
	"path": preload("res://scenes/environment/modules/path_straight.tscn"),
	"corner_outer": preload("res://scenes/environment/modules/path_outer_corner.tscn"),
	"ramp3": preload("res://scenes/environment/modules/path_ramp_3m.tscn"),
	"pad_e": preload("res://scenes/environment/modules/build_pad_empty.tscn"),
	"pad_o": preload("res://scenes/environment/modules/build_pad_occupied.tscn"),
	"core": preload("res://scenes/environment/modules/core_terminus.tscn"),
	"spawn": preload("res://scenes/environment/modules/spawn_arch.tscn"),
	"frame": preload("res://scenes/environment/modules/shaft_shell_frame_large.tscn"),
	"wall_seg": preload("res://scenes/environment/modules/shaft_shell_wall_segment.tscn"),
	"bay": preload("res://scenes/environment/modules/shaft_shell_bay_open.tscn"),
	"trunk": preload("res://scenes/environment/modules/cable_trunk_vertical.tscn"),
	"light_bar": preload("res://scenes/environment/modules/service_light_bar.tscn"),
	"light_pod": preload("res://scenes/environment/modules/service_light_pod.tscn"),
	"vent_lg": preload("res://scenes/environment/modules/vent_cluster_large.tscn"),
	"svc_deck": preload("res://scenes/environment/modules/background_service_deck.tscn"),
	"bg_bridge": preload("res://scenes/environment/modules/background_bridge_short.tscn"),
	"ind_col": preload("res://scenes/environment/modules/industrial_column.tscn"),
	"plat_frame": preload("res://scenes/environment/modules/platform_support_frame.tscn"),
	"pipe": preload("res://scenes/environment/modules/pipe_cluster.tscn"),
	"plat_s": preload("res://scenes/environment/modules/platform_small.tscn"),
	"path_bridge": preload("res://scenes/environment/modules/path_bridge.tscn"),
}

## Deck panel sits slightly above slab local Z=0 / floor elevation.
const DECK_SURFACE_BIAS := 0.045
## Ramp GLB walk plane sits above local Z=0 (deck thickness + panel). Sink so tops meet path panels.
const RAMP_MESH_SINK := 0.04
## Soften pitch at ramp lips so AABB plant does not pop.
const RAMP_PITCH_FADE := 0.3
## Authored support_column hang length (walk origin → foot). Higher floors scale to the same foot plane.
const COLUMN_NATIVE_DROP := 3.0
## Extra void depth past the native hang so feet disappear into floor fog.
const COLUMN_VOID_EXTRA := COLUMN_NATIVE_DROP

const SENTRY_SPOTS := ["F1_C", "F2_A", "F2_E", "F3_D"]
const BOT_PATH_STARTS := [3, 12, 22, 34]
## Match enemy.gd base feel but readable for lookdev; stride-synced gait.
const BOT_SPEED := 0.95
const BOT_STRIDE := 0.42
## Lookdev aim rates — same contract as basic_tower.
const SENTRY_YAW_RATE := deg_to_rad(105.0)
const SENTRY_PITCH_RATE := deg_to_rad(130.0)
const SENTRY_LOCK_TOL := deg_to_rad(2.5)
const SENTRY_FIRE_INTERVAL := 1.6

const MAP_FOCUS := Vector3(0.0, 3.0, 0.0)

@export var capture_on_ready: bool = false
@export var camera_speed: float = 8.0
@export var camera_fast_mul: float = 2.4
@export var camera_look_sens: float = 0.0032
@export var orbit_sensitivity: float = 0.008
@export var orbit_min_distance: float = 6.0
@export var orbit_max_distance: float = 52.0

enum CamMode { ORBIT, FLY }

var _level: Resource
var _enemy_path: PackedVector3Array = PackedVector3Array()
var _near: Node3D
var _mid: Node3D
var _far: Node3D
var _map_root: Node3D
var _bots: Array[Dictionary] = []
var _sentries: Array[Node3D] = []
## Per-sentry aim lock: instance_id → {locked, target_id, cooldown}
var _sentry_aim: Dictionary = {}
## Visual ramp decks (edge-anchored). Used so bots plant on the mesh, not factory cell Y.
var _ramp_surfaces: Array[Dictionary] = []
var _fire_sentry_i: int = 0
var _capture_done: bool = false
var _hero_home_pos: Vector3 = Vector3.ZERO
var _hero_home_basis: Basis = Basis.IDENTITY
var _cam_mode: CamMode = CamMode.ORBIT
var _orbiting: bool = false
var _looking: bool = false
var _orbit_pivot: Vector3 = MAP_FOCUS
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = deg_to_rad(48.0)
var _orbit_dist: float = 22.0


func _ready() -> void:
	_level = TestLevelFactoryScript.create_level()
	_enemy_path = EnemyPathBuilderScript.build(_level)
	_setup_cameras()
	_near = _group("Near")
	_mid = _group("Midground")
	_far = _group("Far")
	_map_root = _group("Map")
	_build_real_level()
	_build_structural_supports()
	_build_open_shaft_shell()
	_build_background_service_decks()
	_build_scene_units()
	_build_shell_lighting()
	_build_void_atmosphere()
	_lift_shell_readability(_mid)
	_disable_shadows(_mid)
	_dim_emissives(_far, 0.55)
	_disable_shadows(_far)
	_refresh_cam_hint()
	set_process(true)
	set_process_input(true)
	var args := OS.get_cmdline_user_args()
	if capture_on_ready or args.has("--capture-shaft-shell"):
		_run_capture()


func _process(delta: float) -> void:
	_move_bots(delta)
	_aim_bot_heads(delta)
	_aim_sentries(delta)
	_try_fire_sentries(delta)
	_move_camera(delta)


func _setup_cameras() -> void:
	# A) Gameplay target — elevated top-down, map dominates frame.
	var hero := get_node_or_null("HeroCamera") as Camera3D
	if hero:
		hero.fov = 30.0
		hero.position = Vector3(11.5, 16.8, 14.2)
		hero.look_at(Vector3(0.0, 3.2, 0.5), Vector3.UP)
		hero.current = true
		hero.far = 240.0
		hero.near = 0.15
		hero.attributes = null
		_hero_home_pos = hero.position
		_hero_home_basis = hero.basis
		_orbit_pivot = MAP_FOCUS
		_sync_orbit_from_camera(hero)
		_apply_orbit(hero)
	# B) Beauty — cine but believable.
	var beauty := get_node_or_null("BeautyCameraA") as Camera3D
	if beauty:
		beauty.fov = 28.0
		beauty.position = Vector3(9.2, 14.6, 16.8)
		beauty.look_at(Vector3(0.1, 3.4, 0.0), Vector3.UP)
		beauty.current = false
		beauty.far = 240.0
		beauty.attributes = _make_dof(38.0, 24.0, 0.016)
	# C) Top-down QA — all three floors readable.
	var qa := get_node_or_null("TopDownCamera") as Camera3D
	if qa:
		qa.fov = 42.0
		qa.position = Vector3(0.5, 24.0, 0.8)
		qa.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
		qa.current = false
		qa.far = 240.0


func _make_dof(far_dist: float, far_trans: float, amount: float) -> CameraAttributesPractical:
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = far_dist
	attr.dof_blur_far_transition = far_trans
	attr.dof_blur_amount = amount
	return attr


func _group(p_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = p_name
	add_child(n)
	return n


func _inst(kind: String, parent: Node3D, pos: Vector3, yaw_deg: float = 0.0, scale := 1.0) -> Node3D:
	var packed: PackedScene = MOD[kind]
	var node := packed.instantiate() as Node3D
	parent.add_child(node)
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_deg)
	if not is_equal_approx(scale, 1.0):
		node.scale = Vector3.ONE * scale
	if kind == "path" or kind == "corner_outer" or kind == "ramp3" or kind == "pad_e" or kind == "pad_o":
		_sanitize_walk_materials(node)
	return node


func _sanitize_walk_materials(node: Node) -> void:
	## Kill authored grooves and kill specular/SSAO moiré on large flat walk faces.
	## Zoom-dependent diagonal bands = screen-frequency aliasing on metal, not mesh grooves.
	var n := String(node.name)
	if n.findn("Groove") >= 0 or (n.findn("Hazard") >= 0 and n.findn("Pad") < 0):
		node.queue_free()
		return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		if n.findn("Panel") >= 0 or n.findn("Slab") >= 0 or n.findn("Deck") >= 0:
			mat.albedo_color = Color(0.14, 0.15, 0.17)
			mat.metallic = 0.12
			mat.roughness = 0.88
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mi.material_override = mat
		elif (
			n.findn("Trim") >= 0
			or n.findn("Rail") >= 0
			or n.findn("OuterRail") >= 0
			or n.findn("Ring") >= 0
		):
			## Keep rails readable/light — same language as ramp side rails.
			mat.albedo_color = Color(0.62, 0.64, 0.66)
			mat.metallic = 0.42
			mat.roughness = 0.58
			mi.material_override = mat
		elif n.findn("Well") >= 0:
			mat.albedo_color = Color(0.14, 0.15, 0.17)
			mat.metallic = 0.12
			mat.roughness = 0.88
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mi.material_override = mat
	for c in node.get_children():
		_sanitize_walk_materials(c)


func _build_real_level() -> void:
	var walk := Node3D.new()
	walk.name = "Walkways"
	_map_root.add_child(walk)
	var ramp_keys := _ramp_cell_keys()
	for floor_def in _level.floors:
		_dress_floor_walk(walk, floor_def, ramp_keys)
		_dress_build_spots(walk, floor_def)
	_dress_ramps(walk)
	_dress_spawn_and_core(walk)


func _ramp_cell_keys() -> Dictionary:
	## Integer rising cells only (not edge waypoints, not landing).
	var keys := {}
	for connector in _level.connectors:
		if connector == null or not connector.has_method("get_waypoints"):
			continue
		var wps: PackedVector3Array = connector.call("get_waypoints")
		if wps.size() < 2:
			continue
		var edge := wps[0]
		var landing := wps[wps.size() - 1]
		var flat := Vector3(landing.x - edge.x, 0.0, landing.z - edge.z)
		if flat.length_squared() < 0.0001:
			continue
		var up_hat := flat.normalized()
		var first_cell := Vector3(edge.x, 0.0, edge.z) + up_hat * 0.5
		var last_cell := Vector3(landing.x, 0.0, landing.z) - up_hat
		var cur := first_cell
		for _i in range(16):
			keys[_cell_key(cur.x, cur.z)] = true
			if cur.distance_to(last_cell) < 0.2:
				break
			cur += up_hat
	return keys


func _cell_key(x: float, z: float) -> String:
	return "%d:%d" % [roundi(x), roundi(z)]


func _yaw_neg_z(dir: Vector3) -> float:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return 0.0
	flat = flat.normalized()
	return rad_to_deg(atan2(-flat.x, -flat.z))


func _rotate_xz(v: Vector2, yaw_deg: float) -> Vector2:
	var r := deg_to_rad(yaw_deg)
	var c := cos(r)
	var s := sin(r)
	return Vector2(v.x * c + v.y * s, -v.x * s + v.y * c)


func _outer_corner_yaw(outer_a: Vector2, outer_b: Vector2) -> float:
	## Mesh at yaw 0 has outer rails on Godot +X and -Z.
	var canonical := [Vector2(1.0, 0.0), Vector2(0.0, -1.0)]
	for yaw_deg in [0.0, 90.0, 180.0, -90.0]:
		var mapped: Array[Vector2] = [
			_rotate_xz(canonical[0], yaw_deg),
			_rotate_xz(canonical[1], yaw_deg),
		]
		if _dir_set_match(mapped, [outer_a, outer_b]):
			return yaw_deg
	return 0.0


func _dir_set_match(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for va in a:
		var found := false
		for vb in b:
			if va.distance_to(vb) < 0.1:
				found = true
				break
		if not found:
			return false
	return true


func _cardinal_outers(connected: Array[Vector2]) -> Array[Vector2]:
	var all_dirs: Array[Vector2] = [
		Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)
	]
	var outers: Array[Vector2] = []
	for d in all_dirs:
		var hit := false
		for c in connected:
			if d.distance_to(c) < 0.1:
				hit = true
				break
		if not hit:
			outers.append(d)
	return outers


func _path_neighbor_map(floor_def: Resource) -> Dictionary:
	## cell_key -> Array[Vector2] of connected cardinal offsets (from path + ramps).
	var map := {}
	var pts: PackedVector3Array = floor_def.path_points
	for i in pts.size():
		var key := _cell_key(pts[i].x, pts[i].z)
		if not map.has(key):
			map[key] = [] as Array[Vector2]
		if i > 0:
			var prev: Vector3 = pts[i - 1]
			var d := Vector2(signf(prev.x - pts[i].x), signf(prev.z - pts[i].z))
			if absf(d.x) + absf(d.y) > 0.5:
				_add_unique_dir(map[key], d)
		if i + 1 < pts.size():
			var nxt: Vector3 = pts[i + 1]
			var d2 := Vector2(signf(nxt.x - pts[i].x), signf(nxt.z - pts[i].z))
			if absf(d2.x) + absf(d2.y) > 0.5:
				_add_unique_dir(map[key], d2)
	## Attach ramp approaches / landings so path→ramp cells become true corners.
	for connector in _level.connectors:
		if connector == null or not connector.has_method("get_waypoints"):
			continue
		var wps: PackedVector3Array = connector.call("get_waypoints")
		if wps.size() < 2:
			continue
		var edge := wps[0]
		var landing := wps[wps.size() - 1]
		var flat := Vector3(landing.x - edge.x, 0.0, landing.z - edge.z)
		if flat.length_squared() < 0.0001:
			continue
		var up_hat := flat.normalized()
		var approach := Vector3(edge.x, 0.0, edge.z) - up_hat * 0.5
		var a_key := _cell_key(approach.x, approach.z)
		if not map.has(a_key):
			map[a_key] = [] as Array[Vector2]
		_add_unique_dir(map[a_key], Vector2(up_hat.x, up_hat.z))
		var l_key := _cell_key(landing.x, landing.z)
		if not map.has(l_key):
			map[l_key] = [] as Array[Vector2]
		_add_unique_dir(map[l_key], Vector2(-up_hat.x, -up_hat.z))
	return map


func _add_unique_dir(arr: Array, d: Vector2) -> void:
	for existing in arr:
		if existing.distance_to(d) < 0.1:
			return
	arr.append(d)


func _dress_floor_walk(parent: Node3D, floor_def: Resource, ramp_keys: Dictionary) -> void:
	var pts: PackedVector3Array = floor_def.path_points
	var elev: float = float(floor_def.elevation)
	var neighbors: Dictionary = _path_neighbor_map(floor_def)
	for i in pts.size():
		var p: Vector3 = pts[i]
		var key := _cell_key(p.x, p.z)
		if ramp_keys.has(key):
			continue
		var dir := Vector3(1.0, 0.0, 0.0)
		if i + 1 < pts.size():
			dir = pts[i + 1] - p
		elif i > 0:
			dir = p - pts[i - 1]
		var connected: Array[Vector2] = neighbors.get(key, [] as Array[Vector2])
		var outers := _cardinal_outers(connected)
		## Convex outer corner: exactly two connected sides that are perpendicular.
		if connected.size() == 2 and outers.size() == 2:
			var dot := connected[0].dot(connected[1])
			if absf(dot) < 0.1:
				_inst("corner_outer", parent, Vector3(p.x, elev, p.z), _outer_corner_yaw(outers[0], outers[1]))
				continue
		_inst("path", parent, Vector3(p.x, elev, p.z), _yaw_neg_z(dir))


func _dress_build_spots(parent: Node3D, floor_def: Resource) -> void:
	var elev: float = float(floor_def.elevation)
	for spot in floor_def.build_spots:
		if spot == null:
			continue
		var id := str(spot.id)
		var kind := "pad_o" if SENTRY_SPOTS.has(id) else "pad_e"
		var o: Vector3 = spot.transform.origin
		_inst(kind, parent, Vector3(o.x, elev, o.z), 0.0)


func _dress_ramps(parent: Node3D) -> void:
	_ramp_surfaces.clear()
	for connector in _level.connectors:
		if connector == null or not connector.has_method("get_waypoints"):
			continue
		var wps: PackedVector3Array = connector.call("get_waypoints")
		if wps.size() < 2:
			continue
		var from_floor = _level.get_floor_by_id(str(connector.from_floor_id))
		var to_floor = _level.get_floor_by_id(str(connector.to_floor_id))
		var elev: float = float(from_floor.elevation) if from_floor else (wps[0].y - TestLevelFactoryScript.PATH_Y)
		var elev_to: float = float(to_floor.elevation) if to_floor else elev + 3.0
		## First waypoint is the downhill tip of the dressed deck; last is landing center.
		var edge := wps[0]
		var landing := wps[wps.size() - 1]
		var uphill := Vector3(landing.x - edge.x, 0.0, landing.z - edge.z)
		if uphill.length_squared() < 0.0001:
			continue
		var up_hat := uphill.normalized()
		var run := 3.0
		var rise := elev_to - elev
		## Sink so ramp deck/panel tops sit flush with adjacent path panels (not proud).
		var origin := Vector3(edge.x, elev - RAMP_MESH_SINK, edge.z)
		_inst("ramp3", parent, origin, _yaw_neg_z(uphill))
		_ramp_surfaces.append({
			"origin": Vector3(origin.x, 0.0, origin.z),
			"up_hat": up_hat,
			"run": run,
			"rise": rise,
			"elev": elev - RAMP_MESH_SINK,
			"elev_to": elev_to - RAMP_MESH_SINK,
			"half_width": 0.48,
		})


func _surface_y_at(xz: Vector3, fallback_y: float) -> float:
	## Prefer the dressed ramp plane; clamp along so lips stay on elev_from/elev_to.
	var p := Vector3(xz.x, 0.0, xz.z)
	var best_y := fallback_y
	var best_lat := 1.0e9
	for ramp in _ramp_surfaces:
		var origin: Vector3 = ramp["origin"]
		var up_hat: Vector3 = ramp["up_hat"]
		var along := (p - origin).dot(up_hat)
		var run: float = float(ramp["run"])
		if along < -0.15 or along > run + 0.15:
			continue
		var lateral := (p - origin - up_hat * along).length()
		var half_w: float = float(ramp["half_width"])
		if lateral > half_w or lateral >= best_lat:
			continue
		var elev: float = float(ramp["elev"])
		var rise: float = float(ramp["rise"])
		var a := clampf(along, 0.0, run)
		best_lat = lateral
		best_y = elev + (a / run) * rise + DECK_SURFACE_BIAS
	return best_y


func _dress_spawn_and_core(parent: Node3D) -> void:
	var floor_1 = _level.get_floor_by_index(0)
	var spawn: Vector3 = _level.spawn_transform.origin
	var ahead := spawn + Vector3(1.0, 0.0, 0.0)
	if floor_1 != null and floor_1.path_points.size() >= 2:
		spawn = floor_1.path_points[0]
		ahead = floor_1.path_points[1]
	var elev_1 := float(floor_1.elevation) if floor_1 else 0.0
	_inst("spawn", parent, Vector3(spawn.x, elev_1, spawn.z), _yaw_neg_z(ahead - spawn))
	var floor_3 = _level.get_floor_by_index(2)
	var core_xz: Vector3 = _level.core_transform.origin
	var elev_3 := float(floor_3.elevation) if floor_3 else 6.0
	if floor_3 != null and floor_3.path_points.size() > 0:
		core_xz = floor_3.path_points[floor_3.path_points.size() - 1]
	_inst("core", parent, Vector3(core_xz.x, elev_3, core_xz.z), 0.0)


func _walk_y(path_point: Vector3) -> float:
	return path_point.y - TestLevelFactoryScript.PATH_Y + DECK_SURFACE_BIAS


func _plant_on_walk(node: Node3D, walk: Vector3) -> void:
	node.global_position = walk
	var min_y := _global_mesh_min_y(node)
	if min_y < 100000.0:
		node.global_position.y += walk.y - min_y + 0.02


func _global_mesh_min_y(node: Node) -> float:
	var lowest := 100000.0
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var aabb := mi.get_aabb()
		for cx in [0.0, 1.0]:
			for cy in [0.0, 1.0]:
				for cz in [0.0, 1.0]:
					var local := aabb.position + aabb.size * Vector3(cx, cy, cz)
					lowest = minf(lowest, mi.to_global(local).y)
	for c in node.get_children():
		lowest = minf(lowest, _global_mesh_min_y(c))
	return lowest


func _build_structural_supports() -> void:
	## Every floor: columns under path start, end, and outer corners.
	## Height grows with elevation so all feet share one void plane under floor 1.
	## Skip any column whose XZ would pierce a lower floor's walkway.
	var supports := Node3D.new()
	supports.name = "Supports"
	_map_root.add_child(supports)
	var floors: Array = _level.floors.duplicate()
	floors.sort_custom(func(a, b) -> bool:
		return float(a.elevation) < float(b.elevation)
	)
	if floors.is_empty():
		return
	var foot_y: float = float(floors[0].elevation) - COLUMN_NATIVE_DROP - COLUMN_VOID_EXTRA
	var occupied := {} ## dedupe XZ across floors
	var placed := 0
	var skipped := 0
	for floor_def in floors:
		var elev: float = float(floor_def.elevation)
		for site in _column_sites_for_floor(floor_def):
			var key := _cell_key(site.x, site.y)
			## Pierce check first — higher floors must not drop through lower walks.
			if _column_pierces_lower_walk(site, elev):
				skipped += 1
				continue
			if occupied.has(key):
				continue
			occupied[key] = true
			_place_support_column(supports, site, elev, foot_y)
			placed += 1
	print("support_columns: placed=%d skipped_pierce=%d foot_y=%.2f" % [placed, skipped, foot_y])


func _column_sites_for_floor(floor_def: Resource) -> Array[Vector2]:
	## Start, end, and every convex 90° outer corner of the floor path.
	var sites: Array[Vector2] = []
	var pts: PackedVector3Array = floor_def.path_points
	if pts.is_empty():
		return sites
	_add_column_site(sites, Vector2(pts[0].x, pts[0].z))
	_add_column_site(sites, Vector2(pts[pts.size() - 1].x, pts[pts.size() - 1].z))
	var neighbors: Dictionary = _path_neighbor_map(floor_def)
	for i in pts.size():
		var p: Vector3 = pts[i]
		var connected: Array[Vector2] = neighbors.get(_cell_key(p.x, p.z), [] as Array[Vector2])
		if connected.size() != 2:
			continue
		if absf(connected[0].dot(connected[1])) < 0.1:
			_add_column_site(sites, Vector2(p.x, p.z))
	return sites


func _add_column_site(sites: Array[Vector2], xz: Vector2) -> void:
	for s in sites:
		if s.distance_to(xz) < 0.25:
			return
	sites.append(xz)


func _column_pierces_lower_walk(xz: Vector2, elev: float) -> bool:
	## True if a vertical from this site would hit a lower floor's walk cell.
	for floor_def in _level.floors:
		if float(floor_def.elevation) >= elev - 0.05:
			continue
		for p in floor_def.path_points:
			if Vector2(p.x, p.z).distance_to(xz) < 0.75:
				return true
	return false


func _place_support_column(parent: Node3D, xz: Vector2, elev: float, foot_y: float) -> void:
	var need_h: float = elev - foot_y
	if need_h < 0.5:
		return
	var scale_y: float = need_h / COLUMN_NATIVE_DROP
	var packed: PackedScene = MOD["support_col"]
	var col := packed.instantiate() as Node3D
	parent.add_child(col)
	col.position = Vector3(xz.x, elev, xz.y)
	col.scale = Vector3(1.0, scale_y, 1.0)
	_darken_support_column(col)
	_plant_column_foot(col, foot_y)


func _darken_support_column(node: Node) -> void:
	## Kill bright exposed/painted joins — columns read as dark shafts into the void.
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.045, 0.048, 0.055)
		mat.metallic = 0.35
		mat.roughness = 0.82
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mi.material_override = mat
	for c in node.get_children():
		_darken_support_column(c)


func _plant_column_foot(col: Node3D, floor_y: float) -> void:
	## Shift so the lowest mesh point sits on the target foot plane.
	var min_y := _global_mesh_min_y(col)
	if min_y >= 100000.0:
		return
	col.global_position.y += floor_y - min_y


func _build_open_shaft_shell() -> void:
	## Open megastructure frame around the playable slice. Keep the camera-side (+Z)
	## and the map core (roughly |xz| < 7) free so orbit never hits a closed shell.
	var frames := [
		{"p": Vector3(-11.5, -1.2, -6.5), "yaw": 12.0, "s": 1.0},
		{"p": Vector3(-12.2, -1.0, 3.8), "yaw": -18.0, "s": 1.0},
		{"p": Vector3(11.8, -1.2, -5.4), "yaw": -10.0, "s": 1.0},
		{"p": Vector3(12.6, -0.8, 4.2), "yaw": 16.0, "s": 0.92},
		{"p": Vector3(-7.2, -1.5, -12.4), "yaw": 4.0, "s": 1.05},
		{"p": Vector3(6.8, -1.4, -13.0), "yaw": -8.0, "s": 1.0},
		{"p": Vector3(-14.2, -1.0, -1.0), "yaw": 28.0, "s": 0.88},
	]
	for spec in frames:
		var n := _inst("frame", _mid, spec["p"] as Vector3, spec["yaw"] as float, spec["s"] as float)
		_plant_column_foot(n, -8.0)

	## Partial walls only behind / beside the map — never a ring.
	_inst("wall_seg", _mid, Vector3(-1.2, 0.0, -11.8), 0.0)
	_inst("wall_seg", _mid, Vector3(-12.4, 0.0, -2.6), 82.0)
	_inst("wall_seg", _mid, Vector3(13.0, -0.2, -6.8), -78.0, 0.92)

	## Open bays as machine niches, back-left and back-right.
	_inst("bay", _mid, Vector3(-10.0, 2.0, -9.8), 28.0)
	_inst("bay", _mid, Vector3(10.6, 0.4, -10.8), -22.0)

	var trunk_a := _inst("trunk", _mid, Vector3(-9.0, -2.0, -7.6), 8.0)
	var trunk_b := _inst("trunk", _mid, Vector3(9.4, -2.2, -8.8), -12.0)
	var trunk_c := _inst("trunk", _mid, Vector3(-12.4, -1.5, 5.4), 20.0, 1.1)
	var trunk_d := _inst("trunk", _mid, Vector3(12.8, -1.8, -1.2), -6.0)
	_plant_column_foot(trunk_a, -8.0)
	_plant_column_foot(trunk_b, -8.0)
	_plant_column_foot(trunk_c, -8.0)
	_plant_column_foot(trunk_d, -8.0)

	_inst("vent_lg", _mid, Vector3(-8.2, 7.2, -10.4), 18.0)
	_inst("vent_lg", _mid, Vector3(9.8, 8.8, -11.4), -14.0)
	_inst("pipe", _mid, Vector3(-10.4, 4.6, -6.4), 40.0)
	_inst("pipe", _mid, Vector3(11.4, 5.8, -5.8), -30.0)

	## Existing kit mass: distant wall fragment + flanking spines + hero west.
	_inst("wall", _far, Vector3(-3.5, -1.0, -16.8), 8.0, 0.85)
	var spine_a := _inst("spine", _mid, Vector3(-13.2, -1.5, 1.0), 10.0)
	var spine_b := _inst("spine", _mid, Vector3(13.4, -1.5, 0.4), -12.0)
	_plant_column_foot(spine_a, -8.0)
	_plant_column_foot(spine_b, -8.0)
	var hero := _inst("hero", _far, Vector3(-15.5, -1.0, 5.8), 22.0, 1.0)
	_plant_column_foot(hero, -8.0)

	## Hanging industrial columns at the rear — origin is the top cap.
	_inst("ind_col", _mid, Vector3(-10.4, 14.0, -13.2), 6.0)
	_inst("ind_col", _mid, Vector3(9.0, 15.5, -13.6), -8.0)


func _build_background_service_decks() -> void:
	## Three fragmentary non-playable heights: void, mid, high. Keep +Z camera side empty.
	_inst("svc_deck", _mid, Vector3(-10.2, -4.2, -8.8), 18.0)
	_inst("svc_deck", _mid, Vector3(8.8, -4.8, -10.2), -12.0)
	_inst("bg_bridge", _mid, Vector3(-1.0, -3.6, -12.0), 8.0)
	_inst("plat_s", _far, Vector3(6.4, -4.4, -13.6), 20.0)

	_inst("svc_deck", _mid, Vector3(-11.8, 3.4, -8.0), 24.0)
	_inst("svc_deck", _mid, Vector3(11.0, 3.8, -10.4), -16.0)
	_inst("bg_bridge", _mid, Vector3(-6.4, 3.2, -12.4), -6.0)
	_inst("path_bridge", _mid, Vector3(4.0, 3.6, -13.2), 90.0)
	_inst("plat_frame", _mid, Vector3(-8.6, 3.5, -11.8), 12.0)

	_inst("svc_deck", _mid, Vector3(-9.0, 9.6, -9.4), 14.0)
	_inst("svc_deck", _mid, Vector3(8.2, 10.8, -11.2), -20.0)
	_inst("bg_bridge", _mid, Vector3(-2.2, 10.2, -13.2), 10.0)
	_inst("plat_s", _mid, Vector3(-12.2, 9.2, -6.2), 32.0)


func _build_shaft_environment() -> void:
	## Kept as a no-op so any leftover call is harmless; shell uses _build_open_shaft_shell.
	pass


func _build_scene_units() -> void:
	var spot_pos := {}
	for floor_def in _level.floors:
		for spot in floor_def.build_spots:
			if spot == null:
				continue
			var id := str(spot.id)
			if not SENTRY_SPOTS.has(id):
				continue
			var o: Vector3 = spot.transform.origin
			spot_pos[id] = Vector3(o.x, float(floor_def.elevation), o.z)
	_sentries.clear()
	_sentry_aim.clear()
	for id in SENTRY_SPOTS:
		if not spot_pos.has(id):
			continue
		var pos: Vector3 = spot_pos[id]
		var sentry := SentryScene.instantiate() as Node3D
		_near.add_child(sentry)
		_plant_on_walk(sentry, pos)
		_enable_shadows(sentry)
		_sentries.append(sentry)
	_bots.clear()
	for start_i in BOT_PATH_STARTS:
		if start_i >= _enemy_path.size():
			continue
		var bot := BotScene.instantiate() as Node3D
		_near.add_child(bot)
		if "bot_stride_length" in bot:
			bot.set("bot_stride_length", BOT_STRIDE)
		_enable_shadows(bot)
		var entry := {
			"node": bot,
			"dist": _path_dist_at_index(start_i),
		}
		_bots.append(entry)
		_place_bot_at_dist(bot, float(entry["dist"]))


func _path_dist_at_index(index: int) -> float:
	var dist := 0.0
	var last := mini(index, _enemy_path.size() - 1)
	for i in range(last):
		dist += _enemy_path[i].distance_to(_enemy_path[i + 1])
	return dist


func _path_total_length() -> float:
	var dist := 0.0
	for i in range(maxi(_enemy_path.size() - 1, 0)):
		dist += _enemy_path[i].distance_to(_enemy_path[i + 1])
	return dist


func _place_bot_at_dist(bot: Node3D, dist: float) -> void:
	if _enemy_path.size() < 2:
		return
	var remaining := dist
	for i in range(_enemy_path.size() - 1):
		var a: Vector3 = _enemy_path[i]
		var b: Vector3 = _enemy_path[i + 1]
		var seg := a.distance_to(b)
		if remaining <= seg or i == _enemy_path.size() - 2:
			var t := 0.0 if seg < 0.001 else clampf(remaining / seg, 0.0, 1.0)
			var wp := a.lerp(b, t)
			var dir := b - a
			var walk_y := _surface_y_at(wp, _walk_y(wp))
			var pitch := _slope_pitch_at(wp, dir)
			## Yaw + pitch first so foot AABB matches the deck, then plant.
			if dir.length_squared() > 0.0001:
				bot.rotation.y = atan2(-dir.x, -dir.z)
			bot.rotation.x = pitch
			bot.rotation.z = 0.0
			_plant_on_walk(bot, Vector3(wp.x, walk_y, wp.z))
			return
		remaining -= seg


func _slope_pitch_at(xz: Vector3, travel_dir: Vector3) -> float:
	## Pitch bot to match ramp deck so feet aren't buried / floating on the slope.
	var p := Vector3(xz.x, 0.0, xz.z)
	var flat := Vector3(travel_dir.x, 0.0, travel_dir.z)
	if flat.length_squared() < 0.0001:
		return 0.0
	flat = flat.normalized()
	var best_pitch := 0.0
	var best_lat := 1.0e9
	var found := false
	for ramp in _ramp_surfaces:
		var origin: Vector3 = ramp["origin"]
		var up_hat: Vector3 = ramp["up_hat"]
		var along := (p - origin).dot(up_hat)
		var run: float = float(ramp["run"])
		if along < -0.15 or along > run + 0.15:
			continue
		var lateral := (p - origin - up_hat * along).length()
		if lateral > float(ramp["half_width"]) or lateral >= best_lat:
			continue
		var rise: float = float(ramp["rise"])
		var grade := atan2(rise, run)
		var a := clampf(along, 0.0, run)
		var fade_w := 1.0
		if a < RAMP_PITCH_FADE:
			fade_w = a / RAMP_PITCH_FADE
		elif a > run - RAMP_PITCH_FADE:
			fade_w = (run - a) / RAMP_PITCH_FADE
		best_lat = lateral
		best_pitch = grade * flat.dot(up_hat) * fade_w
		found = true
	return best_pitch if found else 0.0


func _move_bots(delta: float) -> void:
	if _is_capturing() or _enemy_path.size() < 2:
		return
	var total := _path_total_length()
	if total < 0.1:
		return
	var step := BOT_SPEED * delta
	for entry in _bots:
		var bot: Node3D = entry["node"]
		if bot == null or not is_instance_valid(bot):
			continue
		entry["dist"] = fmod(float(entry["dist"]) + step, total)
		_place_bot_at_dist(bot, float(entry["dist"]))
		if bot.has_method("report_move_distance"):
			bot.call("report_move_distance", step)


func _aim_bot_heads(_delta: float) -> void:
	if _is_capturing():
		return
	for entry in _bots:
		var bot: Node3D = entry["node"]
		if bot == null or not is_instance_valid(bot):
			continue
		var tower := _nearest_sentry(bot.global_position)
		if bot.has_method("set_look_target"):
			bot.call("set_look_target", tower)


func _nearest_sentry(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for sentry in _sentries:
		if sentry == null or not is_instance_valid(sentry):
			continue
		var d := from.distance_squared_to(sentry.global_position)
		if d < best_d:
			best_d = d
			best = sentry
	return best


func _nearest_bot(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := 1.0e9
	for entry in _bots:
		var bot: Node3D = entry["node"]
		if bot == null or not is_instance_valid(bot):
			continue
		var d := from.distance_squared_to(bot.global_position)
		if d < best_d:
			best_d = d
			best = bot
	return best


func _aim_sentries(delta: float) -> void:
	if _is_capturing():
		return
	for sentry in _sentries:
		if sentry == null or not is_instance_valid(sentry):
			continue
		var target := _nearest_bot(sentry.global_position)
		if target == null:
			_set_sentry_lock(sentry, false, false, null)
			continue
		_aim_sentry_at(sentry, target, delta)


func _aim_sentry_at(sentry: Node3D, target: Node3D, delta: float) -> void:
	var turret := VisualSocketsScript.resolve(sentry, "turret")
	if turret == null:
		_set_sentry_lock(sentry, false, false, target)
		return
	var pitch := VisualSocketsScript.resolve(sentry, "weapon_pitch")
	var look := _bot_hit_point(target, turret.global_position)
	var state := _sentry_aim_state(sentry)
	var tid := target.get_instance_id()
	if int(state.get("target_id", 0)) != tid:
		## Retarget resets lock — earliest shot is after slew finishes.
		state["locked"] = false
		state["target_id"] = tid
	var yaw_err := TurretAimScript.step_yaw(turret, look, SENTRY_YAW_RATE, delta)
	var pitch_err := 0.0
	if pitch != null:
		pitch_err = TurretAimScript.step_pitch(pitch, turret, look, SENTRY_PITCH_RATE, delta)
	var locked := TurretAimScript.is_aligned(yaw_err, pitch_err, SENTRY_LOCK_TOL)
	state["locked"] = locked
	_sentry_aim[sentry.get_instance_id()] = state
	_set_sentry_lock(sentry, not locked, locked, target)


func _sentry_aim_state(sentry: Node3D) -> Dictionary:
	var id := sentry.get_instance_id()
	if not _sentry_aim.has(id):
		_sentry_aim[id] = {"locked": false, "target_id": 0, "cooldown": 0.0}
	return (_sentry_aim[id] as Dictionary).duplicate(true)


func _set_sentry_lock(sentry: Node3D, locking: bool, locked: bool, _target: Node3D) -> void:
	if sentry != null and sentry.has_method("set_aim_lock_state"):
		sentry.call("set_aim_lock_state", locking, locked)
	if not locking and not locked and sentry != null:
		var id := sentry.get_instance_id()
		if _sentry_aim.has(id):
			var st: Dictionary = _sentry_aim[id]
			st["locked"] = false
			st["target_id"] = 0
			_sentry_aim[id] = st


func _try_fire_sentries(delta: float) -> void:
	if _is_capturing() or _sentries.is_empty() or _bots.is_empty():
		return
	## Tick cooldowns; fire the next locked sentry that is ready.
	for sentry in _sentries:
		if sentry == null or not is_instance_valid(sentry):
			continue
		var id := sentry.get_instance_id()
		var st: Dictionary = _sentry_aim.get(id, {"locked": false, "target_id": 0, "cooldown": 0.0})
		st["cooldown"] = maxf(float(st.get("cooldown", 0.0)) - delta, 0.0)
		_sentry_aim[id] = st
	var n := _sentries.size()
	for _i in range(n):
		var sentry := _sentries[_fire_sentry_i % n]
		_fire_sentry_i += 1
		if sentry == null or not is_instance_valid(sentry):
			continue
		var st2: Dictionary = _sentry_aim.get(sentry.get_instance_id(), {})
		if not bool(st2.get("locked", false)):
			continue
		if float(st2.get("cooldown", 0.0)) > 0.0:
			continue
		_fire_one_sentry(sentry)
		st2["cooldown"] = SENTRY_FIRE_INTERVAL
		_sentry_aim[sentry.get_instance_id()] = st2
		return


func _fire_one_sentry(sentry: Node3D) -> void:
	if _is_capturing() or sentry == null or not is_instance_valid(sentry):
		return
	var target := _nearest_bot(sentry.global_position)
	if target == null:
		return
	## Fire only after lock — do not snap barrels; tracers follow current tube axis.
	var muzzle_idx := -1
	if sentry.has_method("play_fire_feedback"):
		muzzle_idx = int(sentry.call("play_fire_feedback"))
	var muzzle: Node3D = null
	if sentry.has_method("get_muzzle_socket"):
		muzzle = sentry.call("get_muzzle_socket", muzzle_idx) as Node3D
	if muzzle == null:
		muzzle = VisualSocketsScript.resolve(sentry, "muzzle")
	var from := sentry.global_position + Vector3(0.0, 0.7, 0.0)
	var forward := -sentry.global_transform.basis.z
	if muzzle != null:
		from = muzzle.global_position
		forward = -muzzle.global_transform.basis.z
	if forward.length_squared() < 0.0001:
		return
	forward = forward.normalized()
	var hit := _bot_hit_point(target, from)
	var dist := maxf(from.distance_to(hit), 0.4)
	## Shot travels straight out of the barrel axis.
	var to := from + forward * dist
	_spawn_tracer(from, to)
	_spawn_bot_hit(target, from, hit)


func _bot_hit_point(bot: Node3D, from: Vector3) -> Vector3:
	## Aim at chassis / hip; fall back to chest height.
	var hip := bot.get_node_or_null("Hip") as Node3D
	var torso := bot.find_child("Chassis", true, false) as Node3D
	var aim: Node3D = torso if torso != null else hip
	if aim == null:
		return bot.global_position + Vector3(0.0, 0.42, 0.0)
	var center := aim.global_position
	var dir := (center - from).normalized()
	## Slightly in front of the mesh so the burst sits on the impact surface.
	return center - dir * 0.08


func _spawn_bot_hit(bot: Node3D, from: Vector3, to: Vector3) -> void:
	var impact := ImpactScene.instantiate() as Node3D
	add_child(impact)
	impact.global_position = to
	var inward := (from - to).normalized()
	if inward.length_squared() > 0.001:
		impact.look_at(to + inward, Vector3.UP)
	if bot.has_method("play_hit_feedback"):
		bot.call("play_hit_feedback", to, (to - from).normalized())
	elif bot.has_method("play_visual_event"):
		bot.call("play_visual_event", "hit")


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var mesh_i := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.016
	cap.height = maxf(0.12, from.distance_to(to))
	mesh_i.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.4)
	mat.emission_energy_multiplier = 8.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.88, 0.5, 0.85)
	mesh_i.material_override = mat
	mesh_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_i)
	mesh_i.global_position = (from + to) * 0.5
	mesh_i.look_at(to, Vector3.UP)
	mesh_i.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tw := create_tween()
	tw.tween_property(mesh_i, "scale", Vector3(0.15, 0.15, 0.15), 0.12)
	tw.tween_callback(mesh_i.queue_free)


func _build_shell_lighting() -> void:
	_build_map_lighting()
	## Visible fixtures + supporting omnis. No extra shadow casters.
	_place_bar_light(Vector3(-11.2, 6.2, -6.2), 102.0, Color(0.72, 0.86, 1.0), 0.85, 8.5)
	_place_bar_light(Vector3(11.6, 5.8, -5.2), -78.0, Color(0.74, 0.86, 1.0), 0.8, 8.0)
	_place_bar_light(Vector3(-6.8, 8.4, -11.2), 0.0, Color(0.7, 0.84, 0.98), 0.75, 9.0)
	_place_bar_light(Vector3(6.4, 9.0, -11.6), 8.0, Color(0.7, 0.84, 0.98), 0.7, 8.5)
	_place_bar_light(Vector3(-12.4, 4.2, -2.2), 82.0, Color(0.78, 0.88, 1.0), 0.7, 7.5)
	_place_pod_light(Vector3(-9.6, 5.2, -9.4), 28.0, Color(0.7, 0.82, 0.96), 0.55, 5.5)
	_place_pod_light(Vector3(10.4, 3.6, -10.4), -22.0, Color(0.7, 0.82, 0.96), 0.5, 5.2)
	_place_pod_light(Vector3(-11.6, 3.8, -7.8), 24.0, Color(1.0, 0.78, 0.5), 0.55, 4.6)
	_place_pod_light(Vector3(8.0, 10.6, -10.8), -20.0, Color(0.72, 0.84, 0.98), 0.48, 5.0)
	## Warm machine accents (no shadows).
	_omni_at(Vector3(-10.0, 4.2, -9.6), Color(1.0, 0.7, 0.42), 0.7, 6.0, 0.45)
	_omni_at(Vector3(10.6, 2.4, -10.6), Color(1.0, 0.72, 0.45), 0.55, 5.4, 0.35)
	## Single red status — far bay, not a look driver.
	_omni_at(Vector3(11.4, 2.8, -11.5), Color(0.95, 0.18, 0.12), 0.22, 2.4, 0.15)


func _place_bar_light(pos: Vector3, yaw_deg: float, color: Color, energy: float, omni_range: float) -> void:
	_inst("light_bar", _mid, pos, yaw_deg)
	_omni_at(pos + Vector3(0.0, -0.15, 0.4), color, energy, omni_range, 0.55)


func _place_pod_light(pos: Vector3, yaw_deg: float, color: Color, energy: float, omni_range: float) -> void:
	_inst("light_pod", _mid, pos, yaw_deg)
	_omni_at(pos + Vector3(0.0, -0.05, 0.25), color, energy, omni_range, 0.4)


func _omni_at(pos: Vector3, color: Color, energy: float, omni_range: float, fog_energy: float) -> void:
	var o := OmniLight3D.new()
	o.light_color = color
	o.light_energy = energy
	o.omni_range = omni_range
	o.shadow_enabled = false
	o.light_volumetric_fog_energy = fog_energy
	o.position = pos
	add_child(o)


func _build_map_lighting() -> void:
	# Soft path fill only — keep energy low so KeyLight bot shadows stay readable.
	for x in range(-3, 4):
		var strip := OmniLight3D.new()
		strip.light_color = Color(0.72, 0.82, 0.94)
		strip.light_energy = 0.22
		strip.omni_range = 2.8
		strip.shadow_enabled = false
		strip.position = Vector3(float(x), 0.6, -4.2)
		_near.add_child(strip)
	# Warm pad spot over sentry build area.
	var pad_spot := SpotLight3D.new()
	pad_spot.name = "PadSpot"
	pad_spot.light_color = Color(1.0, 0.78, 0.52)
	pad_spot.light_energy = 3.0
	pad_spot.spot_range = 6.5
	pad_spot.spot_angle = 28.0
	pad_spot.shadow_enabled = true
	pad_spot.shadow_bias = 0.03
	pad_spot.light_volumetric_fog_energy = 0.55
	pad_spot.position = Vector3(1.0, 3.2, -1.5)
	add_child(pad_spot)
	pad_spot.look_at(Vector3(1.0, 0.0, -3.0), Vector3.UP)
	# Upper-floor keys with shadows so bots on F2/F3 read on the deck.
	var f2 := OmniLight3D.new()
	f2.light_color = Color(0.68, 0.76, 0.88)
	f2.light_energy = 1.05
	f2.omni_range = 7.5
	f2.shadow_enabled = true
	f2.shadow_bias = 0.04
	f2.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	f2.position = Vector3(-1.0, 4.5, 2.0)
	add_child(f2)
	var f3 := OmniLight3D.new()
	f3.light_color = Color(0.65, 0.74, 0.86)
	f3.light_energy = 0.95
	f3.omni_range = 7.0
	f3.shadow_enabled = true
	f3.shadow_bias = 0.04
	f3.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	f3.position = Vector3(0.0, 7.5, 1.0)
	add_child(f3)


func _build_void_atmosphere() -> void:
	## Dense blue-grey pool under floor 1 so column feet dissolve into fog.
	for i in 5:
		var p := OmniLight3D.new()
		p.light_color = Color(0.14, 0.22, 0.34)
		p.light_energy = 0.22
		p.omni_range = 14.0
		p.shadow_enabled = false
		p.light_volumetric_fog_energy = 1.35
		p.position = Vector3(-4.0 + float(i) * 2.2, -5.5 - float(i) * 1.4, 0.2)
		add_child(p)
	_tune_floor_fog()


func _tune_floor_fog() -> void:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		return
	var env := we.environment
	## Height fog thickens below F1 so shafts fade before their ends read.
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.15, 0.24)
	env.fog_density = 0.009
	env.fog_height = 0.35
	env.fog_height_density = 0.32
	env.fog_aerial_perspective = 0.7
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.009
	env.volumetric_fog_albedo = Color(0.10, 0.15, 0.24)
	env.volumetric_fog_emission = Color(0.03, 0.05, 0.09)
	env.volumetric_fog_emission_energy = 0.38
	env.volumetric_fog_ambient_inject = 0.58
	env.volumetric_fog_length = 80.0


func _lift_shell_readability(node: Node) -> void:
	## Midground mass is authored near-black; lift albedo so frames/walls read at 25–40%.
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		var surfaces := mesh.get_surface_count() if mesh else 0
		for i in surfaces:
			var src := mi.get_active_material(i)
			if src == null:
				continue
			var mat := src.duplicate() as Material
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				if not sm.emission_enabled:
					sm.albedo_color = sm.albedo_color.lerp(Color(0.18, 0.20, 0.24), 0.42)
					sm.metallic = minf(sm.metallic, 0.4)
					sm.roughness = maxf(sm.roughness, 0.62)
			mi.set_surface_override_material(i, mat)
	for c in node.get_children():
		_lift_shell_readability(c)


func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(node as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for c in node.get_children():
		_disable_shadows(c)


func _enable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in node.get_children():
		_enable_shadows(c)


func _dim_emissives(node: Node, mul: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		var surfaces := mesh.get_surface_count() if mesh else 0
		for i in surfaces:
			var src := mi.get_active_material(i)
			if src == null:
				continue
			var mat := src.duplicate() as Material
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				if sm.emission_enabled:
					sm.emission_energy_multiplier *= mul
					sm.emission = sm.emission.lerp(Color(0.14, 0.22, 0.32), 0.4)
			mi.set_surface_override_material(i, mat)
	for c in node.get_children():
		_dim_emissives(c, mul)


func _is_capturing() -> bool:
	return capture_on_ready or OS.get_cmdline_user_args().has("--capture-shaft-shell")


func _hero_cam() -> Camera3D:
	return get_node_or_null("HeroCamera") as Camera3D


func _refresh_cam_hint() -> void:
	var hud := get_node_or_null("Hud")
	if hud == null or not hud.has_method("set_cam_hint"):
		return
	if _cam_mode == CamMode.ORBIT:
		hud.call("set_cam_hint", "RMB orbit  ·  WASD pan  ·  O fly  ·  R reset")
	else:
		hud.call("set_cam_hint", "RMB look  ·  WASD fly  ·  O orbit  ·  R reset")


func _sync_orbit_from_camera(cam: Camera3D) -> void:
	var offset: Vector3 = cam.global_position - _orbit_pivot
	_orbit_dist = clampf(offset.length(), orbit_min_distance, orbit_max_distance)
	if _orbit_dist < 0.05:
		_orbit_dist = 22.0
		offset = Vector3(0.0, 0.7, 1.0)
	_orbit_yaw = atan2(offset.x, offset.z)
	var flat := Vector2(offset.x, offset.z).length()
	_orbit_pitch = clampf(atan2(offset.y, maxf(flat, 0.01)), deg_to_rad(12.0), deg_to_rad(82.0))


func _apply_orbit(cam: Camera3D) -> void:
	var cp := cos(_orbit_pitch)
	var offset := Vector3(
		sin(_orbit_yaw) * cp,
		sin(_orbit_pitch),
		cos(_orbit_yaw) * cp
	) * _orbit_dist
	cam.global_position = _orbit_pivot + offset
	cam.look_at(_orbit_pivot, Vector3.UP)
	cam.current = true


func _toggle_cam_mode() -> void:
	var cam := _hero_cam()
	if cam == null:
		return
	if _cam_mode == CamMode.ORBIT:
		_cam_mode = CamMode.FLY
		_orbiting = false
	else:
		_cam_mode = CamMode.ORBIT
		_looking = false
		_sync_orbit_from_camera(cam)
		_apply_orbit(cam)
	_refresh_cam_hint()


func _reset_camera() -> void:
	var cam := _hero_cam()
	if cam == null:
		return
	cam.position = _hero_home_pos
	cam.basis = _hero_home_basis
	cam.current = true
	_orbit_pivot = MAP_FOCUS
	_looking = false
	_orbiting = false
	_sync_orbit_from_camera(cam)
	if _cam_mode == CamMode.ORBIT:
		_apply_orbit(cam)


func _move_camera(delta: float) -> void:
	if _is_capturing():
		return
	var cam := _hero_cam()
	if cam == null:
		return
	var ix := Input.get_axis("ui_left", "ui_right")
	var iz := Input.get_axis("ui_down", "ui_up")
	var iy := 0.0
	if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE):
		iy += 1.0
	if Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_CTRL):
		iy -= 1.0
	if is_zero_approx(ix) and is_zero_approx(iz) and is_zero_approx(iy):
		return
	cam.current = true
	var speed := camera_speed * (camera_fast_mul if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var flat_fwd := Vector3(cam.global_transform.basis.z.x, 0.0, cam.global_transform.basis.z.z)
	if flat_fwd.length_squared() < 0.0001:
		flat_fwd = Vector3(0.0, 0.0, 1.0)
	flat_fwd = flat_fwd.normalized()
	var right := Vector3.UP.cross(flat_fwd).normalized()
	var move := (right * ix - flat_fwd * iz + Vector3.UP * iy) * speed * delta
	if _cam_mode == CamMode.ORBIT:
		_orbit_pivot += move
		_apply_orbit(cam)
	else:
		cam.global_position += move


func _input(event: InputEvent) -> void:
	if _is_capturing():
		return
	var cam := _hero_cam()
	if cam == null:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_R or k.physical_keycode == KEY_R:
			_reset_camera()
			get_viewport().set_input_as_handled()
			return
		if k.keycode == KEY_O or k.physical_keycode == KEY_O:
			_toggle_cam_mode()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if _cam_mode == CamMode.ORBIT:
				_orbiting = mb.pressed
			else:
				_looking = mb.pressed
			cam.current = true
			get_viewport().set_input_as_handled()
			return
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var inward := mb.button_index == MOUSE_BUTTON_WHEEL_UP
			if _cam_mode == CamMode.ORBIT:
				var step := 1.25 if inward else -1.25
				_orbit_dist = clampf(_orbit_dist - step, orbit_min_distance, orbit_max_distance)
				_apply_orbit(cam)
			else:
				cam.global_position += -cam.global_transform.basis.z * (1.15 if inward else -1.15)
			cam.current = true
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _cam_mode == CamMode.ORBIT and _orbiting:
			_orbit_yaw -= mm.relative.x * orbit_sensitivity
			_orbit_pitch = clampf(
				_orbit_pitch + mm.relative.y * orbit_sensitivity,
				deg_to_rad(12.0),
				deg_to_rad(82.0)
			)
			_apply_orbit(cam)
			get_viewport().set_input_as_handled()
		elif _cam_mode == CamMode.FLY and _looking:
			cam.rotate_y(-mm.relative.x * camera_look_sens)
			cam.rotate_object_local(Vector3.RIGHT, -mm.relative.y * camera_look_sens)
			var e := cam.rotation
			e.x = clampf(e.x, deg_to_rad(-85.0), deg_to_rad(25.0))
			cam.rotation = e
			cam.current = true
			get_viewport().set_input_as_handled()


func _run_capture() -> void:
	if _capture_done:
		return
	_capture_done = true
	var hud := get_node_or_null("Hud")
	if hud and hud.has_method("set_capture_mode"):
		hud.call("set_capture_mode", true)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(2.4).timeout
	await RenderingServer.frame_post_draw
	var dir := "res://artifacts/visual_previews"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	await _shot("HeroCamera", dir.path_join("shaft_shell_gameplay.png"))
	await _shot("BeautyCameraA", dir.path_join("shaft_shell_beauty.png"))
	await _shot("TopDownCamera", dir.path_join("shaft_shell_topdown_qa.png"))
	print("vertical_shaft_slice_shell: captured screenshots")
	if capture_on_ready or OS.get_cmdline_user_args().has("--capture-shaft-shell"):
		await get_tree().create_timer(0.2).timeout
		get_tree().quit()


func _shot(cam_name: String, path: String) -> void:
	var cam := get_node_or_null(cam_name) as Camera3D
	if cam == null:
		push_error("vertical_shaft_slice_shell: missing camera %s" % cam_name)
		return
	cam.current = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_error("vertical_shaft_slice_shell: no viewport image")
		return
	var abs_path := ProjectSettings.globalize_path(path)
	img.save_png(abs_path)
	print("vertical_shaft_slice_shell: wrote %s" % abs_path)

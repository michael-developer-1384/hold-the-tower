extends Node3D

## Optional WORLD DEBUG and action-score overlays. Default off.

var sim = null
var package: Dictionary = {}
var world_debug: bool = false
var show_scores: bool = false
var _id_labels: Array = []
var _score_labels: Array = []
var _target_line: MeshInstance3D


func setup(p_sim, pkg: Dictionary) -> void:
	sim = p_sim
	package = pkg
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_world_debug(on: bool) -> void:
	world_debug = on
	_refresh()


func set_show_scores(on: bool) -> void:
	show_scores = on
	_refresh()


func _process(_delta: float) -> void:
	if world_debug or show_scores:
		_refresh()


func _refresh() -> void:
	_clear_labels(_id_labels)
	_clear_labels(_score_labels)
	if _target_line != null:
		_target_line.queue_free()
		_target_line = null
	if sim == null or sim.root == null:
		return
	var range_viz = sim.root.get_node_or_null("RangeVisualization")
	if world_debug:
		_spawn_ids()
		_draw_target()
		if range_viz != null and sim.game != null:
			var sel = sim.root.get_node_or_null("SelectionManager")
			if sel != null and sel.get("selected_tower") != null and range_viz.has_method("show_for_tower"):
				range_viz.call("show_for_tower", sel.get("selected_tower"))
	elif range_viz != null and range_viz.has_method("hide_all"):
		var sel2 = sim.root.get_node_or_null("SelectionManager")
		if sel2 == null or sel2.get("selected_tower") == null:
			range_viz.call("hide_all")
	if show_scores:
		_spawn_scores()


func _spawn_ids() -> void:
	if sim.game == null:
		return
	for t in sim.game.get_tree().get_nodes_in_group("towers"):
		if t is Node3D:
			_id_labels.append(_label_at(t.global_position + Vector3(0, 1.6, 0), str(t.get("runtime_id"))))
	for e in sim.game.get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and (not e.has_method("is_alive") or bool(e.call("is_alive"))):
			_id_labels.append(_label_at(e.global_position + Vector3(0, 1.4, 0), str(e.get("runtime_id"))))


func _draw_target() -> void:
	var sel = sim.root.get_node_or_null("SelectionManager")
	if sel == null:
		return
	var tower = sel.get("selected_tower")
	if tower == null or not is_instance_valid(tower):
		return
	var target = null
	if tower.has_method("_find_target"):
		target = tower.call("_find_target")
	if target == null or not (target is Node3D):
		return
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	im.surface_add_vertex(tower.global_position + Vector3(0, 0.8, 0))
	im.surface_add_vertex(target.global_position + Vector3(0, 0.6, 0))
	im.surface_end()
	_target_line = MeshInstance3D.new()
	_target_line.mesh = im
	add_child(_target_line)


func _spawn_scores() -> void:
	if sim == null or sim.clock == null:
		return
	var t: float = float(sim.clock.sim_time)
	var best: Dictionary = {}
	for d in package.get("agent_decisions", []):
		if float(d.get("time", 0.0)) <= t + 0.05:
			best = d
	if best.is_empty():
		return
	var considered: Array = best.get("actions_considered", [])
	var build = sim.game.get("build_manager") if sim.game else null
	if build == null or not build.has_method("get_spots"):
		return
	var spots: Dictionary = {}
	for spot in build.call("get_spots"):
		spots[str(spot.get("spot_id"))] = spot
	for item in considered:
		var a: Dictionary = item.get("action", {})
		if str(a.get("type")) != "PLACE_TOWER":
			continue
		var spot = spots.get(str(a.get("spot_id")), null)
		if spot == null or not (spot is Node3D):
			continue
		var txt := "%s  %.0f" % [str(a.get("tower_type", "")), float(item.get("score", 0.0))]
		_score_labels.append(_label_at(spot.global_position + Vector3(0, 1.2, 0), txt))


func _label_at(pos: Vector3, text: String) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = 0.012
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)
	return l


func _clear_labels(arr: Array) -> void:
	for n in arr:
		if n != null and is_instance_valid(n):
			n.queue_free()
	arr.clear()

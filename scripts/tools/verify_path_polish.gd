extends SceneTree

## Quick QA: ramp surface continuity + outer-corner dress count.
## godot --path . --headless --script res://scripts/tools/verify_path_polish.gd

var _scene: Node3D


func _init() -> void:
	var packed := load("res://scenes/prototypes/vertical_shaft_target_slice.tscn") as PackedScene
	if packed == null:
		push_error("verify_path_polish: missing slice scene")
		quit(1)
		return
	_scene = packed.instantiate() as Node3D
	if _scene == null:
		push_error("verify_path_polish: bad root")
		quit(1)
		return
	root.add_child(_scene)
	print("verify_path_polish: slice running")
	call_deferred("_run_checks")


func _run_checks() -> void:
	var factory := load("res://scripts/level/test_level_factory.gd")
	var level = factory.create_level()
	var builder := load("res://scripts/level/enemy_path_builder.gd")
	var path: PackedVector3Array = builder.build(level)
	print("verify_path_polish: waypoints=%d" % path.size())
	## Print ramp connector waypoints (edge-anchored climb + flat landing).
	for connector in level.connectors:
		var wps: PackedVector3Array = connector.get_waypoints()
		print("ramp %s points=%d" % [str(connector.connector_id), wps.size()])
		for i in wps.size():
			var p: Vector3 = wps[i]
			print("  [%d] (%.2f, %.2f, %.2f)" % [i, p.x, p.y, p.z])

	if _scene.has_method("_surface_y_at") and _scene.has_method("_walk_y"):
		var samples := [
			Vector3(3.50, 0.35, 0.0),
			Vector3(2.00, 1.35, 0.0),
			Vector3(0.50, 3.35, 0.0),
			Vector3(0.25, 3.35, 0.0),
			Vector3(0.00, 3.35, 0.0),
			Vector3(2.00, 3.35, 2.0),
			Vector3(2.00, 6.35, -0.5),
			Vector3(2.00, 6.35, -1.0),
		]
		for p in samples:
			var walk_y: float = _scene.call("_walk_y", p)
			var surf: float = _scene.call("_surface_y_at", p, walk_y)
			var pitch: float = _scene.call("_slope_pitch_at", p, Vector3(-1, 0, 0))
			print(
				"sample xz=(%.2f,%.2f) walk=%.3f surf=%.3f pitch=%.2f"
				% [p.x, p.z, walk_y, surf, pitch]
			)

	var corners := _count_named(_scene, "PathOuterCorner")
	print("verify_path_polish: outer_corners=%d" % corners)
	print("verify_path_polish: ok")
	quit(0)


func _count_named(node: Node, needle: String) -> int:
	var n := 0
	if String(node.name).findn(needle) >= 0:
		n += 1
	for c in node.get_children():
		n += _count_named(c, needle)
	return n

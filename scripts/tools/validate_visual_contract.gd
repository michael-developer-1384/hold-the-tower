extends SceneTree

## Headless visual contract: shared pedestal footprint + semantic nodes.
## godot --headless --path . --script res://scripts/tools/validate_visual_contract.gd

const FOOTPRINT := 0.36
const FOOTPRINT_Y := 0.20
const EPS := 0.008


func _init() -> void:
	var ok := _run()
	quit(0 if ok else 1)


func _run() -> bool:
	var ok := true
	ok = _check_tower(
		"res://scenes/towers/visuals/sentry_visual.tscn",
		["Base", "Turret", "WeaponPitch", "RecoilAssembly", "Muzzle", "Sensor"]
	) and ok
	ok = _check_tower(
		"res://scenes/towers/visuals/guard_post_visual.tscn",
		["Base", "GuardA", "GuardB", "Core"]
	) and ok
	ok = _check_tower(
		"res://scenes/towers/visuals/lava_tower_visual.tscn",
		["Base", "Spout", "Core"]
	) and ok
	ok = _check_named(
		"res://scenes/towers/visuals/guard_visual.tscn",
		["Hip", "Torso", "Head", "Visor", "ArmL", "ArmR", "LegL", "LegR"]
	) and ok
	ok = _check_named(
		"res://scenes/enemies/visuals/bot_visual.tscn",
		["Hip", "Torso", "Head", "Visor", "EyeL", "EyeR", "Antenna", "ArmL", "ArmR", "LegL", "LegR"]
	) and ok
	ok = _check_runtime_sockets() and ok
	ok = _check_preview() and ok
	if ok:
		print("visual_contract: OK")
	return ok


func _check_tower(path: String, required: PackedStringArray) -> bool:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("visual_contract: missing %s" % path)
		return false
	var root := scene.instantiate() as Node3D
	if root == null:
		push_error("visual_contract: root not Node3D %s" % path)
		return false
	self.root.add_child(root)
	var ok := true
	for n in required:
		if _find_named(root, n) == null:
			push_error("visual_contract: %s missing node %s" % [path, n])
			ok = false
	var base := root.get_node_or_null("Base") as Node3D
	if base == null:
		push_error("visual_contract: %s missing Base" % path)
		ok = false
	else:
		if absf(base.position.x) > 0.001 or absf(base.position.z) > 0.001:
			push_error("visual_contract: %s Base not on X/Z 0" % path)
			ok = false
	var hits := _footprint_violations(root)
	for line in hits:
		push_error("visual_contract: %s %s" % [path, line])
		ok = false
	root.queue_free()
	if ok:
		print("visual_contract tower: %s OK" % path.get_file())
	return ok


func _check_named(path: String, required: PackedStringArray) -> bool:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("visual_contract: missing %s" % path)
		return false
	var root := scene.instantiate() as Node3D
	if root == null:
		push_error("visual_contract: root not Node3D %s" % path)
		return false
	var ok := true
	for n in required:
		if _find_named(root, n) == null:
			push_error("visual_contract: %s missing node %s" % [path, n])
			ok = false
	root.free()
	if ok:
		print("visual_contract rig: %s OK" % path.get_file())
	return ok


func _check_runtime_sockets() -> bool:
	var sentry_scene := load("res://scenes/towers/basic_tower.tscn") as PackedScene
	var sentry := sentry_scene.instantiate() as Node3D
	root.add_child(sentry)
	var VisualSocketsScript = load("res://scripts/visuals/visual_sockets.gd")
	var vis := sentry.get_node_or_null("Visual")
	if vis == null:
		push_error("visual_contract: runtime missing Visual")
		sentry.queue_free()
		return false
	if VisualSocketsScript.resolve(vis, "turret") == null:
		push_error("visual_contract: runtime missing turret socket")
		sentry.queue_free()
		return false
	if VisualSocketsScript.resolve(vis, "muzzle") == null:
		push_error("visual_contract: runtime missing muzzle socket")
		sentry.queue_free()
		return false
	sentry.queue_free()
	var lava := (load("res://scenes/towers/lava_tower.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lava)
	if lava.get_node_or_null("Visual/Spout") == null:
		push_error("visual_contract: runtime missing Visual/Spout")
		lava.queue_free()
		return false
	lava.queue_free()
	var post := (load("res://scenes/towers/guard_post.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(post)
	if post.get_node_or_null("Visual/GuardA") == null or post.get_node_or_null("Visual/GuardB") == null:
		push_error("visual_contract: runtime missing GuardA/GuardB")
		post.queue_free()
		return false
	var homes: Array = post.get("_home_offsets")
	if homes.size() < 2:
		push_error("visual_contract: missing _home_offsets")
		post.queue_free()
		return false
	var a: Vector3 = homes[0]
	var b: Vector3 = homes[1]
	if absf(a.x + 0.25) > 0.04 or absf(b.x - 0.25) > 0.04:
		push_error("visual_contract: home offsets should be ~±0.25, got %s %s" % [a, b])
		post.queue_free()
		return false
	if absf(a.y) > 0.001 or absf(b.y) > 0.001:
		push_error("visual_contract: home offset Y must stay 0")
		post.queue_free()
		return false
	post.queue_free()
	print("visual_contract runtime sockets: OK")
	return true


func _check_preview() -> bool:
	var preview_scene := load("res://ui/components/entity_preview_3d.tscn") as PackedScene
	if preview_scene == null:
		push_error("visual_contract: missing EntityPreview3D")
		return false
	var preview := preview_scene.instantiate()
	root.add_child(preview)
	if not preview.has_method("set_visual_scene"):
		push_error("visual_contract: EntityPreview3D missing set_visual_scene")
		preview.queue_free()
		return false
	var vis := load("res://scenes/towers/visuals/sentry_visual.tscn") as PackedScene
	preview.call("set_visual_scene", vis)
	print("visual_contract preview: OK")
	preview.queue_free()
	return true


func _find_named(root: Node, node_name: String) -> Node:
	if root.has_node(node_name):
		return root.get_node(node_name)
	return root.find_child(node_name, true, false)


func _footprint_violations(root: Node3D) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var xform: Transform3D = item[1]
		if n is Node3D:
			xform = xform * (n as Node3D).transform
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var skip := false
			var walk: Node = mi
			while walk != null and walk != root:
				var nm := String(walk.name)
				if nm == "GuardA" or nm == "GuardB" or nm == "PreviewGuard":
					skip = true
					break
				walk = walk.get_parent()
			if skip:
				pass
			elif mi.mesh != null:
				var local := mi.get_aabb()
				for i in 8:
					var corner := xform * local.get_endpoint(i)
					if corner.y <= FOOTPRINT_Y + 0.0001:
						if absf(corner.x) > FOOTPRINT + EPS or absf(corner.z) > FOOTPRINT + EPS:
							out.append(
								"%s low-geom outside 0.72 pad at %s" % [mi.get_path(), corner]
							)
		for child in n.get_children():
			stack.append([child, xform])
	return out

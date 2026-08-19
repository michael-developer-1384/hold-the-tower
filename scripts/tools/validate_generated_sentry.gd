extends SceneTree

## Headless checks for the generated Sentry GLB + visual scene.
## godot --headless --path . --script res://scripts/tools/validate_generated_sentry.gd

const GLB := "res://assets/generated/towers/sentry.glb"
const VISUAL := "res://scenes/towers/visuals/sentry_visual.tscn"
const TRI_MAX := 30000
var SOCKETS := PackedStringArray([
	"Base", "Turret", "WeaponPitch", "RecoilAssembly", "Weapon",
	"Muzzle", "MuzzleLeft", "MuzzleRight", "Sensor"
])


func _init() -> void:
	var ok := _run()
	quit(0 if ok else 1)


func _run() -> bool:
	var abs_path := ProjectSettings.globalize_path(GLB)
	if not FileAccess.file_exists(abs_path) and not ResourceLoader.exists(GLB):
		push_error("generated sentry: missing %s" % GLB)
		return false
	var f := FileAccess.open(GLB, FileAccess.READ)
	if f == null:
		# Imported resource may not open as raw file via res:// on some hosts.
		if not ResourceLoader.exists(GLB):
			push_error("generated sentry: cannot open %s" % GLB)
			return false
	else:
		var sz := f.get_length()
		f.close()
		if sz <= 0:
			push_error("generated sentry: GLB is empty")
			return false
		print("generated sentry: glb_bytes=%d" % sz)

	var packed := load(GLB) as PackedScene
	if packed == null:
		push_error("generated sentry: Godot failed to import GLB")
		return false
	var vis_scene := load(VISUAL) as PackedScene
	if vis_scene == null:
		push_error("generated sentry: missing visual scene")
		return false
	var root := vis_scene.instantiate() as Node3D
	if root == null:
		push_error("generated sentry: visual root not Node3D")
		return false
	self.root.add_child(root)

	var ok := true
	var VisualSocketsScript = load("res://scripts/visuals/visual_sockets.gd")
	for sock in ["base", "turret", "weapon_pitch", "recoil", "muzzle", "sensor"]:
		if VisualSocketsScript.resolve(root, sock) == null:
			push_error("generated sentry: missing socket %s" % sock)
			ok = false
	for n in SOCKETS:
		if root.find_child(n, true, false) == null and root.get_node_or_null(n) == null:
			push_error("generated sentry: missing node %s" % n)
			ok = false

	var stats := {"tris": 0, "verts": 0, "mats": {}}
	_count_meshes(root, stats)
	var tris: int = int(stats["tris"])
	var verts: int = int(stats["verts"])
	var mats: Dictionary = stats["mats"]
	print("generated sentry: triangles=%d vertices=%d materials=%d" % [tris, verts, mats.size()])
	if tris <= 0:
		push_error("generated sentry: no triangles")
		ok = false
	if tris > TRI_MAX:
		push_error("generated sentry: triangle count %d > %d" % [tris, TRI_MAX])
		ok = false

	var runtime := (load("res://scenes/towers/basic_tower.tscn") as PackedScene).instantiate() as Node3D
	self.root.add_child(runtime)
	if runtime.get_node_or_null("Visual") == null:
		push_error("generated sentry: runtime missing Visual")
		ok = false
	else:
		var vis := runtime.get_node("Visual")
		if VisualSocketsScript.resolve(vis, "turret") == null or VisualSocketsScript.resolve(vis, "muzzle") == null:
			push_error("generated sentry: runtime sockets failed")
			ok = false

	if ok:
		print("generated sentry: OK")
	root.queue_free()
	runtime.queue_free()
	return ok


func _count_meshes(n: Node, stats: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			var mesh := mi.mesh
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s)
				var va: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				stats["verts"] = int(stats["verts"]) + va.size()
				var ia = arr[Mesh.ARRAY_INDEX]
				if ia and ia.size() > 0:
					stats["tris"] = int(stats["tris"]) + int(ia.size() / 3)
				else:
					stats["tris"] = int(stats["tris"]) + int(va.size() / 3)
				var mat := mi.get_active_material(s)
				if mat:
					(stats["mats"] as Dictionary)[str(mat.resource_name)] = true
	for child in n.get_children():
		_count_meshes(child, stats)

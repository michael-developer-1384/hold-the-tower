extends SceneTree

## Load every .gd under res:// and print parse failures.
## godot --headless --path . --script res://scripts/tools/check_scripts.gd


func _initialize() -> void:
	var failed := 0
	var checked := 0
	var paths: PackedStringArray = _collect("res://")
	paths.sort()
	for path in paths:
		if path.begins_with("res://scripts/tools/check_scripts.gd"):
			continue
		checked += 1
		var script = load(path)
		if script == null:
			failed += 1
			print("FAIL  %s" % path)
	print("check_scripts: %d checked, %d failed" % [checked, failed])
	quit(1 if failed > 0 else 0)


func _collect(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var child: String = dir_path.path_join(name)
		if dir.current_is_dir():
			if name in ["addons", ".git"]:
				name = dir.get_next()
				continue
			out.append_array(_collect(child))
		elif name.ends_with(".gd"):
			out.append(child)
		name = dir.get_next()
	dir.list_dir_end()
	return out

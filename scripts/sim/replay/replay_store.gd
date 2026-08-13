extends RefCounted

const DIR := "user://sim/replays"
const INDEX := "user://sim/replays/index.json"
const MAX_RETAINED := 40


static func save(pkg: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var run_id := str(pkg.get("run_id", "run"))
	var path := "%s/%s.json" % [DIR, run_id]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("ReplayStore: could not write %s" % path)
		return ""
	var ReplayPackage = load("res://scripts/sim/replay/replay_package.gd")
	f.store_string(JSON.stringify(ReplayPackage.sanitize(pkg), "\t"))
	f.close()
	_index_add(pkg, path)
	_enforce_retention()
	return path


static func load_path(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"error": "missing", "path": path}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"error": "parse", "path": path}
	var pkg: Dictionary = parsed
	var ReplayPackage = load("res://scripts/sim/replay/replay_package.gd")
	if not ReplayPackage.compatible(pkg):
		return {"error": "schema", "message": ReplayPackage.incompatibility_message(pkg), "package": pkg}
	return ReplayPackage.desanitize(pkg)


static func load_id(run_id: String) -> Dictionary:
	return load_path("%s/%s.json" % [DIR, run_id])


static func list_index() -> Array:
	var f := FileAccess.open(INDEX, FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed


static func delete_id(run_id: String) -> void:
	var path := "%s/%s.json" % [DIR, run_id]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var idx: Array = list_index()
	var keep: Array = []
	for item in idx:
		if str(item.get("run_id")) != run_id:
			keep.append(item)
	_write_index(keep)


static func clear_all() -> void:
	for item in list_index():
		delete_id(str(item.get("run_id")))
	_write_index([])


static func _index_add(pkg: Dictionary, path: String) -> void:
	var idx: Array = list_index()
	idx.append({
		"run_id": str(pkg.get("run_id")),
		"path": path,
		"seed": int(pkg.get("seed", 0)),
		"agent_id": str(pkg.get("agent_id", "")),
		"won": bool(pkg.get("metrics", {}).get("won", false)),
		"created_at": str(pkg.get("created_at", "")),
		"duration": float(pkg.get("metrics", {}).get("duration", 0.0)),
		"lives_remaining": int(pkg.get("metrics", {}).get("lives_remaining", 0)),
	})
	_write_index(idx)


static func _enforce_retention() -> void:
	var idx: Array = list_index()
	while idx.size() > MAX_RETAINED:
		var oldest: Dictionary = idx[0]
		idx.remove_at(0)
		var path := str(oldest.get("path", ""))
		if not path.is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_write_index(idx)


static func _write_index(idx: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open(INDEX, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(idx, "\t"))
	f.close()

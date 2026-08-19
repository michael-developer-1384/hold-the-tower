extends Node

## Device/settings persistence separate from progression profile.

const PATH := "user://settings.json"
const VERSION := 1

signal settings_changed(section: String)

var _data: Dictionary = {}
var _boot_done: bool = false


func _ready() -> void:
	_data = _defaults()
	_load()
	apply_all()


func get_section(section: String) -> Dictionary:
	return (_data.get(section, {}) as Dictionary).duplicate(true)


func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	var sec: Dictionary = _data.get(section, {})
	if sec.has(key):
		return sec[key]
	return fallback


func set_value(section: String, key: String, value: Variant, apply_now: bool = true) -> void:
	if not _data.has(section):
		_data[section] = {}
	(_data[section] as Dictionary)[key] = value
	_save()
	if apply_now:
		apply_section(section)
	settings_changed.emit(section)


func apply_all() -> void:
	apply_section("display")
	apply_section("audio")
	apply_section("controls")
	apply_section("accessibility")


func apply_section(section: String) -> void:
	match section:
		"display":
			_apply_display()
		"audio":
			_apply_audio()
		"accessibility":
			_apply_accessibility()
		_:
			pass


func reduced_motion() -> bool:
	return bool(get_value("accessibility", "reduced_motion", false))


func ui_scale() -> float:
	return float(get_value("display", "ui_scale", 1.0))


func time_machine_enabled() -> bool:
	return bool(get_value("gameplay", "time_machine", true))


func floor_ghosting_enabled() -> bool:
	return bool(get_value("gameplay", "floor_ghosting", false))


func preview_uses_kit() -> bool:
	return str(get_value("visual", "preview_model", "generated")) == "kit"


func set_preview_uses_kit(use_kit: bool) -> void:
	set_value("visual", "preview_model", "kit" if use_kit else "generated", false)


func mark_boot_shown() -> void:
	_boot_done = true


func boot_already_shown() -> bool:
	return _boot_done


func _defaults() -> Dictionary:
	return {
		"version": VERSION,
		"display": {
			"window_mode": "windowed", # exclusive | borderless | windowed
			"resolution": "1920x1080",
			"vsync": true,
			"ui_scale": 1.0,
		},
		"audio": {
			"master": 0.85,
			"music": 0.55,
			"sfx": 0.75,
			"ui": 0.65,
			"muted": false,
		},
		"controls": {
			"mouse_orbit_sensitivity": 1.0,
			"gamepad_camera_sensitivity": 1.0,
			"zoom_sensitivity": 1.0,
			"invert_y": false,
		},
		"accessibility": {
			"reduced_motion": false,
			"ui_scale": 1.0,
		},
		"gameplay": {
			"time_machine": true,
			"floor_ghosting": false,
		},
		"visual": {
			"preview_model": "generated",
		},
	}


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		_save()
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_merge_dict(_data, parsed)


func _save() -> void:
	_data["version"] = VERSION
	var abs_path := ProjectSettings.globalize_path(PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()


func _merge_dict(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		if typeof(src[k]) == TYPE_DICTIONARY and typeof(dst.get(k)) == TYPE_DICTIONARY:
			_merge_dict(dst[k], src[k])
		else:
			dst[k] = src[k]


func _apply_display() -> void:
	var mode := str(get_value("display", "window_mode", "windowed"))
	var vsync := bool(get_value("display", "vsync", true))
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	match mode:
		"exclusive":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var res := str(get_value("display", "resolution", "1920x1080")).split("x")
			if res.size() == 2:
				var w := int(res[0])
				var h := int(res[1])
				if w > 0 and h > 0:
					DisplayServer.window_set_size(Vector2i(w, h))
	var scale := float(get_value("display", "ui_scale", 1.0))
	get_tree().root.content_scale_factor = clampf(scale, 0.8, 1.5)


func _apply_audio() -> void:
	if typeof(UiAudio) != TYPE_NIL and UiAudio.has_method("apply_volumes"):
		UiAudio.call("apply_volumes", get_section("audio"))


func _apply_accessibility() -> void:
	# UI scale shared with display apply.
	_apply_display()
	if typeof(UiMotion) != TYPE_NIL and UiMotion.has_method("set_reduced_motion"):
		UiMotion.call("set_reduced_motion", reduced_motion())

extends SceneTree

## godot --path . --script res://scripts/tools/capture_vertical_shaft_slice.gd
## Instantiates the vertical shaft target slice and writes gameplay/beauty/QA PNGs.


func _init() -> void:
	var packed := load("res://scenes/prototypes/vertical_shaft_target_slice.tscn") as PackedScene
	if packed == null:
		push_error("capture_vertical_shaft_slice: missing vertical_shaft_target_slice.tscn")
		quit(1)
		return
	var scene := packed.instantiate() as Node3D
	if scene == null:
		push_error("capture_vertical_shaft_slice: slice root is not Node3D")
		quit(1)
		return
	scene.set("capture_on_ready", true)
	root.add_child(scene)
	print("capture_vertical_shaft_slice: slice running")

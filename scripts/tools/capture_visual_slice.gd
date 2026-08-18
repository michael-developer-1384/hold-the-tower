extends SceneTree

## godot --path . --script res://scripts/tools/capture_visual_slice.gd
## Instantiates the visual target slice and writes hero/beauty PNGs.


func _init() -> void:
	var packed := load("res://scenes/prototypes/visual_target_slice.tscn") as PackedScene
	if packed == null:
		push_error("capture_visual_slice: missing visual_target_slice.tscn")
		quit(1)
		return
	var scene := packed.instantiate() as Node3D
	if scene == null:
		push_error("capture_visual_slice: slice root is not Node3D")
		quit(1)
		return
	scene.set("capture_on_ready", true)
	root.add_child(scene)
	print("capture_visual_slice: slice running")

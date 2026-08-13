extends Node3D

## Spawns short-lived world-space damage/heal labels.

const SimContextScript := preload("res://scripts/sim/sim_context.gd")


static func spawn(parent: Node, world_pos: Vector3, text: String, color: Color = Color.WHITE) -> void:
	if SimContextScript.skip_presentation():
		return
	if parent == null or not is_instance_valid(parent):
		return
	var node := Node3D.new()
	node.name = "FloatingText"
	parent.add_child(node)
	node.global_position = world_pos + Vector3(0.0, 0.9, 0.0)

	var label := Label3D.new()
	label.text = text
	label.font_size = 28
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.outline_size = 4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	node.add_child(label)

	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "global_position:y", node.global_position.y + 0.7, 0.75)
	tween.tween_property(label, "modulate:a", 0.0, 0.75)
	tween.chain().tween_callback(node.queue_free)

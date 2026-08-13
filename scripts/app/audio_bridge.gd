class_name AudioBridge
extends RefCounted

## Resolve gameplay/UI audio without compile-time autoload identifiers.
## Works in PLAY and in `--script` / headless tools.


static func gameplay() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("GameplayAudio")


static func ui() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("UiAudio")


static func play_3d(event_id: String, world_position: Vector3) -> void:
	var a := gameplay()
	if a != null and a.has_method("play_3d"):
		a.call("play_3d", event_id, world_position)


static func play_global(event_id: String) -> void:
	var a := gameplay()
	if a != null and a.has_method("play_global"):
		a.call("play_global", event_id)


static func set_suppressed(suppressed: bool) -> void:
	var a := gameplay()
	if a != null and a.has_method("set_suppressed"):
		a.call("set_suppressed", suppressed)


static func stop_all() -> void:
	var a := gameplay()
	if a != null and a.has_method("stop_all"):
		a.call("stop_all")

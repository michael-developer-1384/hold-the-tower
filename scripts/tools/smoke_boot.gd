extends SceneTree

## Headless smoke: Command Center graph, Sim Lab page, one sim, Watch host.
## godot --headless --path . --script res://scripts/tools/smoke_boot.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	print("smoke_boot: start")
	var lab_scene: PackedScene = load("res://ui/pages/simulation_lab_page.tscn")
	if lab_scene == null:
		push_error("smoke_boot: missing simulation_lab_page.tscn")
		quit(1)
		return
	var lab: Node = lab_scene.instantiate()
	root.add_child(lab)
	await process_frame
	await process_frame
	print("smoke_boot: lab page instantiated")
	lab.queue_free()
	await process_frame

	var Batch = load("res://scripts/sim/balance/batch_runner.gd")
	var result: Dictionary = await Batch.run_one(self, {
		"level_id": "vertical_test",
		"difficulty_id": "normal",
		"agent_id": "smart",
		"player_profile": "optimizer",
		"seed": 1,
		"lookahead": false,
		"record": "replay",
		"time_scale": 40.0,
		"max_sim_seconds": 180.0,
	})
	if result.has("error"):
		push_error("smoke_boot: sim failed %s" % str(result.get("error")))
		quit(1)
		return
	print("smoke_boot: sim done won=%s core=%s replay=%s" % [
		str(result.get("won")), str(result.get("lives_remaining")), str(result.get("replay_id")),
	])

	var run_id: String = str(result.get("replay_id", ""))
	if run_id.is_empty():
		print("smoke_boot: no replay_id, skip watch")
		print("smoke_boot: PASS")
		quit(0)
		return

	var AppRouter = load("res://scripts/app/app_router.gd")
	AppRouter.pending_replay_id = run_id
	AppRouter.pending_seek_time = -1.0
	var watch_scene: PackedScene = load("res://scenes/sim/sim_watch.tscn")
	if watch_scene == null:
		push_error("smoke_boot: missing sim_watch.tscn")
		quit(1)
		return
	var watch: Node = watch_scene.instantiate()
	root.add_child(watch)
	current_scene = watch
	await process_frame
	await process_frame
	await process_frame
	print("smoke_boot: watch host instantiated")
	if watch.has_method("_leave"):
		watch.call("_leave")
	else:
		watch.queue_free()
	await process_frame
	print("smoke_boot: PASS")
	quit(0)

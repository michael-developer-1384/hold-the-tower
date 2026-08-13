extends Node3D

## Visual replay host. Same gameplay graph; agent never re-decides.

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const PlaybackScript := preload("res://scripts/sim/replay/playback_controller.gd")
const OverlayScript := preload("res://scripts/sim/replay/observatory_overlays.gd")

var sim = null
var playback: Node
var hud: CanvasLayer
var overlays: Node
var package: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var run_id := AppRouterScript.pending_replay_id
	package = load("res://scripts/sim/replay/replay_store.gd").load_id(run_id)
	if package.has("error"):
		push_warning("Watch: %s" % str(package.get("message", package.get("error"))))
		AppRouterScript.leave_watch(get_tree())
		return
	var SimScript = load("res://scripts/sim/game_simulation.gd")
	sim = SimScript.new()
	sim.setup({
		"level_id": str(package.get("level_id", "vertical_test")),
		"difficulty_id": str(package.get("difficulty_id", "normal")),
		"seed": int(package.get("seed", 1)),
		"config": package.get("simulation_config", {}).get("config", {}),
		"presentation": true,
		"record": "none",
		"existing_root": self,
		"max_sim_seconds": 1800.0,
	}, get_tree())
	await sim.await_ready()
	if typeof(package.get("initial_snapshot")) == TYPE_DICTIONARY and not (package.get("initial_snapshot") as Dictionary).is_empty():
		load("res://scripts/sim/sim_snapshot.gd").restore(sim, package.get("initial_snapshot"))
	sim.set_replay(package.get("action_log", []))
	var selection = get_node_or_null("SelectionManager")
	if selection != null and "allow_enemy_select" in selection:
		selection.allow_enemy_select = true
	playback = PlaybackScript.new()
	playback.name = "PlaybackController"
	add_child(playback)
	playback.bind(sim, package)
	overlays = OverlayScript.new()
	overlays.name = "ObservatoryOverlays"
	add_child(overlays)
	overlays.setup(sim, package)
	hud = get_node_or_null("ObservatoryHUD")
	if hud != null and hud.has_method("bind"):
		hud.call("bind", sim, playback, package, overlays)
	var seek_t := AppRouterScript.pending_seek_time
	AppRouterScript.pending_seek_time = -1.0
	if seek_t >= 0.0:
		await playback.seek_exact(seek_t)
	else:
		playback.pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()


func _leave() -> void:
	if playback != null and playback.has_method("shutdown"):
		playback.shutdown()
	if sim != null:
		sim.cleanup()
	AppRouterScript.leave_watch(get_tree())

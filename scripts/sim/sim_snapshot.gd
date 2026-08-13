extends RefCounted

## Capture/restore helpers for lookahead. V1 captures session-shaped state plus
## light sim extras; full combat restore (projectiles, CDs, spawn queue) is incomplete.


static func capture(game: Node, clock = null, action_log: Array = []) -> Dictionary:
	var SessionStoreScript = load("res://scripts/run/session_store.gd")
	var snap: Dictionary = SessionStoreScript.capture_from_game(game, true)
	if clock != null:
		snap["sim_time"] = clock.sim_time
	snap["action_log"] = action_log.duplicate(true)
	# Placeholders for future bit-complete restore.
	snap["spawn_queue"] = []
	snap["projectiles"] = []
	snap["tower_cooldowns"] = {}
	return snap


static func restore_incomplete(_game: Node, _snap: Dictionary) -> bool:
	## Not combat-complete in V1 — prefer SessionStore.apply when used from PLAY.
	return false

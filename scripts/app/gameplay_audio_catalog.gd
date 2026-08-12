class_name GameplayAudioCatalog
extends RefCounted

## Sound event definitions for GameplayAudio. Paths only — no playback.

enum Kind { SPATIAL, GLOBAL }


static func all() -> Dictionary:
	return {
		"sentry_fire": _ev("res://audio/sfx/sentry_fire.wav", Kind.SPATIAL, -8.0, 0.03, 8, 18.0),
		"projectile_hit": _ev("res://audio/sfx/projectile_hit.wav", Kind.SPATIAL, -12.0, 0.04, 8, 16.0),
		"guard_attack": _ev("res://audio/sfx/guard_attack.wav", Kind.SPATIAL, -10.0, 0.03, 6, 14.0),
		"enemy_attack": _ev("res://audio/sfx/enemy_attack.wav", Kind.SPATIAL, -11.0, 0.03, 6, 14.0),
		"melee_hit": _ev("res://audio/sfx/melee_hit.wav", Kind.SPATIAL, -10.0, 0.035, 6, 14.0),
		"enemy_death": _ev("res://audio/sfx/enemy_death.wav", Kind.SPATIAL, -9.0, 0.04, 5, 16.0),
		"guard_death": _ev("res://audio/sfx/guard_death.wav", Kind.SPATIAL, -7.0, 0.03, 4, 16.0),
		"tower_build": _ev("res://audio/sfx/tower_build.wav", Kind.SPATIAL, -4.0, 0.02, 3, 20.0),
		"wave_start": _ev("res://audio/sfx/wave_start.wav", Kind.GLOBAL, -5.0, 0.0, 2, 0.0),
		"wave_complete": _ev("res://audio/sfx/wave_complete.wav", Kind.GLOBAL, -6.0, 0.0, 2, 0.0),
		"core_hit": _ev("res://audio/sfx/core_hit.wav", Kind.GLOBAL, -3.0, 0.015, 2, 0.0),
		"level_complete": _ev("res://audio/sfx/level_complete.wav", Kind.GLOBAL, -4.0, 0.0, 1, 0.0),
		"game_over": _ev("res://audio/sfx/game_over.wav", Kind.GLOBAL, -3.0, 0.0, 1, 0.0),
	}


static func get_event(event_id: String) -> Dictionary:
	return all().get(event_id, {})


static func _ev(
	path: String,
	kind: int,
	volume_db: float,
	pitch_var: float,
	max_voices: int,
	max_distance: float
) -> Dictionary:
	return {
		"path": path,
		"kind": kind,
		"volume_db": volume_db,
		"pitch_variance": pitch_var,
		"max_voices": max_voices,
		"max_distance": max_distance,
		"unit_size": 2.5,
	}

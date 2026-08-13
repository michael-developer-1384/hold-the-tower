class_name SimContext
extends RefCounted

## Global simulation mode flags. Not an autoload — static accessors.

static var active: bool = false
static var presentation: bool = true
static var persist_profile: bool = true
static var verbose_prints: bool = true
static var run_seed: int = 0
static var sim_time_ms: float = 0.0 # advanced by SimClock / host
static var config_overrides: Dictionary = {}
static var clock = null # SimClock when simulating
static var rng = null # SeededRng when simulating


static func begin(p_seed: int = 0, p_config: Dictionary = {}) -> void:
	active = true
	presentation = false
	persist_profile = false
	verbose_prints = false
	run_seed = p_seed
	sim_time_ms = 0.0
	config_overrides = p_config.duplicate(true) if not p_config.is_empty() else {}
	clock = null
	rng = null


static func end() -> void:
	active = false
	presentation = true
	persist_profile = true
	verbose_prints = true
	run_seed = 0
	sim_time_ms = 0.0
	config_overrides.clear()
	clock = null
	rng = null


static func is_simulating() -> bool:
	return active


static func skip_presentation() -> bool:
	return active and not presentation


static func should_persist_profile() -> bool:
	return persist_profile


static func allow_prints() -> bool:
	return verbose_prints


static func now_ms() -> float:
	if active:
		return sim_time_ms
	return float(Time.get_ticks_msec())


static func get_override(key: String, default_value: Variant = null) -> Variant:
	if config_overrides.has(key):
		return config_overrides[key]
	return default_value


static func log_msg(msg: String) -> void:
	if allow_prints():
		print(msg)

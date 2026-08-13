class_name SeededRng
extends RefCounted

## Deterministic RNG for agents and future combat randomness.

var _rng := RandomNumberGenerator.new()
var _seed: int = 0


func _init(p_seed: int = 0) -> void:
	reset(p_seed)


func reset(p_seed: int) -> void:
	_seed = p_seed
	_rng.seed = p_seed if p_seed != 0 else 1


func get_seed() -> int:
	return _seed


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func randi() -> int:
	return _rng.randi()


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func pick(array: Array) -> Variant:
	if array.is_empty():
		return null
	return array[randi_range(0, array.size() - 1)]

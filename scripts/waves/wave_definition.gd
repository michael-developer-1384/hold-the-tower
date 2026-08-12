class_name WaveDefinition
extends Resource

@export var wave_number: int = 1
@export var groups: Array = [] # Array of WaveSpawnGroup dictionaries / resources


func total_count() -> int:
	var n := 0
	for g in groups:
		n += int(g.get("count", 0)) if typeof(g) == TYPE_DICTIONARY else int(g.count)
	return n

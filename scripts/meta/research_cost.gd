class_name ResearchCost
extends RefCounted

## Deprecated shim — use ResearchResolver. Kept so older tool paths fail loudly if misused.

const ResearchResolverScript := preload("res://scripts/meta/research_resolver.gd")


static func total_int(tower_id: String, params: Dictionary) -> int:
	var alloc := ResearchResolverScript.allocations_from_params(tower_id, params)
	return ResearchResolverScript.total_invested(alloc)


static func clamp_params(tower_id: String, params: Dictionary) -> Dictionary:
	var alloc := ResearchResolverScript.allocations_from_params(tower_id, params)
	return ResearchResolverScript.params_from_allocations(tower_id, alloc)

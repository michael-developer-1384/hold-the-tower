extends RefCounted

## Player profile = how perfectly an agent decides. Separate from agent_id.

const ID_OPTIMIZER := "optimizer"
const ID_EXPERT := "expert"
const ID_COMPETENT := "competent"
const ID_CASUAL := "casual"
const ID_BEGINNER := "beginner"

const ALL := [ID_OPTIMIZER, ID_EXPERT, ID_COMPETENT, ID_CASUAL, ID_BEGINNER]

## Temperature is a characteristic score-gap after relative softmax (score - best).
## consider_band: options worse than best by more than this get weight 0.
const DEFS := {
	ID_OPTIMIZER: {"temperature": 0.0, "consider_band": 0.0},
	ID_EXPERT: {"temperature": 1.0, "consider_band": 5.0},
	ID_COMPETENT: {"temperature": 6.0, "consider_band": 22.0},
	ID_CASUAL: {"temperature": 10.0, "consider_band": 40.0},
	ID_BEGINNER: {"temperature": 18.0, "consider_band": 80.0},
}


static func normalize(raw: String) -> String:
	var id: String = str(raw).to_lower()
	if id in ALL:
		return id
	return ID_OPTIMIZER


static func definition(profile: String) -> Dictionary:
	var id: String = normalize(profile)
	var d: Dictionary = DEFS.get(id, DEFS[ID_OPTIMIZER])
	return {
		"player_profile": id,
		"temperature": float(d.get("temperature", 0.0)),
		"consider_band": float(d.get("consider_band", 0.0)),
	}


static func temperature_of(profile: String) -> float:
	return float(definition(profile).get("temperature", 0.0))


static func consider_band_of(profile: String) -> float:
	return float(definition(profile).get("consider_band", 0.0))


static func resolve(opts: Dictionary) -> Dictionary:
	var profile: String = normalize(str(opts.get("player_profile", opts.get("profile", ID_OPTIMIZER))))
	var def: Dictionary = definition(profile)
	var overridden: bool = bool(opts.get("temperature_overridden", false)) \
		or str(opts.get("temperature_source", "")) == "override"
	if overridden and opts.has("temperature"):
		def["temperature"] = float(opts.get("temperature", 0.0))
		def["temperature_overridden"] = true
	else:
		def["temperature_overridden"] = false
	return def


static func mix_seed(master: int, stream: String) -> int:
	var h: int = int(hash("%d:%s" % [master, stream]))
	if h == 0:
		h = 1
	return absi(h)


static func apply_to_agent(agent, resolved: Dictionary) -> void:
	if agent == null:
		return
	if "temperature" in agent:
		agent.temperature = float(resolved.get("temperature", 0.0))
	if "consider_band" in agent:
		agent.consider_band = float(resolved.get("consider_band", 0.0))
	if "player_profile" in agent:
		agent.player_profile = str(resolved.get("player_profile", ID_OPTIMIZER))

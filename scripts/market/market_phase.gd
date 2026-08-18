class_name MarketPhase
extends RefCounted

enum Phase {
	PRE_MARKET,
	MARKET_OPEN,
	CLOSED,
}


static func resolve(
	run_ended: bool,
	waves_started: int,
	spawning: bool,
	spawn_finished: bool,
	enemies_alive: int
) -> Phase:
	if run_ended:
		return Phase.CLOSED
	if waves_started <= 0:
		return Phase.PRE_MARKET
	if spawning or not spawn_finished or enemies_alive > 0:
		return Phase.MARKET_OPEN
	return Phase.PRE_MARKET


static func label(phase: Phase) -> String:
	match phase:
		Phase.MARKET_OPEN:
			return "MARKET OPEN"
		Phase.CLOSED:
			return "MARKET CLOSED"
		_:
			return "PRE-MARKET"

class_name MoneyDisplay
extends RefCounted

## Player-facing cash like a trading ticker. Gameplay still stores integer gold.

const PRE_MARKET := "PRE-MARKET"
const MARKET_OPEN := "MARKET OPEN"
const OPENING_BELL := "OPENING BELL"


static func usd(amount: int) -> String:
	var prefix := "-" if amount < 0 else ""
	return "%s$%s.00" % [prefix, _group(absi(amount))]


static func usd_delta(amount: int) -> String:
	if amount > 0:
		return "+%s" % usd(amount)
	if amount < 0:
		return usd(amount)
	return "+%s" % usd(0)


static func session_name(game: Object) -> String:
	return MARKET_OPEN if is_market_open(game) else PRE_MARKET


static func is_market_open(game: Object) -> bool:
	if game == null:
		return false
	if bool(game.get("game_over")) or bool(game.get("level_complete")):
		return false
	if game.has_method("can_start_next_wave"):
		return not bool(game.call("can_start_next_wave"))
	return bool(game.get("wave_running"))


static func _group(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out

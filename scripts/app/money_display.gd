class_name MoneyDisplay
extends RefCounted

## Formatting only. Buying Power is whole tactical units; Portfolio uses cents.

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


static func usd_cents(amount_cents: int) -> String:
	var prefix := "-" if amount_cents < 0 else ""
	var absolute := absi(amount_cents)
	return "%s$%s.%02d" % [prefix, _group(int(absolute / 100.0)), absolute % 100]


static func usd_cents_delta(amount_cents: int) -> String:
	if amount_cents > 0:
		return "+%s" % usd_cents(amount_cents)
	return usd_cents(amount_cents)


static func session_name(game: Object) -> String:
	return MARKET_OPEN if is_market_open(game) else PRE_MARKET


static func is_market_open(game: Object) -> bool:
	if game == null:
		return false
	if bool(game.get("game_over")) or bool(game.get("level_complete")):
		return false
	var market = game.get("market_session")
	if market != null and "current_phase" in market:
		return int(market.get("current_phase")) == 1
	if game.has_method("can_start_next_wave"):
		return bool(game.get("wave_running"))
	return bool(game.get("wave_running"))


static func _group(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out

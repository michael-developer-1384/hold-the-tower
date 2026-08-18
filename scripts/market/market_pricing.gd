class_name MarketPricing
extends RefCounted

const MarketConfig := preload("res://scripts/market/market_config.gd")


static func price_ratio(current_hodl: float, run_open_hodl: float) -> float:
	if run_open_hodl <= 0.0:
		return 1.0
	return clampf(
		current_hodl / run_open_hodl,
		MarketConfig.MIN_TOWER_PRICE_MULTIPLIER,
		MarketConfig.MAX_TOWER_PRICE_MULTIPLIER
	)


static func quote(base_price: int, current_hodl: float, run_open_hodl: float) -> int:
	var ratio := price_ratio(current_hodl, run_open_hodl)
	var raw := float(base_price) * ratio
	if is_equal_approx(ratio, 1.0):
		return maxi(1, base_price)
	# Preserve the direction of even a small real market move in an integer wallet.
	return maxi(1, int(ceili(raw)) if ratio > 1.0 else int(floori(raw)))


static func quote_tower(definition: Resource, current_hodl: float, run_open_hodl: float) -> int:
	if definition == null:
		return 0
	return quote(int(definition.get("cost")), current_hodl, run_open_hodl)


static func quote_upgrade(definition: Resource, current_hodl: float, run_open_hodl: float) -> int:
	if definition == null:
		return 0
	return quote(int(definition.get("upgrade_cost")), current_hodl, run_open_hodl)


static func session_return(close_hodl: float, open_hodl: float) -> float:
	return price_ratio(close_hodl, open_hodl) - 1.0


static func sanitize_persisted_price(price: float) -> float:
	## Additive combat ticks can pin HODL at MIN_HODL_PRICE (0.01). That is a
	## numerical floor, not a tradable open: the next run would print 4× quotes
	## and four-digit session returns. Reconstitute anything below the quote floor.
	var floor_px := MarketConfig.INITIAL_HODL_PRICE * MarketConfig.MIN_TOWER_PRICE_MULTIPLIER
	if price < floor_px:
		return MarketConfig.INITIAL_HODL_PRICE
	return price


static func in_run_floor(run_open_hodl: float) -> float:
	return maxf(
		MarketConfig.MIN_HODL_PRICE,
		maxf(run_open_hodl, MarketConfig.MIN_HODL_PRICE) * MarketConfig.MIN_TOWER_PRICE_MULTIPLIER
	)


static func percent_vs_run_open(current_hodl: float, run_open_hodl: float) -> float:
	if run_open_hodl <= 0.0:
		return 0.0
	return (current_hodl / run_open_hodl - 1.0) * 100.0


static func buy_market_impact(executed_price: int) -> float:
	return (
		MarketConfig.BUY_MARKET_IMPACT_FACTOR
		* float(maxi(executed_price, 0))
		/ maxf(MarketConfig.REFERENCE_BUYING_POWER, 1.0)
	)

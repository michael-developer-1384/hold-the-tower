class_name PortfolioSettlement
extends RefCounted

const MarketConfig := preload("res://scripts/market/market_config.gd")
const PortfolioAccount := preload("res://scripts/economy/portfolio_account.gd")
const PortfolioConfig := preload("res://scripts/economy/portfolio_config.gd")


static func calculate(
	open_price: float,
	close_price: float,
	risk_notional_cents: int,
	leverage: float = PortfolioConfig.DEFAULT_LEVERAGE
) -> Dictionary:
	var session_return := close_price / open_price - 1.0 if open_price > 0.0 else 0.0
	var pnl_cents := int(round(float(risk_notional_cents) * session_return * leverage))
	return {
		"session_return": session_return,
		"risk_notional_cents": risk_notional_cents,
		"leverage": leverage,
		"portfolio_pnl_cents": pnl_cents,
	}


static func settle(
	portfolio: Dictionary,
	market: Dictionary,
	run: Dictionary
) -> Dictionary:
	var open_price := float(run.get("hodl_open", MarketConfig.INITIAL_HODL_PRICE))
	var close_price := float(run.get("hodl_close", open_price))
	var difficulty_id := str(run.get("difficulty_id", "normal"))
	var risk_cents := int(run.get(
		"risk_notional_cents",
		PortfolioConfig.risk_notional_cents(difficulty_id)
	))
	var leverage := float(run.get("leverage", PortfolioConfig.DEFAULT_LEVERAGE))
	var financial := calculate(open_price, close_price, risk_cents, leverage)
	var updated_portfolio := PortfolioAccount.apply_pnl(
		portfolio,
		int(financial["portfolio_pnl_cents"])
	)

	var previous_ath := float(market.get("all_time_high", market.get("current_price", open_price)))
	var run_high := float(run.get("hodl_high", maxf(open_price, close_price)))
	var new_ath := maxf(previous_ath, run_high)
	var anchor := maxf(float(market.get("ath_reward_anchor", previous_ath)), MarketConfig.MIN_HODL_PRICE)
	var thresholds_crossed := _thresholds_crossed(anchor, new_ath)
	var new_anchor := anchor * pow(1.0 + MarketConfig.ATH_REWARD_STEP, thresholds_crossed)
	if thresholds_crossed <= 0:
		new_anchor = anchor

	var updated_market := market.duplicate(true)
	updated_market["current_price"] = close_price
	updated_market["all_time_high"] = new_ath
	updated_market["ath_reward_anchor"] = new_anchor

	var result := run.duplicate(true)
	result.merge(financial, true)
	result.merge({
		"portfolio_before_cents": int(updated_portfolio["account_before_cents"]),
		"portfolio_after_cents": int(updated_portfolio["account_after_cents"]),
		"previous_ath": previous_ath,
		"run_ath": run_high,
		"new_ath": new_ath,
		"ath_thresholds_crossed": thresholds_crossed,
		"ath_rp_earned": thresholds_crossed * MarketConfig.ATH_RP_PER_STEP,
		"ath_xp_earned": thresholds_crossed * MarketConfig.ATH_XP_PER_STEP,
	}, true)
	return {
		"run": result,
		"portfolio": updated_portfolio,
		"market": updated_market,
	}


static func next_ath_threshold(anchor: float) -> float:
	return maxf(anchor, MarketConfig.MIN_HODL_PRICE) * (1.0 + MarketConfig.ATH_REWARD_STEP)


static func _thresholds_crossed(anchor: float, new_ath: float) -> int:
	if new_ath <= anchor:
		return 0
	var steps := 0
	var threshold := next_ath_threshold(anchor)
	while threshold <= new_ath + 0.0000001 and steps < 10000:
		steps += 1
		threshold *= 1.0 + MarketConfig.ATH_REWARD_STEP
	return steps

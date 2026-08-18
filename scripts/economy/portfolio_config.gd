class_name PortfolioConfig
extends RefCounted

const MarketConfig := preload("res://scripts/market/market_config.gd")

const INITIAL_ACCOUNT_BALANCE_CENTS := MarketConfig.INITIAL_ACCOUNT_BALANCE_CENTS
const DEFAULT_LEVERAGE := MarketConfig.DEFAULT_LEVERAGE


static func risk_notional_cents(difficulty_id: String) -> int:
	return MarketConfig.risk_notional_cents(difficulty_id)

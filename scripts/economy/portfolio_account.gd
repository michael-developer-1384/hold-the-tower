class_name PortfolioAccount
extends RefCounted

const PortfolioConfig := preload("res://scripts/economy/portfolio_config.gd")


static func default_state() -> Dictionary:
	var initial := PortfolioConfig.INITIAL_ACCOUNT_BALANCE_CENTS
	return {
		"account_balance_cents": initial,
		"lifetime_pnl_cents": 0,
		"account_ath_cents": initial,
		"runs_settled": 0,
	}


static func normalize(value: Dictionary) -> Dictionary:
	var defaults := default_state()
	return {
		"account_balance_cents": int(value.get(
			"account_balance_cents",
			value.get("balance_cents", defaults["account_balance_cents"])
		)),
		"lifetime_pnl_cents": int(value.get("lifetime_pnl_cents", 0)),
		"account_ath_cents": int(value.get(
			"account_ath_cents",
			value.get("account_balance_cents", defaults["account_ath_cents"])
		)),
		"runs_settled": maxi(int(value.get("runs_settled", 0)), 0),
	}


static func apply_pnl(state: Dictionary, pnl_cents: int) -> Dictionary:
	var out := normalize(state)
	var before := int(out["account_balance_cents"])
	var after := before + pnl_cents
	out["account_balance_cents"] = after
	out["lifetime_pnl_cents"] = int(out["lifetime_pnl_cents"]) + pnl_cents
	out["account_ath_cents"] = maxi(int(out["account_ath_cents"]), after)
	out["runs_settled"] = int(out["runs_settled"]) + 1
	out["account_before_cents"] = before
	out["account_after_cents"] = after
	out["portfolio_pnl_cents"] = pnl_cents
	return out


## Newest-first run history → chronological equity steps, including starting capital.
static func equity_curve(run_history: Array, current_balance_cents: int = -1) -> Array:
	var chrono: Array = []
	for i in range(run_history.size() - 1, -1, -1):
		var entry: Variant = run_history[i]
		if typeof(entry) == TYPE_DICTIONARY:
			chrono.append(entry)
	var start := PortfolioConfig.INITIAL_ACCOUNT_BALANCE_CENTS
	if not chrono.is_empty():
		var first: Dictionary = chrono[0]
		if first.has("portfolio_before_cents"):
			start = int(first.get("portfolio_before_cents", start))
	elif current_balance_cents >= 0:
		start = current_balance_cents
	var points: Array = [{
		"label": "OPEN",
		"equity_cents": start,
		"pnl_cents": 0,
		"is_open": true,
	}]
	var equity := start
	for run_raw in chrono:
		var run: Dictionary = run_raw
		if run.has("portfolio_after_cents"):
			equity = int(run.get("portfolio_after_cents"))
		else:
			equity += int(run.get("portfolio_pnl_cents", 0))
		points.append({
			"label": str(run.get("run_id", "")),
			"run_id": str(run.get("run_id", "")),
			"equity_cents": equity,
			"pnl_cents": int(run.get("portfolio_pnl_cents", 0)),
			"session_return": float(run.get("session_return", 0.0)),
			"assisted": bool(run.get("assisted", false)),
			"is_open": false,
		})
	return points

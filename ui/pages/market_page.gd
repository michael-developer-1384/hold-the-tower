extends Control

const ChartScript := preload("res://ui/components/hodl_equity_chart.gd")
const MoneyDisplayScript := preload("res://scripts/app/money_display.gd")
const PortfolioAccountScript := preload("res://scripts/economy/portfolio_account.gd")

@onready var _metrics: HBoxContainer = %Metrics
@onready var _chart_host: Control = %ChartHost
@onready var _recent: Label = %RecentRun

var _chart: Control


func _ready() -> void:
	if typeof(ProfileManager) != TYPE_NIL:
		ProfileManager.commit_pending_last_run()
	UiStyle.apply_theme(self)
	_chart = ChartScript.new()
	_chart.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chart_host.add_child(_chart)
	_build_metrics()
	_refresh_chart()


func _build_metrics() -> void:
	var portfolio: Dictionary = ProfileManager.get_portfolio()
	var current := ProfileManager.get_global_hodl_price()
	var hodl_ath := ProfileManager.get_global_hodl_ath()
	var distance := (current / hodl_ath - 1.0) * 100.0 if hodl_ath > 0.0 else 0.0
	for item in [
		["ACCOUNT EQUITY", MoneyDisplayScript.usd_cents(int(portfolio.get("account_balance_cents", 0)))],
		["ACCOUNT ATH", MoneyDisplayScript.usd_cents(int(portfolio.get("account_ath_cents", 0)))],
		["LIFETIME P/L", MoneyDisplayScript.usd_cents_delta(int(portfolio.get("lifetime_pnl_cents", 0)))],
		["SESSIONS SETTLED", str(int(portfolio.get("runs_settled", 0)))],
		["HODL INDEX", "%.2f" % current],
		["HODL ATH", "%.2f  (%+.2f%%)" % [hodl_ath, distance]],
		["NEXT RESEARCH", "%.2f" % ProfileManager.get_next_ath_research_threshold()],
	]:
		var col := VBoxContainer.new()
		col.add_child(UiStyle.make_flat_label(str(item[0]), 11, true))
		col.add_child(UiStyle.make_flat_label(str(item[1]), 19))
		_metrics.add_child(col)
	var last := _last_settled(ProfileManager.get_run_history())
	if last.is_empty():
		_recent.text = "No settled sessions yet. Equity only moves when a ranked run closes."
		return
	_recent.text = (
		"Last session  %s  ·  Account %s → %s  ·  HODL %+.2f%%"
		% [
			MoneyDisplayScript.usd_cents_delta(int(last.get("portfolio_pnl_cents", 0))),
			MoneyDisplayScript.usd_cents(int(last.get("portfolio_before_cents", 0))),
			MoneyDisplayScript.usd_cents(int(last.get("portfolio_after_cents", 0))),
			float(last.get("session_return", 0.0)) * 100.0,
		]
	)


func _refresh_chart() -> void:
	var portfolio: Dictionary = ProfileManager.get_portfolio()
	var history: Array = ProfileManager.get_run_history()
	var curve: Array = PortfolioAccountScript.equity_curve(
		history,
		int(portfolio.get("account_balance_cents", 0))
	)
	_chart.call("set_equity", curve, int(portfolio.get("account_ath_cents", 0)))


func _last_settled(history: Array) -> Dictionary:
	for entry_raw in history:
		if typeof(entry_raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_raw
		if bool(entry.get("assisted", false)):
			continue
		if str(entry.get("settlement_status", "")) == "assisted_non_ranked":
			continue
		return entry
	return {}

extends PanelContainer

## Right-side HODL Index ticker + candlestick chart.

const ChartScript := preload("res://ui/components/hodl_candlestick_chart.gd")
const MoneyDisplayScript := preload("res://scripts/app/money_display.gd")

var _title: Label
var _ticker: Label
var _delta: Label
var _session: Label
var _chart: Control
var _last_index: float = 100.0
var _game: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()


func bind_game(game: Node) -> void:
	_game = game
	_refresh_session()


func apply_index(value: float, _snapshot: Dictionary = {}) -> void:
	if _ticker:
		_ticker.text = "%.1f" % value
	if _delta:
		var d := value - _last_index
		if absf(d) < 0.05:
			_delta.text = "0.0"
			_delta.add_theme_color_override("font_color", UiTokens.MUTED)
		elif d > 0.0:
			_delta.text = "+%.1f" % d
			_delta.add_theme_color_override("font_color", UiTokens.SUCCESS)
		else:
			_delta.text = "%.1f" % d
			_delta.add_theme_color_override("font_color", UiTokens.DANGER)
	_refresh_session()


func apply_candles(candles: Array, index: float) -> void:
	if _chart != null and _chart.has_method("set_market"):
		_chart.call("set_market", candles, index)
	var base := 100.0
	if not candles.is_empty():
		var last: Dictionary = candles[candles.size() - 1]
		if bool(last.get("is_live", false)):
			base = float(last.get("open", index))
		elif candles.size() >= 2:
			base = float((candles[candles.size() - 2] as Dictionary).get("close", index))
		else:
			base = float(last.get("open", index))
	_last_index = base
	apply_index(index)
	_refresh_session()


func _refresh_session() -> void:
	if _session == null:
		return
	_session.text = MoneyDisplayScript.session_name(_game)


func _build() -> void:
	add_theme_stylebox_override("panel", UiStyle.make_flat_style(UiTokens.PANEL, UiTokens.SURFACE_LINE, UiTokens.RADIUS_LG, 1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	_title = UiStyle.make_flat_label("HODL INDEX", 14, true)
	header.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_session = UiStyle.make_flat_label(MoneyDisplayScript.PRE_MARKET, 13, true)
	header.add_child(_session)

	var ticker_row := HBoxContainer.new()
	ticker_row.add_theme_constant_override("separation", 10)
	box.add_child(ticker_row)
	_ticker = UiStyle.make_flat_label("100.0", 28)
	_ticker.add_theme_color_override("font_color", UiTokens.TEXT)
	ticker_row.add_child(_ticker)
	_delta = UiStyle.make_flat_label("0.0", 16, true)
	ticker_row.add_child(_delta)

	_chart = ChartScript.new()
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart.custom_minimum_size = Vector2(240, 180)
	box.add_child(_chart)

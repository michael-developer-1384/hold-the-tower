extends Control

## Draws settled account equity as a step/area curve. No market candles.

const PAD := Vector4(78, 18, 14, 28) # left, top, right, bottom
const MoneyDisplayScript := preload("res://scripts/app/money_display.gd")
const PortfolioConfigScript := preload("res://scripts/economy/portfolio_config.gd")

var points: Array = []
var ath_cents: int = 0


func set_equity(p_points: Array, p_ath_cents: int = 0) -> void:
	points = p_points
	ath_cents = p_ath_cents
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	var plot := Rect2(
		PAD.x,
		PAD.y,
		maxf(rect.size.x - PAD.x - PAD.z, 8.0),
		maxf(rect.size.y - PAD.y - PAD.w, 8.0)
	)
	draw_rect(rect, Color(0.08, 0.09, 0.12, 1.0), true)
	_draw_grid(plot)
	var yr := _y_range()
	_draw_baseline(plot, yr)
	_draw_ath(plot, yr)
	_draw_curve(plot, yr)
	_draw_y_labels(plot, yr)


func _y_range() -> Vector2:
	var lo := float(ath_cents) if ath_cents > 0 else 0.0
	var hi := lo
	var has_value := ath_cents > 0
	for p_raw in points:
		if typeof(p_raw) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = p_raw
		var v := float(p.get("equity_cents", 0))
		if not has_value:
			lo = v
			hi = v
			has_value = true
		else:
			lo = minf(lo, v)
			hi = maxf(hi, v)
	if not has_value:
		lo = 0.0
		hi = float(PortfolioConfigScript.INITIAL_ACCOUNT_BALANCE_CENTS)
	var pad := maxf((hi - lo) * 0.12, 25000.0)
	lo = maxf(lo - pad, 0.0)
	hi += pad
	if hi - lo < 50000.0:
		hi = lo + 50000.0
	return Vector2(lo, hi)


func _y_to_px(plot: Rect2, yr: Vector2, value: float) -> float:
	var t := 0.0 if yr.y <= yr.x else (value - yr.x) / (yr.y - yr.x)
	return plot.position.y + plot.size.y * (1.0 - clampf(t, 0.0, 1.0))


func _x_to_px(plot: Rect2, index: int, count: int) -> float:
	if count <= 1:
		return plot.position.x + plot.size.x * 0.08
	return plot.position.x + plot.size.x * (float(index) / float(count - 1))


func _draw_grid(plot: Rect2) -> void:
	var line := Color(0.22, 0.25, 0.30, 0.55)
	for i in 5:
		var y := plot.position.y + plot.size.y * (float(i) / 4.0)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.position.x + plot.size.x, y), line, 1.0)
	draw_rect(plot, Color(0.28, 0.32, 0.38, 0.45), false, 1.0)


func _draw_y_labels(plot: Rect2, yr: Vector2) -> void:
	var font := ThemeDB.fallback_font
	for i in 5:
		var t := float(i) / 4.0
		var v := lerpf(yr.y, yr.x, t)
		var y := plot.position.y + plot.size.y * t
		draw_string(
			font,
			Vector2(4.0, y + 4.0),
			MoneyDisplayScript.usd_cents(int(round(v))),
			HORIZONTAL_ALIGNMENT_LEFT,
			PAD.x - 8.0,
			10,
			UiTokens.TEXT_DIM
		)


func _draw_baseline(plot: Rect2, yr: Vector2) -> void:
	if points.is_empty():
		return
	var open_cents := int(points[0].get("equity_cents", 0))
	var y := _y_to_px(plot, yr, float(open_cents))
	draw_dashed_line(
		Vector2(plot.position.x, y),
		Vector2(plot.position.x + plot.size.x, y),
		Color(0.92, 0.94, 0.96, 0.22),
		1.0,
		6.0
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(plot.position.x + 6.0, y - 4.0),
		"START %s" % MoneyDisplayScript.usd_cents(open_cents),
		HORIZONTAL_ALIGNMENT_LEFT,
		180.0,
		10,
		UiTokens.TEXT_DIM
	)


func _draw_ath(plot: Rect2, yr: Vector2) -> void:
	if ath_cents <= 0:
		return
	if not points.is_empty() and ath_cents == int(points[0].get("equity_cents", -1)):
		return
	var y := _y_to_px(plot, yr, float(ath_cents))
	draw_dashed_line(
		Vector2(plot.position.x, y),
		Vector2(plot.position.x + plot.size.x, y),
		UiTokens.ACCENT.lerp(Color.WHITE, 0.2),
		1.0,
		8.0
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(plot.position.x + plot.size.x - 140.0, y - 4.0),
		"ATH %s" % MoneyDisplayScript.usd_cents(ath_cents),
		HORIZONTAL_ALIGNMENT_RIGHT,
		136.0,
		10,
		UiTokens.ACCENT
	)


func _draw_curve(plot: Rect2, yr: Vector2) -> void:
	var n := points.size()
	if n <= 0:
		return
	var coords: PackedVector2Array = PackedVector2Array()
	for i in n:
		coords.append(Vector2(_x_to_px(plot, i, n), _y_to_px(plot, yr, float(points[i].get("equity_cents", 0)))))
	if n >= 2:
		var fill: PackedVector2Array = PackedVector2Array()
		var floor_y := plot.position.y + plot.size.y
		fill.append(Vector2(coords[0].x, floor_y))
		fill.append_array(coords)
		fill.append(Vector2(coords[n - 1].x, floor_y))
		draw_colored_polygon(fill, Color(UiTokens.ACCENT.r, UiTokens.ACCENT.g, UiTokens.ACCENT.b, 0.16))
	for i in range(1, n):
		var pnl := int(points[i].get("pnl_cents", 0))
		var col := UiTokens.MUTED
		if pnl > 0:
			col = UiTokens.SUCCESS
		elif pnl < 0:
			col = UiTokens.DANGER
		draw_line(coords[i - 1], coords[i], col, 2.0)
	var font := ThemeDB.fallback_font
	for i in n:
		var p: Dictionary = points[i]
		var pos := coords[i]
		var pnl := int(p.get("pnl_cents", 0))
		var col := UiTokens.TEXT
		if not bool(p.get("is_open", false)):
			if pnl > 0:
				col = UiTokens.SUCCESS
			elif pnl < 0:
				col = UiTokens.DANGER
		draw_circle(pos, 3.5 if i == n - 1 else 2.5, col)
		var x_label := "OPEN" if bool(p.get("is_open", false)) else "S%d" % i
		draw_string(
			font,
			Vector2(pos.x - 18.0, plot.position.y + plot.size.y + 16.0),
			x_label,
			HORIZONTAL_ALIGNMENT_CENTER,
			36.0,
			10,
			UiTokens.TEXT_DIM
		)
	var last: Dictionary = points[n - 1]
	var tag := MoneyDisplayScript.usd_cents(int(last.get("equity_cents", 0)))
	draw_string(
		font,
		Vector2(coords[n - 1].x - 72.0, coords[n - 1].y - 8.0),
		tag,
		HORIZONTAL_ALIGNMENT_RIGHT,
		70.0,
		11,
		UiTokens.TEXT
	)

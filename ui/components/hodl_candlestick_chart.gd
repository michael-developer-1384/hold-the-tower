extends Control

## Draws OHLC candles from plain dictionaries. No market math.

const MIN_SPAN := 20.0
const PAD := Vector4(44, 18, 14, 28) # left, top, right, bottom

var candles: Array = []
var current_index: float = 100.0


func set_market(p_candles: Array, p_index: float) -> void:
	candles = p_candles
	current_index = p_index
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
	_draw_index_line(plot, yr)
	_draw_candles(plot, yr)
	_draw_y_labels(plot, yr)


func _y_range() -> Vector2:
	var lo := current_index
	var hi := current_index
	for c in candles:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		lo = minf(lo, float(c.get("low", lo)))
		hi = maxf(hi, float(c.get("high", hi)))
	var span := maxf(hi - lo, MIN_SPAN)
	var mid := (hi + lo) * 0.5
	lo = clampf(mid - span * 0.5, 0.0, 100.0 - span)
	hi = clampf(lo + span, span, 100.0)
	lo = hi - span
	return Vector2(lo, hi)


func _y_to_px(plot: Rect2, yr: Vector2, value: float) -> float:
	var t := 0.0 if yr.y <= yr.x else (value - yr.x) / (yr.y - yr.x)
	return plot.position.y + plot.size.y * (1.0 - clampf(t, 0.0, 1.0))


func _draw_grid(plot: Rect2) -> void:
	var line := Color(0.22, 0.25, 0.30, 0.55)
	for i in 5:
		var y := plot.position.y + plot.size.y * (float(i) / 4.0)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.position.x + plot.size.x, y), line, 1.0)
	draw_rect(plot, Color(0.28, 0.32, 0.38, 0.45), false, 1.0)


func _draw_y_labels(plot: Rect2, yr: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var fs := 11
	for i in 5:
		var t := float(i) / 4.0
		var v := lerpf(yr.y, yr.x, t)
		var y := plot.position.y + plot.size.y * t
		draw_string(
			font,
			Vector2(4.0, y + 4.0),
			"%.0f" % v,
			HORIZONTAL_ALIGNMENT_LEFT,
			PAD.x - 8.0,
			fs,
			UiTokens.TEXT_DIM
		)


func _draw_index_line(plot: Rect2, yr: Vector2) -> void:
	var y := _y_to_px(plot, yr, current_index)
	draw_line(
		Vector2(plot.position.x, y),
		Vector2(plot.position.x + plot.size.x, y),
		Color(0.92, 0.94, 0.96, 0.35),
		1.0
	)


func _draw_candles(plot: Rect2, yr: Vector2) -> void:
	var n := candles.size()
	if n <= 0:
		return
	var slot := plot.size.x / float(n)
	var body_w := clampf(slot * 0.55, 4.0, 18.0)
	var font := ThemeDB.fallback_font
	for i in n:
		var c: Dictionary = candles[i]
		var cx := plot.position.x + slot * (float(i) + 0.5)
		var o := float(c.get("open", 0.0))
		var h := float(c.get("high", o))
		var l := float(c.get("low", o))
		var cl := float(c.get("close", o))
		var up := cl >= o
		var col := UiTokens.SUCCESS if up else UiTokens.DANGER
		if bool(c.get("is_live", false)):
			col = col.lerp(Color.WHITE, 0.18)
		var y_h := _y_to_px(plot, yr, h)
		var y_l := _y_to_px(plot, yr, l)
		var y_o := _y_to_px(plot, yr, o)
		var y_c := _y_to_px(plot, yr, cl)
		draw_line(Vector2(cx, y_h), Vector2(cx, y_l), col, 1.2)
		var top := minf(y_o, y_c)
		var bot := maxf(y_o, y_c)
		var body_h := maxf(bot - top, 1.5)
		var body := Rect2(cx - body_w * 0.5, top, body_w, body_h)
		draw_rect(body, col, true)
		if bool(c.get("is_live", false)):
			draw_rect(body.grow(1.5), Color(0.92, 0.94, 0.96, 0.85), false, 1.2)
			draw_circle(Vector2(cx, y_c), 3.0, Color.WHITE)
		if slot >= 16.0:
			draw_string(
				font,
				Vector2(cx - slot * 0.45, plot.position.y + plot.size.y + 16.0),
				"W%d" % int(c.get("wave", i + 1)),
				HORIZONTAL_ALIGNMENT_CENTER,
				slot * 0.9,
				10,
				UiTokens.TEXT_DIM
			)

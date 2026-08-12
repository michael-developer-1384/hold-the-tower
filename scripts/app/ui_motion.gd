extends Node

## Central UI motion timings. Respects Reduced Motion.

const MICRO_MS := 110.0
const PAGE_MS := 220.0
const MODAL_MS := 180.0

var _reduced: bool = false


func _ready() -> void:
	if typeof(SettingsManager) != TYPE_NIL:
		_reduced = SettingsManager.reduced_motion()
		if not SettingsManager.settings_changed.is_connected(_on_settings):
			SettingsManager.settings_changed.connect(_on_settings)


func set_reduced_motion(enabled: bool) -> void:
	_reduced = enabled


func reduced_motion() -> bool:
	return _reduced


func micro_sec() -> float:
	return 0.02 if _reduced else MICRO_MS / 1000.0


func page_sec() -> float:
	return 0.08 if _reduced else PAGE_MS / 1000.0


func modal_sec() -> float:
	return 0.06 if _reduced else MODAL_MS / 1000.0


func tween_page_enter(node: CanvasItem) -> void:
	if node == null:
		return
	node.modulate.a = 0.0
	if _reduced:
		var t := create_tween()
		t.tween_property(node, "modulate:a", 1.0, page_sec())
		return
	if node is Control:
		var c := node as Control
		var base := c.position
		c.position = base + Vector2(0, 12)
		var t2 := create_tween()
		t2.set_parallel(true)
		t2.tween_property(c, "modulate:a", 1.0, page_sec())
		t2.tween_property(c, "position", base, page_sec()).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		var t3 := create_tween()
		t3.tween_property(node, "modulate:a", 1.0, page_sec())


func animate_progress(bar: ProgressBar, target: float) -> void:
	if bar == null:
		return
	if _reduced:
		bar.value = target
		return
	var t := create_tween()
	t.tween_property(bar, "value", target, page_sec()).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func count_number(label: Label, from_v: float, to_v: float, suffix: String = "", prefix: String = "") -> void:
	if label == null:
		return
	if _reduced:
		label.text = "%s%d%s" % [prefix, int(round(to_v)), suffix]
		return
	var state := {"v": from_v}
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		label.text = "%s%d%s" % [prefix, int(round(v)), suffix]
	, from_v, to_v, page_sec())
	state["v"] = to_v


func _on_settings(section: String) -> void:
	if section == "accessibility" and typeof(SettingsManager) != TYPE_NIL:
		_reduced = SettingsManager.reduced_motion()

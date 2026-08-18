extends Control

const Runner := preload("res://scripts/balance/balance_analysis_runner.gd")
const Ai := preload("res://scripts/balance/report/balance_ai_exporter.gd")
const Report := preload("res://scripts/balance/balance_report.gd")

var _status: Label
var _summary: Label
var _busy := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	box.add_child(UiStyle.make_section_label("BALANCE LAB"))
	box.add_child(UiStyle.label(
		"Designer analysis only. Combat numbers are not changed. Default run is isolated matrix + timing + ramp.",
		"caption",
		true
	))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(_btn("RUN ANALYSIS", _run_analysis))
	row.add_child(_btn("OPEN LATEST REPORT", _open_html))
	row.add_child(_btn("EXPORT AI JSON", _export_ai))
	row.add_child(_btn("COPY AI SUMMARY", _copy_summary))
	_status = UiStyle.label("Idle.", "body", true)
	box.add_child(_status)
	_summary = UiStyle.label("", "caption", true)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UiStyle._style_button(b, "ghost")
	b.pressed.connect(cb)
	return b


func _run_analysis() -> void:
	if _busy:
		return
	_busy = true
	_status.text = "Running isolated matrix + timing + ramp…"
	var out: Dictionary = await Runner.run(get_tree(), {
		"seed": 7,
		"difficulty_id": "normal",
		"level_id": "vertical_test",
	})
	_busy = false
	_status.text = "Wrote %s" % ProjectSettings.globalize_path(str(out.get("html_path", "")))
	var report: Dictionary = out.get("report", {})
	_summary.text = str(report.get("designer_summary", out.get("summary", "")))


func _open_html() -> void:
	var path := ProjectSettings.globalize_path(Runner.HTML_PATH)
	if not FileAccess.file_exists(Runner.HTML_PATH):
		_status.text = "No latest HTML report. Run analysis first."
		return
	OS.shell_open(path)
	_status.text = "Opened %s" % path


func _export_ai() -> void:
	var report := Runner.load_json(Runner.JSON_PATH)
	if report.is_empty():
		_status.text = "No latest JSON report. Run analysis first."
		return
	Report.write_json(Runner.AI_PATH, Ai.export(report))
	_status.text = "Exported %s" % ProjectSettings.globalize_path(Runner.AI_PATH)


func _copy_summary() -> void:
	var report := Runner.load_json(Runner.JSON_PATH)
	if report.is_empty():
		_status.text = "No latest JSON report. Run analysis first."
		return
	var text := "%s\n%s" % [ProjectSettings.globalize_path(Runner.AI_PATH), str(report.get("designer_summary", ""))]
	DisplayServer.clipboard_set(text)
	_status.text = "Copied AI summary."

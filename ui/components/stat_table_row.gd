extends HBoxContainer

## Label left, value right, optional delta. Presentation-aware.

@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel
@onready var _delta_label: Label = %DeltaLabel


func setup(stat_name: String, value: String, delta: String = "") -> void:
	if _name_label == null:
		_name_label = get_node_or_null("NameLabel") as Label
		_value_label = get_node_or_null("ValueLabel") as Label
		_delta_label = get_node_or_null("DeltaLabel") as Label
	if _name_label:
		_name_label.text = stat_name
	if _value_label:
		_value_label.text = value
	if _delta_label:
		_delta_label.text = delta
		_delta_label.visible = not delta.is_empty()


func setup_stat(stat_key: String, value: float, delta_from: float = NAN) -> void:
	var StatPresentationScript := preload("res://scripts/app/stat_presentation.gd")
	var label := StatPresentationScript.label(stat_key)
	var formatted := StatPresentationScript.format_value(stat_key, value)
	var delta := ""
	if not is_nan(delta_from):
		delta = StatPresentationScript.format_delta(stat_key, delta_from, value)
	setup(label, formatted, delta)
	var desc := StatPresentationScript.description(stat_key)
	if not desc.is_empty():
		tooltip_text = "%s\n\n%s" % [label, desc]

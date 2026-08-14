extends PanelContainer

## Roadmap node: completed / current / next / future.

const StatPresentationScript := preload("res://scripts/app/stat_presentation.gd")

enum State { COMPLETED, CURRENT, NEXT, FUTURE }

@onready var _level_label: Label = %LevelLabel
@onready var _state_label: Label = %StateLabel
@onready var _xp_label: Label = %XpLabel
@onready var _cap_label: Label = %CapLabel
@onready var _capacity_label: Label = %CapacityLabel
@onready var _extra_label: Label = %ExtraLabel


func setup(entry: Dictionary, current_level: int) -> void:
	_ensure_nodes()
	var lvl := int(entry.get("level", 1))
	var state := _state_for(lvl, current_level)
	_level_label.text = "LV %d" % lvl
	match state:
		State.CURRENT:
			_state_label.text = "CURRENT"
			_state_label.add_theme_color_override("font_color", UiTokens.ACCENT)
			_level_label.add_theme_color_override("font_color", UiTokens.ACCENT)
			UiStyle.style_card_panel(self, true, false)
			custom_minimum_size = Vector2(0, 148)
			size_flags_horizontal = Control.SIZE_EXPAND_FILL
			size_flags_stretch_ratio = 1.25
		State.NEXT:
			_state_label.text = "NEXT"
			_state_label.add_theme_color_override("font_color", UiTokens.COST)
			_level_label.add_theme_color_override("font_color", UiTokens.TEXT)
			UiStyle.style_card_panel(self, false, false)
			custom_minimum_size = Vector2(0, 140)
			size_flags_horizontal = Control.SIZE_EXPAND_FILL
			size_flags_stretch_ratio = 1.1
		State.COMPLETED:
			_state_label.text = "DONE"
			_state_label.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
			_level_label.add_theme_color_override("font_color", UiTokens.MUTED)
			UiStyle.style_card_panel(self, false, false)
			modulate = Color(0.85, 0.85, 0.88, 0.92)
			custom_minimum_size = Vector2(0, 120)
			size_flags_horizontal = Control.SIZE_EXPAND_FILL
			size_flags_stretch_ratio = 0.9
		State.FUTURE:
			_state_label.text = "LOCKED"
			_state_label.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
			_level_label.add_theme_color_override("font_color", UiTokens.TEXT_DIM)
			UiStyle.style_card_panel(self, false, true)
			custom_minimum_size = Vector2(0, 120)
			size_flags_horizontal = Control.SIZE_EXPAND_FILL
			size_flags_stretch_ratio = 0.85

	_xp_label.text = "%d XP" % int(entry.get("xp_required", 0))
	_cap_label.text = "Cap %s" % str(entry.get("research_cap_label", "?"))
	# Compact but named: Sentry/Guard capacities in RP (all states).
	_capacity_label.text = "%d / %d / %d RP" % [
		int(entry.get("sentry_capacity", 0)),
		int(entry.get("guard_capacity", 0)),
		int(entry.get("lava_capacity", 0)),
	]
	_capacity_label.tooltip_text = "%s %d RP  ·  %s %d RP  ·  %s %d RP" % [
		StatPresentationScript.display_tower("basic_tower"),
		int(entry.get("sentry_capacity", 0)),
		StatPresentationScript.display_tower("guard_post"),
		int(entry.get("guard_capacity", 0)),
		StatPresentationScript.display_tower("lava_tower"),
		int(entry.get("lava_capacity", 0)),
	]
	var extras: Array = entry.get("placeholder_unlocks", [])
	if extras.is_empty():
		_extra_label.visible = false
	else:
		_extra_label.visible = true
		_extra_label.text = str(extras[0])


func _state_for(lvl: int, current_level: int) -> int:
	if lvl < current_level:
		return State.COMPLETED
	if lvl == current_level:
		return State.CURRENT
	if lvl == current_level + 1:
		return State.NEXT
	return State.FUTURE


func _ensure_nodes() -> void:
	if _level_label == null:
		_level_label = %LevelLabel
		_state_label = %StateLabel
		_xp_label = %XpLabel
		_cap_label = %CapLabel
		_capacity_label = %CapacityLabel
		_extra_label = %ExtraLabel

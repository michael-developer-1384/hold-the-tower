extends Button

## Play Setup level row. Data-bound; layout is the Button itself in the scene.

signal level_selected(level_id: String)

var level_id: String = ""


func setup(level: Dictionary, placeholder: bool, unlocked: bool) -> void:
	level_id = str(level.get("id", ""))
	var display_name := str(level.get("display_name", level_id))
	var status := "COMING SOON" if placeholder else ("UNLOCKED" if unlocked else "LOCKED")
	text = "%s\n%s" % [display_name, status]
	disabled = placeholder or not unlocked
	add_theme_font_size_override("font_size", UiTokens.FONT_BODY)
	UiStyle.style_tab_button(self, false)
	if unlocked and not placeholder and not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func set_active(active: bool) -> void:
	button_pressed = active
	UiStyle.style_tab_button(self, active)


func _on_pressed() -> void:
	level_selected.emit(level_id)

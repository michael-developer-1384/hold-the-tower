extends Control

const UiStyleScript := preload("res://scripts/app/ui_style.gd")
const AppRouterScript := preload("res://scripts/app/app_router.gd")


func _ready() -> void:
	UiStyleScript.apply_root(self)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := UiStyleScript.make_panel()
	panel.custom_minimum_size = Vector2(420, 360)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	vbox.add_child(UiStyleScript.make_title("HODL THE TOWER", 40))
	vbox.add_child(UiStyleScript.make_label("Ridiculously serious tower defense.", 14, true))

	var rp := UiStyleScript.make_flat_label(
		"LV %d   RP %d" % [ProfileManager.get_player_level(), ProfileManager.get_research_points()],
		18
	)
	rp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rp)

	var play_btn := UiStyleScript.make_button("PLAY")
	play_btn.pressed.connect(func() -> void: AppRouterScript.go_play(get_tree()))
	vbox.add_child(play_btn)

	var gallery_btn := UiStyleScript.make_button("GALLERY")
	gallery_btn.pressed.connect(func() -> void: AppRouterScript.go_gallery(get_tree()))
	vbox.add_child(gallery_btn)

	var quit_btn := UiStyleScript.make_button("QUIT")
	quit_btn.pressed.connect(func() -> void: AppRouterScript.quit_game(get_tree()))
	vbox.add_child(quit_btn)

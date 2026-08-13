extends CanvasLayer

const AppRouterScript := preload("res://scripts/app/app_router.gd")

var sim = null
var playback = null
var package: Dictionary = {}
var overlays = null
var _filter: String = "ALL"
var _event_list: VBoxContainer
var _inspector: VBoxContainer
var _time_label: Label
var _slider: HSlider
var _play_btn: Button
var _speed_label: Label
var _filter_row: HBoxContainer
var _dragging: bool = false
var _selected_decision: Dictionary = {}
var _event_times: PackedFloat32Array = PackedFloat32Array()
var _last_highlight_t: float = -1.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func bind(p_sim, p_playback, pkg: Dictionary, p_overlays) -> void:
	sim = p_sim
	playback = p_playback
	package = pkg
	overlays = p_overlays
	if playback:
		playback.time_changed.connect(_on_time)
		playback.playing_changed.connect(_on_playing)
		playback.speed_changed.connect(func(s): _speed_label.text = _speed_text(s))
	var sel = get_parent().get_node_or_null("SelectionManager")
	if sel != null:
		if sel.has_signal("tower_selection_changed"):
			sel.tower_selection_changed.connect(_on_tower)
		if sel.has_signal("enemy_selection_changed"):
			sel.enemy_selection_changed.connect(_on_enemy)
	_rebuild_events()
	_show_overview()
	_on_time(sim.clock.sim_time if sim and sim.clock else 0.0)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	UiStyle.apply_theme(root)

	var left := _panel(Vector2(280, 0))
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_right = 300
	left.offset_left = 12
	left.offset_top = 12
	left.offset_bottom = -88
	root.add_child(left)
	var left_box := VBoxContainer.new()
	left.add_child(left_box)
	left_box.add_child(UiStyle.make_section_label("EVENTS"))
	_filter_row = HBoxContainer.new()
	_filter_row.add_theme_constant_override("separation", 4)
	left_box.add_child(_filter_row)
	_add_filter_button("ALL")
	_add_filter_button("AGENT")
	_add_filter_button("BUILD")
	_add_filter_button("WAVE")
	_add_filter_button("LEAK")
	_add_filter_button("KILL")
	_add_filter_button("GUARD")
	var escroll := ScrollContainer.new()
	escroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	escroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_box.add_child(escroll)
	_event_list = VBoxContainer.new()
	_event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	escroll.add_child(_event_list)

	var right := _panel(Vector2(320, 0))
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -332
	right.offset_right = -12
	right.offset_top = 12
	right.offset_bottom = -88
	root.add_child(right)
	var rscroll := ScrollContainer.new()
	rscroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rscroll)
	_inspector = VBoxContainer.new()
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.add_child(_inspector)

	var bottom := _panel(Vector2(0, 76))
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -80
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_bottom = -8
	root.add_child(bottom)
	var brow := VBoxContainer.new()
	bottom.add_child(brow)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	brow.add_child(controls)
	var back := UiStyle.make_compact_button("BACK", 72, 32, "ghost")
	back.pressed.connect(func() -> void:
		var host = get_parent()
		if host != null and host.has_method("_leave"):
			host.call("_leave")
		else:
			AppRouterScript.leave_watch(get_tree())
	)
	controls.add_child(back)
	_play_btn = UiStyle.make_compact_button("PLAY", 72, 32, "primary")
	_play_btn.pressed.connect(func() -> void:
		if playback:
			playback.toggle()
	)
	controls.add_child(_play_btn)
	for spec in [["-EVT", -1], ["+EVT", 1]]:
		var eb := UiStyle.make_compact_button(str(spec[0]), 56, 32, "secondary")
		var d: int = int(spec[1])
		eb.pressed.connect(func() -> void:
			if playback:
				playback.jump_event(d)
		)
		controls.add_child(eb)
	for spec2 in [["+1", 1], ["+10", 10]]:
		var tb := UiStyle.make_compact_button(str(spec2[0]), 48, 32, "secondary")
		var n: int = int(spec2[1])
		tb.pressed.connect(func() -> void:
			if playback:
				playback.step_ticks(n)
		)
		controls.add_child(tb)
	var s1 := UiStyle.make_compact_button("+1s", 48, 32, "secondary")
	s1.pressed.connect(func() -> void:
		if playback:
			playback.step_seconds(1.0)
	)
	controls.add_child(s1)
	for sp in [0.25, 1.0, 2.0, 10.0, 40.0]:
		var sb := UiStyle.make_compact_button("%s×" % str(sp), 52, 32, "ghost")
		var sv: float = float(sp)
		sb.pressed.connect(func() -> void:
			if playback:
				playback.set_speed(sv)
		)
		controls.add_child(sb)
	var mx := UiStyle.make_compact_button("MAX", 52, 32, "ghost")
	mx.pressed.connect(func() -> void:
		if playback:
			playback.set_max_speed()
	)
	controls.add_child(mx)
	_speed_label = UiStyle.make_flat_label("1×", UiTokens.FONT_BODY, true)
	controls.add_child(_speed_label)
	_time_label = UiStyle.make_flat_label("0.00 / 0.00", UiTokens.FONT_DATA, false)
	controls.add_child(_time_label)
	var dbg := CheckBox.new()
	dbg.text = "WORLD DEBUG"
	dbg.pressed.connect(func() -> void:
		if overlays:
			overlays.set_world_debug(dbg.button_pressed)
	)
	controls.add_child(dbg)
	var sc := CheckBox.new()
	sc.text = "SHOW ACTION SCORES"
	sc.pressed.connect(func() -> void:
		if overlays:
			overlays.set_show_scores(sc.button_pressed)
	)
	controls.add_child(sc)
	var aud := CheckBox.new()
	aud.text = "AUDIO"
	aud.button_pressed = true
	aud.pressed.connect(func() -> void:
		if playback:
			playback.set_audio_override(1 if aud.button_pressed else -1)
	)
	controls.add_child(aud)
	_slider = HSlider.new()
	_slider.min_value = 0
	_slider.max_value = 1
	_slider.step = 0.01
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.drag_started.connect(func() -> void:
		_dragging = true
		if playback:
			playback.begin_scrub()
	)
	_slider.value_changed.connect(func(v: float) -> void:
		if _dragging and playback:
			playback.preview_scrub(v)
	)
	_slider.drag_ended.connect(func(_changed: bool) -> void:
		_dragging = false
		if playback:
			playback.end_scrub(_slider.value)
	)
	brow.add_child(_slider)


func _panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	UiStyle.style_card_panel(p)
	return p


func _on_time(t: float) -> void:
	var dur := float(package.get("metrics", {}).get("duration", 1.0))
	_slider.max_value = maxf(dur, 0.1)
	if not _dragging:
		_slider.set_value_no_signal(t)
	_time_label.text = "%.2f / %.2f" % [t, dur]
	if _last_highlight_t < 0.0 or absf(t - _last_highlight_t) >= 0.05:
		_last_highlight_t = t
		_update_event_highlights(t)


func _on_playing(on: bool) -> void:
	_play_btn.text = "PAUSE" if on else "PLAY"


func _speed_text(s: float) -> String:
	return "%s×" % str(s)


func _rebuild_events() -> void:
	if _event_list == null:
		return
	for c in _event_list.get_children():
		_event_list.remove_child(c)
		c.free()
	_event_times = PackedFloat32Array()
	var t: float = 0.0
	if sim != null and sim.clock != null:
		t = float(sim.clock.sim_time)
	for e in package.get("event_log", []):
		var ev: Dictionary = e
		var event_name: String = str(ev.get("event", ""))
		if not _pass_filter(event_name):
			continue
		var et: float = float(ev.get("time", 0.0))
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%.1f  %s" % [et, _event_label(ev)]
		row.pressed.connect(func() -> void:
			_inspect_event(ev)
			if playback:
				playback.seek_exact(float(ev.get("time", 0.0)))
		)
		UiStyle._style_button(row, "ghost")
		_event_list.add_child(row)
		_event_times.append(et)
	_update_event_highlights(t)


func _update_event_highlights(t: float) -> void:
	if _event_list == null:
		return
	var rows: Array = _event_list.get_children()
	var n: int = mini(rows.size(), _event_times.size())
	for i in n:
		var row: CanvasItem = rows[i]
		row.modulate = Color(1, 1, 1, 1) if float(_event_times[i]) <= t + 0.05 else Color(1, 1, 1, 0.45)


func _add_filter_button(filter_name: String) -> void:
	var b := UiStyle.make_compact_button(filter_name, 0, 26, "ghost")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		_filter = filter_name
		_rebuild_events()
	)
	_filter_row.add_child(b)


func _pass_filter(event_name: String) -> bool:
	match _filter:
		"AGENT":
			return event_name == "agent_decision"
		"BUILD":
			return event_name in ["tower_built", "tower_upgraded", "tower_selected"]
		"WAVE":
			return event_name.begins_with("wave")
		"LEAK":
			return event_name in ["enemy_reached_core"]
		"KILL":
			return event_name in ["enemy_killed"]
		"GUARD":
			return event_name.contains("guard")
		_:
			return true


func _event_label(e: Dictionary) -> String:
	var event_name: String = str(e.get("event", ""))
	if event_name == "agent_decision":
		var a: Dictionary = e.get("action", {})
		return "AGENT  %s" % str(a.get("type", ""))
	return event_name


func _inspect_event(e: Dictionary) -> void:
	if str(e.get("event")) == "agent_decision":
		var did: int = int(e.get("decision_id", 0))
		for d in package.get("agent_decisions", []):
			var decision: Dictionary = d
			if int(decision.get("decision_id", 0)) == did:
				_show_decision(decision)
				return
	_clear_inspector()
	_inspector.add_child(UiStyle.make_section_label("EVENT"))
	_inspector.add_child(UiStyle.label(str(e), "data"))


func _show_overview() -> void:
	_clear_inspector()
	_inspector.add_child(UiStyle.make_section_label("RUN OVERVIEW"))
	var m: Dictionary = package.get("metrics", {})
	_inspector.add_child(UiStyle.make_stat_row("SEED", str(package.get("seed"))))
	_inspector.add_child(UiStyle.make_stat_row("AGENT", str(package.get("agent_id"))))
	_inspector.add_child(UiStyle.make_stat_row("PROFILE", str(package.get("player_profile", ""))))
	_inspector.add_child(UiStyle.make_stat_row("RESULT", "WIN" if bool(m.get("won")) else "LOSS"))
	var beh: Dictionary = m.get("behavior", {})
	if not beh.is_empty():
		_inspector.add_child(UiStyle.make_stat_row("BEST %", "%.0f%%" % (float(beh.get("best_action_rate", 0.0)) * 100.0)))
		_inspector.add_child(UiStyle.make_stat_row("AVG REGRET", "%.2f" % float(beh.get("average_decision_regret", 0.0))))
	_inspector.add_child(UiStyle.make_stat_row("CORE", str(m.get("lives_remaining"))))
	_inspector.add_child(UiStyle.make_stat_row("KILLS", str(m.get("enemies_killed"))))
	_inspector.add_child(UiStyle.make_stat_row("LEAKS", str(m.get("enemies_leaked"))))
	_inspector.add_child(UiStyle.make_stat_row("DAMAGE", "%.0f" % float(m.get("total_damage", 0.0))))
	_inspector.add_child(UiStyle.make_stat_row("DURATION", "%.1fs" % float(m.get("duration", 0.0))))


func _show_decision(d: Dictionary) -> void:
	_selected_decision = d
	_clear_inspector()
	_inspector.add_child(UiStyle.make_section_label("%s · %s  DECISION #%s" % [
		str(package.get("agent_id", "AGENT")).to_upper(),
		str(package.get("player_profile", "")).to_upper(),
		str(d.get("decision_id")),
	]))
	_inspector.add_child(UiStyle.make_stat_row("TIME", "%.2f" % float(d.get("time", 0.0))))
	var st: Dictionary = d.get("state_summary", {})
	if not st.is_empty():
		_inspector.add_child(UiStyle.label("gold %s  core %s  wave %s  towers %s  enemies %s" % [
			str(st.get("gold")), str(st.get("core_hp")), str(st.get("wave")),
			str(st.get("towers")), str(st.get("enemies")),
		], "caption", true))
	var chosen: Dictionary = d.get("action", {})
	var rank := int(d.get("chosen_rank", 1))
	var nopt := int(d.get("option_count", 0))
	var regret := float(d.get("score_gap", 0.0))
	var best_a: Dictionary = d.get("best_action", {})
	if rank <= 1 and regret <= 0.05:
		_inspector.add_child(UiStyle.label("BEST ACTION CHOSEN", "label"))
	else:
		_inspector.add_child(UiStyle.label("SUBOPTIMAL · RANK %d · REGRET %.1f" % [rank, regret], "label"))
	_inspector.add_child(UiStyle.make_stat_row("CHOSEN", "%s  %s" % [str(chosen.get("type")), _action_detail(chosen)]))
	_inspector.add_child(UiStyle.make_stat_row("RANK", "#%d of %d" % [rank, maxi(nopt, 1)]))
	_inspector.add_child(UiStyle.make_stat_row("BEST", "%s  %s" % [str(best_a.get("type", "")), _action_detail(best_a)]))
	_inspector.add_child(UiStyle.make_stat_row("CHOSEN SCORE", "%.1f" % float(d.get("chosen_score", d.get("score", 0.0)))))
	_inspector.add_child(UiStyle.make_stat_row("BEST SCORE", "%.1f" % float(d.get("best_score", 0.0))))
	_inspector.add_child(UiStyle.make_stat_row("REGRET", "%.1f" % regret))
	var bd: Dictionary = d.get("breakdown", {})
	if not bd.is_empty():
		_inspector.add_child(UiStyle.make_section_label("BREAKDOWN"))
		for k in bd.keys():
			if k == "total":
				continue
			_inspector.add_child(UiStyle.make_stat_row(str(k), str(bd[k])))
	var considered: Array = d.get("actions_considered", [])
	if not considered.is_empty():
		_inspector.add_child(UiStyle.make_section_label("OPTIONS"))
		for item in considered:
			var a: Dictionary = item.get("action", {})
			_inspector.add_child(UiStyle.label("%.1f  %s  %s" % [
				float(item.get("score", 0.0)), str(a.get("type")), _action_detail(a)
			], "data"))
	var look: Dictionary = d.get("lookahead", {})
	if not look.is_empty():
		_inspector.add_child(UiStyle.make_section_label("LOOKAHEAD"))
		_inspector.add_child(UiStyle.label(str(look), "caption", true))


func _action_detail(a: Dictionary) -> String:
	var bits: PackedStringArray = []
	for k in ["spot_id", "tower_type", "runtime_id"]:
		if str(a.get(k, "")) != "":
			bits.append(str(a.get(k)))
	return " ".join(bits)


func _on_tower(tower: Node3D) -> void:
	if tower == null:
		return
	_clear_inspector()
	_inspector.add_child(UiStyle.make_section_label("TOWER"))
	_inspector.add_child(UiStyle.make_stat_row("ID", str(tower.get("runtime_id"))))
	_inspector.add_child(UiStyle.make_stat_row("TYPE", str(tower.get("tower_type"))))
	_inspector.add_child(UiStyle.make_stat_row("FLOOR", str(tower.get("floor_id"))))
	if tower.has_method("get_ui_stat_lines"):
		for line in tower.call("get_ui_stat_lines"):
			_inspector.add_child(UiStyle.label(str(line), "data"))
	for k in ["damage_dealt", "kills", "shots_fired", "hits", "level"]:
		if k in tower:
			_inspector.add_child(UiStyle.make_stat_row(k, str(tower.get(k))))


func _on_enemy(enemy: Node3D) -> void:
	if enemy == null:
		return
	_clear_inspector()
	_inspector.add_child(UiStyle.make_section_label("ENEMY"))
	if enemy.has_method("get_inspect_lines"):
		for line in enemy.call("get_inspect_lines"):
			_inspector.add_child(UiStyle.label(str(line), "data"))
	else:
		_inspector.add_child(UiStyle.make_stat_row("ID", str(enemy.get("runtime_id"))))
		_inspector.add_child(UiStyle.make_stat_row("HP", "%.0f / %.0f" % [float(enemy.get("health")), float(enemy.get("max_health"))]))


func _clear_inspector() -> void:
	for c in _inspector.get_children():
		c.queue_free()

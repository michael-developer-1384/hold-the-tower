extends Control

const AppRouterScript := preload("res://scripts/app/app_router.gd")
const LevelCatalogScript := preload("res://scripts/meta/level_catalog.gd")
const DifficultyCatalogScript := preload("res://scripts/meta/difficulty_catalog.gd")

var _level_id: String = "vertical_test"
var _diff_id: String = "normal"
var _agent_id: String = "smart"
var _player_profile: String = "optimizer"
var _temp_override: bool = false
var _temp_value: float = 0.0
var _temp_label: Label
var _opt_hint: Label
var _seed: int = 1
var _runs: int = 5
var _lookahead: bool = false
var _speed: float = 40.0
var _record: String = "deep"
var _status: Label
var _list: VBoxContainer
var _inspect: VBoxContainer
var _compare: Label
var _sort: String = "seed"
var _rows: Array[Dictionary] = []
var _selected: Array[String] = []
var _busy: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.apply_theme(self)
	_build()
	_reload_index()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	margin.add_child(cols)

	var cfg := UiStyle.make_panel()
	cfg.custom_minimum_size = Vector2(280, 0)
	cols.add_child(cfg)
	var cfg_box := VBoxContainer.new()
	cfg.add_child(cfg_box)
	cfg_box.add_child(UiStyle.make_section_label("SIM LAB"))
	cfg_box.add_child(_labeled_option("LEVEL", _ids(LevelCatalogScript.all()), _level_id, func(v: String): _level_id = v))
	cfg_box.add_child(_labeled_option("DIFFICULTY", _ids(DifficultyCatalogScript.all()), _diff_id, func(v: String): _diff_id = v))
	cfg_box.add_child(_labeled_option("AGENT", ["random", "basic", "smart"], _agent_id, func(v: String): _agent_id = v))
	cfg_box.add_child(_labeled_option("PLAYER PROFILE", ["optimizer", "expert", "competent", "casual", "beginner"], _player_profile, func(v: String):
		_player_profile = v
		_refresh_profile_ui()
	))
	_temp_label = UiStyle.label("Temperature: 0.0", "caption", true)
	cfg_box.add_child(_temp_label)
	_opt_hint = UiStyle.label(
		"Deterministic decision policy. Multiple seeds only create different runs if gameplay RNG exists.",
		"caption",
		true
	)
	_opt_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cfg_box.add_child(_opt_hint)
	if OS.is_debug_build():
		var ov := CheckBox.new()
		ov.text = "OVERRIDE TEMPERATURE"
		ov.toggled.connect(func(on: bool) -> void:
			_temp_override = on
			_refresh_profile_ui()
		)
		cfg_box.add_child(ov)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 40
		spin.step = 0.1
		spin.value = 0
		spin.value_changed.connect(func(v: float) -> void:
			_temp_value = v
			if _temp_override:
				_temp_label.text = "Temperature: %.2f (override)" % v
		)
		cfg_box.add_child(spin)
	_refresh_profile_ui()
	cfg_box.add_child(_int_row("SEED", _seed, func(v: int): _seed = v))
	cfg_box.add_child(_int_row("RUNS", _runs, func(v: int): _runs = clampi(v, 1, 20)))
	cfg_box.add_child(_labeled_option("SPEED", ["1", "10", "40"], str(int(_speed)), func(v: String): _speed = float(v)))
	cfg_box.add_child(_labeled_option("RECORD", ["none", "summary", "replay", "deep"], _record, func(v: String): _record = v))
	var look := CheckBox.new()
	look.text = "LOOKAHEAD"
	look.button_pressed = _lookahead
	look.toggled.connect(func(on: bool) -> void: _lookahead = on)
	cfg_box.add_child(look)
	var run_btn := UiStyle.make_button("RUN", 40, "primary")
	run_btn.pressed.connect(_on_run)
	cfg_box.add_child(run_btn)
	_status = UiStyle.label("Ready.", "caption", true)
	cfg_box.add_child(_status)

	var mid := UiStyle.make_panel()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	var mid_box := VBoxContainer.new()
	mid.add_child(mid_box)
	var sort_row := HBoxContainer.new()
	mid_box.add_child(sort_row)
	sort_row.add_child(UiStyle.make_section_label("RUNS"))
	var sort_keys: PackedStringArray = ["seed", "result", "core", "duration"]
	for s in sort_keys:
		var sb := UiStyle.make_compact_button(s.to_upper(), 80, 28, "ghost")
		var key: String = s
		sb.pressed.connect(func() -> void:
			_sort = key
			_render_list()
		)
		sort_row.add_child(sb)
	var lib := UiStyle.make_compact_button("REFRESH", 80, 28, "secondary")
	lib.pressed.connect(_reload_index)
	sort_row.add_child(lib)
	var del := UiStyle.make_compact_button("DELETE", 80, 28, "danger")
	del.pressed.connect(_delete_selected)
	sort_row.add_child(del)
	var clr := UiStyle.make_compact_button("CLEAR", 80, 28, "danger")
	clr.pressed.connect(func() -> void:
		load("res://scripts/sim/replay/replay_store.gd").clear_all()
		_reload_index()
	)
	sort_row.add_child(clr)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var right := UiStyle.make_panel()
	right.custom_minimum_size = Vector2(340, 0)
	cols.add_child(right)
	var rbox := VBoxContainer.new()
	right.add_child(rbox)
	rbox.add_child(UiStyle.make_section_label("INSPECT / COMPARE"))
	var rscroll := ScrollContainer.new()
	rscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rbox.add_child(rscroll)
	_inspect = VBoxContainer.new()
	_inspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.add_child(_inspect)
	_compare = UiStyle.label("Select two runs, then COMPARE.", "caption", true)
	_compare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rbox.add_child(_compare)
	var cmp := UiStyle.make_button("COMPARE", 36, "secondary")
	cmp.pressed.connect(_on_compare)
	rbox.add_child(cmp)


func _ids(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		var row: Dictionary = e
		out.append(str(row.get("id")))
	return out


func _labeled_option(title: String, values: Array, current: String, on_pick: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_child(UiStyle.make_section_label(title))
	var opt := OptionButton.new()
	for v in values:
		var value: String = str(v)
		opt.add_item(value)
		if value == current:
			opt.select(opt.item_count - 1)
	opt.item_selected.connect(func(i: int) -> void: on_pick.call(opt.get_item_text(i)))
	box.add_child(opt)
	return box


func _int_row(title: String, value: int, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(UiStyle.make_flat_label(title, UiTokens.FONT_CAPTION, true))
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 999999
	spin.value = value
	spin.value_changed.connect(func(v: float) -> void: on_change.call(int(v)))
	row.add_child(spin)
	return row


func _on_run() -> void:
	if _busy:
		return
	_busy = true
	_status.text = "Running..."
	var Batch = load("res://scripts/sim/balance/batch_runner.gd")
	var tree := get_tree()
	var app := tree.current_scene
	var collected: Array = []
	for i in _runs:
		_status.text = "Running %d / %d" % [i + 1, _runs]
		var opts := {
			"level_id": _level_id,
			"difficulty_id": _diff_id,
			"agent_id": _agent_id,
			"player_profile": _player_profile,
			"seed": _seed + i,
			"time_scale": _speed,
			"lookahead": _lookahead,
			"record": _record,
		}
		if _temp_override:
			opts["temperature"] = _temp_value
			opts["temperature_overridden"] = true
		var r: Dictionary = await Batch.run_one(tree, opts)
		collected.append(r)
		if app != null and is_instance_valid(app):
			tree.current_scene = app
	_busy = false
	var Diversity = load("res://scripts/sim/balance/diversity.gd")
	var div: Dictionary = Diversity.summarize(collected)
	_status.text = "Done. %d run(s).  unique sequences %d  unique builds %d" % [
		collected.size(), int(div.get("unique_action_sequences", 0)), int(div.get("unique_final_builds", 0)),
	]
	if int(div.get("unique_action_sequences", 0)) <= 1 and collected.size() > 1:
		_status.text += "\nSeeds produced the same strategic run."
	_reload_index()


func _refresh_profile_ui() -> void:
	var Profile = load("res://scripts/sim/agents/player_profile.gd")
	var temperature: float = float(Profile.temperature_of(_player_profile))
	if _temp_override:
		_temp_label.text = "Temperature: %.2f (override)" % _temp_value
	else:
		_temp_label.text = "Temperature: %.2f" % temperature
	if _opt_hint:
		_opt_hint.visible = _player_profile == "optimizer"


func _batch_results_from_index() -> Array:
	var out: Array = []
	for pkg in _rows:
		var row: Dictionary = pkg
		out.append({
			"action_log": row.get("action_log", []),
			"seed": row.get("seed"),
			"replay_id": row.get("run_id"),
			"won": row.get("metrics", {}).get("won"),
			"lives_remaining": row.get("metrics", {}).get("lives_remaining"),
			"tower_stats": row.get("final_result", {}).get("tower_stats", []),
			"behavior": row.get("metrics", {}).get("behavior", {}),
		})
	return out


func _reload_index() -> void:
	_rows.clear()
	var Store = load("res://scripts/sim/replay/replay_store.gd")
	for item in Store.list_index():
		var pkg: Dictionary = Store.load_id(str(item.get("run_id")))
		if pkg.has("error"):
			continue
		_rows.append(pkg)
	_render_list()


func _render_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var rows: Array = _rows.duplicate()
	rows.sort_custom(_sort_fn)
	var Diversity = load("res://scripts/sim/balance/diversity.gd")
	var tag_map: Dictionary = Diversity.interesting_tags(_batch_results_from_index())
	for pkg in rows:
		var row: Dictionary = pkg
		_list.add_child(_make_row(row, tag_map))


func _sort_fn(a: Dictionary, b: Dictionary) -> bool:
	var ma: Dictionary = a.get("metrics", {})
	var mb: Dictionary = b.get("metrics", {})
	match _sort:
		"result":
			return int(ma.get("won", false)) > int(mb.get("won", false))
		"core":
			return int(ma.get("lives_remaining", 0)) > int(mb.get("lives_remaining", 0))
		"duration":
			return float(ma.get("duration", 0.0)) < float(mb.get("duration", 0.0))
		_:
			return int(a.get("seed", 0)) < int(b.get("seed", 0))


func _make_row(pkg: Dictionary, tag_map: Dictionary = {}) -> PanelContainer:
	var p := UiStyle.make_panel()
	var box := VBoxContainer.new()
	p.add_child(box)
	var m: Dictionary = pkg.get("metrics", {})
	var beh: Dictionary = m.get("behavior", {})
	var counts: Dictionary = _tower_counts(pkg)
	var title := "%s | %s | %s | %s | %s | %.0fs | %.0f%% | %.1f | %dS / %dG / %dL" % [
		str(pkg.get("seed")),
		str(pkg.get("agent_id", "?")),
		str(pkg.get("player_profile", "?")),
		"WIN" if bool(m.get("won")) else "LOSS",
		str(m.get("lives_remaining")),
		float(m.get("duration", 0.0)),
		float(beh.get("best_action_rate", 0.0)) * 100.0,
		float(beh.get("average_decision_regret", 0.0)),
		int(counts.get("basic_tower", 0)),
		int(counts.get("guard_post", 0)),
		int(counts.get("lava_tower", 0)),
	]
	box.add_child(UiStyle.label(title, "data"))
	var tags: PackedStringArray = _tags_for(pkg, tag_map)
	if not tags.is_empty():
		box.add_child(UiStyle.label("  ".join(tags), "caption", true))
	var actions := HBoxContainer.new()
	box.add_child(actions)
	var watch := UiStyle.make_compact_button("WATCH", 80, 28, "primary")
	watch.pressed.connect(func() -> void:
		AppRouterScript.go_watch(get_tree(), str(pkg.get("run_id")))
	)
	actions.add_child(watch)
	var insp := UiStyle.make_compact_button("INSPECT", 80, 28, "secondary")
	insp.pressed.connect(func() -> void: _show_inspect(pkg))
	actions.add_child(insp)
	var pick := CheckBox.new()
	pick.text = "COMPARE"
	pick.toggled.connect(func(on: bool) -> void:
		var id := str(pkg.get("run_id"))
		if on:
			if not _selected.has(id):
				_selected.append(id)
			while _selected.size() > 2:
				_selected.remove_at(0)
		else:
			_selected.erase(id)
	)
	pick.button_pressed = _selected.has(str(pkg.get("run_id")))
	actions.add_child(pick)
	return p


func _tower_counts(pkg: Dictionary) -> Dictionary:
	return load("res://scripts/sim/replay/replay_package.gd").tower_composition(pkg.get("final_result", {}))


func _show_inspect(pkg: Dictionary) -> void:
	for c in _inspect.get_children():
		c.queue_free()
	var m: Dictionary = pkg.get("metrics", {})
	_inspect.add_child(UiStyle.make_section_label("OVERVIEW"))
	_inspect.add_child(UiStyle.make_stat_row("RUN", str(pkg.get("run_id"))))
	_inspect.add_child(UiStyle.make_stat_row("SEED", str(pkg.get("seed"))))
	_inspect.add_child(UiStyle.make_stat_row("AGENT", str(pkg.get("agent_id"))))
	_inspect.add_child(UiStyle.make_stat_row("PROFILE", str(pkg.get("player_profile", ""))))
	_inspect.add_child(UiStyle.make_stat_row("RESULT", "WIN" if bool(m.get("won")) else "LOSS"))
	var beh: Dictionary = m.get("behavior", {})
	if not beh.is_empty():
		_inspect.add_child(UiStyle.make_stat_row("BEST %", "%.0f%%" % (float(beh.get("best_action_rate", 0.0)) * 100.0)))
		_inspect.add_child(UiStyle.make_stat_row("AVG REGRET", "%.2f" % float(beh.get("average_decision_regret", 0.0))))
	_inspect.add_child(UiStyle.make_stat_row("CORE", str(m.get("lives_remaining"))))
	_inspect.add_child(UiStyle.make_stat_row("KILLS", str(m.get("enemies_killed"))))
	_inspect.add_child(UiStyle.make_stat_row("DURATION", "%.1fs" % float(m.get("duration", 0.0))))
	var w := UiStyle.make_button("WATCH", 36, "primary")
	w.pressed.connect(func() -> void:
		AppRouterScript.go_watch(get_tree(), str(pkg.get("run_id")))
	)
	_inspect.add_child(w)


func _on_compare() -> void:
	if _selected.size() < 2:
		_compare.text = "Pick two runs with COMPARE."
		return
	var Store = load("res://scripts/sim/replay/replay_store.gd")
	var a: Dictionary = Store.load_id(str(_selected[0]))
	var b: Dictionary = Store.load_id(str(_selected[1]))
	if a.has("error") or b.has("error"):
		_compare.text = "Could not load one of the selected replays."
		return
	var Compare = load("res://scripts/sim/replay/replay_compare.gd")
	_compare.text = Compare.format_text(a, b)
	var ddiv: Dictionary = Compare.first_decision_divergence(a, b)
	var div: Dictionary = Compare.first_divergence(a.get("action_log", []), b.get("action_log", []))
	var ta := float(ddiv.get("time_a", div.get("time_a", 0.0)))
	var tb := float(ddiv.get("time_b", div.get("time_b", 0.0)))
	if bool(ddiv.get("found", false)) or bool(div.get("found", false)):
		var ja := UiStyle.make_compact_button("WATCH FROM HERE A", 140, 28, "primary")
		ja.pressed.connect(func() -> void:
			AppRouterScript.go_watch(get_tree(), str(a.get("run_id")), ta)
		)
		var jb := UiStyle.make_compact_button("WATCH FROM HERE B", 140, 28, "primary")
		jb.pressed.connect(func() -> void:
			AppRouterScript.go_watch(get_tree(), str(b.get("run_id")), tb)
		)
		_inspect.add_child(ja)
		_inspect.add_child(jb)


func _tags_for(pkg: Dictionary, tag_map: Dictionary = {}) -> PackedStringArray:
	var tags: PackedStringArray = []
	var key: String = str(pkg.get("run_id", pkg.get("seed", "")))
	for t in tag_map.get(key, []):
		if not tags.has(str(t)):
			tags.append(str(t))
	var Diversity = load("res://scripts/sim/balance/diversity.gd")
	var seq: String = Diversity.action_sequence(pkg.get("action_log", []))
	var copies := 0
	for other in _rows:
		var other_pkg: Dictionary = other
		if Diversity.action_sequence(other_pkg.get("action_log", [])) == seq:
			copies += 1
	if copies > 1 and not tags.has("STRATEGIC DUPLICATE"):
		tags.append("STRATEGIC DUPLICATE")
	return tags


func _delete_selected() -> void:
	var Store = load("res://scripts/sim/replay/replay_store.gd")
	for id in _selected:
		Store.delete_id(str(id))
	_selected.clear()
	_reload_index()

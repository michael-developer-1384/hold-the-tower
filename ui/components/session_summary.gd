extends PanelContainer

## Active session or last-run summary card.

const StatPresentationScript := preload("res://scripts/app/stat_presentation.gd")

@onready var _title: Label = %TitleLabel
@onready var _body: Label = %BodyLabel
@onready var _extra: Label = %ExtraLabel
@onready var _actions: HBoxContainer = %ActionsHost


func _ready() -> void:
	UiStyle.style_card_panel(self)


func setup_session(session: Dictionary) -> void:
	_ensure_nodes()
	_title.text = "ACTIVE SESSION"
	_body.text = StatPresentationScript.session_summary_line(session)
	_extra.visible = false


func setup_last_run(run: Dictionary) -> void:
	_ensure_nodes()
	_title.text = "LAST RUN"
	var result := "Victory" if str(run.get("result", "")) == "level_complete" else "Defeat"
	var level := StatPresentationScript.display_level(str(run.get("level_id", "?")))
	_body.text = "%s · %s" % [level, result]
	var rp := int(run.get("research_earned", 0))
	var xp := int(run.get("research_xp_earned", 0))
	if rp > 0 or xp > 0:
		_extra.text = "+%d RP · +%d XP" % [rp, xp]
		_extra.visible = true
	else:
		_extra.visible = false


func actions_host() -> HBoxContainer:
	_ensure_nodes()
	return _actions


func _ensure_nodes() -> void:
	if _title == null:
		_title = get_node_or_null("%TitleLabel") as Label
		_body = get_node_or_null("%BodyLabel") as Label
		_extra = get_node_or_null("%ExtraLabel") as Label
		_actions = get_node_or_null("%ActionsHost") as HBoxContainer

extends Node

## Central UI audio. Replace placeholder WAVs later without touching call sites.

enum Ev {
	FOCUS,
	ACCEPT,
	BACK,
	ERROR,
	MODAL,
	RESEARCH,
	REWARD,
	BOOT,
}

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"

var _players: Dictionary = {}
var _hover_cooldown: float = 0.0
var _ambient: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = BUS_MUSIC
	_ambient.volume_db = -28.0
	add_child(_ambient)
	_setup_player("focus", "res://audio/ui/ui_focus.wav", -10.0)
	_setup_player("accept", "res://audio/ui/ui_accept.wav", -6.0)
	_setup_player("back", "res://audio/ui/ui_back.wav", -8.0)
	_setup_player("error", "res://audio/ui/ui_error.wav", -4.0)
	_setup_player("modal", "res://audio/ui/ui_modal.wav", -8.0)
	_setup_player("research", "res://audio/ui/ui_research.wav", -6.0)
	_setup_player("reward", "res://audio/ui/ui_reward.wav", -5.0)
	_setup_player("boot", "res://audio/ui/ui_boot.wav", -4.0)
	if ResourceLoader.exists("res://audio/ui/ui_ambient.wav"):
		_ambient.stream = load("res://audio/ui/ui_ambient.wav")
	if typeof(SettingsManager) != TYPE_NIL:
		apply_volumes(SettingsManager.get_section("audio"))


func _process(delta: float) -> void:
	if _hover_cooldown > 0.0:
		_hover_cooldown = maxf(0.0, _hover_cooldown - delta)


func apply_volumes(audio: Dictionary) -> void:
	var muted := bool(audio.get("muted", false))
	_set_bus_volume(BUS_MASTER, 0.0 if muted else float(audio.get("master", 0.85)))
	_set_bus_volume(BUS_MUSIC, float(audio.get("music", 0.55)))
	_set_bus_volume(BUS_SFX, float(audio.get("sfx", 0.75)))
	_set_bus_volume(BUS_UI, float(audio.get("ui", 0.65)))


func play(ev: Ev) -> void:
	var key := _key(ev)
	if not _players.has(key):
		return
	if ev == Ev.FOCUS:
		if _hover_cooldown > 0.0:
			return
		_hover_cooldown = 0.045
	var p: AudioStreamPlayer = _players[key]
	if p.stream == null:
		return
	if p.playing:
		p.stop()
	p.play()


func play_focus() -> void:
	play(Ev.FOCUS)


func play_accept() -> void:
	play(Ev.ACCEPT)


func play_back() -> void:
	play(Ev.BACK)


func play_error() -> void:
	play(Ev.ERROR)


func play_modal() -> void:
	play(Ev.MODAL)


func play_research() -> void:
	play(Ev.RESEARCH)


func play_reward() -> void:
	play(Ev.REWARD)


func play_boot() -> void:
	play(Ev.BOOT)


func start_ambient() -> void:
	if _ambient and _ambient.stream and not _ambient.playing:
		_ambient.play()


func stop_ambient() -> void:
	if _ambient and _ambient.playing:
		_ambient.stop()


func _setup_player(key: String, path: String, volume_db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = BUS_UI
	p.volume_db = volume_db
	if ResourceLoader.exists(path):
		p.stream = load(path)
	add_child(p)
	_players[key] = p


func _key(ev: Ev) -> String:
	match ev:
		Ev.FOCUS:
			return "focus"
		Ev.ACCEPT:
			return "accept"
		Ev.BACK:
			return "back"
		Ev.ERROR:
			return "error"
		Ev.MODAL:
			return "modal"
		Ev.RESEARCH:
			return "research"
		Ev.REWARD:
			return "reward"
		Ev.BOOT:
			return "boot"
	return "focus"


func _ensure_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX, BUS_UI]:
		if AudioServer.get_bus_index(bus_name) < 0:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var v := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)

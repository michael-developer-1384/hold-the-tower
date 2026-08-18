class_name AppRouter
extends RefCounted

## Meta navigation. Shell hosts pages; gameplay is a full scene swap.

const APP_SCENE := "res://scenes/app.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const WATCH_SCENE := "res://scenes/sim/sim_watch.tscn"

const ROUTE_MAIN := "main"
const ROUTE_PLAY := "play"
const ROUTE_MARKET := "market"
const ROUTE_PROGRESSION := "progression"
const ROUTE_DATABASE := "database"
const ROUTE_TOWER_DETAIL := "tower_detail"
const ROUTE_ENEMY_DETAIL := "enemy_detail"
const ROUTE_SETTINGS := "settings"
const ROUTE_AFTER_ACTION := "after_action"
const ROUTE_SIM_LAB := "sim_lab"
const ROUTE_BALANCE_LAB := "balance_lab"

const PAGE_SCENES := {
	ROUTE_MAIN: "res://ui/pages/main_menu_page.tscn",
	ROUTE_PLAY: "res://ui/pages/play_setup_page.tscn",
	ROUTE_MARKET: "res://ui/pages/market_page.tscn",
	ROUTE_PROGRESSION: "res://ui/pages/progression_page.tscn",
	ROUTE_DATABASE: "res://ui/pages/database_page.tscn",
	ROUTE_TOWER_DETAIL: "res://ui/pages/tower_detail_page.tscn",
	ROUTE_ENEMY_DETAIL: "res://ui/pages/enemy_detail_page.tscn",
	ROUTE_SETTINGS: "res://ui/pages/settings_page.tscn",
	ROUTE_AFTER_ACTION: "res://ui/pages/after_action_page.tscn",
	ROUTE_SIM_LAB: "res://ui/pages/simulation_lab_page.tscn",
	ROUTE_BALANCE_LAB: "res://ui/pages/balance_lab_page.tscn",
}

static var pending_tower_id: String = ""
static var pending_enemy_id: String = ""
static var pending_gallery_mode: String = "towers"
static var pending_resume_session: bool = false
static var pending_route_on_boot: String = ROUTE_MAIN
static var pending_replay_id: String = ""
static var pending_seek_time: float = -1.0
static var _shell: Node = null


static func bind_shell(host: Node) -> void:
	_shell = host


static func shell() -> Node:
	return _shell


static func go_to(route: String, push: bool = true) -> void:
	if _shell != null and _shell.has_method("navigate"):
		_shell.call("navigate", route, push)
		return
	# Fallback before shell exists: boot into app with pending route.
	pending_route_on_boot = route


static func back() -> bool:
	if _shell != null and _shell.has_method("navigate_back"):
		return bool(_shell.call("navigate_back"))
	return false


static func go_main_menu(tree: SceneTree) -> void:
	pending_route_on_boot = ROUTE_MAIN
	tree.paused = false
	if str(tree.current_scene.scene_file_path) == APP_SCENE and _shell != null:
		go_to(ROUTE_MAIN, false)
		return
	tree.change_scene_to_file(APP_SCENE)


static func go_play(tree: SceneTree) -> void:
	_ensure_shell_or_boot(tree, ROUTE_PLAY)


static func go_progression(tree: SceneTree) -> void:
	_ensure_shell_or_boot(tree, ROUTE_PROGRESSION)


static func go_market(tree: SceneTree) -> void:
	_ensure_shell_or_boot(tree, ROUTE_MARKET)


static func go_gallery(tree: SceneTree, mode: String = "towers") -> void:
	pending_gallery_mode = mode
	_ensure_shell_or_boot(tree, ROUTE_DATABASE)


static func go_database(tree: SceneTree, mode: String = "towers") -> void:
	go_gallery(tree, mode)


static func go_detail(tree: SceneTree, tower_id: String) -> void:
	pending_tower_id = tower_id
	_ensure_shell_or_boot(tree, ROUTE_TOWER_DETAIL)


static func go_enemy_detail(tree: SceneTree, enemy_id: String) -> void:
	pending_enemy_id = enemy_id
	_ensure_shell_or_boot(tree, ROUTE_ENEMY_DETAIL)


static func go_settings(tree: SceneTree) -> void:
	_ensure_shell_or_boot(tree, ROUTE_SETTINGS)


static func go_game(tree: SceneTree, resume_session: bool = false) -> void:
	pending_resume_session = resume_session
	_shell = null
	tree.paused = false
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.stop_ambient()
	tree.change_scene_to_file(GAME_SCENE)


static func go_post_game(tree: SceneTree) -> void:
	pending_route_on_boot = ROUTE_AFTER_ACTION
	tree.paused = false
	tree.change_scene_to_file(APP_SCENE)


static func go_sim_lab(tree: SceneTree) -> void:
	_ensure_shell_or_boot(tree, ROUTE_SIM_LAB)


static func go_balance_lab(tree: SceneTree) -> void:
	_ensure_shell_or_boot(tree, ROUTE_BALANCE_LAB)


static func go_watch(tree: SceneTree, run_id: String, seek_time: float = -1.0) -> void:
	pending_replay_id = run_id
	pending_seek_time = seek_time
	pending_route_on_boot = ROUTE_SIM_LAB
	var pkg: Dictionary = load("res://scripts/sim/replay/replay_store.gd").load_id(run_id)
	var run_seed := int(pkg.get("seed", 0)) if not pkg.has("error") else 0
	var cfg: Dictionary = {}
	if not pkg.has("error"):
		cfg = pkg.get("simulation_config", {}).get("config", {})
	var SimContextScript = load("res://scripts/sim/sim_context.gd")
	SimContextScript.begin(run_seed, cfg if typeof(cfg) == TYPE_DICTIONARY else {})
	SimContextScript.presentation = true
	_shell = null
	tree.paused = false
	if typeof(UiAudio) != TYPE_NIL:
		UiAudio.stop_ambient()
	tree.change_scene_to_file(WATCH_SCENE)


static func leave_watch(tree: SceneTree) -> void:
	pending_route_on_boot = ROUTE_SIM_LAB
	tree.paused = false
	var SimContextScript = load("res://scripts/sim/sim_context.gd")
	if SimContextScript.active:
		SimContextScript.end()
	tree.change_scene_to_file(APP_SCENE)


static func quit_game(tree: SceneTree) -> void:
	tree.quit()


static func _ensure_shell_or_boot(tree: SceneTree, route: String) -> void:
	tree.paused = false
	if _shell != null:
		go_to(route, true)
		return
	pending_route_on_boot = route
	if tree.current_scene == null or str(tree.current_scene.scene_file_path) != APP_SCENE:
		tree.change_scene_to_file(APP_SCENE)
	else:
		# App scene loading; shell will consume pending_route_on_boot.
		pass

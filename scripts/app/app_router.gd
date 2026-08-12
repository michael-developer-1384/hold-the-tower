class_name AppRouter
extends RefCounted

const APP_SCENE := "res://scenes/app.tscn"
const PLAY_SCENE := "res://ui/play_menu.tscn"
const GALLERY_SCENE := "res://ui/tower_gallery.tscn"
const DETAIL_SCENE := "res://ui/tower_detail.tscn"
const POST_SCENE := "res://ui/post_game_stats.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

static var pending_tower_id: String = ""


static func go_main_menu(tree: SceneTree) -> void:
	tree.change_scene_to_file(APP_SCENE)


static func go_play(tree: SceneTree) -> void:
	tree.change_scene_to_file(PLAY_SCENE)


static func go_gallery(tree: SceneTree) -> void:
	tree.change_scene_to_file(GALLERY_SCENE)


static func go_detail(tree: SceneTree, tower_id: String) -> void:
	pending_tower_id = tower_id
	tree.change_scene_to_file(DETAIL_SCENE)


static func go_game(tree: SceneTree) -> void:
	tree.change_scene_to_file(GAME_SCENE)


static func go_post_game(tree: SceneTree) -> void:
	tree.change_scene_to_file(POST_SCENE)


static func quit_game(tree: SceneTree) -> void:
	tree.quit()

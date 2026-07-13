## 场景管理器模块
##
## 负责管理场景切换
## 作为全局单例使用

extends Node

## 场景路径常量
const LOGIN_SCENE: String = "res://scenes/login/login_scene.tscn"
const MAIN_SCENE: String = "res://scenes/main/main_scene.tscn"
const GAME_SCENE: String = "res://scenes/game/game_scene.tscn"

## 当前场景名称
var _current_scene: String = ""

## 信号：场景切换完成
signal scene_changed(scene_name: String)


## 切换到登录场景
func go_to_login() -> void:
	_change_scene(LOGIN_SCENE, "login")


## 切换到主界面场景
func go_to_main() -> void:
	_change_scene(MAIN_SCENE, "main")


## 切换到游戏场景
func go_to_game() -> void:
	_change_scene(GAME_SCENE, "game")


## 内部场景切换方法
func _change_scene(path: String, scene_name: String) -> void:
	_current_scene = scene_name
	var error = get_tree().change_scene_to_file(path)
	if error == OK:
		scene_changed.emit(scene_name)
	else:
		push_error("场景切换失败: " + path)


## 获取当前场景名称
func get_current_scene() -> String:
	return _current_scene


## 检查是否在指定场景
func is_current_scene(scene_name: String) -> bool:
	return _current_scene == scene_name

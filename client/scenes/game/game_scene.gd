## 游戏主场景脚本
##
## 负责游戏场景的初始化和管理
## 加载玩家数据并更新HUD显示

extends Node2D

## 节点引用
@onready var player: CharacterBody2D = $GameWorld/Player
@onready var hud: CanvasLayer = $UI/HUD

## 玩家数据
var _player_data: Dictionary = {}


func _ready() -> void:
	# 连接API信号
	ApiClient.request_completed.connect(_on_api_success)
	ApiClient.request_failed.connect(_on_api_error)

	# 加载玩家数据
	_load_player_data()


## 加载玩家数据
func _load_player_data() -> void:
	hud.set_status("加载玩家数据...")
	ApiClient.get_request(APIConfig.PLAYER_PROFILE, true)


## API请求成功回调
func _on_api_success(result: Dictionary) -> void:
	if result.has("nickname"):
		_player_data = result
		_update_game_display()
	else:
		hud.set_status("未知响应格式")


## 更新游戏显示
func _update_game_display() -> void:
	# 更新HUD
	hud.update_hud(_player_data)

	# 更新玩家节点
	player.set_player_data(_player_data)

	hud.set_status("游戏加载完成 - 使用WASD或方向键移动")


## API请求失败回调
func _on_api_error(error: String, status_code: int) -> void:
	if status_code == 401:
		hud.set_status("认证失败，返回登录...")
		TokenManager.clear_token()
		await get_tree().create_timer(2.0).timeout
		SceneManager.go_to_login()
		return

	hud.set_status("错误: " + error)


## 返回主界面
func _go_to_main() -> void:
	SceneManager.go_to_main()

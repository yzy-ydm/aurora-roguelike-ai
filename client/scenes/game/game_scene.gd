## 游戏主场景脚本
##
## 负责游戏场景的初始化和管理
## 加载玩家数据和游戏资源

extends Node2D

## 节点引用
@onready var player: CharacterBody2D = $GameWorld/Player
@onready var hud: CanvasLayer = $UI/HUD
@onready var resource_button: Button = $UI/MenuPanel/MenuButtons/ResourceButton
@onready var logout_button: Button = $UI/MenuPanel/MenuButtons/LogoutButton

## 玩家数据
var _player_data: Dictionary = {}


func _ready() -> void:
	# 连接按钮信号
	resource_button.pressed.connect(_on_resource_pressed)
	logout_button.pressed.connect(_on_logout_pressed)

	# 连接API信号
	ApiClient.request_completed.connect(_on_api_success)
	ApiClient.request_failed.connect(_on_api_error)

	# 连接资源服务信号
	ResourceService.all_resources_loaded.connect(_on_resources_loaded)
	ResourceService.resource_load_error.connect(_on_resource_error)

	# 加载玩家数据
	_load_player_data()

	# 开始加载游戏资源
	_load_game_resources()


## 加载玩家数据
func _load_player_data() -> void:
	hud.set_status("加载玩家数据...")
	ApiClient.get_request(APIConfig.PLAYER_PROFILE, true)


## 加载游戏资源
func _load_game_resources() -> void:
	ResourceService.load_all_resources()


## 资源加载完成回调
func _on_resources_loaded() -> void:
	_update_resource_display()
	hud.set_status("资源加载完成 - 使用WASD或方向键移动")


## 资源加载失败回调
func _on_resource_error(error: String) -> void:
	hud.set_status("资源加载失败: " + error)


## 更新资源显示
func _update_resource_display() -> void:
	hud.update_resource_counts(
		ResourceService.get_weapon_count(),
		ResourceService.get_monster_count(),
		ResourceService.get_map_count(),
		ResourceService.get_event_count()
	)


## API请求成功回调
func _on_api_success(result: Dictionary) -> void:
	if result.has("nickname"):
		_player_data = result
		_update_game_display()
	# 注意：数组类型的响应由ResourceService处理


## 更新游戏显示
func _update_game_display() -> void:
	# 更新HUD
	hud.update_hud(_player_data)

	# 更新玩家节点
	player.set_player_data(_player_data)


## API请求失败回调
func _on_api_error(error: String, status_code: int) -> void:
	if status_code == 401:
		hud.set_status("认证失败，返回登录...")
		TokenManager.clear_token()
		await get_tree().create_timer(2.0).timeout
		SceneManager.go_to_login()
		return

	hud.set_status("错误: " + error)


## 资源中心按钮
func _on_resource_pressed() -> void:
	SceneManager.go_to_resource_center()


## 退出登录按钮
func _on_logout_pressed() -> void:
	TokenManager.clear_token()
	SceneManager.go_to_login()

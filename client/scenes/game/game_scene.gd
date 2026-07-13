## 游戏主场景脚本
##
## 负责游戏场景的初始化和管理
## 集成GameStateManager进行状态管理
## 支持退出保存功能

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

	# 连接信号
	SaveService.save_saved.connect(_on_save_saved)
	SaveService.save_error.connect(_on_save_error)

	# 从GameStateManager获取玩家数据
	_player_data = GameStateManager.get_player_data()

	# 更新显示
	_update_game_display()

	# 更新资源显示
	_update_resource_display()

	# 更新游戏运行时间
	set_process(true)


## 每帧处理
func _process(delta: float) -> void:
	# 更新游戏运行时间
	GameStateManager.add_play_time(delta)


## 更新资源显示
func _update_resource_display() -> void:
	hud.update_resource_counts(
		ResourceService.get_weapon_count(),
		ResourceService.get_monster_count(),
		ResourceService.get_map_count(),
		ResourceService.get_event_count()
	)


## 更新游戏显示
func _update_game_display() -> void:
	# 更新HUD
	hud.update_hud(_player_data)

	# 更新玩家节点
	player.set_player_data(_player_data)

	hud.set_status("游戏进行中 - 使用WASD或方向键移动")


## 存档保存成功
func _on_save_saved(success: bool, message: String) -> void:
	if success:
		hud.set_status("存档保存成功")
	else:
		hud.set_status("存档保存失败: " + message)


## 存档保存错误
func _on_save_error(error: String) -> void:
	hud.set_status("存档保存错误: " + error)


## 资源中心按钮
func _on_resource_pressed() -> void:
	SceneManager.go_to_resource_center()


## 退出登录按钮（带保存）
func _on_logout_pressed() -> void:
	hud.set_status("正在保存游戏...")
	GameFlowController.exit_game()

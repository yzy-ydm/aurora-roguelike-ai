## 游戏主场景脚本
##
## 负责游戏场景的初始化和管理
## 集成世界系统、交互系统、暂停菜单、设置、存档选择功能

extends Node2D

## 节点引用
@onready var player: CharacterBody2D = $GameWorld/Player
@onready var world: Node2D = $GameWorld/World
@onready var interaction_detector: Area2D = $GameWorld/Player/InteractionDetector
@onready var interaction_manager: Node = $InteractionManager
@onready var hud: CanvasLayer = $UI/HUD
@onready var interaction_hint: CanvasLayer = $UI/InteractionHint
@onready var resource_button: Button = $UI/MenuPanel/MenuButtons/ResourceButton
@onready var logout_button: Button = $UI/MenuPanel/MenuButtons/LogoutButton
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var settings_menu: CanvasLayer = $SettingsMenu
@onready var save_selection: CanvasLayer = $SaveSelection

## 世界管理器
var _world_manager: Node = null

## 房间管理器
var _room_manager: Node = null

## 玩家数据
var _player_data: Dictionary = {}

## 暂停状态
var _is_paused: bool = false


func _ready() -> void:
	# 连接按钮信号
	resource_button.pressed.connect(_on_resource_pressed)
	logout_button.pressed.connect(_on_logout_pressed)

	# 连接暂停菜单信号
	pause_menu.resume_game.connect(_on_resume_game)
	pause_menu.open_settings.connect(_on_open_settings)
	pause_menu.exit_to_menu.connect(_on_exit_to_menu)

	# 连接设置菜单信号
	settings_menu.settings_closed.connect(_on_settings_closed)

	# 连接存档选择信号
	save_selection.save_selected.connect(_on_save_selected)
	save_selection.save_selection_closed.connect(_on_save_selection_closed)

	# 连接交互管理器信号
	interaction_manager.nearest_object_changed.connect(_on_nearest_object_changed)
	interaction_manager.interaction_triggered.connect(_on_interaction_triggered)

	# 设置交互检测器
	interaction_detector.set_interaction_manager(interaction_manager)

	# 从GameStateManager获取玩家数据
	_player_data = GameStateManager.get_player_data()

	# 初始化世界系统
	_init_world_system()

	# 更新显示
	_update_game_display()

	# 更新资源显示
	_update_resource_display()

	# 更新游戏运行时间
	set_process(true)


## 初始化世界系统
func _init_world_system() -> void:
	# 创建房间管理器
	_room_manager = Node.new()
	_room_manager.name = "RoomManager"
	_room_manager.set_script(load("res://scripts/world/room_manager.gd"))
	add_child(_room_manager)

	# 创建世界管理器
	_world_manager = Node.new()
	_world_manager.name = "WorldManager"
	_world_manager.set_script(load("res://scripts/world/world_manager.gd"))
	add_child(_world_manager)

	# 初始化世界管理器
	_world_manager.initialize(world, _room_manager)

	# 连接世界管理器信号
	_world_manager.world_initialized.connect(_on_world_initialized)
	_world_manager.world_load_error.connect(_on_world_load_error)
	_world_manager.room_changed.connect(_on_room_changed)

	# 加载世界
	_world_manager.load_world()

	# 进入第一个房间
	_world_manager.enter_first_room()


## 输入处理
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
	elif event.is_action_pressed("interaction"):
		_try_interact()


## 每帧处理
func _process(delta: float) -> void:
	# 更新游戏运行时间
	if not _is_paused:
		GameStateManager.add_play_time(delta)


## 切换暂停状态
func _toggle_pause() -> void:
	if _is_paused:
		_resume_game()
	else:
		_pause_game()


## 暂停游戏
func _pause_game() -> void:
	_is_paused = true
	get_tree().paused = true
	GameStateManager.set_state(GameStateManager.GameState.PAUSED)
	pause_menu.show_pause()
	hud.set_status("游戏暂停")


## 恢复游戏
func _resume_game() -> void:
	_is_paused = false
	get_tree().paused = false
	GameStateManager.set_state(GameStateManager.GameState.PLAYING)
	pause_menu.hide_pause()
	hud.set_status("游戏进行中")


## 尝试交互
func _try_interact() -> void:
	if _is_paused:
		return

	if interaction_manager.has_interactable():
		interaction_manager.trigger_interaction()


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
	hud.update_hud(_player_data)
	player.set_player_data(_player_data)
	hud.set_status("游戏进行中 - 按ESC暂停")


## 世界初始化完成
func _on_world_initialized() -> void:
	var map_data = _world_manager.get_current_map()
	if map_data:
		hud.set_status("世界加载完成: " + map_data.name)


## 世界加载错误
func _on_world_load_error(error: String) -> void:
	hud.set_status("世界加载失败: " + error)


## 房间切换
func _on_room_changed(room_data: RoomData) -> void:
	hud.set_status("当前房间: " + room_data.room_name + " (" + room_data.room_type + ")")


## 最近交互对象变化
func _on_nearest_object_changed(obj: Variant) -> void:
	if obj and obj is InteractiveObject:
		interaction_hint.show_hint(obj.interaction_hint)
	else:
		interaction_hint.hide_hint()


## 交互触发
func _on_interaction_triggered(object_id: int) -> void:
	var obj = interaction_manager.get_object(object_id)
	if obj:
		hud.set_status("交互: " + obj.object_name)
		# 完成交互
		interaction_manager.complete_interaction(object_id)


## 暂停菜单：继续游戏
func _on_resume_game() -> void:
	_resume_game()


## 暂停菜单：打开设置
func _on_open_settings() -> void:
	pause_menu.hide_pause()
	settings_menu.show_settings()


## 暂停菜单：退出到主菜单
func _on_exit_to_menu() -> void:
	pause_menu.hide_pause()
	save_selection.show_save_selection()


## 设置菜单：关闭
func _on_settings_closed() -> void:
	pause_menu.show_pause()


## 存档选择：选择存档槽位
func _on_save_selected(slot: int) -> void:
	var save_data = GameStateManager.get_save_data()
	SaveService.save_game(slot, save_data)
	await get_tree().create_timer(1.0).timeout
	_exit_to_menu()


## 存档选择：关闭
func _on_save_selection_closed() -> void:
	pause_menu.show_pause()


## 退出到主菜单
func _exit_to_menu() -> void:
	_is_paused = false
	get_tree().paused = false
	GameStateManager.set_state(GameStateManager.GameState.NOT_STARTED)
	SceneManager.go_to_main()


## 资源中心按钮
func _on_resource_pressed() -> void:
	SceneManager.go_to_resource_center()


## 退出登录按钮（带保存）
func _on_logout_pressed() -> void:
	hud.set_status("正在保存游戏...")
	GameFlowController.exit_game()

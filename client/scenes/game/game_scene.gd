## 游戏主场景脚本 (Phase 13)
##
## 职责:
## - 初始化FloorManager和CombatManager
## - 初始化升级系统和Boss系统
## - 初始化AI自适应系统
## - 连接信号
## - 管理UI更新
##
## 不再负责:
## - 房间生成(委托FloorManager)
## - 怪物生成(委托RoomSpawner)
## - 奖励生成(委托RoomSpawner)
## - 战斗状态(委托CombatManager)

extends Node2D

## ==================== 节点引用 ====================

@onready var player: CharacterBody2D = $GameWorld/Player
@onready var hud: CanvasLayer = $UI/HUD
@onready var interaction_hint: CanvasLayer = $UI/InteractionHint
@onready var interaction_manager: Node = $InteractionManager
@onready var interaction_detector: Area2D = $GameWorld/Player/InteractionDetector
@onready var resource_button: Button = $UI/MenuPanel/MenuButtons/ResourceButton
@onready var logout_button: Button = $UI/MenuPanel/MenuButtons/LogoutButton
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var settings_menu: CanvasLayer = $SettingsMenu
@onready var save_selection: CanvasLayer = $SaveSelection

## ==================== 核心系统 ====================

## 楼层管理器
var _floor_manager: Node = null

## 战斗管理器
var _combat_manager: Node = null

## 房间渲染器(FloorManager子模块)
var _room_renderer: Node = null

## 房间生成器(FloorManager子模块)
var _room_spawner: Node = null

## AI内容服务
var _ai_content_service: Node = null

## ==================== Phase 12 新增系统 ====================

## 升级管理器
var _upgrade_manager: Node = null

## Phase 18.2: _boss_controller 变量已废弃归档（声明后零使用）

## ==================== Phase 13 新增系统 ====================

## 行为分析器
var _behavior_analyzer: Node = null

## AI上下文管理器
var _ai_context_manager: Node = null

## NPC记忆管理器
var _npc_memory_manager: Node = null

## 数据统计管理器
var _analytics_manager: Node = null

## ==================== UI系统 ====================

var _inventory_manager: Node = null
var _equipment_manager: Node = null
var _object_manager: Node = null
var _damage_system: Node = null

## UI面板
var _level_up_panel: Node = null
var _boss_health_bar: Node = null

## ==================== 状态 ====================

var _player_data: Dictionary = {}
var _is_paused: bool = false

## GameOver面板
var _game_over_panel: CanvasLayer = null


## ==================== 初始化 ====================

func _ready() -> void:
	# 连接UI信号
	_connect_ui_signals()

	# 获取玩家数据
	_player_data = GameStateManager.get_player_data()

	# 初始化系统
	_init_ui_systems()
	# TASK-030: 游戏系统初始化含 AI 模式探测（await），保证第一个房间就有明确 AI MODE
	await _init_gameplay_systems()
	_init_progression_systems()
	_init_boss_system()
	# TASK-030: 本地 JSON 存档系统（save_system.gd）已删除——存档统一走 SaveService→服务端
	_init_ai_adaptive_systems()

	# 更新显示
	_update_game_display()
	set_process(true)

	# Phase 20.4: 在所有初始化完成后同步重置Camera
	_sync_camera_to_player()


## 同步Camera到Player位置
func _sync_camera_to_player() -> void:
	if not player:
		return

	# 获取Camera并强制同步（不覆盖玩家位置，位置由_on_fm_room_entered设置）
	var cam = player.get_node_or_null("Camera2D")
	if cam:
		cam.reset_smoothing()
		cam.force_update_scroll()


## 连接UI信号
func _connect_ui_signals() -> void:
	resource_button.pressed.connect(_on_resource_pressed)
	logout_button.pressed.connect(_on_logout_pressed)
	pause_menu.resume_game.connect(_on_resume_game)
	pause_menu.open_settings.connect(_on_open_settings)
	pause_menu.exit_to_menu.connect(_on_exit_to_menu)
	settings_menu.settings_closed.connect(_on_settings_closed)
	save_selection.save_selected.connect(_on_save_selected)
	save_selection.save_selection_closed.connect(_on_save_selection_closed)
	interaction_manager.nearest_object_changed.connect(_on_nearest_object_changed)
	interaction_manager.interaction_triggered.connect(_on_interaction_triggered)
	interaction_detector.set_interaction_manager(interaction_manager)

	# Phase 15: 连接玩家死亡信号
	if player.has_signal("player_dead"):
		player.player_dead.connect(_on_player_dead)

	# 连接玩家受伤信号，实时更新HUD
	if player.has_signal("player_damaged"):
		player.player_damaged.connect(_on_player_damaged)


## 初始化UI系统
func _init_ui_systems() -> void:
	# 背包系统
	_inventory_manager = Node.new()
	_inventory_manager.name = "InventoryManager"
	_inventory_manager.set_script(load("res://scripts/inventory/inventory_manager.gd"))
	add_child(_inventory_manager)

	_equipment_manager = Node.new()
	_equipment_manager.name = "EquipmentManager"
	_equipment_manager.set_script(load("res://scripts/inventory/equipment_manager.gd"))
	add_child(_equipment_manager)
	_equipment_manager.initialize(_inventory_manager)

	# 对象系统
	_object_manager = Node.new()
	_object_manager.name = "ObjectManager"
	_object_manager.set_script(load("res://scripts/object/object_manager.gd"))
	add_child(_object_manager)

	# 创建GameOver面板
	_create_game_over_panel()


## 创建GameOver面板（代码动态创建，不依赖tscn）
func _create_game_over_panel() -> void:
	_game_over_panel = CanvasLayer.new()
	_game_over_panel.name = "GameOverPanel"
	_game_over_panel.layer = 100  # 确保在最上层
	_game_over_panel.visible = false
	_game_over_panel.process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时仍可交互
	add_child(_game_over_panel)

	# 背景遮罩
	var overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_panel.add_child(overlay)

	# 居中容器
	var center = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_panel.add_child(center)

	# 面板
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(400, 300)
	center.add_child(panel)

	# 垂直布局
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# 标题
	var title = Label.new()
	title.name = "Title"
	title.text = "你已阵亡"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	# 信息
	var info = Label.new()
	info.name = "Info"
	info.text = "战斗失败..."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)

	# 按钮容器
	var buttons = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	vbox.add_child(buttons)

	# 重新开始按钮
	var restart_btn = Button.new()
	restart_btn.name = "RestartButton"
	restart_btn.text = "重新开始"
	restart_btn.custom_minimum_size = Vector2(150, 50)
	restart_btn.pressed.connect(_on_restart_pressed)
	buttons.add_child(restart_btn)

	# 返回主菜单按钮
	var menu_btn = Button.new()
	menu_btn.name = "MenuButton"
	menu_btn.text = "返回主菜单"
	menu_btn.custom_minimum_size = Vector2(150, 50)
	menu_btn.pressed.connect(_on_exit_to_menu)
	buttons.add_child(menu_btn)

	print("[GameScene] GameOverPanel created")


## 重新开始运行（不回主菜单）
## TASK-028: 全新 run —— 清空 run 临时状态、重建全新 PlayerStats、
## 重置武器为初始武器（旧实现 revive() 只回血，等级/金币/武器强化全部残留）
func restart_run() -> void:
	print("[GameScene] Restarting run...")

	# 隐藏GameOver面板
	if _game_over_panel:
		_game_over_panel.visible = false

	# 解除暂停
	_is_paused = false
	get_tree().paused = false

	# 1. 清空 run 临时状态（运行时统计/扩展数据/楼层/存档），保留 profile 基线
	GameStateManager.reset_run_state()

	# 2. Phase 18.2: 全新 run 基线 = 默认属性 + 账号昵称
	#    （禁止读取死亡时 PlayerStats，也禁止继承 profile 属性快照——
	#      重新开始必须是 level=1/exp=0/gold=0/hp=max_hp）
	if player:
		var baseline: Dictionary = {
			"nickname": GameStateManager.get_profile_data().get("nickname", "冒险者")
		}
		player.reset_stats_to(baseline)
		player.set_control_enabled(true)

	# 3. 武器重置为初始武器
	if player:
		player.reset_weapon_to_default()

	# 重新初始化战斗管理器
	if _combat_manager:
		_combat_manager.reset()

	# 清除当前房间的怪物和奖励
	if _room_spawner:
		_room_spawner.clear_monsters()
		_room_spawner.clear_rewards()

	# 重新生成楼层并进入第一个房间
	if _floor_manager:
		_floor_manager.generate_floor(1)

	# 更新显示
	_player_data = player.get_player_data() if player else {}
	_update_game_display()

	# 设置游戏状态
	GameStateManager.set_state(GameStateManager.GameState.EXPLORATION)

	print("[GameScene] Run restarted successfully (fresh PlayerStats + default weapon)")


## 重新开始按钮回调
func _on_restart_pressed() -> void:
	restart_run()


## 初始化游戏系统
func _init_gameplay_systems() -> void:
	# 伤害系统
	_damage_system = Node.new()
	_damage_system.name = "DamageSystem"
	_damage_system.set_script(load("res://scripts/combat/damage_system.gd"))
	add_child(_damage_system)

	# AI内容服务
	_ai_content_service = Node.new()
	_ai_content_service.name = "AIContentService"
	_ai_content_service.set_script(load("res://scripts/ai/ai_content_service.gd"))
	add_child(_ai_content_service)
	_ai_content_service.set_service_type(_ai_content_service.AIServiceType.REAL)

	# Phase 21.4.1: 后台启动AI初始化
	_ai_content_service.start_initialization()
	print("[GameScene] AIContentService initialization started")

	# 容器节点
	var monster_container = Node2D.new()
	monster_container.name = "MonsterContainer"
	$GameWorld.add_child(monster_container)

	var reward_container = Node2D.new()
	reward_container.name = "RewardContainer"
	$GameWorld.add_child(reward_container)

	# 楼层管理器
	_floor_manager = Node.new()
	_floor_manager.name = "FloorManager"
	_floor_manager.set_script(load("res://scripts/world/floor_manager.gd"))
	add_child(_floor_manager)

	# 获取子模块引用
	_room_renderer = _floor_manager.get_room_renderer()
	_room_spawner = _floor_manager.get_room_spawner()

	# 配置FloorManager
	_floor_manager.set_room_container($GameWorld)
	_floor_manager.set_monster_container(monster_container)
	_floor_manager.set_reward_container(reward_container)
	_floor_manager.set_player(player)
	_floor_manager.set_ai_content_service(_ai_content_service)

	# 连接FloorManager信号
	_floor_manager.floor_generated.connect(_on_floor_generated)
	_floor_manager.room_entered.connect(_on_fm_room_entered)
	_floor_manager.room_exited.connect(_on_fm_room_exited)
	_floor_manager.floor_completed.connect(_on_floor_completed)
	_floor_manager.ai_event_received.connect(_on_ai_event_received)
	_floor_manager.difficulty_adjusted.connect(_on_difficulty_adjusted)

	# 连接RoomSpawner信号
	_room_spawner.monster_spawned.connect(_on_monster_spawned)
	_room_spawner.reward_collected.connect(_on_reward_collected)
	_room_spawner.all_rewards_collected.connect(_on_all_rewards_collected)

	# 战斗管理器
	_combat_manager = Node.new()
	_combat_manager.name = "CombatManager"
	_combat_manager.set_script(load("res://scripts/combat/combat_manager.gd"))
	add_child(_combat_manager)

	# 配置CombatManager
	_combat_manager.set_room_spawner(_room_spawner)
	_combat_manager.set_floor_manager(_floor_manager)

	# 连接CombatManager信号
	_combat_manager.combat_state_changed.connect(_on_combat_state_changed)
	_combat_manager.combat_started.connect(_on_combat_started)
	_combat_manager.combat_cleared.connect(_on_combat_cleared)
	_combat_manager.room_completed.connect(_on_combat_room_completed)
	_combat_manager.monster_killed.connect(_on_monster_killed)
	# Phase 9.3: 战斗进度信号同步HUD(初始0/N + 每次击杀)
	_combat_manager.combat_progress_changed.connect(_on_combat_progress_changed)

	# 连接Boss信号
	_combat_manager.boss_fight_started.connect(_on_boss_fight_started)
	_combat_manager.boss_defeated.connect(_on_boss_defeated)

	# 连接RoomRenderer出口信号
	_room_renderer.exit_portal_entered.connect(_on_exit_portal_entered)

	# 连接下一层传送门信号（Phase 10.1.6）
	_room_renderer.next_floor_portal_entered.connect(_on_next_floor_portal_entered)

	print("[GameScene] Core gameplay systems initialized")

	# TASK-030: 等待 AI 初始化完成（含云端探测，最长 5 秒）再生成楼层
	# 保证第一个房间起 AI 模式明确稳定（不再"第一次房间 fallback、后面 cloud"）
	var cloud_ready: bool = await _ai_content_service.await_ready(5.0)
	_ai_content_service.print_status()
	print("[GameScene] AI initialization done, cloud_ready=", cloud_ready)

	# 生成楼层并进入第一个房间
	# TASK-025: 起始楼层取运行时楼层（加载存档时恢复进度；新游戏默认第1层）
	_floor_manager.generate_floor(GameStateManager.get_current_floor())


## 初始化升级系统
func _init_progression_systems() -> void:
	# 升级管理器
	_upgrade_manager = Node.new()
	_upgrade_manager.name = "UpgradeManager"
	_upgrade_manager.set_script(load("res://scripts/progression/upgrade_manager.gd"))
	add_child(_upgrade_manager)

	# 配置升级管理器
	_upgrade_manager.set_ai_content_service(_ai_content_service)
	_upgrade_manager.set_player(player)

	# 连接信号
	# 注意: upgrade_selection_required 由 LevelUpPanel 内部连接，不要重复连接
	_upgrade_manager.level_up.connect(_on_level_up)
	_upgrade_manager.exp_gained.connect(_on_exp_gained)

	# 升级面板
	_level_up_panel = CanvasLayer.new()
	_level_up_panel.name = "LevelUpPanel"
	_level_up_panel.set_script(load("res://scripts/ui/level_up_panel.gd"))
	add_child(_level_up_panel)

	# 配置升级面板
	_level_up_panel.set_upgrade_manager(_upgrade_manager)
	_level_up_panel.upgrade_selected.connect(_on_upgrade_selected)
	_level_up_panel.reward_selected.connect(_on_reward_selected)

	# 连接怪物死亡信号到经验值
	if _room_spawner:
		_room_spawner.monster_died.connect(_on_monster_died_for_exp)

	print("[GameScene] Progression systems initialized")


## 初始化Boss系统
func _init_boss_system() -> void:
	# Boss血条UI
	_boss_health_bar = CanvasLayer.new()
	_boss_health_bar.name = "BossHealthBar"
	_boss_health_bar.set_script(load("res://scripts/ui/boss_health_bar.gd"))
	add_child(_boss_health_bar)

	print("[GameScene] Boss system initialized")


## TASK-030: _init_save_system 已删除（本地 JSON 存档为重复存档逻辑，统一走 SaveService）


## 初始化AI自适应系统 (Phase 13)
func _init_ai_adaptive_systems() -> void:
	# 行为分析器
	_behavior_analyzer = Node.new()
	_behavior_analyzer.name = "BehaviorAnalyzer"
	_behavior_analyzer.set_script(load("res://scripts/ai/behavior_analyzer.gd"))
	add_child(_behavior_analyzer)
	_behavior_analyzer.set_player(player)

	# AI上下文管理器
	_ai_context_manager = Node.new()
	_ai_context_manager.name = "AIContextManager"
	_ai_context_manager.set_script(load("res://scripts/ai/ai_context_manager.gd"))
	add_child(_ai_context_manager)

	# 配置上下文管理器
	_ai_context_manager.set_behavior_analyzer(_behavior_analyzer)
	_ai_context_manager.set_player(player)
	_ai_context_manager.set_floor_manager(_floor_manager)
	_ai_context_manager.set_combat_manager(_combat_manager)
	_ai_context_manager.set_upgrade_manager(_upgrade_manager)

	# 配置FloorManager的AI上下文管理器
	_floor_manager.set_ai_context_manager(_ai_context_manager)

	# NPC记忆管理器
	_npc_memory_manager = Node.new()
	_npc_memory_manager.name = "NPCMemoryManager"
	_npc_memory_manager.set_script(load("res://scripts/ai/npc_memory_manager.gd"))
	add_child(_npc_memory_manager)

	# 配置上下文管理器的NPC记忆引用
	_ai_context_manager.set_npc_memory_manager(_npc_memory_manager)

	# 数据统计管理器
	_analytics_manager = Node.new()
	_analytics_manager.name = "AnalyticsManager"
	_analytics_manager.set_script(load("res://scripts/managers/analytics_manager.gd"))
	add_child(_analytics_manager)

	# 连接信号到行为分析器
	_connect_behavior_signals()

	# 开始新的运行统计
	_analytics_manager.start_run()

	print("[GameScene] AI adaptive systems initialized")


## 连接行为分析器信号
func _connect_behavior_signals() -> void:
	# 战斗信号
	if _combat_manager:
		_combat_manager.combat_started.connect(_behavior_analyzer.on_combat_started)
		_combat_manager.combat_cleared.connect(_behavior_analyzer.on_combat_cleared)
		_combat_manager.monster_killed.connect(_behavior_analyzer.on_monster_killed)

	# 玩家信号
	if player and player.has_signal("player_damaged"):
		player.player_damaged.connect(_behavior_analyzer.on_player_damaged)

	# 升级信号
	if _upgrade_manager:
		_upgrade_manager.level_up.connect(_behavior_analyzer.on_level_up)
		_upgrade_manager.exp_gained.connect(_behavior_analyzer.on_exp_gained)
		_upgrade_manager.upgrade_applied.connect(_behavior_analyzer.on_upgrade_applied)

	# 楼层信号
	if _floor_manager:
		_floor_manager.floor_generated.connect(_behavior_analyzer.on_floor_generated)
		_floor_manager.room_entered.connect(_behavior_analyzer.on_room_entered)

	print("[GameScene] Behavior signals connected")


## ==================== 每帧处理 ====================

func _process(delta: float) -> void:
	if not _is_paused:
		GameStateManager.add_play_time(delta)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
	elif event.is_action_pressed("interaction"):
		_try_interact()


## ==================== FloorManager回调 ====================

func _on_floor_generated(floor_data: FloorData) -> void:
	print("[GameScene] Floor generated: ", floor_data.get_room_count(), " rooms")
	# TASK-025: 同步运行时楼层（保存/自动保存记录真实进度）
	GameStateManager.set_current_floor(floor_data.floor_level)
	hud.set_status("第" + str(floor_data.floor_level) + "层已生成！")
	# 更新HUD楼层信息
	hud.update_floor_info(floor_data.floor_level, 1)


func _on_fm_room_entered(room: NewRoomData) -> void:
	# TASK-005: 重复进入防护（与 FloorManager.enter_room 的 is_completed 拒绝构成双层防御）
	if room.is_completed():
		print("[Room Enter] Room ", room.id, " already COMPLETED, ignore re-enter")
		return
	print("[Room Enter] Room ID:", room.id, " | Display:", room.display_index, " | Type:", room.get_type_string(), " | Name:", room.room_name)
	hud.set_status("进入: " + room.room_name)
	# 更新HUD房间信息(使用display_index和房间类型)
	if _floor_manager:
		hud.update_floor_info_with_type(
			_floor_manager.get_floor_level(),
			room.display_index,
			room.room_name
		)

	# Phase 17.1: 重置玩家位置到横版出生点(地面左侧)
	if player:
		player.global_position = WorldCoordinate.player_spawn_pos(room.position)
		var cam = player.get_node_or_null("Camera2D")
		if cam:
			cam.reset_smoothing()
			cam.force_update_scroll()

	# 设置状态为探索
	GameStateManager.set_state(GameStateManager.GameState.EXPLORATION)

	# 重置战斗管理器
	_combat_manager.reset()

	# 获取房间内容
	var content = room.content
	if not content:
		# TASK-005: 无内容房间走统一完成入口（禁止直接建门）
		print("[GameScene] No content for room, completing via state machine")
		_complete_current_room("no_content")
		return

	print("[GameScene] Room content: monsters=", content.monster_count, " rewards=", content.reward_count)

	# Phase 9.4: 锁定房间内容，防止AI异步结果覆盖已开始战斗的房间
	content.finalize()

	# 检查是否是Boss房间
	if room.room_type == NewRoomData.RoomType.BOSS:
		print("[GameScene] Boss room detected!")
		# TASK-005: Boss战属于战斗流程 → COMBAT 状态
		_floor_manager._current_floor.set_current_room_state(NewRoomData.RoomState.COMBAT)
		_start_boss_fight(room)
		return

	# Phase 26: 设置当前房间中心（用于local坐标计算）
	if _room_spawner:
		_room_spawner.set_room_center(room.position)

	# 普通战斗房间（TASK-004: 仅战斗型房间走怪物生成+战斗流程）
	# 事件/奖励/宝箱等非战斗房禁止生成怪物，由下方类型分发处理各自流程
	# TASK-005: 生成怪物成功后进入 COMBAT 状态；禁止进房时提前创建出口
	var spawned_monsters := 0
	if room.room_type in [NewRoomData.RoomType.COMBAT, NewRoomData.RoomType.ELITE] and content.monster_count > 0:
		spawned_monsters = _room_spawner.spawn_monsters(content, room.position)
		if spawned_monsters > 0:
			_combat_manager.start_combat(content)
			_floor_manager._current_floor.set_current_room_state(NewRoomData.RoomState.COMBAT)
	# 非战斗房间根据类型分发
	match room.room_type:
		NewRoomData.RoomType.REWARD:
			_handle_reward_room(content, room.position)
		NewRoomData.RoomType.EVENT:
			_handle_event_room(room, room.position)
		NewRoomData.RoomType.TREASURE:
			_handle_treasure_room(content, room.position)
		NewRoomData.RoomType.COMBAT, NewRoomData.RoomType.ELITE:
			# TASK-005: 战斗房不提前建出口；无怪物可生成时走统一完成入口
			if spawned_monsters == 0:
				_complete_current_room("no_monsters")
		_:
			# TASK-005: START/商店/空房无战斗流程，进房即完成（统一入口建唯一出口）
			_complete_current_room("empty_room")


func _on_fm_room_exited(room: NewRoomData) -> void:
	print("[GameScene] Room exited: ", room.room_name)


## 开始Boss战
func _start_boss_fight(room: NewRoomData) -> void:
	# 创建Boss数据
	var boss_data = _create_boss_data_for_room(room)
	if not boss_data:
		# TASK-005: Boss生成失败走统一完成入口（避免玩家卡死）
		print("[GameScene] Failed to create boss data")
		_complete_current_room("boss_spawn_failed")
		return

	# 生成Boss
	var boss_entity = _room_spawner.spawn_boss(boss_data, room.position)
	if not boss_entity:
		print("[GameScene] failed to spawn boss")
		_complete_current_room("boss_spawn_failed")
		return

	# 开始Boss战
	_combat_manager.start_boss_fight(boss_data)

	print("[GameScene] Boss fight started: ", boss_data.name)


## 根据房间创建Boss数据
func _create_boss_data_for_room(room: NewRoomData) -> BossData:
	# 根据楼层等级生成不同Boss
	var floor_level = 1
	if _floor_manager:
		floor_level = _floor_manager.get_floor_level()

	var boss_data = BossData.new()
	boss_data.id = "boss_floor_" + str(floor_level)
	boss_data.name = _get_boss_name(floor_level)
	boss_data.description = "守护本层的强大Boss"
	# TASK-027: Boss HP 500-800（第一层 500，逐层 +60，封顶 800）
	boss_data.max_health = clampi(500 + (floor_level - 1) * 60, 500, 800)
	# TASK-028: Boss攻击 30-50（第一层 30，逐层 +4，封顶 50）
	boss_data.attack = clampi(30 + (floor_level - 1) * 4, 30, 50)
	# Boss防御范围：5-15
	boss_data.defense = clampi(3 + floor_level * 2, 3, 15)
	# Phase 9.3: Boss移动速度降低至60%，避免贴脸持续伤害
	boss_data.speed = (80.0 + floor_level * 10) * 0.6
	boss_data.attack_cooldown = 1.5  # 攻击间隔1.5秒
	boss_data.attack_prepare_time = 0.5  # 攻击前摇0.5秒
	boss_data.reward_gold = 100 + floor_level * 50
	boss_data.reward_exp = 80 + floor_level * 40

	# 添加技能（显式构造Array[Dictionary]，避免类型推断为Array）
	var skills: Array[Dictionary] = []
	skills.append({"name": "重击", "damage_mult": 2.0, "cooldown": 3.0, "range": 80.0, "phase": 0})
	skills.append({"name": "冲锋", "damage_mult": 1.5, "cooldown": 5.0, "range": 200.0, "phase": 1})
	skills.append({"name": "怒吼", "damage_mult": 0.5, "cooldown": 8.0, "range": 150.0, "phase": 2})
	boss_data.skills = skills

	return boss_data


## 获取Boss名称
func _get_boss_name(floor_level: int) -> String:
	var names = ["地牢守卫", "暗影骑士", "深渊领主", "混沌之王", "毁灭者"]
	var index = (floor_level - 1) % names.size()
	return names[index]


func _on_floor_completed() -> void:
	print("[GameScene] Floor completed!")
	hud.set_status("恭喜通关！楼层已清除！")

	# 自动存档
	_auto_save()

	# Phase 10.1.6: 创建下一层传送门
	_create_next_floor_portal()


## ==================== CombatManager回调 ====================

func _on_combat_state_changed(new_state: int) -> void:
	match new_state:
		0: hud.set_status("房间状态: 空")
		1: hud.set_status("房间状态: 进入战斗...")
		2: hud.set_status("房间状态: 战斗中！")
		3: hud.set_status("房间状态: 已清除！")
		4: hud.set_status("房间状态: 奖励阶段")
		5: hud.set_status("房间状态: Boss战！")


func _on_combat_started(monster_count: int) -> void:
	print("[GameScene] Combat started: ", monster_count, " monsters")
	hud.set_status("战斗开始！怪物数量: " + str(monster_count))


func _on_combat_cleared() -> void:
	# Phase 9.4: Boss战走独立结算流程，不走普通combat reward
	if _combat_manager.is_boss_fight():
		print("[GameScene] Combat cleared (Boss fight) - skipping normal reward flow")
		return

	# Phase 16.1.6: 额外检查当前房间是否是 Boss房间
	# 原因: CombatManager.on_boss_defeated() 先设置 _is_boss_fight=false 再发射 combat_cleared
	# 导致 is_boss_fight() 返回 false，需要通过房间类型二次判断
	if _floor_manager:
		var current_room = _floor_manager.get_current_room()
		if current_room and current_room.room_type == NewRoomData.RoomType.BOSS:
			print("[GameScene] Combat cleared (Boss room) - skipping normal reward flow")
			return

	print("[GameScene] Combat cleared!")
	hud.set_status("房间已清除！拾取奖励后通过传送门进入下一房间")

	# Phase 16.1: 显示房间清空反馈
	if _room_renderer:
		_room_renderer.show_room_clear_feedback()

	# 生成奖励
	if _room_spawner:
		var content = _combat_manager.get_current_content()
		var room_pos = Vector2.ZERO
		if _floor_manager:
			var current_room = _floor_manager.get_current_room()
			if current_room:
				if not content:
					content = current_room.content
				room_pos = current_room.position
		_room_spawner.spawn_rewards(content, room_pos)

	# TASK-005: 清怪 → REWARD 状态（不创建出口）
	# 出口在奖励全部领取后由 room_completed 信号路径统一创建
	_floor_manager._current_floor.set_current_room_state(NewRoomData.RoomState.REWARD)


func _on_combat_room_completed() -> void:
	print("[GameScene] Room completed")
	# Phase 27: 触发房间完成流程，生成Portal
	_complete_current_room("reward_phase_completed")


func _on_monster_killed(dead_count: int, total_count: int) -> void:
	hud.set_status("怪物: " + str(dead_count) + "/" + str(total_count) + " 已击杀")
	hud.update_combat_status(dead_count, total_count)


## Phase 9.3: 战斗进度变化回调(含初始0/N)
func _on_combat_progress_changed(current_kills: int, total_monsters: int) -> void:
	hud.update_combat_status(current_kills, total_monsters)


## ==================== RoomSpawner回调 ====================

func _on_monster_spawned(monster_entity: MonsterEntity) -> void:
	print("[GameScene] Monster spawned: ", monster_entity.get_monster_name())


func _on_reward_collected(reward_data: RewardData) -> void:
	print("[GameScene] Reward collected: ", reward_data.name)
	hud.set_status("获得: " + reward_data.description)
	_player_data = player.get_player_data()
	_update_game_display()


func _on_all_rewards_collected() -> void:
	print("[GameScene] All rewards collected!")
	hud.set_status("所有奖励已收集！")
	# 完成奖励阶段，推进战斗状态机
	if _combat_manager:
		_combat_manager.complete_reward_phase()


## ==================== 非战斗房间处理 ====================

## Reward房: 直接生成奖励物品等待拾取
func _handle_reward_room(content: RoomContentData, room_pos: Vector2) -> void:
	print("[GameScene] Reward room entered")
	hud.set_status("奖励房间! 拾取掉落物品")

	# TASK-005: 奖励房进入 REWARD 状态
	_floor_manager._current_floor.set_current_room_state(NewRoomData.RoomState.REWARD)

	# 生成奖励物品
	if _room_spawner:
		_room_spawner.spawn_rewards(content, room_pos)
		# 断开旧连接避免重复触发（安全模式）
		if _room_spawner.has_signal("all_rewards_collected"):
			if _room_spawner.all_rewards_collected.is_connected(_on_reward_room_cleared):
				_room_spawner.all_rewards_collected.disconnect(_on_reward_room_cleared)
			_room_spawner.all_rewards_collected.connect(_on_reward_room_cleared)


## Reward房所有奖励收集完成
func _on_reward_room_cleared() -> void:
	print("[GameScene] Reward room cleared!")
	hud.set_status("奖励已收集完毕!")
	_complete_current_room("reward_collected")


## Event房: 显示随机事件
func _handle_event_room(room: NewRoomData, room_pos: Vector2) -> void:
	print("[GameScene] Event room entered")
	hud.set_status("发现事件! 选择一个...")

	# TASK-005: 事件房进入 EVENT 状态（禁止生成怪物/进入战斗）
	_floor_manager._current_floor.set_current_room_state(NewRoomData.RoomState.EVENT)

	# 生成随机事件
	var event = _generate_random_event()
	if event.is_empty():
		print("[GameScene] Event room: no event generated, completing via state machine")
		_complete_current_room("event_empty")
		return

	# 显示事件面板
	_show_event_panel(event, room)


## 生成随机事件
func _generate_random_event() -> Dictionary:
	var events = [
		{
			"title": "神秘祭坛",
			"description": "一座古老的祭坛出现在你面前，散发着微弱的光芒。",
			"choices": [
				{"text": "献祭10金币获得+5攻击", "reward": {"gold": -10, "attack": 5}, "risk": {}},
				{"text": "献祭20生命获得+10攻击", "reward": {"max_health": 10, "attack": 10}, "risk": {"damage": 20}},
				{"text": "离开", "reward": {}, "risk": {}}
			]
		},
		{
			"title": "流浪商人",
			"description": "一个神秘的商人在此停留，他展示着稀有的物品。",
			"choices": [
				{"text": "购买生命药水(15金币)", "reward": {"gold": -15, "heal": 30}, "risk": {}},
				{"text": "购买攻击强化(25金币)", "reward": {"gold": -25, "attack": 5}, "risk": {}},
				{"text": "拒绝交易", "reward": {}, "risk": {}}
			]
		},
		{
			"title": "远古宝箱",
			"description": "一个布满灰尘的宝箱躺在角落。",
			"choices": [
				{"text": "打开宝箱", "reward": {"gold": 50, "attack": 3}, "risk": {"damage": 10}},
				{"text": "谨慎检查后打开", "reward": {"gold": 30}, "risk": {"damage": 5}},
				{"text": "离开", "reward": {}, "risk": {}}
			]
		},
		{
			"title": "智慧老者",
			"description": "一位老者坐在地上，似乎 knows 你的命运。",
			"choices": [
				{"text": "请教战斗技巧(+3攻击)", "reward": {"attack": 3}, "risk": {}},
				{"text": "请求治疗(+20生命)", "reward": {"heal": 20}, "risk": {}},
				{"text": "无视离开", "reward": {}, "risk": {}}
			]
		}
	]

	return events[randi() % events.size()]


## 显示事件选择面板
func _show_event_panel(event: Dictionary, room: NewRoomData) -> void:
	# TASK-003: 暂停玩家控制
	# 旧代码调用不存在的 player.set_physics_processing(false) → 进入事件房即崩溃
	# 现封装为 player_controller.set_control_enabled()（物理帧+输入+速度清零）
	if player:
		player.set_control_enabled(false)

	hud.set_status(event.get("title", "事件"))

	var choices = event.get("choices", [])
	print("[Event] Event: ", event.get("title", ""))
	print("[Event] Choices: ", choices.size())

	# 简化版：自动选择第一个选项（完整实现需要UI面板）
	_apply_event_choice(event, 0, room)


## 应用事件选择
func _apply_event_choice(event: Dictionary, choice_index: int, room: NewRoomData) -> void:
	var choices = event.get("choices", [])
	if choice_index >= choices.size():
		choice_index = 0

	var choice = choices[choice_index]
	var reward = choice.get("reward", {})
	var risk = choice.get("risk", {})

	print("[Event] Selected: ", choice.get("text", ""))

	# 应用奖励
	if player:
		if reward.has("gold"):
			player.add_gold(reward["gold"])
		if reward.has("attack"):
			player.add_attack(reward["attack"])
		if reward.has("max_health"):
			player.add_max_health(reward["max_health"])
		if reward.has("heal"):
			player.heal(reward["heal"])

	# 应用风险
	if risk.has("damage") and player:
		player.take_damage(risk["damage"])

	_player_data = player.get_player_data()
	_update_game_display()

	# TASK-003: 恢复玩家控制（物理帧+输入处理；速度已在禁用时清零，从静止状态恢复）
	if player:
		player.set_control_enabled(true)

	hud.set_status("事件完成! " + choice.get("text", ""))

	# 延迟后创建出口
	await get_tree().create_timer(1.5).timeout
	_complete_current_room("event_completed")


## Treasure房: 生成宝箱
func _handle_treasure_room(content: RoomContentData, room_pos: Vector2) -> void:
	print("[GameScene] Treasure room entered")
	hud.set_status("发现宝箱! 寻找并打开它")

	# TASK-005: 宝箱房属于奖励流程 → REWARD 状态
	_floor_manager._current_floor.set_current_room_state(NewRoomData.RoomState.REWARD)

	# 生成奖励物品（chest作为reward_item的特殊形式）
	var reward_count = content.reward_count if content else 2
	reward_count = max(1, min(reward_count, 3))

	for i in range(reward_count):
		var reward_data = RewardData.generate_random_reward(i)
		# TASK-002: 平台感知采样（与战斗房/Reward房一致，避开平台碰撞体）
		var platform_rects: Array[Rect2] = []
		if _room_renderer and _room_renderer.has_method("get_platform_rects"):
			platform_rects = _room_renderer.get_platform_rects()
		var world_pos = WorldCoordinate.reward_spawn_pos(room_pos, platform_rects, i, reward_count)
		var local_spawn_pos = world_pos - room_pos
		_room_spawner.spawn_reward(reward_data, local_spawn_pos)

	print("[GameScene] Treasure room: spawned ", reward_count, " rewards")

	# 监听奖励收集（断开旧连接避免重复触发）
	if _room_spawner and _room_spawner.has_signal("all_rewards_collected"):
		if _room_spawner.all_rewards_collected.is_connected(_on_treasure_room_cleared):
			_room_spawner.all_rewards_collected.disconnect(_on_treasure_room_cleared)
		_room_spawner.all_rewards_collected.connect(_on_treasure_room_cleared)


func _on_treasure_room_cleared() -> void:
	print("[GameScene] Treasure room cleared!")
	hud.set_status("宝箱已打开! 获得奖励!")
	_complete_current_room("treasure_opened")


## ==================== 出口传送门 ====================

## 自动保存: 当前进度到当前存档槽位
func _auto_save() -> void:
	# TASK-027: 死亡状态禁止写入存档——hp=0 不得持久化为正式存档
	if player and player.is_dead():
		print("[GameScene] Auto-save SKIPPED: player is dead (no dead-state save)")
		return

	var save_data = GameStateManager.get_save_data()
	if save_data.is_empty():
		print("[GameScene] Auto-save skipped: no save data")
		return
	var floor_level = 1
	if _floor_manager:
		floor_level = _floor_manager.get_floor_level()
	save_data["current_floor"] = floor_level
	var save_slot = GameStateManager.get_current_slot()
	if save_slot < 1:
		save_slot = 1  # fallback to slot 1 if no slot assigned
	print("[Save Debug] Auto-save: slot=", save_slot, " floor=", floor_level, " level=", save_data.get("player_state", {}).get("level", 1), " weapon_id=", save_data.get("player_state", {}).get("weapon_id", -1))
	SaveService.save_game(save_slot, save_data)
	print("[GameScene] Auto-saved to slot ", save_slot, " (floor ", floor_level, ")")


## Phase 24: 统一房间完成接口
## 所有房间类型完成后必须调用此函数，确保状态机一致
## TASK-005: 重复防护由 RoomState.COMPLETED 终态保证
## （旧 TASK-001 completed 布尔锁已由状态机替代）
func _complete_current_room(reason: String) -> void:
	var room = _floor_manager.get_current_room()
	if not room:
		print("[RoomComplete] WARNING: No current room!")
		return

	# 已完成房间不再重复处理（transition_to(COMPLETED) 只成功一次 → 出口唯一）
	if room.is_completed():
		print("[RoomComplete] Room already COMPLETED, skip. reason=", reason)
		return

	print("[RoomComplete] room_id=" + str(room.id) + " type=" + room.get_type_string() + " reason=" + reason)

	# 唯一完成入口（FloorData → NewRoomData.transition_to(COMPLETED)）
	_floor_manager._current_floor.complete_current_room()

	# 出口仅在状态成功转换为 COMPLETED 后创建
	_create_room_exits()


func _on_exit_portal_entered(target_room_id: int) -> void:
	print("[GameScene] Exit portal entered: room ", target_room_id)
	_floor_manager.enter_room(target_room_id)


func _create_room_exits() -> void:
	if not _floor_manager or not _room_renderer:
		return

	var available_ids = _floor_manager.get_available_exit_ids()
	if available_ids.size() == 0:
		print("[GameScene] No available exits (floor complete?)")
		hud.set_status("恭喜通关！所有房间已清除！")
		return

	var current_floor = _floor_manager.get_current_floor()
	var current_room = current_floor.get_current_room()
	var current_room_id = current_room.id if current_room else -1

	# Phase 9.3: 强制线性推进，禁止返回已访问房间
	# TASK-005: 传送门目标禁止选择已完成房间
	# （旧代码兜底级允许已完成 → 玩家进入被拒 "already entered/completed, skipping"）
	# 优先级: 未访问房间 > 已访问未完成房间（已完成房间一律排除）
	# TASK-006: 增加 [PortalSelection] 防御日志；无有效目标时走紧急出口（绝不软锁）
	print("[PortalSelection] room ", current_room_id, " candidates=", available_ids)
	var target_id = -1
	var selection_reason = ""

	# 第一优先：未访问的房间
	for id in available_ids:
		if id == current_room_id:
			continue
		var room = current_floor.get_room(id)
		if room and not room.visited:
			target_id = id
			selection_reason = "priority1 unvisited"
			break

	# 第二优先：任意未完成的房间(允许回溯到未完成房；已完成房间一律排除)
	if target_id == -1:
		for id in available_ids:
			if id == current_room_id:
				continue
			var room = current_floor.get_room(id)
			if room and not room.is_completed():
				target_id = id
				selection_reason = "priority2 unfinished"
				break

	# TASK-005: 无有效目标时不乱建门——楼层完成走下一层流程
	# TASK-006: 楼层未完成则走紧急出口防御（DAG 结构下理论不可达，绝不软锁）
	if target_id == -1:
		if _floor_manager.is_floor_complete():
			print("[PortalSelection] no valid target, floor complete")
			_on_floor_completed()
		else:
			_emergency_exit_portal(current_floor, current_room_id)
		return

	var target_room = current_floor.get_room(target_id)
	if target_room:
		print("[PortalSelection] ", selection_reason, " -> room ", target_id)
		print("[Portal] Current Room:", current_room_id, " | Target Room:", target_id, " | Type:", target_room.get_type_string())
		_room_renderer.create_exit_portal(target_id, target_room.get_type_string())


## TASK-006: 紧急出口——正常 DAG 拓扑下不会触发（每房必有未访问前向边）
## 防御性兜底：宁可让玩家跳过探索，绝不允许软锁
## 优先级: 未完成Boss房 > 未访问非当前房 > 未完成非当前房
func _emergency_exit_portal(current_floor: FloorData, current_room_id: int) -> void:
	print("[PortalSelection] WARNING: no valid forward target for room ", current_room_id, " (should not happen)")
	var target_id = -1
	var reason = ""

	# 优先1: 未完成的 Boss 房
	for room in current_floor.get_all_rooms():
		if room.room_type == NewRoomData.RoomType.BOSS and not room.is_completed():
			target_id = room.id
			reason = "unfinished boss"
			break
	# 优先2: 未访问的非当前房
	if target_id == -1:
		for room in current_floor.get_all_rooms():
			if room.id == current_room_id or room.is_completed():
				continue
			if not room.visited:
				target_id = room.id
				reason = "unvisited"
				break
	# 优先3: 未完成的非当前房
	if target_id == -1:
		for room in current_floor.get_all_rooms():
			if room.id == current_room_id or room.is_completed():
				continue
			target_id = room.id
			reason = "unfinished"
			break

	var target_room = current_floor.get_room(target_id) if target_id >= 0 else null
	if not target_room:
		print("[PortalSelection] ERROR: no emergency target, cannot create portal")
		hud.set_status("附近没有可探索的房间了...")
		return

	print("[PortalSelection] EMERGENCY: portal to room ", target_id, " (", reason, ")")
	print("[Portal] Current Room:", current_room_id, " | Target Room:", target_id, " | Type:", target_room.get_type_string())
	_room_renderer.create_exit_portal(target_id, target_room.get_type_string())


## ==================== 下一层传送门（Phase 10.1.6） ====================

## 创建下一层传送门
func _create_next_floor_portal() -> void:
	if not _room_renderer:
		return

	print("[GameScene] Creating next floor portal")
	hud.set_status("Boss已被击败！进入传送门前往下一层！")

	# 创建下一层传送门
	_room_renderer.create_next_floor_portal()


## 下一层传送门触发（Phase 10.1.8: 添加转场效果）
func _on_next_floor_portal_entered() -> void:
	print("[FLOOR TRANSITION] Next floor portal entered!")

	# 记录旧楼层信息
	var old_level = _floor_manager.get_floor_level() if _floor_manager else 0
	print("[FLOOR TRANSITION] Old floor: ", old_level)

	# 淡出效果
	await _fade_out(0.5)

	# 生成下一层
	if _floor_manager:
		_floor_manager.generate_next_floor()

	# 记录新楼层信息
	var new_level = _floor_manager.get_floor_level() if _floor_manager else 0
	var room_count = _floor_manager.get_current_floor().get_room_count() if _floor_manager and _floor_manager.get_current_floor() else 0
	print("[FLOOR TRANSITION] New floor: ", new_level)
	print("[FLOOR TRANSITION] Room count: ", room_count)

	# 更新显示
	_player_data = player.get_player_data() if player else {}
	_update_game_display()

	# 显示楼层切换提示
	_show_floor_transition(new_level)

	# 淡入效果
	await _fade_in(0.5)

	print("[FLOOR TRANSITION] Transition complete!")


## 淡出效果（Phase 10.1.8）
func _fade_out(duration: float) -> void:
	# 创建全屏黑色遮罩
	var overlay = _get_or_create_transition_overlay()
	overlay.modulate.a = 0.0
	overlay.visible = true

	# 淡出动画
	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, duration)
	await tween.finished


## 淡入效果（Phase 10.1.8）
func _fade_in(duration: float) -> void:
	var overlay = _get_or_create_transition_overlay()
	if not overlay.visible:
		return

	# 淡入动画
	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, duration)
	await tween.finished

	overlay.visible = false


## 获取或创建转场遮罩（Phase 10.1.8）
func _get_or_create_transition_overlay() -> ColorRect:
	var overlay = get_node_or_null("TransitionOverlay")
	if not overlay:
		overlay = ColorRect.new()
		overlay.name = "TransitionOverlay"
		overlay.color = Color(0, 0, 0, 1)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = 1000  # 确保在最上层
		overlay.visible = false
		add_child(overlay)
	return overlay


## 显示楼层切换提示（Phase 10.1.8）
func _show_floor_transition(floor_level: int) -> void:
	# 创建楼层提示
	var label = Label.new()
	label.text = "第" + str(floor_level) + "层"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 设置字体大小
	label.add_theme_font_size_override("font_size", 48)

	# 设置字体颜色（白色）
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	# 添加到场景
	var overlay = _get_or_create_transition_overlay()
	overlay.add_child(label)

	# 等待1.5秒
	await get_tree().create_timer(1.5).timeout

	# 移除标签
	label.queue_free()


## ==================== UI交互 ====================

func _toggle_pause() -> void:
	if _is_paused:
		_resume_game()
	else:
		_pause_game()


func _pause_game() -> void:
	_is_paused = true
	get_tree().paused = true
	GameStateManager.set_state(GameStateManager.GameState.PAUSED)
	pause_menu.show_pause()
	hud.set_status("游戏暂停")


func _resume_game() -> void:
	# 如果玩家已死亡，不允许恢复游戏，只能重新开始或退出
	if player and player.is_dead():
		print("[GameScene] Cannot resume - player is dead")
		return

	_is_paused = false
	get_tree().paused = false
	GameStateManager.set_state(GameStateManager.GameState.PLAYING)
	pause_menu.hide_pause()
	hud.set_status("游戏进行中")


func _try_interact() -> void:
	if _is_paused:
		return
	if interaction_manager.has_interactable():
		interaction_manager.trigger_interaction()


func _handle_weapon_pickup(weapon_obj: WeaponObject) -> void:
	var weapon_data = weapon_obj.get_weapon_data()
	if weapon_data:
		_inventory_manager.add_weapon(weapon_data)
		ApiClient.post_request(APIConfig.PLAYER_WEAPONS, {"weapon_id": weapon_data.id}, true)
		hud.set_status("获得武器: " + weapon_data.name + " (伤害: " + str(weapon_data.damage) + ")")


func _update_game_display() -> void:
	# Phase 9.4: 先同步到PlayerStats，再从PlayerStats读取（确保HUD字段完整）
	player.set_player_data(_player_data)
	_player_data = player.get_player_data()
	hud.update_hud(_player_data)
	hud.set_status("游戏进行中 - 按ESC暂停")


func _update_resource_display() -> void:
	hud.update_resource_counts(
		ResourceService.get_weapon_count(),
		ResourceService.get_monster_count(),
		ResourceService.get_map_count(),
		ResourceService.get_event_count()
	)


## ==================== UI回调 ====================

func _on_nearest_object_changed(obj: Variant) -> void:
	if obj and obj is InteractiveObject:
		interaction_hint.show_hint(obj.interaction_hint)
	else:
		interaction_hint.hide_hint()


func _on_interaction_triggered(object_id: int) -> void:
	var obj = interaction_manager.get_object(object_id)
	if obj:
		var game_obj = _find_game_object_by_interactive_id(object_id)
		if game_obj and game_obj is WeaponObject:
			_handle_weapon_pickup(game_obj)
		else:
			hud.set_status("交互: " + obj.object_name)
		interaction_manager.complete_interaction(object_id)


func _find_game_object_by_interactive_id(interactive_id: int) -> GameObject:
	for obj in _object_manager.get_all_objects():
		if obj.has_interactive_object() and obj.get_interactive_object().object_id == interactive_id:
			return obj
	return null


func _on_resume_game() -> void:
	_resume_game()


func _on_open_settings() -> void:
	pause_menu.hide_pause()
	settings_menu.show_settings()


func _on_exit_to_menu() -> void:
	pause_menu.hide_pause()
	# TASK-027: 死亡后不允许保存死档——跳过存档面板直接回主菜单
	if player and player.is_dead():
		print("[GameScene] Player dead, skipping save panel (death ends the run)")
		_exit_to_menu()
		return
	save_selection.show_save_selection()


func _on_settings_closed() -> void:
	pause_menu.show_pause()


func _on_save_selected(slot: int) -> void:
	# TASK-027: 死亡状态禁止保存死档（面板理论上不可达，双保险）
	if player and player.is_dead():
		save_selection.set_status("死亡状态无法保存")
		print("[GameScene] Save REJECTED: player is dead")
		await get_tree().create_timer(1.5).timeout
		_exit_to_menu()
		return

	# TASK-029: 已分配当前槽位（默认槽位1）时一律沿用——保存面板点选其它槽位
	# 不产生游离存档（规则: 已有 slot1 → 默认继续 slot1，不自动创建 slot2）
	var actual_slot: int = GameStateManager.resolve_save_slot(slot)
	if actual_slot != slot:
		print("[Save Debug] Slot choice ", slot, " overridden -> current slot ", actual_slot)
		save_selection.set_status("默认使用槽位 " + str(actual_slot) + " 保存...")

	# TASK-026: 等待真实保存结果并给出反馈
	# （旧实现固定等 1 秒后无条件退出：保存失败/超时玩家无感知 → "无法正常保存"）
	var save_data = GameStateManager.get_save_data()
	save_selection.set_status("保存中...")

	# 用 Dictionary 容器捕获结果（GDScript lambda 按值捕获局部变量，必须借引用容器）
	var box := {"done": false, "ok": false, "msg": ""}
	var on_saved := func(success: bool, message: String) -> void:
		box["done"] = true
		box["ok"] = success
		box["msg"] = message
	var on_error := func(error: String) -> void:
		box["done"] = true
		box["ok"] = false
		box["msg"] = error

	SaveService.save_saved.connect(on_saved)
	SaveService.save_error.connect(on_error)
	SaveService.save_game(actual_slot, save_data)

	var waited := 0
	while not box["done"] and waited < 100:  # 最长约 10 秒
		await get_tree().create_timer(0.1).timeout
		waited += 1
	SaveService.save_saved.disconnect(on_saved)
	SaveService.save_error.disconnect(on_error)

	if box["ok"]:
		print("[Save Debug] Save via panel SUCCESS: slot=", actual_slot)
		save_selection.set_status("保存成功！")
		hud.set_status("保存成功！槽位 " + str(actual_slot))
	else:
		var msg: String = str(box["msg"]) if box["msg"] != "" else "保存超时，请检查服务端"
		print("[Save Debug] Save via panel FAILED: ", msg)
		save_selection.set_status("保存失败: " + msg)
		hud.set_status("保存失败: " + msg)
		# 失败时延长停留时间，让玩家看清错误信息
		await get_tree().create_timer(3.0).timeout
		save_selection.set_status("选择存档槽位")
		save_selection.show_save_selection()
		return

	await get_tree().create_timer(1.0).timeout
	_exit_to_menu()


func _on_save_selection_closed() -> void:
	pause_menu.show_pause()


func _exit_to_menu() -> void:
	_is_paused = false
	get_tree().paused = false
	# TASK-027: 退出时清理 run 临时状态与存档服务状态锁（主菜单状态干净）
	GameStateManager.reset_run_state()
	SaveService.reset_state()
	# TASK-029: 退出游戏统一重置游戏流程状态（重新登录/再进入不被旧状态阻塞）
	GameFlowController.reset_flow()
	GameStateManager.set_state(GameStateManager.GameState.NOT_STARTED)
	SceneManager.go_to_main()


func _on_resource_pressed() -> void:
	SceneManager.go_to_resource_center()


func _on_logout_pressed() -> void:
	hud.set_status("正在保存游戏...")
	GameFlowController.exit_game()


## ==================== Phase 12: 升级系统回调 ====================

## 升级回调 (Phase 9.4.2: 同步更新HUD)
func _on_level_up(new_level: int) -> void:
	print("[GameScene] Level up! Now level ", new_level)
	hud.set_status("升级！等级 " + str(new_level))
	# 更新HUD等级和经验
	if player:
		_player_data = player.get_player_data()
		hud.update_hud(_player_data)
	GameStateManager.set_state(GameStateManager.GameState.LEVEL_UP)


## 升级选择需求回调
func _on_upgrade_selection_required(options: Array) -> void:
	print("[GameScene] Upgrade selection required: ", options.size(), " options")
	if _level_up_panel:
		_level_up_panel.show_upgrade_panel(options)


## 经验获取回调 (Phase 9.4.2: 同步更新HUD)
func _on_exp_gained(amount: int, current_exp: int, exp_to_next: int) -> void:
	hud.set_status("获得 " + str(amount) + " 经验 (" + str(current_exp) + "/" + str(exp_to_next) + ")")
	# 更新HUD经验条
	if player:
		_player_data = player.get_player_data()
		hud.update_hud(_player_data)


## 强化选择完成回调
func _on_upgrade_selected(upgrade: UpgradeData) -> void:
	print("[GameScene] Upgrade selected: ", upgrade.name)
	hud.set_status("获得强化: " + upgrade.name)
	# Phase 9.4: 升级后刷新HUD（属性可能已变化）
	if player:
		_player_data = player.get_player_data()
		hud.update_hud(_player_data)
	GameStateManager.set_state(GameStateManager.GameState.PLAYING)


## 奖励选择完成回调 (Phase 9.3.2)
func _on_reward_selected(reward: RewardData) -> void:
	print("[GameScene] Reward selected: ", reward.name)
	hud.set_status("获得奖励: " + reward.name)

	# 应用奖励到玩家
	if player and reward:
		reward.apply_to_player(player)

	# 更新显示
	_player_data = player.get_player_data()
	_update_game_display()

	GameStateManager.set_state(GameStateManager.GameState.PLAYING)


## 怪物死亡时获取经验值
func _on_monster_died_for_exp(entity: MonsterEntity) -> void:
	if _upgrade_manager and entity:
		var exp_reward = entity.get_experience_reward()
		await _upgrade_manager.add_experience(exp_reward)


## ==================== Phase 12: Boss系统回调 ====================

## Boss战斗开始
func _on_boss_fight_started(boss_data: BossData) -> void:
	print("[GameScene] Boss fight started: ", boss_data.name)
	GameStateManager.set_state(GameStateManager.GameState.BOSS)
	hud.set_status("Boss战开始！")

	if _boss_health_bar:
		_boss_health_bar.show_boss(boss_data.name, boss_data.max_health)


## Boss被击败 - 独立结算流程 (Phase 9.4)
func _on_boss_defeated() -> void:
	print("[GameScene] Boss defeated!")
	hud.set_status("Boss被击败！")

	if _boss_health_bar:
		_boss_health_bar.hide_boss()

	# Boss专属奖励（不走普通combat reward流程）
	if _room_spawner:
		var boss_data = _combat_manager.get_boss_data()
		var room_pos = Vector2.ZERO
		if _floor_manager:
			var current_room = _floor_manager.get_current_room()
			if current_room:
				room_pos = current_room.position
				# Phase 26: 设置房间中心
				_room_spawner.set_room_center(room_pos)
				var reward_container = _room_spawner._get_reward_container()
				if reward_container:
					_room_spawner._reward_container = reward_container

		# 创建Boss专属奖励内容
		var boss_content = RoomContentData.new()
		boss_content.room_type = "boss"
		boss_content.reward_count = 5
		boss_content.reward_quality = 2.0
		_room_spawner.spawn_rewards(boss_content, room_pos)

	# 标记房间完成
	if _floor_manager and _floor_manager._current_floor:
		# TASK-005: Boss 状态链 COMBAT → REWARD → COMPLETED（统一状态机）
		_floor_manager._current_floor.set_current_room_state(NewRoomData.RoomState.REWARD)
		_floor_manager._current_floor.complete_current_room()

	# Phase 10.1.6: 等待2秒后检查楼层完成状态
	await get_tree().create_timer(2.0).timeout

	# 检查楼层是否完成
	if _floor_manager and _floor_manager.is_floor_complete():
		_on_floor_completed()
	else:
		# Boss击败后也创建出口（进入下一层）
		_create_room_exits()

	# Boss击败后自动存档
	await get_tree().create_timer(0.5).timeout
	_auto_save()


## TASK-030: _on_save_completed/_on_load_completed 已删除（本地 JSON 存档系统回调，
## 存档结果反馈由 pause_menu/存档面板直接监听 SaveService.save_saved/save_error）


## ==================== Phase 13: AI自适应系统回调 ====================

## AI事件接收回调
func _on_ai_event_received(event_data) -> void:
	print("[GameScene] AI event received: ", event_data.title if event_data else "null")
	if event_data:
		hud.set_status("发现事件: " + event_data.title)
		# Phase 15: 显示事件面板
		_show_ai_event(event_data)


## 显示AI事件面板
func _show_ai_event(event_data) -> void:
	if not event_data:
		return

	# 设置游戏状态为EVENT
	GameStateManager.set_state(GameStateManager.GameState.EVENT)

	# 查找或创建AI事件面板
	var event_panel = get_node_or_null("UI/AIEventPanel")
	if event_panel and event_panel.has_method("show_event"):
		event_panel.show_event(event_data)
	else:
		print("[GameScene] AIEventPanel not found, using HUD fallback")
		hud.set_status("事件: " + event_data.title + " - " + event_data.description)


## 事件选择完成回调
func _on_event_completed(rewards: Dictionary) -> void:
	print("[GameScene] Event completed, rewards: ", rewards)

	# 恢复游戏状态
	GameStateManager.set_state(GameStateManager.GameState.EXPLORATION)

	# 更新玩家显示
	_player_data = player.get_player_data()
	_update_game_display()

	hud.set_status("事件完成！")


## 难度调整回调
func _on_difficulty_adjusted(adjustment: Dictionary) -> void:
	print("[GameScene] Difficulty adjusted")
	var hp_mult = adjustment.get("enemy_hp_multiplier", 1.0)
	if hp_mult > 1.0:
		hud.set_status("难度提升！怪物更强了")
	elif hp_mult < 1.0:
		hud.set_status("难度降低！怪物变弱了")


## 玩家受伤回调 - 实时更新HUD
func _on_player_damaged(damage: int, current_health: int) -> void:
	# 从玩家节点获取最新数据并更新HUD
	if player:
		_player_data = player.get_player_data()
		hud.update_hud(_player_data)


## Phase 15: 玩家死亡回调
func _on_player_dead() -> void:
	print("[GameScene] Player is dead!")
	hud.set_status("你已阵亡...")

	# TASK-027: 死亡即结束本次 run——不再自动保存
	# （旧实现 _auto_save() 会把 hp=0 写入正式存档槽位，污染"继续游戏"）

	# 停止所有怪物AI
	_stop_all_monsters()

	# 显示GameOver面板
	if _game_over_panel:
		_game_over_panel.visible = true
		get_tree().paused = true


## 停止所有怪物的AI行为
func _stop_all_monsters() -> void:
	var monster_container = $GameWorld.get_node_or_null("MonsterContainer")
	if monster_container:
		for monster in monster_container.get_children():
			if monster.has_method("set"):
				monster.set("velocity", Vector2.ZERO)
			if monster.has_method("set_physics_process"):
				monster.set_physics_process(false)

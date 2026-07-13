## 游戏主场景脚本
##
## 负责游戏场景的初始化和管理
## 集成世界系统、对象系统、交互系统、武器拾取系统、暂停菜单、设置、存档选择功能

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

## 对象管理器
var _object_manager: Node = null

## 背包管理器
var _inventory_manager: Node = null

## 装备管理器
var _equipment_manager: Node = null

## 怪物生成器
var _monster_spawner: Node = null

## 伤害系统
var _damage_system: Node = null

## 掉落管理器
var _drop_manager: Node = null

## 房间图管理器
var _room_graph: Node = null

## 房间内容管理器
var _room_content_manager: Node = null

## AI内容服务
var _ai_content_service: Node = null

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

	# 初始化系统
	_init_inventory_system()
	_init_object_system()
	_init_damage_system()
	_init_monster_system()
	_init_drop_system()
	_init_world_system()

	# 更新显示
	_update_game_display()

	# 更新资源显示
	_update_resource_display()

	# 更新游戏运行时间
	set_process(true)


## 初始化背包系统
func _init_inventory_system() -> void:
	# 创建背包管理器
	_inventory_manager = Node.new()
	_inventory_manager.name = "InventoryManager"
	_inventory_manager.set_script(load("res://scripts/inventory/inventory_manager.gd"))
	add_child(_inventory_manager)

	# 创建装备管理器
	_equipment_manager = Node.new()
	_equipment_manager.name = "EquipmentManager"
	_equipment_manager.set_script(load("res://scripts/inventory/equipment_manager.gd"))
	add_child(_equipment_manager)

	# 初始化装备管理器
	_equipment_manager.initialize(_inventory_manager)


## 初始化对象系统
func _init_object_system() -> void:
	# 创建对象管理器
	_object_manager = Node.new()
	_object_manager.name = "ObjectManager"
	_object_manager.set_script(load("res://scripts/object/object_manager.gd"))
	add_child(_object_manager)


## 初始化伤害系统
func _init_damage_system() -> void:
	_damage_system = Node.new()
	_damage_system.name = "DamageSystem"
	_damage_system.set_script(load("res://scripts/combat/damage_system.gd"))
	add_child(_damage_system)
	print("[GameScene] Damage system initialized")


## 初始化掉落系统
func _init_drop_system() -> void:
	_drop_manager = Node.new()
	_drop_manager.name = "DropManager"
	_drop_manager.set_script(load("res://scripts/drop/drop_manager.gd"))
	add_child(_drop_manager)

	# 设置奖励容器
	_drop_manager.setup_container($GameWorld)

	# 设置玩家引用
	_drop_manager.set_player(player)

	# 连接信号
	_drop_manager.reward_collected.connect(_on_reward_collected)
	_drop_manager.all_rewards_collected.connect(_on_all_rewards_collected)

	print("[GameScene] Drop system initialized")


## 初始化怪物系统
func _init_monster_system() -> void:
	# 创建怪物生成器
	_monster_spawner = Node.new()
	_monster_spawner.name = "MonsterSpawner"
	_monster_spawner.set_script(load("res://scripts/enemy/monster_spawner.gd"))
	add_child(_monster_spawner)

	# 设置怪物容器
	_monster_spawner.setup_container($GameWorld)

	# 连接信号
	_monster_spawner.monster_spawned.connect(_on_monster_spawned)
	_monster_spawner.all_monsters_dead.connect(_on_all_monsters_dead)
	_monster_spawner.monster_died_signal.connect(_on_monster_died)

	print("[GameScene] Monster system initialized")


## 初始化世界系统
func _init_world_system() -> void:
	# 创建房间管理器
	_room_manager = Node.new()
	_room_manager.name = "RoomManager"
	_room_manager.set_script(load("res://scripts/world/room_manager.gd"))
	add_child(_room_manager)

	# 创建房间图管理器
	_room_graph = Node.new()
	_room_graph.name = "RoomGraph"
	_room_graph.set_script(load("res://scripts/world/room_graph.gd"))
	add_child(_room_graph)

	# 创建AI内容服务
	_ai_content_service = Node.new()
	_ai_content_service.name = "AIContentService"
	_ai_content_service.set_script(load("res://scripts/ai/ai_content_service.gd"))
	add_child(_ai_content_service)

	# 设置AI服务类型为REAL（使用云端AI服务）
	# AIServiceType.REAL = 1
	_ai_content_service.set_service_type(_ai_content_service.AIServiceType.REAL)

	# 设置RoomGraph的AIContentService引用
	_room_graph.set_ai_content_service(_ai_content_service)

	# 设置玩家等级（从GameStateManager获取）
	var player_level = _player_data.get("level", 1)
	_room_graph.set_player_level(player_level)

	# 创建房间内容管理器
	_room_content_manager = Node.new()
	_room_content_manager.name = "RoomContentManager"
	_room_content_manager.set_script(load("res://scripts/world/room_content_manager.gd"))
	add_child(_room_content_manager)

	# 连接房间图信号
	_room_graph.room_graph_generated.connect(_on_room_graph_generated)
	_room_graph.current_room_changed.connect(_on_current_room_changed)

	# 设置RoomManager的RoomGraph引用
	_room_manager.set_room_graph(_room_graph)

	# 设置RoomManager的RoomContentManager引用
	_room_manager.set_room_content_manager(_room_content_manager)

	# 设置RoomContentManager的AIContentService引用
	_room_content_manager.set_ai_content_service(_ai_content_service)
	_room_content_manager.set_use_ai(true)

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

	# 连接房间管理器信号
	_room_manager.room_entered.connect(_on_room_entered)
	_room_manager.room_state_changed.connect(_on_room_state_changed)
	_room_manager.room_cleared.connect(_on_room_cleared)

	# 设置MonsterSpawner的RoomManager引用
	_monster_spawner.set_room_manager(_room_manager)

	# 生成房间图
	_room_graph.generate_new_floor(1)

	# 加载世界
	_world_manager.load_world()

	# 进入第一个房间
	_world_manager.enter_first_room()

	# 创建测试对象
	_create_test_objects()


## 创建测试对象
func _create_test_objects() -> void:
	# 创建测试宝箱1
	var chest1 = TestChest.new()
	chest1.object_name = "木制宝箱"
	chest1.set_position(Vector2(400, 300))

	var interactive1 = chest1.create_interactive_object()
	interactive1.set_linked_node(_create_placeholder_node("木制宝箱", Vector2(400, 300), Color(0.8, 0.6, 0.2, 1.0)))
	_object_manager.register_object(chest1)
	interaction_manager.register_object(interactive1)

	# 创建测试宝箱2
	var chest2 = TestChest.new()
	chest2.object_name = "铁制宝箱"
	chest2.set_position(Vector2(800, 500))

	var interactive2 = chest2.create_interactive_object()
	interactive2.set_linked_node(_create_placeholder_node("铁制宝箱", Vector2(800, 500), Color(0.6, 0.6, 0.7, 1.0)))
	_object_manager.register_object(chest2)
	interaction_manager.register_object(interactive2)

	# 创建武器拾取对象（使用ResourceService中的武器数据）
	var weapons = ResourceService.get_weapons()
	if weapons.size() > 0:
		var weapon1 = weapons[0]  # 第一把武器
		var weapon_obj1 = WeaponObject.new()
		weapon_obj1.set_weapon_data(weapon1)
		weapon_obj1.set_position(Vector2(300, 600))

		var interactive_weapon1 = weapon_obj1.create_interactive_object()
		interactive_weapon1.set_linked_node(_create_weapon_node(weapon1, Vector2(300, 600)))
		_object_manager.register_object(weapon_obj1)
		interaction_manager.register_object(interactive_weapon1)

	if weapons.size() > 1:
		var weapon2 = weapons[1]  # 第二把武器
		var weapon_obj2 = WeaponObject.new()
		weapon_obj2.set_weapon_data(weapon2)
		weapon_obj2.set_position(Vector2(700, 200))

		var interactive_weapon2 = weapon_obj2.create_interactive_object()
		interactive_weapon2.set_linked_node(_create_weapon_node(weapon2, Vector2(700, 200)))
		_object_manager.register_object(weapon_obj2)
		interaction_manager.register_object(interactive_weapon2)

	# 注意：怪物现在由房间系统自动生成
	print("[GameScene] Test objects created. Monsters will spawn when entering combat rooms.")


## 创建占位节点
func _create_placeholder_node(obj_name: String, pos: Vector2, color: Color) -> Node2D:
	var node = Node2D.new()
	node.name = obj_name
	node.position = pos

	# 创建可视化占位
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	var image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	node.add_child(sprite)

	# 创建Area2D用于交互检测
	var area = Area2D.new()
	area.name = "InteractionArea"
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 40.0
	collision.shape = shape
	area.add_child(collision)

	# 设置meta数据用于交互检测
	area.set_meta("interactive_object_id", _get_interactive_id_for_object(obj_name))
	node.add_child(area)

	add_child(node)
	return node


## 创建武器节点
func _create_weapon_node(weapon_data: WeaponData, pos: Vector2) -> Node2D:
	var node = Node2D.new()
	node.name = weapon_data.name
	node.position = pos

	# 创建可视化占位（不同稀有度不同颜色）
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	var image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	var color = _get_rarity_color(weapon_data.rarity)
	image.fill(color)
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	node.add_child(sprite)

	# 创建Area2D用于交互检测
	var area = Area2D.new()
	area.name = "InteractionArea"
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 40.0
	collision.shape = shape
	area.add_child(collision)

	# 设置meta数据用于交互检测
	area.set_meta("interactive_object_id", _get_interactive_id_for_object(weapon_data.name))
	node.add_child(area)

	add_child(node)
	return node


## 获取稀有度颜色
func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common":
			return Color(0.7, 0.7, 0.7, 1.0)  # 灰色
		"uncommon":
			return Color(0.2, 0.8, 0.2, 1.0)  # 绿色
		"rare":
			return Color(0.2, 0.4, 0.9, 1.0)  # 蓝色
		"epic":
			return Color(0.7, 0.2, 0.9, 1.0)  # 紫色
		"legendary":
			return Color(0.9, 0.6, 0.1, 1.0)  # 橙色
		_:
			return Color(0.7, 0.7, 0.7, 1.0)  # 默认灰色


## 获取对象对应的InteractiveObject ID
func _get_interactive_id_for_object(obj_name: String) -> int:
	for obj in interaction_manager.get_all_objects():
		if obj.object_name == obj_name:
			return obj.object_id
	return -1


## 输入处理
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
	elif event.is_action_pressed("interaction"):
		_try_interact()
	elif event.is_action_pressed("ui_accept"):  # N键或回车键
		_try_enter_next_room()
	elif event is InputEventKey and event.pressed:
		_handle_number_key(event)


## 处理数字键输入
func _handle_number_key(event: InputEventKey) -> void:
	# 数字键1-9选择房间
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var room_index = event.keycode - KEY_1
		_try_enter_room_by_index(room_index)


## 尝试进入下一房间
func _try_enter_next_room() -> void:
	if not _room_manager:
		return

	# 检查房间是否已清除
	if _room_manager.is_room_cleared():
		print("[GameScene] Entering next room...")
		_room_manager.enter_next_room()
	else:
		print("[GameScene] Room not cleared yet")


## 尝试进入指定索引的房间
func _try_enter_room_by_index(index: int) -> void:
	if not _room_graph:
		return

	# 获取可用房间
	var available = _room_graph.get_available_room_ids()

	# 检查索引是否有效
	if index < available.size():
		var room_id = available[index]
		print("[GameScene] Entering room: ", room_id)
		_room_manager.enter_room_by_id(room_id)
	else:
		print("[GameScene] Invalid room index: ", index)
	else:
		print("[GameScene] Room not cleared yet")


## 每帧处理
func _process(delta: float) -> void:
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


## 处理武器拾取
func _handle_weapon_pickup(weapon_obj: WeaponObject) -> void:
	var weapon_data = weapon_obj.get_weapon_data()
	if weapon_data:
		# 添加到背包
		_inventory_manager.add_weapon(weapon_data)

		# 同步到服务器
		_sync_weapon_to_server(weapon_data.id)

		# 更新HUD
		hud.set_status("获得武器: " + weapon_data.name + " (伤害: " + str(weapon_data.damage) + ")")


## 同步武器到服务器
func _sync_weapon_to_server(weapon_id: int) -> void:
	var data = {"weapon_id": weapon_id}
	ApiClient.post_request(APIConfig.PLAYER_WEAPONS, data, true)


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
		# 检查是否是WeaponObject
		var game_obj = _find_game_object_by_interactive_id(object_id)
		if game_obj and game_obj is WeaponObject:
			_handle_weapon_pickup(game_obj)
		else:
			hud.set_status("交互: " + obj.object_name)

		# 完成交互
		interaction_manager.complete_interaction(object_id)


## 根据InteractiveObject ID查找GameObject
func _find_game_object_by_interactive_id(interactive_id: int) -> GameObject:
	for obj in _object_manager.get_all_objects():
		if obj.has_interactive_object() and obj.get_interactive_object().object_id == interactive_id:
			return obj
	return null


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


## 怪物生成回调
func _on_monster_spawned(monster_entity: MonsterEntity) -> void:
	print("[GameScene] Monster spawned: ", monster_entity.get_monster_name())
	hud.set_status("怪物出现了: " + monster_entity.get_monster_name())


## 所有怪物死亡回调
func _on_all_monsters_dead() -> void:
	print("[GameScene] All monsters defeated!")
	hud.set_status("所有怪物已被消灭！")


## 怪物死亡回调
func _on_monster_died(monster_entity: MonsterEntity) -> void:
	print("[GameScene] Monster died: ", monster_entity.get_monster_name())


## 房间进入回调
func _on_room_entered(room_data: RoomData) -> void:
	print("[GameScene] Room entered: ", room_data.room_name)

	# 获取房间内容数据
	var content = _room_manager.get_current_content()
	if not content:
		print("[GameScene] No content data for room")
		return

	print("[GameScene] Room content: monsters=", content.monster_count, " rewards=", content.reward_count)

	# 根据房间内容生成怪物
	if content.monster_count > 0:
		var room_position = room_data.position
		var room_size = Vector2(room_data.width, room_data.height)

		# 使用MonsterSpawner生成怪物
		var monster_count = _monster_spawner.spawn_monsters_from_content(content, room_position, room_size)

		# 开始房间战斗
		if monster_count > 0:
			_room_manager.start_room_combat(monster_count)
		else:
			print("[GameScene] No monsters spawned")
	else:
		print("[GameScene] No monsters in this room")


## 房间状态变化回调
func _on_room_state_changed(new_state: int) -> void:
	match new_state:
		0:  # EMPTY
			hud.set_status("房间状态: 空")
		1:  # SPAWNING
			hud.set_status("房间状态: 生成怪物中...")
		2:  # COMBAT
			hud.set_status("房间状态: 战斗中！")
		3:  # CLEARED
			hud.set_status("房间状态: 已清除！可以进入下一房间")
		4:  # REWARD
			hud.set_status("房间状态: 奖励阶段")


## 房间清除回调
func _on_room_cleared() -> void:
	print("[GameScene] Room cleared!")
	hud.set_status("房间已清除！拾取奖励后按N进入下一房间")

	# 获取房间内容数据
	var content = _room_manager.get_current_content()

	# 生成奖励
	if _drop_manager and _room_manager:
		var current_room = _room_manager.get_current_room()
		if current_room:
			var room_position = current_room.position

			# 使用RoomContentData生成奖励
			if content and content.reward_count > 0:
				_drop_manager.spawn_rewards_from_content(content, room_position)
			else:
				# 默认生成3个奖励
				_drop_manager.spawn_rewards_for_room(room_position, 3)


## 奖励收集回调
func _on_reward_collected(reward_data: RewardData) -> void:
	print("[GameScene] Reward collected: ", reward_data.name)
	hud.set_status("获得: " + reward_data.description)

	# 更新玩家显示
	_player_data = player.get_player_data()
	_update_game_display()


## 所有奖励收集完成回调
func _on_all_rewards_collected() -> void:
	print("[GameScene] All rewards collected!")
	hud.set_status("所有奖励已收集！按N进入下一房间")


## 房间图生成回调
func _on_room_graph_generated() -> void:
	print("[GameScene] Room graph generated")
	if _room_graph:
		_room_graph.print_status()
		hud.set_status("房间图已生成！当前房间: " + str(_room_graph.get_current_room_id()))


## 当前房间变化回调
func _on_current_room_changed(old_id: int, new_id: int) -> void:
	print("[GameScene] Current room changed: ", old_id, " -> ", new_id)
	if _room_graph:
		var available = _room_graph.get_available_room_ids()
		print("[GameScene] Available rooms: ", available)
		hud.set_status("当前房间: " + str(new_id) + " | 可用房间: " + str(available))

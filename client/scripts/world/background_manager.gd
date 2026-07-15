## 背景管理器 (Phase 17.2)
##
## 负责生成和管理视差背景
## 使用Parallax2D实现远近层次效果
##
## 背景结构:
## Background
## ├── FarLayer (远山/天空)
## ├── MiddleLayer (中景建筑/岩石)
## └── ForegroundLayer (前景装饰)

extends Node

## ==================== 配置 ====================

## 远景滚动速度 (相对于摄像机)
const FAR_SCROLL_SPEED: float = 0.1

## 中景滚动速度
const MIDDLE_SCROLL_SPEED: float = 0.3

## 前景滚动速度
const FOREGROUND_SCROLL_SPEED: float = 0.6

## ==================== 引用 ====================

## 当前背景节点
var _current_background: Node2D = null

## 房间容器
var _room_container: Node2D = null

## ==================== 初始化 ====================

func set_room_container(container: Node2D) -> void:
	_room_container = container


## ==================== 背景生成 ====================

## 生成视差背景
func spawn_background(room_type: NewRoomData.RoomType, room_position: Vector2) -> void:
	if not _room_container:
		print("[BackgroundManager] Error: No room container")
		return

	# 清除旧背景
	clear_background()

	# 创建背景根节点
	var bg_node = Node2D.new()
	bg_node.name = "ParallaxBackground"
	bg_node.position = room_position
	bg_node.z_index = -20  # 在所有元素之下

	# 根据房间类型生成不同背景
	match room_type:
		NewRoomData.RoomType.START:
			_create_forest_background(bg_node)
		NewRoomData.RoomType.COMBAT:
			_create_dungeon_background(bg_node)
		NewRoomData.RoomType.ELITE:
			_create_elite_background(bg_node)
		NewRoomData.RoomType.BOSS:
			_create_boss_background(bg_node)
		NewRoomData.RoomType.REWARD:
			_create_reward_background(bg_node)
		_:
			_create_dungeon_background(bg_node)

	_room_container.add_child(bg_node)
	_current_background = bg_node

	print("[BackgroundManager] Spawned background for room type: ", _get_type_name(room_type))


## 清除背景
func clear_background() -> void:
	if _current_background and _current_background.is_inside_tree():
		_current_background.queue_free()
		_current_background = null


## ==================== 背景类型 ====================

## 森林背景 (起始房间)
func _create_forest_background(parent: Node2D) -> void:
	# 远景: 天空渐变
	var sky = _create_sky_layer(Color(0.1, 0.15, 0.2), Color(0.2, 0.3, 0.4))
	parent.add_child(sky)

	# 中景: 远山
	var mountains = _create_mountains_layer(Color(0.15, 0.2, 0.15), 200)
	parent.add_child(mountains)

	# 前景: 树木轮廓
	var trees = _create_trees_layer(Color(0.1, 0.15, 0.1))
	parent.add_child(trees)


## 地牢背景 (战斗房间)
func _create_dungeon_background(parent: Node2D) -> void:
	# 远景: 深色背景
	var dark_bg = _create_sky_layer(Color(0.05, 0.05, 0.08), Color(0.08, 0.08, 0.12))
	parent.add_child(dark_bg)

	# 中景: 石柱
	var pillars = _create_pillars_layer(Color(0.12, 0.1, 0.08), 150)
	parent.add_child(pillars)

	# 前景: 火把装饰
	var torches = _create_torches_layer()
	parent.add_child(torches)


## 精英房间背景
func _create_elite_background(parent: Node2D) -> void:
	# 远景: 紫色调
	var purple_bg = _create_sky_layer(Color(0.1, 0.05, 0.15), Color(0.15, 0.08, 0.2))
	parent.add_child(purple_bg)

	# 中景: 水晶
	var crystals = _create_crystals_layer(Color(0.3, 0.1, 0.4))
	parent.add_child(crystals)


## Boss房间背景
func _create_boss_background(parent: Node2D) -> void:
	# 远景: 深红色
	var red_bg = _create_sky_layer(Color(0.15, 0.03, 0.03), Color(0.2, 0.05, 0.05))
	parent.add_child(red_bg)

	# 中景: 岩浆裂纹
	var lava = _create_lava_layer()
	parent.add_child(lava)

	# 前景: 柱子
	var boss_pillars = _create_pillars_layer(Color(0.2, 0.1, 0.08), 250)
	parent.add_child(boss_pillars)


## 奖励房间背景
func _create_reward_background(parent: Node2D) -> void:
	# 远景: 金色调
	var gold_bg = _create_sky_layer(Color(0.1, 0.1, 0.05), Color(0.15, 0.15, 0.08))
	parent.add_child(gold_bg)

	# 中景: 宝箱装饰
	var treasure = _create_treasure_layer()
	parent.add_child(treasure)


## ==================== 层生成工具 ====================

## 创建天空层
func _create_sky_layer(color_bottom: Color, color_top: Color) -> Node2D:
	var layer = Node2D.new()
	layer.name = "SkyLayer"

	# 使用渐变色块模拟天空
	var gradient = ColorRect.new()
	gradient.name = "Gradient"
	gradient.size = Vector2(1600, 800)
	gradient.position = Vector2(-800, -400)
	gradient.color = color_bottom.lerp(color_top, 0.5)
	layer.add_child(gradient)

	# 添加星星/粒子装饰
	for i in range(20):
		var star = ColorRect.new()
		star.name = "Star_" + str(i)
		star.size = Vector2(2, 2)
		star.position = Vector2(
			randf_range(-700, 700),
			randf_range(-350, -100)
		)
		star.color = Color(1, 1, 1, randf_range(0.3, 0.8))
		layer.add_child(star)

	return layer


## 创建山脉层
func _create_mountains_layer(color: Color, height: float) -> Node2D:
	var layer = Node2D.new()
	layer.name = "MountainsLayer"

	# 创建多个山峰
	for i in range(5):
		var mountain = Polygon2D.new()
		mountain.name = "Mountain_" + str(i)
		var x_pos = -600 + i * 300
		var peak_height = randf_range(height * 0.7, height)

		mountain.polygon = PackedVector2Array([
			Vector2(x_pos - 100, 100),
			Vector2(x_pos, 100 - peak_height),
			Vector2(x_pos + 100, 100)
		])
		mountain.color = color.lightened(randf_range(0, 0.2))
		layer.add_child(mountain)

	return layer


## 创建树木层
func _create_trees_layer(color: Color) -> Node2D:
	var layer = Node2D.new()
	layer.name = "TreesLayer"

	# 创建树干和树冠
	for i in range(8):
		var x_pos = -600 + i * 150 + randf_range(-30, 30)

		# 树干
		var trunk = ColorRect.new()
		trunk.name = "Trunk_" + str(i)
		trunk.size = Vector2(8, 40)
		trunk.position = Vector2(x_pos - 4, 60)
		trunk.color = Color(0.2, 0.15, 0.1)
		layer.add_child(trunk)

		# 树冠
		var crown = Polygon2D.new()
		crown.name = "Crown_" + str(i)
		crown.polygon = PackedVector2Array([
			Vector2(x_pos - 20, 60),
			Vector2(x_pos, 20),
			Vector2(x_pos + 20, 60)
		])
		crown.color = color.lightened(randf_range(0, 0.15))
		layer.add_child(crown)

	return layer


## 创建石柱层
func _create_pillars_layer(color: Color, height: float) -> Node2D:
	var layer = Node2D.new()
	layer.name = "PillarsLayer"

	# 创建石柱
	for i in range(4):
		var x_pos = -400 + i * 250

		var pillar = ColorRect.new()
		pillar.name = "Pillar_" + str(i)
		pillar.size = Vector2(30, height)
		pillar.position = Vector2(x_pos - 15, 100 - height)
		pillar.color = color.lightened(randf_range(0, 0.1))
		layer.add_child(pillar)

		# 柱头
		var cap = ColorRect.new()
		cap.name = "Cap_" + str(i)
		cap.size = Vector2(40, 10)
		cap.position = Vector2(x_pos - 20, 100 - height - 10)
		cap.color = color.lightened(0.2)
		layer.add_child(cap)

	return layer


## 创建火把层
func _create_torches_layer() -> Node2D:
	var layer = Node2D.new()
	layer.name = "TorchesLayer"

	# 火把位置
	var torch_positions = [
		Vector2(-300, -50),
		Vector2(-100, -80),
		Vector2(100, -50),
		Vector2(300, -80)
	]

	for i in range(torch_positions.size()):
		var pos = torch_positions[i]

		# 火把底座
		var base = ColorRect.new()
		base.name = "TorchBase_" + str(i)
		base.size = Vector2(6, 20)
		base.position = pos + Vector2(-3, 0)
		base.color = Color(0.3, 0.2, 0.1)
		layer.add_child(base)

		# 火焰
		var flame = ColorRect.new()
		flame.name = "Flame_" + str(i)
		flame.size = Vector2(10, 12)
		flame.position = pos + Vector2(-5, -12)
		flame.color = Color(1.0, 0.6, 0.1, 0.8)
		layer.add_child(flame)

	return layer


## 创建水晶层
func _create_crystals_layer(color: Color) -> Node2D:
	var layer = Node2D.new()
	layer.name = "CrystalsLayer"

	# 水晶位置
	var crystal_positions = [
		Vector2(-400, 50),
		Vector2(-200, 30),
		Vector2(0, 60),
		Vector2(200, 40),
		Vector2(400, 55)
	]

	for i in range(crystal_positions.size()):
		var pos = crystal_positions[i]
		var height = randf_range(30, 60)

		var crystal = Polygon2D.new()
		crystal.name = "Crystal_" + str(i)
		crystal.polygon = PackedVector2Array([
			Vector2(pos.x - 8, pos.y),
			Vector2(pos.x, pos.y - height),
			Vector2(pos.x + 8, pos.y)
		])
		crystal.color = color.lightened(randf_range(0, 0.3))
		layer.add_child(crystal)

	return layer


## 创建岩浆层
func _create_lava_layer() -> Node2D:
	var layer = Node2D.new()
	layer.name = "LavaLayer"

	# 岩浆裂纹
	for i in range(6):
		var x_pos = -500 + i * 200

		var crack = Polygon2D.new()
		crack.name = "Crack_" + str(i)
		crack.polygon = PackedVector2Array([
			Vector2(x_pos - 30, 120),
			Vector2(x_pos - 10, 110),
			Vector2(x_pos + 10, 115),
			Vector2(x_pos + 30, 108)
		])
		crack.color = Color(1.0, 0.3, 0.0, 0.6)
		layer.add_child(crack)

	return layer


## 创建宝箱装饰层
func _create_treasure_layer() -> Node2D:
	var layer = Node2D.new()
	layer.name = "TreasureLayer"

	# 宝箱位置
	var chest_positions = [
		Vector2(-200, 80),
		Vector2(0, 90),
		Vector2(200, 80)
	]

	for i in range(chest_positions.size()):
		var pos = chest_positions[i]

		# 宝箱主体
		var chest = ColorRect.new()
		chest.name = "Chest_" + str(i)
		chest.size = Vector2(24, 18)
		chest.position = pos + Vector2(-12, -18)
		chest.color = Color(0.6, 0.4, 0.1)
		layer.add_child(chest)

		# 宝箱盖
		var lid = ColorRect.new()
		lid.name = "Lid_" + str(i)
		lid.size = Vector2(26, 6)
		lid.position = pos + Vector2(-13, -24)
		lid.color = Color(0.7, 0.5, 0.15)
		layer.add_child(lid)

	return layer


## ==================== 工具函数 ====================

func _get_type_name(room_type: NewRoomData.RoomType) -> String:
	match room_type:
		NewRoomData.RoomType.START: return "start"
		NewRoomData.RoomType.COMBAT: return "combat"
		NewRoomData.RoomType.ELITE: return "elite"
		NewRoomData.RoomType.BOSS: return "boss"
		NewRoomData.RoomType.REWARD: return "reward"
		_: return "unknown"

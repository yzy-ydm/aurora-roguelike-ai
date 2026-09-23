## 房间装饰管理器 (Phase 16.1)
##
## 根据RoomType随机生成装饰物
## 提升房间视觉层次和氛围
##
## 职责:
## - 根据房间类型生成装饰
## - 管理装饰物生命周期
## - 不影响游戏逻辑

extends Node

## ==================== 配置 ====================

## 装饰物数量范围
const DECORATION_COUNT = {
	"start": {"min": 2, "max": 4},
	"combat": {"min": 3, "max": 6},
	"elite": {"min": 2, "max": 5},
	"boss": {"min": 4, "max": 8},
	"reward": {"min": 3, "max": 6},
	"shop": {"min": 2, "max": 4},
	"event": {"min": 2, "max": 5},
	"treasure": {"min": 3, "max": 6}
}

## 装饰物颜色方案
const DECORATION_COLORS = {
	"start": [Color(0.3, 0.5, 0.3), Color(0.4, 0.6, 0.4)],
	"combat": [Color(0.6, 0.3, 0.3), Color(0.5, 0.2, 0.2), Color(0.4, 0.15, 0.15)],
	"elite": [Color(0.5, 0.3, 0.5), Color(0.6, 0.4, 0.6)],
	"boss": [Color(0.7, 0.2, 0.2), Color(0.8, 0.3, 0.3), Color(0.9, 0.4, 0.4)],
	"reward": [Color(0.8, 0.7, 0.2), Color(0.9, 0.8, 0.3), Color(1.0, 0.9, 0.4)],
	"shop": [Color(0.3, 0.5, 0.7), Color(0.4, 0.6, 0.8)],
	"event": [Color(0.6, 0.5, 0.3), Color(0.7, 0.6, 0.4)],
	"treasure": [Color(0.8, 0.6, 0.2), Color(0.9, 0.7, 0.3)]
}

## ==================== 引用 ====================

## 装饰容器
var _decoration_container: Node2D = null

## 当前装饰列表
var _current_decorations: Array[Node2D] = []

## ==================== 初始化 ====================

func set_decoration_container(container: Node2D) -> void:
	_decoration_container = container


## ==================== 装饰生成 ====================

## 生成房间装饰
func spawn_decorations(room_type: NewRoomData.RoomType, room_center: Vector2) -> void:
	if not _decoration_container:
		print("[RoomDecoration] Error: No decoration container")
		return

	# 清除旧装饰
	clear_decorations()

	# 获取房间类型字符串
	var type_string = _get_type_string(room_type)

	# 获取装饰数量
	var count_config = DECORATION_COUNT.get(type_string, {"min": 2, "max": 4})
	var decoration_count = randi_range(count_config.min, count_config.max)

	# 获取颜色方案
	var colors = DECORATION_COLORS.get(type_string, [Color(0.5, 0.5, 0.5)])

	print("[RoomDecoration] Spawning ", decoration_count, " decorations for ", type_string)

	# 生成装饰
	for i in range(decoration_count):
		var pos = _get_random_position(room_center)
		var color = colors[randi() % colors.size()]
		var size = _get_random_size(room_type)

		_create_decoration(pos, color, size, type_string)

	print("[RoomDecoration] Spawned ", _current_decorations.size(), " decorations")


## 创建单个装饰
func _create_decoration(pos: Vector2, color: Color, size: Vector2, type_string: String) -> void:
	var decoration = Node2D.new()
	decoration.name = "Decoration_" + str(_current_decorations.size())
	decoration.position = pos

	# 创建装饰精灵
	var sprite = Sprite2D.new()
	var image = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)

	# 根据类型填充不同图案
	match type_string:
		"combat":
			_fill_combat_pattern(image, color)
		"boss":
			_fill_boss_pattern(image, color)
		"reward":
			_fill_reward_pattern(image, color)
		_:
			image.fill(color)

	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	sprite.z_index = -5  # 在背景之上，游戏对象之下

	decoration.add_child(sprite)
	_decoration_container.add_child(decoration)
	_current_decorations.append(decoration)


## 填充战斗房间图案
func _fill_combat_pattern(image: Image, color: Color) -> void:
	var width = image.get_width()
	var height = image.get_height()

	for x in range(width):
		for y in range(height):
			# 创建石头纹理
			var noise = randf()
			if noise > 0.7:
				image.set_pixel(x, y, color.darkened(0.3))
			elif noise > 0.4:
				image.set_pixel(x, y, color)
			else:
				image.set_pixel(x, y, color.lightened(0.2))


## 填充Boss房间图案
func _fill_boss_pattern(image: Image, color: Color) -> void:
	var width = image.get_width()
	var height = image.get_height()

	for x in range(width):
		for y in range(height):
			# 创建火焰纹理
			var dist_from_center = Vector2(x - width/2, y - height/2).length()
			var normalized_dist = dist_from_center / (width/2)

			if normalized_dist < 0.3:
				image.set_pixel(x, y, color.lightened(0.5))
			elif normalized_dist < 0.6:
				image.set_pixel(x, y, color)
			else:
				image.set_pixel(x, y, color.darkened(0.3))


## 填充奖励房间图案
func _fill_reward_pattern(image: Image, color: Color) -> void:
	var width = image.get_width()
	var height = image.get_height()

	for x in range(width):
		for y in range(height):
			# 创建闪光纹理
			var time = Time.get_ticks_msec() / 1000.0
			var shimmer = sin(x * 0.5 + y * 0.3 + time) * 0.3 + 0.7

			var pixel_color = color
			pixel_color.r *= shimmer
			pixel_color.g *= shimmer
			pixel_color.b *= shimmer

			image.set_pixel(x, y, pixel_color)


## ==================== 位置计算 ====================

## 获取随机位置（避开中心玩家区域）
func _get_random_position(room_center: Vector2) -> Vector2:
	var hw = WorldCoordinate.HALF_WIDTH
	var hh = WorldCoordinate.HALF_HEIGHT

	# Phase 26: 返回local坐标（相对于房间中心），而不是world坐标
	# 避开中心区域（玩家可能站立的地方）
	var margin = 80.0
	var x = randf_range(-hw + margin, hw - margin)
	var y = randf_range(-hh + margin, hh - margin)

	# 确保不在中心区域
	while abs(x) < 60 and abs(y) < 60:
		x = randf_range(-hw + margin, hw - margin)
		y = randf_range(-hh + margin, hh - margin)

	return Vector2(x, y)  # Phase 26: 返回local坐标


## 获取随机大小
func _get_random_size(room_type: NewRoomData.RoomType) -> Vector2:
	match room_type:
		NewRoomData.RoomType.BOSS:
			return Vector2(randf_range(30, 60), randf_range(30, 60))
		NewRoomData.RoomType.REWARD:
			return Vector2(randf_range(20, 40), randf_range(20, 40))
		_:
			return Vector2(randf_range(15, 35), randf_range(15, 35))


## ==================== 清理 ====================

## 清除所有装饰
func clear_decorations() -> void:
	for decoration in _current_decorations:
		if decoration and decoration.is_inside_tree():
			decoration.queue_free()
	_current_decorations.clear()


## ==================== 工具函数 ====================

## 获取房间类型字符串
func _get_type_string(room_type: NewRoomData.RoomType) -> String:
	match room_type:
		NewRoomData.RoomType.START:
			return "start"
		NewRoomData.RoomType.COMBAT:
			return "combat"
		NewRoomData.RoomType.ELITE:
			return "elite"
		NewRoomData.RoomType.BOSS:
			return "boss"
		NewRoomData.RoomType.REWARD:
			return "reward"
		NewRoomData.RoomType.SHOP:
			return "shop"
		NewRoomData.RoomType.EVENT:
			return "event"
		NewRoomData.RoomType.TREASURE:
			return "treasure"
		_:
			return "combat"

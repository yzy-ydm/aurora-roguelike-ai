## 奖励物品脚本 (Phase 16.2.2 视觉升级)
##
## 玩家接近时自动拾取
## 根据奖励类型显示不同像素艺术Sprite
##
## Phase 16.2.2:
## - 为每种奖励类型生成独特像素艺术纹理
## - 增加旋转动画
## - 增加发光脉冲效果
## - 保留浮动动画和拾取逻辑

extends Area2D

## 奖励数据
var _reward_data: RewardData = null

## 是否已收集
var _collected: bool = false

## 浮动动画
var _float_time: float = 0.0
var _float_speed: float = 2.0
var _float_height: float = 5.0
var _start_position: Vector2 = Vector2.ZERO

## 旋转动画
var _rotation_speed: float = 0.5

## 发光脉冲
var _glow_time: float = 0.0
var _glow_speed: float = 3.0

## 节点引用
@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape

## 信号
signal reward_collected(reward_data: RewardData)


## 初始化
func _ready() -> void:
	# 碰撞层: 检测Player(Layer 2)进入拾取范围
	collision_layer = 0  # 奖励本身不需要被检测
	collision_mask = 2   # 检测Player(Layer 2)

	# 设置碰撞检测
	body_entered.connect(_on_body_entered)

	# 创建外观
	_setup_appearance()

	# 记录起始位置
	_start_position = position


## 每帧更新
func _process(delta: float) -> void:
	if _collected:
		return

	# 浮动动画
	_float_time += delta * _float_speed
	position.y = _start_position.y + sin(_float_time) * _float_height

	# 轻微旋转
	if sprite:
		sprite.rotation += delta * _rotation_speed

	# 发光脉冲效果
	_glow_time += delta * _glow_speed
	if sprite:
		var glow = 0.85 + sin(_glow_time) * 0.15
		sprite.modulate.a = glow


## 设置奖励数据
func set_reward_data(data: RewardData) -> void:
	_reward_data = data
	_update_appearance()


## 设置外观 (Phase 16.2.2: 生成像素艺术纹理)
func _setup_appearance() -> void:
	if not sprite:
		push_warning("[RewardItem] Sprite node not found")
		return

	# 默认纹理 (白色方块，等待 set_reward_data 替换)
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture

	# 创建碰撞形状
	if collision_shape:
		var shape = CircleShape2D.new()
		shape.radius = 20.0
		collision_shape.set_deferred("shape", shape)


## 更新外观 (Phase 16.2.2: 根据类型生成像素艺术)
func _update_appearance() -> void:
	if not _reward_data:
		return
	if not sprite:
		push_warning("[RewardItem] Sprite node not found")
		return

	# 生成类型专属像素艺术纹理
	var texture = _generate_reward_texture(_reward_data.type)
	sprite.texture = texture

	# 保留颜色叠加 (轻微着色)
	sprite.modulate = _reward_data.color.lerp(Color.WHITE, 0.3)

	# 根据类型调整旋转速度
	match _reward_data.type:
		RewardData.RewardType.GOLD:
			_rotation_speed = 0.8  # 金币转快一点
		RewardData.RewardType.WEAPON_UPGRADE:
			_rotation_speed = 0.3  # 武器升级慢一点
		RewardData.RewardType.NEW_WEAPON:
			_rotation_speed = 0.3
		_:
			_rotation_speed = 0.5


## ==================== 像素艺术生成 ====================

## 生成奖励类型专属纹理
func _generate_reward_texture(type: RewardData.RewardType) -> Texture2D:
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)

	match type:
		RewardData.RewardType.GOLD:
			_draw_gold_coin(image)
		RewardData.RewardType.ATTACK_UP:
			_draw_attack_boost(image)
		RewardData.RewardType.HEALTH_UP:
			_draw_health_boost(image)
		RewardData.RewardType.HEAL:
			_draw_heal_potion(image)
		RewardData.RewardType.WEAPON_UPGRADE:
			_draw_weapon_upgrade(image)
		RewardData.RewardType.ATTRIBUTE_BOOST:
			_draw_attribute_boost(image)
		RewardData.RewardType.NEW_WEAPON:
			_draw_new_weapon(image)
		RewardData.RewardType.PASSIVE_ITEM:
			_draw_passive_item(image)
		_:
			image.fill(Color.WHITE)

	return ImageTexture.create_from_image(image)


## 金币: 金色圆形 + ¥符号
func _draw_gold_coin(image: Image) -> void:
	var gold = Color(1.0, 0.84, 0.0)
	var gold_dark = Color(0.85, 0.68, 0.0)
	var gold_light = Color(1.0, 0.95, 0.5)

	# 圆形主体
	_fill_circle(image, 8, 8, 6, gold)
	# 边缘暗色
	_set_pixel(image, 3, 6, gold_dark)
	_set_pixel(image, 3, 7, gold_dark)
	_set_pixel(image, 3, 8, gold_dark)
	_set_pixel(image, 3, 9, gold_dark)
	_set_pixel(image, 12, 6, gold_dark)
	_set_pixel(image, 12, 7, gold_dark)
	_set_pixel(image, 12, 8, gold_dark)
	_set_pixel(image, 12, 9, gold_dark)
	# 高光
	_set_pixel(image, 6, 4, gold_light)
	_set_pixel(image, 7, 4, gold_light)
	_set_pixel(image, 5, 5, gold_light)
	# $ 符号简化
	_set_pixel(image, 7, 6, gold_dark)
	_set_pixel(image, 8, 6, gold_dark)
	_set_pixel(image, 6, 7, gold_dark)
	_set_pixel(image, 7, 8, gold_dark)
	_set_pixel(image, 8, 8, gold_dark)
	_set_pixel(image, 9, 9, gold_dark)
	_set_pixel(image, 7, 10, gold_dark)
	_set_pixel(image, 8, 10, gold_dark)


## 攻击强化: 红色剑形
func _draw_attack_boost(image: Image) -> void:
	var red = Color(0.9, 0.2, 0.2)
	var red_light = Color(1.0, 0.4, 0.4)
	var gray = Color(0.6, 0.6, 0.6)

	# 剑身
	for i in range(4, 13):
		_set_pixel(image, 8, i, red)
		_set_pixel(image, 7, i, red)
	# 剑尖
	_set_pixel(image, 8, 3, red_light)
	_set_pixel(image, 7, 3, red_light)
	_set_pixel(image, 8, 2, red_light)
	# 剑柄横档
	_fill_pixels(image, 5, 11, 6, gray)
	# 剑柄
	_set_pixel(image, 8, 12, gray)
	_set_pixel(image, 7, 12, gray)
	_set_pixel(image, 8, 13, gray)
	_set_pixel(image, 7, 13, gray)


## 生命强化: 绿色心形
func _draw_health_boost(image: Image) -> void:
	var green = Color(0.2, 0.9, 0.2)
	var green_light = Color(0.5, 1.0, 0.5)

	# 心形
	_set_pixel(image, 4, 5, green)
	_set_pixel(image, 5, 4, green)
	_set_pixel(image, 6, 4, green)
	_set_pixel(image, 9, 4, green)
	_set_pixel(image, 10, 4, green)
	_set_pixel(image, 11, 5, green)
	_fill_pixels(image, 3, 6, 10, green)
	_fill_pixels(image, 4, 7, 8, green)
	_fill_pixels(image, 5, 8, 6, green)
	_fill_pixels(image, 6, 9, 4, green)
	_fill_pixels(image, 7, 10, 2, green)
	# 高光
	_set_pixel(image, 5, 5, green_light)
	_set_pixel(image, 5, 6, green_light)


## 治疗药水: 青色瓶子
func _draw_heal_potion(image: Image) -> void:
	var cyan = Color(0.2, 0.8, 0.9)
	var cyan_light = Color(0.5, 1.0, 1.0)
	var gray = Color(0.5, 0.5, 0.5)

	# 瓶口
	_fill_pixels(image, 6, 2, 4, gray)
	_fill_pixels(image, 6, 3, 4, gray)
	# 瓶颈
	_fill_pixels(image, 7, 4, 2, cyan)
	# 瓶身
	_fill_pixels(image, 5, 5, 6, cyan)
	_fill_pixels(image, 4, 6, 8, cyan)
	_fill_pixels(image, 4, 7, 8, cyan)
	_fill_pixels(image, 4, 8, 8, cyan)
	_fill_pixels(image, 4, 9, 8, cyan)
	_fill_pixels(image, 5, 10, 6, cyan)
	_fill_pixels(image, 6, 11, 4, cyan)
	# 高光
	_set_pixel(image, 5, 6, cyan_light)
	_set_pixel(image, 5, 7, cyan_light)
	_set_pixel(image, 6, 6, cyan_light)
	# 十字标记
	_set_pixel(image, 7, 7, Color.WHITE)
	_set_pixel(image, 8, 7, Color.WHITE)
	_set_pixel(image, 7, 8, Color.WHITE)
	_set_pixel(image, 8, 8, Color.WHITE)


## 武器升级: 橙色上箭头
func _draw_weapon_upgrade(image: Image) -> void:
	var orange = Color(1.0, 0.6, 0.1)
	var orange_light = Color(1.0, 0.8, 0.4)

	# 上箭头
	_set_pixel(image, 8, 2, orange_light)
	_fill_pixels(image, 7, 3, 3, orange_light)
	_fill_pixels(image, 6, 4, 5, orange)
	_fill_pixels(image, 5, 5, 7, orange)
	# 箭杆
	_fill_pixels(image, 7, 6, 3, orange)
	_fill_pixels(image, 7, 7, 3, orange)
	_fill_pixels(image, 7, 8, 3, orange)
	_fill_pixels(image, 7, 9, 3, orange)
	_fill_pixels(image, 7, 10, 3, orange)
	# 底座
	_fill_pixels(image, 5, 11, 7, orange)
	_fill_pixels(image, 5, 12, 7, orange)


## 属性强化: 紫色菱形宝石
func _draw_attribute_boost(image: Image) -> void:
	var purple = Color(0.7, 0.3, 0.9)
	var purple_light = Color(0.9, 0.5, 1.0)
	var purple_dark = Color(0.5, 0.1, 0.7)

	# 菱形
	_set_pixel(image, 8, 2, purple_light)
	_fill_pixels(image, 7, 3, 3, purple_light)
	_fill_pixels(image, 6, 4, 5, purple)
	_fill_pixels(image, 5, 5, 7, purple)
	_fill_pixels(image, 4, 6, 9, purple)
	_fill_pixels(image, 4, 7, 9, purple)
	_fill_pixels(image, 5, 8, 7, purple)
	_fill_pixels(image, 6, 9, 5, purple)
	_fill_pixels(image, 7, 10, 3, purple)
	_fill_pixels(image, 8, 11, 1, purple_dark)
	# 高光
	_set_pixel(image, 6, 5, purple_light)
	_set_pixel(image, 7, 4, purple_light)
	_set_pixel(image, 5, 6, purple_light)
	# 内部光芒
	_set_pixel(image, 7, 6, purple_light)
	_set_pixel(image, 8, 7, purple_light)


## 新武器: 青色双剑
func _draw_new_weapon(image: Image) -> void:
	var cyan = Color(0.1, 0.8, 0.9)
	var cyan_light = Color(0.4, 1.0, 1.0)
	var gray = Color(0.6, 0.6, 0.6)

	# 左剑
	_set_pixel(image, 4, 3, cyan_light)
	_set_pixel(image, 5, 4, cyan)
	_set_pixel(image, 6, 5, cyan)
	_set_pixel(image, 7, 6, cyan)
	_set_pixel(image, 8, 7, gray)
	# 右剑
	_set_pixel(image, 11, 3, cyan_light)
	_set_pixel(image, 10, 4, cyan)
	_set_pixel(image, 9, 5, cyan)
	_set_pixel(image, 8, 6, cyan)
	_set_pixel(image, 7, 7, gray)
	# 剑柄
	_set_pixel(image, 9, 8, gray)
	_set_pixel(image, 6, 8, gray)


## 被动物品: 白色星星
func _draw_passive_item(image: Image) -> void:
	var white = Color(0.95, 0.95, 0.95)
	var yellow = Color(1.0, 1.0, 0.7)

	# 星形
	_set_pixel(image, 8, 1, yellow)
	_set_pixel(image, 8, 2, white)
	_fill_pixels(image, 7, 3, 3, white)
	_fill_pixels(image, 2, 6, 12, white)
	_fill_pixels(image, 3, 7, 10, white)
	_fill_pixels(image, 4, 8, 8, white)
	_fill_pixels(image, 5, 9, 6, white)
	_fill_pixels(image, 4, 10, 8, white)
	_fill_pixels(image, 3, 11, 10, white)
	# 中心高光
	_set_pixel(image, 7, 6, yellow)
	_set_pixel(image, 8, 6, yellow)
	_set_pixel(image, 7, 7, yellow)
	_set_pixel(image, 8, 7, yellow)


## ==================== 辅助函数 ====================

## 填充水平像素行
func _fill_pixels(image: Image, x: int, y: int, width: int, color: Color) -> void:
	for i in range(width):
		_set_pixel(image, x + i, y, color)


## 填充圆形区域
func _fill_circle(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for x in range(16):
		for y in range(16):
			var dist = Vector2(x - cx, y - cy).length()
			if dist <= radius:
				_set_pixel(image, x, y, color)


## 设置单个像素 (带边界检查)
func _set_pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < 16 and y >= 0 and y < 16:
		image.set_pixel(x, y, color)


## ==================== 碰撞检测 ====================

## 碰撞检测
func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return

	# 检查是否是玩家
	if body.name == "Player" or body.has_method("get_player_data"):
		call_deferred("_collect", body)


## 收集奖励
func _collect(collector: Node2D) -> void:
	if _collected:
		return

	_collected = true
	print("[Reward] Collected: ", _reward_data.name)

	# 显示属性变化提示
	_spawn_attribute_popup(collector)

	# 应用奖励到玩家
	if _reward_data:
		_reward_data.apply_to_player(collector)

	# 发送信号
	reward_collected.emit(_reward_data)

	# 通知父节点
	var parent = get_parent()
	if parent and parent.has_method("remove_reward"):
		parent.remove_reward(self)

	# 播放收集动画
	_play_collect_animation()


## 生成属性变化提示
func _spawn_attribute_popup(collector: Node2D) -> void:
	if not _reward_data:
		return

	var parent = get_parent()
	if not parent:
		return

	var attribute_name = ""
	var is_positive = true

	match _reward_data.type:
		RewardData.RewardType.GOLD:
			attribute_name = "金币"
		RewardData.RewardType.ATTACK_UP:
			attribute_name = "攻击"
		RewardData.RewardType.HEALTH_UP:
			attribute_name = "生命"
		RewardData.RewardType.HEAL:
			attribute_name = "治疗"
		RewardData.RewardType.WEAPON_UPGRADE:
			attribute_name = "武器升级"
		RewardData.RewardType.ATTRIBUTE_BOOST:
			attribute_name = _reward_data.stat_key
		RewardData.RewardType.NEW_WEAPON:
			attribute_name = "新武器"
		RewardData.RewardType.PASSIVE_ITEM:
			attribute_name = _reward_data.name + ": " + _reward_data.description

	var popup_script = load("res://scripts/ui/attribute_popup.gd")
	if popup_script and popup_script.has_method("create_attribute_popup"):
		popup_script.create_attribute_popup(
			parent,
			position + Vector2(0, -30),
			attribute_name,
			_reward_data.value,
			is_positive
		)


## 播放收集动画
func _play_collect_animation() -> void:
	# 禁用碰撞
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	if not sprite:
		queue_free()
		return

	# 停止浮动和旋转
	set_process(false)

	# 淡出 + 放大动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3)
	tween.chain().tween_callback(queue_free)


## ==================== 查询接口 ====================

## 获取奖励数据
func get_reward_data() -> RewardData:
	return _reward_data


## 是否已收集
func is_collected() -> bool:
	return _collected

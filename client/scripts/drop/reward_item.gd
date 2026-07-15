## 奖励物品脚本
##
## 玩家接近时自动拾取
## 显示为简单颜色方块

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


## 设置奖励数据
func set_reward_data(data: RewardData) -> void:
	_reward_data = data
	_update_appearance()


## 设置外观
func _setup_appearance() -> void:
	# 安全检查：确保sprite节点存在
	if not sprite:
		push_warning("[RewardItem] Sprite node not found in _setup_appearance")
		return

	# 创建默认方块
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture

	# 创建碰撞形状（deferred避免physics flushing queries错误）
	if collision_shape:
		var shape = CircleShape2D.new()
		shape.radius = 20.0
		collision_shape.set_deferred("shape", shape)


## 更新外观
func _update_appearance() -> void:
	if not _reward_data:
		return

	# 安全检查：确保sprite节点存在
	if not sprite:
		push_warning("[RewardItem] Sprite node not found")
		return

	# 根据奖励类型设置颜色
	sprite.modulate = _reward_data.color

	# 根据奖励类型调整大小
	match _reward_data.type:
		RewardData.RewardType.GOLD:
			sprite.scale = Vector2(0.8, 0.8)
		RewardData.RewardType.ATTACK_UP:
			sprite.scale = Vector2(1.0, 1.0)
		RewardData.RewardType.HEALTH_UP:
			sprite.scale = Vector2(1.0, 1.0)
		RewardData.RewardType.HEAL:
			sprite.scale = Vector2(0.9, 0.9)
		RewardData.RewardType.WEAPON_UPGRADE:
			sprite.scale = Vector2(1.2, 1.2)
		RewardData.RewardType.ATTRIBUTE_BOOST:
			sprite.scale = Vector2(1.1, 1.1)
		RewardData.RewardType.NEW_WEAPON:
			sprite.scale = Vector2(1.3, 1.3)
		RewardData.RewardType.PASSIVE_ITEM:
			sprite.scale = Vector2(1.0, 1.0)


## 碰撞检测
func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return

	# 检查是否是玩家
	if body.name == "Player" or body.has_method("get_player_data"):
		# 延迟调用，避免在物理回调中执行queue_free
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

	# 通知父节点(兼容DropManager)
	# RoomSpawner通过信号追踪, 不需要直接调用
	var parent = get_parent()
	if parent and parent.has_method("remove_reward"):
		parent.remove_reward(self)

	# 播放收集动画（简单淡出）
	_play_collect_animation()


## 生成属性变化提示
func _spawn_attribute_popup(collector: Node2D) -> void:
	if not _reward_data:
		return

	# 获取父节点
	var parent = get_parent()
	if not parent:
		return

	# 根据奖励类型确定属性名
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
			is_positive = true
		RewardData.RewardType.WEAPON_UPGRADE:
			attribute_name = "武器升级"
		RewardData.RewardType.ATTRIBUTE_BOOST:
			attribute_name = _reward_data.stat_key
		RewardData.RewardType.NEW_WEAPON:
			attribute_name = "新武器"
		RewardData.RewardType.PASSIVE_ITEM:
			# Phase 9.5.1: 显示被动物品名称和描述
			attribute_name = _reward_data.name + ": " + _reward_data.description

	# 创建属性提示
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
	# 禁用碰撞（set_deferred避免physics flushing queries）
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# 安全检查：确保sprite节点存在
	if not sprite:
		queue_free()
		return

	# 淡出动画
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_callback(queue_free)


## 获取奖励数据
func get_reward_data() -> RewardData:
	return _reward_data


## 是否已收集
func is_collected() -> bool:
	return _collected

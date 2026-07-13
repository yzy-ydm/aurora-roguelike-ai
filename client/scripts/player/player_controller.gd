## 玩家控制器脚本
##
## 负责玩家节点的输入处理、移动控制和数据显示
## 使用CharacterBody2D实现标准移动和碰撞

extends CharacterBody2D

## 移动速度（像素/秒）
const MOVE_SPEED: float = 200.0

## 玩家数据
var _player_data: Dictionary = {}

## 节点引用
@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	# 初始化玩家显示
	_setup_player_display()


## 物理帧处理（每帧调用）
func _physics_process(_delta: float) -> void:
	# 获取输入方向
	var input_direction = _get_input_direction()

	# 计算速度
	velocity = input_direction * MOVE_SPEED

	# 移动并处理碰撞
	move_and_slide()


## 获取输入方向
func _get_input_direction() -> Vector2:
	var direction = Vector2.ZERO

	# 水平方向
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1

	# 垂直方向
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1

	# 归一化防止对角线移动速度过快
	if direction.length() > 0:
		direction = direction.normalized()

	return direction


## 设置玩家显示
func _setup_player_display() -> void:
	# 创建占位矩形纹理
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.6, 1.0, 1.0))
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture

	# 创建碰撞形状
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	collision_shape.shape = shape


## 设置玩家数据
func set_player_data(data: Dictionary) -> void:
	_player_data = data
	_update_display()


## 获取玩家数据
func get_player_data() -> Dictionary:
	return _player_data


## 更新显示
func _update_display() -> void:
	# 未来可以根据玩家数据更新外观
	# 当前阶段只保存数据
	pass


## 获取玩家昵称
func get_nickname() -> String:
	return _player_data.get("nickname", "未知玩家")


## 获取玩家等级
func get_level() -> int:
	return _player_data.get("level", 1)


## 获取当前位置
func get_position() -> Vector2:
	return position


## 设置位置
func set_position(new_position: Vector2) -> void:
	position = new_position

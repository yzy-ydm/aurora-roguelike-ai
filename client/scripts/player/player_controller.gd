## 玩家控制器脚本
##
## 负责玩家节点的基础管理
## 当前阶段只负责显示，不实现移动和战斗逻辑

extends CharacterBody2D

## 玩家数据
var _player_data: Dictionary = {}

## 节点引用
@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	# 初始化玩家显示
	_setup_player_display()


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

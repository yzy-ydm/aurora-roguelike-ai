## 命中特效 (Phase 10.4)
##
## 受到攻击位置生成短暂白色闪光
## 生命周期: 0.15秒
## 自动queue_free

extends Node2D

## 生命周期
const LIFETIME: float = 0.15

## 特效大小
const EFFECT_SIZE: float = 20.0

## 节点引用
var _sprite: Sprite2D = null


func _ready() -> void:
	# 创建白色闪光
	_sprite = Sprite2D.new()
	var image = Image.create(int(EFFECT_SIZE), int(EFFECT_SIZE), false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0.8))
	var texture = ImageTexture.create_from_image(image)
	_sprite.texture = texture
	add_child(_sprite)

	# 启动生命周期
	_start_lifetime()


## 启动生命周期
func _start_lifetime() -> void:
	# 淡出效果
	var tween = create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, LIFETIME)
	tween.tween_callback(queue_free)


## 静态方法: 创建命中特效
static func create_hit_effect(parent: Node, position: Vector2) -> void:
	var effect_scene = load("res://scripts/combat/hit_effect.gd")
	if not effect_scene:
		return

	var effect = Node2D.new()
	effect.set_script(effect_scene)
	effect.position = position
	parent.add_child(effect)

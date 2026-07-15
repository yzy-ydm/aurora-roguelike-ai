## 伤害数字飘字 (Phase 10.4 增强版)
##
## 显示伤害数值
## 向上漂浮后消失
## 支持暴击显示
## 增加随机偏移和缩放动画

extends Node2D

## 飘字配置
var float_speed: float = 60.0
var float_duration: float = 0.8
var fade_duration: float = 0.3

## 随机偏移范围
const OFFSET_X: float = 15.0
const OFFSET_Y: float = 10.0

## 节点引用
@onready var label: Label = $Label

## 初始位置
var _start_position: Vector2 = Vector2.ZERO

## 当前时间
var _elapsed_time: float = 0.0


## 初始化
func _ready() -> void:
	_start_position = position

	# 随机偏移
	_start_position.x += randf_range(-OFFSET_X, OFFSET_X)
	_start_position.y += randf_range(-OFFSET_Y, OFFSET_Y)
	position = _start_position

	# 缩放动画
	scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)


## 设置伤害数值
func setup(damage: int, is_critical: bool = false, is_heal: bool = false, is_player_damage: bool = false) -> void:
	if not label:
		return

	# 设置文本
	label.text = str(damage)

	# 设置颜色和大小
	if is_heal:
		# 治疗：绿色
		label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2, 1.0))
		label.add_theme_font_size_override("font_size", 20)
	elif is_player_damage:
		# 玩家受伤：红色
		label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1.0))
		label.add_theme_font_size_override("font_size", 22)
	elif is_critical:
		# 暴击：黄色放大
		label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
		label.add_theme_font_size_override("font_size", 28)
		# 暴击前缀
		label.text = "暴击! " + str(damage)
		# 暴击更大的缩放动画
		scale = Vector2(0.3, 0.3)
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)
	else:
		# 普通怪物受伤：白色
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 20)


## 每帧更新
func _process(delta: float) -> void:
	_elapsed_time += delta

	# 向上漂浮(缓动效果)
	var progress = _elapsed_time / float_duration
	var eased_progress = 1.0 - (1.0 - progress) * (1.0 - progress)  # ease-out
	position.y = _start_position.y - (float_speed * eased_progress)

	# 轻微左右摆动
	position.x = _start_position.x + sin(_elapsed_time * 8.0) * 2.0

	# 淡出效果
	if _elapsed_time > (float_duration - fade_duration):
		var alpha = 1.0 - ((_elapsed_time - (float_duration - fade_duration)) / fade_duration)
		modulate.a = max(0.0, alpha)

	# 超时销毁
	if _elapsed_time >= float_duration:
		queue_free()


## 静态方法：创建伤害数字
static func create_damage_number(parent: Node, position: Vector2, damage: int, is_critical: bool = false, is_heal: bool = false) -> void:
	# 加载场景
	var scene = load("res://scenes/combat/damage_number.tscn")
	if not scene:
		return

	# 实例化
	var number = scene.instantiate()
	if not number:
		return

	# 设置位置
	number.position = position

	# 设置数据
	number.setup(damage, is_critical, is_heal)

	# 添加到场景
	parent.add_child(number)

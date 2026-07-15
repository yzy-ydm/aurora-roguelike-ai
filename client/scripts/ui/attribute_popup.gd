## 属性变化提示
##
## 显示属性变化数值
## 例如：攻击+10、生命+20

extends Node2D

## 飘字配置
var float_speed: float = 40.0
var float_duration: float = 1.5
var fade_duration: float = 0.5

## 节点引用
@onready var label: Label = $Label

## 初始位置
var _start_position: Vector2 = Vector2.ZERO

## 当前时间
var _elapsed_time: float = 0.0


## 初始化
func _ready() -> void:
	_start_position = position


## 设置属性变化
func setup(attribute_name: String, value: int, is_positive: bool = true) -> void:
	if not label:
		return

	# 设置文本
	var prefix = "+" if is_positive else ""
	label.text = attribute_name + " " + prefix + str(value)

	# 设置颜色
	if is_positive:
		label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2, 1.0))  # 绿色
	else:
		label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1.0))  # 红色


## 每帧更新
func _process(delta: float) -> void:
	_elapsed_time += delta

	# 向上漂浮
	position.y = _start_position.y - (float_speed * _elapsed_time)

	# 随机左右偏移
	position.x = _start_position.x + sin(_elapsed_time * 3.0) * 5.0

	# 淡出效果
	if _elapsed_time > (float_duration - fade_duration):
		var alpha = 1.0 - ((_elapsed_time - (float_duration - fade_duration)) / fade_duration)
		modulate.a = max(0.0, alpha)

	# 超时销毁
	if _elapsed_time >= float_duration:
		queue_free()


## 静态方法：创建属性提示
static func create_attribute_popup(parent: Node, position: Vector2, attribute_name: String, value: int, is_positive: bool = true) -> void:
	# 加载场景
	var scene = load("res://scenes/ui/attribute_popup.tscn")
	if not scene:
		# 如果场景不存在，创建简单的Label
		_create_simple_popup(parent, position, attribute_name, value, is_positive)
		return

	# 实例化
	var popup = scene.instantiate()
	if not popup:
		return

	# 设置位置
	popup.position = position

	# 设置数据
	popup.setup(attribute_name, value, is_positive)

	# 添加到场景
	parent.add_child(popup)


## 创建简单的属性提示（无场景时）
static func _create_simple_popup(parent: Node, position: Vector2, attribute_name: String, value: int, is_positive: bool) -> void:
	# 创建Node2D
	var popup = Node2D.new()
	popup.position = position

	# 创建Label
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 设置文本
	var prefix = "+" if is_positive else ""
	label.text = attribute_name + " " + prefix + str(value)

	# 设置颜色
	if is_positive:
		label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2, 1.0))
	else:
		label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1.0))

	popup.add_child(label)
	parent.add_child(popup)

	# 创建淡出动画
	var tween = popup.create_tween()
	tween.tween_property(popup, "position:y", position.y - 50, 1.5)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 1.5)
	tween.tween_callback(popup.queue_free)

## 房间清空反馈系统 (Phase 16.1)
##
## 房间清空时显示视觉反馈
## 提升游戏体验

extends Node

## ==================== 配置 ====================

## 反馈文本
const CLEAR_TEXT = "Room Cleared!"

## 文本颜色
const TEXT_COLOR = Color(0.2, 1.0, 0.2, 1.0)  # 绿色

## 文本持续时间
const TEXT_DURATION = 2.0

## ==================== 引用 ====================

## 反馈容器
var _feedback_container: Node2D = null

## 当前反馈节点
var _current_feedback: Node = null

## ==================== 初始化 ====================

func set_feedback_container(container: Node2D) -> void:
	_feedback_container = container


## ==================== 反馈显示 ====================

## 显示房间清空反馈
func show_clear_feedback(room_center: Vector2) -> void:
	if not _feedback_container:
		print("[RoomClearFeedback] Error: No feedback container")
		return

	# 清除旧反馈
	clear_feedback()

	# 创建反馈节点
	var feedback = _create_feedback_node(room_center)
	_feedback_container.add_child(feedback)
	_current_feedback = feedback

	# 自动清除
	await _feedback_container.get_tree().create_timer(TEXT_DURATION).timeout
	clear_feedback()


## 创建反馈节点
func _create_feedback_node(room_center: Vector2) -> Node2D:
	var feedback_node = Node2D.new()
	feedback_node.name = "RoomClearFeedback"
	feedback_node.position = room_center + Vector2(0, -50)  # 在房间上方

	# 创建文本标签
	var label = Label.new()
	label.text = CLEAR_TEXT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 设置字体样式
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

	# 居中对齐
	label.position = Vector2(-100, -20)
	label.size = Vector2(200, 40)

	feedback_node.add_child(label)

	# 添加淡出动画
	_animate_feedback(feedback_node)

	return feedback_node


## 动画反馈
func _animate_feedback(feedback_node: Node2D) -> void:
	# 获取场景树
	var scene_tree = feedback_node.get_tree()
	if not scene_tree:
		return

	# 创建Tween动画
	var tween = scene_tree.create_tween()

	# 初始状态
	feedback_node.modulate.a = 1.0
	feedback_node.scale = Vector2(0.5, 0.5)

	# 弹出动画
	tween.tween_property(feedback_node, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(feedback_node, "scale", Vector2(1.0, 1.0), 0.2)

	# 等待
	tween.tween_interval(0.5)

	# 淡出动画
	tween.tween_property(feedback_node, "modulate:a", 0.0, 1.0)


## ==================== 清理 ====================

## 清除反馈
func clear_feedback() -> void:
	if _current_feedback and _current_feedback.is_inside_tree():
		_current_feedback.queue_free()
		_current_feedback = null


## ==================== 扩展功能 ====================

## 显示自定义反馈
func show_custom_feedback(text: String, color: Color, room_center: Vector2) -> void:
	if not _feedback_container:
		return

	clear_feedback()

	var feedback = _create_custom_feedback_node(text, color, room_center)
	_feedback_container.add_child(feedback)
	_current_feedback = feedback

	await _feedback_container.get_tree().create_timer(TEXT_DURATION).timeout
	clear_feedback()


## 创建自定义反馈节点
func _create_custom_feedback_node(text: String, color: Color, room_center: Vector2) -> Node2D:
	var feedback_node = Node2D.new()
	feedback_node.name = "CustomFeedback"
	feedback_node.position = room_center + Vector2(0, -50)

	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

	label.position = Vector2(-100, -20)
	label.size = Vector2(200, 40)

	feedback_node.add_child(label)
	_animate_feedback(feedback_node)

	return feedback_node

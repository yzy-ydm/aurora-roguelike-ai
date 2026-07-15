## 房间清空反馈系统 (Phase 16.1, Phase 16.1.6 修复)
##
## 房间清空时显示视觉反馈
## 提升游戏体验
##
## Phase 16.1.6 修复:
## - 不跨 await 传递节点参数，改用 _current_feedback 成员
## - 使用 is_instance_valid() 检查节点有效性
## - 防止重复调用导致节点冲突

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

## 是否正在显示 (防止重复调用)
var _is_showing: bool = false

## ==================== 初始化 ====================

func set_feedback_container(container: Node2D) -> void:
	_feedback_container = container


## ==================== 反馈显示 ====================

## 显示房间清空反馈
func show_clear_feedback(room_center: Vector2) -> void:
	if not _feedback_container:
		print("[RoomClearFeedback] Error: No feedback container")
		return

	# 防止重复调用
	if _is_showing:
		print("[RoomClearFeedback] Already showing, skipping")
		return

	_is_showing = true

	# 清除旧反馈
	_force_clear_feedback()

	# 创建反馈节点
	var feedback = _create_feedback_node(room_center)
	_feedback_container.add_child(feedback)
	_current_feedback = feedback

	# 延迟一帧确保节点在 SceneTree 中
	await get_tree().process_frame

	# 安全检查: 节点可能在 await 期间被清除
	if not _is_current_valid():
		_is_showing = false
		return

	# 启动动画
	_animate_feedback(_current_feedback)

	# 等待动画完成
	await get_tree().create_timer(TEXT_DURATION).timeout

	# 清除
	_force_clear_feedback()
	_is_showing = false


## 创建反馈节点 (不启动动画)
func _create_feedback_node(room_center: Vector2) -> Node2D:
	var feedback_node = Node2D.new()
	feedback_node.name = "RoomClearFeedback"
	feedback_node.position = room_center + Vector2(0, -50)

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

	# 初始状态
	feedback_node.modulate.a = 1.0
	feedback_node.scale = Vector2(0.5, 0.5)

	return feedback_node


## 动画反馈 (节点必须已在 SceneTree 中且有效)
func _animate_feedback(feedback_node: Node2D) -> void:
	# 安全检查
	if not is_instance_valid(feedback_node):
		return
	if not feedback_node.is_inside_tree():
		return

	# 创建 Tween (绑定到节点，节点销毁时 Tween 自动取消)
	var tween = feedback_node.create_tween()
	if not tween:
		return

	# 弹出动画
	tween.tween_property(feedback_node, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(feedback_node, "scale", Vector2(1.0, 1.0), 0.2)

	# 等待
	tween.tween_interval(0.5)

	# 淡出动画
	tween.tween_property(feedback_node, "modulate:a", 0.0, 1.0)


## ==================== 安全检查 ====================

## 检查当前反馈节点是否有效
func _is_current_valid() -> bool:
	return _current_feedback != null and is_instance_valid(_current_feedback) and _current_feedback.is_inside_tree()


## ==================== 清理 ====================

## 强制清除反馈 (安全版本)
func _force_clear_feedback() -> void:
	if _current_feedback:
		if is_instance_valid(_current_feedback) and _current_feedback.is_inside_tree():
			_current_feedback.queue_free()
		_current_feedback = null


## 清除反馈 (外部调用)
func clear_feedback() -> void:
	_force_clear_feedback()
	_is_showing = false


## ==================== 扩展功能 ====================

## 显示自定义反馈
func show_custom_feedback(text: String, color: Color, room_center: Vector2) -> void:
	if not _feedback_container:
		return

	# 防止重复调用
	if _is_showing:
		return

	_is_showing = true

	_force_clear_feedback()

	var feedback = _create_custom_feedback_node(text, color, room_center)
	_feedback_container.add_child(feedback)
	_current_feedback = feedback

	await get_tree().process_frame

	if not _is_current_valid():
		_is_showing = false
		return

	_animate_feedback(_current_feedback)

	await get_tree().create_timer(TEXT_DURATION).timeout

	_force_clear_feedback()
	_is_showing = false


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

	feedback_node.modulate.a = 1.0
	feedback_node.scale = Vector2(0.5, 0.5)

	return feedback_node

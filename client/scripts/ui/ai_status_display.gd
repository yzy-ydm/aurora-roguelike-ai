## AI状态显示 (Phase 15)
##
## 显示AI当前工作状态
## 用于让玩家知道AI正在做什么

extends Control

## AI状态枚举
enum AIStatus {
	IDLE,
	GENERATING,
	ANALYZING_PLAYER,
	ADJUSTING_DIFFICULTY,
	GENERATING_EVENT,
	GENERATING_NPC
}

## 当前状态
var _current_status: AIStatus = AIStatus.IDLE

## 状态文本映射
var _status_texts: Dictionary = {
	AIStatus.IDLE: "",
	AIStatus.GENERATING: "AI正在生成内容...",
	AIStatus.ANALYZING_PLAYER: "AI正在分析玩家行为...",
	AIStatus.ADJUSTING_DIFFICULTY: "AI正在调整难度...",
	AIStatus.GENERATING_EVENT: "AI正在生成事件...",
	AIStatus.GENERATING_NPC: "AI正在生成NPC对话..."
}

## 节点引用
@onready var status_label: Label = $StatusLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	# 初始隐藏
	visible = false


## 设置AI状态
func set_status(status: AIStatus) -> void:
	if _current_status == status:
		return

	_current_status = status

	if status == AIStatus.IDLE:
		_hide_status()
	else:
		_show_status(_status_texts.get(status, "AI工作中..."))


## 显示状态
func _show_status(text: String) -> void:
	if status_label:
		status_label.text = text
	visible = true

	# 播放显示动画
	if animation_player and animation_player.has_animation("show"):
		animation_player.play("show")


## 隐藏状态
func _hide_status() -> void:
	if animation_player and animation_player.has_animation("hide"):
		animation_player.play("hide")
	else:
		visible = false


## 获取当前状态
func get_status() -> AIStatus:
	return _current_status


## 静态方法：快速设置状态
static func update_status(parent: Node, status: AIStatus) -> void:
	var display = parent.get_node_or_null("UI/AIStatusDisplay")
	if display and display.has_method("set_status"):
		display.set_status(status)

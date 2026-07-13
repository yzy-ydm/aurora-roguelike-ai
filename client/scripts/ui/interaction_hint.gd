## 交互提示UI
##
## 负责显示交互提示
## 当玩家靠近可交互对象时显示提示

extends CanvasLayer

## 节点引用
@onready var hint_label: Label = $HintLabel

## 是否显示
var _is_visible: bool = false


func _ready() -> void:
	# 初始隐藏
	visible = false


## 显示交互提示
func show_hint(text: String = "按 E 交互") -> void:
	if hint_label:
		hint_label.text = text
	visible = true
	_is_visible = true


## 隐藏交互提示
func hide_hint() -> void:
	visible = false
	_is_visible = false


## 设置提示文本
func set_hint_text(text: String) -> void:
	if hint_label:
		hint_label.text = text


## 检查是否显示中
func is_showing() -> bool:
	return _is_visible

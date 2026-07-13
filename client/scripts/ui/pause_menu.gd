## 暂停菜单控制器
##
## 负责暂停菜单的显示和交互
## 使用Godot标准暂停机制

extends CanvasLayer

## 节点引用
@onready var continue_button: Button = $Panel/VBox/ContinueButton
@onready var save_button: Button = $Panel/VBox/SaveButton
@onready var settings_button: Button = $Panel/VBox/SettingsButton
@onready var exit_button: Button = $Panel/VBox/ExitButton
@onready var status_label: Label = $Panel/VBox/StatusLabel

## 信号
signal resume_game
signal open_settings
signal exit_to_menu


func _ready() -> void:
	# 连接按钮信号
	continue_button.pressed.connect(_on_continue_pressed)
	save_button.pressed.connect(_on_save_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# 连接存档信号
	SaveService.save_saved.connect(_on_save_saved)
	SaveService.save_error.connect(_on_save_error)

	# 初始隐藏
	visible = false


## 显示暂停菜单
func show_pause() -> void:
	visible = true
	status_label.text = ""


## 隐藏暂停菜单
func hide_pause() -> void:
	visible = false


## 继续游戏按钮
func _on_continue_pressed() -> void:
	hide_pause()
	resume_game.emit()


## 保存游戏按钮
func _on_save_pressed() -> void:
	status_label.text = "保存中..."
	save_button.disabled = true

	var slot = GameStateManager.get_current_slot()
	if slot >= 0:
		var save_data = GameStateManager.get_save_data()
		SaveService.save_game(slot, save_data)
	else:
		status_label.text = "无存档槽位"


## 设置按钮
func _on_settings_pressed() -> void:
	open_settings.emit()


## 退出按钮
func _on_exit_pressed() -> void:
	exit_to_menu.emit()


## 存档保存成功
func _on_save_saved(success: bool, message: String) -> void:
	save_button.disabled = false
	if success:
		status_label.text = "保存成功"
	else:
		status_label.text = "保存失败: " + message


## 存档保存错误
func _on_save_error(error: String) -> void:
	save_button.disabled = false
	status_label.text = "保存失败: " + error

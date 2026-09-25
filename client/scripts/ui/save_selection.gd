## 存档选择界面控制器
##
## 负责存档选择界面的显示和交互
## 显示存档信息，支持选择和加载

extends CanvasLayer

## 节点引用
@onready var slot1_button: Button = $Panel/VBox/Slot1
@onready var slot2_button: Button = $Panel/VBox/Slot2
@onready var slot3_button: Button = $Panel/VBox/Slot3
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var back_button: Button = $Panel/VBox/BackButton

## 存档槽位按钮数组
var _slot_buttons: Array[Button] = []

## 信号
signal save_selected(slot: int)
signal save_selection_closed


func _ready() -> void:
	# 初始化槽位按钮数组
	_slot_buttons = [slot1_button, slot2_button, slot3_button]

	# 连接按钮信号
	slot1_button.pressed.connect(_on_slot_pressed.bind(1))
	slot2_button.pressed.connect(_on_slot_pressed.bind(2))
	slot3_button.pressed.connect(_on_slot_pressed.bind(3))
	back_button.pressed.connect(_on_back_pressed)

	# 连接存档服务信号
	SaveService.saves_loaded.connect(_on_saves_loaded)
	SaveService.save_error.connect(_on_save_error)

	# 初始隐藏
	visible = false


## 显示存档选择界面
func show_save_selection() -> void:
	visible = true
	status_label.text = "加载存档中..."
	_disable_slots()

	# 加载存档列表
	SaveService.load_saves()


## 隐藏存档选择界面
func hide_save_selection() -> void:
	visible = false


## TASK-026: 外部设置面板状态文本（保存中/保存成功/保存失败反馈）
func set_status(text: String) -> void:
	status_label.text = text


## 存档列表加载完成
func _on_saves_loaded(saves: Array) -> void:
	_enable_slots()
	_update_slot_display(saves)


## 更新槽位显示
func _update_slot_display(saves: Array) -> void:
	# 重置所有槽位
	for i in range(3):
		_slot_buttons[i].text = "槽位 " + str(i + 1) + " - 空"
		_slot_buttons[i].disabled = false

	# 填充已有存档信息
	for save in saves:
		if save is Dictionary:
			var slot = save.get("slot_number", -1)
			if slot >= 1 and slot <= 3:
				var save_name = save.get("save_name", "未命名存档")
				var floor = save.get("current_floor", 1)
				var play_time = save.get("play_time", 0)
				var minutes = play_time / 60
				_slot_buttons[slot - 1].text = "槽位 " + str(slot) + " - " + save_name + " (F" + str(floor) + " / " + str(minutes) + "分钟)"

	status_label.text = "选择存档槽位"


## 槽位按钮按下
func _on_slot_pressed(slot: int) -> void:
	status_label.text = "加载槽位 " + str(slot) + "..."
	_disable_slots()
	save_selected.emit(slot)


## 返回按钮
func _on_back_pressed() -> void:
	hide_save_selection()
	save_selection_closed.emit()


## 禁用所有槽位按钮
func _disable_slots() -> void:
	for button in _slot_buttons:
		button.disabled = true


## 启用所有槽位按钮
func _enable_slots() -> void:
	for button in _slot_buttons:
		button.disabled = false


## 存档加载错误
func _on_save_error(error: String) -> void:
	status_label.text = "错误: " + error
	_enable_slots()

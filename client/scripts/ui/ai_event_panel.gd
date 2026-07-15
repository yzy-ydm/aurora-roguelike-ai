## AI事件面板 (Phase 11)
##
## 显示AI生成的事件
## 支持事件标题、描述、选择按钮

extends CanvasLayer

## 节点引用
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var description_label: Label = $Panel/VBox/DescriptionLabel
@onready var choices_container: VBoxContainer = $Panel/VBox/ChoicesContainer

## 事件管理器引用
var _event_manager: Node = null

## 信号
signal choice_selected(choice_index: int)


## 初始化
func _ready() -> void:
	# 默认隐藏
	hide()


## 设置事件管理器
func set_event_manager(manager: Node) -> void:
	_event_manager = manager
	if _event_manager:
		_event_manager.event_started.connect(_on_event_started)
		_event_manager.event_completed.connect(_on_event_completed)


## 显示事件
func _on_event_started(event: AIEventData) -> void:
	if not event:
		return

	# 设置标题
	title_label.text = event.title

	# 设置描述
	description_label.text = event.description

	# 清除旧选项
	for child in choices_container.get_children():
		child.queue_free()

	# 创建选项按钮
	for i in range(event.choices.size()):
		var choice = event.choices[i]
		var button = Button.new()
		button.text = choice.get("text", "选项 " + str(i + 1))
		button.pressed.connect(_on_choice_pressed.bind(i))
		choices_container.add_child(button)

	# 显示面板
	show()


## 选项按下
func _on_choice_pressed(choice_index: int) -> void:
	print("[AIEventPanel] Choice selected: ", choice_index)
	choice_selected.emit(choice_index)

	# 通知事件管理器
	if _event_manager:
		_event_manager.make_choice(choice_index)


## 事件完成
func _on_event_completed(rewards: Dictionary) -> void:
	# 隐藏面板
	hide()

## 升级面板 (Phase 12, Phase 9.3.2 增强)
##
## 显示升级时的强化选择界面
## 玩家从3个随机强化中选择一个
## 支持 UpgradeData 和 RewardData

extends CanvasLayer

## ==================== 配置 ====================

## 强化按钮场景
var _upgrade_button_scene: PackedScene = null

## ==================== 状态 ====================

## 当前显示的强化选项 (UpgradeData)
var _current_options: Array[UpgradeData] = []

## 当前显示的奖励选项 (RewardData, Phase 9.3.2)
var _current_reward_options: Array[RewardData] = []

## 当前模式: "upgrade" 或 "reward"
var _current_mode: String = "upgrade"

## 是否正在显示
var _is_showing: bool = false

## ==================== 引用 ====================

## 升级管理器引用
var _upgrade_manager: Node = null

## 节点引用（动态创建或从场景加载）
var panel: PanelContainer = null
var title_label: Label = null
var options_container: VBoxContainer = null
var description_label: Label = null

## ==================== 信号 ====================

## 强化选择完成
signal upgrade_selected(upgrade: UpgradeData)

## 奖励选择完成 (Phase 9.3.2)
signal reward_selected(reward: RewardData)

## 面板关闭
signal panel_closed()


## ==================== 初始化 ====================

func _ready() -> void:
	# 如果子节点不存在，动态创建UI结构
	_setup_ui_if_needed()
	# 默认隐藏
	hide()
	_is_showing = false

	# 关键：设置为暂停时仍可处理输入
	# 否则 get_tree().paused = true 后按钮无法点击
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


## 动态创建UI结构（如果从代码创建CanvasLayer时没有子节点）
func _setup_ui_if_needed() -> void:
	panel = get_node_or_null("Panel") as PanelContainer
	if not panel:
		panel = PanelContainer.new()
		panel.name = "Panel"
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.custom_minimum_size = Vector2(400, 300)
		add_child(panel)

	var vbox = panel.get_node_or_null("VBox") as VBoxContainer
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.name = "VBox"
		panel.add_child(vbox)

	title_label = vbox.get_node_or_null("TitleLabel") as Label
	if not title_label:
		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.text = "选择强化"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title_label)

	options_container = vbox.get_node_or_null("OptionsContainer") as VBoxContainer
	if not options_container:
		options_container = VBoxContainer.new()
		options_container.name = "OptionsContainer"
		vbox.add_child(options_container)

	description_label = vbox.get_node_or_null("DescriptionLabel") as Label
	if not description_label:
		description_label = Label.new()
		description_label.name = "DescriptionLabel"
		description_label.text = ""
		description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(description_label)


## 设置升级管理器
func set_upgrade_manager(manager: Node) -> void:
	_upgrade_manager = manager
	if _upgrade_manager:
		_upgrade_manager.upgrade_selection_required.connect(_on_upgrade_selection_required)
		print("[LevelUpPanel] Connected to UpgradeManager")


## ==================== 显示逻辑 ====================

## 升级选择需求回调
func _on_upgrade_selection_required(options: Array[UpgradeData]) -> void:
	# 防止重复弹出
	if _is_showing:
		print("[LevelUpPanel] Already showing, ignoring duplicate request")
		return
	show_upgrade_panel(options)


## 显示升级面板
func show_upgrade_panel(options: Array[UpgradeData]) -> void:
	if options.size() == 0:
		print("[LevelUpPanel] No upgrade options to show")
		return

	_current_options = options
	_current_mode = "upgrade"
	_is_showing = true

	# 设置标题
	if title_label:
		title_label.text = "选择强化"

	# 清除旧选项
	_clear_options()

	# 创建选项按钮
	for i in range(options.size()):
		var upgrade = options[i]
		_create_upgrade_option_button(upgrade, i)

	# 显示面板
	show()

	# 暂停游戏
	get_tree().paused = true

	print("[LevelUpPanel] Showing upgrade panel with ", options.size(), " options")


## 显示奖励选择面板 (Phase 9.3.2)
func show_reward_panel(rewards: Array[RewardData], panel_title: String = "选择奖励") -> void:
	if rewards.size() == 0:
		print("[LevelUpPanel] No reward options to show")
		return

	_current_reward_options = rewards
	_current_mode = "reward"
	_is_showing = true

	# 设置标题
	if title_label:
		title_label.text = panel_title

	# 清除旧选项
	_clear_options()

	# 创建选项按钮
	for i in range(rewards.size()):
		var reward = rewards[i]
		_create_reward_option_button(reward, i)

	# 显示面板
	show()

	# 暂停游戏
	get_tree().paused = true

	print("[LevelUpPanel] Showing reward panel with ", rewards.size(), " options")


## 清除选项
func _clear_options() -> void:
	if options_container:
		for child in options_container.get_children():
			child.queue_free()


## 创建升级选项按钮
func _create_upgrade_option_button(upgrade: UpgradeData, index: int) -> void:
	if not options_container:
		return

	# 创建按钮容器
	var button_container = HBoxContainer.new()
	button_container.name = "Option_" + str(index)

	# 创建按钮
	var button = Button.new()
	button.name = "Button"
	button.text = upgrade.name
	button.custom_minimum_size = Vector2(200, 60)

	# 设置按钮样式
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = _get_rarity_color(upgrade.rarity)
	style_box.border_color = Color.WHITE
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", style_box)

	# 连接信号
	button.pressed.connect(_on_option_selected.bind(index))

	# 创建描述标签
	var desc_label = Label.new()
	desc_label.name = "Description"
	desc_label.text = upgrade.description
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 添加到容器
	button_container.add_child(button)
	button_container.add_child(desc_label)

	# 添加到选项容器
	options_container.add_child(button_container)


## 创建奖励选项按钮 (Phase 9.3.2)
func _create_reward_option_button(reward: RewardData, index: int) -> void:
	if not options_container:
		return

	# 创建按钮容器
	var button_container = HBoxContainer.new()
	button_container.name = "Reward_" + str(index)

	# 创建按钮
	var button = Button.new()
	button.name = "Button"
	button.text = reward.name
	button.custom_minimum_size = Vector2(200, 60)

	# 设置按钮样式 (使用奖励颜色)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = reward.color.darkened(0.3)
	style_box.border_color = reward.color
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", style_box)

	# 连接信号
	button.pressed.connect(_on_reward_option_selected.bind(index))

	# 创建描述标签
	var desc_label = Label.new()
	desc_label.name = "Description"
	desc_label.text = reward.description
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 添加到容器
	button_container.add_child(button)
	button_container.add_child(desc_label)

	# 添加到选项容器
	options_container.add_child(button_container)


## 获取稀有度颜色
func _get_rarity_color(rarity) -> Color:
	# 支持字符串类型 (RewardData)
	if rarity is String:
		match rarity:
			"common":
				return Color(0.3, 0.3, 0.3, 0.8)
			"uncommon":
				return Color(0.1, 0.4, 0.1, 0.8)
			"rare":
				return Color(0.1, 0.2, 0.5, 0.8)
			"epic":
				return Color(0.4, 0.1, 0.5, 0.8)
			"legendary":
				return Color(0.5, 0.4, 0.1, 0.8)
			_:
				return Color(0.3, 0.3, 0.3, 0.8)

	# 支持枚举类型 (UpgradeData)
	match rarity:
		UpgradeData.UpgradeRarity.COMMON:
			return Color(0.3, 0.3, 0.3, 0.8)
		UpgradeData.UpgradeRarity.UNCOMMON:
			return Color(0.1, 0.4, 0.1, 0.8)
		UpgradeData.UpgradeRarity.RARE:
			return Color(0.1, 0.2, 0.5, 0.8)
		UpgradeData.UpgradeRarity.EPIC:
			return Color(0.4, 0.1, 0.5, 0.8)
		UpgradeData.UpgradeRarity.LEGENDARY:
			return Color(0.5, 0.4, 0.1, 0.8)
		_:
			return Color(0.3, 0.3, 0.3, 0.8)


## ==================== 选择处理 ====================

## 选项选中回调
func _on_option_selected(index: int) -> void:
	print("[LevelUpPanel] Button clicked index=", index)
	if index < 0 or index >= _current_options.size():
		print("[LevelUpPanel] Invalid option index: ", index)
		return

	var selected_upgrade = _current_options[index]
	print("[LevelUpPanel] Upgrade selected: ", selected_upgrade.name)

	# 应用强化
	if _upgrade_manager:
		_upgrade_manager.apply_upgrade(selected_upgrade)

	# 发送信号
	upgrade_selected.emit(selected_upgrade)

	# 关闭面板
	_hide_panel()


## 奖励选项选中回调 (Phase 9.3.2)
func _on_reward_option_selected(index: int) -> void:
	if index < 0 or index >= _current_reward_options.size():
		print("[LevelUpPanel] Invalid reward index: ", index)
		return

	var selected_reward = _current_reward_options[index]
	print("[LevelUpPanel] Selected reward: ", selected_reward.name)

	# 发送信号 (由外部处理应用逻辑)
	reward_selected.emit(selected_reward)

	# 关闭面板
	_hide_panel()


## 隐藏面板
func _hide_panel() -> void:
	hide()
	_is_showing = false
	_current_options.clear()
	_current_reward_options.clear()
	_current_mode = "upgrade"

	# 恢复游戏
	get_tree().paused = false

	panel_closed.emit()
	print("[LevelUpPanel] Panel closed")


## ==================== 查询接口 ====================

## 是否正在显示
func is_showing() -> bool:
	return _is_showing

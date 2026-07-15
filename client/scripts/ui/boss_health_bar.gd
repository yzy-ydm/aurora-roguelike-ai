## Boss血条 (Phase 12)
##
## 显示Boss的血量和阶段信息

extends CanvasLayer

## ==================== 引用 ====================

## Boss控制器引用
var _boss_controller: Node = null

## 节点引用（动态创建或从场景加载）
var panel: PanelContainer = null
var boss_name_label: Label = null
var health_bar: ProgressBar = null
var health_label: Label = null
var phase_label: Label = null

## ==================== 状态 ====================

## 是否正在显示
var _is_showing: bool = false


## ==================== 初始化 ====================

func _ready() -> void:
	# 动态创建UI结构（如果从代码创建CanvasLayer时没有子节点）
	_setup_ui_if_needed()
	# 默认隐藏
	hide()
	_is_showing = false


## 动态创建UI结构
func _setup_ui_if_needed() -> void:
	panel = get_node_or_null("Panel") as PanelContainer
	if not panel:
		panel = PanelContainer.new()
		panel.name = "Panel"
		panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
		panel.custom_minimum_size = Vector2(300, 80)
		add_child(panel)

	var vbox = panel.get_node_or_null("VBox") as VBoxContainer
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.name = "VBox"
		panel.add_child(vbox)

	boss_name_label = vbox.get_node_or_null("NameLabel") as Label
	if not boss_name_label:
		boss_name_label = Label.new()
		boss_name_label.name = "NameLabel"
		boss_name_label.text = "Boss"
		boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(boss_name_label)

	health_bar = vbox.get_node_or_null("HealthBar") as ProgressBar
	if not health_bar:
		health_bar = ProgressBar.new()
		health_bar.name = "HealthBar"
		health_bar.min_value = 0
		health_bar.max_value = 100
		health_bar.value = 100
		vbox.add_child(health_bar)

	health_label = health_bar.get_node_or_null("HealthLabel") as Label
	if not health_label:
		health_label = Label.new()
		health_label.name = "HealthLabel"
		health_label.text = "100/100"
		health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		health_bar.add_child(health_label)

	phase_label = vbox.get_node_or_null("PhaseLabel") as Label
	if not phase_label:
		phase_label = Label.new()
		phase_label.name = "PhaseLabel"
		phase_label.text = "Phase 1"
		phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(phase_label)


## 设置Boss控制器
func set_boss_controller(controller: Node) -> void:
	_boss_controller = controller
	if _boss_controller:
		# 连接信号
		_boss_controller.boss_damaged.connect(_on_boss_damaged)
		_boss_controller.phase_changed.connect(_on_phase_changed)
		_boss_controller.boss_defeated.connect(_on_boss_defeated)
		print("[BossHealthBar] Connected to BossController")


## ==================== 显示逻辑 ====================

## 显示Boss血条
func show_boss(boss_name: String, max_health: int) -> void:
	if boss_name_label:
		boss_name_label.text = boss_name

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = max_health

	if health_label:
		health_label.text = str(max_health) + "/" + str(max_health)

	if phase_label:
		phase_label.text = "Phase 1"

	show()
	_is_showing = true
	print("[BossHealthBar] Showing boss: ", boss_name)


## 隐藏Boss血条
func hide_boss() -> void:
	hide()
	_is_showing = false
	print("[BossHealthBar] Hiding boss health bar")


## 更新血量显示
func _update_health_display(current_health: int, max_health: int) -> void:
	if health_bar:
		health_bar.value = current_health

	if health_label:
		health_label.text = str(current_health) + "/" + str(max_health)


## ==================== 信号回调 ====================

## Boss受伤回调
func _on_boss_damaged(damage: int, current_health: int) -> void:
	if _boss_controller and "_boss_data" in _boss_controller and _boss_controller._boss_data:
		var max_health = _boss_controller._boss_data.max_health
		_update_health_display(current_health, max_health)
	else:
		# 回退：使用health_bar的max_value
		if health_bar:
			_update_health_display(current_health, int(health_bar.max_value))


## 阶段转换回调
func _on_phase_changed(new_phase: BossData.BossPhase) -> void:
	if phase_label:
		match new_phase:
			BossData.BossPhase.PHASE_1:
				phase_label.text = "Phase 1"
			BossData.BossPhase.PHASE_2:
				phase_label.text = "Phase 2"
			BossData.BossPhase.PHASE_3:
				phase_label.text = "Phase 3"

	print("[BossHealthBar] Phase changed to: ", new_phase)


## Boss被击败回调
func _on_boss_defeated() -> void:
	# 延迟隐藏
	await get_tree().create_timer(2.0).timeout
	hide_boss()


## ==================== 查询接口 ====================

## 是否正在显示
func is_showing() -> bool:
	return _is_showing

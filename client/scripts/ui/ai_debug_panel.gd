## AI调试面板 (Phase 15)
##
## 用于毕业答辩展示
## 显示AI决策过程和玩家行为分析
##
## 仅在Debug模式下显示

extends PanelContainer

## 节点引用
@onready var player_context_label: Label = $VBox/PlayerContext/ValueLabel
@onready var ai_decision_label: Label = $VBox/AIDecision/ValueLabel
@onready var network_stats_label: Label = $VBox/NetworkStats/ValueLabel

## 是否启用
var _enabled: bool = false

## 更新间隔
var _update_interval: float = 0.5
var _update_timer: float = 0.0


func _ready() -> void:
	# 默认隐藏
	visible = false

	# Debug模式自动启用
	if OS.is_debug_build():
		_enabled = true
		visible = true


func _process(delta: float) -> void:
	if not _enabled:
		return

	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_timer = 0.0
		_update_display()


## 更新显示
func _update_display() -> void:
	_update_player_context()
	_update_ai_decision()
	_update_network_stats()


## 更新玩家上下文
func _update_player_context() -> void:
	if not player_context_label:
		return

	var context = ""

	# 获取行为分析器
	var behavior_analyzer = _find_node("BehaviorAnalyzer")
	if behavior_analyzer and behavior_analyzer.has_method("get_behavior_data"):
		var data = behavior_analyzer.get_behavior_data()
		if data:
			context += "Level: " + str(data.get("player_level", 1)) + "\n"
			context += "Combat Style: " + str(data.get("combat_style", "unknown")) + "\n"
			context += "Preferred Upgrade: " + str(data.get("preferred_upgrade", "none")) + "\n"
			context += "Death Rate: " + str(data.get("death_rate", 0.0)) + "\n"
			context += "Damage Rate: " + str(data.get("damage_rate", 0.0))

	player_context_label.text = context if context else "等待数据..."


## 更新AI决策
func _update_ai_decision() -> void:
	if not ai_decision_label:
		return

	var decision = ""

	# 获取FloorManager
	var floor_manager = _find_node("FloorManager")
	if floor_manager:
		var difficulty = floor_manager.get_difficulty_adjustment()
		if difficulty:
			decision += "Difficulty: " + str(difficulty.get("difficulty", 1.0)) + "\n"
			decision += "Enemy HP Mult: " + str(difficulty.get("enemy_hp_multiplier", 1.0)) + "\n"
			decision += "Reward Mult: " + str(difficulty.get("reward_multiplier", 1.0))

	ai_decision_label.text = decision if decision else "等待AI决策..."


## 更新网络统计
func _update_network_stats() -> void:
	if not network_stats_label:
		return

	var stats = ""

	# 获取AnalyticsManager
	var analytics = _find_node("AnalyticsManager")
	if analytics and analytics.has_method("get_statistics"):
		var data = analytics.get_statistics()
		if data:
			stats += "Requests: " + str(data.get("total_requests", 0)) + "\n"
			stats += "Success Rate: " + str(snapped(data.get("success_rate", 0.0) * 100, 0.1)) + "%\n"
			stats += "Avg Latency: " + str(snapped(data.get("avg_latency", 0.0), 0.01)) + "s"

	network_stats_label.text = stats if stats else "等待网络数据..."


## 查找节点
func _find_node(node_name: String) -> Node:
	var root = get_tree().current_scene
	if root:
		return root.get_node_or_null(node_name)
	return null


## 切换显示
func toggle() -> void:
	_enabled = !_enabled
	visible = _enabled


## 设置启用状态
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	visible = enabled

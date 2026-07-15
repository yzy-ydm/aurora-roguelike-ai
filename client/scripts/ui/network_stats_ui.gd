## 网络统计UI (Phase 15)
##
## 显示API请求统计信息
## 用于监控网络性能

extends PanelContainer

## 节点引用
@onready var requests_label: Label = $VBox/Requests/ValueLabel
@onready var success_rate_label: Label = $VBox/SuccessRate/ValueLabel
@onready var latency_label: Label = $VBox/Latency/ValueLabel
@onready var fallback_label: Label = $VBox/Fallback/ValueLabel

## 更新间隔
var _update_interval: float = 1.0
var _update_timer: float = 0.0

## 是否显示
var _visible: bool = false


func _ready() -> void:
	# 默认隐藏
	visible = false


func _process(delta: float) -> void:
	if not _visible:
		return

	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_timer = 0.0
		_update_stats()


## 切换显示
func toggle() -> void:
	_visible = !_visible
	visible = _visible


## 更新统计
func _update_stats() -> void:
	# 获取AnalyticsManager
	var analytics = get_tree().current_scene.get_node_or_null("AnalyticsManager")
	if not analytics:
		return

	if analytics.has_method("get_statistics"):
		var stats = analytics.get_statistics()
		if stats:
			_update_display(stats)


## 更新显示
func _update_display(stats: Dictionary) -> void:
	if requests_label:
		requests_label.text = str(stats.get("total_requests", 0))

	if success_rate_label:
		var rate = stats.get("success_rate", 0.0) * 100
		success_rate_label.text = str(snapped(rate, 0.1)) + "%"

	if latency_label:
		var latency = stats.get("avg_latency", 0.0) * 1000
		latency_label.text = str(snapped(latency, 1)) + "ms"

	if fallback_label:
		fallback_label.text = str(stats.get("fallback_count", 0))


## 设置显示状态
func set_visible_state(show: bool) -> void:
	_visible = show
	visible = show
	if show:
		_update_stats()

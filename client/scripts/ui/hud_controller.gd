## HUD控制器脚本
##
## 负责显示游戏内HUD信息
## 包括：玩家昵称、等级、生命值、金币

extends CanvasLayer

## 节点引用
@onready var nickname_label: Label = $TopBar/PlayerInfo/NicknameLabel
@onready var level_label: Label = $TopBar/PlayerInfo/LevelLabel
@onready var health_label: Label = $TopBar/StatsContainer/HealthBar/HealthLabel
@onready var health_progress: ProgressBar = $TopBar/StatsContainer/HealthBar/HealthProgress
@onready var gold_label: Label = $TopBar/GoldContainer/GoldLabel
@onready var status_label: Label = $StatusPanel/StatusLabel

## 玩家数据缓存
var _player_data: Dictionary = {}


func _ready() -> void:
	# 初始显示
	_clear_display()


## 更新HUD显示
func update_hud(data: Dictionary) -> void:
	_player_data = data
	_update_display()


## 更新显示内容
func _update_display() -> void:
	# 玩家昵称
	var nickname = _player_data.get("nickname", "未知玩家")
	nickname_label.text = "玩家: " + str(nickname)

	# 等级
	var level = _player_data.get("level", 1)
	level_label.text = "等级: " + str(level)

	# 生命值
	var current_health = _player_data.get("current_health", 0)
	var max_health = _player_data.get("max_health", 100)
	health_label.text = "生命值: " + str(current_health) + "/" + str(max_health)

	# 生命值进度条
	if max_health > 0:
		health_progress.value = (float(current_health) / float(max_health)) * 100.0
	else:
		health_progress.value = 0

	# 金币
	var gold = _player_data.get("gold", 0)
	gold_label.text = "金币: " + str(gold)


## 清除显示
func _clear_display() -> void:
	nickname_label.text = "玩家: 加载中..."
	level_label.text = "等级: -"
	health_label.text = "生命值: -/-"
	health_progress.value = 0
	gold_label.text = "金币: -"


## 设置状态文本
func set_status(text: String) -> void:
	status_label.text = text


## 获取当前玩家数据
func get_player_data() -> Dictionary:
	return _player_data

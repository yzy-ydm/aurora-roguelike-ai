## 主界面场景脚本
##
## 显示玩家信息，处理登出逻辑

extends Control

## 节点引用
@onready var nickname_label: Label = $VBoxContainer/PlayerInfoPanel/PlayerInfo/NicknameLabel
@onready var level_label: Label = $VBoxContainer/PlayerInfoPanel/PlayerInfo/LevelLabel
@onready var experience_label: Label = $VBoxContainer/PlayerInfoPanel/PlayerInfo/ExperienceLabel
@onready var health_label: Label = $VBoxContainer/PlayerInfoPanel/PlayerInfo/HealthLabel
@onready var attack_label: Label = $VBoxContainer/PlayerInfoPanel/PlayerInfo/AttackLabel
@onready var defense_label: Label = $VBoxContainer/PlayerInfoPanel/PlayerInfo/DefenseLabel
@onready var gold_label: Label = $VBoxContainer/PlayerInfoPanel/PlayerInfo/GoldLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var refresh_button: Button = $VBoxContainer/ButtonContainer/RefreshButton
@onready var logout_button: Button = $VBoxContainer/ButtonContainer/LogoutButton


func _ready() -> void:
	# 连接信号
	refresh_button.pressed.connect(_on_refresh_pressed)
	logout_button.pressed.connect(_on_logout_pressed)

	ApiClient.request_completed.connect(_on_api_success)
	ApiClient.request_failed.connect(_on_api_error)

	# 加载玩家信息
	_load_player_profile()


## 加载玩家信息
func _load_player_profile() -> void:
	status_label.text = "加载玩家信息..."
	ApiClient.get_request(APIConfig.PLAYER_PROFILE, true)


## 刷新按钮按下
func _on_refresh_pressed() -> void:
	_load_player_profile()


## 退出按钮按下
func _on_logout_pressed() -> void:
	TokenManager.clear_token()
	SceneManager.go_to_login()


## API请求成功回调
func _on_api_success(result: Dictionary) -> void:
	if result.has("nickname"):
		_display_player_info(result)
	else:
		status_label.text = "未知响应格式"


## 显示玩家信息
func _display_player_info(data: Dictionary) -> void:
	nickname_label.text = "昵称: " + str(data.get("nickname", "未知"))
	level_label.text = "等级: " + str(data.get("level", 0))
	experience_label.text = "经验: " + str(data.get("experience", 0)) + " / " + str(data.get("experience_to_next_level", 100))
	health_label.text = "生命值: " + str(data.get("current_health", 0)) + " / " + str(data.get("max_health", 100))
	attack_label.text = "攻击力: " + str(data.get("attack", 0))
	defense_label.text = "防御力: " + str(data.get("defense", 0))
	gold_label.text = "金币: " + str(data.get("gold", 0))
	status_label.text = "数据加载完成"


## API请求失败回调
func _on_api_error(error: String, status_code: int) -> void:
	if status_code == 401:
		status_label.text = "认证失败，请重新登录"
		TokenManager.clear_token()
		await get_tree().create_timer(2.0).timeout
		SceneManager.go_to_login()
		return

	status_label.text = "错误: " + error

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
@onready var continue_button: Button = $VBoxContainer/ButtonContainer/ContinueButton
@onready var logout_button: Button = $VBoxContainer/ButtonContainer/LogoutButton


func _ready() -> void:
	# 连接信号
	refresh_button.pressed.connect(_on_refresh_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
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


## 继续游戏按钮按下（TASK-025: 读取槽位1存档并进入游戏）
## TASK-026: 内存列表为空时先拉取存档列表再判断
## （同会话刚保存后 _saves 可能未含新档——保存成功刷新已修复，此处为跨场景兜底）
func _on_continue_pressed() -> void:
	continue_button.disabled = true
	var save_data = SaveService.get_save_by_slot(1)
	if save_data.size() == 0:
		status_label.text = "正在检查存档..."
		var box := {"done": false}
		var handler := func(saves: Array) -> void:
			box["done"] = true
		SaveService.saves_loaded.connect(handler)
		SaveService.load_saves()
		var waited := 0
		while not box["done"] and waited < 300:
			await get_tree().process_frame
			waited += 1
		SaveService.saves_loaded.disconnect(handler)
		save_data = SaveService.get_save_by_slot(1)

	if save_data.size() > 0:
		# TASK-027: 有效存档校验——死亡存档(hp<=0)视为无效，不进入游戏
		var player_state: Variant = save_data.get("player_state", {})
		var current_health := -1
		if player_state is Dictionary:
			current_health = int(player_state.get("current_health", -1))
		if current_health <= 0:
			print("[MainScene] Continue game REJECTED: save is a dead state (hp=", current_health, ")")
			status_label.text = "没有有效存档，请先开始新游戏（登录后自动进入）"
			continue_button.disabled = false
			return
		status_label.text = "正在加载存档 (第" + str(save_data.get("current_floor", 1)) + "层)..."
		print("[MainScene] Continue game: loading save slot 1 (floor ", save_data.get("current_floor", 1), ")")
		GameFlowController.enter_game(1)
	else:
		status_label.text = "没有有效存档，请先开始新游戏（登录后自动进入）"
	continue_button.disabled = false


## 退出按钮按下
func _on_logout_pressed() -> void:
	# TASK-029: 登出统一重置流程状态（重新登录不再被旧状态阻塞）
	GameFlowController.reset_flow()
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

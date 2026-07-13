## 登录界面场景脚本
##
## 处理用户登录和注册逻辑
## 登录成功后使用GameFlowController加载游戏数据

extends Control

## 当前操作类型
var _is_registering: bool = false

## 是否正在处理请求
var _is_processing: bool = false

## 是否正在验证Token（隔离Token验证和正常登录）
var _checking_token: bool = false

## 是否正在进入游戏（防重复触发）
var _entering_game: bool = false

## 节点引用
@onready var username_input: LineEdit = $VBoxContainer/TabContainer/Login/UsernameInput
@onready var password_input: LineEdit = $VBoxContainer/TabContainer/Login/PasswordInput
@onready var login_button: Button = $VBoxContainer/TabContainer/Login/LoginButton

@onready var reg_username_input: LineEdit = $VBoxContainer/TabContainer/Register/RegUsernameInput
@onready var reg_password_input: LineEdit = $VBoxContainer/TabContainer/Register/RegPasswordInput
@onready var reg_email_input: LineEdit = $VBoxContainer/TabContainer/Register/RegEmailInput
@onready var register_button: Button = $VBoxContainer/TabContainer/Register/RegisterButton

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var tab_container: TabContainer = $VBoxContainer/TabContainer


func _ready() -> void:
	# 连接信号
	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(_on_register_pressed)

	ApiClient.request_completed.connect(_on_api_success)
	ApiClient.request_failed.connect(_on_api_error)

	GameFlowController.flow_progress.connect(_on_flow_progress)
	GameFlowController.flow_completed.connect(_on_flow_completed)
	GameFlowController.flow_error.connect(_on_flow_error)

	# 检查是否有保存的Token
	if TokenManager.has_token():
		print("[LoginScene] TOKEN CHECK START - found saved token")
		status_label.text = "检测到已保存的Token，正在验证..."
		_set_buttons_enabled(false)
		_checking_token = true
		_check_existing_token()


## 检查已保存的Token
func _check_existing_token() -> void:
	ApiClient.get_request(APIConfig.PLAYER_PROFILE, true)


## 登录按钮按下
func _on_login_pressed() -> void:
	if _is_processing:
		return

	var username = username_input.text.strip_edges()
	var password = password_input.text

	if username.length() < 3:
		status_label.text = "用户名至少3个字符"
		return

	if password.length() < 8:
		status_label.text = "密码至少8个字符"
		return

	_is_processing = true
	_checking_token = false
	_set_buttons_enabled(false)
	status_label.text = "正在登录..."
	_is_registering = false

	var data = {
		"username": username,
		"password": password
	}
	ApiClient.post_request(APIConfig.AUTH_LOGIN, data)


## 注册按钮按下
func _on_register_pressed() -> void:
	if _is_processing:
		return

	var username = reg_username_input.text.strip_edges()
	var password = reg_password_input.text
	var email = reg_email_input.text.strip_edges()

	if username.length() < 3:
		status_label.text = "用户名至少3个字符"
		return

	if password.length() < 8:
		status_label.text = "密码至少8个字符"
		return

	_is_processing = true
	_checking_token = false
	_set_buttons_enabled(false)
	status_label.text = "正在注册..."
	_is_registering = true

	var data = {
		"username": username,
		"password": password
	}
	if email != "":
		data["email"] = email

	ApiClient.post_request(APIConfig.AUTH_REGISTER, data)


## 设置按钮状态
func _set_buttons_enabled(enabled: bool) -> void:
	login_button.disabled = !enabled
	register_button.disabled = !enabled


## API请求成功回调
func _on_api_success(result: Variant) -> void:
	# 只处理Dictionary类型响应
	if not result is Dictionary:
		return

	# Token验证成功（包含玩家数据）
	if _checking_token and result.has("nickname"):
		print("[LoginScene] TOKEN CHECK SUCCESS - valid player profile")
		print("[LoginScene] Starting game flow from saved token")
		_checking_token = false
		_is_processing = true
		_set_buttons_enabled(false)
		TokenManager.set_user_info(result)
		status_label.text = "正在加载游戏数据..."
		GameFlowController.start_game()
		return

	# 只处理登录/注册响应，忽略其他API响应
	if _is_registering:
		# 注册响应只包含code和message，不包含access_token
		if result.has("code") and result.has("message") and not result.has("access_token"):
			_handle_register_success(result)
	elif result.has("access_token"):
		# 只处理包含access_token的登录响应
		_handle_login_or_profile_success(result)
	# 其他响应（如player profile）不处理，交给其他模块


## 处理注册成功
func _handle_register_success(_result: Dictionary) -> void:
	_is_processing = false
	_set_buttons_enabled(true)
	status_label.text = "注册成功！请登录"
	_is_registering = false
	tab_container.current_tab = 0


## 处理登录成功
func _handle_login_or_profile_success(result: Dictionary) -> void:
	print("[LoginScene] LOGIN SUCCESS - processing login response")

	# 保存Token
	var token = result["access_token"]
	TokenManager.save_token(token)

	if result.has("user"):
		TokenManager.set_user_info(result["user"])

	status_label.text = "登录成功！正在加载游戏数据..."
	print("[LoginScene] Calling GameFlowController.start_game()")

	# 使用GameFlowController启动游戏流程
	GameFlowController.start_game()


## API请求失败回调
func _on_api_error(error: String, status_code: int) -> void:
	print("[LoginScene] API ERROR - error: ", error, " status: ", status_code, " checking_token: ", _checking_token)

	# Token验证阶段的错误处理（不影响GameFlowController状态）
	if _checking_token:
		print("[LoginScene] TOKEN CHECK FAILED - clearing token")
		_checking_token = false
		_is_processing = false
		_set_buttons_enabled(true)
		TokenManager.clear_token()

		if status_code == 401 or status_code == 404:
			status_label.text = "检测到旧账号数据异常，请重新登录"
		else:
			status_label.text = "Token验证失败，请重新登录"
		return

	# 正常登录/注册阶段的错误处理
	_is_processing = false
	_set_buttons_enabled(true)

	# 如果是Token验证失败，清除Token
	if status_code == 401 and TokenManager.has_token():
		TokenManager.clear_token()
		status_label.text = "Token已过期，请重新登录"
		return

	status_label.text = "错误: " + error


## 流程进度回调
func _on_flow_progress(message: String) -> void:
	print("[LoginScene] flow_progress received: ", message)
	status_label.text = message


## 流程完成回调
func _on_flow_completed() -> void:
	print("[LoginScene] FLOW COMPLETED RECEIVED!")

	# 防止重复进入游戏
	if _entering_game:
		print("[LoginScene] Already entering game, skipping...")
		return

	_entering_game = true
	_is_processing = false
	_set_buttons_enabled(true)
	status_label.text = "数据加载完成，进入游戏..."
	print("[LoginScene] Entering game in 0.5 seconds...")

	# 检查节点是否在场景树中，避免 get_tree() 返回 null
	if not is_inside_tree():
		print("[LoginScene] Node not in tree, entering game immediately")
		GameFlowController.enter_game()
		return

	# 延迟一下让用户看到消息
	await get_tree().create_timer(0.5).timeout

	# 再次检查是否还在场景树中（延迟期间可能被移除）
	if not is_inside_tree():
		print("[LoginScene] Node removed from tree during delay")
		return

	print("[LoginScene] Calling GameFlowController.enter_game()")
	GameFlowController.enter_game()


## 流程错误回调
func _on_flow_error(error: String) -> void:
	print("[LoginScene] FLOW ERROR RECEIVED: ", error)
	_is_processing = false
	_set_buttons_enabled(true)
	status_label.text = "加载失败: " + error


## 跳转到主界面
func _go_to_main_scene() -> void:
	SceneManager.go_to_main()

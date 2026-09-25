## 登录界面场景脚本 (Phase 22.1 简化版)
##
## 处理用户登录和注册逻辑
## 登录成功后使用GameFlowController加载游戏数据
##
## Phase 22.1 设计原则：
## - 启动后直接显示登录界面
## - 禁止启动自动验证Token
## - 禁止启动自动登录
## - 只有点击按钮才执行登录
## - 启动到登录界面 <2秒

extends Control

## ==================== 状态标志 ====================

## 是否正在处理请求
var _is_processing: bool = false

## 是否正在进入游戏（防重复触发）
var _entering_game: bool = false

## ==================== 节点引用 ====================

@onready var username_input: LineEdit = $VBoxContainer/TabContainer/Login/UsernameInput
@onready var password_input: LineEdit = $VBoxContainer/TabContainer/Login/PasswordInput
@onready var login_button: Button = $VBoxContainer/TabContainer/Login/LoginButton

@onready var reg_username_input: LineEdit = $VBoxContainer/TabContainer/Register/RegUsernameInput
@onready var reg_password_input: LineEdit = $VBoxContainer/TabContainer/Register/RegPasswordInput
@onready var reg_email_input: LineEdit = $VBoxContainer/TabContainer/Register/RegEmailInput
@onready var register_button: Button = $VBoxContainer/TabContainer/Register/RegisterButton

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var tab_container: TabContainer = $VBoxContainer/TabContainer

## 开发者快速登录按钮（安全引用，不存在不报错）
var _dev_login_button: Button = null


## ==================== 初始化 ====================

func _ready() -> void:
	print("[BOOT] Login Scene Ready: ", Time.get_ticks_msec())

	# TASK-029: 登录界面是生命周期的起点——强制重置流程状态
	# （退出游戏/登出后回登录界面时保证 GameFlow 处于 IDLE）
	GameFlowController.reset_flow()

	# 连接信号
	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(_on_register_pressed)

	ApiClient.request_completed.connect(_on_api_success)
	ApiClient.request_failed.connect(_on_api_error)

	GameFlowController.flow_progress.connect(_on_flow_progress)
	GameFlowController.flow_completed.connect(_on_flow_completed)
	GameFlowController.flow_error.connect(_on_flow_error)

	# 安全获取开发者登录按钮（不存在不报错）
	_dev_login_button = get_node_or_null("VBoxContainer/TabContainer/Login/DevLoginButton")
	if _dev_login_button:
		_dev_login_button.pressed.connect(_on_dev_login_pressed)
		_dev_login_button.visible = APIConfig.DEV_MODE
		print("[LoginScene] Dev login button found")

	# Phase 22.1: 直接显示登录界面，不执行任何自动操作
	_show_login_interface()


## ==================== 登录界面 ====================

## 显示登录界面
func _show_login_interface() -> void:
	_is_processing = false
	_set_buttons_enabled(true)
	status_label.text = "请输入账号密码"
	print("[LOGIN] Waiting User Input: ", Time.get_ticks_msec())


## ==================== 登录操作 ====================

## 登录按钮按下
func _on_login_pressed() -> void:
	if _is_processing:
		print("[LoginScene] Already processing, ignoring login press")
		return

	var username = username_input.text.strip_edges()
	var password = password_input.text

	if username.length() < 3:
		status_label.text = "用户名至少3个字符"
		return

	if password.length() < 8:
		status_label.text = "密码至少8个字符"
		return

	print("[LOGIN] Request Start: ", Time.get_ticks_msec())
	_is_processing = true
	_set_buttons_enabled(false)
	status_label.text = "正在登录..."

	# TASK-029: 生命周期进入 AUTHENTICATING 阶段
	GameFlowController.begin_authentication()

	var data = {
		"username": username,
		"password": password
	}
	ApiClient.post_request(APIConfig.AUTH_LOGIN, data)


## 注册按钮按下
func _on_register_pressed() -> void:
	if _is_processing:
		print("[LoginScene] Already processing, ignoring register press")
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
	_set_buttons_enabled(false)
	status_label.text = "正在注册..."

	var data = {
		"username": username,
		"password": password
	}
	if email != "":
		data["email"] = email

	ApiClient.post_request(APIConfig.AUTH_REGISTER, data)


## 开发者快速登录（只有点击按钮才执行）
func _on_dev_login_pressed() -> void:
	if _is_processing:
		return

	if not APIConfig.DEV_MODE:
		status_label.text = "非开发模式"
		return

	print("[LoginScene] DEV LOGIN: Using test account")
	_is_processing = true
	_set_buttons_enabled(false)
	status_label.text = "开发者登录中..."

	# TASK-029: 生命周期进入 AUTHENTICATING 阶段
	GameFlowController.begin_authentication()

	var data = {
		"username": APIConfig.DEV_USERNAME,
		"password": APIConfig.DEV_PASSWORD
	}
	ApiClient.post_request(APIConfig.AUTH_LOGIN, data)


## ==================== API回调 ====================

## 设置按钮状态
func _set_buttons_enabled(enabled: bool) -> void:
	login_button.disabled = !enabled
	register_button.disabled = !enabled
	if _dev_login_button:
		_dev_login_button.disabled = !enabled


## API请求成功回调
func _on_api_success(result: Variant) -> void:
	# Phase 22.4: LoginScene收到成功
	print("[HTTP DEBUG] LoginScene Received:")
	print("  TIME: ", Time.get_ticks_msec())

	if not result is Dictionary:
		return

	# 登录响应
	if result.has("access_token"):
		_handle_login_success(result)
	# 注册响应
	elif result.has("code") and result.has("message"):
		_handle_register_success(result)


## 处理登录成功
func _handle_login_success(result: Dictionary) -> void:
	print("[LOGIN] Success: ", Time.get_ticks_msec())

	# 保存Token
	var token = result["access_token"]
	TokenManager.save_token(token)

	if result.has("user"):
		TokenManager.set_user_info(result["user"])

	status_label.text = "登录成功！正在加载游戏数据..."

	# 启动游戏流程
	print("[LOGIN] Enter Game: ", Time.get_ticks_msec())
	GameFlowController.start_game()


## 处理注册成功
func _handle_register_success(_result: Dictionary) -> void:
	_is_processing = false
	_set_buttons_enabled(true)
	status_label.text = "注册成功！请登录"
	tab_container.current_tab = 0


## API请求失败回调
func _on_api_error(error: String, status_code: int) -> void:
	print("[LoginScene] API ERROR: ", error, " status: ", status_code)

	_is_processing = false
	_set_buttons_enabled(true)

	# TASK-029: 登录失败回到 IDLE，允许重试（禁止残留 AUTHENTICATING）
	GameFlowController.reset_flow()

	# Token过期
	if status_code == 401 and TokenManager.has_token():
		TokenManager.clear_token()
		status_label.text = "Token已过期，请重新登录"
		return

	status_label.text = "错误: " + error


## ==================== GameFlow回调 ====================

## 流程进度回调
func _on_flow_progress(message: String) -> void:
	print("[LoginScene] flow_progress: ", message)
	status_label.text = message


## 流程完成回调
func _on_flow_completed() -> void:
	print("[LoginScene] FLOW COMPLETED")

	if _entering_game:
		return

	_entering_game = true
	_is_processing = false
	status_label.text = "进入游戏..."

	if not is_inside_tree():
		GameFlowController.enter_game()
		return

	await get_tree().create_timer(0.3).timeout

	if not is_inside_tree():
		return

	GameFlowController.enter_game()


## 流程错误回调
func _on_flow_error(error: String) -> void:
	print("[LoginScene] FLOW ERROR: ", error)
	# TASK-029: 流程错误后回到 IDLE（允许重新登录重试）
	GameFlowController.reset_flow()
	_is_processing = false
	_set_buttons_enabled(true)
	status_label.text = "加载失败: " + error

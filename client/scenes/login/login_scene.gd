## 登录界面场景脚本
##
## 处理用户登录和注册逻辑

extends Control

## 当前操作类型
var _is_registering: bool = false

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

	# 检查是否有保存的Token
	if TokenManager.has_token():
		status_label.text = "检测到已保存的Token，正在验证..."
		_check_existing_token()


## 检查已保存的Token
func _check_existing_token() -> void:
	ApiClient.get_request(APIConfig.PLAYER_PROFILE, true)


## 登录按钮按下
func _on_login_pressed() -> void:
	var username = username_input.text.strip_edges()
	var password = password_input.text

	if username.length() < 3:
		status_label.text = "用户名至少3个字符"
		return

	if password.length() < 8:
		status_label.text = "密码至少8个字符"
		return

	status_label.text = "正在登录..."
	_is_registering = false

	var data = {
		"username": username,
		"password": password
	}
	ApiClient.post_request(APIConfig.AUTH_LOGIN, data)


## 注册按钮按下
func _on_register_pressed() -> void:
	var username = reg_username_input.text.strip_edges()
	var password = reg_password_input.text
	var email = reg_email_input.text.strip_edges()

	if username.length() < 3:
		status_label.text = "用户名至少3个字符"
		return

	if password.length() < 8:
		status_label.text = "密码至少8个字符"
		return

	status_label.text = "正在注册..."
	_is_registering = true

	var data = {
		"username": username,
		"password": password
	}
	if email != "":
		data["email"] = email

	ApiClient.post_request(APIConfig.AUTH_REGISTER, data)


## API请求成功回调
func _on_api_success(result: Dictionary) -> void:
	if _is_registering:
		_handle_register_success(result)
	else:
		_handle_login_or_profile_success(result)


## 处理注册成功
func _handle_register_success(_result: Dictionary) -> void:
	status_label.text = "注册成功！请登录"
	_is_registering = false
	tab_container.current_tab = 0


## 处理登录或玩家信息成功
func _handle_login_or_profile_success(result: Dictionary) -> void:
	# 检查是否是登录响应（包含access_token）
	if result.has("access_token"):
		var token = result["access_token"]
		TokenManager.save_token(token)

		if result.has("user"):
			TokenManager.set_user_info(result["user"])

		status_label.text = "登录成功！"

		# 切换到主界面
		_go_to_main_scene()
	# 检查是否是玩家信息响应（已有Token验证成功）
	elif result.has("id") and result.has("nickname"):
		TokenManager.set_user_info(result)
		_go_to_main_scene()
	else:
		status_label.text = "未知响应格式"


## API请求失败回调
func _on_api_error(error: String, status_code: int) -> void:
	# 如果是Token验证失败，清除Token
	if status_code == 401 and TokenManager.has_token():
		TokenManager.clear_token()
		status_label.text = "Token已过期，请重新登录"
		return

	status_label.text = "错误: " + error


## 跳转到游戏场景
func _go_to_main_scene() -> void:
	SceneManager.go_to_game()

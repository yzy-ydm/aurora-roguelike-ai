## JWT Token管理模块
##
## 负责保存、读取、清除JWT Token
## 作为全局单例使用

extends Node

## Token存储路径
const TOKEN_PATH: String = "user://token.dat"

## 当前Token
var _current_token: String = ""

## 用户信息缓存
var _user_info: Dictionary = {}

## 信号：Token变更
signal token_changed(token: String)
signal token_cleared


## 保存Token到文件
func save_token(token: String) -> void:
	_current_token = token

	# 写入文件
	var file = FileAccess.open(TOKEN_PATH, FileAccess.WRITE)
	if file:
		file.store_string(token)
		file.close()

	token_changed.emit(token)


## 从文件加载Token
func load_token() -> String:
	if _current_token != "":
		return _current_token

	if FileAccess.file_exists(TOKEN_PATH):
		var file = FileAccess.open(TOKEN_PATH, FileAccess.READ)
		if file:
			_current_token = file.get_as_text()
			file.close()
			token_changed.emit(_current_token)

	return _current_token


## 获取当前Token
func get_token() -> String:
	if _current_token == "":
		load_token()
	return _current_token


## 检查是否有Token
func has_token() -> bool:
	if _current_token == "":
		load_token()
	return _current_token != ""


## 清除Token
func clear_token() -> void:
	_current_token = ""
	_user_info = {}

	# 删除文件
	if FileAccess.file_exists(TOKEN_PATH):
		DirAccess.remove_absolute(TOKEN_PATH)

	token_cleared.emit()


## 设置用户信息
func set_user_info(info: Dictionary) -> void:
	_user_info = info


## 获取用户信息
func get_user_info() -> Dictionary:
	return _user_info


## 获取Authorization头
func get_auth_header() -> String:
	if has_token():
		return "Authorization: Bearer " + get_token()
	return ""

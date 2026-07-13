## API客户端模块
##
## 负责发送HTTP请求，处理JSON响应
## 作为全局单例使用

extends Node

## 信号：请求完成
signal request_completed(result: Dictionary)
signal request_failed(error: String, status_code: int)

## HTTP请求节点
var _http_request: HTTPRequest

## 当前请求队列
var _pending_requests: Array = []


func _ready() -> void:
	# 创建HTTPRequest节点
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)


## 发送GET请求
func get_request(endpoint: String, use_auth: bool = false) -> void:
	var url = APIConfig.get_full_url(endpoint)
	var headers: PackedStringArray = ["Content-Type: application/json"]

	if use_auth and TokenManager.has_token():
		headers.append(TokenManager.get_auth_header())

	var error = _http_request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		request_failed.emit("HTTP请求创建失败", 0)


## 发送POST请求
func post_request(endpoint: String, data: Dictionary, use_auth: bool = false) -> void:
	var url = APIConfig.get_full_url(endpoint)
	var headers: PackedStringArray = ["Content-Type: application/json"]

	if use_auth and TokenManager.has_token():
		headers.append(TokenManager.get_auth_header())

	var json_string = JSON.stringify(data)
	var error = _http_request.request(url, headers, HTTPClient.METHOD_POST, json_string)
	if error != OK:
		request_failed.emit("HTTP请求创建失败", 0)


## 发送PUT请求
func put_request(endpoint: String, data: Dictionary, use_auth: bool = false) -> void:
	var url = APIConfig.get_full_url(endpoint)
	var headers: PackedStringArray = ["Content-Type: application/json"]

	if use_auth and TokenManager.has_token():
		headers.append(TokenManager.get_auth_header())

	var json_string = JSON.stringify(data)
	var error = _http_request.request(url, headers, HTTPClient.METHOD_PUT, json_string)
	if error != OK:
		request_failed.emit("HTTP请求创建失败", 0)


## HTTP请求完成回调
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# 检查请求结果
	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit("网络连接失败", 0)
		return

	# 解析响应体
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())

	if parse_result != OK:
		request_failed.emit("JSON解析失败", response_code)
		return

	var response_data = json.data

	# 检查HTTP状态码
	if response_code >= 200 and response_code < 300:
		request_completed.emit(response_data)
	else:
		# 提取错误信息
		var error_message = "未知错误"
		if response_data is Dictionary:
			if response_data.has("detail"):
				error_message = response_data["detail"]
			elif response_data.has("message"):
				error_message = response_data["message"]
		request_failed.emit(error_message, response_code)

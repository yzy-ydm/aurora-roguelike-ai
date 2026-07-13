## API客户端模块
##
## 负责发送HTTP请求，处理JSON响应
## 使用请求队列避免并发冲突
## 作为全局单例使用

extends Node

## 信号：请求完成（使用Variant支持Array和Dictionary）
signal request_completed(result: Variant)
signal request_failed(error: String, status_code: int)

## 请求队列
var _request_queue: Array = []

## 当前是否正在处理请求
var _is_processing: bool = false


func _ready() -> void:
	pass


## 发送GET请求
func get_request(endpoint: String, use_auth: bool = false) -> void:
	var url = APIConfig.get_full_url(endpoint)
	var headers: PackedStringArray = ["Content-Type: application/json"]

	if use_auth and TokenManager.has_token():
		headers.append(TokenManager.get_auth_header())

	_queue_request(url, headers, HTTPClient.METHOD_GET, "")


## 发送POST请求
func post_request(endpoint: String, data: Dictionary, use_auth: bool = false) -> void:
	var url = APIConfig.get_full_url(endpoint)
	var headers: PackedStringArray = ["Content-Type: application/json"]

	if use_auth and TokenManager.has_token():
		headers.append(TokenManager.get_auth_header())

	var json_string = JSON.stringify(data)
	_queue_request(url, headers, HTTPClient.METHOD_POST, json_string)


## 发送PUT请求
func put_request(endpoint: String, data: Dictionary, use_auth: bool = false) -> void:
	var url = APIConfig.get_full_url(endpoint)
	var headers: PackedStringArray = ["Content-Type: application/json"]

	if use_auth and TokenManager.has_token():
		headers.append(TokenManager.get_auth_header())

	var json_string = JSON.stringify(data)
	_queue_request(url, headers, HTTPClient.METHOD_PUT, json_string)


## 将请求加入队列
func _queue_request(url: String, headers: PackedStringArray, method: int, body: String) -> void:
	print("[ApiClient] Queuing request: ", url)
	var request_data = {
		"url": url,
		"headers": headers,
		"method": method,
		"body": body
	}
	_request_queue.append(request_data)
	_process_next_request()


## 处理队列中的下一个请求
func _process_next_request() -> void:
	if _is_processing:
		return

	if _request_queue.is_empty():
		return

	_is_processing = true
	var request_data = _request_queue.pop_front()

	# 创建新的HTTPRequest节点
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed.bind(http_request))

	# 发送请求
	print("[ApiClient] Sending HTTP request to: ", request_data["url"])
	print("[ApiClient] Headers: ", request_data["headers"])
	var error = http_request.request(
		request_data["url"],
		request_data["headers"],
		request_data["method"],
		request_data["body"]
	)

	if error != OK:
		_is_processing = false
		http_request.queue_free()
		request_failed.emit("HTTP请求创建失败", 0)
		_process_next_request()


## HTTP请求完成回调
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest) -> void:
	# 释放HTTPRequest节点
	http_request.queue_free()
	_is_processing = false

	# 检查请求结果
	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit("网络连接失败", 0)
		_process_next_request()
		return

	# 解析响应体
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())

	if parse_result != OK:
		request_failed.emit("JSON解析失败", response_code)
		_process_next_request()
		return

	var response_data = json.data

	# [DEBUG] 打印响应信息
	print("[ApiClient] Response Code: ", response_code)
	print("[ApiClient] Response Data: ", response_data)

	# 检查HTTP状态码
	if response_code >= 200 and response_code < 300:
		print("[ApiClient] Emitting request_completed signal")
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

	# 处理下一个请求
	_process_next_request()

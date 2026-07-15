## 存档系统 (Phase 12)
##
## 负责游戏存档的保存和加载
## 使用JSON格式存储
## 保存路径: user://save/

extends Node

## 存档目录
const SAVE_DIR: String = "user://save/"

## 存档文件扩展名
const SAVE_EXTENSION: String = ".json"

## 最大存档槽位
const MAX_SAVE_SLOTS: int = 3

## 信号
signal save_completed(slot: int, success: bool)
signal load_completed(slot: int, success: bool)
signal save_error(error: String)


func _ready() -> void:
	# 确保存档目录存在
	_ensure_save_dir()


## 确保存档目录存在
func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		print("[SaveSystem] Created save directory: ", SAVE_DIR)


## 保存游戏
func save_game(slot: int, data: Dictionary) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		print("[SaveSystem] Invalid save slot: ", slot)
		save_error.emit("Invalid save slot")
		return false

	var file_path = _get_save_path(slot)

	# 添加元数据
	var save_data = {
		"version": "1.0",
		"timestamp": Time.get_unix_time_from_system(),
		"slot": slot,
		"data": data
	}

	# 转换为JSON
	var json_string = JSON.stringify(save_data, "\t")

	# 写入文件
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		var error_msg = "Failed to open file for writing: " + file_path
		print("[SaveSystem] ", error_msg)
		save_error.emit(error_msg)
		save_completed.emit(slot, false)
		return false

	file.store_string(json_string)
	file.close()

	print("[SaveSystem] Game saved to slot ", slot)
	save_completed.emit(slot, true)
	return true


## 加载游戏
func load_game(slot: int) -> Dictionary:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		print("[SaveSystem] Invalid save slot: ", slot)
		load_completed.emit(slot, false)
		return {}

	var file_path = _get_save_path(slot)

	# 检查文件是否存在
	if not FileAccess.file_exists(file_path):
		print("[SaveSystem] Save file not found: ", file_path)
		load_completed.emit(slot, false)
		return {}

	# 读取文件
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[SaveSystem] Failed to open file for reading: ", file_path)
		load_completed.emit(slot, false)
		return {}

	var json_string = file.get_as_text()
	file.close()

	# 解析JSON
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		print("[SaveSystem] Failed to parse save file: ", file_path)
		load_completed.emit(slot, false)
		return {}

	var save_data = json.data

	# 验证存档格式
	if not _validate_save_data(save_data):
		print("[SaveSystem] Invalid save data format")
		load_completed.emit(slot, false)
		return {}

	print("[SaveSystem] Game loaded from slot ", slot)
	load_completed.emit(slot, true)
	return save_data.get("data", {})


## 删除存档
func delete_save(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return false

	var file_path = _get_save_path(slot)

	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		print("[SaveSystem] Deleted save slot ", slot)
		return true

	return false


## 检查存档是否存在
func save_exists(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return false
	return FileAccess.file_exists(_get_save_path(slot))


## 获取存档信息（不加载完整数据）
func get_save_info(slot: int) -> Dictionary:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return {}

	var file_path = _get_save_path(slot)

	if not FileAccess.file_exists(file_path):
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		return {}

	var save_data = json.data

	return {
		"slot": slot,
		"timestamp": save_data.get("timestamp", 0),
		"version": save_data.get("version", "unknown"),
		"exists": true
	}


## 获取所有存档信息
func get_all_save_info() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	for i in range(MAX_SAVE_SLOTS):
		saves.append(get_save_info(i))
	return saves


## 获取存档路径
func _get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_" + str(slot) + SAVE_EXTENSION


## 验证存档数据
func _validate_save_data(data: Dictionary) -> bool:
	# 检查必要字段
	if not data.has("version"):
		return false
	if not data.has("data"):
		return false
	return true

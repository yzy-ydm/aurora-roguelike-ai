## AI缓存管理器
##
## 缓存AI生成结果
## 支持楼层数据和房间内容缓存
## 提供缓存持久化功能

extends Node

## 缓存文件路径
const CACHE_DIR = "user://ai_cache/"
const FLOOR_CACHE_FILE = "floor_cache.json"
const ROOM_CACHE_FILE = "room_cache.json"

## 内存缓存
var _floor_cache: Dictionary = {}  # floor_level -> data
var _room_cache: Dictionary = {}   # room_id -> data

## 缓存统计
var _cache_hits: int = 0
var _cache_misses: int = 0

## 信号
signal cache_loaded()
signal cache_saved()
signal cache_cleared()


## 初始化
func _ready() -> void:
	# 创建缓存目录
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	print("[CacheManager] Initialized, cache dir: ", CACHE_DIR)


## 获取楼层缓存
func get_floor_cache(floor_level: int) -> Dictionary:
	var key = str(floor_level)
	if _floor_cache.has(key):
		_cache_hits += 1
		print("[CacheManager] Floor cache hit: ", floor_level)
		return _floor_cache[key]

	_cache_misses += 1
	print("[CacheManager] Floor cache miss: ", floor_level)
	return {}


## 设置楼层缓存
func set_floor_cache(floor_level: int, data: Dictionary) -> void:
	var key = str(floor_level)
	_floor_cache[key] = data
	print("[CacheManager] Floor cached: ", floor_level)


## 获取房间内容缓存
func get_room_cache(room_id: int) -> Dictionary:
	var key = str(room_id)
	if _room_cache.has(key):
		_cache_hits += 1
		print("[CacheManager] Room cache hit: ", room_id)
		return _room_cache[key]

	_cache_misses += 1
	print("[CacheManager] Room cache miss: ", room_id)
	return {}


## 设置房间内容缓存
func set_room_cache(room_id: int, data: Dictionary) -> void:
	var key = str(room_id)
	_room_cache[key] = data
	print("[CacheManager] Room cached: ", room_id)


## 检查楼层缓存是否存在
func has_floor_cache(floor_level: int) -> bool:
	return _floor_cache.has(str(floor_level))


## 检查房间缓存是否存在
func has_room_cache(room_id: int) -> bool:
	return _room_cache.has(str(room_id))


## 保存缓存到文件
func save_cache() -> void:
	print("[CacheManager] Saving cache...")

	# 保存楼层缓存
	_save_json_file(CACHE_DIR + FLOOR_CACHE_FILE, _floor_cache)

	# 保存房间缓存
	_save_json_file(CACHE_DIR + ROOM_CACHE_FILE, _room_cache)

	cache_saved.emit()
	print("[CacheManager] Cache saved")


## 从文件加载缓存
func load_cache() -> void:
	print("[CacheManager] Loading cache...")

	# 加载楼层缓存
	var floor_data = _load_json_file(CACHE_DIR + FLOOR_CACHE_FILE)
	if floor_data:
		_floor_cache = floor_data

	# 加载房间缓存
	var room_data = _load_json_file(CACHE_DIR + ROOM_CACHE_FILE)
	if room_data:
		_room_cache = room_data

	cache_loaded.emit()
	print("[CacheManager] Cache loaded, floors: ", _floor_cache.size(), " rooms: ", _room_cache.size())


## 清除缓存
func clear_cache() -> void:
	_floor_cache.clear()
	_room_cache.clear()

	# 删除缓存文件
	_delete_file(CACHE_DIR + FLOOR_CACHE_FILE)
	_delete_file(CACHE_DIR + ROOM_CACHE_FILE)

	cache_cleared.emit()
	print("[CacheManager] Cache cleared")


## 获取缓存统计
func get_cache_stats() -> Dictionary:
	return {
		"floor_cache_size": _floor_cache.size(),
		"room_cache_size": _room_cache.size(),
		"cache_hits": _cache_hits,
		"cache_misses": _cache_misses,
		"hit_rate": _get_hit_rate()
	}


## 获取命中率
func _get_hit_rate() -> float:
	var total = _cache_hits + _cache_misses
	if total == 0:
		return 0.0
	return float(_cache_hits) / float(total)


## 保存JSON文件
func _save_json_file(file_path: String, data: Dictionary) -> void:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("[CacheManager] Saved: ", file_path)
	else:
		print("[CacheManager] Error: Failed to save ", file_path)


## 加载JSON文件
func _load_json_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		print("[CacheManager] File not found: ", file_path)
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[CacheManager] Error: Failed to open ", file_path)
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("[CacheManager] Error: Failed to parse JSON: ", file_path)
		return {}

	var data = json.data
	if data is Dictionary:
		return data

	print("[CacheManager] Error: Invalid JSON format: ", file_path)
	return {}


## 删除文件
func _delete_file(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		print("[CacheManager] Deleted: ", file_path)


## 打印缓存状态
func print_cache_status() -> void:
	print("[CacheManager] Cache Status:")
	print("  Floor cache: ", _floor_cache.size(), " entries")
	print("  Room cache: ", _room_cache.size(), " entries")
	print("  Cache hits: ", _cache_hits)
	print("  Cache misses: ", _cache_misses)
	print("  Hit rate: ", _get_hit_rate() * 100, "%")

## 资源管理器模块
##
## 负责管理游戏资源的加载和缓存
## 作为全局单例使用

extends Node

## 资源缓存
var _texture_cache: Dictionary = {}
var _audio_cache: Dictionary = {}

## 信号：资源加载完成
signal resource_loaded(path: String)
signal resource_load_failed(path: String, error: String)


## 加载纹理资源
func load_texture(path: String) -> Texture2D:
	# 检查缓存
	if _texture_cache.has(path):
		return _texture_cache[path]

	# 加载资源
	if ResourceLoader.exists(path):
		var texture = load(path) as Texture2D
		if texture:
			_texture_cache[path] = texture
			resource_loaded.emit(path)
			return texture
		else:
			resource_load_failed.emit(path, "纹理加载失败")
			return null
	else:
		resource_load_failed.emit(path, "资源不存在")
		return null


## 加载音频资源
func load_audio(path: String) -> AudioStream:
	# 检查缓存
	if _audio_cache.has(path):
		return _audio_cache[path]

	# 加载资源
	if ResourceLoader.exists(path):
		var audio = load(path) as AudioStream
		if audio:
			_audio_cache[path] = audio
			resource_loaded.emit(path)
			return audio
		else:
			resource_load_failed.emit(path, "音频加载失败")
			return null
	else:
		resource_load_failed.emit(path, "资源不存在")
		return null


## 预加载资源
func preload_resource(path: String) -> void:
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource:
			if resource is Texture2D:
				_texture_cache[path] = resource
			elif resource is AudioStream:
				_audio_cache[path] = resource
			resource_loaded.emit(path)
		else:
			resource_load_failed.emit(path, "资源加载失败")
	else:
		resource_load_failed.emit(path, "资源不存在")


## 清除缓存
func clear_cache() -> void:
	_texture_cache.clear()
	_audio_cache.clear()


## 清除指定资源缓存
func clear_resource(path: String) -> void:
	_texture_cache.erase(path)
	_audio_cache.erase(path)


## 获取缓存的纹理
func get_cached_texture(path: String) -> Texture2D:
	return _texture_cache.get(path)


## 获取缓存的音频
func get_cached_audio(path: String) -> AudioStream:
	return _audio_cache.get(path)


## 检查资源是否已缓存
func is_cached(path: String) -> bool:
	return _texture_cache.has(path) or _audio_cache.has(path)

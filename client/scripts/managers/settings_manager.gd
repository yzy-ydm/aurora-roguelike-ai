## 设置管理器模块
##
## 负责管理游戏设置
## 使用ConfigFile保存本地配置
## 作为全局单例使用

extends Node

## 配置文件路径
const CONFIG_PATH: String = "user://settings.cfg"

## 默认设置
const DEFAULT_MASTER_VOLUME: float = 1.0
const DEFAULT_MUSIC_VOLUME: float = 0.8
const DEFAULT_SFX_VOLUME: float = 1.0

## 当前设置
var _master_volume: float = DEFAULT_MASTER_VOLUME
var _music_volume: float = DEFAULT_MUSIC_VOLUME
var _sfx_volume: float = DEFAULT_SFX_VOLUME

## 信号
signal settings_changed


func _ready() -> void:
	_load_settings()


## 加载设置
func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)

	if err == OK:
		_master_volume = config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)
		_music_volume = config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)
		_sfx_volume = config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)
	else:
		# 使用默认值并保存
		_save_settings()


## 保存设置
func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", _master_volume)
	config.set_value("audio", "music_volume", _music_volume)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.save(CONFIG_PATH)


## 获取主音量
func get_master_volume() -> float:
	return _master_volume


## 设置主音量
func set_master_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_save_settings()
	settings_changed.emit()


## 获取音乐音量
func get_music_volume() -> float:
	return _music_volume


## 设置音乐音量
func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_save_settings()
	settings_changed.emit()


## 获取音效音量
func get_sfx_volume() -> float:
	return _sfx_volume


## 设置音效音量
func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_save_settings()
	settings_changed.emit()


## 重置为默认设置
func reset_to_defaults() -> void:
	_master_volume = DEFAULT_MASTER_VOLUME
	_music_volume = DEFAULT_MUSIC_VOLUME
	_sfx_volume = DEFAULT_SFX_VOLUME
	_save_settings()
	settings_changed.emit()

## 设置菜单控制器
##
## 负责设置界面的显示和交互
## 管理音量设置

extends CanvasLayer

## 节点引用
@onready var master_slider: HSlider = $Panel/VBox/MasterVolume/Slider
@onready var master_value: Label = $Panel/VBox/MasterVolume/Value
@onready var music_slider: HSlider = $Panel/VBox/MusicVolume/Slider
@onready var music_value: Label = $Panel/VBox/MusicVolume/Value
@onready var sfx_slider: HSlider = $Panel/VBox/SFXVolume/Slider
@onready var sfx_value: Label = $Panel/VBox/SFXVolume/Value
@onready var reset_button: Button = $Panel/VBox/ResetButton
@onready var back_button: Button = $Panel/VBox/BackButton

## 信号
signal settings_closed


func _ready() -> void:
	# 连接按钮信号
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)

	# 连接滑块信号
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	# 初始隐藏
	visible = false


## 显示设置菜单
func show_settings() -> void:
	# 加载当前设置
	master_slider.value = SettingsManager.get_master_volume() * 100
	music_slider.value = SettingsManager.get_music_volume() * 100
	sfx_slider.value = SettingsManager.get_sfx_volume() * 100

	_update_value_labels()
	visible = true


## 隐藏设置菜单
func hide_settings() -> void:
	visible = false


## 更新数值标签
func _update_value_labels() -> void:
	master_value.text = str(int(master_slider.value)) + "%"
	music_value.text = str(int(music_slider.value)) + "%"
	sfx_value.text = str(int(sfx_slider.value)) + "%"


## 主音量变化
func _on_master_changed(value: float) -> void:
	SettingsManager.set_master_volume(value / 100.0)
	_update_value_labels()


## 音乐音量变化
func _on_music_changed(value: float) -> void:
	SettingsManager.set_music_volume(value / 100.0)
	_update_value_labels()


## 音效音量变化
func _on_sfx_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value / 100.0)
	_update_value_labels()


## 恢复默认按钮
func _on_reset_pressed() -> void:
	SettingsManager.reset_to_defaults()
	# 更新滑块显示
	master_slider.value = SettingsManager.get_master_volume() * 100
	music_slider.value = SettingsManager.get_music_volume() * 100
	sfx_slider.value = SettingsManager.get_sfx_volume() * 100
	_update_value_labels()


## 返回按钮
func _on_back_pressed() -> void:
	hide_settings()
	settings_closed.emit()

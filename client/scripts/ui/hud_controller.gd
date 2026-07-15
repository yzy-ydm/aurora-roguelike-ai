## HUD控制器脚本 (Phase 15 增强)
##
## 负责显示游戏内HUD信息
## 包括：玩家昵称、等级、生命值、经验值、金币、楼层、房间、战斗状态
##
## Phase 10.1.6: 添加DEBUG_UI开关控制调试信息显示

extends CanvasLayer

## ==================== 调试开关 ====================

## DEBUG_UI开关 - 控制调试信息显示
## 设为false时隐藏：资源面板、调试状态、开发信息
const DEBUG_UI: bool = false

## ==================== 节点引用 ====================

@onready var nickname_label: Label = $TopBar/PlayerInfo/NicknameLabel
@onready var level_label: Label = $TopBar/PlayerInfo/LevelLabel
@onready var health_label: Label = $TopBar/StatsContainer/HealthBar/HealthLabel
@onready var health_progress: ProgressBar = $TopBar/StatsContainer/HealthBar/HealthProgress
@onready var exp_label: Label = $TopBar/StatsContainer/ExpBar/ExpLabel
@onready var exp_progress: ProgressBar = $TopBar/StatsContainer/ExpBar/ExpProgress
@onready var gold_label: Label = $TopBar/GoldContainer/GoldLabel
@onready var floor_label: Label = $TopBar/FloorInfo/FloorLabel
@onready var room_label: Label = $TopBar/FloorInfo/RoomLabel
@onready var weapon_count: Label = $ResourcePanel/ResourceInfo/WeaponCount
@onready var monster_count: Label = $ResourcePanel/ResourceInfo/MonsterCount
@onready var map_count: Label = $ResourcePanel/ResourceInfo/MapCount
@onready var event_count: Label = $ResourcePanel/ResourceInfo/EventCount
@onready var status_label: Label = $StatusPanel/StatusLabel
@onready var combat_label: Label = $CombatPanel/CombatInfo/MonsterCount
@onready var boss_health_bar: ProgressBar = $BossPanel/BossHealthBar
@onready var boss_name_label: Label = $BossPanel/BossName
@onready var resource_panel: PanelContainer = $ResourcePanel

## 玩家数据缓存
var _player_data: Dictionary = {}

## 战斗状态
var _combat_kills: int = 0
var _combat_total: int = 0


func _ready() -> void:
	# 初始显示
	_clear_display()

	# Phase 10.1.6: 非DEBUG模式下隐藏调试面板
	if not DEBUG_UI:
		_hide_debug_panels()


## 更新HUD显示
func update_hud(data: Dictionary) -> void:
	_player_data = data
	_update_display()


## 更新显示内容
func _update_display() -> void:
	# 玩家昵称
	var nickname = _player_data.get("nickname", "未知玩家")
	if nickname_label:
		nickname_label.text = "玩家: " + str(nickname)

	# 等级
	var level = _player_data.get("level", 1)
	if level_label:
		level_label.text = "Lv." + str(level)

	# 生命值
	var current_health = _player_data.get("current_health", 0)
	var max_health = _player_data.get("max_health", 100)
	if health_label:
		health_label.text = "HP: " + str(current_health) + "/" + str(max_health)

	# 生命值进度条
	if health_progress:
		if max_health > 0:
			health_progress.value = (float(current_health) / float(max_health)) * 100.0
		else:
			health_progress.value = 0

	# Phase 15: 经验值
	var current_exp = _player_data.get("current_exp", 0)
	var max_exp = _player_data.get("max_exp", 100)
	if exp_label:
		exp_label.text = "EXP: " + str(current_exp) + "/" + str(max_exp)
	if exp_progress:
		if max_exp > 0:
			exp_progress.value = (float(current_exp) / float(max_exp)) * 100.0
		else:
			exp_progress.value = 0

	# 金币
	var gold = _player_data.get("gold", 0)
	if gold_label:
		gold_label.text = "金币: " + str(gold)


## 更新资源统计显示
func update_resource_counts(weapons: int, monsters: int, maps: int, events: int) -> void:
	if weapon_count:
		weapon_count.text = "武器: " + str(weapons)
	if monster_count:
		monster_count.text = "怪物: " + str(monsters)
	if map_count:
		map_count.text = "地图: " + str(maps)
	if event_count:
		event_count.text = "事件: " + str(events)


## 清除显示
func _clear_display() -> void:
	if nickname_label:
		nickname_label.text = "玩家: 加载中..."
	if level_label:
		level_label.text = "等级: -"
	if health_label:
		health_label.text = "生命值: -/-"
	if health_progress:
		health_progress.value = 0
	if gold_label:
		gold_label.text = "金币: -"
	if weapon_count:
		weapon_count.text = "武器: 加载中..."
	if monster_count:
		monster_count.text = "怪物: 加载中..."
	if map_count:
		map_count.text = "地图: 加载中..."
	if event_count:
		event_count.text = "事件: 加载中..."


## Phase 10.1.6: 隐藏调试面板
func _hide_debug_panels() -> void:
	# 隐藏资源面板
	if resource_panel:
		resource_panel.visible = false

	# 隐藏战斗面板（可选，根据需要调整）
	# 战斗面板在游戏中会自动显示，所以这里不隐藏

	print("[HUD] Debug panels hidden (DEBUG_UI=false)")


## 设置状态文本
func set_status(text: String) -> void:
	if status_label:
		status_label.text = text


## 获取当前玩家数据
func get_player_data() -> Dictionary:
	return _player_data


## Phase 15: 更新楼层信息
func update_floor_info(floor: int, room: int) -> void:
	if floor_label:
		floor_label.text = "第" + str(floor) + "层"
	if room_label:
		room_label.text = "区域" + str(room)


## Phase 10.1: 更新楼层信息(带房间类型)
func update_floor_info_with_type(floor: int, display_index: int, room_type: String) -> void:
	if floor_label:
		floor_label.text = "第" + str(floor) + "层"
	if room_label:
		room_label.text = "区域" + str(display_index) + "\n" + room_type


## Phase 15: 更新战斗状态
func update_combat_status(kills: int, total: int) -> void:
	_combat_kills = kills
	_combat_total = total
	if combat_label:
		combat_label.text = "怪物: " + str(kills) + "/" + str(total)


## Phase 15: 显示Boss血条
func show_boss_health(boss_name: String, current_hp: int, max_hp: int) -> void:
	if boss_name_label:
		boss_name_label.text = boss_name
	if boss_health_bar:
		boss_health_bar.visible = true
		boss_health_bar.max_value = max_hp
		boss_health_bar.value = current_hp


## Phase 15: 更新Boss血条
func update_boss_health(current_hp: int, max_hp: int) -> void:
	if boss_health_bar:
		boss_health_bar.value = current_hp


## Phase 15: 隐藏Boss血条
func hide_boss_health() -> void:
	if boss_health_bar:
		boss_health_bar.visible = false
	if boss_name_label:
		boss_name_label.text = ""


## Phase 15: 显示AI状态
func show_ai_status(text: String) -> void:
	# 在状态栏显示AI状态
	set_status("[AI] " + text)

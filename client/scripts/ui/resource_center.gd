## 资源中心控制器
##
## 负责管理资源展示页面
## 调用ResourceService获取数据并显示

extends Control

## 节点引用
@onready var tab_container: TabContainer = $VBoxContainer/TabContainer
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var back_button: Button = $VBoxContainer/BackButton

## 武器面板节点
@onready var weapon_list: ItemList = $VBoxContainer/TabContainer/Weapons/WeaponList
@onready var weapon_detail: RichTextLabel = $VBoxContainer/TabContainer/Weapons/WeaponDetail

## 怪物面板节点
@onready var monster_list: ItemList = $VBoxContainer/TabContainer/Monsters/MonsterList
@onready var monster_detail: RichTextLabel = $VBoxContainer/TabContainer/Monsters/MonsterDetail

## 地图面板节点
@onready var map_list: ItemList = $VBoxContainer/TabContainer/Maps/MapList
@onready var map_detail: RichTextLabel = $VBoxContainer/TabContainer/Maps/MapDetail

## 事件面板节点
@onready var event_list: ItemList = $VBoxContainer/TabContainer/Events/EventList
@onready var event_detail: RichTextLabel = $VBoxContainer/TabContainer/Events/EventDetail


func _ready() -> void:
	# 连接信号
	back_button.pressed.connect(_on_back_pressed)
	weapon_list.item_selected.connect(_on_weapon_selected)
	monster_list.item_selected.connect(_on_monster_selected)
	map_list.item_selected.connect(_on_map_selected)
	event_list.item_selected.connect(_on_event_selected)

	ResourceService.all_resources_loaded.connect(_on_resources_loaded)
	ResourceService.resource_load_error.connect(_on_resource_error)

	# 加载资源
	_load_resources()


## 加载资源
func _load_resources() -> void:
	status_label.text = "加载资源中..."

	if ResourceService.is_loaded():
		_on_resources_loaded()
	else:
		ResourceService.load_all_resources()


## 资源加载完成
func _on_resources_loaded() -> void:
	status_label.text = "资源加载完成"
	_populate_weapon_list()
	_populate_monster_list()
	_populate_map_list()
	_populate_event_list()


## 资源加载失败
func _on_resource_error(error: String) -> void:
	status_label.text = "资源加载失败: " + error


## 填充武器列表
func _populate_weapon_list() -> void:
	weapon_list.clear()
	var weapons = ResourceService.get_weapons()
	for weapon in weapons:
		weapon_list.add_item(weapon.name + " [" + weapon.rarity + "]")


## 填充怪物列表
func _populate_monster_list() -> void:
	monster_list.clear()
	var monsters = ResourceService.get_monsters()
	for monster in monsters:
		monster_list.add_item(monster.name + " [Lv." + str(monster.level) + "]")


## 填充地图列表
func _populate_map_list() -> void:
	map_list.clear()
	var maps = ResourceService.get_maps()
	for map_data in maps:
		map_list.add_item(map_data.name + " [F" + str(map_data.floor_level) + "]")


## 填充事件列表
func _populate_event_list() -> void:
	event_list.clear()
	var events = ResourceService.get_events()
	for event in events:
		event_list.add_item(event.name + " [" + event.type + "]")


## 武器选中
func _on_weapon_selected(index: int) -> void:
	var weapons = ResourceService.get_weapons()
	if index >= 0 and index < weapons.size():
		var weapon = weapons[index]
		weapon_detail.text = _format_weapon_detail(weapon)


## 怪物选中
func _on_monster_selected(index: int) -> void:
	var monsters = ResourceService.get_monsters()
	if index >= 0 and index < monsters.size():
		var monster = monsters[index]
		monster_detail.text = _format_monster_detail(monster)


## 地图选中
func _on_map_selected(index: int) -> void:
	var maps = ResourceService.get_maps()
	if index >= 0 and index < maps.size():
		var map_data = maps[index]
		map_detail.text = _format_map_detail(map_data)


## 事件选中
func _on_event_selected(index: int) -> void:
	var events = ResourceService.get_events()
	if index >= 0 and index < events.size():
		var event = events[index]
		event_detail.text = _format_event_detail(event)


## 格式化武器详情
func _format_weapon_detail(weapon: WeaponData) -> String:
	var text = ""
	text += "[b]" + weapon.name + "[/b]\n\n"
	text += "类型: " + weapon.type + "\n"
	text += "稀有度: " + weapon.rarity + "\n"
	text += "攻击力: " + str(weapon.damage) + "\n"
	text += "暴击加成: " + str(weapon.crit_rate_bonus) + "%\n"
	text += "价格: " + str(weapon.price) + " 金币\n\n"
	if weapon.description != "":
		text += "[i]" + weapon.description + "[/i]\n\n"
	if weapon.special_effect != "":
		text += "特殊效果: " + weapon.special_effect + "\n"
	return text


## 格式化怪物详情
func _format_monster_detail(monster: MonsterData) -> String:
	var text = ""
	text += "[b]" + monster.name + "[/b]\n\n"
	text += "类型: " + monster.type + "\n"
	text += "等级: " + str(monster.level) + "\n"
	text += "生命值: " + str(monster.health) + "\n"
	text += "攻击力: " + str(monster.attack) + "\n"
	text += "防御力: " + str(monster.defense) + "\n"
	text += "速度: " + str(monster.speed) + "\n"
	text += "经验奖励: " + str(monster.experience_reward) + "\n"
	text += "金币奖励: " + str(monster.gold_reward) + "\n"
	text += "出现层数: " + str(monster.min_floor) + "-" + str(monster.max_floor) + "\n\n"
	if monster.description != "":
		text += "[i]" + monster.description + "[/i]\n\n"
	if monster.special_ability != "":
		text += "特殊能力: " + monster.special_ability + "\n"
	return text


## 格式化地图详情
func _format_map_detail(map_data: MapData) -> String:
	var text = ""
	text += "[b]" + map_data.name + "[/b]\n\n"
	text += "类型: " + map_data.type + "\n"
	text += "层数: " + str(map_data.floor_level) + "\n"
	text += "尺寸: " + str(map_data.width) + "x" + str(map_data.height) + "\n"
	text += "房间数: " + str(map_data.room_count) + "\n"
	text += "难度: " + str(map_data.difficulty) + "\n\n"
	if map_data.description != "":
		text += "[i]" + map_data.description + "[/i]\n"
	return text


## 格式化事件详情
func _format_event_detail(event: EventData) -> String:
	var text = ""
	text += "[b]" + event.name + "[/b]\n\n"
	text += "类型: " + event.type + "\n"
	text += "触发概率: " + str(event.trigger_rate) + "%\n"
	text += "出现层数: " + str(event.min_floor) + "-" + str(event.max_floor) + "\n\n"
	if event.description != "":
		text += "[i]" + event.description + "[/i]\n\n"
	if event.option1_text != "":
		text += "选项1: " + event.option1_text + "\n"
	if event.option2_text != "":
		text += "选项2: " + event.option2_text + "\n"
	return text


## 返回按钮
func _on_back_pressed() -> void:
	SceneManager.go_to_game()

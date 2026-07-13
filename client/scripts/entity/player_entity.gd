## 玩家实体类
##
## 封装玩家实体
## 管理玩家Node引用、玩家数据、玩家位置
## 与已有PlayerController兼容

class_name PlayerEntity
extends Entity

## 玩家Node引用
var _player_node: CharacterBody2D = null

## 玩家数据
var _player_data: Dictionary = {}

## 玩家属性
var level: int = 1
var experience: int = 0
var health: int = 100
var max_health: int = 100
var attack: int = 10
var defense: int = 5
var gold: int = 0


## 初始化玩家实体
func _init() -> void:
	super._init()
	entity_type = "player"
	entity_name = "Player"


## 绑定玩家Node
func bind_player_node(node: CharacterBody2D) -> void:
	_player_node = node
	if _player_node:
		position = _player_node.position


## 获取玩家Node
func get_player_node() -> CharacterBody2D:
	return _player_node


## 设置玩家数据
func set_player_data(data: Dictionary) -> void:
	_player_data = data
	_update_from_data()


## 获取玩家数据
func get_player_data() -> Dictionary:
	return _player_data


## 从玩家数据更新属性
func _update_from_data() -> void:
	entity_name = _player_data.get("nickname", "Player")
	level = _player_data.get("level", 1)
	experience = _player_data.get("experience", 0)
	health = _player_data.get("current_health", 100)
	max_health = _player_data.get("max_health", 100)
	attack = _player_data.get("attack", 10)
	defense = _player_data.get("defense", 5)
	gold = _player_data.get("gold", 0)


## 同步位置到Node
func sync_position_to_node() -> void:
	if _player_node:
		_player_node.position = position


## 从Node同步位置
func sync_position_from_node() -> void:
	if _player_node:
		position = _player_node.position


## 设置位置并同步到Node
func set_position(new_position: Vector2) -> void:
	super.set_position(new_position)
	sync_position_to_node()


## 获取玩家昵称
func get_nickname() -> String:
	return entity_name


## 获取玩家等级
func get_level() -> int:
	return level


## 获取玩家生命值
func get_health() -> int:
	return health


## 获取玩家最大生命值
func get_max_health() -> int:
	return max_health


## 获取玩家攻击力
func get_attack() -> int:
	return attack


## 获取玩家防御力
func get_defense() -> int:
	return defense


## 获取玩家金币
func get_gold() -> int:
	return gold


## 检查玩家是否存活
func is_alive() -> bool:
	return health > 0


## 转换为字典
func to_dict() -> Dictionary:
	var data = super.to_dict()
	data["player_data"] = _player_data
	data["level"] = level
	data["experience"] = experience
	data["health"] = health
	data["max_health"] = max_health
	data["attack"] = attack
	data["defense"] = defense
	data["gold"] = gold
	return data


## 从字典加载
func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	_player_data = data.get("player_data", {})
	level = data.get("level", 1)
	experience = data.get("experience", 0)
	health = data.get("health", 100)
	max_health = data.get("max_health", 100)
	attack = data.get("attack", 10)
	defense = data.get("defense", 5)
	gold = data.get("gold", 0)

## 玩家实体类 (Phase 9.4.3 重构)
##
## 封装玩家实体
## 管理玩家Node引用、玩家位置、身份信息
## 运行时属性委托给PlayerStats管理
##
## 职责:
## - 身份信息 (entity_id, entity_name, entity_type)
## - 网络/实体相关字段 (_player_node, position sync)
## - 存档包装 (to_dict/from_dict with PlayerStats)
##
## 不再负责:
## - 玩家属性管理 (委托给PlayerStats)
## - 运行时状态查询 (委托给PlayerStats)

class_name PlayerEntity
extends Entity

## 玩家Node引用
var _player_node: CharacterBody2D = null

## 玩家属性系统引用 (Phase 9.4.3: Source of Truth)
var _stats: PlayerStats = null


## 初始化玩家实体
func _init() -> void:
	super._init()
	entity_type = "player"
	entity_name = "Player"


## ==================== Node绑定 ====================

## 绑定玩家Node
func bind_player_node(node: CharacterBody2D) -> void:
	_player_node = node
	if _player_node:
		position = _player_node.position


## 获取玩家Node
func get_player_node() -> CharacterBody2D:
	return _player_node


## ==================== PlayerStats管理 ====================

## 设置PlayerStats引用
func set_stats(stats: PlayerStats) -> void:
	_stats = stats
	if _stats:
		entity_name = _stats.nickname


## 获取PlayerStats引用
func get_stats() -> PlayerStats:
	return _stats


## 从Dictionary加载PlayerStats (Phase 9.4.3)
func load_stats_from_dict(data: Dictionary) -> void:
	if not _stats:
		_stats = PlayerStats.from_dict(data)
	else:
		_stats.sync_from_dict(data)
	entity_name = _stats.nickname


## ==================== 位置同步 ====================

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


## ==================== 属性查询 (委托给PlayerStats) ====================

## 获取玩家昵称
func get_nickname() -> String:
	if _stats:
		return _stats.nickname
	return entity_name


## 获取玩家等级
func get_level() -> int:
	if _stats:
		return _stats.level
	return 1


## 获取玩家生命值
func get_health() -> int:
	if _stats:
		return _stats.current_health
	return 100


## 获取玩家最大生命值
func get_max_health() -> int:
	if _stats:
		return _stats.max_health
	return 100


## 获取玩家攻击力
func get_attack() -> int:
	if _stats:
		return _stats.attack
	return 10


## 获取玩家防御力
func get_defense() -> int:
	if _stats:
		return _stats.defense
	return 0


## 获取玩家金币
func get_gold() -> int:
	if _stats:
		return _stats.gold
	return 0


## 检查玩家是否存活
func is_alive() -> bool:
	if _stats:
		return not _stats.is_dead()
	return true


## ==================== 序列化 ====================

## 转换为字典 (Phase 9.4.3: 使用PlayerStats.to_dict())
func to_dict() -> Dictionary:
	var data = super.to_dict()

	# 从PlayerStats导出运行时属性
	if _stats:
		var stats_dict = _stats.to_dict()
		data["player_stats"] = stats_dict
		# 兼容旧字段
		data["level"] = _stats.level
		data["experience"] = _stats.experience
		data["health"] = _stats.current_health
		data["max_health"] = _stats.max_health
		data["attack"] = _stats.attack
		data["defense"] = _stats.defense
		data["gold"] = _stats.gold
	else:
		# 无PlayerStats时使用默认值
		data["player_stats"] = {}
		data["level"] = 1
		data["experience"] = 0
		data["health"] = 100
		data["max_health"] = 100
		data["attack"] = 10
		data["defense"] = 0
		data["gold"] = 0

	return data


## 从字典加载 (Phase 9.4.3: 兼容旧存档)
func from_dict(data: Dictionary) -> void:
	super.from_dict(data)

	# 优先从player_stats字段加载
	if data.has("player_stats") and data["player_stats"] is Dictionary and not data["player_stats"].is_empty():
		load_stats_from_dict(data["player_stats"])
	else:
		# 兼容旧存档: 从扁平字段构建Dictionary给PlayerStats
		var legacy_data: Dictionary = {}
		if data.has("level"):
			legacy_data["level"] = data["level"]
		if data.has("experience"):
			legacy_data["experience"] = data["experience"]
		if data.has("health"):
			legacy_data["current_health"] = data["health"]
		if data.has("max_health"):
			legacy_data["max_health"] = data["max_health"]
		if data.has("attack"):
			legacy_data["attack"] = data["attack"]
		if data.has("defense"):
			legacy_data["defense"] = data["defense"]
		if data.has("gold"):
			legacy_data["gold"] = data["gold"]

		# 也尝试从player_data字段加载(旧存档可能有此字段)
		if data.has("player_data") and data["player_data"] is Dictionary:
			for key in data["player_data"]:
				legacy_data[key] = data["player_data"][key]

		if legacy_data.size() > 0:
			load_stats_from_dict(legacy_data)
		else:
			# 全新玩家，创建默认PlayerStats
			load_stats_from_dict({})

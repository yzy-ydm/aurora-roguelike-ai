## 怪物实体类
##
## 继承Entity体系
## 管理怪物数据、属性、生命周期
## 与PlayerEntity设计模式一致

class_name MonsterEntity
extends Entity

## 怪物Node引用
var _monster_node: CharacterBody2D = null

## 怪物数据（来自服务器）
var _monster_data: MonsterData = null

## 战斗属性
## 默认值与 MonsterBalanceConfig.NORMAL (floor=1) 对齐
## HP: 40-80, ATK: 5-10, DEF: 0-3
var health: int = 50
var max_health: int = 50
var attack: int = 7
var defense: int = 1
var speed: float = 100.0

## AI属性
var ai_type: String = "melee"
var detection_range: float = 200.0
var attack_range: float = 60.0  # TASK-017.7: 50→60，玩家移速200下保证近距离攻击可命中

## 状态
var is_dead: bool = false


## 初始化怪物实体
func _init() -> void:
	super._init()
	entity_type = "monster"


## 绑定怪物Node
func bind_monster_node(node: CharacterBody2D) -> void:
	_monster_node = node
	if _monster_node:
		position = _monster_node.position


## 获取怪物Node
func get_monster_node() -> CharacterBody2D:
	return _monster_node


## 设置怪物数据
func set_monster_data(data: MonsterData) -> void:
	_monster_data = data
	_update_from_data()


## 获取怪物数据
func get_monster_data() -> MonsterData:
	return _monster_data


## 从MonsterData更新属性
func _update_from_data() -> void:
	if not _monster_data:
		return

	entity_name = _monster_data.name
	health = _monster_data.health
	max_health = _monster_data.health
	attack = _monster_data.attack
	defense = _monster_data.defense
	speed = _monster_data.speed


## 同步位置到Node
func sync_position_to_node() -> void:
	if _monster_node:
		_monster_node.position = position


## 从Node同步位置
func sync_position_from_node() -> void:
	if _monster_node:
		position = _monster_node.position


## 设置位置并同步到Node
func set_position(new_position: Vector2) -> void:
	super.set_position(new_position)
	sync_position_to_node()


## 获取怪物名称
func get_monster_name() -> String:
	return entity_name


## 获取怪物类型
func get_monster_type() -> String:
	if _monster_data:
		return _monster_data.type
	return "normal"


## 获取生命值
func get_health() -> int:
	return health


## 获取最大生命值
func get_max_health() -> int:
	return max_health


## 获取攻击力
func get_attack() -> int:
	return attack


## 获取防御力
func get_defense() -> int:
	return defense


## 获取速度
func get_speed() -> float:
	return speed


## 检查是否存活
func is_alive() -> bool:
	return health > 0 and not is_dead


## 受到伤害
func take_damage(damage: int) -> void:
	if is_dead:
		return

	health -= damage
	if health <= 0:
		health = 0
		die()


## 死亡
func die() -> void:
	if is_dead:
		return

	is_dead = true
	state = EntityState.DESTROYED

	# 通知Node执行死亡动画
	if _monster_node and _monster_node.has_method("on_death"):
		_monster_node.on_death()


## 获取经验奖励
func get_experience_reward() -> int:
	if _monster_data:
		return _monster_data.experience_reward
	return 10


## 获取金币奖励
func get_gold_reward() -> int:
	if _monster_data:
		return _monster_data.gold_reward
	return 5


## 转换为字典
func to_dict() -> Dictionary:
	var data = super.to_dict()
	data["monster_data_id"] = _monster_data.id if _monster_data else 0
	data["health"] = health
	data["max_health"] = max_health
	data["attack"] = attack
	data["defense"] = defense
	data["speed"] = speed
	data["is_dead"] = is_dead
	return data


## 从字典加载
func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	health = data.get("health", 50)
	max_health = data.get("max_health", 50)
	attack = data.get("attack", 7)
	defense = data.get("defense", 1)
	speed = data.get("speed", 100.0)
	is_dead = data.get("is_dead", false)

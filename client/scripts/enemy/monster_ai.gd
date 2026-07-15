## 怪物AI脚本
##
## 负责怪物的行为逻辑
## 支持IDLE/CHASE/ATTACK状态
## 支持受击硬直

extends Node

## 所属怪物节点
var _monster_node: CharacterBody2D = null

## 怪物实体引用
var _monster_entity: MonsterEntity = null

## 玩家引用
var _player_node: CharacterBody2D = null

## AI状态
enum AIState {
	IDLE,       # 空闲
	CHASE,      # 追击
	ATTACK,     # 攻击
	DEAD        # 死亡
}

var _current_state: AIState = AIState.IDLE

## 攻击冷却
var _attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_TIME: float = 1.5

## 距离阈值
const IDLE_DISTANCE: float = 300.0
const CHASE_DISTANCE: float = 100.0


## 初始化AI
func initialize(monster_node: CharacterBody2D, monster_entity: MonsterEntity) -> void:
	_monster_node = monster_node
	_monster_entity = monster_entity

	# 查找玩家节点
	_find_player()


## 查找玩家节点
func _find_player() -> void:
	# 在场景树中查找Player节点
	var root = Engine.get_main_loop().root
	if root:
		var game_scene = root.get_node_or_null("GameScene")
		if game_scene:
			var game_world = game_scene.get_node_or_null("GameWorld")
			if game_world:
				_player_node = game_world.get_node_or_null("Player")

	if not _player_node:
		print("[MonsterAI] Warning: Player node not found")


## 每帧更新
func update(delta: float) -> void:
	if not _monster_entity or not _monster_entity.is_alive():
		_current_state = AIState.DEAD
		return

	if not _player_node:
		_find_player()
		return

	# 玩家已死亡，停止所有AI行为
	if _player_node.has_method("is_dead") and _player_node.is_dead():
		_current_state = AIState.IDLE
		_monster_node.velocity = Vector2.ZERO
		return

	# 检查受击硬直
	if _monster_node.has_method("get") and _monster_node.get("_is_hit_stunned"):
		if _monster_node._is_hit_stunned:
			return  # 硬直中不执行AI

	# 更新攻击冷却
	if _attack_cooldown > 0:
		_attack_cooldown -= delta

	# 计算与玩家的距离
	var distance_to_player = _monster_node.position.distance_to(_player_node.position)

	# 状态决策
	_decide_state(distance_to_player)

	# 执行状态行为
	_execute_state(delta, distance_to_player)


## 决策状态
func _decide_state(distance: float) -> void:
	if not _monster_entity.is_alive():
		_current_state = AIState.DEAD
		return

	# 使用统一的距离阈值
	if distance <= CHASE_DISTANCE:
		_current_state = AIState.ATTACK
	elif distance <= IDLE_DISTANCE:
		_current_state = AIState.CHASE
	else:
		_current_state = AIState.IDLE


## 执行状态行为
func _execute_state(delta: float, distance: float) -> void:
	match _current_state:
		AIState.IDLE:
			_do_idle(delta)
		AIState.CHASE:
			_do_chase(delta)
		AIState.ATTACK:
			_do_attack(delta, distance)
		AIState.DEAD:
			pass


## 空闲行为
func _do_idle(_delta: float) -> void:
	# 待机不动
	pass


## 追击行为 (Phase 17.2: 横版追踪)
func _do_chase(_delta: float) -> void:
	if not _player_node or not _monster_node:
		return

	# Phase 17.2: 横版移动 - 只在水平方向追踪
	var speed = _monster_entity.get_speed()
	var dx = _player_node.position.x - _monster_node.position.x

	# 设置水平速度
	if abs(dx) > 10:  # 避免抖动
		_monster_node.velocity.x = sign(dx) * speed
	else:
		_monster_node.velocity.x = 0

	# 翻转Sprite朝向
	if _monster_node.has_node("Sprite"):
		var sprite = _monster_node.get_node("Sprite")
		if sprite:
			sprite.flip_h = (dx < 0)


## 攻击行为 (Phase 17.2: 横版攻击)
func _do_attack(_delta: float, distance: float) -> void:
	if not _player_node or not _monster_node:
		return

	# 如果在攻击范围内且冷却结束
	if distance <= _monster_entity.attack_range and _attack_cooldown <= 0:
		_perform_attack()
		_attack_cooldown = ATTACK_COOLDOWN_TIME
	else:
		# 如果不在攻击范围，继续接近
		var speed = _monster_entity.get_speed()
		var dx = _player_node.position.x - _monster_node.position.x

		if abs(dx) > 10:
			_monster_node.velocity.x = sign(dx) * speed
		else:
			_monster_node.velocity.x = 0


## 执行攻击
func _perform_attack() -> void:
	if not _player_node or not _monster_entity:
		return

	# 玩家已死亡，不执行攻击
	if _player_node.has_method("is_dead") and _player_node.is_dead():
		return

	print("[MonsterAI] ", _monster_entity.get_monster_name(), " attacks player!")

	# 通过MonsterNode攻击玩家(DamageSystem计算伤害)
	if _monster_node.has_method("attack_player"):
		_monster_node.attack_player(_player_node)
	else:
		# Fallback: 直接调用
		var damage = _monster_entity.get_attack()
		if _player_node.has_method("take_damage"):
			_player_node.take_damage(damage, _monster_node.position)


## 获取当前AI状态
func get_ai_state() -> AIState:
	return _current_state


## 获取AI状态字符串
func get_ai_state_string() -> String:
	match _current_state:
		AIState.IDLE:
			return "idle"
		AIState.CHASE:
			return "chase"
		AIState.ATTACK:
			return "attack"
		AIState.DEAD:
			return "dead"
	return "unknown"

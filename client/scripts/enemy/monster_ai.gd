## 怪物AI脚本
##
## 负责怪物的行为逻辑
## 第一版：简单AI
## - 检测玩家
## - 朝玩家移动
## - 接触玩家造成伤害

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
const ATTACK_COOLDOWN_TIME: float = 1.0


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

	var detection_range = _monster_entity.detection_range
	var attack_range = _monster_entity.attack_range

	if distance <= attack_range:
		_current_state = AIState.ATTACK
	elif distance <= detection_range:
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


## 追击行为
func _do_chase(_delta: float) -> void:
	if not _player_node or not _monster_node:
		return

	# 计算朝向玩家的方向
	var direction = (_player_node.position - _monster_node.position).normalized()

	# 移动
	var speed = _monster_entity.get_speed()
	_monster_node.velocity = direction * speed
	_monster_node.move_and_slide()


## 攻击行为
func _do_attack(_delta: float, distance: float) -> void:
	if not _player_node or not _monster_node:
		return

	# 如果在攻击范围内且冷却结束
	if distance <= _monster_entity.attack_range and _attack_cooldown <= 0:
		_perform_attack()
		_attack_cooldown = ATTACK_COOLDOWN_TIME
	else:
		# 如果不在攻击范围，继续接近
		var direction = (_player_node.position - _monster_node.position).normalized()
		var speed = _monster_entity.get_speed()
		_monster_node.velocity = direction * speed
		_monster_node.move_and_slide()


## 执行攻击
func _perform_attack() -> void:
	if not _player_node or not _monster_entity:
		return

	print("[MonsterAI] ", _monster_entity.get_monster_name(), " attacks player!")

	# 获取怪物攻击力
	var damage = _monster_entity.get_attack()

	# 对玩家造成伤害（通过玩家的受伤方法）
	if _player_node.has_method("take_damage"):
		_player_node.take_damage(damage)
		print("[MonsterAI] Dealt ", damage, " damage to player")


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

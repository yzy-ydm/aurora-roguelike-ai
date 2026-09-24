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

## ==================== TASK-018.0/TASK-017.9: 出生保护与攻击前摇 ====================

## 出生保护时间: 生成后这段时间内不决策/不追击/不攻击（重力与碰撞正常，可落地）
const SPAWN_PROTECTION_TIME: float = 0.8
var _protection_timer: float = 0.0

## 攻击前摇时间: 进入攻击范围后先准备，期间停止移动，之后才执行伤害
const ATTACK_WINDUP_TIME: float = 0.3
var _windup_timer: float = 0.0
var _is_winding_up: bool = false


## 初始化AI
func initialize(monster_node: CharacterBody2D, monster_entity: MonsterEntity) -> void:
	_monster_node = monster_node
	_monster_entity = monster_entity

	# TASK-018.0: 启动出生保护（防止贴脸出生时玩家进房即被攻击）
	_protection_timer = SPAWN_PROTECTION_TIME

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
	# TASK-018.0: 出生保护期内不决策/不追击/不攻击（重力与碰撞由 monster_node 正常处理）
	if _protection_timer > 0:
		_protection_timer -= delta
		if _protection_timer > 0:
			return
		# 保护刚结束: 本帧继续正常决策，避免额外空帧

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
	# TASK-017.7: 统一使用 global_position（怪物在房间local坐标系、玩家在世界坐标系，
	# 混用 position 导致距离恒大于追击阈值，AI 永远停在 IDLE）
	var distance_to_player = _monster_node.global_position.distance_to(_player_node.global_position)

	# 状态决策
	_decide_state(distance_to_player)

	# TASK-017.9: 前摇中玩家离开攻击决策范围 → 取消前摇（防止状态残留）
	if _is_winding_up and distance_to_player > CHASE_DISTANCE:
		_is_winding_up = false

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
	var dx = _player_node.global_position.x - _monster_node.global_position.x

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


## 攻击行为 (Phase 17.2: 横版攻击; TASK-017.9: 增加前摇)
func _do_attack(_delta: float, distance: float) -> void:
	if not _player_node or not _monster_node:
		return

	# 前摇期间: 停止移动，倒计时结束后执行伤害
	if _is_winding_up:
		_monster_node.velocity.x = 0
		_windup_timer -= _delta
		if _windup_timer <= 0:
			_is_winding_up = false
			_execute_attack(distance)
		return

	# 如果在攻击范围内且冷却结束 → 进入前摇
	if distance <= _monster_entity.attack_range and _attack_cooldown <= 0:
		_start_attack_windup()
	else:
		# 如果不在攻击范围，继续接近
		var speed = _monster_entity.get_speed()
		var dx = _player_node.global_position.x - _monster_node.global_position.x

		if abs(dx) > 10:
			_monster_node.velocity.x = sign(dx) * speed
		else:
			_monster_node.velocity.x = 0


## 开始攻击前摇 (TASK-017.9): 停止移动，0.3秒后执行伤害
func _start_attack_windup() -> void:
	_is_winding_up = true
	_windup_timer = ATTACK_WINDUP_TIME
	_monster_node.velocity.x = 0


## 执行攻击伤害 (TASK-017.9: 前摇结束后调用)
## 玩家在前摇期间跑出攻击范围（容差25px）→ 攻击落空，但同样进入冷却
func _execute_attack(distance: float) -> void:
	if distance > _monster_entity.attack_range + 25.0:
		_attack_cooldown = ATTACK_COOLDOWN_TIME
		return

	_perform_attack()
	_attack_cooldown = ATTACK_COOLDOWN_TIME


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
			_player_node.take_damage(damage, _monster_node.global_position)


## 获取当前AI状态
func get_ai_state() -> AIState:
	return _current_state


## 获取AI状态字符串
func get_ai_state_string() -> String:
	# TASK-017.9: 前摇状态标记（便于调试与测试）
	if _is_winding_up:
		return "windup"
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

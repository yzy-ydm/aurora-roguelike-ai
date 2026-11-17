## Boss控制器 (Phase 12)
##
## 管理Boss的战斗行为、技能释放、阶段转换
## 继承MonsterNode的逻辑，增加Boss专属机制
##
## BUG-3 FIX: 原为 _physics_process (Node无物理帧)，改为每帧 _process 驱动 AI 逻辑，
## 物理移动委托给 MonsterNode（BossNode = CharacterBody2D）。

class_name BossController
extends Node

## ==================== 配置 ====================

## 技能冷却时间
var _skill_cooldowns: Dictionary = {}

## 当前技能计时器
var _skill_timers: Dictionary = {}

## 是否正在释放技能
var _is_using_skill: bool = false

## 当前技能
var _current_skill: Dictionary = {}

## Phase 9.3: 攻击节奏控制
var _attack_cooldown_timer: float = 0.0  # 全局攻击冷却计时器
var _is_preparing_attack: bool = false   # 是否正在攻击前摇

## ==================== 引用 ====================

## Boss实体引用
var _boss_entity: MonsterEntity = null

## Boss节点引用
var _boss_node: CharacterBody2D = null

## Boss数据
var _boss_data: BossData = null

## 玩家引用
var _player_node: CharacterBody2D = null

## ==================== 状态 ====================

## 当前阶段
var _current_phase: BossData.BossPhase = BossData.BossPhase.PHASE_1

## 是否激活
var _is_active: bool = false

## ==================== 信号 ====================

## 阶段转换
signal phase_changed(new_phase: BossData.BossPhase)

## 技能释放
signal skill_used(skill_name: String)

## Boss被击败
signal boss_defeated()

## Boss受伤
signal boss_damaged(damage: int, current_health: int)


## ==================== 初始化 ====================

func initialize(boss_node: CharacterBody2D, boss_entity: MonsterEntity, boss_data: BossData) -> void:
	_boss_node = boss_node
	_boss_entity = boss_entity
	_boss_data = boss_data

	# BUG-29 FIX: 重置阶段状态，防止旧 BossController 残留导致阶段显示错误
	_current_phase = BossData.BossPhase.PHASE_1

	# 查找玩家
	_find_player()

	# 初始化技能冷却
	_init_skills()

	_is_active = true
	print("[BossController] Initialized: ", boss_data.name)


func _find_player() -> void:
	var root = Engine.get_main_loop().root
	if root:
		var game_scene = root.get_node_or_null("GameScene")
		if game_scene:
			var game_world = game_scene.get_node_or_null("GameWorld")
			if game_world:
				_player_node = game_world.get_node_or_null("Player")


func _init_skills() -> void:
	if not _boss_data:
		return

	# BUG-22 FIX: 校验每个技能的必填字段，跳过损坏的配置避免运行时错误
	var valid_skill_types := ["charge", "aoe", "projectile", "melee"]
	for skill in _boss_data.skills:
		var skill_name = skill.get("name", "")
		if skill_name.is_empty():
			print("[BossController] WARNING: skill missing 'name', skipping: ", skill)
			continue
		var skill_type = skill.get("type", "melee")
		if not skill_type in valid_skill_types:
			print("[BossController] WARNING: unknown skill type '", skill_type, "' for '",
				  skill_name, "', defaulting to 'melee'")
			skill_type = "melee"
		var cooldown = skill.get("cooldown", 5.0)
		_skill_cooldowns[skill_name] = cooldown
		_skill_timers[skill_name] = 0.0


## ==================== 每帧更新 ====================

func _process(delta: float) -> void:
	update(delta)


func update(delta: float) -> void:
	if not _is_active or not _boss_entity or not _boss_entity.is_alive():
		return

	# 更新技能冷却
	_update_skill_cooldowns(delta)

	# Phase 9.3: 更新全局攻击冷却
	if _attack_cooldown_timer > 0:
		_attack_cooldown_timer -= delta

	# 检查阶段转换
	_check_phase_transition()

	# AI决策
	_decide_action(delta)


## 更新技能冷却
func _update_skill_cooldowns(delta: float) -> void:
	for skill_name in _skill_timers:
		if _skill_timers[skill_name] > 0:
			_skill_timers[skill_name] -= delta


## 检查阶段转换
func _check_phase_transition() -> void:
	if not _boss_data or not _boss_entity:
		return

	var new_phase = _boss_data.check_phase_transition(_boss_entity.health)
	if new_phase != _current_phase:
		_current_phase = new_phase
		print("[BossController] Phase changed to: ", _boss_data.get_phase_name())
		phase_changed.emit(_current_phase)

		# 阶段转换时重置所有技能冷却
		_reset_all_cooldowns()


## 重置所有技能冷却
func _reset_all_cooldowns() -> void:
	for skill_name in _skill_timers:
		_skill_timers[skill_name] = 0.0


## ==================== AI决策 ====================

func _decide_action(delta: float) -> void:
	if not _player_node or not _boss_node:
		return

	# 如果正在释放技能或前摇，等待完成
	if _is_using_skill or _is_preparing_attack:
		return

	# Phase 9.3: 全局攻击冷却检查
	if _attack_cooldown_timer > 0:
		_chase_player(delta)
		return

	# 尝试释放技能
	if _try_use_skill():
		return

	# 默认行为：追踪玩家
	_chase_player(delta)


## 通过DamageSystem攻击玩家
func _deal_damage_to_player(damage_multiplier: float = 1.0) -> void:
	if not _player_node or not _boss_node:
		return

	var damage_system = _find_damage_system()
	if damage_system and damage_system.has_method("on_boss_attack_player"):
		damage_system.on_boss_attack_player(_boss_node, _player_node, damage_multiplier)
	else:
		# Fallback
		var damage = int(_boss_data.attack * damage_multiplier)
		if _player_node.has_method("take_damage"):
			# BUG-1 FIX: 使用 global_position 而非 position（Boss 节点在 MonsterContainer 内有偏移）
			_player_node.take_damage(damage, _boss_node.global_position)


## 查找DamageSystem
func _find_damage_system() -> Node:
	var root = Engine.get_main_loop().root
	if root:
		var game_scene = root.get_node_or_null("GameScene")
		if game_scene:
			return game_scene.get_node_or_null("DamageSystem")
	return null


## 尝试释放技能
func _try_use_skill() -> bool:
	if not _boss_data:
		return false

	var available_skills = _boss_data.get_phase_skills()
	for skill in available_skills:
		var skill_name = skill.get("name", "unknown")
		var cooldown = _skill_timers.get(skill_name, 0.0)

		if cooldown <= 0:
			# BUG-1 FIX: 使用 global_position 而非 position（Boss 节点在 MonsterContainer 内有偏移）
			var distance = _boss_node.global_position.distance_to(_player_node.global_position)
			var min_range = skill.get("min_range", 0)
			var max_range = skill.get("max_range", 300)

			if distance >= min_range and distance <= max_range:
				call_deferred("_use_skill", skill)
				return true

	return false


## 释放技能
func _use_skill(skill: Dictionary) -> void:
	var skill_name = skill.get("name", "unknown")
	var cooldown = skill.get("cooldown", 5.0)
	var skill_type = skill.get("type", "melee")

	print("[BossController] Preparing skill: ", skill_name)

	# Phase 9.3: 攻击前摇 - 给玩家反应时间
	_is_preparing_attack = true
	var prepare_time = _boss_data.attack_prepare_time if _boss_data else 0.5
	await get_tree().create_timer(prepare_time).timeout
	_is_preparing_attack = false

	# 检查Boss是否还活着(前摇期间可能被击杀)
	if not _is_active or not _boss_entity or not _boss_entity.is_alive():
		return

	print("[BossController] Using skill: ", skill_name)

	_is_using_skill = true
	_current_skill = skill
	_skill_timers[skill_name] = cooldown

	skill_used.emit(skill_name)

	# 根据技能类型执行
	match skill_type:
		"charge":
			_execute_charge_attack(skill)
		"aoe":
			_execute_aoe_attack(skill)
		"projectile":
			_execute_projectile_attack(skill)
		_:
			_execute_melee_attack(skill)

	# Phase 9.3: 设置全局攻击冷却
	var boss_cooldown = _boss_data.attack_cooldown if _boss_data else 1.5
	_attack_cooldown_timer = max(boss_cooldown, cooldown)


## 执行冲撞攻击
func _execute_charge_attack(skill: Dictionary) -> void:
	if not _player_node or not _boss_node:
		_is_using_skill = false
		return

	var charge_speed = skill.get("speed", 400.0)
	var damage_multiplier = skill.get("damage_multiplier", 2.0)
	var duration = skill.get("duration", 0.5)

	# BUG-1 FIX: 使用 global_position 计算方向
	var direction = (_player_node.global_position - _boss_node.global_position).normalized()
	var target_velocity = direction * charge_speed

	# BUG-2 FIX: BossController 是 Node，不能直接设置 CharacterBody2D.velocity 并期待 move_and_slide 生效。
	# 改为在 await 循环中每帧手动推进 Boss 位移（Controller 不在物理帧中运行）。
	_boss_node.velocity = target_velocity
	_boss_node.move_and_slide()

	# 等待期间每帧手动推进 Boss 位移
	var elapsed: float = 0.0
	const MOVE_STEP: float = 0.016
	while elapsed < duration and _is_active and _boss_entity and _boss_entity.is_alive():
		_boss_node.velocity = target_velocity
		_boss_node.move_and_slide()
		elapsed += MOVE_STEP
		await get_tree().create_timer(MOVE_STEP).timeout

	_boss_node.velocity = Vector2.ZERO

	# 检测碰撞伤害(通过DamageSystem)
	# BUG-1 FIX: 使用 global_position
	var distance = _boss_node.global_position.distance_to(_player_node.global_position)
	if distance < 60:
		_deal_damage_to_player(damage_multiplier)

	_is_using_skill = false


## 执行范围攻击
func _execute_aoe_attack(skill: Dictionary) -> void:
	var damage_multiplier = skill.get("damage_multiplier", 1.5)
	var radius = skill.get("radius", 150.0)
	var warning_duration = skill.get("warning_duration", 1.0)
	var duration = skill.get("duration", 0.5)

	# BUG-1 FIX: 使用 global_position 作为 AOE 中心
	_spawn_aoe_warning(_boss_node.global_position, radius, warning_duration)

	# 等待警告时间
	await get_tree().create_timer(warning_duration).timeout

	# 检测范围内玩家(通过DamageSystem)
	if _player_node:
		# BUG-1 FIX: 使用 global_position
		var distance = _boss_node.global_position.distance_to(_player_node.global_position)
		if distance <= radius:
			_deal_damage_to_player(damage_multiplier)

	_is_using_skill = false


## 执行投射物攻击
func _execute_projectile_attack(skill: Dictionary) -> void:
	var projectile_count = skill.get("count", 3)
	var spread_angle = skill.get("spread", 30.0)
	var damage_multiplier = skill.get("damage_multiplier", 0.8)

	# BUG-1 FIX: 使用 global_position 计算方向
	if _player_node:
		var base_direction = (_player_node.global_position - _boss_node.global_position).normalized()

		for i in range(projectile_count):
			var angle_offset = deg_to_rad(spread_angle * (i - projectile_count / 2))
			var direction = base_direction.rotated(angle_offset)
			_spawn_projectile(direction, int(_boss_data.attack * damage_multiplier))

	await get_tree().create_timer(0.5).timeout
	_is_using_skill = false


## 执行近战攻击
func _execute_melee_attack(skill: Dictionary) -> void:
	var damage_multiplier = skill.get("damage_multiplier", 1.2)
	var range = skill.get("range", 60.0)

	if _player_node:
		# BUG-1 FIX: 使用 global_position
		var distance = _boss_node.global_position.distance_to(_player_node.global_position)
		if distance <= range:
			_deal_damage_to_player(damage_multiplier)

	await get_tree().create_timer(0.3).timeout
	_is_using_skill = false


## 生成范围攻击警告
func _spawn_aoe_warning(pos: Vector2, radius: float, duration: float) -> void:
	# BUG-13 FIX: 先添加到父节点再设置 local 坐标（避免 get_parent() 在 add_child 前为 null）
	var warning = Node2D.new()

	var circle = ColorRect.new()
	circle.size = Vector2(radius * 2, radius * 2)
	circle.position = -circle.size / 2
	circle.color = Color(1, 0, 0, 0.3)
	warning.add_child(circle)

	if _boss_node.get_parent():
		_boss_node.get_parent().add_child(warning)
		# 将世界坐标转为父节点的 local 坐标
		warning.position = pos - _boss_node.get_parent().global_position

	# 延迟移除
	await get_tree().create_timer(duration).timeout
	if warning.is_inside_tree():
		warning.queue_free()


## 生成投射物
func _spawn_projectile(direction: Vector2, damage: int) -> void:
	# 使用现有的子弹系统
	var bullet_scene = load("res://scenes/combat/bullet.tscn")
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		# BUG-1/BUG-14 FIX: 使用 global_position 确保子弹在世界坐标正确位置生成
		bullet.global_position = _boss_node.global_position
		# is_enemy_bullet=true → collision_layer=16, mask=Wall+Player (handled in bullet.gd)
		bullet.setup(damage, 300.0, direction, false, _boss_node, true)

		if _boss_node.get_parent():
			_boss_node.get_parent().add_child(bullet)


## 追踪玩家
func _chase_player(delta: float) -> void:
	if not _player_node or not _boss_node or not _boss_data:
		return

	# BUG-1 FIX: 使用 global_position
	var direction = (_player_node.global_position - _boss_node.global_position).normalized()
	_boss_node.velocity = direction * _boss_data.speed
	_boss_node.move_and_slide()


## ==================== 受伤处理 ====================

func take_damage(damage: int) -> void:
	if not _boss_entity:
		return

	_boss_entity.take_damage(damage)
	boss_damaged.emit(damage, _boss_entity.health)

	# 检查是否死亡
	if not _boss_entity.is_alive():
		_on_boss_death()


func _on_boss_death() -> void:
	_is_active = false
	print("[BossController] Boss defeated!")
	boss_defeated.emit()


## ==================== 统一战斗属性接口 (Phase 20.2) ====================
## 让DamageSystem可以统一处理 Player / Monster / Boss

## 获取攻击力(兼容DamageSystem)
func get_attack() -> int:
	if _boss_data:
		return _boss_data.attack
	return 25


## 获取防御力(兼容DamageSystem)
func get_defense() -> int:
	if _boss_data:
		return _boss_data.defense
	return 10


## 获取怪物实体(兼容DamageSystem名称查询)
func get_monster_entity() -> MonsterEntity:
	return _boss_entity


## ==================== 查询接口 ====================

func get_boss_data() -> BossData:
	return _boss_data


func get_current_phase() -> BossData.BossPhase:
	return _current_phase


func is_active() -> bool:
	return _is_active


func get_health_percent() -> float:
	if not _boss_entity or _boss_entity.max_health <= 0:
		return 0.0
	return float(_boss_entity.health) / float(_boss_entity.max_health)

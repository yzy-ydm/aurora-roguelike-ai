## 伤害系统 (Phase 20.1)
##
## 唯一伤害计算入口
## 所有伤害必须经过此系统计算后才能应用
##
## 职责:
## - 基础伤害计算
## - 防御减伤
## - 暴击判定
## - 最低伤害保护
## - 生成伤害数字和命中特效

extends Node

## 伤害信号
signal damage_dealt(target: Node2D, damage: int, is_critical: bool)


## ==================== 伤害计算 ====================

## 计算最终伤害(核心公式)
## attacker_attack: 攻击者基础攻击力
## weapon_damage: 武器伤害(可为0)
## target_defense: 目标防御力
## crit_rate: 暴击率(0.0~1.0)
func calculate_damage(attacker_attack: int, weapon_damage: int, target_defense: int, crit_rate: float = 0.0) -> Dictionary:
	# 基础伤害 = 攻击力 + 武器伤害
	var base_damage = attacker_attack + weapon_damage

	# 防御减伤 = 防御力 / (防御力 + 100)
	var defense_reduction = target_defense / (target_defense + 100.0)

	# 最终伤害 = 基础伤害 * (1 - 防御减伤)
	var final_damage = base_damage * (1.0 - defense_reduction)

	# 暴击判定
	var is_critical = randf() < crit_rate
	if is_critical:
		final_damage = final_damage * 1.5

	# 取整，最少1点伤害
	final_damage = max(1, int(final_damage))

	return {
		"damage": final_damage,
		"is_critical": is_critical
	}


## ==================== 玩家→怪物/Boss 伤害 ====================

## 处理子弹命中怪物或Boss(玩家攻击)
## bullet: 子弹节点(携带武器伤害和暴击信息)
## target: 怪物节点(MonsterNode) 或 Boss节点(BossController宿主)
func on_bullet_hit(bullet: Node2D, target: Node2D) -> void:
	if not bullet or not target:
		return

	# 从子弹获取攻击信息（使用getter方法避免.get()返回默认值的问题）
	var is_critical = bullet.get_is_critical() if bullet.has_method("get_is_critical") else false
	var source = bullet.get_source() if bullet.has_method("get_source") else null

	# 获取玩家攻击力
	var attacker_attack = 10
	if source and source.has_method("get_attack"):
		attacker_attack = source.get_attack()

	# 获取目标防御力(统一接口)
	var target_defense = _get_target_defense(target)

	# TASK-028: 修复武器伤害双重计入
	# player_controller.get_attack() 已包含武器伤害（攻击力 + weapon_instance.get_damage()）
	# 旧公式 base = (attack+weapon) + bullet.weapon → 武器伤害被计两次
	# 新公式 base = attacker_attack（武器只计一次）；bullet.damage 仅供无 DamageSystem 兜底路径
	var result = calculate_damage(attacker_attack, 0, target_defense, 0.0)
	var final_damage = result["damage"]

	# 如果子弹标记为暴击,则应用暴击倍率
	if is_critical:
		final_damage = int(final_damage * 1.5)
		final_damage = max(1, final_damage)

	# 应用伤害到目标
	apply_damage_to_monster(target, final_damage, is_critical, source)

	# 销毁子弹
	if bullet.has_method("destroy"):
		bullet.destroy()
	elif bullet.is_inside_tree():
		bullet.queue_free()


## 获取目标防御力(统一接口,支持Monster和Boss)
func _get_target_defense(target: Node2D) -> int:
	# 优先直接调用get_defense()(Boss和MonsterNode都可以实现)
	if target.has_method("get_defense"):
		return target.get_defense()

	# 回退: 通过MonsterEntity获取(MonsterNode)
	if target.has_method("get_monster_entity"):
		var entity = target.get_monster_entity()
		if entity:
			return entity.defense

	return 0


## ==================== 怪物→玩家 伤害 ====================

## 处理怪物攻击玩家
## attacker: 怪物节点(MonsterNode)
## target: 玩家节点(Player)
func on_monster_attack_player(attacker: Node2D, target: Node2D) -> void:
	if not attacker or not target:
		return

	# 获取怪物攻击力
	var attacker_attack = 10
	if attacker.has_method("get_monster_entity"):
		var entity = attacker.get_monster_entity()
		if entity:
			attacker_attack = entity.get_attack()

	# 获取玩家防御力
	var target_defense = 0
	if target.has_method("get_player_data"):
		var data = target.get_player_data()
		target_defense = data.get("defense", 0)

	# 计算最终伤害
	var result = calculate_damage(attacker_attack, 0, target_defense, 0.0)
	var final_damage = result["damage"]

	# 应用伤害到玩家
	# TASK-017.7: 击退方向基准统一用世界坐标（attacker.position 是房间local，方向会错乱）
	apply_damage_to_player(target, final_damage, attacker.global_position)


## ==================== Boss→玩家 伤害 ====================

## 处理Boss攻击玩家
## boss_node: Boss节点(宿主节点,不是BossController)
## target: 玩家节点(Player)
## skill_damage_multiplier: 技能伤害倍率
func on_boss_attack_player(boss_node: Node2D, target: Node2D, skill_damage_multiplier: float = 1.0) -> void:
	if not boss_node or not target:
		return

	# 获取Boss攻击力(统一接口)
	var attacker_attack = _get_boss_attack(boss_node)

	# 应用技能倍率
	attacker_attack = int(attacker_attack * skill_damage_multiplier)

	# 获取玩家防御力
	var target_defense = 0
	if target.has_method("get_player_data"):
		var data = target.get_player_data()
		target_defense = data.get("defense", 0)

	# 计算最终伤害
	var result = calculate_damage(attacker_attack, 0, target_defense, 0.0)
	var final_damage = result["damage"]

	# 应用伤害到玩家
	apply_damage_to_player(target, final_damage, boss_node.position)


## 获取Boss攻击力(统一接口)
func _get_boss_attack(boss_node: Node2D) -> int:
	# 优先直接调用get_attack()(BossController宿主节点)
	if boss_node.has_method("get_attack"):
		return boss_node.get_attack()

	# 回退: 通过BossController的_boss_entity获取
	if boss_node.has_method("get") and boss_node.get("_boss_entity"):
		return boss_node._boss_entity.get_attack()

	return 25


## ==================== 伤害应用 ====================

## 应用伤害到怪物
func apply_damage_to_monster(target: Node2D, damage: int, is_critical: bool = false, source: Node2D = null) -> void:
	if not target:
		return

	if target.has_method("take_damage"):
		# Phase 17.5: 记录伤害前HP
		var hp_before = 0
		var target_name = "Unknown"
		if target.has_method("get_monster_entity"):
			var entity = target.get_monster_entity()
			if entity:
				hp_before = entity.get_health()
				target_name = entity.get_monster_name()
		elif target.name:
			target_name = target.name

		# 应用伤害
		target.take_damage(damage)

		# Phase 17.5: 记录伤害后HP
		var hp_after = 0
		if target.has_method("get_monster_entity"):
			var entity = target.get_monster_entity()
			if entity:
				hp_after = entity.get_health()

		_spawn_damage_number(target, damage, is_critical)
		_spawn_hit_effect(target)
		damage_dealt.emit(target, damage, is_critical)

		# Phase 17.5: 输出详细伤害日志
		print("[Damage] monster ", target_name, " hp ", hp_before, "->", hp_after)


## 应用伤害到玩家
func apply_damage_to_player(target: Node2D, damage: int, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if not target:
		return

	if target.has_method("take_damage"):
		target.take_damage(damage, attacker_position)
		_spawn_damage_number(target, damage, false, false, true)
		damage_dealt.emit(target, damage, false)
		print("[DamageSystem] Monster dealt ", damage, " damage to player")


## ==================== 特效生成 ====================

## 生成伤害数字
func _spawn_damage_number(target: Node2D, damage: int, is_critical: bool, is_heal: bool = false, is_player_damage: bool = false) -> void:
	print("[DamageNumber] Spawn Start damage=", damage, " target=", target.name)

	# Phase 17.7.2: 使用EffectContainer而不是MonsterContainer
	var parent = _get_effect_container()
	if not parent:
		print("[DamageNumber] ERROR: No EffectContainer found, aborting")
		return

	# 使用global_position确保位置正确
	var spawn_pos = target.global_position + Vector2(randf_range(-10, 10), -20)
	print("[DamageNumber] Position: global=", spawn_pos, " target_global=", target.global_position)

	# 直接加载场景实例化
	var scene = load("res://scenes/combat/damage_number.tscn")
	if not scene:
		print("[DamageNumber] ERROR: Failed to load scene")
		return
	print("[DamageNumber] Scene Loaded: ", scene.resource_path)

	var number = scene.instantiate()
	if not number:
		print("[DamageNumber] ERROR: Failed to instantiate")
		return
	print("[DamageNumber] Instance Created: ", number.name)

	# Phase 17.7.2: 设置global_position
	number.global_position = spawn_pos
	number.setup(damage)
	parent.add_child(number)
	print("[DamageNumber] Added To Tree: parent=", parent.name, " global_pos=", number.global_position, " visible=", number.visible, " z_index=", number.z_index, " modulate=", number.modulate)


## 获取EffectContainer
func _get_effect_container() -> Node:
	var root = Engine.get_main_loop().root
	if root:
		var game_scene = root.get_node_or_null("GameScene")
		if game_scene:
			var game_world = game_scene.get_node_or_null("GameWorld")
			if game_world:
				# 查找或创建EffectContainer
				var effect_container = game_world.get_node_or_null("EffectContainer")
				if not effect_container:
					effect_container = Node2D.new()
					effect_container.name = "EffectContainer"
					game_world.add_child(effect_container)
					print("[DamageSystem] Created EffectContainer")
				return effect_container
	return null


## 生成命中特效
func _spawn_hit_effect(target: Node2D) -> void:
	var parent = _get_effect_container()
	if not parent:
		return

	# 直接实例化Node2D并挂载脚本
	var hit_effect_script = load("res://scripts/combat/hit_effect.gd")
	if not hit_effect_script:
		return

	var effect = Node2D.new()
	effect.set_script(hit_effect_script)
	effect.global_position = target.global_position
	parent.add_child(effect)

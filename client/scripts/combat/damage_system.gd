## 伤害系统
##
## 负责处理所有伤害计算和应用
## 作为中间层，解耦子弹和怪物
## 统一管理伤害逻辑

extends Node

## 伤害信号
signal damage_dealt(target: Node2D, damage: int, is_critical: bool)


## 计算伤害
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


## 应用伤害到目标
func apply_damage(target: Node2D, damage: int, is_critical: bool = false, source: Node2D = null) -> void:
	if not target:
		return

	# 检查目标是否有take_damage方法
	if target.has_method("take_damage"):
		target.take_damage(damage)

		# 发送伤害信号
		damage_dealt.emit(target, damage, is_critical)

		# 打印伤害信息
		var target_name = "Unknown"
		if target.has_method("get_monster_entity"):
			var entity = target.get_monster_entity()
			if entity:
				target_name = entity.get_monster_name()
		elif target.name:
			target_name = target.name

		if is_critical:
			print("[DamageSystem] CRITICAL! Dealt ", damage, " damage to ", target_name)
		else:
			print("[DamageSystem] Dealt ", damage, " damage to ", target_name)
	else:
		print("[DamageSystem] Target has no take_damage method")


## 处理子弹命中
func on_bullet_hit(bullet: Node2D, target: Node2D) -> void:
	if not bullet or not target:
		return

	# 从子弹获取伤害信息
	var damage = bullet.get("damage") if bullet.has_method("get") else 10
	var is_critical = bullet.get("is_critical") if bullet.has_method("get") else false
	var source = bullet.get("source") if bullet.has_method("get") else null

	# 应用伤害
	apply_damage(target, damage, is_critical, source)

	# 销毁子弹
	if bullet.has_method("destroy"):
		bullet.destroy()
	elif bullet.is_inside_tree():
		bullet.queue_free()

## 奖励数据模型
##
## 定义房间清除后的奖励类型和数值

class_name RewardData
extends RefCounted

## 奖励类型枚举
enum RewardType {
	GOLD,              # 金币
	ATTACK_UP,         # 攻击力提升
	HEALTH_UP,         # 生命值提升
	HEAL,              # 治疗
	WEAPON_UPGRADE,    # 武器升级 (Phase 9.3.2)
	ATTRIBUTE_BOOST,   # 属性强化 (Phase 9.3.2)
	NEW_WEAPON,        # 新武器 (Phase 9.3.2)
	PASSIVE_ITEM       # 被动物品 (Phase 9.3.2)
}

## 奖励属性
var id: int = 0
var name: String = ""
var description: String = ""
var type: RewardType = RewardType.GOLD
var value: int = 0
var color: Color = Color.WHITE

## 扩展属性 (Phase 9.3.2)
var stat_key: String = ""        # ATTRIBUTE_BOOST: 目标属性名 (attack, max_health, move_speed, crit_rate)
var weapon_id: int = -1          # NEW_WEAPON/WEAPON_UPGRADE: 武器ID
var passive_id: String = ""      # PASSIVE_ITEM: 被动物品ID
var rarity: String = "common"    # 稀有度 (common, uncommon, rare, epic, legendary)


## 初始化
func _init(reward_id: int = 0, reward_name: String = "", reward_type: RewardType = RewardType.GOLD, reward_value: int = 0) -> void:
	id = reward_id
	name = reward_name
	type = reward_type
	value = reward_value
	_setup_defaults()


## 设置默认值
func _setup_defaults() -> void:
	match type:
		RewardType.GOLD:
			name = name if name != "" else "金币"
			description = "获得 " + str(value) + " 金币"
			color = Color(1.0, 0.84, 0.0, 1.0)  # 金色
		RewardType.ATTACK_UP:
			name = name if name != "" else "攻击力提升"
			description = "攻击力 +" + str(value)
			color = Color(0.9, 0.2, 0.2, 1.0)  # 红色
		RewardType.HEALTH_UP:
			name = name if name != "" else "生命值提升"
			description = "最大生命值 +" + str(value)
			color = Color(0.2, 0.9, 0.2, 1.0)  # 绿色
		RewardType.HEAL:
			name = name if name != "" else "治疗"
			description = "恢复 " + str(value) + " 生命值"
			color = Color(0.2, 0.8, 0.9, 1.0)  # 青色
		RewardType.WEAPON_UPGRADE:
			name = name if name != "" else "武器升级"
			description = "武器等级 +1"
			color = Color(0.9, 0.6, 0.1, 1.0)  # 橙色
		RewardType.ATTRIBUTE_BOOST:
			name = name if name != "" else "属性强化"
			description = _get_attribute_description()
			color = Color(0.6, 0.2, 0.9, 1.0)  # 紫色
		RewardType.NEW_WEAPON:
			name = name if name != "" else "新武器"
			description = "获得新武器"
			color = Color(0.1, 0.8, 0.9, 1.0)  # 青色
		RewardType.PASSIVE_ITEM:
			name = name if name != "" else "被动物品"
			description = "获得被动效果"
			color = Color(0.9, 0.9, 0.9, 1.0)  # 白色


## 获取属性强化描述
func _get_attribute_description() -> String:
	match stat_key:
		"attack":
			return "攻击力 +" + str(value)
		"max_health":
			return "最大生命 +" + str(value)
		"move_speed":
			return "移动速度 +" + str(value) + "%"
		"crit_rate":
			return "暴击率 +" + str(value) + "%"
		"defense":
			return "防御力 +" + str(value)
		_:
			return stat_key + " +" + str(value)


## 获取奖励类型字符串
func get_type_string() -> String:
	match type:
		RewardType.GOLD:
			return "gold"
		RewardType.ATTACK_UP:
			return "attack_up"
		RewardType.HEALTH_UP:
			return "health_up"
		RewardType.HEAL:
			return "heal"
		RewardType.WEAPON_UPGRADE:
			return "weapon_upgrade"
		RewardType.ATTRIBUTE_BOOST:
			return "attribute_boost"
		RewardType.NEW_WEAPON:
			return "new_weapon"
		RewardType.PASSIVE_ITEM:
			return "passive_item"
	return "unknown"


## 应用奖励到玩家
func apply_to_player(player: Node) -> void:
	if not player:
		return

	match type:
		RewardType.GOLD:
			_apply_gold(player)
		RewardType.ATTACK_UP:
			_apply_attack_up(player)
		RewardType.HEALTH_UP:
			_apply_health_up(player)
		RewardType.HEAL:
			_apply_heal(player)
		RewardType.WEAPON_UPGRADE:
			_apply_weapon_upgrade(player)
		RewardType.ATTRIBUTE_BOOST:
			_apply_attribute_boost(player)
		RewardType.NEW_WEAPON:
			_apply_new_weapon(player)
		RewardType.PASSIVE_ITEM:
			_apply_passive_item(player)


## 应用金币奖励
func _apply_gold(player: Node) -> void:
	if player.has_method("add_gold"):
		player.add_gold(value)
		print("[Reward] Added ", value, " gold")
	elif player.has_method("get_player_data"):
		var data = player.get_player_data()
		data["gold"] = data.get("gold", 0) + value
		player.set_player_data(data)
		print("[Reward] Added ", value, " gold")


## 应用攻击力提升
func _apply_attack_up(player: Node) -> void:
	if player.has_method("add_attack"):
		player.add_attack(value)
		print("[Reward] Attack +", value)
	elif player.has_method("get_player_data"):
		var data = player.get_player_data()
		data["attack"] = data.get("attack", 10) + value
		player.set_player_data(data)
		print("[Reward] Attack +", value)


## 应用生命值提升
func _apply_health_up(player: Node) -> void:
	if player.has_method("add_max_health"):
		player.add_max_health(value)
		print("[Reward] Max Health +", value)
	elif player.has_method("get_player_data"):
		var data = player.get_player_data()
		data["max_health"] = data.get("max_health", 100) + value
		data["current_health"] = data.get("current_health", 100) + value
		player.set_player_data(data)
		print("[Reward] Max Health +", value)


## 应用治疗
func _apply_heal(player: Node) -> void:
	if player.has_method("heal"):
		player.heal(value)
		print("[Reward] Healed ", value, " HP")
	elif player.has_method("get_player_data"):
		var data = player.get_player_data()
		var current = data.get("current_health", 100)
		var max_hp = data.get("max_health", 100)
		data["current_health"] = min(current + value, max_hp)
		player.set_player_data(data)
		print("[Reward] Healed ", value, " HP")


## 应用武器升级 (Phase 9.3.2)
func _apply_weapon_upgrade(player: Node) -> void:
	if player.has_method("upgrade_weapon"):
		var success = player.upgrade_weapon()
		if success:
			print("[Reward] Weapon upgraded!")
		else:
			print("[Reward] Weapon already at max level")
	else:
		print("[Reward] Player does not support weapon upgrade")


## 应用属性强化 (Phase 9.3.2)
func _apply_attribute_boost(player: Node) -> void:
	if stat_key == "":
		print("[Reward] Error: stat_key is empty for ATTRIBUTE_BOOST")
		return

	match stat_key:
		"attack":
			if player.has_method("add_attack"):
				player.add_attack(value)
		"max_health":
			if player.has_method("add_max_health"):
				player.add_max_health(value)
		"move_speed":
			if player.has_method("add_move_speed_percent"):
				player.add_move_speed_percent(float(value) / 100.0)
			elif player.has_method("get_player_data"):
				var data = player.get_player_data()
				var key = "move_speed_bonus"
				data[key] = data.get(key, 0.0) + float(value) / 100.0
				player.set_player_data(data)
		"crit_rate":
			if player.has_method("get_player_data"):
				var data = player.get_player_data()
				var key = "crit_rate_bonus"
				data[key] = data.get(key, 0.0) + float(value) / 100.0
				player.set_player_data(data)
		"defense":
			if player.has_method("get_player_data"):
				var data = player.get_player_data()
				data["defense"] = data.get("defense", 0) + value
				player.set_player_data(data)

	print("[Reward] Attribute boost: ", stat_key, " +", value)


## 应用新武器 (Phase 9.3.2)
func _apply_new_weapon(player: Node) -> void:
	if player.has_method("equip_new_weapon"):
		player.equip_new_weapon(weapon_id)
		print("[Reward] New weapon equipped: ", weapon_id)
	else:
		print("[Reward] Player does not support weapon equip")


## 应用被动物品 (Phase 9.3.2, Phase 9.5.1 增强)
func _apply_passive_item(player: Node) -> void:
	if player.has_method("add_passive_item"):
		player.add_passive_item(passive_id)
		print("[Reward] Passive item added via PlayerController: ", passive_id)
	elif player.has_method("get_stats"):
		# 直接通过PlayerStats添加
		var stats = player.get_stats()
		if stats:
			stats.add_passive(passive_id)
			print("[Reward] Passive item added via PlayerStats: ", passive_id)
	else:
		print("[Reward] Warning: Player does not support passive items")


## 转换为字典 (Phase 9.5.1: 确保passive_id完整序列化)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"type": get_type_string(),
		"value": value,
		"stat_key": stat_key,
		"weapon_id": weapon_id,
		"passive_id": passive_id,
		"rarity": rarity
	}


## 从字典创建
static func from_dict(data: Dictionary) -> RewardData:
	var reward = RewardData.new()
	reward.id = data.get("id", 0)
	reward.name = data.get("name", "")
	reward.description = data.get("description", "")

	var type_str = data.get("type", "gold")
	match type_str:
		"gold":
			reward.type = RewardType.GOLD
		"attack_up":
			reward.type = RewardType.ATTACK_UP
		"health_up":
			reward.type = RewardType.HEALTH_UP
		"heal":
			reward.type = RewardType.HEAL
		"weapon_upgrade":
			reward.type = RewardType.WEAPON_UPGRADE
		"attribute_boost":
			reward.type = RewardType.ATTRIBUTE_BOOST
		"new_weapon":
			reward.type = RewardType.NEW_WEAPON
		"passive_item":
			reward.type = RewardType.PASSIVE_ITEM

	reward.value = data.get("value", 0)
	reward.stat_key = data.get("stat_key", "")
	reward.weapon_id = data.get("weapon_id", -1)
	reward.passive_id = data.get("passive_id", "")
	reward.rarity = data.get("rarity", "common")
	reward._setup_defaults()
	return reward


## 生成随机奖励
static func generate_random_reward(reward_id: int = 0) -> RewardData:
	var random_type = randi() % 7
	var reward_type: RewardType
	var value: int
	var reward: RewardData

	match random_type:
		0:
			reward_type = RewardType.GOLD
			value = randi_range(10, 50)
			reward = RewardData.new(reward_id, "", reward_type, value)
		1:
			reward_type = RewardType.ATTACK_UP
			value = randi_range(1, 5)
			reward = RewardData.new(reward_id, "", reward_type, value)
		2:
			reward_type = RewardType.HEALTH_UP
			value = randi_range(5, 20)
			reward = RewardData.new(reward_id, "", reward_type, value)
		3:
			reward_type = RewardType.HEAL
			value = randi_range(10, 30)
			reward = RewardData.new(reward_id, "", reward_type, value)
		4:
			reward = _create_random_attribute_boost(reward_id)
		5:
			reward = _create_random_weapon_upgrade(reward_id)
		6:
			reward = _create_random_passive_item(reward_id)
		_:
			reward = RewardData.new(reward_id, "", RewardType.GOLD, randi_range(10, 50))

	return reward


## 生成随机属性强化奖励
static func _create_random_attribute_boost(reward_id: int) -> RewardData:
	var stats = ["attack", "max_health", "move_speed", "crit_rate", "defense"]
	var stat_key = stats[randi() % stats.size()]
	var value: int

	match stat_key:
		"attack":
			value = randi_range(2, 8)
		"max_health":
			value = randi_range(10, 30)
		"move_speed":
			value = randi_range(5, 15)
		"crit_rate":
			value = randi_range(3, 10)
		"defense":
			value = randi_range(2, 6)
		_:
			value = 5

	var reward = RewardData.new(reward_id, "", RewardType.ATTRIBUTE_BOOST, value)
	reward.stat_key = stat_key
	reward._setup_defaults()
	return reward


## 生成随机武器升级奖励
static func _create_random_weapon_upgrade(reward_id: int) -> RewardData:
	var reward = RewardData.new(reward_id, "", RewardType.WEAPON_UPGRADE, 1)
	reward._setup_defaults()
	return reward


## 生成随机被动物品奖励
static func _create_random_passive_item(reward_id: int) -> RewardData:
	var passives = [
		{"id": "thorns", "name": "荆棘", "desc": "反弹10%受到的伤害"},
		{"id": "regen", "name": "再生", "desc": "每5秒恢复2点生命"},
		{"id": "magnet", "name": "磁铁", "desc": "自动拾取范围+50%"},
		{"id": "lucky", "name": "幸运星", "desc": "暴击率+5%"},
	]
	var passive = passives[randi() % passives.size()]

	var reward = RewardData.new(reward_id, passive["name"], RewardType.PASSIVE_ITEM, 0)
	reward.passive_id = passive["id"]
	reward.description = passive["desc"]
	reward._setup_defaults()
	return reward

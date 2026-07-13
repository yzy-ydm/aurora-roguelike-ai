## 奖励数据模型
##
## 定义房间清除后的奖励类型和数值

class_name RewardData
extends RefCounted

## 奖励类型枚举
enum RewardType {
	GOLD,           # 金币
	ATTACK_UP,      # 攻击力提升
	HEALTH_UP,      # 生命值提升
	HEAL            # 治疗
}

## 奖励属性
var id: int = 0
var name: String = ""
var description: String = ""
var type: RewardType = RewardType.GOLD
var value: int = 0
var color: Color = Color.WHITE


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


## 转换为字典
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"type": get_type_string(),
		"value": value
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

	reward.value = data.get("value", 0)
	reward._setup_defaults()
	return reward


## 生成随机奖励
static func generate_random_reward(reward_id: int = 0) -> RewardData:
	var random_type = randi() % 4
	var reward_type: RewardType
	var value: int

	match random_type:
		0:
			reward_type = RewardType.GOLD
			value = randi_range(10, 50)
		1:
			reward_type = RewardType.ATTACK_UP
			value = randi_range(1, 5)
		2:
			reward_type = RewardType.HEALTH_UP
			value = randi_range(5, 20)
		3:
			reward_type = RewardType.HEAL
			value = randi_range(10, 30)

	return RewardData.new(reward_id, "", reward_type, value)

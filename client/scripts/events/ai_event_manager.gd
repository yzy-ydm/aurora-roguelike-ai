## AI事件管理器 (Phase 11)
##
## 管理AI生成的事件
## 支持事件显示、选择、执行

extends Node

## 当前事件
var _current_event: AIEventData = null

## 事件状态
enum EventState {
	NONE,       # 无事件
	CHOOSING,   # 等待选择
	COMPLETED   # 已完成
}

var _state: EventState = EventState.NONE

## 信号
signal event_started(event: AIEventData)
signal event_choice_made(choice_index: int, choice_data: Dictionary)
signal event_completed(rewards: Dictionary)
signal event_state_changed(new_state: EventState)


## 初始化
func _ready() -> void:
	print("[AIEventManager] Initialized")


## 设置当前事件
func set_event(event_data: AIEventData) -> void:
	if not event_data or not event_data.is_valid():
		print("[AIEventManager] Invalid event data")
		return

	_current_event = event_data
	_set_state(EventState.CHOOSING)
	event_started.emit(_current_event)
	print("[AIEventManager] Event started: ", _current_event.title)


## 做出选择
func make_choice(choice_index: int) -> void:
	if _state != EventState.CHOOSING or not _current_event:
		print("[AIEventManager] No event to choose")
		return

	if choice_index < 0 or choice_index >= _current_event.choices.size():
		print("[AIEventManager] Invalid choice index: ", choice_index)
		return

	var choice_data = _current_event.choices[choice_index]
	print("[AIEventManager] Choice made: ", choice_data.get("text", ""))

	# 发送选择信号
	event_choice_made.emit(choice_index, choice_data)

	# 应用奖励
	var reward = choice_data.get("reward", {})
	if reward.size() > 0:
		await _apply_reward(reward)

	# 应用风险
	var risk = choice_data.get("risk", {})
	if risk.size() > 0:
		_apply_risk(risk)

	# 完成事件
	_current_event.complete()
	_set_state(EventState.COMPLETED)
	event_completed.emit(reward)


## 应用奖励
func _apply_reward(reward: Dictionary) -> void:
	# 获取玩家节点
	var player = _find_player()
	if not player:
		return

	# 应用各种奖励
	if reward.has("hp"):
		player.heal(reward["hp"])
		print("[AIEventManager] HP +", reward["hp"])

	if reward.has("health"):
		player.heal(reward["health"])
		print("[AIEventManager] Health +", reward["health"])

	if reward.has("exp"):
		# 通过UpgradeManager添加经验
		var upgrade_manager = _find_upgrade_manager()
		if upgrade_manager:
			await upgrade_manager.add_experience(reward["exp"])
			print("[AIEventManager] EXP +", reward["exp"])

	if reward.has("attack"):
		player.add_attack(reward["attack"])
		print("[AIEventManager] Attack +", reward["attack"])

	if reward.has("max_health"):
		player.add_max_health(reward["max_health"])
		print("[AIEventManager] Max Health +", reward["max_health"])

	if reward.has("gold"):
		player.add_gold(reward["gold"])
		print("[AIEventManager] Gold +", reward["gold"])

	if reward.has("attribute"):
		var attr = reward["attribute"]
		if attr is Dictionary:
			for key in attr:
				match key:
					"attack":
						player.add_attack(attr[key])
					"defense":
						# Phase 9.4.2: 通过PlayerStats修改防御
						if player.has_method("get_stats"):
							player.get_stats().add_defense(attr[key])
							print("[AIEventManager] Defense +", attr[key])
					"speed":
						if player.has_method("get_stats"):
							player.get_stats().add_move_speed_bonus(float(attr[key]) / 100.0)
							print("[AIEventManager] Speed +", attr[key])
			print("[AIEventManager] Attributes applied: ", attr)


## 应用风险
func _apply_risk(risk: Dictionary) -> void:
	var player = _find_player()
	if not player:
		return

	if risk.has("damage"):
		var damage = risk["damage"]
		player.take_damage(damage)
		print("[AIEventManager] Risk damage: ", damage)

	if risk.has("lose_hp"):
		var damage = risk["lose_hp"]
		player.take_damage(damage)
		print("[AIEventManager] Risk lose HP: ", damage)

	if risk.has("lose_gold"):
		var amount = risk["lose_gold"]
		# Phase 9.4.2: 通过PlayerStats读取金币
		if player.has_method("get_stats"):
			var current_gold = player.get_stats().gold
			player.add_gold(-amount)
			print("[AIEventManager] Risk lose gold: ", amount, " (was ", current_gold, ")")
		else:
			print("[AIEventManager] Cannot apply gold loss: player has no get_stats method")

	if risk.has("lose_upgrade"):
		# 升级回退（暂时只记录，实际效果需要UpgradeManager支持）
		print("[AIEventManager] Risk lose upgrade: ", risk["lose_upgrade"])
		# TODO: 与UpgradeManager集成实现升级回退


## 查找玩家节点
func _find_player() -> Node:
	var root = get_tree().current_scene
	if root:
		var game_world = root.get_node_or_null("GameWorld")
		if game_world:
			return game_world.get_node_or_null("Player")
	return null


## 查找升级管理器
func _find_upgrade_manager() -> Node:
	var root = get_tree().current_scene
	if root:
		return root.get_node_or_null("UpgradeManager")
	return null


## 设置状态
func _set_state(new_state: EventState) -> void:
	if _state == new_state:
		return
	_state = new_state
	event_state_changed.emit(new_state)

	match new_state:
		EventState.NONE:
			print("[AIEventManager] State: NONE")
		EventState.CHOOSING:
			print("[AIEventManager] State: CHOOSING")
		EventState.COMPLETED:
			print("[AIEventManager] State: COMPLETED")


## 获取当前事件
func get_current_event() -> AIEventData:
	return _current_event


## 获取当前状态
func get_state() -> EventState:
	return _state


## 是否正在选择
func is_choosing() -> bool:
	return _state == EventState.CHOOSING


## 清除事件
func clear_event() -> void:
	_current_event = null
	_set_state(EventState.NONE)

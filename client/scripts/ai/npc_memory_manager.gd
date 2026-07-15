## NPC记忆管理器 (Phase 13)
##
## 管理NPC与玩家的交互记忆
## 支持NPC记住玩家的过去选择和关系

extends Node

## ==================== 数据结构 ====================

## NPC记忆数据
class NPCMemory:
	var npc_id: String = ""
	var interaction_count: int = 0
	var last_interaction_time: float = 0.0
	var player_choices: Array[Dictionary] = []  # [{choice_text, timestamp}]
	var relationship: float = 0.0  # -1.0 到 1.0
	var notes: Array[String] = []  # NPC对玩家的印象


## ==================== 存储 ====================

## NPC记忆字典 {npc_id: NPCMemory}
var _memories: Dictionary = {}


## ==================== 信号 ====================

## NPC记忆更新
signal npc_memory_updated(npc_id: String, memory)


## ==================== 方法 ====================

## 记录NPC交互
func record_interaction(npc_id: String, player_choice: String = "", relationship_change: float = 0.0) -> void:
	var memory = _get_or_create_memory(npc_id)

	memory.interaction_count += 1
	memory.last_interaction_time = Time.get_unix_time_from_system()

	if player_choice != "":
		memory.player_choices.append({
			"choice_text": player_choice,
			"timestamp": memory.last_interaction_time
		})

	# 更新关系值
	memory.relationship = clamp(memory.relationship + relationship_change, -1.0, 1.0)

	npc_memory_updated.emit(npc_id, memory)
	print("[NPCMemory] Recorded interaction with ", npc_id, ", count: ", memory.interaction_count)


## 添加NPC笔记
func add_note(npc_id: String, note: String) -> void:
	var memory = _get_or_create_memory(npc_id)
	memory.notes.append(note)
	npc_memory_updated.emit(npc_id, memory)


## 获取NPC记忆
func get_memory(npc_id: String):
	return _memories.get(npc_id)


## 获取NPC记忆字典
func get_memory_dict(npc_id: String) -> Dictionary:
	var memory = _memories.get(npc_id)
	if not memory:
		return {}

	return {
		"interaction_count": memory.interaction_count,
		"relationship": memory.relationship,
		"player_choices": memory.player_choices,
		"notes": memory.notes
	}


## 获取NPC关系值
func get_relationship(npc_id: String) -> float:
	var memory = _memories.get(npc_id)
	if memory:
		return memory.relationship
	return 0.0


## 获取交互次数
func get_interaction_count(npc_id: String) -> int:
	var memory = _memories.get(npc_id)
	if memory:
		return memory.interaction_count
	return 0


## 获取所有记忆字典
func get_all_memories_dict() -> Dictionary:
	var result = {}
	for npc_id in _memories:
		result[npc_id] = get_memory_dict(npc_id)
	return result


## 检查是否是首次交互
func is_first_interaction(npc_id: String) -> bool:
	return not _memories.has(npc_id) or _memories[npc_id].interaction_count == 0


## 获取关系等级描述
func get_relationship_level(npc_id: String) -> String:
	var rel = get_relationship(npc_id)
	if rel >= 0.8:
		return "close_friend"  # 密友
	elif rel >= 0.5:
		return "friend"  # 朋友
	elif rel >= 0.2:
		return "friendly"  # 友好
	elif rel >= -0.2:
		return "neutral"  # 中立
	elif rel >= -0.5:
		return "unfriendly"  # 不友好
	else:
		return "hostile"  # 敌对


## ==================== 内部方法 ====================

## 获取或创建NPC记忆
func _get_or_create_memory(npc_id: String) -> NPCMemory:
	if not _memories.has(npc_id):
		var memory = NPCMemory.new()
		memory.npc_id = npc_id
		_memories[npc_id] = memory
	return _memories[npc_id]


## ==================== 序列化 ====================

## 转换为字典
func to_dict() -> Dictionary:
	var result = {}
	for npc_id in _memories:
		var memory = _memories[npc_id]
		result[npc_id] = {
			"interaction_count": memory.interaction_count,
			"last_interaction_time": memory.last_interaction_time,
			"player_choices": memory.player_choices,
			"relationship": memory.relationship,
			"notes": memory.notes
		}
	return result


## 从字典加载
func from_dict(data: Dictionary) -> void:
	_memories.clear()
	for npc_id in data:
		var memory_data = data[npc_id]
		var memory = NPCMemory.new()
		memory.npc_id = npc_id
		memory.interaction_count = memory_data.get("interaction_count", 0)
		memory.last_interaction_time = memory_data.get("last_interaction_time", 0.0)
		memory.player_choices = memory_data.get("player_choices", [])
		memory.relationship = memory_data.get("relationship", 0.0)
		memory.notes = memory_data.get("notes", [])
		_memories[npc_id] = memory

	print("[NPCMemory] Loaded ", _memories.size(), " NPC memories")


## 重置
func reset() -> void:
	_memories.clear()
	print("[NPCMemory] Reset all memories")

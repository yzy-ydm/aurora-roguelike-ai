## AI房间内容数据模型 (Phase 11)
##
## 保存AI生成的房间增强信息
## 不影响游戏核心逻辑，仅提供额外内容

class_name AIRoomContent
extends RefCounted

## 房间名称(AI生成)
var room_name: String = ""

## 房间描述(AI生成)
var room_description: String = ""

## 房间事件
var room_event: String = ""

## 事件选项
var event_choices: Array[Dictionary] = []

## 推荐等级
var recommended_level: int = 1

## 敌人修饰符(影响怪物属性)
var enemy_modifier: Dictionary = {}

## 奖励描述
var reward_description: String = ""

## NPC对话
var npc_dialogue: Array[String] = []

## 是否已加载AI内容
var is_loaded: bool = false


## 从Dictionary创建
static func from_dict(data: Dictionary) -> AIRoomContent:
	var content = AIRoomContent.new()
	content.room_name = data.get("room_name", "")
	content.room_description = data.get("room_description", "")
	content.room_event = data.get("room_event", "")
	content.event_choices = data.get("event_choices", [])
	content.recommended_level = data.get("recommended_level", 1)
	content.enemy_modifier = data.get("enemy_modifier", {})
	content.reward_description = data.get("reward_description", "")
	content.npc_dialogue = data.get("npc_dialogue", [])
	content.is_loaded = true
	return content


## 转换为Dictionary
func to_dict() -> Dictionary:
	return {
		"room_name": room_name,
		"room_description": room_description,
		"room_event": room_event,
		"event_choices": event_choices,
		"recommended_level": recommended_level,
		"enemy_modifier": enemy_modifier,
		"reward_description": reward_description,
		"npc_dialogue": npc_dialogue
	}


## 是否有事件
func has_event() -> bool:
	return room_event != "" and event_choices.size() > 0


## 是否有NPC对话
func has_dialogue() -> bool:
	return npc_dialogue.size() > 0

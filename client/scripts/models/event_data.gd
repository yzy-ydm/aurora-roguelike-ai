## 事件数据模型
##
## 负责解析和存储事件资源数据
## 从API JSON响应转换为结构化数据

class_name EventData
extends RefCounted

## 事件属性
var id: int = 0
var name: String = ""
var description: String = ""
var type: String = ""
var trigger_rate: float = 10.0
var min_floor: int = 1
var max_floor: int = 999
var effect_data: Variant = null
var option1_text: String = ""
var option1_effect: Variant = null
var option2_text: String = ""
var option2_effect: Variant = null


## 从Dictionary创建EventData
static func from_dict(data: Dictionary) -> EventData:
	var event = EventData.new()
	event.id = data.get("id", 0)
	event.name = data.get("name", "")
	event.description = data.get("description", "")
	event.type = data.get("type", "")
	event.trigger_rate = data.get("trigger_rate", 10.0)
	event.min_floor = data.get("min_floor", 1)
	event.max_floor = data.get("max_floor", 999)
	event.effect_data = data.get("effect_data", null)
	event.option1_text = data.get("option1_text", "")
	event.option1_effect = data.get("option1_effect", null)
	event.option2_text = data.get("option2_text", "")
	event.option2_effect = data.get("option2_effect", null)
	return event


## 从Dictionary数组创建EventData数组
static func from_array(data_array: Array) -> Array[EventData]:
	var events: Array[EventData] = []
	for data in data_array:
		if data is Dictionary:
			events.append(from_dict(data))
	return events


## 转换为Dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"type": type,
		"trigger_rate": trigger_rate,
		"min_floor": min_floor,
		"max_floor": max_floor,
		"effect_data": effect_data,
		"option1_text": option1_text,
		"option1_effect": option1_effect,
		"option2_text": option2_text,
		"option2_effect": option2_effect
	}

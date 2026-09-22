## 新房间数据模型 (Phase 10.1)
##
## 统一RoomNodeData和RoomData为单一模型
## 替代旧的 room_node_data.gd + room_data.gd
##
## 设计原则:
## - 房间类型用枚举(不用字符串)
## - 连接关系内嵌
## - 内容数据内嵌
## - 坐标系统一为像素坐标

class_name NewRoomData
extends RefCounted

## 房间类型枚举
enum RoomType {
	START,
	COMBAT,
	REWARD,
	SHOP,
	ELITE,
	BOSS,
	EVENT,
	TREASURE
}

## 基础属性
var id: int = 0
var display_index: int = 0  ## 玩家友好的显示编号(楼层内从1开始)
var room_type: RoomType = RoomType.COMBAT
var room_name: String = ""

## 连接关系
var connections: Array[int] = []

## 状态
var visited: bool = false
var completed: bool = false

## Phase 24: 房间进入计数，防止重复进入
## enter_count >= 2 表示房间已完成所有流程（进入→清除→离开）
var enter_count: int = 0

## 布局(像素坐标)
var position: Vector2 = Vector2.ZERO   # 房间中心在世界中的像素坐标
var width: int = 640                    # 房间宽度(像素), 默认640=20*32
var height: int = 480                   # 房间高度(像素), 默认480=15*32

## 房间内容
var content: RoomContentData = null


## 构造函数
func _init(node_id: int = 0, type: RoomType = RoomType.COMBAT) -> void:
	id = node_id
	room_type = type
	room_name = _generate_name()


## 生成房间名称
func _generate_name() -> String:
	# 使用 display_index 生成玩家友好的名称
	var idx = display_index if display_index > 0 else id
	match room_type:
		RoomType.START:
			return "起始房间"
		RoomType.COMBAT:
			return "战斗房间"
		RoomType.REWARD:
			return "奖励房间"
		RoomType.SHOP:
			return "商店房间"
		RoomType.ELITE:
			return "精英房间"
		RoomType.BOSS:
			return "Boss房间"
		RoomType.EVENT:
			return "事件房间"
		RoomType.TREASURE:
			return "宝箱房间"
		_:
			return "房间"


## ==================== 连接管理 ====================

func add_connection(target_id: int) -> void:
	if target_id not in connections:
		connections.append(target_id)


func remove_connection(target_id: int) -> void:
	connections.erase(target_id)


func is_connected_to(target_id: int) -> bool:
	return target_id in connections


func get_connection_count() -> int:
	return connections.size()


## ==================== 状态管理 ====================

func mark_visited() -> void:
	visited = true


func mark_completed() -> void:
	completed = true
	visited = true


func is_cleared() -> bool:
	return completed


## ==================== 类型工具 ====================

func get_type_string() -> String:
	match room_type:
		RoomType.START:
			return "start"
		RoomType.COMBAT:
			return "combat"
		RoomType.REWARD:
			return "reward"
		RoomType.SHOP:
			return "shop"
		RoomType.ELITE:
			return "elite"
		RoomType.BOSS:
			return "boss"
		RoomType.EVENT:
			return "event"
		RoomType.TREASURE:
			return "treasure"
		_:
			return "unknown"


## 获取玩家友好的显示名称(含区域编号)
func get_display_name() -> String:
	var idx = display_index if display_index > 0 else id
	return "区域" + str(idx)


func get_type_color() -> Color:
	match room_type:
		RoomType.START:
			return Color(0.2, 0.8, 0.2, 1.0)
		RoomType.COMBAT:
			return Color(0.8, 0.2, 0.2, 1.0)
		RoomType.REWARD:
			return Color(1.0, 0.84, 0.0, 1.0)
		RoomType.SHOP:
			return Color(0.2, 0.6, 0.8, 1.0)
		RoomType.ELITE:
			return Color(0.8, 0.2, 0.8, 1.0)
		RoomType.BOSS:
			return Color(0.9, 0.1, 0.1, 1.0)
		RoomType.EVENT:
			return Color(0.6, 0.4, 0.2, 1.0)
		RoomType.TREASURE:
			return Color(1.0, 0.6, 0.0, 1.0)
		_:
			return Color.WHITE


func has_monsters() -> bool:
	if content:
		return content.monster_count > 0
	return room_type in [RoomType.COMBAT, RoomType.ELITE, RoomType.BOSS]


## ==================== 静态工厂 ====================

static func type_from_string(type_str: String) -> RoomType:
	match type_str:
		"start":
			return RoomType.START
		"combat":
			return RoomType.COMBAT
		"reward":
			return RoomType.REWARD
		"shop":
			return RoomType.SHOP
		"elite":
			return RoomType.ELITE
		"boss":
			return RoomType.BOSS
		"event":
			return RoomType.EVENT
		"treasure":
			return RoomType.TREASURE
		_:
			return RoomType.COMBAT


## ==================== 序列化 ====================

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_index": display_index,
		"type": get_type_string(),
		"connections": connections,
		"visited": visited,
		"completed": completed,
		"position": {"x": position.x, "y": position.y},
		"width": width,
		"height": height
	}

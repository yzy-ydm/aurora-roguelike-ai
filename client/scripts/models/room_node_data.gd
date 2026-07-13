## 房间节点数据模型
##
## 用于Roguelike房间图系统
## 表示房间图中的一个节点

class_name RoomNodeData
extends RefCounted

## 房间类型枚举
enum RoomType {
	START,      # 起始房间
	COMBAT,     # 战斗房间
	REWARD,     # 奖励房间
	SHOP,       # 商店房间
	ELITE,      # 精英房间
	BOSS,       # Boss房间
	EVENT,      # 事件房间
	TREASURE    # 宝箱房间
}

## 房间属性
var id: int = 0
var room_type: RoomType = RoomType.COMBAT
var connections: Array[int] = []  # 连接的房间ID列表
var visited: bool = false
var completed: bool = false
var position: Vector2 = Vector2.ZERO  # 在房间图中的位置

## 房间数据（用于实际房间生成）
var room_data: RoomData = null


## 初始化
func _init(node_id: int = 0, type: RoomType = RoomType.COMBAT) -> void:
	id = node_id
	room_type = type


## 添加连接
func add_connection(room_id: int) -> void:
	if room_id not in connections:
		connections.append(room_id)


## 移除连接
func remove_connection(room_id: int) -> void:
	connections.erase(room_id)


## 检查是否连接到指定房间
func is_connected_to(room_id: int) -> bool:
	return room_id in connections


## 获取连接数量
func get_connection_count() -> int:
	return connections.size()


## 标记为已访问
func mark_visited() -> void:
	visited = true


## 标记为已完成
func mark_completed() -> void:
	completed = true
	visited = true


## 重置状态
func reset() -> void:
	visited = false
	completed = false


## 获取房间类型字符串
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
	return "unknown"


## 获取房间类型颜色
func get_type_color() -> Color:
	match room_type:
		RoomType.START:
			return Color(0.2, 0.8, 0.2, 1.0)  # 绿色
		RoomType.COMBAT:
			return Color(0.8, 0.2, 0.2, 1.0)  # 红色
		RoomType.REWARD:
			return Color(1.0, 0.84, 0.0, 1.0)  # 金色
		RoomType.SHOP:
			return Color(0.2, 0.6, 0.8, 1.0)  # 蓝色
		RoomType.ELITE:
			return Color(0.8, 0.2, 0.8, 1.0)  # 紫色
		RoomType.BOSS:
			return Color(0.9, 0.1, 0.1, 1.0)  # 深红色
		RoomType.EVENT:
			return Color(0.6, 0.4, 0.2, 1.0)  # 棕色
		RoomType.TREASURE:
			return Color(1.0, 0.6, 0.0, 1.0)  # 橙色
	return Color.WHITE


## 转换为字典
func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": get_type_string(),
		"connections": connections,
		"visited": visited,
		"completed": completed,
		"position": {"x": position.x, "y": position.y}
	}


## 从字典创建
static func from_dict(data: Dictionary) -> RoomNodeData:
	var node = RoomNodeData.new()
	node.id = data.get("id", 0)

	var type_str = data.get("type", "combat")
	match type_str:
		"start":
			node.room_type = RoomType.START
		"combat":
			node.room_type = RoomType.COMBAT
		"reward":
			node.room_type = RoomType.REWARD
		"shop":
			node.room_type = RoomType.SHOP
		"elite":
			node.room_type = RoomType.ELITE
		"boss":
			node.room_type = RoomType.BOSS
		"event":
			node.room_type = RoomType.EVENT
		"treasure":
			node.room_type = RoomType.TREASURE

	node.connections = data.get("connections", [])
	node.visited = data.get("visited", false)
	node.completed = data.get("completed", false)

	var pos = data.get("position", {})
	node.position = Vector2(pos.get("x", 0), pos.get("y", 0))

	return node

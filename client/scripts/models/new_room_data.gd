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

## Phase 24: 房间进入计数
## TASK-005: 仅保留用于调试/存档兼容/数据统计
## 禁止任何业务逻辑使用（旧规则 enter_count >= 2 已废弃）
## 所有进入限制统一使用 RoomState.COMPLETED
var enter_count: int = 0

## ==================== TASK-005: 房间生命周期状态机 ====================
## 所有状态变化必须经过 transition_to()，禁止其他脚本直接修改

enum RoomState {
	ENTERING,   ## 进入房间（初始化阶段）
	COMBAT,     ## 战斗中（战斗房/Boss房）
	REWARD,     ## 奖励阶段（战斗房清怪后 / 奖励房 / 宝箱房）
	EVENT,      ## 事件流程（事件房）
	COMPLETED,  ## 已完成（终态：创建唯一出口，禁止重入）
	EXITING     ## 已离开（未完成房被放弃，允许回溯重入）
}

## 当前房间状态（唯一权威来源）
## completed 字段仅为存档兼容快照；所有业务判断一律读取 state
var state: RoomState = RoomState.ENTERING

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

## TASK-005: 房间状态转换唯一入口
## 所有状态变化必须经过此方法；非法转换直接拒绝并记录日志
## 转换日志格式: [RoomState] Room ID: X | OLD_STATE -> NEW_STATE
func transition_to(new_state: RoomState) -> bool:
	if new_state == state:
		return true  # 幂等：同状态转换视为成功，不重复记录日志
	if not _is_legal_transition(state, new_state):
		print("[RoomState] Room ID: ", id, " | ", state_to_string(state),
			" -> ", state_to_string(new_state), " REJECTED (illegal transition)")
		return false
	var old_state: RoomState = state
	state = new_state
	if new_state == RoomState.COMPLETED:
		completed = true   # 存档兼容快照（禁止作为业务判断条件）
		visited = true
	print("[RoomState] Room ID: ", id, " | ", state_to_string(old_state),
		" -> ", state_to_string(new_state))
	return true


## 合法转换表
## ENTERING → COMBAT / REWARD / EVENT / COMPLETED / EXITING
## COMBAT   → REWARD / EXITING / COMPLETED（仅异常兜底，如Boss生成失败；正常流程必须经 REWARD）
## REWARD   → COMPLETED / EXITING
## EVENT    → COMPLETED / EXITING
## COMPLETED → (终态，禁止任何再转换)
## EXITING  → ENTERING（回溯重入未完成房）
func _is_legal_transition(from_state: RoomState, to_state: RoomState) -> bool:
	match from_state:
		RoomState.ENTERING:
			return to_state in [RoomState.COMBAT, RoomState.REWARD, RoomState.EVENT,
				RoomState.COMPLETED, RoomState.EXITING]
		RoomState.COMBAT:
			return to_state in [RoomState.REWARD, RoomState.EXITING, RoomState.COMPLETED]
		RoomState.REWARD:
			return to_state in [RoomState.COMPLETED, RoomState.EXITING]
		RoomState.EVENT:
			return to_state in [RoomState.COMPLETED, RoomState.EXITING]
		RoomState.COMPLETED:
			return false
		RoomState.EXITING:
			return to_state == RoomState.ENTERING
	return false


## 状态字符串（日志/调试/论文展示用）
static func state_to_string(s: RoomState) -> String:
	match s:
		RoomState.ENTERING: return "ENTERING"
		RoomState.COMBAT: return "COMBAT"
		RoomState.REWARD: return "REWARD"
		RoomState.EVENT: return "EVENT"
		RoomState.COMPLETED: return "COMPLETED"
		RoomState.EXITING: return "EXITING"
	return "UNKNOWN"


## TASK-005: 房间是否已完成（业务判断统一入口，替代旧 completed 布尔）
func is_completed() -> bool:
	return state == RoomState.COMPLETED


## TASK-005: 房间是否允许进入（统一进入限制，替代旧 enter_count>=2）
func can_enter() -> bool:
	return state != RoomState.COMPLETED


func mark_visited() -> void:
	visited = true


## 兼容接口：仅存档/旧代码使用；业务上请使用 transition_to(RoomState.COMPLETED)
func mark_completed() -> void:
	completed = true
	visited = true


func is_cleared() -> bool:
	return is_completed()


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
		"state": state_to_string(state),
		"position": {"x": position.x, "y": position.y},
		"width": width,
		"height": height
	}

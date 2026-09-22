## 世界坐标系统 (Phase 17.1: 横版房间)
##
## 统一坐标转换规则
## 禁止直接使用room.position作为世界坐标
##
## 坐标体系:
## - 房间坐标(room position): 房间中心在世界中的位置
## - 房间内坐标(local pos): 相对于房间中心的偏移(-width/2 ~ +width/2, -height/2 ~ +height/2)
## - 世界坐标(world pos): 最终渲染坐标
##
## 所有坐标必须经过本模块转换

class_name WorldCoordinate
extends RefCounted

## 房间默认尺寸(像素) - Phase 17.1: 横版宽屏
const ROOM_WIDTH: int = 1280
const ROOM_HEIGHT: int = 720
const HALF_WIDTH: int = 640
const HALF_HEIGHT: int = 360

## 地面高度配置
const GROUND_HEIGHT: int = 64
const GROUND_Y: int = HALF_HEIGHT - GROUND_HEIGHT / 2


## ==================== 核心转换 ====================

## 房间内随机位置 → 世界坐标
## room_center: 房间中心的世界坐标
## margin: 距墙壁的最小距离(像素)
static func random_world_pos(room_center: Vector2, margin: float = 40.0) -> Vector2:
	var x = randf_range(-HALF_WIDTH + margin, HALF_WIDTH - margin)
	var y = randf_range(-HALF_HEIGHT + margin, HALF_HEIGHT - margin)
	return room_center + Vector2(x, y)


## 房间内指定位置 → 世界坐标
## local_pos: 相对于房间中心的偏移
static func local_to_world(room_center: Vector2, local_pos: Vector2) -> Vector2:
	return room_center + local_pos


## 世界坐标 → 房间内坐标
static func world_to_local(room_center: Vector2, world_pos: Vector2) -> Vector2:
	return world_pos - room_center


## ==================== 预设位置 ====================

## 获取房间内预设的怪物生成区域(横版: 地面上)
## Phase 17.5: 根据index分布怪物位置，避免重叠
static func monster_spawn_pos(room_center: Vector2, index: int = 0, total: int = 1) -> Vector2:
	# 根据index分布怪物位置
	var x_offset: float

	if total == 1:
		# 单个怪物：随机左侧或右侧
		var side = randi() % 2
		if side == 0:
			x_offset = randf_range(-400, -200)
		else:
			x_offset = randf_range(200, 400)
	else:
		# 多个怪物：均匀分布
		var spacing = 600.0 / (total + 1)
		x_offset = -300 + spacing * (index + 1)
		# 添加随机偏移
		x_offset += randf_range(-30, 30)

	# Y坐标在地面上方（怪物高度的一半）
	var y_pos = GROUND_Y - 30

	return room_center + Vector2(x_offset, y_pos)


## 获取奖励生成位置(横版: 地面上，玩家可达范围)
## Phase 24: 奖励必须在玩家跳跃可达范围内生成
const REWARD_FLOAT_OFFSET: int = 40
static func reward_spawn_pos(room_center: Vector2) -> Vector2:
	# 奖励生成在地面附近，确保玩家可以走到拾取
	var x = randf_range(-200, 200)  # 水平范围缩小，确保在平台附近
	var y = GROUND_Y - REWARD_FLOAT_OFFSET  # 在地面上方40像素
	# 返回世界坐标
	return room_center + Vector2(x, y)


## 获取出口传送门位置(横版: 右侧地面)
static func exit_portal_pos(room_center: Vector2) -> Vector2:
	return room_center + Vector2(HALF_WIDTH - 40, GROUND_Y - 30)


## 获取玩家出生位置(横版: 地面左侧)
static func player_spawn_pos(room_center: Vector2) -> Vector2:
	return room_center + Vector2(-HALF_WIDTH + 100, GROUND_Y - 30)


## ==================== 边界检查 ====================

## 检查世界坐标是否在房间内
static func is_in_room(room_center: Vector2, world_pos: Vector2) -> bool:
	var local = world_to_local(room_center, world_pos)
	return abs(local.x) <= HALF_WIDTH and abs(local.y) <= HALF_HEIGHT


## 将世界坐标钳制到房间内
static func clamp_to_room(room_center: Vector2, world_pos: Vector2) -> Vector2:
	var local = world_to_local(room_center, world_pos)
	local.x = clamp(local.x, -HALF_WIDTH + 10, HALF_WIDTH - 10)
	local.y = clamp(local.y, -HALF_HEIGHT + 10, HALF_HEIGHT - 10)
	return room_center + local

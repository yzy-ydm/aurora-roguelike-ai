## 世界坐标系统 (Phase 10.1.5)
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

## 房间默认尺寸(像素)
const ROOM_WIDTH: int = 640   # 20 * 32
const ROOM_HEIGHT: int = 480  # 15 * 32
const HALF_WIDTH: int = 320
const HALF_HEIGHT: int = 240


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

## 获取房间内预设的怪物生成区域(避开中心玩家区域)
static func monster_spawn_pos(room_center: Vector2) -> Vector2:
	# 怪物在房间边缘区域生成, 避开中心
	var side = randi() % 4
	var pos: Vector2
	match side:
		0:  # 上
			pos = Vector2(randf_range(-HALF_WIDTH + 40, HALF_WIDTH - 40), -HALF_HEIGHT + 60)
		1:  # 下
			pos = Vector2(randf_range(-HALF_WIDTH + 40, HALF_WIDTH - 40), HALF_HEIGHT - 60)
		2:  # 左
			pos = Vector2(-HALF_WIDTH + 60, randf_range(-HALF_HEIGHT + 40, HALF_HEIGHT - 40))
		3:  # 右
			pos = Vector2(HALF_WIDTH - 60, randf_range(-HALF_HEIGHT + 40, HALF_HEIGHT - 40))
	return room_center + pos


## 获取奖励生成位置(房间内随机, 偏中心)
static func reward_spawn_pos(room_center: Vector2) -> Vector2:
	var x = randf_range(-100, 100)
	var y = randf_range(-80, 80)
	return room_center + Vector2(x, y)


## 获取出口传送门位置(房间右侧)
static func exit_portal_pos(room_center: Vector2) -> Vector2:
	return room_center + Vector2(HALF_WIDTH - 30, 0)


## 获取玩家出生位置(房间中心)
static func player_spawn_pos(room_center: Vector2) -> Vector2:
	return room_center


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

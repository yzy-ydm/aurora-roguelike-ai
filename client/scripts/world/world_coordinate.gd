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

	# TASK-001 修复: 怪物出生在地面上站立高度（而非悬浮于空中）
	# 地面顶部 = GROUND_Y - GROUND_HEIGHT/2 = 328 - 32 = 296
	# 怪物碰撞体28px高，中心 = 296 - 14 = 282
	# 旧值 298 使怪物出生后陷入地面16px（AI尚未修复重力前会永久悬浮）
	const MONSTER_HALF_HEIGHT: float = 14.0
	var y_pos = GROUND_Y - GROUND_HEIGHT / 2.0 - MONSTER_HALF_HEIGHT

	return room_center + Vector2(x_offset, y_pos)


## ==================== 奖励生成位置（TASK-002: 平台感知） ====================

## 奖励浮动高度（地面带: 地面中心 GROUND_Y 以上 40px，即地面顶部以上 8px）
const REWARD_FLOAT_OFFSET: int = 40

## 奖励拾取碰撞半径（与 reward_item.gd 的 CircleShape2D 一致）
const REWARD_COLLISION_RADIUS: float = 20.0

## 平台上方安全间隙: 奖励圆底部与平台顶面至少间隔 6px（Y轴安全偏移）
const REWARD_PLATFORM_CLEARANCE: float = 6.0

## 地面带 X 范围: 左右边界墙内侧面在 ±630，奖励半径 20 → ±400 足够安全
const REWARD_GROUND_BAND_X: float = 400.0

## 平台顶面最低高度（最低高度限制）:
## 地面顶部 = GROUND_Y - GROUND_HEIGHT/2 = 296；玩家站立中心 ≈ 280，最大跳跃 ≈ 65-70px
## 平台顶面 y ∈ [226, 296] 时玩家可从地面直接跳上；更低（更高处）的平台视为不可达装饰
const REWARD_PLATFORM_TOP_MIN_Y: float = 226.0


## 获取奖励生成位置（横版: 地面上/平台上方，保证玩家可拾取）
## TASK-002: 平台感知采样——
##   1) 优先地面带（GROUND_Y-40 附近，按 index/total 分布槽位 + 随机抖动）
##   2) 地面带被平台占据时，落在可达平台（顶面 y∈[226,296]）上方 6px
##   3) 兜底: 系统化地面扫描（确定性）
## platform_rects: 房间内平台矩形列表（RoomRenderer.get_platform_rects()，local 坐标，position=左上角）
## index/total: 多个奖励时的槽位分布（旧调用方不传时默认房间中央地面带）
static func reward_spawn_pos(room_center: Vector2, platform_rects: Array[Rect2] = [], index: int = 0, total: int = 1, rng: RandomNumberGenerator = null) -> Vector2:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var ground_y: float = float(GROUND_Y - REWARD_FLOAT_OFFSET)
	var total_f: float = maxf(1.0, float(total))
	var target_x: float = lerpf(-REWARD_GROUND_BAND_X, REWARD_GROUND_BAND_X, (float(index) + 0.5) / total_f)

	# 1) 地面带采样: 槽位附近抖动，找到第一个不与平台重叠的点
	for attempt in range(12):
		var x: float = clampf(target_x + rng.randf_range(-80.0, 80.0), -REWARD_GROUND_BAND_X, REWARD_GROUND_BAND_X)
		var y: float = ground_y + rng.randf_range(-8.0, 8.0)
		if _reward_pos_clear(Vector2(x, y), platform_rects):
			return room_center + Vector2(x, y)

	# 2) 平台顶面采样: 平台顶面在跳跃可达范围内 → 奖励放在平台上方安全间隙处
	#    选平台中心 X 最接近目标槽位的一个，保证多个奖励分散
	var best: Vector2 = Vector2.ZERO
	var best_dist: float = INF
	var found: bool = false
	for rect in platform_rects:
		var top_y: float = rect.position.y
		if top_y < REWARD_PLATFORM_TOP_MIN_Y or top_y > float(GROUND_Y - GROUND_HEIGHT / 2.0):
			continue  # 最低高度限制: 平台顶面必须在 [226, 296]（地面一跳可达）
		var min_x: float = rect.position.x + REWARD_COLLISION_RADIUS
		var max_x: float = rect.end.x - REWARD_COLLISION_RADIUS
		if max_x < min_x:
			continue  # 平台太窄放不下奖励
		var px: float = clampf(target_x, min_x, max_x)
		var cand: Vector2 = Vector2(px, top_y - REWARD_COLLISION_RADIUS - REWARD_PLATFORM_CLEARANCE)
		if _reward_pos_clear(cand, platform_rects):
			var d: float = absf(rect.get_center().x - target_x)
			if d < best_dist:
				best_dist = d
				best = cand
				found = true
	if found:
		return room_center + best

	# 3) 系统化地面扫描（确定性兜底）
	var scan_x: float = -REWARD_GROUND_BAND_X
	while scan_x <= REWARD_GROUND_BAND_X:
		if _reward_pos_clear(Vector2(scan_x, ground_y), platform_rects):
			return room_center + Vector2(scan_x, ground_y)
		scan_x += 56.0

	# 4) 最终兜底（理论不可达: 所有候选都被占据时退回旧行为）
	return room_center + Vector2(0.0, ground_y)


## TASK-002: 奖励中心点是否与所有平台矩形保持安全距离（碰撞区域检测）
## 判定: 矩形向外扩大 (奖励半径+安全间隙) 后仍包含该点 → 不安全（经典圆-矩形碰撞检测）
## 容差 0.1px: 使"恰好间隔 6px"的平台顶面候选判定为安全（浮点边界）
static func _reward_pos_clear(local_pos: Vector2, platform_rects: Array[Rect2]) -> bool:
	# 墙体/房间边界保护（不生成在墙体）
	if absf(local_pos.x) > HALF_WIDTH - 40.0 or absf(local_pos.y) > HALF_HEIGHT - 40.0:
		return false
	var margin: float = REWARD_COLLISION_RADIUS + REWARD_PLATFORM_CLEARANCE - 0.1
	for rect in platform_rects:
		if rect.grow(margin).has_point(local_pos):
			return false
	return true


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

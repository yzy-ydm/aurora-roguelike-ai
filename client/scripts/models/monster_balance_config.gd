## 怪物属性平衡配置 (Phase 24)
##
## 统一客户端和服务端的怪物数值范围
## 所有房间类型和楼层的怪物属性必须使用此配置
## 禁止在业务代码中硬编码HP/Attack/Defense

class_name MonsterBalanceConfig
extends RefCounted

## ==================== 基础属性范围 ====================

## 普通怪物 (floor 1) - TASK-028: HP 80-150 / ATK 10-20（玩家不能无脑站撸）
const NORMAL_HP_MIN: int = 80
const NORMAL_HP_MAX: int = 150
const NORMAL_ATK_MIN: int = 10
const NORMAL_ATK_MAX: int = 20
const NORMAL_DEF_MIN: int = 0
const NORMAL_DEF_MAX: int = 5

## 普通怪物 (floor 2) - TASK-028: HP 120-220 / ATK 15-30
const NORMAL_F2_HP_MIN: int = 120
const NORMAL_F2_HP_MAX: int = 220
const NORMAL_F2_ATK_MIN: int = 15
const NORMAL_F2_ATK_MAX: int = 30

## 移动速度 (px/s) - TASK-017.7: 玩家基础速度200，怪物约为其1/3
## 修复前 DB 数据为 3~15（蜗速），统一由本配置生成
const NORMAL_SPEED_MIN: float = 60.0
const NORMAL_SPEED_MAX: float = 90.0

## 精英怪物 (floor 1)
const ELITE_HP_MIN: int = 200
const ELITE_HP_MAX: int = 400
const ELITE_ATK_MIN: int = 12
const ELITE_ATK_MAX: int = 25
const ELITE_DEF_MIN: int = 3
const ELITE_DEF_MAX: int = 10
const ELITE_SPEED_MIN: float = 70.0
const ELITE_SPEED_MAX: float = 120.0

## Boss (floor 1) - TASK-027: HP 500-800；TASK-028: ATK 30-50
const BOSS_HP_MIN: int = 500
const BOSS_HP_MAX: int = 800
const BOSS_ATK_MIN: int = 30
const BOSS_ATK_MAX: int = 50
const BOSS_DEF_MIN: int = 5
const BOSS_DEF_MAX: int = 15
const BOSS_SPEED_MIN: float = 90.0
const BOSS_SPEED_MAX: float = 130.0

## ==================== 楼层缩放系数 ====================

## 每层增加的比例（线性增长）
const HP_SCALE_PER_LEVEL: float = 0.15   # 每层+15%HP
const ATK_SCALE_PER_LEVEL: float = 0.10  # 每层+10%攻击
const DEF_SCALE_PER_LEVEL: float = 0.08  # 每层+8%防御
const SPEED_SCALE_PER_LEVEL: float = 0.05  # 每层+5%速度（TASK-017.7，远慢于属性增长）

## 最大缩放倍数（防止数值膨胀）
const MAX_HP_MULTIPLIER: float = 3.0
const MAX_ATK_MULTIPLIER: float = 2.5
const MAX_DEF_MULTIPLIER: float = 2.0
const MAX_SPEED_MULTIPLIER: float = 1.5  # TASK-017.7: 速度上限+50%（怪物不追上玩家）


## ==================== 核心方法 ====================

## 根据怪物类型和楼层获取属性范围
## TASK-028: 普通怪按层基准（第一层/第二层明确目标区间），
## 第三层起在第二层基准上按 +15%/层 缓增（封顶 3.0）
static func get_range(monster_type: String, floor_level: int) -> Dictionary:
	var speed_factor: float = _get_speed_factor(floor_level)

	if monster_type != "elite" and monster_type != "boss":
		# normal: 分层基准
		if floor_level <= 1:
			return {
				"hp_min": NORMAL_HP_MIN, "hp_max": NORMAL_HP_MAX,
				"atk_min": NORMAL_ATK_MIN, "atk_max": NORMAL_ATK_MAX,
				"def_min": NORMAL_DEF_MIN, "def_max": NORMAL_DEF_MAX,
				"spd_min": NORMAL_SPEED_MIN, "spd_max": NORMAL_SPEED_MAX
			}
		var f: int = max(2, floor_level)
		var factor: float = min(1.0 + (f - 2) * HP_SCALE_PER_LEVEL, MAX_HP_MULTIPLIER)
		return {
			"hp_min": int(NORMAL_F2_HP_MIN * factor), "hp_max": int(NORMAL_F2_HP_MAX * factor),
			"atk_min": int(NORMAL_F2_ATK_MIN * factor), "atk_max": int(NORMAL_F2_ATK_MAX * factor),
			"def_min": NORMAL_DEF_MIN, "def_max": NORMAL_DEF_MAX,
			"spd_min": NORMAL_SPEED_MIN * speed_factor, "spd_max": NORMAL_SPEED_MAX * speed_factor
		}

	var base: Dictionary
	var level_factor: float = _get_level_factor(floor_level)

	match monster_type:
		"elite":
			base = {
				"hp_min": ELITE_HP_MIN, "hp_max": ELITE_HP_MAX,
				"atk_min": ELITE_ATK_MIN, "atk_max": ELITE_ATK_MAX,
				"def_min": ELITE_DEF_MIN, "def_max": ELITE_DEF_MAX,
				"spd_min": ELITE_SPEED_MIN, "spd_max": ELITE_SPEED_MAX
			}
		_:
			base = {
				"hp_min": BOSS_HP_MIN, "hp_max": BOSS_HP_MAX,
				"atk_min": BOSS_ATK_MIN, "atk_max": BOSS_ATK_MAX,
				"def_min": BOSS_DEF_MIN, "def_max": BOSS_DEF_MAX,
				"spd_min": BOSS_SPEED_MIN, "spd_max": BOSS_SPEED_MAX
			}

	return {
		"hp_min": int(base["hp_min"] * level_factor),
		"hp_max": int(base["hp_max"] * level_factor),
		"atk_min": int(base["atk_min"] * level_factor),
		"atk_max": int(base["atk_max"] * level_factor),
		"def_min": int(base["def_min"] * level_factor),
		"def_max": int(base["def_max"] * level_factor),
		"spd_min": base["spd_min"] * speed_factor,
		"spd_max": base["spd_max"] * speed_factor
	}


## 生成单个怪物属性（带随机性）
static func generate_monster_stats(monster_type: String, floor_level: int) -> Dictionary:
	var range = get_range(monster_type, floor_level)
	return {
		"health": randi_range(range["hp_min"], range["hp_max"]),
		"attack": randi_range(range["atk_min"], range["atk_max"]),
		"defense": randi_range(range["def_min"], range["def_max"]),
		"speed": randi_range(int(range["spd_min"]), int(range["spd_max"])),  # TASK-017.7
		"level": floor_level
	}


## 钳制已有属性到合理范围
static func clamp_stats(stats: Dictionary, monster_type: String, floor_level: int) -> Dictionary:
	var range = get_range(monster_type, floor_level)
	stats["health"] = clampi(stats.get("health", 50), range["hp_min"], range["hp_max"])
	stats["attack"] = clampi(stats.get("attack", 5), range["atk_min"], range["atk_max"])
	stats["defense"] = clampi(stats.get("defense", 0), range["def_min"], range["def_max"])
	return stats


## ==================== 内部工具 ====================

## 计算楼层缩放因子
static func _get_level_factor(floor_level: int) -> float:
	if floor_level <= 1:
		return 1.0
	var hp_factor = min(1.0 + (floor_level - 1) * HP_SCALE_PER_LEVEL, MAX_HP_MULTIPLIER)
	var atk_factor = min(1.0 + (floor_level - 1) * ATK_SCALE_PER_LEVEL, MAX_ATK_MULTIPLIER)
	var def_factor = min(1.0 + (floor_level - 1) * DEF_SCALE_PER_LEVEL, MAX_DEF_MULTIPLIER)
	# 使用HP因子作为统一缩放（简化）
	return hp_factor


## 计算速度楼层缩放因子（TASK-017.7: 速度独立缩放，上限+50%保持玩家风筝能力）
static func _get_speed_factor(floor_level: int) -> float:
	if floor_level <= 1:
		return 1.0
	return min(1.0 + (floor_level - 1) * SPEED_SCALE_PER_LEVEL, MAX_SPEED_MULTIPLIER)

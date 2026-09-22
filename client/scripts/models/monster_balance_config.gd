## 怪物属性平衡配置 (Phase 24)
##
## 统一客户端和服务端的怪物数值范围
## 所有房间类型和楼层的怪物属性必须使用此配置
## 禁止在业务代码中硬编码HP/Attack/Defense

class_name MonsterBalanceConfig
extends RefCounted

## ==================== 基础属性范围 ====================

## 普通怪物 (floor 1)
const NORMAL_HP_MIN: int = 50
const NORMAL_HP_MAX: int = 150
const NORMAL_ATK_MIN: int = 5
const NORMAL_ATK_MAX: int = 15
const NORMAL_DEF_MIN: int = 0
const NORMAL_DEF_MAX: int = 5

## 精英怪物 (floor 1)
const ELITE_HP_MIN: int = 200
const ELITE_HP_MAX: int = 400
const ELITE_ATK_MIN: int = 12
const ELITE_ATK_MAX: int = 25
const ELITE_DEF_MIN: int = 3
const ELITE_DEF_MAX: int = 10

## Boss (floor 1)
const BOSS_HP_MIN: int = 800
const BOSS_HP_MAX: int = 1200
const BOSS_ATK_MIN: int = 20
const BOSS_ATK_MAX: int = 35
const BOSS_DEF_MIN: int = 5
const BOSS_DEF_MAX: int = 15

## ==================== 楼层缩放系数 ====================

## 每层增加的比例（线性增长）
const HP_SCALE_PER_LEVEL: float = 0.15   # 每层+15%HP
const ATK_SCALE_PER_LEVEL: float = 0.10  # 每层+10%攻击
const DEF_SCALE_PER_LEVEL: float = 0.08  # 每层+8%防御

## 最大缩放倍数（防止数值膨胀）
const MAX_HP_MULTIPLIER: float = 3.0
const MAX_ATK_MULTIPLIER: float = 2.5
const MAX_DEF_MULTIPLIER: float = 2.0


## ==================== 核心方法 ====================

## 根据怪物类型和楼层获取属性范围
static func get_range(monster_type: String, floor_level: int) -> Dictionary:
	var base: Dictionary
	var level_factor: float = _get_level_factor(floor_level)

	match monster_type:
		"elite":
			base = {
				"hp_min": ELITE_HP_MIN, "hp_max": ELITE_HP_MAX,
				"atk_min": ELITE_ATK_MIN, "atk_max": ELITE_ATK_MAX,
				"def_min": ELITE_DEF_MIN, "def_max": ELITE_DEF_MAX
			}
		"boss":
			base = {
				"hp_min": BOSS_HP_MIN, "hp_max": BOSS_HP_MAX,
				"atk_min": BOSS_ATK_MIN, "atk_max": BOSS_ATK_MAX,
				"def_min": BOSS_DEF_MIN, "def_max": BOSS_DEF_MAX
			}
		_:  # normal 或未知
			base = {
				"hp_min": NORMAL_HP_MIN, "hp_max": NORMAL_HP_MAX,
				"atk_min": NORMAL_ATK_MIN, "atk_max": NORMAL_ATK_MAX,
				"def_min": NORMAL_DEF_MIN, "def_max": NORMAL_DEF_MAX
			}

	return {
		"hp_min": int(base["hp_min"] * level_factor),
		"hp_max": int(base["hp_max"] * level_factor),
		"atk_min": int(base["atk_min"] * level_factor),
		"atk_max": int(base["atk_max"] * level_factor),
		"def_min": int(base["def_min"] * level_factor),
		"def_max": int(base["def_max"] * level_factor)
	}


## 生成单个怪物属性（带随机性）
static func generate_monster_stats(monster_type: String, floor_level: int) -> Dictionary:
	var range = get_range(monster_type, floor_level)
	return {
		"health": randi_range(range["hp_min"], range["hp_max"]),
		"attack": randi_range(range["atk_min"], range["atk_max"]),
		"defense": randi_range(range["def_min"], range["def_max"]),
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

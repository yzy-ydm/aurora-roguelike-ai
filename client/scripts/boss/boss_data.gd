## Boss数据模型 (Phase 12)
##
## 定义Boss的属性和技能配置

class_name BossData
extends RefCounted

## Boss阶段
enum BossPhase {
	PHASE_1,    # 第一阶段
	PHASE_2,    # 第二阶段 (HP < 50%)
	PHASE_3     # 第三阶段 (HP < 25%)
}

## 基础属性
var id: String = ""
var name: String = ""
var description: String = ""

## 战斗属性
var max_health: int = 500
var attack: int = 25
var defense: int = 10
var speed: float = 120.0

## Phase 9.3: 攻击节奏控制
var attack_cooldown: float = 1.5       # 攻击间隔(秒)，最低1.5秒
var attack_prepare_time: float = 0.5   # 攻击前摇(秒)，给玩家反应时间

## 阶段配置
var phase_thresholds: Dictionary = {
	0.5: BossPhase.PHASE_2,
	0.25: BossPhase.PHASE_3
}

## 技能列表
var skills: Array[Dictionary] = []

## 当前阶段
var _current_phase: BossPhase = BossPhase.PHASE_1

## 掉落奖励
var reward_gold: int = 200
var reward_exp: int = 150


## 从字典创建
static func from_dict(data: Dictionary) -> BossData:
	var boss = BossData.new()
	boss.id = data.get("id", "")
	boss.name = data.get("name", "Unknown Boss")
	boss.description = data.get("description", "")
	boss.max_health = data.get("max_health", 500)
	boss.attack = data.get("attack", 25)
	boss.defense = data.get("defense", 10)
	boss.speed = data.get("speed", 120.0)
	boss.attack_cooldown = data.get("attack_cooldown", 1.5)
	boss.attack_prepare_time = data.get("attack_prepare_time", 0.5)
	# TASK-022: 未类型化 Array 不能直接赋给 Array[Dictionary] 成员，逐项验证类型
	var raw_skills = data.get("skills", [])
	if raw_skills is Array:
		for item in raw_skills:
			if item is Dictionary:
				boss.skills.append(item)
	boss.reward_gold = data.get("reward_gold", 200)
	boss.reward_exp = data.get("reward_exp", 150)

	if data.has("phase_thresholds"):
		boss.phase_thresholds = data["phase_thresholds"]

	return boss


## 转换为字典
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"max_health": max_health,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"attack_cooldown": attack_cooldown,
		"attack_prepare_time": attack_prepare_time,
		"skills": skills,
		"reward_gold": reward_gold,
		"reward_exp": reward_exp,
		"phase_thresholds": phase_thresholds
	}


## 检查阶段转换
func check_phase_transition(current_health: int) -> BossPhase:
	var health_percent = float(current_health) / float(max_health)

	for threshold in phase_thresholds:
		if health_percent <= threshold:
			var new_phase = phase_thresholds[threshold]
			if new_phase > _current_phase:
				_current_phase = new_phase
				return _current_phase

	return _current_phase


## 获取当前阶段
func get_current_phase() -> BossPhase:
	return _current_phase


## 获取当前阶段的技能
func get_phase_skills() -> Array[Dictionary]:
	var phase_skills: Array[Dictionary] = []
	for skill in skills:
		var skill_phase = skill.get("phase", 0)
		if skill_phase <= _current_phase:
			phase_skills.append(skill)
	return phase_skills


## 获取阶段名称
func get_phase_name() -> String:
	match _current_phase:
		BossPhase.PHASE_1:
			return "Phase 1"
		BossPhase.PHASE_2:
			return "Phase 2"
		BossPhase.PHASE_3:
			return "Phase 3"
		_:
			return "Unknown"

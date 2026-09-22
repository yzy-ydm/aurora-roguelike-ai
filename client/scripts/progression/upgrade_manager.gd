## 升级管理器 (Phase 12)
##
## 管理玩家升级、经验值、强化选择
## 负责生成随机强化选项并应用到玩家

extends Node

## ==================== 经验值配置 ====================

## 基础升级所需经验
const BASE_EXP_REQUIRE: int = 100

## 每级经验增长系数
const EXP_GROWTH_RATE: float = 1.5

## 最大等级
const MAX_LEVEL: int = 50

## ==================== 状态 ====================

## 已应用的强化列表
var _applied_upgrades: Array[UpgradeData] = []

## 可用强化池
var _upgrade_pool: Array[UpgradeData] = []

## ==================== 引用 ====================

## AI内容服务引用
var _ai_content_service: Node = null

## 玩家引用
var _player: CharacterBody2D = null

## ==================== 信号 ====================

## 获得经验
signal exp_gained(amount: int, current_exp: int, exp_to_next: int)

## 升级
signal level_up(new_level: int)

## 需要选择强化
signal upgrade_selection_required(upgrade_options: Array[UpgradeData])

## 强化已应用
signal upgrade_applied(upgrade: UpgradeData)


## ==================== 初始化 ====================

func _ready() -> void:
	_init_default_upgrade_pool()


## 设置AI内容服务
func set_ai_content_service(service: Node) -> void:
	_ai_content_service = service


## 设置玩家引用
func set_player(player: CharacterBody2D) -> void:
	_player = player


## 初始化默认强化池
func _init_default_upgrade_pool() -> void:
	# 攻击强化
	_upgrade_pool.append(_create_upgrade("attack_boost_1", "攻击强化I", "攻击力 +5", {"attack": 5}, {}, UpgradeData.UpgradeRarity.COMMON))
	_upgrade_pool.append(_create_upgrade("attack_boost_2", "攻击强化II", "攻击力 +10", {"attack": 10}, {}, UpgradeData.UpgradeRarity.UNCOMMON))
	_upgrade_pool.append(_create_upgrade("attack_boost_3", "攻击强化III", "攻击力 +15", {"attack": 15}, {}, UpgradeData.UpgradeRarity.RARE))

	# 生命强化
	_upgrade_pool.append(_create_upgrade("health_boost_1", "生命强化I", "最大生命 +20", {"max_health": 20}, {}, UpgradeData.UpgradeRarity.COMMON))
	_upgrade_pool.append(_create_upgrade("health_boost_2", "生命强化II", "最大生命 +40", {"max_health": 40}, {}, UpgradeData.UpgradeRarity.UNCOMMON))
	_upgrade_pool.append(_create_upgrade("health_boost_3", "生命强化III", "最大生命 +60", {"max_health": 60}, {}, UpgradeData.UpgradeRarity.RARE))

	# 速度强化
	_upgrade_pool.append(_create_upgrade("speed_boost_1", "速度强化I", "移动速度 +10%", {}, {"move_speed": 0.10}, UpgradeData.UpgradeRarity.COMMON))
	_upgrade_pool.append(_create_upgrade("speed_boost_2", "速度强化II", "移动速度 +20%", {}, {"move_speed": 0.20}, UpgradeData.UpgradeRarity.UNCOMMON))

	# 暴击强化
	_upgrade_pool.append(_create_upgrade("crit_boost_1", "暴击强化I", "暴击率 +5%", {}, {"crit_rate": 0.05}, UpgradeData.UpgradeRarity.UNCOMMON))
	_upgrade_pool.append(_create_upgrade("crit_boost_2", "暴击强化II", "暴击率 +10%", {}, {"crit_rate": 0.10}, UpgradeData.UpgradeRarity.RARE))
	_upgrade_pool.append(_create_upgrade("crit_damage_boost", "暴击伤害强化", "暴击伤害 +30%", {}, {"crit_damage": 0.30}, UpgradeData.UpgradeRarity.RARE))

	# 防御强化
	_upgrade_pool.append(_create_upgrade("defense_boost_1", "防御强化I", "防御力 +5", {"defense": 5}, {}, UpgradeData.UpgradeRarity.COMMON))
	_upgrade_pool.append(_create_upgrade("defense_boost_2", "防御强化II", "防御力 +10", {"defense": 10}, {}, UpgradeData.UpgradeRarity.UNCOMMON))

	# 特殊强化
	_upgrade_pool.append(_create_upgrade("heal_on_kill", "嗜血", "击杀回复 5 生命", {"heal_on_kill": 5}, {}, UpgradeData.UpgradeRarity.RARE))
	_upgrade_pool.append(_create_upgrade("exp_boost", "经验增幅", "经验获取 +25%", {}, {"exp_rate": 0.25}, UpgradeData.UpgradeRarity.UNCOMMON))

	# 武器升级 (Phase 9.3.2)
	_upgrade_pool.append(_create_weapon_upgrade("weapon_upgrade_1", "武器强化I", "武器等级 +1 (伤害提升)", 1, UpgradeData.UpgradeRarity.COMMON))
	_upgrade_pool.append(_create_weapon_upgrade("weapon_upgrade_2", "武器强化II", "武器等级 +2 (伤害大幅提升)", 2, UpgradeData.UpgradeRarity.UNCOMMON))
	_upgrade_pool.append(_create_weapon_upgrade("weapon_upgrade_3", "武器强化III", "武器等级 +3 (伤害巨幅提升)", 3, UpgradeData.UpgradeRarity.RARE))


## 创建强化数据
func _create_upgrade(id: String, name: String, desc: String, mods: Dictionary, pct_mods: Dictionary, rarity: UpgradeData.UpgradeRarity) -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = id
	upgrade.name = name
	upgrade.description = desc
	upgrade.type = UpgradeData.UpgradeType.STAT_BOOST
	upgrade.rarity = rarity
	upgrade.modifiers = mods
	upgrade.percent_modifiers = pct_mods
	return upgrade


## 创建武器升级数据 (Phase 9.3.2)
func _create_weapon_upgrade(id: String, name: String, desc: String, level_amount: int, rarity: UpgradeData.UpgradeRarity) -> UpgradeData:
	var upgrade = UpgradeData.new()
	upgrade.id = id
	upgrade.name = name
	upgrade.description = desc
	upgrade.type = UpgradeData.UpgradeType.WEAPON_MOD
	upgrade.rarity = rarity
	upgrade.modifiers = {"weapon_upgrade": level_amount}
	return upgrade


## ==================== 经验值系统 ====================

## 添加经验值 (Phase 9.4.2: 委托PlayerStats)
func add_experience(amount: int) -> void:
	if not _player:
		print("[UpgradeManager] No player reference")
		return

	var s = _player.get_stats()
	var old_level = s.level
	var old_exp = s.experience

	# Phase 24: 记录升级次数（可能连续升级）
	var level_before = s.level
	var leveled = s.gain_exp(amount)
	var level_after = s.level

	# 同步回_player_data
	_player._player_data = s.to_dict()

	print("[UpgradeManager] Gained EXP (", s.experience, "/", s.experience_to_next, ")")
	exp_gained.emit(amount, s.experience, s.experience_to_next)

	# Phase 24: 处理所有升级（包括连续升级）
	if leveled:
		var levels_gained = level_after - level_before
		print("[UpgradeManager] Level Up! ", level_before, " -> ", level_after, " (gained ", levels_gained, " levels)")
		# 发出最终等级信号
		level_up.emit(level_after)

		# 生成强化选项（只生成一次，基于最终等级）
		var options = await _generate_upgrade_options(3)
		upgrade_selection_required.emit(options)


## ==================== 强化系统 ====================

## 生成随机强化选项
func _generate_upgrade_options(count: int) -> Array[UpgradeData]:
	var options: Array[UpgradeData] = []
	var available = _upgrade_pool.duplicate()

	# 获取当前等级 (Phase 9.4.2: 从PlayerStats读取)
	var current_level = get_current_level()

	# 尝试从AI获取强化
	if _ai_content_service and _ai_content_service.has_method("generate_upgrade_options"):
		var ai_options = await _ai_content_service.generate_upgrade_options(
			current_level,
			_get_player_stats_dict()
		)
		if ai_options.size() > 0:
			for ai_option in ai_options:
				var upgrade = UpgradeData.from_dict(ai_option)
				if upgrade.id != "":
					options.append(upgrade)

	# 如果AI没有返回足够的选项，从本地池补充
	if options.size() < count:
		available.shuffle()
		for upgrade in available:
			if options.size() >= count:
				break
			# 检查是否已存在
			var exists = false
			for existing in options:
				if existing.id == upgrade.id:
					exists = true
					break
			if not exists:
				options.append(upgrade)

	# 确保返回指定数量
	while options.size() < count and available.size() > 0:
		var random_upgrade = available[randi() % available.size()]
		options.append(random_upgrade)
		available.erase(random_upgrade)

	return options.slice(0, count)


## 应用强化选择
func apply_upgrade(upgrade: UpgradeData) -> void:
	if not upgrade or not _player:
		return

	_applied_upgrades.append(upgrade)

	# 应用固定属性修改
	for key in upgrade.modifiers:
		var value = upgrade.modifiers[key]
		_apply_stat_modification(key, value)

	# 应用百分比修改 (存储供后续计算)
	for key in upgrade.percent_modifiers:
		var value = upgrade.percent_modifiers[key]
		_apply_percent_modification(key, value)

	print("[UpgradeManager] Applied upgrade: ", upgrade.name)
	upgrade_applied.emit(upgrade)


## 应用属性修改 (Phase 9.4.1: 通过PlayerStats)
func _apply_stat_modification(stat: String, value: int) -> void:
	match stat:
		"attack":
			_player.add_attack(value)
		"max_health":
			_player.add_max_health(value)
		"defense":
			# Phase 9.4.1: 通过PlayerStats修改
			var s = _player.get_stats()
			s.add_defense(value)
		"heal_on_kill":
			# Phase 9.4.1: 通过PlayerStats修改
			var s = _player.get_stats()
			s.heal_on_kill += value
		"weapon_upgrade":
			# 武器升级 (Phase 9.3.2)
			for i in range(value):
				if _player.has_method("upgrade_weapon"):
					_player.upgrade_weapon()


## 应用百分比修改 (Phase 9.4.1: 通过PlayerStats)
func _apply_percent_modification(stat: String, value: float) -> void:
	var s = _player.get_stats()
	match stat:
		"crit_rate":
			s.add_crit_rate_bonus(value)
		"crit_damage":
			s.add_crit_damage_bonus(value)
		"move_speed":
			s.add_move_speed_bonus(value)
		"exp_rate":
			s.exp_rate_bonus += value
		_:
			# 兜底: 存储到PlayerStats
			var key = stat + "_bonus"
			if s.to_dict().has(key):
				# 已被上面处理
				pass


## ==================== 查询接口 ====================

## 获取当前等级 (Phase 9.4.2: 从PlayerStats读取)
func get_current_level() -> int:
	if _player:
		return _player.get_stats().level
	return 1


## 获取当前经验值 (Phase 9.4.2: 从PlayerStats读取)
func get_current_exp() -> int:
	if _player:
		return _player.get_stats().experience
	return 0


## 获取升级所需经验 (Phase 9.4.2: 从PlayerStats读取)
func get_exp_to_next_level() -> int:
	if _player:
		return _player.get_stats().experience_to_next
	return 100


## 获取经验百分比 (Phase 9.4.2: 从PlayerStats读取)
func get_exp_percent() -> float:
	if _player:
		return _player.get_stats().get_exp_percent()
	return 0.0


## 获取已应用的强化
func get_applied_upgrades() -> Array[UpgradeData]:
	return _applied_upgrades


## 获取玩家属性 (Phase 9.4.1: 通过PlayerStats)
func _get_player_stat(stat: String, default_value: float) -> float:
	if not _player:
		return default_value
	var s = _player.get_stats()
	var data = s.to_dict()
	return data.get(stat, default_value)


## 获取玩家属性字典 (Phase 9.4.1: 通过PlayerStats)
func _get_player_stats_dict() -> Dictionary:
	if _player:
		return _player.get_player_data()
	return {}


## 设置等级和经验 (Phase 9.4.2: 更新PlayerStats)
func set_level_and_exp(level: int, exp: int) -> void:
	if _player:
		var s = _player.get_stats()
		s.level = level
		s.experience = exp
		s.experience_to_next = _calculate_exp_requirement(level)
		# 同步回_player_data
		_player._player_data = s.to_dict()
		print("[UpgradeManager] Restored level ", level, " EXP ", exp)


## 计算升级所需经验 (Phase 9.4.2: 静态工具方法)
func _calculate_exp_requirement(level: int) -> int:
	return int(BASE_EXP_REQUIRE * pow(EXP_GROWTH_RATE, level - 1))

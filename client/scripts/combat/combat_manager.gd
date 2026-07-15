## 战斗管理器 (Phase 12)
##
## 管理战斗生命周期
## 从RoomManager中剥离战斗职责
##
## 职责:
## - 战斗状态机
## - 怪物统计
## - 清怪检测
## - 房间完成事件
## - 奖励触发
## - Boss战管理

extends Node

## ==================== 战斗状态 ====================

enum CombatState {
	IDLE,       # 空闲(非战斗房间)
	ENTERING,   # 进入战斗房间
	COMBAT,     # 战斗中
	CLEARED,    # 已清除
	REWARD,     # 奖励阶段
	BOSS        # Boss战
}

## 当前战斗状态
var _state: CombatState = CombatState.IDLE

## 当前房间怪物总数
var _total_monsters: int = 0

## 已死亡怪物数
var _dead_monsters: int = 0

## 当前房间内容
var _current_content: RoomContentData = null

## 是否为Boss战
var _is_boss_fight: bool = false

## Boss数据
var _boss_data: BossData = null

## ==================== 引用 ====================

## RoomSpawner引用
var _room_spawner: Node = null

## FloorManager引用
var _floor_manager: Node = null

## ==================== 信号 ====================

## 战斗状态变化
signal combat_state_changed(new_state: CombatState)

## 战斗开始
signal combat_started(monster_count: int)

## 怪物死亡(带统计)
signal monster_killed(dead_count: int, total_count: int)

## 战斗结束(所有怪物死亡)
signal combat_cleared()

## 房间完成(奖励阶段结束)
signal room_completed()

## 战斗进度变化(用于UI显示)
signal combat_progress_changed(current_kills: int, total_monsters: int)

## Boss战开始
signal boss_fight_started(boss_data: BossData)

## Boss被击败
signal boss_defeated()


## ==================== 初始化 ====================

func set_room_spawner(spawner: Node) -> void:
	_room_spawner = spawner
	if _room_spawner:
		_room_spawner.all_monsters_dead.connect(_on_all_monsters_dead)
		_room_spawner.monster_died.connect(_on_monster_died)
		print("[CombatManager] Connected to RoomSpawner")


func set_floor_manager(fm: Node) -> void:
	_floor_manager = fm


## ==================== 战斗流程 ====================

## 开始战斗
func start_combat(content: RoomContentData) -> void:
	if not content or content.monster_count <= 0:
		print("[CombatManager] No monsters, skipping combat")
		_set_state(CombatState.IDLE)
		return

	_total_monsters = content.monster_count
	_dead_monsters = 0
	_current_content = content

	_set_state(CombatState.ENTERING)
	print("[CombatManager] Starting combat with ", _total_monsters, " monsters")

	# 延迟切换到战斗状态
	await get_tree().create_timer(0.1).timeout
	_set_state(CombatState.COMBAT)
	combat_started.emit(_total_monsters)
	# Phase 9.3: 通知HUD初始战斗进度(0/N)
	combat_progress_changed.emit(0, _total_monsters)


## 怪物死亡回调(由RoomSpawner调用)
func on_monster_died(entity: MonsterEntity) -> void:
	_dead_monsters += 1
	print("[CombatManager] Monster died: ", _dead_monsters, "/", _total_monsters)
	monster_killed.emit(_dead_monsters, _total_monsters)
	combat_progress_changed.emit(_dead_monsters, _total_monsters)


## 所有怪物死亡回调(由RoomSpawner信号触发)
func _on_all_monsters_dead() -> void:
	print("[CombatManager] All monsters dead!")
	_set_state(CombatState.CLEARED)

	# 标记当前房间完成
	if _floor_manager and _floor_manager._current_floor:
		_floor_manager._current_floor.complete_current_room()

	# 延迟发送cleared信号，避免在物理回调链中触发奖励生成
	# 导致"Can't change this state while flushing queries"错误
	call_deferred("_emit_combat_cleared")


## deferred回调：发送战斗清除信号
func _emit_combat_cleared() -> void:
	combat_cleared.emit()

	# 延迟进入奖励阶段
	await get_tree().create_timer(1.0).timeout
	_set_state(CombatState.REWARD)


## 单个怪物死亡回调(由RoomSpawner信号触发)
func _on_monster_died(entity: MonsterEntity) -> void:
	on_monster_died(entity)


## 完成奖励阶段
func complete_reward_phase() -> void:
	print("[CombatManager] Reward phase completed")
	_set_state(CombatState.IDLE)
	room_completed.emit()


## 重置(进入新房间时调用)
func reset() -> void:
	_total_monsters = 0
	_dead_monsters = 0
	_current_content = null
	_is_boss_fight = false
	_boss_data = null
	_set_state(CombatState.IDLE)
	# 通知HUD清空战斗进度，避免残留上一个房间的怪物数量
	combat_progress_changed.emit(0, 0)


## ==================== Boss战管理 ====================

## 开始Boss战
func start_boss_fight(boss_data: BossData) -> void:
	if not boss_data:
		print("[CombatManager] No boss data provided")
		return

	_is_boss_fight = true
	_boss_data = boss_data
	_total_monsters = 1  # Boss算作1个怪物
	_dead_monsters = 0

	_set_state(CombatState.BOSS)
	print("[CombatManager] Starting boss fight: ", boss_data.name)
	boss_fight_started.emit(boss_data)


## Boss被击败
func on_boss_defeated() -> void:
	if not _is_boss_fight:
		return

	print("[CombatManager] Boss defeated!")
	_is_boss_fight = false
	_set_state(CombatState.CLEARED)
	boss_defeated.emit()
	combat_cleared.emit()

	# 标记当前房间完成
	if _floor_manager and _floor_manager._current_floor:
		_floor_manager._current_floor.complete_current_room()

	# 延迟进入奖励阶段
	await get_tree().create_timer(1.0).timeout
	_set_state(CombatState.REWARD)


## 是否为Boss战
func is_boss_fight() -> bool:
	return _is_boss_fight


## 获取Boss数据
func get_boss_data() -> BossData:
	return _boss_data


## ==================== 状态管理 ====================

func _set_state(new_state: CombatState) -> void:
	if _state == new_state:
		return
	_state = new_state
	combat_state_changed.emit(new_state)

	match new_state:
		CombatState.IDLE:
			print("[CombatManager] State: IDLE")
		CombatState.ENTERING:
			print("[CombatManager] State: ENTERING")
		CombatState.COMBAT:
			print("[CombatManager] State: COMBAT")
		CombatState.CLEARED:
			print("[CombatManager] State: CLEARED")
		CombatState.REWARD:
			print("[CombatManager] State: REWARD")


## ==================== 查询接口 ====================

func get_state() -> CombatState:
	return _state


func is_in_combat() -> bool:
	return _state == CombatState.COMBAT or _state == CombatState.ENTERING


func is_cleared() -> bool:
	return _state == CombatState.CLEARED or _state == CombatState.REWARD


func is_idle() -> bool:
	return _state == CombatState.IDLE


func get_dead_count() -> int:
	return _dead_monsters


func get_total_count() -> int:
	return _total_monsters


func get_alive_count() -> int:
	return _total_monsters - _dead_monsters


func get_current_content() -> RoomContentData:
	return _current_content

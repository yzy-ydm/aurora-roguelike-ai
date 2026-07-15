## 武器系统
##
## 负责发射子弹、控制攻击间隔
## 管理武器属性（伤害、射速）
## 支持WeaponData数据驱动

extends Node

## 武器数据
var _weapon_data: WeaponData = null

## 武器实例（Phase 9.3.1: 支持等级成长）
var _weapon_instance: WeaponInstance = null

## 武器属性（从WeaponData读取）
var weapon_damage: int = 10
var attack_speed: float = 0.3  # 攻击间隔（秒）
var bullet_speed: float = 500.0
var bullet_count: int = 1      # 每次发射子弹数
var spread_angle: float = 0.0  # 散射角度

## 攻击冷却
var _cooldown_remaining: float = 0.0
var _can_attack: bool = true

## 子弹场景
var _bullet_scene: PackedScene = null

## 子弹容器
var _bullet_container: Node2D = null

## 所属节点（玩家）
var _owner: Node2D = null

## 信号
signal weapon_fired()
signal weapon_ready()


## 初始化
func _ready() -> void:
	# 加载子弹场景
	_bullet_scene = load("res://scenes/combat/bullet.tscn")

	if not _bullet_scene:
		print("[Weapon] Warning: Bullet scene not found")


## 每帧更新
func _process(delta: float) -> void:
	# 更新冷却
	if _cooldown_remaining > 0:
		_cooldown_remaining -= delta
		if _cooldown_remaining <= 0:
			_can_attack = true
			weapon_ready.emit()


## 设置所属节点
func set_owner_node(owner: Node2D) -> void:
	_owner = owner


## 设置子弹容器
func set_bullet_container(container: Node2D) -> void:
	_bullet_container = container


## 设置武器数据
func set_weapon_data(data: WeaponData) -> void:
	_weapon_data = data
	_apply_weapon_data()


## 设置武器实例（Phase 9.3.1: 支持等级成长）
func set_weapon_instance(instance: WeaponInstance) -> void:
	_weapon_instance = instance
	if instance:
		_weapon_data = instance.get_weapon_data()
		_apply_weapon_data()
		# 使用实例的当前伤害
		weapon_damage = instance.get_damage()
		print("[Weapon] WeaponInstance set: ", instance.get_name(), " Lv", instance.get_level(), " damage:", weapon_damage)


## 获取武器实例
func get_weapon_instance() -> WeaponInstance:
	return _weapon_instance


## 应用武器数据
func _apply_weapon_data() -> void:
	if not _weapon_data:
		return

	weapon_damage = _weapon_data.damage
	attack_speed = _weapon_data.fire_rate
	bullet_speed = _weapon_data.bullet_speed
	bullet_count = _weapon_data.bullet_count

	print("[Weapon] Loaded weapon data: ", _weapon_data.name, " damage: ", weapon_damage)


## 设置武器属性（兼容旧接口）
func setup(damage: int, speed: float, atk_speed: float) -> void:
	weapon_damage = damage
	bullet_speed = speed
	attack_speed = atk_speed


## 尝试攻击
func try_attack(attack_direction: Vector2) -> bool:
	if not _can_attack:
		return false

	if not _bullet_scene:
		print("[Weapon] Error: Bullet scene not loaded")
		return false

	# 发射子弹
	_fire(attack_direction)

	# 设置冷却
	_can_attack = false
	_cooldown_remaining = attack_speed

	return true


## 发射子弹
func _fire(direction: Vector2) -> void:
	if not _bullet_container:
		print("[Weapon] Error: BulletContainer is null, cannot fire")
		return

	# 计算暴击率(暴击判定在子弹创建时完成)
	var crit_rate = 0.1  # 10%暴击率
	var is_critical = randf() < crit_rate

	# 获取当前伤害（优先从WeaponInstance获取，支持等级成长）
	var current_damage = weapon_damage
	if _weapon_instance:
		current_damage = _weapon_instance.get_damage()

	# 创建子弹 - 只传递武器伤害，不计算总伤害
	# 伤害计算由DamageSystem在命中时完成
	var bullet = _bullet_scene.instantiate()
	if not bullet:
		print("[Weapon] Error: Failed to instantiate bullet")
		return

	# 子弹出生位置偏移，避免与玩家碰撞体重叠
	var spawn_offset = direction * 20.0
	var spawn_pos = (_owner.global_position if _owner else Vector2.ZERO) + spawn_offset
	bullet.global_position = spawn_pos
	bullet.setup(current_damage, bullet_speed, direction, is_critical, _owner)

	_bullet_container.add_child(bullet)

	weapon_fired.emit()
	print("[Weapon] Fired bullet, damage:", current_damage, " crit:", is_critical, " pos:", spawn_pos, " dir:", direction)


## 是否可以攻击
func can_attack() -> bool:
	return _can_attack


## 获取剩余冷却时间
func get_cooldown_remaining() -> float:
	return _cooldown_remaining


## 获取冷却百分比（0-1）
func get_cooldown_percent() -> float:
	if attack_speed <= 0:
		return 0.0
	return _cooldown_remaining / attack_speed

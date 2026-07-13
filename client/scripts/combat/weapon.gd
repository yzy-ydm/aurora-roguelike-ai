## 武器系统
##
## 负责发射子弹、控制攻击间隔
## 管理武器属性（伤害、射速）
## 支持WeaponData数据驱动

extends Node

## 武器数据
var _weapon_data: WeaponData = null

## 武器属性（从WeaponData读取）
var weapon_damage: int = 10
var attack_speed: float = 0.3  # 攻击间隔（秒）
var bullet_speed: float = 400.0
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
		# 如果没有指定容器，添加到父节点
		_bullet_container = get_parent()

	# 计算玩家攻击力
	var player_attack = 10
	if _owner and _owner.has_method("get_attack"):
		player_attack = _owner.get_attack()

	# 总伤害 = 武器伤害 + 玩家攻击力
	var total_damage = weapon_damage + player_attack

	# 计算暴击率
	var crit_rate = 0.1  # 10%暴击率
	var is_critical = randf() < crit_rate

	# 创建子弹
	var bullet = _bullet_scene.instantiate()
	if bullet:
		bullet.position = _owner.position if _owner else Vector2.ZERO
		bullet.setup(total_damage, bullet_speed, direction, is_critical, _owner)

		_bullet_container.add_child(bullet)

		weapon_fired.emit()
		print("[Weapon] Fired bullet, damage: ", total_damage, " critical: ", is_critical)


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

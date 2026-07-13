## 玩家控制器脚本
##
## 负责玩家节点的输入处理、移动控制和数据显示
## 使用CharacterBody2D实现标准移动和碰撞

extends CharacterBody2D

## 移动速度（像素/秒）
const MOVE_SPEED: float = 200.0

## 玩家数据
var _player_data: Dictionary = {}

## 武器系统
var _weapon: Node = null

## 子弹容器
var _bullet_container: Node2D = null

## 节点引用
@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	# 初始化玩家显示
	_setup_player_display()

	# 初始化武器系统
	_setup_weapon()


## 物理帧处理（每帧调用）
func _physics_process(_delta: float) -> void:
	# 获取输入方向
	var input_direction = _get_input_direction()

	# 计算速度
	velocity = input_direction * MOVE_SPEED

	# 移动并处理碰撞
	move_and_slide()


## 输入处理
func _input(event: InputEvent) -> void:
	# 鼠标左键攻击
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_attack()


## 获取输入方向
func _get_input_direction() -> Vector2:
	var direction = Vector2.ZERO

	# 水平方向
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1

	# 垂直方向
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1

	# 归一化防止对角线移动速度过快
	if direction.length() > 0:
		direction = direction.normalized()

	return direction


## 设置玩家显示
func _setup_player_display() -> void:
	# 创建占位矩形纹理
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.6, 1.0, 1.0))
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture

	# 创建碰撞形状
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	collision_shape.shape = shape


## 设置武器系统
func _setup_weapon() -> void:
	# 创建武器节点
	_weapon = Node.new()
	_weapon.name = "Weapon"
	_weapon.set_script(load("res://scripts/combat/weapon.gd"))
	add_child(_weapon)

	# 设置武器所有者
	_weapon.set_owner_node(self)

	# 加载武器数据
	_load_weapon_data()

	# 创建子弹容器
	_bullet_container = Node2D.new()
	_bullet_container.name = "Bullets"

	# 延迟添加到场景树
	call_deferred("_add_bullet_container")


## 加载武器数据
func _load_weapon_data() -> void:
	# 从ResourceService获取武器数据
	var weapons = ResourceService.get_weapons()

	if weapons.size() > 0:
		# 使用第一个武器
		var weapon_data = weapons[0]
		_weapon.set_weapon_data(weapon_data)
		print("[Player] Loaded weapon: ", weapon_data.name)
	else:
		# 创建默认武器数据
		var default_weapon = _create_default_weapon_data()
		_weapon.set_weapon_data(default_weapon)
		print("[Player] Using default weapon")


## 创建默认武器数据
func _create_default_weapon_data() -> WeaponData:
	var weapon_data = WeaponData.new()
	weapon_data.id = 0
	weapon_data.name = "basic_gun"
	weapon_data.description = "基础手枪"
	weapon_data.type = "gun"
	weapon_data.rarity = "common"
	weapon_data.damage = 20
	weapon_data.fire_rate = 0.2  # 5发/秒
	weapon_data.bullet_speed = 500.0
	weapon_data.bullet_count = 1
	weapon_data.range = 500.0
	return weapon_data


## 添加子弹容器到场景
func _add_bullet_container() -> void:
	var game_world = get_parent()
	if game_world:
		game_world.add_child(_bullet_container)
		_weapon.set_bullet_container(_bullet_container)


## 尝试攻击
func _try_attack() -> void:
	if not _weapon:
		return

	# 计算攻击方向（朝向鼠标位置）
	var mouse_pos = get_global_mouse_position()
	var attack_direction = (mouse_pos - position).normalized()

	# 尝试发射
	_weapon.try_attack(attack_direction)


## 获取玩家攻击力
func get_attack() -> int:
	return _player_data.get("attack", 10)


## 设置玩家数据
func set_player_data(data: Dictionary) -> void:
	_player_data = data
	_update_display()


## 获取玩家数据
func get_player_data() -> Dictionary:
	return _player_data


## 更新显示
func _update_display() -> void:
	# 未来可以根据玩家数据更新外观
	# 当前阶段只保存数据
	pass


## 获取玩家昵称
func get_nickname() -> String:
	return _player_data.get("nickname", "未知玩家")


## 获取玩家等级
func get_level() -> int:
	return _player_data.get("level", 1)


## 获取玩家位置（避免与Node2D内置方法冲突）
func get_player_position() -> Vector2:
	return position


## 设置玩家位置（避免与Node2D内置方法冲突）
func set_player_position(new_position: Vector2) -> void:
	position = new_position


## 受到伤害（供怪物调用）
func take_damage(damage: int) -> void:
	print("[Player] Took ", damage, " damage!")

	# 从玩家数据中获取当前生命值
	var current_health = _player_data.get("current_health", 100)
	current_health -= damage

	if current_health < 0:
		current_health = 0

	# 更新玩家数据
	_player_data["current_health"] = current_health

	# 更新显示
	_update_display()

	# 检查是否死亡
	if current_health <= 0:
		print("[Player] Player died!")
		# TODO: 处理玩家死亡

	print("[Player] Current health: ", current_health)


## 添加金币
func add_gold(amount: int) -> void:
	var gold = _player_data.get("gold", 0)
	gold += amount
	_player_data["gold"] = gold
	print("[Player] Gold: ", gold)


## 添加攻击力
func add_attack(amount: int) -> void:
	var attack = _player_data.get("attack", 10)
	attack += amount
	_player_data["attack"] = attack
	print("[Player] Attack: ", attack)


## 添加最大生命值
func add_max_health(amount: int) -> void:
	var max_health = _player_data.get("max_health", 100)
	var current_health = _player_data.get("current_health", 100)
	max_health += amount
	current_health += amount
	_player_data["max_health"] = max_health
	_player_data["current_health"] = current_health
	print("[Player] Max Health: ", max_health)


## 治疗
func heal(amount: int) -> void:
	var current_health = _player_data.get("current_health", 100)
	var max_health = _player_data.get("max_health", 100)
	current_health = min(current_health + amount, max_health)
	_player_data["current_health"] = current_health
	print("[Player] Health: ", current_health)

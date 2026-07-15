extends Node2D

var damage_value: int = 0

## 生命周期配置
var life_time: float = 0.8
var move_speed: float = 40.0
var _elapsed_time: float = 0.0

@onready var label: Label = find_child("Label", true, false)


func _ready():
	print("[DamageNumber Ready]")

	if label:
		print("[DamageNumber] Label Found")
		label.visible = true
		label.modulate = Color.WHITE
		label.scale = Vector2(2, 2)
	else:
		print("[DamageNumber ERROR] Label Missing")


func setup(damage: int):
	damage_value = damage
	print("[DamageNumber Setup] damage=", damage)

	if label == null:
		label = find_child("Label", true, false)

	if label:
		label.text = str(damage)
		label.visible = true
		label.modulate = Color.WHITE
		label.scale = Vector2(2, 2)

		print("[DamageNumber Text Set] text=", label.text, " visible=", label.visible, " position=", global_position)
	else:
		print("[DamageNumber ERROR] Cannot find Label")

	# 启动生命周期
	_elapsed_time = 0.0
	print("[DamageNumber] Start Animation")


func _process(delta: float):
	# 向上漂浮
	global_position.y -= move_speed * delta

	# 更新计时
	_elapsed_time += delta

	# 计算剩余时间比例
	var remaining = 1.0 - (_elapsed_time / life_time)
	remaining = max(0.0, remaining)

	# 修改透明度
	if label:
		label.modulate.a = remaining

	# 超时销毁
	if _elapsed_time >= life_time:
		print("[DamageNumber] Destroyed")
		queue_free()

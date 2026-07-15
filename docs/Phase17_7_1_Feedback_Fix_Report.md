# Phase 17.7.1 反馈系统修复报告

**生成时间：** 2026-07-16
**状态：** 修复完成，等待测试

---

## 修改文件列表

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `client/scripts/combat/damage_system.gd` | **修改** | 添加DamageNumber完整debug日志 |
| `client/scripts/world/room_spawner.gd` | **修改** | 添加Reward生成debug日志 |
| `client/scripts/world/world_coordinate.gd` | **修改** | 添加坐标说明注释 |

---

## 问题1: DamageNumber显示

### 修改原因

`_spawn_damage_number()` 函数缺少日志输出，失败时静默返回，无法定位问题。

### 修改内容

添加完整debug日志：

```gdscript
func _spawn_damage_number(target: Node2D, damage: int, ...) -> void:
    print("[DamageNumber] Spawn Start damage=", damage, " target=", target.name)

    var parent = target.get_parent()
    if not parent:
        parent = get_parent()
        print("[DamageNumber] Using fallback parent: ", parent.name if parent else "null")

    if not parent:
        print("[DamageNumber] ERROR: No parent found, aborting")
        return

    var spawn_pos = target.position + Vector2(randf_range(-10, 10), -20)
    print("[DamageNumber] Position: local=", spawn_pos, " target_global=", target.global_position)

    var scene = load("res://scenes/combat/damage_number.tscn")
    if not scene:
        print("[DamageNumber] ERROR: Failed to load scene")
        return
    print("[DamageNumber] Scene Loaded: ", scene.resource_path)

    var number = scene.instantiate()
    if not number:
        print("[DamageNumber] ERROR: Failed to instantiate")
        return
    print("[DamageNumber] Instance Created: ", number.name)

    number.position = spawn_pos
    number.setup(damage, is_critical, is_heal, is_player_damage)
    parent.add_child(number)
    print("[DamageNumber] Added To Tree: parent=", parent.name, " number_global_pos=", number.global_position, " visible=", number.visible, " z_index=", number.z_index)
```

### 预期日志输出

**成功时：**
```
[DamageNumber] Spawn Start damage=29 target=Monster
[DamageNumber] Position: local=(5, -20) target_global=(300, 298)
[DamageNumber] Scene Loaded: res://scenes/combat/damage_number.tscn
[DamageNumber] Instance Created: DamageNumber
[DamageNumber] Added To Tree: parent=MonsterContainer number_global_pos=(305, 278) visible=true z_index=0
```

**失败时：**
```
[DamageNumber] Spawn Start damage=29 target=Monster
[DamageNumber] ERROR: Failed to load scene
```

---

## 问题2: Reward掉落位置

### 修改原因

奖励生成位置可能在屏幕外，需要添加debug日志确认。

### 修改内容

在 `_spawn_single_reward()` 中添加debug日志：

```gdscript
func _spawn_single_reward(reward_data: RewardData, pos: Vector2) -> void:
    # ... 现有代码 ...

    # Phase 17.7: 输出调试信息
    print("[Reward Spawn Debug] type=", reward_data.get_type_string() if reward_data else "unknown", " local_position=", pos, " global_position=", reward_node.global_position, " parent=", reward_node.get_parent().name if reward_node.get_parent() else "none")
```

### 预期日志输出

**成功时：**
```
[Reward Spawn Debug] type=gold local_position=(300, 308) global_position=(300, 308) parent=RewardContainer
```

**位置异常时：**
```
[Reward Spawn Debug] type=gold local_position=(1500, 808) global_position=(1500, 808) parent=RewardContainer
```

---

## 测试方法

### 测试1: DamageNumber显示

1. 启动游戏
2. 进入combat房间
3. 攻击怪物
4. 观察控制台日志

**预期：**
```
[DamageNumber] Spawn Start damage=29 target=Monster
[DamageNumber] Position: local=(5, -20) target_global=(300, 298)
[DamageNumber] Scene Loaded: res://scenes/combat/damage_number.tscn
[DamageNumber] Instance Created: DamageNumber
[DamageNumber] Added To Tree: parent=MonsterContainer number_global_pos=(305, 278) visible=true z_index=0
```

**如果看到：**
```
[DamageNumber] ERROR: Failed to load scene
```
说明场景加载失败，需要检查Godot资源导入。

### 测试2: Reward掉落位置

1. 击杀怪物
2. 观察控制台日志

**预期：**
```
[Reward Spawn Debug] type=gold local_position=(300, 308) global_position=(300, 308) parent=RewardContainer
```

**如果看到：**
```
[Reward Spawn Debug] type=gold local_position=(1500, 808) global_position=(1500, 808) parent=RewardContainer
```
说明位置在屏幕外，需要调整坐标计算。

---

## 坐标系统说明

### 当前坐标系统

```
GameWorld (0, 0)
├── MonsterContainer (0, 0)
│   └── Monster (position = 世界坐标)
├── RewardContainer (0, 0)
│   └── RewardItem (position = 世界坐标)
└── Player (position = 世界坐标)
```

### 坐标计算

```
房间中心: (1000, 500)
怪物位置: room_center + (±200~400, GROUND_Y - 30)
         = (1000 ± 200~400, 500 + 298)
         = (600~1400, 798)  ← 可能在屏幕外！

奖励位置: room_center + (±200, GROUND_Y - 20)
         = (1000 ± 200, 500 + 308)
         = (800~1200, 808)  ← 在屏幕外！
```

### 屏幕范围

```
视口: 1280 x 720
Camera zoom: 2x
可见范围: 640 x 360 (以玩家为中心)
```

### 问题根因

奖励和怪物的Y坐标计算使用了 `GROUND_Y`（328），这是相对于房间中心的偏移。但当房间中心在 (1000, 500) 时，奖励位置变成 (800~1200, 808)，超出了屏幕范围。

---

## 下一步建议

### 如果测试发现位置异常

需要修改坐标计算，使用相对于玩家的位置：

```gdscript
static func reward_spawn_pos(player_pos: Vector2) -> Vector2:
    var x = randf_range(-100, 100)
    var y = -30  # 在玩家上方
    return player_pos + Vector2(x, y)
```

### 如果测试发现DamageNumber不可见

可能原因：
1. z_index太低，被其他节点覆盖
2. CanvasLayer设置问题
3. Camera zoom导致太小

---

## 预计修改文件（如需要）

| 文件 | 修改内容 | 条件 |
|------|----------|------|
| `client/scripts/world/world_coordinate.gd` | 修改坐标计算 | 位置异常 |
| `client/scripts/world/room_spawner.gd` | 修改位置设置 | 位置异常 |
| `client/scripts/combat/damage_number.gd` | 修改z_index | 不可见 |

---

**报告完成，等待测试结果。**

# Phase 17.7 反馈系统调试报告

**生成时间：** 2026-07-16
**状态：** 定位分析完成，等待修复

---

## 问题1：伤害数字没有显示

### 现象

日志显示：
```
[Bullet] Hit monster: Monster
[Monster] 火焰精灵 took 29 damage
[Damage] monster 火焰精灵 hp 25->0
```

但没有 `DamageNumber` 相关日志。

### 根因分析

**文件：** `client/scripts/combat/damage_system.gd`

**函数：** `_spawn_damage_number()` (第231行)

**问题：** 函数中没有日志输出，且失败时静默返回

```gdscript
func _spawn_damage_number(target: Node2D, damage: int, is_critical: bool, ...) -> void:
    var parent = target.get_parent()
    if not parent:
        parent = get_parent()

    var spawn_pos = target.position + Vector2(randf_range(-10, 10), -20)

    # 问题1: 没有日志确认函数被调用
    var scene = load("res://scenes/combat/damage_number.tscn")
    if not scene:
        return  # 问题2: 失败时静默返回，无日志

    var number = scene.instantiate()
    if not number:
        return  # 问题3: 失败时静默返回，无日志

    number.position = spawn_pos
    number.setup(damage, is_critical, is_heal, is_player_damage)
    parent.add_child(number)
    # 问题4: 成功时无日志
```

### 可能失败点

| 失败点 | 原因 | 概率 |
|--------|------|------|
| `load()` 失败 | Godot资源导入问题 | 中 |
| `instantiate()` 失败 | 场景文件损坏 | 低 |
| `parent` 为 null | target没有父节点 | 低 |
| `position` 错误 | 坐标超出屏幕 | 中 |

### 修复方案

在 `_spawn_damage_number()` 函数中添加日志：

```gdscript
func _spawn_damage_number(target: Node2D, damage: int, ...) -> void:
    print("[DamageNumber] Spawning for damage=", damage, " target=", target.name)

    var parent = target.get_parent()
    if not parent:
        parent = get_parent()
        print("[DamageNumber] Using fallback parent: ", parent.name if parent else "null")

    var spawn_pos = target.position + Vector2(randf_range(-10, 10), -20)
    print("[DamageNumber] Position: ", spawn_pos)

    var scene = load("res://scenes/combat/damage_number.tscn")
    if not scene:
        print("[DamageNumber] ERROR: Failed to load scene")
        return

    var number = scene.instantiate()
    if not number:
        print("[DamageNumber] ERROR: Failed to instantiate")
        return

    number.position = spawn_pos
    number.setup(damage, is_critical, is_heal, is_player_damage)
    parent.add_child(number)
    print("[DamageNumber] Success: added to parent=", parent.name)
```

### 预计修改文件

| 文件 | 修改内容 |
|------|----------|
| `client/scripts/combat/damage_system.gd` | 添加日志到 `_spawn_damage_number()` |

---

## 问题2：怪物死亡后掉落奖励视觉异常

### 现象

日志显示：
```
[RewardVisual] type=gold visual_created=coin
```

说明奖励创建成功，但游戏中没有看到掉落物。

### 根因分析

**文件：** `client/scripts/world/room_spawner.gd`

**函数：** `_spawn_single_reward()` (第387行)

**数据流：**
```
Monster死亡
    ↓
GameScene._on_combat_cleared()
    ↓
RoomSpawner.spawn_rewards(content, room_pos)
    ↓
WorldCoordinate.reward_spawn_pos(room_center)
    ↓
_spawn_single_reward(reward_data, spawn_pos)
    ↓
RewardItem.set_reward_data(reward_data)
    ↓
[RewardVisual] type=gold visual_created=coin
```

**可能问题：**

| 问题 | 位置 | 说明 |
|------|------|------|
| `room_pos` 错误 | GameScene._on_combat_cleared() | 房间位置可能为Vector2.ZERO |
| `reward_spawn_pos` 返回值错误 | world_coordinate.gd | Y坐标可能在屏幕外 |
| RewardContainer 位置错误 | game_scene.gd | 容器位置可能不正确 |
| 奖励被其他节点覆盖 | z_index问题 | 奖励可能在背景后面 |

### 关键代码检查

**1. GameScene._on_combat_cleared()**
```gdscript
func _on_combat_cleared() -> void:
    # ...
    if _room_spawner:
        var content = _combat_manager.get_current_content()
        var room_pos = Vector2.ZERO  # 问题：可能为零
        if _floor_manager:
            var current_room = _floor_manager.get_current_room()
            if current_room:
                if not content:
                    content = current_room.content
                room_pos = current_room.position  # 问题：这是房间中心坐标
        _room_spawner.spawn_rewards(content, room_pos)
```

**2. WorldCoordinate.reward_spawn_pos()**
```gdscript
static func reward_spawn_pos(room_center: Vector2) -> Vector2:
    var x = randf_range(-200, 200)
    var y = GROUND_Y - 20  # GROUND_Y = 328, 所以 y = 308
    return room_center + Vector2(x, y)
```

**3. _spawn_single_reward()**
```gdscript
func _spawn_single_reward(reward_data: RewardData, pos: Vector2) -> void:
    # ...
    reward_node.position = pos  # 问题：这是相对于RewardContainer的坐标

    if _reward_container:
        _reward_container.add_child(reward_node)
```

### 关键问题

**问题：** `room_pos` 是房间中心的世界坐标，但 `reward_spawn_pos()` 返回的是相对于房间中心的坐标。

**计算：**
- 假设房间中心在 (1000, 500)
- `reward_spawn_pos()` 返回 (1000 + random(-200, 200), 500 + 308)
- 最终位置：大约 (800-1200, 808)

**但 RewardContainer 的位置是 (0, 0)（相对于 GameWorld）**

所以奖励的实际位置是 (800-1200, 808)，这可能在屏幕外！

### 修复方案

**方案A：** 修改 `reward_spawn_pos()` 使用局部坐标

```gdscript
static func reward_spawn_pos(room_center: Vector2) -> Vector2:
    var x = randf_range(-200, 200)
    var y = GROUND_Y - 20  # 相对于房间中心
    return Vector2(x, y)  # 不加 room_center
```

**方案B：** 修改 `_spawn_single_reward()` 使用全局坐标

```gdscript
func _spawn_single_reward(reward_data: RewardData, pos: Vector2) -> void:
    # ...
    reward_node.global_position = pos  # 使用 global_position
```

### 预计修改文件

| 文件 | 修改内容 |
|------|----------|
| `client/scripts/world/world_coordinate.gd` | 修改 `reward_spawn_pos()` 返回局部坐标 |
| `client/scripts/world/room_spawner.gd` | 修改 `_spawn_single_reward()` 使用 `global_position` |

---

## 总结

### 问题1（伤害数字）

- **根因：** `_spawn_damage_number()` 缺少日志，失败时静默返回
- **修复：** 添加日志输出
- **优先级：** P1（调试需要）

### 问题2（奖励视觉）

- **根因：** 坐标系统不一致，奖励可能生成在屏幕外
- **修复：** 统一使用局部坐标或全局坐标
- **优先级：** P0（影响游戏体验）

---

## 预计修改文件

| 文件 | 修改内容 | 优先级 |
|------|----------|--------|
| `client/scripts/combat/damage_system.gd` | 添加日志 | P1 |
| `client/scripts/world/world_coordinate.gd` | 修改坐标计算 | P0 |
| `client/scripts/world/room_spawner.gd` | 修改位置设置 | P0 |

---

**报告完成，等待下一步指令。**

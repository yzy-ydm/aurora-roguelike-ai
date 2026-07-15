# Phase 17.7.2 Render Layer Fix Report

**生成时间：** 2026-07-16
**状态：** 修复完成，等待测试

---

## 修改文件列表

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `client/scenes/combat/damage_number.tscn` | **修改** | 设置z_index=100 |
| `client/scripts/combat/damage_system.gd` | **修改** | 使用EffectContainer，添加debug日志 |
| `client/scripts/drop/reward_item.gd` | **修改** | 设置z_index=50，添加debug日志 |

---

## 修改详情

### 1. DamageNumber z_index

**文件：** `client/scenes/combat/damage_number.tscn`

**修改：**
```gdscript
[node name="DamageNumber" type="Node2D"]
script = ExtResource("1")
z_index = 100  # 新增
```

### 2. DamageNumber parent容器

**文件：** `client/scripts/combat/damage_system.gd`

**修改：**
- 将DamageNumber添加到`EffectContainer`而不是`MonsterContainer`
- 使用`global_position`确保位置正确
- 添加`_get_effect_container()`函数

**关键代码：**
```gdscript
func _spawn_damage_number(target: Node2D, damage: int, ...) -> void:
    var parent = _get_effect_container()  # 使用EffectContainer
    var spawn_pos = target.global_position + Vector2(randf_range(-10, 10), -20)
    number.global_position = spawn_pos  # 使用global_position
    parent.add_child(number)

func _get_effect_container() -> Node:
    # 查找或创建EffectContainer
    var root = Engine.get_main_loop().root
    if root:
        var game_scene = root.get_node_or_null("GameScene")
        if game_scene:
            var game_world = game_scene.get_node_or_null("GameWorld")
            if game_world:
                var effect_container = game_world.get_node_or_null("EffectContainer")
                if not effect_container:
                    effect_container = Node2D.new()
                    effect_container.name = "EffectContainer"
                    game_world.add_child(effect_container)
                return effect_container
    return null
```

### 3. RewardItem z_index

**文件：** `client/scripts/drop/reward_item.gd`

**修改：**
```gdscript
func _ready() -> void:
    # ...
    z_index = 50  # 新增
    # ...
```

---

## 预期日志输出

### DamageNumber

```
[DamageNumber] Spawn Start damage=29 target=Monster
[DamageNumber] Position: global=(305, 278) target_global=(300, 298)
[DamageNumber] Scene Loaded: res://scenes/combat/damage_number.tscn
[DamageNumber] Instance Created: DamageNumber
[DamageNumber] Added To Tree: parent=EffectContainer global_pos=(305, 278) visible=true z_index=100 modulate=(1, 1, 1, 1)
```

### Reward

```
[RewardVisual] type=gold visual_created=coin
[Reward Debug] global_position=(300, 308) z_index=50 visible=true sprite_texture=... parent=RewardContainer
```

---

## 测试方法

### 测试1: DamageNumber显示

1. 启动游戏
2. 进入combat房间
3. 攻击怪物
4. 观察控制台日志和屏幕

**预期：**
- 控制台显示 `[DamageNumber] Added To Tree: parent=EffectContainer`
- 屏幕上显示伤害数字（白色，向上漂浮）

### 测试2: Reward显示

1. 击杀怪物
2. 观察控制台日志和屏幕

**预期：**
- 控制台显示 `[Reward Debug] global_position=... z_index=50 visible=true`
- 屏幕上显示奖励图标（根据类型不同）

---

## z_index层级说明

| 元素 | z_index | 说明 |
|------|---------|------|
| Background | -20 | 背景 |
| Platform | 5 | 平台 |
| Monster | 10 | 怪物 |
| Player | 20 | 玩家 |
| Bullet | 30 | 子弹 |
| Reward | 50 | 奖励 |
| DamageNumber | 100 | 伤害数字 |

---

## 可能的问题

### 如果DamageNumber仍然不可见

可能原因：
1. `EffectContainer`未正确创建
2. `global_position`计算错误
3. Camera zoom导致太小

### 如果Reward仍然不可见

可能原因：
1. 位置在屏幕外
2. sprite纹理未正确加载
3. z_index被其他节点覆盖

---

## 下一步

1. 运行游戏测试
2. 观察控制台日志
3. 确认DamageNumber和Reward是否显示
4. 如果仍有问题，根据日志进一步调试

---

**报告完成，等待测试结果。**

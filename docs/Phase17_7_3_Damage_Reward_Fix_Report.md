# Phase 17.7.3 DamageNumber & Reward Fix Report

**生成时间：** 2026-07-16
**状态：** 修复完成，等待测试

---

## 修改文件列表

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `client/scripts/combat/damage_number.gd` | **修改** | 添加setup()调试日志 |
| `client/scripts/world/world_coordinate.gd` | **修改** | 调整奖励生成位置 |

---

## 问题1: DamageNumber不显示

### 修改内容

在`setup()`函数中添加调试日志：

```gdscript
func setup(damage: int, is_critical: bool = false, ...) -> void:
    if not label:
        print("[DamageNumber] ERROR: Label node not found")
        return

    # ... 设置文本和颜色 ...

    # Phase 17.7.3: 调试日志
    print("[DamageNumber Setup] text=", label.text, " visible=", visible, " scale=", scale, " modulate=", modulate, " label_visible=", label.visible, " label_modulate=", label.modulate, " global_position=", global_position, " z_index=", z_index)
```

### 预期日志输出

```
[DamageNumber Setup] text=29 visible=true scale=(1, 1) modulate=(1, 1, 1, 1) label_visible=true label_modulate=(1, 1, 1, 1) global_position=(305, 278) z_index=100
```

### 可能的问题

如果日志显示正常但仍不可见：

1. **Camera zoom问题** - Camera zoom=2可能导致文字太小
2. **字体问题** - 默认字体可能不可见
3. **位置问题** - 可能在屏幕外

---

## 问题2: Reward进入地板

### 根因

奖励生成位置`y = GROUND_Y - 20 = 308`，但奖励实际显示时会进入地板。

### 修改内容

添加`REWARD_FLOAT_OFFSET`常量，调整奖励生成位置：

```gdscript
## Phase 17.7.3: 返回世界坐标，奖励浮在平台上方
const REWARD_FLOAT_OFFSET: int = 40
static func reward_spawn_pos(room_center: Vector2) -> Vector2:
    var x = randf_range(-200, 200)
    var y = GROUND_Y - REWARD_FLOAT_OFFSET  # 在地面上方40像素
    # 返回世界坐标
    return room_center + Vector2(x, y)
```

### 位置计算

**修改前：**
- `y = GROUND_Y - 20 = 328 - 20 = 308`

**修改后：**
- `y = GROUND_Y - 40 = 328 - 40 = 288`

---

## 测试方法

### 测试1: DamageNumber显示

1. 启动游戏
2. 进入combat房间
3. 攻击怪物
4. 观察控制台日志

**预期日志：**
```
[DamageNumber] Spawn Start damage=29 target=Monster
[DamageNumber] Position: global=(305, 278) target_global=(300, 298)
[DamageNumber] Scene Loaded: res://scenes/combat/damage_number.tscn
[DamageNumber] Instance Created: DamageNumber
[DamageNumber] Added To Tree: parent=EffectContainer global_pos=(305, 278) visible=true z_index=100 modulate=(1, 1, 1, 1)
[DamageNumber Setup] text=29 visible=true scale=(1, 1) modulate=(1, 1, 1, 1) label_visible=true label_modulate=(1, 1, 1, 1) global_position=(305, 278) z_index=100
```

**如果仍不可见：**
- 检查Camera zoom设置
- 检查字体是否加载
- 检查位置是否在屏幕内

### 测试2: Reward位置

1. 击杀怪物
2. 观察奖励位置

**预期：**
- 奖励在平台上方40像素
- 不会进入地板

**预期日志：**
```
[Reward Spawn Debug] type=gold local_position=(300, 288) global_position=(300, 288) parent=RewardContainer
[Reward Debug] global_position=(300, 288) z_index=50 visible=true sprite_texture=... parent=RewardContainer
```

---

## 坐标系统说明

### 地面位置

```
HALF_HEIGHT = 360
GROUND_HEIGHT = 64
GROUND_Y = 360 - 32 = 328  (地面顶部)
```

### 奖励位置

```
修改前: y = 328 - 20 = 308 (部分在地面内)
修改后: y = 328 - 40 = 288 (完全在地面上方)
```

### 屏幕范围

```
视口: 1280 x 720
Camera zoom: 2x
可见范围: 640 x 360 (以玩家为中心)
```

---

## 下一步

1. 运行游戏测试
2. 观察控制台日志
3. 确认DamageNumber和Reward是否显示
4. 如果仍有问题，根据日志进一步调试

---

**报告完成，等待测试结果。**

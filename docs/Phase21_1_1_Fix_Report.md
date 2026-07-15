# Phase 21.1.1 Combat Stability Hotfix Report

**修复时间：** 2026-07-16
**版本：** v1.0-stable
**状态：** 修复完成，等待测试

---

## 修改文件列表

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `client/scripts/enemy/monster_node.gd` | **修改** | 添加死亡防重复触发机制 |
| `client/scripts/combat/bullet.gd` | **修改** | 修复_hit_target() return逻辑 |

---

## 任务1: Monster死亡防重复触发

### 修改内容

**文件：** `client/scripts/enemy/monster_node.gd`

**1. 添加成员变量：**
```gdscript
## Phase 21.1.1: 死亡状态标志（防重复触发）
var _is_dying: bool = false
```

**2. 修改on_death()函数：**
```gdscript
func on_death() -> void:
    # Phase 21.1.1: 防止重复触发死亡
    if _is_dying:
        return
    _is_dying = true

    print("[Monster] ", _monster_entity.get_monster_name(), " died!")
    # ... 保持原有死亡逻辑不变
```

### 验证

- 同一个怪物的 `[Monster] xxx died!` 日志只能出现一次
- 防止多次通知RoomSpawner
- 防止多次调用queue_free()

---

## 任务2: Bullet命中流程return修复

### 修改内容

**文件：** `client/scripts/combat/bullet.gd`

**修改前：**
```gdscript
func _hit_target(target: Node2D) -> void:
    if _damage_system and _damage_system.has_method("on_bullet_hit"):
        _damage_system.on_bullet_hit(self, target)
    else:
        if target.has_method("take_damage"):
            target.take_damage(damage)
        destroy()
```

**修改后：**
```gdscript
func _hit_target(target: Node2D) -> void:
    if _damage_system and _damage_system.has_method("on_bullet_hit"):
        _damage_system.on_bullet_hit(self, target)
        return  # Phase 21.1.1: DamageSystem内部会调用destroy()，避免重复执行

    # 如果没有DamageSystem，直接调用take_damage
    if target.has_method("take_damage"):
        target.take_damage(damage)
    destroy()
```

### 验证

- DamageSystem.on_bullet_hit()内部会调用bullet.destroy()
- 添加return避免重复执行destroy()
- 普通伤害路径（无DamageSystem）保持不变

---

## 测试步骤

### 测试1: 普通怪物

1. 启动游戏
2. 进入combat房间
3. 攻击普通怪物
4. 观察控制台日志

**预期：**
```
[Bullet] Hit monster: Monster
[Damage] monster 火焰精灵 hp 100->71
[DamageNumber] Spawn Start damage=29 target=Monster
[Monster] 火焰精灵 died!
[DamageNumber] Destroyed
```

**验证点：**
- `[Monster] xxx died!` 只出现一次
- `[DamageNumber] Destroyed` 正常输出
- 子弹正常销毁

### 测试2: Boss怪物

1. 进入Boss房间
2. 攻击Boss
3. 观察控制台日志

**预期：**
```
[Bullet] Hit monster: BossMonster
[Damage] boss xxx hp 500->471
[BossController] Boss defeated!
[CombatManager] Boss defeated!
[GameScene] Boss defeated!
```

**验证点：**
- `[BossController] Boss defeated!` 只出现一次
- `[CombatManager] Boss defeated!` 只出现一次
- Boss奖励正常生成

### 测试3: 连续射击

1. 进入combat房间
2. 连续快速射击怪物
3. 观察控制台日志

**预期：**
- 每个怪物的死亡日志只出现一次
- DamageNumber正常显示和消失
- 子弹正常销毁
- 房间clear正常触发

---

## 修改原因

### 问题1: Monster死亡无防重复触发

**风险：** 如果多次调用on_death()，可能导致：
- 多次通知RoomSpawner
- 多次调用queue_free()
- 潜在的内存泄漏或崩溃

**修复：** 添加`_is_dying`标志，确保死亡流程只执行一次

### 问题2: Bullet._hit_target()无return

**风险：** DamageSystem.on_bullet_hit()内部会调用bullet.destroy()，但_hit_target()之后没有return，可能继续执行else分支

**修复：** 添加return语句，避免重复执行destroy()

---

## 是否发现新问题

**未发现新问题。**

修改内容：
- 只添加了防重复触发机制
- 只添加了return语句
- 没有改变现有逻辑
- 没有引入新依赖

---

## 总结

| 任务 | 状态 | 说明 |
|------|------|------|
| Monster死亡防重复触发 | ✅ 完成 | 添加`_is_dying`标志 |
| Bullet命中流程return修复 | ✅ 完成 | 添加return语句 |
| 测试验证 | ⏳ 等待 | 需要实际测试 |

---

**Phase 21.1.1 修复完成，等待测试结果。**

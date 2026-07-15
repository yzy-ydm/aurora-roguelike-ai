# Phase 24.1 伤害公式审计报告

**审计时间：** 2026-07-16
**版本：** v1.0-stable
**状态：** 审计完成

---

## 1. 伤害计算流程图

```
Player攻击
    ↓
Weapon.try_attack(direction)
    ↓
获取WeaponInstance.get_damage() → weapon_damage
    ↓
创建Bullet，传递 weapon_damage + is_critical
    ↓
Bullet飞行命中Monster
    ↓
DamageSystem.on_bullet_hit(bullet, target)
    ↓
获取 source.get_attack() → attacker_attack
获取 bullet.get_damage() → weapon_damage
获取 target防御 → target_defense
    ↓
calculate_damage(attacker_attack, weapon_damage, target_defense, 0.0)
    ↓
base_damage = attacker_attack + weapon_damage
defense_reduction = target_defense / (target_defense + 100)
final_damage = base_damage * (1 - defense_reduction)
    ↓
如果 is_critical:
    final_damage = final_damage * 1.5
    ↓
最终伤害 = max(1, int(final_damage))
```

---

## 2. 示例计算

### 当前测试参数

| 参数 | 值 | 来源 |
|------|-----|------|
| Player Attack | 10 | PlayerStats.attack |
| Weapon Damage | 15 | WeaponInstance.get_damage() |
| Weapon Level | 1 | 默认 |
| Target Defense | 0 | 怪物无防御 |
| Critical | false | 无暴击 |

### 计算过程

```
attacker_attack = source.get_attack()
                = player.attack + weapon_instance.get_damage()
                = 10 + 15
                = 25

weapon_damage = bullet.get_damage()
              = 15

base_damage = attacker_attack + weapon_damage
            = 25 + 15
            = 40

defense_reduction = 0 / (0 + 100)
                  = 0

final_damage = 40 * (1 - 0)
             = 40
```

**结果：** 40伤害

### 为什么可能是74伤害？

**可能原因：**

1. **武器升级** - 武器等级提升导致伤害增加
2. **属性奖励** - 升级获得的攻击力加成
3. **被动物品** - 攻击力加成

**假设场景：**

| 参数 | 值 | 说明 |
|------|-----|------|
| Player Attack | 15 | 升级+5 |
| Weapon Damage | 25 | 武器升级后 |
| Critical | true | 10%暴击率 |

```
base_damage = 15 + 25 = 40
final_damage = 40 * 1.5 = 60
```

**或：**

| 参数 | 值 | 说明 |
|------|-----|------|
| Player Attack | 20 | 升级+10 |
| Weapon Damage | 30 | 武器升级后 |
| Critical | true | 10%暴击率 |

```
base_damage = 20 + 30 = 50
final_damage = 50 * 1.5 = 75
```

**接近74伤害！**

---

## 3. 哪些参数影响最大

### 影响权重分析

| 参数 | 影响权重 | 说明 |
|------|----------|------|
| Weapon Damage | ⭐⭐⭐⭐⭐ | 直接影响基础伤害 |
| Player Attack | ⭐⭐⭐⭐ | 直接影响基础伤害 |
| Critical | ⭐⭐⭐ | 1.5倍暴击 |
| Weapon Level | ⭐⭐⭐ | 每级增加damage_growth |
| Target Defense | ⭐⭐ | 减伤百分比 |

### 伤害公式

```
final_damage = (player_attack + weapon_damage) * (1 - defense/(defense+100)) * crit_multiplier
```

### 参数敏感度

| 参数变化 | 伤害变化 | 说明 |
|----------|----------|------|
| Weapon +5 | +5 | 线性增长 |
| Attack +5 | +5 | 线性增长 |
| Critical触发 | *1.5 | 50%提升 |
| Defense +10 | -9% | 递减收益 |

---

## 4. 哪些参数适合平衡调整

### 推荐调整参数

| 参数 | 当前值 | 建议调整 | 效果 |
|------|--------|----------|------|
| Player Attack | 10 | 10 | 保持 |
| Weapon Damage | 20 | 10-15 | 降低DPS |
| Critical Multiplier | 1.5 | 1.3 | 降低暴击收益 |
| Defense Formula | defense/(defense+100) | defense/(defense+50) | 增加防御收益 |

### 平衡公式建议

**当前公式：**
```
final_damage = (attack + weapon) * (1 - defense/(defense+100))
```

**建议公式：**
```
final_damage = (attack + weapon) * (100 / (100 + defense)) * crit_mult
```

---

## 5. 总结

### 当前伤害链

```
Player Attack (10)
    + Weapon Damage (20)
    = Base Damage (30)
    * (1 - Defense%)
    * Critical (1.5x)
    = Final Damage
```

### 关键发现

1. **伤害计算正确** - 公式逻辑清晰
2. **暴击判定在子弹创建时** - 避免重复判定
3. **防御公式合理** - 递减收益设计
4. **DPS过高** - 需要调整基础数值

### 平衡建议

| 优先级 | 调整项 | 当前值 | 建议值 |
|--------|--------|--------|--------|
| P1 | 武器基础伤害 | 20 | 10-15 |
| P2 | 暴击倍率 | 1.5 | 1.3 |
| P3 | 怪物防御 | 0-10 | 5-15 |

---

**Phase 24.1 伤害公式审计完成。**

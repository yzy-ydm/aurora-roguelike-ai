# 玩法系统文档

> Aurora-Roguelike-AI 核心玩法说明

最后更新：2026-07-16

---

## 核心循环

```
登录 → 选择存档 → 进入楼层 → 探索房间 → 战斗 → 奖励 → Boss → 下一层
```

---

## 房间系统

### 房间类型

| 类型 | 说明 | 怪物 | 奖励 |
|------|------|------|------|
| START | 起始房间 | 无 | 无 |
| COMBAT | 战斗房间 | 2-4个 | 1-3个 |
| ELITE | 精英房间 | 1-2个 | 2-4个 |
| BOSS | Boss房间 | 1个Boss | 5个 |
| REWARD | 奖励房间 | 无 | 3-5个 |
| SHOP | 商店房间 | 无 | 待实现 |
| EVENT | 事件房间 | 0-2个 | AI生成 |
| TREASURE | 宝箱房间 | 无 | 待实现 |

### 楼层生成

- 每层8-12个房间
- 主路径4-6个房间
- 分支房间若干
- Boss房间固定在最后

---

## 战斗系统

### 伤害公式

```
base_damage = player_attack + weapon_damage
defense_reduction = target_defense / (target_defense + 100)
final_damage = base_damage * (1 - defense_reduction) * crit_multiplier
```

### 玩家操作

- **移动：** A/D 或 左右箭头
- **跳跃：** 空格/W/Up
- **冲刺：** Shift/C
- **攻击：** 鼠标左键（朝面朝方向）

---

## Boss系统

### Boss数据

```gdscript
boss_hp = 300 + floor_level * 200
boss_attack = 15 + floor_level * 10
boss_defense = 5 + floor_level * 5
```

### Boss阶段

| 阶段 | HP阈值 | 技能 |
|------|--------|------|
| Phase 1 | 100%-50% | 重击 |
| Phase 2 | 50%-25% | 冲锋 |
| Phase 3 | 25%-0% | 怒吼 |

---

## 奖励系统

### 奖励类型

| 类型 | 数值范围 | 说明 |
|------|----------|------|
| GOLD | 10-50 | 金币 |
| ATTACK_UP | 1-5 | 攻击力 |
| HEALTH_UP | 5-20 | 最大生命 |
| HEAL | 10-30 | 治疗 |
| WEAPON_UPGRADE | +1级 | 武器升级 |
| ATTRIBUTE_BOOST | 2-8 | 属性强化 |
| PASSIVE_ITEM | 特殊 | 被动效果 |

---

## 成长系统

### 升级经验

```
exp_required = 100 * 1.5^(level-1)
```

### 升级奖励

| 类型 | COMMON | UNCOMMON | RARE |
|------|--------|----------|------|
| 攻击 | +5 | +10 | +15 |
| 生命 | +20 | +40 | +60 |
| 防御 | +5 | +10 | - |

---

**当前状态：核心玩法完整，数值需平衡调整**

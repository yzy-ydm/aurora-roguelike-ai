# Phase 25 怪物平衡系统设计分析报告

**分析时间：** 2026-07-16
**版本：** v1.0-stable
**状态：** 分析完成

---

## 1. 当前所有怪物数据位置

### 数据存储位置

| 位置 | 文件 | 说明 |
|------|------|------|
| 本地默认数据 | `client/scripts/services/resource_service.gd` | `_load_default_monsters()` |
| API服务器 | `server/app/api/monster/router.py` | `/api/monsters` |
| AI生成 | `client/scripts/ai/ai_content_service.gd` | 动态生成 |

### 默认怪物数据

```gdscript
# resource_service.gd
{
    "id": 1, "name": "史莱姆", "type": "normal", "level": 1,
    "health": 20, "attack": 5, "defense": 2, "speed": 3,
    "experience_reward": 10, "gold_reward": 5
},
{
    "id": 2, "name": "哥布林", "type": "normal", "level": 1,
    "health": 30, "attack": 8, "defense": 3, "speed": 5,
    "experience_reward": 15, "gold_reward": 8
},
{
    "id": 3, "name": "骷髅战士", "type": "normal", "level": 2,
    "health": 40, "attack": 10, "defense": 5, "speed": 4,
    "experience_reward": 20, "gold_reward": 12
},
{
    "id": 4, "name": "蝙蝠", "type": "normal", "level": 1,
    "health": 15, "attack": 6, "defense": 1, "speed": 10,
    "experience_reward": 8, "gold_reward": 3
},
{
    "id": 5, "name": "精英卫兵", "type": "elite", "level": 3,
    "health": 80, "attack": 15, "defense": 10, "speed": 5,
    "experience_reward": 40, "gold_reward": 25
},
{
    "id": 6, "name": "暗影刺客", "type": "elite", "level": 3,
    "health": 60, "attack": 20, "defense": 4, "speed": 8,
    "experience_reward": 35, "gold_reward": 20
}
```

---

## 2. 当前Boss数据位置

### Boss数据生成

**位置：** `client/scenes/game/game_scene.gd`

```gdscript
func _create_boss_data_for_room(room: NewRoomData) -> BossData:
    var floor_level = _floor_manager.get_floor_level()

    var boss_data = BossData.new()
    boss_data.max_health = 300 + floor_level * 200
    boss_data.attack = 15 + floor_level * 10
    boss_data.defense = 5 + floor_level * 5
    boss_data.speed = (80.0 + floor_level * 10) * 0.6
    boss_data.attack_cooldown = 1.5
    boss_data.attack_prepare_time = 0.5
    boss_data.reward_gold = 100 + floor_level * 50
    boss_data.reward_exp = 80 + floor_level * 40
```

### Boss数值表

| Floor | HP | Attack | Defense | Speed | Reward Gold | Reward EXP |
|-------|-----|--------|---------|-------|-------------|------------|
| 1 | 500 | 25 | 10 | 54 | 150 | 120 |
| 2 | 700 | 35 | 15 | 60 | 200 | 160 |
| 3 | 900 | 45 | 20 | 66 | 250 | 200 |
| 5 | 1300 | 65 | 30 | 78 | 350 | 280 |
| 10 | 2300 | 115 | 55 | 108 | 600 | 480 |

---

## 3. 当前Floor难度来源

### 难度调整机制

**位置：** `client/scripts/models/room_content_data.gd`

```gdscript
func apply_difficulty_modifier(diff: int) -> void:
    difficulty = diff

    # 怪物数量调整
    var difficulty_mult = 1.0 + (diff - 1) * 0.2
    monster_count = int(monster_count * difficulty_mult)

    # 怪物等级调整
    monster_level = max(1, diff)

    # 奖励品质调整
    reward_quality *= (1.0 + (diff - 1) * 0.1)
```

### 难度公式

| 参数 | 公式 | 示例 (Floor 3) |
|------|------|----------------|
| 怪物数量 | `base * (1 + (floor-1) * 0.2)` | 3 * 1.4 = 4.2 → 4 |
| 怪物等级 | `max(1, floor)` | 3 |
| 奖励品质 | `base * (1 + (floor-1) * 0.1)` | 1.0 * 1.2 = 1.2 |

### 怪物等级修正

**位置：** `client/scripts/world/room_spawner.gd`

```gdscript
func _apply_level_modifier(entity: MonsterEntity, level: int) -> void:
    var multiplier = 1.0 + (level - 1) * 0.3
    entity.health = int(entity.health * multiplier)
    entity.max_health = int(entity.max_health * multiplier)
    entity.attack = int(entity.attack * multiplier)
    entity.defense = int(entity.defense * multiplier)
```

**等级修正公式：** `属性 = 基础属性 * (1 + (level-1) * 0.3)`

---

## 4. 当前玩家成长速度

### 初始属性

| 属性 | 初始值 |
|------|--------|
| HP | 100 |
| Attack | 10 |
| Defense | 0 |
| Move Speed | 200 |

### 升级奖励

| 升级项 | COMMON | UNCOMMON | RARE |
|--------|--------|----------|------|
| 攻击 | +5 | +10 | +15 |
| 生命 | +20 | +40 | +60 |
| 防御 | +5 | +10 | - |
| 速度 | +10% | +20% | - |
| 暴击 | - | +5% | +10% |

### 武器成长

```gdscript
# weapon_instance.gd
func get_damage() -> int:
    var base = _weapon_data.base_damage if _weapon_data.base_damage > 0 else _weapon_data.damage
    return base + _weapon_data.damage_growth * (_level - 1)
```

**默认武器：** 基础伤害 20，每级 +5

### 经验需求

```gdscript
# upgrade_manager.gd
const BASE_EXP_REQUIRE: int = 100
const EXP_GROWTH_RATE: float = 1.5

func _calculate_exp_requirement(level: int) -> int:
    return int(BASE_EXP_REQUIRE * pow(EXP_GROWTH_RATE, level - 1))
```

| 等级 | 经验需求 |
|------|----------|
| 1→2 | 100 |
| 2→3 | 150 |
| 3→4 | 225 |
| 5→6 | 506 |
| 10→11 | 3844 |

---

## 5. 设计统一平衡参数

### MonsterBalanceConfig 设计

```gdscript
class_name MonsterBalanceConfig
extends RefCounted

## ==================== 基础属性倍率 ====================

## 普通怪物基础倍率
const NORMAL_HP_MULT: float = 1.0
const NORMAL_ATTACK_MULT: float = 1.0
const NORMAL_DEFENSE_MULT: float = 1.0

## 精英怪物倍率
const ELITE_HP_MULT: float = 2.5
const ELITE_ATTACK_MULT: float = 1.8
const ELITE_DEFENSE_MULT: float = 2.0

## Boss倍率
const BOSS_HP_MULT: float = 10.0
const BOSS_ATTACK_MULT: float = 3.0
const BOSS_DEFENSE_MULT: float = 2.5

## ==================== Floor难度成长 ====================

## 每层怪物属性成长
const FLOOR_HP_GROWTH: float = 0.15      # 每层+15%
const FLOOR_ATTACK_GROWTH: float = 0.12  # 每层+12%
const FLOOR_DEFENSE_GROWTH: float = 0.10 # 每层+10%

## 每层怪物数量成长
const FLOOR_COUNT_GROWTH: float = 0.20   # 每层+20%

## ==================== 等级修正 ====================

## 怪物等级修正
const LEVEL_HP_GROWTH: float = 0.30      # 每级+30%
const LEVEL_ATTACK_GROWTH: float = 0.25  # 每级+25%
const LEVEL_DEFENSE_GROWTH: float = 0.20 # 每级+20%

## ==================== 玩家成长参考 ====================

## 玩家每次升级属性成长
const PLAYER_ATTACK_PER_LEVEL: int = 5
const PLAYER_HP_PER_LEVEL: int = 20
const PLAYER_DEFENSE_PER_LEVEL: int = 3

## 武器每级伤害成长
const WEAPON_DAMAGE_PER_LEVEL: int = 5

## ==================== 目标战斗时长 ====================

## 普通怪物目标击杀时间（秒）
const TARGET_NORMAL_KILL_TIME: float = 2.0

## 精英怪物目标击杀时间（秒）
const TARGET_ELITE_KILL_TIME: float = 5.0

## Boss目标击杀时间（秒）
const TARGET_BOSS_KILL_TIME: float = 60.0

## ==================== 计算方法 ====================

## 计算怪物HP
static func calculate_monster_hp(base_hp: int, monster_type: String, floor_level: int, monster_level: int) -> int:
    var type_mult = 1.0
    match monster_type:
        "elite": type_mult = ELITE_HP_MULT
        "boss": type_mult = BOSS_HP_MULT

    var floor_mult = 1.0 + (floor_level - 1) * FLOOR_HP_GROWTH
    var level_mult = 1.0 + (monster_level - 1) * LEVEL_HP_GROWTH

    return int(base_hp * type_mult * floor_mult * level_mult)

## 计算怪物攻击
static func calculate_monster_attack(base_attack: int, monster_type: String, floor_level: int, monster_level: int) -> int:
    var type_mult = 1.0
    match monster_type:
        "elite": type_mult = ELITE_ATTACK_MULT
        "boss": type_mult = BOSS_ATTACK_MULT

    var floor_mult = 1.0 + (floor_level - 1) * FLOOR_ATTACK_GROWTH
    var level_mult = 1.0 + (monster_level - 1) * LEVEL_ATTACK_GROWTH

    return int(base_attack * type_mult * floor_mult * level_mult)
```

---

## 6. Phase 25 实施方案

### 实施步骤

| 步骤 | 任务 | 说明 |
|------|------|------|
| 1 | 创建 `MonsterBalanceConfig` | 统一平衡参数 |
| 2 | 修改 `RoomSpawner` | 使用新公式计算怪物属性 |
| 3 | 修改 `GameScene` | Boss数据使用新公式 |
| 4 | 测试验证 | 验证战斗平衡 |

### 实施优先级

| 优先级 | 任务 | 预计效果 |
|--------|------|----------|
| P0 | 创建平衡配置 | 统一数值管理 |
| P1 | 修改怪物生成 | 使用新公式 |
| P2 | 修改Boss生成 | 使用新公式 |
| P3 | 测试调优 | 验证平衡性 |

### 预期效果

| 怪物类型 | Floor 1 HP | Floor 3 HP | Floor 5 HP |
|----------|------------|------------|------------|
| 史莱姆 (普通) | 20 | 26 | 33 |
| 哥布林 (普通) | 30 | 39 | 50 |
| 精英卫兵 (精英) | 50 | 65 | 83 |
| Boss | 200 | 260 | 330 |

---

## 总结

### 当前状态

| 项目 | 状态 | 说明 |
|------|------|------|
| 怪物数据 | ✅ | 本地默认 + API + AI |
| Boss数据 | ✅ | 动态生成 |
| 难度系统 | ✅ | Floor成长 |
| 玩家成长 | ✅ | 升级 + 武器 |

### 建议

1. **创建统一平衡配置** - `MonsterBalanceConfig`
2. **使用公式计算属性** - 替代硬编码
3. **测试验证平衡性** - 确保战斗体验

---

**Phase 25 怪物平衡系统设计分析完成。**

# Phase 1 游戏核心闭环审计报告

> 生成日期：2026-09-22
> 目的：全面追踪AI生成内容到游戏显示的完整链路，定位所有断点

---

## 一、怪物HP=1935根因分析

### 1.1 数据流追踪

```
AI服务生成
    ↓
{"health": base_hp * multiplier, ...}
    ↓
HTTP JSON响应
    ↓
Client RoomSpawner._get_monster_by_config()
    ↓
ResourceService.get_monsters() → 从服务器获取武器库
    ↓
MonsterData.from_dict(data)
    ↓
health = max(data.get("health", 50), 10)  ← 已修复
    ↓
MonsterEntity.set_monster_data()
    ↓
health = _monster_data.health  ← 正确赋值
    ↓
_apply_level_modifier(entity, content.monster_level)
    ↓
entity.health = int(entity.health * multiplier)
             = int(50 * (1 + (level-1) * 0.3))
             = int(50 * 1.9)  ← Level 7时
             = 95  ← 仍然合理
```

**但日志显示 HP=1935！**

### 1.2 问题定位

检查所有可能的数据源：

| 数据源 | 位置 | 问题 |
|--------|------|------|
| AI服务Mock生成 | ai_service.py | 已修复base_hp计算 |
| MonsterData默认值 | monster_data.gd | 已修复为50 |
| MonsterEntity默认值 | monster_entity.gd | 仍为100 |
| 数据库测试数据 | insert_test_data.sql | 存在健康值999 |
| 数据库monster表 | 可能有异常数据 | 需要检查 |
| AI LLM生成 | 如果调用真实AI | 可能返回异常值 |

### 1.3 最可能的根因

**路径A：AI LLM生成时未裁剪HP**
- 如果`AI_PROVIDER=agnes`且API返回`health: 1935`
- Validator裁剪到500，但原始值可能被缓存或使用

**路径B：数据库有异常数据**
- `insert_test_data.sql`中有`health=999`的测试数据
- 如果ResourceService加载了这些脏数据

**路径C：_apply_level_modifier累积效应**
```python
# Level 1: health = 50
# Level 7: health = 50 * (1 + 6*0.3) = 50 * 2.8 = 140
# 仍然不会达到1935
```

**路径D：Boss数据路径**
```gdscript
# room_spawner.gd
monster_data.health = boss_data.max_health  # 直接赋值！
```
- Boss可能通过这条路径，绕过了Validator

---

## 二、问题汇总

### P0问题（必须修复）

| # | 问题 | 影响 | 位置 |
|---|------|------|------|
| 1 | MonsterEntity默认HP=100 | 覆盖AI生成的合理值 | monster_entity.gd:17 |
| 2 | 数据库有health=999的脏数据 | 污染ResourceService | insert_test_data.sql |
| 3 | Boss路径绕过Validator | HP无上限 | room_spawner.gd:223 |
| 4 | 无统一MonsterBalanceConfig | 数值散落各处 | 全局 |

### P1问题（应该修复）

| # | 问题 | 影响 |
|---|------|------|
| 5 | 怪物攻击无冷却 | 每秒多段伤害 |
| 6 | 武器掉落不显示 | 玩家感知不到变化 |
| 7 | 经验系统可能无限增长 | 升级逻辑异常 |

---

## 三、修复方案

### 方案1：建立MonsterBalanceConfig

创建统一配置文件：
```python
# server/ai/services/monster_balance.py
class MonsterBalanceConfig:
    # 普通怪范围
    NORMAL_HP_MIN = 40
    NORMAL_HP_MAX = 80
    NORMAL_ATK_MIN = 5
    NORMAL_ATK_MAX = 10
    NORMAL_DEF_MIN = 0
    NORMAL_DEF_MAX = 3

    # 精英怪范围
    ELITE_HP_MIN = 120
    ELITE_HP_MAX = 200

    # Boss范围
    BOSS_HP_MIN = 500
    BOSS_HP_MAX = 800
```

### 方案2：强制应用配置

所有生成路径必须经过：
```python
def generate_monster_config(room_type, floor_level, player_level):
    config = get_balance_config(room_type, floor_level)
    return {
        "health": clamp(random_range(config.hp_min, config.hp_max)),
        "attack": clamp(random_range(config.atk_min, config.atk_max)),
        ...
    }
```

### 方案3：清理数据库

删除或修正test data中的health=999记录。

---

## 四、修改计划

### Step 1: 创建MonsterBalanceConfig
- 新建 `server/ai/services/monster_balance.py`
- 定义所有怪物类型和楼层的属性范围

### Step 2: 修改AI服务使用配置
- 修改 `_generate_monster_config()` 使用配置
- 添加Validator强制裁剪

### Step 3: 清理数据库
- 修正insert_test_data.sql中的异常值

### Step 4: 修复MonsterEntity默认值
- 设置合理的默认HP/ATK/DEF

### Step 5: 添加整合测试
- 测试HP范围
- 测试武器掉落
- 测试经验系统

---

*报告完成，等待确认修复方案后开始编码。*

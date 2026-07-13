# Aurora-Roguelike-AI 战斗与怪物系统设计文档

> **设计时间**: 2026-07-13
> **设计目标**: 将当前项目升级为俯视角动作Roguelike
> **设计原则**: 兼容现有架构，最小改动，最大扩展性
> **参考游戏**: 元气骑士、挺进地牢

---

## 一、CombatSystem 整体架构

### 1.1 系统总览

```
┌─────────────────────────────────────────────────────────────────┐
│                      CombatManager (战斗管理器)                   │
│                      scripts/combat/combat_manager.gd            │
├─────────────────────────────────────────────────────────────────┤
│  职责：协调所有战斗子系统，管理战斗状态                              │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  WeaponSystem    │ │  BulletSystem    │ │  DamageSystem    │
│  武器系统         │ │  子弹系统         │ │  伤害系统         │
├──────────────────┤ ├──────────────────┤ ├──────────────────┤
│ - 武器切换       │ │ - 子弹生成       │ │ - 伤害计算       │
│ - 攻击触发       │ │ - 子弹移动       │ │ - 暴击判定       │
│ - 攻击动画       │ │ - 碰撞检测       │ │ - 元素克制       │
│ - 武器特效       │ │ - 子弹回收       │ │ - 伤害应用       │
└──────────────────┘ └──────────────────┘ └──────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  HealthSystem    │
                    │  生命系统         │
                    ├──────────────────┤
                    │ - 生命值管理     │
                    │ - 受伤处理       │
                    │ - 死亡处理       │
                    │ - 治疗处理       │
                    └──────────────────┘
```

### 1.2 WeaponSystem（武器系统）

**职责**:
- 管理玩家当前武器
- 处理武器攻击逻辑
- 协调子弹生成
- 管理武器冷却

**核心逻辑**:

```
攻击流程：
1. 玩家按下攻击键
2. WeaponSystem 检查冷却
3. 根据武器类型执行攻击
   - 近战武器：创建攻击区域
   - 远程武器：调用 BulletSystem 生成子弹
4. 触发攻击动画
5. 重置冷却计时器
```

**武器类型支持**:

| 类型 | 攻击方式 | 实现方式 |
|------|----------|----------|
| sword（剑） | 近战挥砍 | Area2D 扇形检测 |
| axe（斧） | 近战重击 | Area2D 圆形检测 |
| bow（弓） | 远程射击 | 生成子弹 |
| staff（法杖） | 远程魔法 | 生成子弹（带特效） |
| dagger（匕首） | 近战快速 | Area2D 小范围 |
| spear（长矛） | 近战直线 | Area2D 线形检测 |

### 1.3 BulletSystem（子弹系统）

**职责**:
- 生成子弹实例
- 管理子弹生命周期
- 处理子弹碰撞
- 回收子弹对象

**子弹类型**:

| 类型 | 行为 | 特性 |
|------|------|------|
| normal | 直线飞行 | 基础子弹 |
| piercing | 穿透敌人 | 不销毁 |
| explosive | 爆炸范围 | 范围伤害 |
| homing | 追踪目标 | 自动导向 |
| bouncing | 弹跳 | 碰撞反弹 |

**子弹节点结构**:

```
Bullet (Area2D)
├── Sprite2D (子弹外观)
├── CollisionShape2D (碰撞形状)
└── BulletScript (子弹逻辑)
    ├── speed: float
    ├── damage: int
    ├── direction: Vector2
    ├── bullet_type: BulletType
    └── lifetime: float
```

**对象池设计**:
- 预生成子弹对象池（避免频繁创建/销毁）
- 子弹超出屏幕或命中后回收到池中
- 池大小可配置（默认20个）

### 1.4 DamageSystem（伤害系统）

**职责**:
- 计算最终伤害值
- 处理暴击判定
- 处理元素克制
- 生成伤害数字

**伤害计算公式**:

```
基础伤害 = 武器伤害 + 玩家攻击力
防御减伤 = 目标防御力 / (目标防御力 + 100)
元素加成 = 元素克制表[攻击元素][防御元素]

最终伤害 = 基础伤害 × (1 - 防御减伤) × 元素加成 × 暴击倍率

暴击判定：
if randf() < 暴击率:
    最终伤害 = 最终伤害 × 1.5
    is_critical = true
```

**元素克制表**:

| 攻击\防御 | 火 | 冰 | 雷 | 暗 | 无 |
|-----------|----|----|----|----|----|
| 火 | 0.5 | 2.0 | 1.0 | 1.0 | 1.0 |
| 冰 | 1.0 | 0.5 | 2.0 | 1.0 | 1.0 |
| 雷 | 1.0 | 1.0 | 0.5 | 2.0 | 1.0 |
| 暗 | 2.0 | 1.0 | 1.0 | 0.5 | 1.0 |
| 无 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |

### 1.5 HealthSystem（生命系统）

**职责**:
- 管理实体生命值
- 处理受伤逻辑
- 处理死亡逻辑
- 处理治疗逻辑

**受伤流程**:

```
1. 接收伤害请求（damage, source, element）
2. 检查无敌状态
3. 调用 DamageSystem 计算实际伤害
4. 扣除生命值
5. 生成伤害数字飘字
6. 触发受伤动画/特效
7. 检查是否死亡
   - 是：触发死亡逻辑
   - 否：触发无敌帧
```

**死亡流程**:

```
1. 触发死亡动画
2. 禁用碰撞
3. 生成掉落物
4. 更新统计数据
5. 延迟后销毁节点
```

---

## 二、Monster 系统架构

### 2.1 系统总览

```
┌─────────────────────────────────────────────────────────────────┐
│                      MonsterSystem (怪物系统)                     │
│                      scripts/enemy/monster_system.gd             │
├─────────────────────────────────────────────────────────────────┤
│  职责：管理所有怪物的生成、AI、生命周期                              │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  MonsterBase     │ │  MonsterAI       │ │  MonsterSpawner  │
│  怪物基类         │ │  怪物AI          │ │  怪物生成器       │
├──────────────────┤ ├──────────────────┤ ├──────────────────┤
│ - 属性管理       │ │ - 行为树         │ │ - 生成配置       │
│ - 状态机         │ │ - 寻路           │ │ - 位置计算       │
│ - 受伤/死亡      │ │ - 攻击决策       │ │ - 批量生成       │
│ - 掉落处理       │ │ - 状态切换       │ │ - 难度调整       │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

### 2.2 MonsterBase（怪物基类）

**继承关系**:

```
Entity (entity.gd)
  └── MonsterBase (monster_base.gd)
        ├── MeleeMonster (近战怪物)
        ├── RangedMonster (远程怪物)
        ├── EliteMonster (精英怪物)
        └── BossMonster (Boss怪物)
```

**节点结构**:

```
Monster (CharacterBody2D)
├── Sprite2D (怪物外观)
├── CollisionShape2D (碰撞形状)
├── Hitbox (Area2D) (受击区域)
│   └── CollisionShape2D
├── AttackArea (Area2D) (攻击区域)
│   └── CollisionShape2D
├── HealthBar (ProgressBar) (血条)
└── AIController (怪物AI)
```

**怪物状态机**:

```
┌─────────┐
│  IDLE   │ ◄─────────────────┐
└────┬────┘                   │
     │ 发现玩家               │
     ▼                       │
┌─────────┐                   │
│  CHASE  │ ──失去目标────────┘
└────┬────┘
     │ 进入攻击范围
     ▼
┌─────────┐
│ ATTACK  │
└────┬────┘
     │ 攻击完成
     ▼
┌─────────┐
│  HURT   │ ──► 返回 CHASE
└────┬────┘
     │ 生命值 <= 0
     ▼
┌─────────┐
│  DEAD   │ ──► 掉落 + 销毁
└─────────┘
```

### 2.3 MonsterAI（怪物AI）

**AI 类型**:

| 类型 | 行为 | 适用怪物 |
|------|------|----------|
| melee | 接近玩家 → 近战攻击 | 哥布林、骷髅 |
| ranged | 保持距离 → 远程攻击 | 弓箭手、法师 |
| aggressive | 快速接近 → 疯狂攻击 | 狂战士 |
| defensive | 巡逻 → 反击 | 卫兵 |
| boss | 多阶段 → 特殊技能 | Boss怪物 |

**AI 决策流程**:

```
每帧更新：
1. 检测玩家距离
2. 根据 AI 类型决策
   - 在检测范围内？→ 追击
   - 在攻击范围内？→ 攻击
   - 超出范围？→ 巡逻/待机
3. 执行决策结果
4. 更新状态机
```

**寻路方案**:
- 简单方案：直线移动 + 碰撞避障
- 进阶方案：A*寻路（后期优化）

### 2.4 MonsterSpawner（怪物生成器）

**职责**:
- 根据房间配置生成怪物
- 管理怪物数量上限
- 处理怪物死亡计数

**生成逻辑**:

```
进入房间时：
1. 读取房间的 monster_spawn_config
2. 遍历配置列表
3. 对每个配置：
   - 计算生成位置（随机但避免重叠）
   - 实例化怪物场景
   - 设置怪物属性（从 MonsterData）
   - 添加到场景树
4. 记录当前房间怪物数量
```

**生成配置格式**:

```json
{
  "monsters": [
    {"type": "goblin", "count": 3},
    {"type": "skeleton", "count": 2}
  ],
  "max_monsters": 10,
  "spawn_radius": 200
}
```

### 2.5 怪物类型设计

**普通怪物**:

| 名称 | 类型 | 特点 |
|------|------|------|
| 哥布林 | melee | 低血量，快速 |
| 骷髅 | melee | 中等血量，中等攻击 |
| 蝙蝠 | melee | 低血量，高速度 |
| 弓箭手 | ranged | 远程攻击，保持距离 |
| 法师 | ranged | 魔法攻击，元素伤害 |

**精英怪物**:

| 名称 | 类型 | 特点 |
|------|------|------|
| 精英哥布林 | melee | 高血量，高攻击 |
| 骷髅骑士 | melee | 高防御，带盾 |
| 暗影弓手 | ranged | 高伤害，快速射击 |

**Boss怪物**:

| 名称 | 类型 | 特点 |
|------|------|------|
| 哥布林王 | boss | 召唤小怪，范围攻击 |
| 骨龙 | boss | 高血量，多阶段 |
| 暗影领主 | boss | 元素攻击，瞬移 |

---

## 三、与现有系统兼容方式

### 3.1 Entity 系统兼容

**现有 Entity 结构** (entity.gd):
```
Entity (RefCounted)
├── entity_id: int
├── entity_name: String
├── entity_type: String
├── position: Vector2
├── state: EntityState
└── 方法：activate(), pause(), destroy()
```

**MonsterBase 扩展方式**:
```
Entity
  └── MonsterBase (继承 Entity)
        ├── 复用：entity_id, entity_name, position, state
        ├── 新增：health, attack, defense, speed
        ├── 新增：monster_data: MonsterData
        └── 新增：AI 相关属性
```

**兼容要点**:
- MonsterBase 继承 Entity，复用基础属性
- 使用 Entity 的状态机（CREATED, ACTIVE, PAUSED, DESTROYED）
- 扩展新状态（CHASE, ATTACK, HURT, DEAD）

### 3.2 ObjectManager 兼容

**现有 ObjectManager 职责**:
- 注册/注销游戏对象
- 管理对象生命周期
- 提供对象查询接口

**怪物注册方式**:
```
MonsterSpawner 生成怪物
    ↓
调用 ObjectManager.register_object(monster)
    ↓
ObjectManager 管理怪物生命周期
    ↓
怪物死亡时调用 ObjectManager.unregister_object(monster)
```

**扩展 ObjectManager**:
- 新增 `get_monsters()` 方法
- 新增 `get_monsters_in_area()` 方法
- 新增怪物计数功能

### 3.3 WorldManager 兼容

**现有 WorldManager 职责**:
- 管理世界状态
- 加载地图数据
- 协调 RoomManager

**战斗系统集成**:
```
WorldManager.load_world()
    ↓
加载地图数据
    ↓
创建房间时：
    ├── MapRenderer 渲染房间
    ├── MonsterSpawner 生成怪物
    └── 门/锁控制
```

**新增信号**:
- `room_cleared` - 房间怪物清除
- `all_rooms_cleared` - 所有房间清除

### 3.4 RoomManager 兼容

**现有 RoomManager 职责**:
- 管理房间列表
- 房间切换逻辑
- 房间状态管理

**战斗流程集成**:

```
进入房间 (enter_room)
    ↓
房间状态：IN_COMBAT
    ↓
MonsterSpawner 生成怪物
    ↓
门关闭（锁定）
    ↓
玩家战斗
    ↓
所有怪物死亡
    ↓
房间状态：COMPLETED
    ↓
门开启
    ↓
可以进入下一房间
```

**扩展 RoomManager**:
- 新增房间状态：`IN_COMBAT`, `COMPLETED`
- 新增怪物计数
- 新增门/锁控制逻辑

### 3.5 ResourceService 兼容

**现有 ResourceService**:
- 已加载 `_monsters: Array[MonsterData]`
- 已实现 `get_monsters()` 方法

**使用方式**:
```
MonsterSpawner 需要生成怪物时：
1. 调用 ResourceService.get_monsters()
2. 根据房间配置筛选怪物
3. 使用 MonsterData 初始化怪物属性
```

---

## 四、文件目录设计

### 4.1 新增目录结构

```
client/scripts/
├── combat/                    # 战斗系统（新增）
│   ├── combat_manager.gd     # 战斗管理器
│   ├── weapon_system.gd      # 武器系统
│   ├── bullet_system.gd      # 子弹系统
│   ├── damage_system.gd      # 伤害系统
│   ├── health_system.gd      # 生命系统
│   ├── bullet.gd             # 子弹脚本
│   └── damage_number.gd      # 伤害数字
│
├── enemy/                     # 怪物系统（新增）
│   ├── monster_system.gd     # 怪物系统管理器
│   ├── monster_base.gd       # 怪物基类
│   ├── monster_ai.gd         # 怪物AI
│   ├── monster_spawner.gd    # 怪物生成器
│   ├── monster_health_bar.gd # 怪物血条
│   ├── melee_monster.gd      # 近战怪物
│   ├── ranged_monster.gd     # 远程怪物
│   ├── elite_monster.gd      # 精英怪物
│   └── boss_monster.gd       # Boss怪物
│
└── drop/                      # 掉落系统（新增）
    ├── drop_system.gd        # 掉落管理器
    ├── drop_item.gd          # 掉落物品
    └── drop_table.gd         # 掉落表
```

### 4.2 新增场景文件

```
client/scenes/
├── combat/                    # 战斗场景（新增）
│   ├── bullet.tscn           # 子弹场景
│   ├── damage_number.tscn    # 伤害数字场景
│   └── attack_effect.tscn    # 攻击特效
│
├── enemy/                     # 怪物场景（新增）
│   ├── monster_base.tscn     # 怪物基类场景
│   ├── goblin.tscn           # 哥布林
│   ├── skeleton.tscn         # 骷髅
│   ├── bat.tscn              # 蝙蝠
│   ├── archer.tscn           # 弓箭手
│   └── boss_goblin_king.tscn # Boss
│
└── drop/                      # 掉落场景（新增）
    ├── drop_gold.tscn        # 金币掉落
    ├── drop_item.tscn        # 物品掉落
    └── drop_weapon.tscn      # 武器掉落
```

### 4.3 修改现有文件

| 文件 | 修改内容 |
|------|----------|
| player_controller.gd | 添加攻击输入处理 |
| game_scene.gd | 初始化战斗系统、怪物系统 |
| room_manager.gd | 添加战斗状态管理 |
| object_manager.gd | 添加怪物管理方法 |
| hud_controller.gd | 显示战斗信息 |

---

## 五、Signal 通信设计

### 5.1 CombatManager 信号

```gdscript
# 战斗管理器信号
signal weapon_equipped(weapon_data: WeaponData)    # 武器装备
signal weapon_changed(old_weapon: WeaponData, new_weapon: WeaponData)  # 武器切换
signal attack_started(weapon_data: WeaponData)     # 攻击开始
signal attack_finished(weapon_data: WeaponData)    # 攻击结束
signal damage_dealt(target: Node2D, damage: int, is_critical: bool)  # 造成伤害
signal damage_taken(source: Node2D, damage: int)   # 受到伤害
```

### 5.2 HealthSystem 信号

```gdscript
# 生命系统信号
signal health_changed(old_value: int, new_value: int, max_value: int)  # 生命值变化
signal healed(amount: int)                         # 治疗
signal damaged(amount: int, source: Node2D)        # 受伤
signal died(entity: Node2D)                        # 死亡
signal invincibility_started()                     # 无敌开始
signal invincibility_ended()                       # 无敌结束
```

### 5.3 MonsterSystem 信号

```gdscript
# 怪物系统信号
signal monster_spawned(monster: Node2D)            # 怪物生成
signal monster_died(monster: Node2D)               # 怪物死亡
signal monster_hit(monster: Node2D, damage: int)   # 怪物受击
signal all_monsters_cleared()                       # 所有怪物清除
signal boss_defeated(boss_name: String)            # Boss击败
```

### 5.4 RoomManager 扩展信号

```gdscript
# 房间管理器扩展信号
signal room_combat_started(room_data: RoomData)    # 房间战斗开始
signal room_combat_ended(room_data: RoomData)      # 房间战斗结束
signal room_cleared(room_data: RoomData)           # 房间清除
signal room_door_opened(room_data: RoomData)       # 房间门开启
signal room_door_closed(room_data: RoomData)       # 房间门关闭
```

### 5.5 信号连接图

```
CombatManager
    ├── damage_dealt ──► HUD 更新伤害数字
    ├── damage_dealt ──► HealthSystem 扣血
    └── attack_finished ──► WeaponSystem 重置冷却

HealthSystem
    ├── health_changed ──► HUD 更新血条
    ├── died ──► MonsterBase 执行死亡
    └── died ──► MonsterSpawner 更新计数

MonsterSystem
    ├── monster_died ──► DropSystem 生成掉落
    ├── monster_died ──► RoomManager 检查清除
    └── all_monsters_cleared ──► RoomManager 开门

RoomManager
    ├── room_entered ──► MonsterSpawner 生成怪物
    ├── room_cleared ──► 门开启
    └── room_cleared ──► HUD 显示提示
```

---

## 六、数据结构设计

### 6.1 CombatData（战斗数据）

```gdscript
## 战斗数据结构
class_name CombatData

## 伤害结果
var damage_value: int = 0          # 伤害值
var damage_type: String = "physical"  # 伤害类型（physical/magical）
var element: String = "none"       # 元素类型
var is_critical: bool = false      # 是否暴击
var source: Node2D = null          # 伤害来源
var target: Node2D = null          # 伤害目标
```

### 6.2 WeaponConfig（武器配置）

```gdscript
## 武器运行时配置（扩展 WeaponData）
class_name WeaponConfig

## 基础数据（来自 WeaponData）
var weapon_data: WeaponData

## 运行时属性
var current_durability: int = 100  # 当前耐久
var cooldown_remaining: float = 0  # 剩余冷却
var is_equipped: bool = false      # 是否装备

## 攻击配置
var attack_area_size: Vector2 = Vector2(50, 30)  # 攻击区域大小
var attack_area_offset: Vector2 = Vector2(30, 0) # 攻击区域偏移
```

### 6.3 MonsterConfig（怪物配置）

```gdscript
## 怪物运行时配置（扩展 MonsterData）
class_name MonsterConfig

## 基础数据（来自 MonsterData）
var monster_data: MonsterData

## 运行时属性
var current_health: int = 100      # 当前生命
var current_state: String = "idle" # 当前状态
var target: Node2D = null          # 当前目标

## AI 配置
var detection_range: float = 200.0 # 检测范围
var attack_range: float = 50.0     # 攻击范围
var attack_cooldown: float = 1.0   # 攻击冷却
var move_speed: float = 100.0      # 移动速度

## 掉落配置
var drop_table: Array = []         # 掉落表
```

### 6.4 SpawnConfig（生成配置）

```gdscript
## 怪物生成配置
class_name SpawnConfig

## 房间怪物配置
var monsters: Array = [
    {"type": "goblin", "count": 3},
    {"type": "skeleton", "count": 2}
]

## 生成参数
var max_monsters: int = 10         # 最大怪物数
var spawn_radius: float = 200.0    # 生成半径
var spawn_delay: float = 0.5       # 生成延迟
var difficulty_modifier: float = 1.0  # 难度修正
```

### 6.5 DropConfig（掉落配置）

```gdscript
## 掉落配置
class_name DropConfig

## 掉落物品
var item_type: String = "gold"     # 物品类型（gold/item/weapon）
var item_id: int = 0               # 物品ID
var drop_rate: float = 0.5         # 掉落概率（0-1）
var count_min: int = 1             # 最小数量
var count_max: int = 3             # 最大数量

## 掉落表
var drop_table: Array[DropConfig] = []
```

---

## 七、开发顺序

### 7.1 Phase 1：基础战斗框架（第1周）

**目标**: 实现玩家攻击和基础伤害

**任务清单**:

| 序号 | 任务 | 文件 | 依赖 |
|------|------|------|------|
| 1 | 创建 combat 目录结构 | - | 无 |
| 2 | 实现 CombatManager | combat_manager.gd | 无 |
| 3 | 实现 DamageSystem | damage_system.gd | 无 |
| 4 | 实现 HealthSystem | health_system.gd | 无 |
| 5 | 修改 player_controller.gd | 添加攻击输入 | 无 |
| 6 | 创建攻击区域（Area2D） | player.tscn | 无 |

**验收标准**:
- 玩家可以按下攻击键
- 攻击会检测前方区域
- 有简单的攻击反馈（日志输出）

### 7.2 Phase 2：子弹系统（第2周）

**目标**: 实现远程武器和子弹

**任务清单**:

| 序号 | 任务 | 文件 | 依赖 |
|------|------|------|------|
| 1 | 实现 BulletSystem | bullet_system.gd | Phase 1 |
| 2 | 创建子弹场景 | bullet.tscn | 无 |
| 3 | 实现子弹脚本 | bullet.gd | 无 |
| 4 | 实现对象池 | bullet_system.gd | 无 |
| 5 | 实现伤害数字 | damage_number.tscn/gd | 无 |
| 6 | 集成 WeaponSystem | weapon_system.gd | Phase 1 |

**验收标准**:
- 远程武器可以发射子弹
- 子弹会检测碰撞
- 命中后显示伤害数字

### 7.3 Phase 3：怪物基础（第3周）

**目标**: 实现怪物实体和基础AI

**任务清单**:

| 序号 | 任务 | 文件 | 依赖 |
|------|------|------|------|
| 1 | 创建 enemy 目录结构 | - | 无 |
| 2 | 实现 MonsterBase | monster_base.gd | Entity |
| 3 | 创建怪物基类场景 | monster_base.tscn | 无 |
| 4 | 实现 MonsterAI（基础） | monster_ai.gd | 无 |
| 5 | 创建哥布林怪物 | goblin.tscn | MonsterBase |
| 6 | 实现怪物血条 | monster_health_bar.gd | 无 |
| 7 | 集成 HealthSystem | - | Phase 1 |

**验收标准**:
- 怪物可以在房间中生成
- 怪物会检测玩家并追击
- 怪物会攻击玩家
- 怪物死亡后会掉落物品

### 7.4 Phase 4：怪物生成系统（第4周）

**目标**: 实现房间怪物生成和战斗流程

**任务清单**:

| 序号 | 任务 | 文件 | 依赖 |
|------|------|------|------|
| 1 | 实现 MonsterSpawner | monster_spawner.gd | Phase 3 |
| 2 | 实现 MonsterSystem | monster_system.gd | Phase 3 |
| 3 | 修改 RoomManager | 添加战斗状态 | Phase 3 |
| 4 | 实现房间门/锁逻辑 | room_manager.gd | 无 |
| 5 | 集成 ObjectManager | 添加怪物管理 | 无 |
| 6 | 实现掉落系统 | drop_system.gd | 无 |

**验收标准**:
- 进入房间后自动生成怪物
- 门会关闭直到怪物清除
- 怪物清除后门会开启
- 怪物死亡会掉落物品

### 7.5 Phase 5：怪物类型扩展（第5周）

**目标**: 实现多种怪物类型

**任务清单**:

| 序号 | 任务 | 文件 | 依赖 |
|------|------|------|------|
| 1 | 实现 MeleeMonster | melee_monster.gd | Phase 3 |
| 2 | 实现 RangedMonster | ranged_monster.gd | Phase 3 |
| 3 | 创建骷髅怪物 | skeleton.tscn | MeleeMonster |
| 4 | 创建蝙蝠怪物 | bat.tscn | MeleeMonster |
| 5 | 创建弓箭手怪物 | archer.tscn | RangedMonster |
| 6 | 完善 MonsterAI | 支持多种AI类型 | Phase 3 |

**验收标准**:
- 至少3种不同类型的怪物
- 近战怪物会接近攻击
- 远程怪物会保持距离射击
- 不同怪物有不同的属性

### 7.6 Phase 6：Boss系统（第6周）

**目标**: 实现Boss怪物

**任务清单**:

| 序号 | 任务 | 文件 | 依赖 |
|------|------|------|------|
| 1 | 实现 BossMonster | boss_monster.gd | Phase 3 |
| 2 | 实现 EliteMonster | elite_monster.gd | Phase 3 |
| 3 | 创建哥布林王Boss | boss_goblin_king.tscn | BossMonster |
| 4 | 实现Boss多阶段AI | boss_monster.gd | 无 |
| 5 | 实现Boss特殊技能 | boss_monster.gd | 无 |
| 6 | 集成Boss房间逻辑 | room_manager.gd | Phase 4 |

**验收标准**:
- Boss怪物有独特外观
- Boss有多个战斗阶段
- Boss有特殊技能
- 击败Boss后有特殊奖励

---

## 八、风险与注意事项

### 8.1 技术风险

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| 碰撞检测性能 | 🟡 中 | 使用对象池，限制子弹数量 |
| AI 寻路复杂度 | 🟡 中 | 先用简单方案，后期优化 |
| 怪物数量过多 | 🟡 中 | 限制同屏怪物数量 |
| 信号连接混乱 | 🟢 低 | 统一在 CombatManager 管理 |

### 8.2 兼容性风险

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| Entity 系统冲突 | 🟢 低 | 继承而非修改 |
| ObjectManager 冲突 | 🟢 低 | 扩展而非重写 |
| 现有功能破坏 | 🟢 低 | 充分测试 |

### 8.3 开发风险

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| 开发时间不足 | 🟡 中 | 优先实现核心功能 |
| 美术资源缺失 | 🟢 低 | 使用占位符 |
| 测试不充分 | 🟡 中 | 每个Phase进行测试 |

---

## 九、总结

### 9.1 设计要点

1. **模块化设计**: CombatSystem、MonsterSystem 独立模块
2. **信号驱动**: 使用 Godot 信号解耦系统
3. **数据驱动**: 怪物属性来自 MonsterData
4. **兼容现有**: 继承 Entity，扩展 ObjectManager
5. **渐进开发**: 6个Phase，每周一个里程碑

### 9.2 预期成果

完成本设计后，游戏将具备：
- ✅ 玩家可以攻击（近战/远程）
- ✅ 怪物可以生成和战斗
- ✅ 完整的伤害计算系统
- ✅ 房间战斗流程
- ✅ Boss战斗
- ✅ 掉落系统

### 9.3 后续扩展

完成战斗和怪物系统后，可以继续：
- 技能系统
- 装备系统完善
- AI动态生成
- 美术资源替换
- 音效系统

---

**文档完成时间**: 2026-07-13
**设计依据**: 项目状态分析报告
**下一步**: 按照开发顺序开始 Phase 1

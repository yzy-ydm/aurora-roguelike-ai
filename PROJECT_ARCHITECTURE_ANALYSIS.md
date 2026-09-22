# Aurora-Roguelike-AI 项目架构分析

> 分析日期：2026-09-22
> 分析目标：为Phase 2开发提供完整架构参考
> 禁止修改代码 — 仅分析

---

## 一、项目整体架构

### 1.1 代码规模

| 层级 | 文件数 | 说明 |
|------|--------|------|
| **服务端 (Python)** | ~30个.py | FastAPI + AI服务 + 数据库 |
| **客户端 (Godot)** | 98个.gd | GDScript脚本 |
| **场景文件** | 19个.tscn | 场景定义 |
| **文档** | 30+个.md | 设计文档、审计报告 |

### 1.2 核心目录结构

```
D:\GraduationProject\
├── server/                      # FastAPI + AI服务
│   ├── ai/
│   │   ├── api/                 # AI路由 (8001端口)
│   │   ├── services/            # AI服务核心
│   │   │   ├── ai_service.py    # 主生成服务
│   │   │   ├── ai_validator.py  # 内容验证
│   │   │   ├── ai_quality_checker.py  # 质量检查
│   │   │   ├── monster_balance.py  # 怪物平衡配置 (Task1新增)
│   │   │   ├── provider_factory.py  # Provider工厂
│   │   │   ├── agnes_provider.py    # Agnes AI
│   │   │   ├── mimo_client.py       # MiMo API
│   │   │   └── prompt_builder.py    # Prompt模板
│   │   ├── cache/               # 缓存管理
│   │   └── tests/               # 143个测试用例
│   └── app/                     # 主FastAPI (8000端口)
│       ├── api/                 # 业务路由
│       └── database/            # SQLAlchemy ORM
│
├── client/                      # Godot 4.7 客户端
│   ├── scripts/
│   │   ├── player/              # 玩家系统
│   │   │   ├── player_controller.gd  # 输入+移动+战斗
│   │   │   └── player_stats.gd       # 属性(HP/ATK/EXP/Level)
│   │   ├── combat/              # 战斗系统
│   │   │   ├── weapon.gd          # 武器节点(发射控制)
│   │   │   ├── weapon_instance.gd   # 武器实例(等级/伤害计算)
│   │   │   ├── bullet.gd          # 子弹(移动+碰撞)
│   │   │   └── damage_system.gd   # 伤害计算(防御/暴击)
│   │   ├── enemy/               # 怪物系统
│   │   │   ├── monster_entity.gd  # 怪物数据(HP/ATK/DEF)
│   │   │   ├── monster_node.gd    # 怪物物理+渲染
│   │   │   └── monster_ai.gd      # AI状态机(IDLE/CHASE/ATTACK)
│   │   ├── models/              # 数据模型
│   │   │   ├── weapon_data.gd     # 武器数据
│   │   │   ├── reward_data.gd     # 奖励数据(含WEAPON_DEFS)
│   │   │   ├── monster_data.gd    # 怪物数据
│   │   │   └── room_content_data.gd  # 房间内容
│   │   ├── world/               # 世界系统
│   │   │   ├── floor_generator.gd  # 楼层生成
│   │   │   ├── floor_manager.gd    # 楼层管理
│   │   │   ├── room_renderer.gd    # 平台渲染
│   │   │   └── room_spawner.gd     # 怪物/奖励生成
│   │   ├── drop/                # 掉落系统
│   │   │   ├── reward_item.gd     # 奖励物品
│   │   │   └── drop_manager.gd    # 掉落管理
│   │   ├── inventory/           # 背包
│   │   │   ├── inventory_manager.gd
│   │   │   └── equipment_manager.gd
│   │   └── ui/                  # UI系统
│   │       ├── hud_controller.gd
│   │       ├── level_up_panel.gd
│   │       └── boss_health_bar.gd
│   └── scenes/                  # 场景定义
│       ├── game/game_scene.tscn    # 主游戏场景
│       ├── game/hud.tscn           # HUD
│       └── ...
│
└── CURRENT_GAMEPLAY_ANALYSIS.md  # 上一版分析报告
```

---

## 二、当前游戏完整流程

```
[登录] login_scene.gd
  → API POST /auth/login → JWT Token
  → GameStateManager → SceneManager.go_to_game()

[游戏初始化] game_scene.gd._ready()
  → _init_gameplay_systems()
    → DamageSystem + AIContentService + FloorManager
    → CombatManager + UpgradeManager + SaveSystem
  → _floor_manager.generate_floor(1)

[楼层生成] floor_generator.gd
  → 生成8-12个RoomNodeData
  → 主路径4-6个房间 + 分支 + 最后Boss
  → 房间类型随机概率(见下文)

[进入房间] game_scene.gd._on_fm_room_entered(room)
  → content.finalize()  // 锁定内容防止AI覆盖
  → 判断: Boss? → _start_boss_fight()
  → 判断: monster_count > 0? → spawn_monsters() → start_combat()
  → monster_count == 0? → _create_room_exits()  // ← BUG: reward/event/treasure都走这里

[战斗] combat_manager.gd
  → spawn_monsters() 从ResourceService获取MonsterData
  → 每个怪物: MonsterEntity.set_monster_data() → set_monster_node()
  → 玩家点击鼠标 → _try_attack() → weapon.try_attack()
  → Weapon创建Bullet → Bullet移动 → 碰撞MonsterNode
  → DamageSystem.on_bullet_hit() → calculate_damage() → monster.take_damage()
  → 怪物死亡 → RoomSpawner.on_monster_died() → CombatManager._on_all_monsters_dead()
  → 延迟1秒 → REWARD状态 → spawn_rewards()

[奖励拾取] reward_item.gd
  → 碰撞检测(body_entered) → _collect()
  → reward_data.apply_to_player(player)
  → emit reward_collected → RoomSpawner._on_reward_collected()
  → all_rewards_collected → CombatManager.complete_reward_phase()

[升级] upgrade_manager.gd
  → 怪物死亡→ get_experience_reward() → add_experience()
  → PlayerStats.gain_exp() → _level_up()
  → upgrade_selection_required → LevelUpPanel → 玩家选择 → apply_upgrade()

[Boss战] boss_controller.gd
  → spawn_boss() 创建BossEntity + BossController
  → Boss独立状态机，多阶段切换
  → boss_defeated → 独立奖励流程 → 下一层传送门

[离开房间] Portal Area2D
  → body_entered → game_scene._on_exit_portal_entered(target_id)
  → FloorManager.enter_room(target_id)

[下一层] boss killed → next_floor_portal
  → fade out → generate_next_floor() → fade in
```

---

## 三、数据流深度追踪

### 3.1 武器数据流 (断点分析)

```
起点: ResourceService.get_weapons()
  → 返回 WeaponData[] (默认: 铁剑id=1, 短弓id=2)

游戏开始: player._load_weapon_data()
  → weapon_data = weapons[0]  // 铁剑
  → WeaponInstance.create(weapon_data)  // Lv1, damage=10
  → _weapon.set_weapon_instance(instance)
  → [Weapon] Loaded weapon: 铁剑 Lv1

攻击流程:
  player._try_attack()
    → _weapon.try_attack(direction)
      → _fire(direction)
        → current_damage = _weapon_instance.get_damage()  // = 10
        → bullet.setup(current_damage, ...)
        → bullet.damage = 10

伤害计算:
  DamageSystem.on_bullet_hit(bullet, target)
    → attacker_attack = source.get_attack()
      → player.get_attack()
        → return base_attack + weapon_instance.get_damage()
        → return 10 + 10 = 20

[武器效果完全生效 ✓]

=== 断点：拾取新武器 ===

RewardData (NEW_WEAPON type):
  → reward.weapon_id = 2 (火焰步枪)
  → reward.apply_to_player(player)
    → player.equip_new_weapon(2)
      → equip_new_weapon(): weapon_id=2 > 0
        → print("TODO: Multi-weapon system not yet implemented")
        → return upgrade_weapon()  // ← BUG! 走升级分支!
          → weapon_instance.upgrade()  // 只是升级现有武器

[结果: 玩家永远只有铁剑, 火焰步枪从未被使用]
```

### 3.2 Reward房间数据流 (断点分析)

```
进入Reward房间:
  game_scene.gd._on_fm_room_entered(room)
    → room.room_type == REWARD
    → content = room.content
    → content.monster_count = 0  // Reward房没有怪物
    → content.finalize()

  if room.room_type == BOSS:  // false
  if content.monster_count > 0:  // false (0)
    → else: _create_room_exits()  // ← BUG! 只创建出口，没有奖励!

[结果: 玩家进入Reward房 → 看到空平台 → 走到出口离开]
```

### 3.3 Event房间数据流 (断点分析)

```
同Reward房间:
  room.room_type == EVENT
  content.monster_count = 0
  → _create_room_exits()  // 没有任何事件处理!

[结果: Event房 = 空房]
```

### 3.4 平台高度可行性分析

```
玩家跳跃物理:
  GRAVITY = 980 px/s²
  JUMP_FORCE = -400 px/s
  最大跳跃高度 = v²/(2g) = 400²/(2×980) = 160000/1960 ≈ 81.6 px

需要: 相邻平台高度差 ≤ 81px (安全余量: 建议 ≤ 70px)

实际平台坐标 (相对GROUND_Y):
  Combat:    p1(y=100), p2(y=0), p3(y=-120)  →  gap=100px ❌
  Elite:     p1(y=80),  p2(y=20), p3(y=80), p4(y=-100) → gap=180px ❌
  Boss:      p1(y=60),  p2(y=60), p3(y=-60) → gap=120px ❌
  Reward:    p1(y=50),  p2(y=-50), p3(y=-50) → gap=100px ❌
  Shop:      p1(y=60),  p2(y=60) → OK (同一高度)
  Event:     p1(y=30) → OK (单层)
  Treasure:  p1(y=80),  p2(y=-40) → gap=120px ❌

结论: 6个房间类型的平台有跳跃困难
```

---

## 四、未完成模块详细分析

### 4.1 武器系统闭环 (P0)

**当前状态：**
- `WeaponData`: 定义了id, name, damage, fire_rate等 ✓
- `WeaponInstance`: 支持等级成长，damage = base + growth*(level-1) ✓
- `Weapon`: 发射控制，cooldown，支持weapon_instance ✓
- `InventoryManager`: 管理武器列表 ✓
- `EquipmentManager`: 装备/卸下武器 ✓

**缺失：**
1. `PlayerController.equip_new_weapon()` 是TODO，未实现多武器切换
2. 没有 `_weapon_inventory: Array[WeaponInstance]` 存储多个武器
3. 没有 `_active_weapon_index: int` 跟踪当前装备
4. `RewardItem`拾取后不创建WeaponObject
5. `WeaponObject`已实现但游戏中从未生成/放置

**修复方案：**
- 在PlayerController中添加武器库存管理
- 重写equip_new_weapon()创建新WeaponInstance并添加到库存
- 添加switch_weapon()方法
- 武器切换时更新_weapon节点的数据

### 4.2 Reward房间 (P0)

**当前状态：**
- `RoomContentData.reward_count`: 奖励数量 ✓
- `RoomContentData.reward_quality`: 奖励品质 ✓
- `RoomSpawner.spawn_rewards()`: 生成奖励物品 ✓
- `RewardItem`: 碰撞检测+拾取+应用奖励 ✓
- `RewardData`: 8种奖励类型定义 ✓

**缺失：**
1. `game_scene.gd` 进入Reward房时不调用spawn_rewards()
2. `game_scene.gd` 没有Reward房专属处理分支

**修复方案：**
- 在`_on_fm_room_entered()`中添加Reward房分支
- 调用`_room_spawner.spawn_rewards(content, room.position)`
- 等待所有奖励收集后创建出口(现有逻辑已支持)

### 4.3 Event房间 (P0)

**当前状态：**
- `AIContentService.generate_context_event()`: AI生成事件 ✓
- `game_scene._on_ai_event_received()`: 接收AI事件 ✓
- `AIEventPanel`: 事件展示UI ✓

**缺失：**
1. Event房进入后没有触发事件面板的机制
2. 事件选择后没有应用效果

**修复方案：**
- Event房进入时自动触发事件面板
- 实现3种事件: merchant(回复生命)、treasure(获得金币)、altar(属性交换)
- 事件选择后应用效果并创建出口

### 4.4 房间生成规则 (P1)

**当前状态：**
- `FloorGenerator._get_random_room_type()`: 纯随机概率 ✓
- 前2层: combat 60%, reward 20%, event 10%, treasure 10%
- 后期: combat 40%, reward 20%, elite 10%, event 10%, shop 10%, treasure 10%

**问题：**
- 可能连续出现2个reward或event
- 没有保证Boss前有战斗房

**修复方案：**
- 添加防连续规则：上一个是reward则下一个不能是reward
- 保证最后3个房间中有至少1个combat + 1个boss

### 4.5 平台高度 (P1)

**当前状态：**
- 平台Y坐标硬编码在room_renderer.gd中
- 最高平台Y=100，超出玩家跳跃能力(81px)

**修复方案：**
- 所有平台Y坐标限制在±60范围内
- 确保相邻平台高度差≤60px

### 4.6 EXP多级升级 (P1)

**当前状态：**
- `PlayerStats.gain_exp()`: 只升1级
- 多余EXP留在`experience`字段

**修复方案：**
- 改为while循环，支持连续升级
- HUD显示前clamp经验值

---

## 五、Phase 2 开发计划

### Phase A: 武器系统闭环
**修改文件：**
- `player_controller.gd` — 添加_weapon_inventory + _active_weapon_index + 重写equip_new_weapon
- `weapon.gd` — 添加weapon_type可视化
- `bullet.gd` — 根据武器类型改变子弹颜色
- `hud_controller.gd` — 显示当前武器名称
- `reward_data.gd` — 已有WEAPON_DEFS，直接使用

**风险：** 中 — 涉及战斗核心

### Phase B: Reward房间
**修改文件：**
- `game_scene.gd` — 添加Reward房分支处理

**风险：** 低 — 仅添加新分支

### Phase C: Event房间
**修改文件：**
- `game_scene.gd` — 添加Event房分支处理
- 新建 `event_panel.gd` — 事件UI

**风险：** 低 — 独立系统

### Phase D: 房间生成规则
**修改文件：**
- `floor_generator.gd` — 替换随机逻辑为带约束的生成

**风险：** 低 — 纯生成逻辑

### Phase E: 平台高度限制
**修改文件：**
- `room_renderer.gd` — 调整所有平台Y坐标

**风险：** 极低 — 纯数值调整

### Phase F: EXP多级升级
**修改文件：**
- `player_stats.gd` — gain_exp改为while循环

**风险：** 极低 — 单行代码修改

---

## 六、关键设计决策建议

### 武器系统
- **不实现**复杂武器切换UI（快捷键Q切换即可）
- **实现**拾取自动装备第一条新武器
- **保持**武器升级系统不变（作为强化选项）

### Reward房
- **复用**现有spawn_rewards()逻辑
- **不新建**奖励选择UI（直接掉落拾取即可）
- **保持**与战斗房相同的奖励拾取流程

### Event房
- **实现**简单事件面板（文本+选择按钮）
- **事件效果**直接修改PlayerStats
- **不实现**复杂NPC对话系统

### 房间生成
- **最小改动**：在现有概率基础上添加"不能连续同类房间"规则
- **保证**Boss前至少有1个combat房

### 平台
- **修改坐标**：所有Y值压缩到±60范围内
- **不改变**平台宽度逻辑

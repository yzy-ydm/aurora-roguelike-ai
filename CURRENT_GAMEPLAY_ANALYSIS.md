# Aurora-Roguelike-AI 当前游戏流程分析

> 生成日期：2026-09-22
> 作者：Agnes (Sapiens AI)
> 项目版本：v0.9.0-alpha + Task1修复

---

## 一、当前完整游戏流程

```
登录场景
  ↓ HTTP POST /auth/login
  ↓ JWT Token
  ↓ GameStateManager.set_state(EXPLORATION)
  ↓ SceneManager.go_to_game()

游戏场景 (GameScene)
  ↓ _init_gameplay_systems()
    ├── DamageSystem
    ├── AIContentService (异步初始化)
    ├── FloorManager
    │     ├── FloorGenerator (本地随机生成房间结构)
    │     ├── RoomRenderer (视觉生成)
    │     └── RoomSpawner (怪物/奖励生成)
    ├── CombatManager
    ├── UpgradeManager
    ├── SaveSystem
    └── AI Adaptive Systems (BehaviorAnalyzer, AIContextManager...)

  ↓ _floor_manager.generate_floor(1)
    ↓ FloorGenerator.generate_floor()
      → 生成8-12个RoomNodeData
      → 确定房间类型（随机概率）
      → 建立连接关系
      → Boss房间固定末尾

  ↓ FloorManager.enter_room(0) [起始房间]
    ↓ _ensure_room_content(room)
      → room.content = RoomContentData.from_room_node()  (本地默认)
      → 后台请求AI内容 (_request_room_content_ai)
      → AI结果 arrives → 覆盖room.content（如果未finalize）
    ↓ RoomRenderer.render_room(room)
      → 渲染平台、背景、边界墙
      → 根据房间类型调用不同布局函数
    ↓ game_scene._on_fm_room_entered(room)
      → 锁定玩家位置
      → 重置CombatManager
      → 检查Boss房间 → _start_boss_fight()
      → 检查monster_count > 0 → spawn_monsters() → start_combat()
      → monster_count == 0 → _create_room_exits()

[战斗流程]
  RoomSpawner.spawn_monsters()
    → 从ResourceService.get_monsters()获取MonsterData数组
    → 遍历生成每个怪物
    → MonsterEntity.set_monster_data(monster_data)
    → _apply_level_modifier (已禁用，服务端已处理)
  CombatManager.start_combat(content)
    → 状态机: IDLE → ENTERING → COMBAT
  玩家点击鼠标 → _try_attack() → Weapon.try_attack()
    → 创建Bullet节点，设置damage/speed/direction
    → Bullet移动 → 碰撞检测
    → DamageSystem.on_bullet_hit() → calculate_damage()
    → MonsterNode.take_damage() → MonsterEntity.take_damage()
    → 死亡 → on_death() → RoomSpawner.on_monster_died()
    → 所有怪物死亡 → CombatManager._on_all_monsters_dead()
    → 延迟1秒 → REWARD状态
  game_scene._on_combat_cleared()
    → spawn_rewards(content, room_pos)
    → create_exit_portal()

[奖励拾取]
  RewardItem _on_body_entered() → _collect()
    → reward_data.apply_to_player(player)
    → emit reward_collected signal
  RoomSpawner._on_reward_collected()
    → 从列表移除，检查是否全部收集
    → all_rewards_collected signal
  game_scene._on_all_rewards_collected()
    → CombatManager.complete_reward_phase()

[离开房间]
  玩家进入Portal Area2D
  → game_scene._on_exit_portal_entered(target_id)
  → FloorManager.enter_room(target_id)

[Boss战斗]
  game_scene._start_boss_fight(room)
    → _create_boss_data_for_room() (Boss公式: HP=400+floor*80)
    → RoomSpawner.spawn_boss(boss_data, room_center)
    → BossController创建
    → CombatManager.start_boss_fight()
  Boss死亡 → boss_defeated signal
    → CombatManager.on_boss_defeated()
    → 标记房间完成
    → 延迟 → REWARD状态
  game_scene._on_boss_defeated()
    → spawn_boss_rewards()
    → _on_floor_completed() → _create_next_floor_portal()

[升级]
  怪物死亡 → game_scene._on_monster_died_for_exp()
    → UpgradeManager.add_experience(exp_reward)
    → PlayerStats.gain_exp() → level_up()
    → upgrade_selection_required signal
    → LevelUpPanel.show_upgrade_panel(options)
    → 玩家选择 → UpgradeManager.apply_upgrade()
    → PlayerStats属性修改

[下一层]
  Boss房间完成 → 传送门生成
  玩家进入 → game_scene._on_next_floor_portal_entered()
    → 淡出 → generate_next_floor()
    → 淡入 → 新楼层开始

[存档/读档]
  暂停菜单 → SaveSelection
    → SaveService.save_game(slot, data)
    → SaveService.load_game(slot)
      → GameStateManager.restore_from_save()
      → GameStateManager.set_state(LOGIN)
```

---

## 二、已完成模块

### 核心系统 (已完成且可运行)
| 模块 | 文件 | 状态 | 说明 |
|------|------|------|------|
| 登录认证 | login_scene.gd, api_client.gd | ✅ | JWT Token，REST API |
| 玩家移动 | player_controller.gd | ✅ | 横版平台移动+跳跃+冲刺 |
| 战斗系统 | combat_manager.gd, damage_system.gd | ✅ | 伤害计算、防御减伤、暴击 |
| 武器攻击 | weapon.gd, weapon_instance.gd, bullet.gd | ✅ | 冷却控制、子弹发射 |
| 怪物AI | monster_ai.gd, monster_node.gd | ✅ | IDLE/CHASE/ATTACK状态机 |
| 怪物实体 | monster_entity.gd, monster_data.gd | ✅ | HP/ATK/DEF属性管理 |
| 房间生成 | floor_generator.gd, room_spawner.gd | ✅ | 平台布局、怪物/奖励生成 |
| Boss系统 | boss_controller.gd, boss_data.gd | ✅ | 多阶段、技能、独立战斗流程 |
| 升级系统 | upgrade_manager.gd, level_up_panel.gd | ✅ | EXP积累、升级选项、强化应用 |
| 存档系统 | save_system.gd, game_state_manager.gd | ✅ | 本地JSON存档 |
| 奖励拾取 | reward_item.gd, drop_manager.gd | ✅ | 碰撞检测、奖励应用、视觉效果 |

### AI系统 (已完成且测试通过)
| 模块 | 文件 | 状态 | 说明 |
|------|------|------|------|
| Provider架构 | agnes_provider.py, mimo_client.py | ✅ | 多Provider支持 |
| 工厂模式 | provider_factory.py | ✅ | 统一创建入口 |
| 内容生成 | ai_service.py | ✅ | 楼层/房间/怪物/武器/事件 |
| 验证器 | ai_validator.py | ✅ | JSON格式+数值范围校验 |
| 质量检查 | ai_quality_checker.py | ✅ | 平衡性评分 |
| 缓冲器 | cache_manager.py | ✅ | 楼层/房间/怪物/武器缓存 |
| Prompt构建 | prompt_builder.py | ✅ | 6类Prompt模板 |
| MonsterBalance | monster_balance.py | ✅ | 统一数值配置 (Task1新增) |

### 测试
| 套件 | 数量 | 状态 |
|------|------|------|
| server AI测试 | 143 passed | ✅ |
| Godot客户端测试 | test_weapon_growth.gd | 存在但未集成到CI |

---

## 三、未完成模块

### P0 — 核心体验断点

| # | 问题 | 影响 | 位置 |
|---|------|------|------|
| 1 | **Reward房间无实际奖励** | 进入奖励房 → 只看到平台 → 可以走出去，没有任何奖励UI或掉落 | game_scene.gd:592-599 |
| 2 | **武器拾取不切换武器** | equip_new_weapon()是TODO，全部降级为升级当前武器 | player_controller.gd:544-560 |
| 3 | **Event房间无交互** | 事件房生成后直接变成"空战斗房"，没有事件面板 | game_scene.gd:586-599 |
| 4 | **WeaponObject拾取链断裂** | WeaponObject已实现但游戏场景中从未放置/激活 | object_manager.gd, weapon_object.gd |
| 5 | **不可达平台高度** | 某些平台Y坐标超过玩家跳跃极限 | room_renderer.gd:251-328 |

### P1 — 缺失功能

| # | 问题 | 说明 |
|---|------|------|
| 6 | **商店房无购买逻辑** | SHOP房间生成但无NPC/购买界面 |
| 7 | **Treasure房无宝箱互动** | TREASURE房间只生成平台，无宝箱对象 |
| 8 | **HUD武器显示缺失** | HUD不显示当前武器名称和伤害 |
| 9 | **武器切换UI缺失** | 没有快捷键或UI让玩家的武器发生变化 |
| 10 | **EXP显示超限** | 多次升级时HUD经验条可能显示 >100% |

---

## 四、数据流

### 怪物数据流
```
FloorGenerator (本地随机)
  → RoomNodeData[] (房间结构)
    → FloorManager.convert_to_floor_data()
      → NewRoomData[] (统一模型)
        → FloorData.current_floor
          → RoomContentManager.generate_content_for_room()
            → AIContentService.generate_room_content()
              → Server AI (Mock/Agnes/Mimo)
                → RoomContentData (monster_count, monster_types, monster_level)
                  → game_scene._on_fm_room_entered()
                    → RoomSpawner.spawn_monsters(content, room_pos)
                      → ResourceService.get_monsters() (默认数据)
                      → _get_monster_by_config() (匹配类型)
                      → MonsterData.from_dict(server_data)
                      → MonsterEntity.set_monster_data()
                      → [Task1修复后] 不再二次倍率修正
```

### 奖励数据流
```
RoomContentData.reward_count + reward_quality
  → RoomSpawner.spawn_rewards(content, room_pos)
    → _generate_reward_from_strategy() 或 RewardData.generate_random_reward()
    → RewardItem.set_reward_data()
    → RewardItem._on_body_entered() → _collect()
      → RewardData.apply_to_player(player)
        → match type: GOLD/ATTACK_UP/HEALTH_UP/HEAL/NEW_WEAPON/WEAPON_UPGRADE/ATTRIBUTE_BOOST/PASSIVE_ITEM
          → player.add_gold() / player.add_attack() / player.heal() / player.equip_new_weapon()
```

### 武器数据流 (当前断裂点)
```
ResourceService.get_weapons() [初始加载铁剑/短弓]
  → player._load_weapon_data()
    → WeaponInstance.create(weapons[0])
    → weapon.set_weapon_instance(instance)
    → 默认: basic_gun damage=20, fire_rate=0.2

[Reward] NEW_WEAPON奖励
  → player.equip_new_weapon(weapon_id)
    → equip_new_weapon(): weapon_id=1/2/3/4 → 走upgrade_weapon()分支 ← 断点!
    → 应该: 创建WeaponInstance + 添加到_inventory + 切换_active

[Weapon切换] 未实现
```

---

## 五、AI参与位置

```
游戏开始时:
  FloorManager.generate_floor(1)
    → 本地生成房间结构 (确定性)
    → 后台请求AI楼层内容 (_request_ai_background)
      → AIContentService.generate_floor_content()
        → Server AI: generate_floor(floor=1, player=1)
          → 返回: {floor, room_count, rooms: [{id, type, monsters, rewards, chests}]}
        → 本地验证 → 解析为RoomNodeData[]
        → 不覆盖已生成的本地楼层 (仅作为补充)

进入房间时:
  FloorManager.enter_room(id)
    → _ensure_room_content(room)
      → AI生成房间内容 (异步后台)
        → Server AI: generate_room_content(room_id, room_type, floor, player)
          → 返回: {room_id, room_type, monsters: [{id, count, health, attack...}], rewards: {...}}
        → AIValidator.validate_room_content(result, floor_level)  ← Task1已修复动态约束
        → 如果房间未finalize → 更新room.content
        → 如果已finalize → 丢弃AI结果 (防止覆盖已开始战斗的房间)

战斗中:
  无AI参与 (纯本地逻辑)

升级时:
  UpgradeManager._generate_upgrade_options()
    → AI生成强化选项 (异步)
      → Server AI: generate_upgrade(player_level, player_stats)
        → 返回: {upgrades: [{id, name, description, type, rarity, modifiers}]}
    → 如果AI失败 → 使用本地_pool

事件房:
  FloorManager._request_ai_room_content()
    → Server AI: generate_context_event(context)
    → 返回事件数据 → ai_event_received signal
    → game_scene._show_ai_event() → AIEventPanel.show_event()
```

---

## 六、当前Bug列表

### Bug 1: Reward房间空转
- **现象**: 玩家进入"奖励房间"后，没有奖励物品出现，直接走到出口离开
- **根因**: `game_scene.gd:592-599` — 当 `content.monster_count == 0` 时只调用 `_create_room_exits()`
- **代码**:
```gdscript
if content.monster_count > 0:
    var monster_count = _room_spawner.spawn_monsters(content, room_pos)
    if monster_count > 0:
        _combat_manager.start_combat(content)
    else:
        _create_room_exits()  # ← reward/event/treasure room 都走这里
else:
    _create_room_exits()
```
- **影响**: 所有非战斗房间(奖励/事件/宝箱)都完全没有功能

### Bug 2: 武器系统不闭环
- **现象**: 拾取武器奖励后只是升级现有武器，不会获得新武器
- **根因**: `player_controller.gd:544-560` — `equip_new_weapon()` 是TODO
- **影响**: 玩家永远只有一把武器

### Bug 3: Event房间无交互
- **现象**: 进入事件房后没有任何事件触发
- **根因**: 同上 — `monster_count == 0` 时只创建出口
- **影响**: Event房间和普通空房没有区别

### Bug 4: 不可达平台
- **现象**: 玩家无法到达某些高处平台
- **根因**: `room_renderer.gd:251-328` — 部分平台Y坐标超出跳跃极限
- **详情**: 最大跳跃高度约33像素，但某些平台在Y=80-120位置
- **影响**: 玩家无法到达某些区域

### Bug 5: EXP超限显示
- **现象**: 一次性获得大量EXP时，HUD经验条可能显示>100%
- **根因**: `player_stats.gd:140-149` — 只升1级，多余EXP留在`experience`字段
- **影响**: 视觉上不精确但不会崩溃

---

## 七、下一阶段开发计划 (Phase 2)

### Phase 2.1: Reward房间闭环
**目标**: 进入奖励房后自动弹出奖励选择UI，玩家选择后应用属性变化

**方案**:
1. 在 `game_scene.gd` 中检测Reward房间类型
2. 进入Reward房时自动生成3个奖励选项（无需MonsterSpawner）
3. 创建 `RewardChoicePanel` 显示选项
4. 玩家选择后 → `reward.apply_to_player(player)` → 关闭面板 → 创建出口

**修改文件**:
- `client/scenes/game/game_scene.gd` — 添加Reward房处理逻辑
- `client/scripts/ui/reward_choice_panel.gd` — 新建奖励选择UI
- `client/scripts/models/reward_data.gd` — 已有RewardType枚举，直接使用

**风险**: 低 — 仅添加新分支，不影响战斗系统

---

### Phase 2.2: 武器系统闭环
**目标**: 实现多武器切换，不同武器有不同伤害和外观

**方案**:
1. 在 `PlayerController` 中添加 `_weapon_inventory` 和 `_active_weapon_index`
2. 重写 `equip_new_weapon()` — 创建WeaponInstance并添加到库存
3. 添加 `switch_weapon(index)` 方法
4. 在 `weapon.gd` 中根据武器类型改变子弹颜色
5. HUD显示当前武器名称和伤害
6. 支持4种武器: 铁剑(基础)、火焰枪(红弹高伤)、冰霜法杖(蓝弹减速)、雷霆弓(紫弹暴击)

**修改文件**:
- `client/scripts/player/player_controller.gd` — 武器库存管理
- `client/scripts/combat/weapon.gd` — 武器类型特效
- `client/scripts/combat/bullet.gd` — 子弹颜色根据武器类型
- `client/scripts/ui/hud_controller.gd` — 显示当前武器
- `client/scripts/combat/weapon_instance.gd` — 增加weapon_type字段

**风险**: 中 — 涉及战斗核心代码，需要测试兼容性

---

### Phase 2.3: Event房间系统
**目标**: 实现事件房的基本交互

**方案**:
1. 定义3种事件类型: merchant(商人)、treasure(宝箱)、altar(祭坛)
2. 创建 `EventPanel` 显示事件文本和选择
3. 在 `game_scene.gd` 中检测Event房间 → 显示事件面板
4. 玩家选择后 → 应用效果 → 关闭面板 → 创建出口

**修改文件**:
- `client/scripts/ui/event_panel.gd` — 新建事件面板
- `client/scenes/game/game_scene.gd` — 添加Event房处理

**风险**: 低 — 独立系统，不影响战斗

---

### Phase 2.4: 房间生成规则优化
**目标**: 确保每层房间类型比例合理

**方案**:
1. 修改 `FloorGenerator._get_random_room_type()` 为确定性分布
2. 固定比例: start=1, combat=6, reward=1, event=1, boss=1, 其余filler
3. 总房间数保持8-12个

**修改文件**:
- `client/scripts/world/floor_generator.gd` — 替换随机逻辑

**风险**: 低 — 纯生成逻辑变更

---

### Phase 2.5: 平台高度限制
**目标**: 确保所有平台可到达

**方案**:
1. 计算玩家最大跳跃高度: `JUMP_FORCE²/(2*GRAVITY) ≈ 32.7px`
2. 限制平台最大高度差为25px（留安全余量）
3. 修改所有 `_create_*_platforms()` 方法中的平台坐标

**修改文件**:
- `client/scripts/world/room_renderer.gd` — 调整平台坐标

**风险**: 低 — 纯数值调整

---

## 八、执行顺序建议

```
Phase 2.4 (房间生成规则) → 最先做，影响后续所有Phase
    ↓
Phase 2.5 (平台高度) → 确保游戏可玩
    ↓
Phase 2.1 (Reward房) → 核心体验闭环
    ↓
Phase 2.3 (Event房) → 丰富游戏内容
    ↓
Phase 2.2 (武器系统) → 最重要的P0问题
```

每完成一个Phase后等待人工验收，确认后再进行下一个。

# TASK-007_ANALYSIS_REPORT — Roguelike 核心成长闭环审计

> 阶段：TASK-007 第一阶段产物（**仅分析，未修改任何代码**）
> 目标：战斗 → 奖励 → 选择 → 属性成长 → 继续探索 完整循环
> 日期：2026-09-23
> 状态：**等待确认后实施**

---

## 1. 现状分析（7 大系统盘点）

### 1.1 系统清单（哪些功能已经存在）

| 系统 | 位置 | 状态 | 关键能力 |
|---|---|---|---|
| UpgradeManager | [upgrade_manager.gd](client/scripts/progression/upgrade_manager.gd) | ✅ **完整存在** | EXP 系统（100 基础/1.5 增长/上限50级）；强化池 18 项（攻击I-III/生命I-III/速度I-II/暴击I-II/暴击伤害/防御I-II/嗜血/经验增幅/武器强化I-III）；`_generate_upgrade_options(3)` 随机 3 选 1（AI 优先，本地池补足）；`apply_upgrade()` 应用到 PlayerStats；4 个信号齐全 |
| RewardSystem | [reward_data.gd](client/scripts/models/reward_data.gd) + [reward_item.gd](client/scripts/drop/reward_item.gd) + [room_spawner.gd](client/scripts/world/room_spawner.gd) | ✅ **完整存在** | RewardData 8 类型（含 ATTACK_UP/HEALTH_UP/WEAPON_UPGRADE/ATTRIBUTE_BOOST）；`stat_key` 支持 attack/max_health/move_speed/crit_rate/defense；`apply_to_player()` 完整实现；`generate_random_reward()` 随机生成；拾取物（Area2D+像素视觉+动画）完整 |
| WeaponSystem | [weapon_data.gd](client/scripts/models/weapon_data.gd) + [weapon_instance.gd](client/scripts/combat/weapon_instance.gd) | ✅ **完整存在** | 武器等级 1~10、`upgrade()`/`set_level()`/`is_max_level()`、伤害成长 `base + growth*(level-1)`；`player_controller.upgrade_weapon()` 同步存档 weapon_level |
| PlayerStats | [player_stats.gd](client/scripts/player/player_stats.gd) | ✅ **完整存在** | 基础属性 + 等级经验 + 百分比加成（crit_rate_bonus/crit_damage_bonus/move_speed_bonus/exp_rate_bonus）+ 被动；`add_attack/add_max_health/add_crit_rate_bonus/add_move_speed_bonus` 等全套修改接口；`to_dict/from_dict/sync_from_dict` 序列化完整 |
| RoomLifecycle | [new_room_data.gd](client/scripts/models/new_room_data.gd)（TASK-005） | ✅ **完整存在** | RoomState 状态机 + `transition_to()` 唯一入口；战斗房：进入→COMBAT→清怪→REWARD→全拾取→COMPLETED→唯一出口 |
| CombatManager | [combat_manager.gd](client/scripts/combat/combat_manager.gd) | ✅ **完整存在** | 战斗状态机 IDLE/ENTERING/COMBAT/CLEARED/REWARD/BOSS；`combat_cleared`/`room_completed` 信号；`complete_reward_phase()` |
| SaveSystem | [save_system.gd](client/scripts/managers/save_system.gd) + [save_service.gd](client/scripts/services/save_service.gd) + [game_state_manager.gd](client/scripts/managers/game_state_manager.gd) | ✅ **完整存在** | JSON 存档 3 槽位；`get_save_data()` = PlayerStats.to_dict()（**已含全部加成字段**）+ weapon_level/weapon_id/passive_items；自动存档点：楼层完成/Boss/退出 |
| **LevelUpPanel** | [level_up_panel.gd](client/scripts/ui/level_up_panel.gd) | ⚠️ **双模式面板已存在，但 reward 模式从未被调用** | `show_upgrade_panel()`（升级 3 选 1，正常工作中）；`show_reward_panel()`（**全工程零调用**）；`reward_selected` 信号已接线到 game_scene `_on_reward_selected`（已实现 apply + HUD 刷新 + 恢复 PLAYING 状态） |

### 1.2 关键发现：面板已就绪、属性接线有缺口

1. **奖励选择 UI 完全不用新建**——LevelUpPanel 自带 `show_reward_panel(rewards, title)` 模式，暂停游戏、3 按钮+描述、选择信号全部实现，game_scene 侧 `_on_reward_selected` 处理函数也已存在。缺的只是**调用点**。
2. **两个属性加成"入库不生效"**（成长闭环的断裂点）：
   - 暴击率：[weapon.gd:137](client/scripts/combat/weapon.gd#L137) 硬编码 `crit_rate = 0.1`，`PlayerStats.get_crit_rate()` 全工程**零消费者** → 选了暴击强化毫无效果
   - 移动速度：[player_controller.gd:214](client/scripts/player/player_controller.gd#L214) 用常量 `MOVE_SPEED = 200.0`，`get_final_move_speed()` 零消费者 → 选了速度强化毫无效果

## 2. 当前奖励流程（战斗房实况）

```
进战斗房 → ENTERING → COMBAT → 怪物全灭
  → [CombatManager] combat_cleared 信号
  → game_scene._on_combat_cleared()          [game_scene.gd:724]
     ① 清房反馈特效
     ② room_spawner.spawn_rewards(content)   ← 房间内散落 3 个"拾取物"
     ③ set_current_room_state(REWARD)        ← 无出口
  → 玩家走近逐个拾取（金币/属性/武器/被动，即捡即生效）
  → 全部拾取 → all_rewards_collected 信号
  → combat_manager.complete_reward_phase() → room_completed 信号
  → _complete_current_room("reward_phase_completed")
  → COMPLETED → 创建唯一出口 → 进下一房
```

**特征**：奖励是"散落拾取"（碰一下自动获得），**没有选择环节**。

## 3. 当前成长流程（EXP/升级驱动，工作中）

```
怪物死亡 → monster_died 信号 → _on_monster_died_for_exp()
  → upgrade_manager.add_experience() → PlayerStats.gain_exp()
  → 升级 → 自动满血 +ATK2 +HP10（PlayerStats._level_up 内置）
  → _generate_upgrade_options(3)（AI 优先，本地池补足）
  → upgrade_selection_required 信号
  → LevelUpPanel.show_upgrade_panel() → 暂停游戏 → 玩家 3 选 1
  → apply_upgrade() → 属性立即写入 PlayerStats → HUD 刷新
  → upgrade_applied → 行为分析器记录（AI 画像用）
```

**特征**：选择环节**只绑定在升级上**（概率性事件），不是每场战斗后的确定性环节。

## 4. 缺失环节（与目标功能对照）

| # | 缺失 | 详情 | 目标要求 |
|---|---|---|---|
| G1 | **战斗房完成后的"选择"环节不存在** | `show_reward_panel()` 零调用；战斗房清怪后是散落拾取而非 3 选 1 | 战斗房完成后 → 3 选 1 奖励选择界面 |
| G2 | **暴击率提升无实际效果** | weapon.gd 硬编码 crit_rate=0.1；`get_crit_rate()` 无消费者 | 暴击率提升选项必须生效 |
| G3 | **移动速度提升无实际效果** | player_controller 用常量 MOVE_SPEED；`get_final_move_speed()` 无消费者 | 移动速度提升选项必须生效 |
| G4 | **选择后不立即存档** | 自动存档点只有：楼层完成/Boss/退出；单场战斗选择后无保存点 | 玩家选择后保存当前 run 状态 |
| G5 | 嗜血（heal_on_kill）无消费点 | 仅 AI 强化池有定义 | 与 TASK-007 无关，本轮不处理 |

## 5. 涉及文件

| 文件 | 现状 | 本轮动作 |
|---|---|---|
| [game_scene.gd](client/scenes/game/game_scene.gd) | `_on_combat_cleared()` 散落拾取；`_on_reward_selected()` 已实现但无上游调用 | **修改**：接入奖励选择面板 + 选择后完成房间 + 自动存档 |
| [weapon.gd](client/scripts/combat/weapon.gd) | 硬编码 crit_rate=0.1 | **修改**：`_fire()` 读取玩家实际暴击率（G2 接线） |
| [player_controller.gd](client/scripts/player/player_controller.gd) | 用常量 MOVE_SPEED | **修改**：`_physics_process()` 用 `get_final_move_speed()`（G3 接线） |
| [test_reward_choice.gd](client/tests/) | 不存在 | **新增**（见 §7） |
| UpgradeManager / RewardData / RewardItem / LevelUpPanel / PlayerStats / RoomState 状态机 / CombatManager / floor_generator / AI 系统 / 存档格式 | 已完整 | **一律复用，零改动** |

**不修改**（按用户要求）：floor_generator.gd、地图 DAG 结构、AI 核心架构、存档格式（PlayerStats.to_dict 已含全部字段，无需加）、战斗底层碰撞逻辑。

## 6. 最小修改方案

### 6.1 战斗房奖励流程改造（G1）

**方案 A（推荐）**：战斗房"散落拾取"替换为"3 选 1 选择面板"

```
_on_combat_cleared() 改为:
  ① 清房反馈特效（保留）
  ② _generate_reward_choices() → 3 个 RewardData
     类型池（目标 5 类）: 攻击提升 / 最大生命提升 / 暴击率提升 / 移动速度提升 / 武器强化
     生成: RewardData 现有工厂（ATTACK_UP / HEALTH_UP / ATTRIBUTE_BOOST(crit_rate|move_speed) / WEAPON_UPGRADE）
     去重: 3 个选项类型不重复
  ③ set_current_room_state(REWARD)（保留，状态机不动）
  ④ LevelUpPanel.show_reward_panel(choices, "选择奖励")  ← 复用现有面板

_on_reward_selected(reward) 改造:
  ① reward.apply_to_player(player)（现有逻辑保留）
  ② 若当前房间为战斗房 → _complete_current_room("reward_choice_selected")
     → COMPLETED → 创建唯一出口（走 TASK-005/TASK-006 现有路径）
  ③ _auto_save()（G4: 选择后保存 run 状态）
  ④ HUD 刷新（现有逻辑保留）
```

**状态机影响**：零改动。仍走 COMBAT→REWARD→COMPLETED 合法转换链，只是 REWARD 阶段的"触发完成"从「全拾取信号」变为「面板选择回调」。奖励房/宝箱房保持散落拾取不变（RoomSpawner 拾取链路原样保留）。

**方案 B（备选）**：战斗房保留散落拾取 + 清怪后额外弹面板 → 不推荐（奖励翻倍、与目标流程"完成后生成选择界面"语义不符、保留两套奖励路径维护成本高）。

### 6.2 属性生效接线（G2/G3）

| 接线 | 改动 | 说明 |
|---|---|---|
| 暴击率 | `weapon.gd` `_fire()`：`var crit_rate = 0.1` → 从玩家读取（`player.get_stats().get_crit_rate()`，经 Weapon 现有 player 引用传递） | 属"成长消费点接线"，不触碰碰撞/伤害公式 |
| 移动速度 | `player_controller.gd` `_physics_process()`：`MOVE_SPEED` 常量 → `get_stats().get_final_move_speed()` | 基础值 200 不变（move_speed_bonus=0 时行为完全一致） |

> 说明：这两处改动触及 combat/player 文件，但均在用户禁止事项（floor_generator/DAG/AI核心/存档格式/碰撞逻辑）**之外**。若不接线，暴击率/移动速度两个选项将是"选了没效果"的假奖励，违反 TASK-007 目标。如用户希望本轮不碰这两个文件，可退化为"面板只出 3 类有效选项（攻击/生命/武器）"——**待确认**（见 §8）。

### 6.3 存档（G4）

- `_on_reward_selected` 战斗房分支末尾调用现有 `_auto_save()`（[game_scene.gd:989](client/scenes/game/game_scene.gd#L989)）
- 存档格式零改动：PlayerStats.to_dict() 已含 attack/max_health/crit_rate_bonus/move_speed_bonus/weapon_level(经扩展字段)，选择结果天然持久化

## 7. 测试计划（test_reward_choice.gd）

沿用现有测试脚手架模式（SceneTree + `_check` + 元护栏），覆盖用户要求的 5 点：

| # | 检查项 | 内容 |
|---|---|---|
| T1 | 奖励生成 | 每次生成恰 3 个选项；类型 ∈ 5 目标类型池；3 选项类型不重复 |
| T2 | 随机性 | 多次生成（≥50 次）出现不同组合（断言不恒为同一组） |
| T3 | 选择生效 | 模拟选择 → `apply_to_player` → PlayerStats 对应数值变化 |
| T4 | 属性变化 | 逐类型断言：攻击+ / 最大生命+（含当前生命同步）/ 暴击率加成+ / 移速加成+ / 武器等级+（weapon 桩） |
| T5 | 存档兼容 | `to_dict→from_dict` 往返保留全部加成字段；旧格式存档（无加成字段）加载取默认值不报错 |
| T6 | 流程回归 | 模拟战斗房流程：清怪→面板 3 选项→选择→REWARD→COMPLETED→出口（镜像 game_scene 路径，桩注入） |

**回归影响预告**：`test_room_lifecycle.gd`（TASK-005）T2 断言"清怪→生成散落奖励→拾取→完成"。战斗房改面板后，该断言需同步更新（**仅改测试文件断言，TASK-005 生产代码零改动**）；TASK-001/002/003/004/006 套件不涉及战斗房奖励生成路径，预期不受影响（实施时全量回归验证）。

## 8. 风险分析

| # | 风险 | 评估 |
|---|---|---|
| R1 | test_room_lifecycle T2 断言与新流程冲突 | 低。测试文件随流程更新断言，生产代码（RoomState/transition_to/completed 逻辑/CombatManager）零改动；实施时全量回归把关 |
| R2 | 面板弹出时 `get_tree().paused=true` 与战斗房状态交互 | 低。清怪后才弹面板，怪物已清空、无物理交互风险；LevelUpPanel 已设 PROCESS_MODE_WHEN_PAUSED（升级面板已在实战中验证） |
| R3 | weapon.gd / player_controller.gd 接线触及战斗相关文件 | 低~中。改动是"数据源替换"（硬编码→PlayerStats 读取），不触碰碰撞/伤害公式/弹道逻辑；基础值不变时行为完全一致（回归可证） |
| R4 | 存档兼容 | 极低。存档格式与 PlayerStats 字段零改动；旧档加载 from_dict 默认值兜底 |
| R5 | AI 降级路径生成内容中的 reward_count/reward_items 仍驱动奖励房/宝箱房 | 无影响。战斗房改面板后不再走 spawn_rewards，AI 内容对奖励房/宝箱房路径不变；**AI 系统零改动** |
| R6 | 武器已满级时"武器强化"选项出现 | 低。选项生成时检查 `weapon_instance.is_max_level()`，满级则从剩余类型补位（3 选项类型不重复的前提下仍有 4 类可用） |
| R7 | 面板打开期间玩家误操作/重复选择 | 低。LevelUpPanel `_is_showing` 防重入；选择即关面板恢复游戏，`reward_selected` 只发一次 |
| R8 | 连续战斗房奖励膨胀 | 中（设计取舍）。每战斗房 +1 项属性成长会随层数线性膨胀，需数值控制（建议：数值随层数平缓或上限封顶）——实施计划中给出具体数值方案供确认 |

## 9. 待确认问题

1. **方案 A vs 方案 B**（战斗房：面板替换拾取 vs 拾取+面板并存）——推荐 A
2. **G2/G3 接线范围**：是否同意本轮修改 weapon.gd / player_controller.gd（各 1~3 行数据源替换）？不同意则暴击/速度选项从面板类型池剔除
3. **数值平衡**：3 选项每房永久成长，是否接受"每房必得 1 项"（无稀缺性）？还是按概率/按层数出现选择面板？

---

**结论**：基础设施（UpgradeManager/RewardData/LevelUpPanel 双模式/PlayerStats/状态机/存档）全部齐备，TASK-007 本质是**接线任务**——接上调用点（G1）+ 补上两个属性消费点（G2/G3）+ 加一个存档点（G4），预计改动 3 个文件 + 新增 1 个测试文件。

⏸️ **分析完成，已停止。等待你确认后进入实施阶段。**

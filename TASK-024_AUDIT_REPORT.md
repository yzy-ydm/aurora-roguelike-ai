# TASK-024_AUDIT_REPORT — AI 动态内容闭环审计与系统完整性检查

> 日期：2026-09-24
> 状态：**仅审计，未修改任何代码，等待确认后实施**
> 第一阶段闭环链路详见：[AI_FEATURE_FLOW_AUDIT.md](AI_FEATURE_FLOW_AUDIT.md)

---

## 1. 问题清单（问题 / 等级 / 影响 / 建议方案 / 预计修改文件）

### F-1【P1】武器伤害双重计入（Damage 计算链路）

| 项 | 内容 |
|---|---|
| 现象 | 铁剑 damage=5，实际造成 18/19 伤害（应为 ~14/15） |
| 根因 | [player_controller.get_attack()](client/scripts/player/player_controller.gd#L524-L532) 返回"攻击力+武器伤害"（=15），[damage_system.on_bullet_hit](client/scripts/combat/damage_system.gd#L65-L73) 又加上 bullet 携带的武器伤害（+5）→ base=(10+5)+5=20，减伤后 18/19 |
| 影响 | 玩家 DPS 虚高 33%；数值体系失真（毕设演示的数据合理性） |
| 建议方案 | 方案 A（推荐）：on_bullet_hit 改读裸攻击力 `source.get_stats().attack`，保留 get_attack() 语义（全工程唯一消费者就是此处，影响面最小）。**注意：修复后玩家 DPS -25%，需联动实测战斗手感** |
| 预计修改 | damage_system.gd（~2 行）+ 测试断言 |

### F-2【P1】AI 动态难度调整零消费者（毕设亮点功能无效果）

| 项 | 内容 |
|---|---|
| 现象 | difficulty 请求返回 200、数值已存储，但怪物属性和伤害计算完全不受影响 |
| 根因 | [floor_manager._difficulty_adjustment](client/scripts/world/floor_manager.gd#L36) 仅被调试面板读取；怪物属性由 `MonsterBalanceConfig.generate_monster_stats` 生成（[room_spawner._apply_monster_clamp](client/scripts/world/room_spawner.gd#L228)），不读任何 multiplier |
| 影响 | "AI 分析玩家表现→动态调整难度"这一论文核心卖点实际无效 |
| 建议方案 | 消费点放在怪物生成侧（不动 AI 架构）：`_apply_monster_clamp` 前从 FloorManager 读 `get_difficulty_adjustment()`，HP/ATK 乘以对应 multiplier（钳制上下限防失控）。可选：damage_system 侧不重复乘（避免双重缩放） |
| 预计修改 | room_spawner.gd（~6 行，注入 difficulty 引用或经 game_scene 传入） |

### F-3【P1】AI NPC 对白零 UI 消费（玩家看不到）

| 项 | 内容 |
|---|---|
| 现象 | dialogue 返回 200、转换正常，但玩家在游戏中从未看到对白 |
| 根因 | [floor_manager.gd:270-271](client/scripts/world/floor_manager.gd#L270-L271) 拿到 dialogue 后仅 print 日志，无任何 UI 显示调用 |
| 影响 | AI 叙事内容完全不可见，AI 生成能力展示缺失 |
| 建议方案 | 最小方案：floor_manager 发送新信号（或复用 ai_event_received 旁路）→ game_scene 将 dialogue 逐行经 `hud.set_status()` 或已有的 HUD 文本区滚动显示（无需新建 UI 系统；完整气泡 UI 属扩展，不在本次范围） |
| 预计修改 | floor_manager.gd（~3 行信号）+ game_scene.gd（~10 行显示）+ hud_controller.gd（如需滚动显示 ~10 行） |

### F-4【P2】玩家双重减伤（Defense 减伤链路）

| 项 | 内容 |
|---|---|
| 现象 | 玩家实际承伤低于设计值 |
| 根因 | [damage_system.calculate_damage](client/scripts/combat/damage_system.gd#L26-L34) 按防御公式减伤一次，[player_stats.take_damage](client/scripts/player/player_stats.gd#L181-L185) 又 `amount - defense` 减第二次 |
| 影响 | 防御数值被放大；与 F-1 同源——数值体系失真 |
| 建议方案 | 与 F-1 一起处理：DamageSystem 为唯一伤害计算入口（设计注释已声明），`PlayerStats.take_damage` 改为直接扣血 `current_health = max(0, current_health - amount)`。**注意：玩家会变脆，需与 F-1 修复后的手感联动实测** |
| 预计修改 | player_stats.gd（~2 行） |

### F-5【P2】暴击率硬编码，成长加成无效（Critical 系统）

| 项 | 内容 |
|---|---|
| 现象 | 选择暴击率强化后毫无效果 |
| 根因 | [weapon.gd:137](client/scripts/combat/weapon.gd#L137) `var crit_rate = 0.1` 硬编码；`PlayerStats.get_crit_rate()`/`crit_rate_bonus` 全工程零消费者 |
| 影响 | 成长系统存在"假选项"（TASK-007 G2 遗留） |
| 建议方案 | `_fire()` 从 `_owner.get_stats().get_crit_rate()` 读取（1 行，基础值 0.1 行为不变）；归属 TASK-007 成长接线任务或本次一并修 |
| 预计修改 | weapon.gd（~1 行） |

### F-6【P0/P1】存档槽位 -1 影响正常游戏流程（Save 系统）

| 项 | 内容 |
|---|---|
| 现象 | 暂停菜单保存按钮显示"无存档槽位"；自动保存硬编码回退槽位 1；**无任何加载入口**；即使加载也不恢复楼层进度 |
| 根因 | ① [GameFlowController.enter_game](client/scripts/managers/game_flow_controller.gd#L108-L119) 唯一设置 `_current_slot` 的入口，但所有调用方（login_scene:251/259）不带参数 → slot 永远 -1；② [pause_menu.gd:58-63](client/scripts/ui/pause_menu.gd#L58-L63) 要求 slot≥0；③ 主菜单无"继续游戏"；④ [game_scene.gd:387](client/scenes/game/game_scene.gd#L387) 硬编码 `generate_floor(1)` |
| 影响 | 毕设演示"存档/读档"环节无法演示；TASK-020 已修保存链路本身，本项是槽位管理与加载入口 |
| 建议方案 | ① 主菜单增加"继续游戏"按钮 → 列出存档（SaveService.get_saves）→ `enter_game(slot)`；② 新游戏时分配槽位（或明确"新游戏用槽位 1"并设置 `_current_slot`）；③ 加载时读取 `current_floor` 传给 generate_floor；④ 保存成功回写 `_current_slot` |
| 预计修改 | main_scene.gd（+按钮）、game_flow_controller.gd（~5 行）、game_scene.gd（~3 行）、save_selection.gd（复用） |

---

## 2. 第二阶段确认结论（AI 结果是否真正影响游戏）

| 检查项 | 结论 |
|---|---|
| difficulty_adjustment → MonsterData/Monster 实例/Damage | ❌ 无消费者（F-2），影响范围：全部楼层的怪物 HP/ATK/DEF、全部战斗伤害 |
| NPC dialogue → 玩家可见 | ❌ 无 UI 消费（F-3），影响范围：AI 叙事完全不可见 |
| AI reward → Reward 系统 | ✅ 生效（reward_items/reward_quality/reward_strategy 经 RoomSpawner 映射为 RewardData） |
| AI upgrade → Upgrade 系统 | ✅ 生效（AI 选项进入升级面板 3 选 1，不足时本地补足） |
| AI room_content → 怪物生成 | ✅ 生效（monster count/type/level 经 validate 后生效，finalize 防覆盖） |
| AI context_event → 事件面板 | ✅ 生效（事件面板弹出，HUD 兜底） |

---

## 3. 第三阶段审计结论（核心玩法系统）

| 系统 | 检查项 | 结论 |
|---|---|---|
| Damage 计算链路 | attack / weapon damage / bullet damage 是否重复计算 | ❌ **武器伤害重复计入**（F-1） |
| Defense 减伤链路 | DamageSystem / PlayerStats 是否重复减伤 | ❌ **双重减伤**（F-4） |
| Critical 系统 | crit_rate 是否硬编码、成长是否有效 | ❌ **硬编码 0.1，成长无效**（F-5） |
| Save 系统 | save_slot=-1 是否影响正常流程 | ❌ **影响**（暂停保存不可用/自动保存回退槽位1/无加载入口）（F-6） |

---

## 4. 建议实施顺序（等确认）

| 顺序 | 问题 | 等级 | 说明 |
|---|---|---|---|
| 1 | F-6 存档槽位+加载入口 | P0 | 毕设演示"存档/读档"环节的硬需求 |
| 2 | F-1 武器伤害双计 + F-4 双重减伤 | P1（联动） | 数值体系修正，需人工实测战斗手感后微调 |
| 3 | F-2 难度消费点 | P1 | 论文核心卖点，改动集中在怪物生成侧 |
| 4 | F-3 NPC 对白显示 | P1 | 最小 HUD 方案，AI 叙事可见 |
| 5 | F-5 暴击率接线 | P2 | 1 行改动，可与 TASK-007 合并 |

**审计完成，未修改任何代码。等待下一步指令。**

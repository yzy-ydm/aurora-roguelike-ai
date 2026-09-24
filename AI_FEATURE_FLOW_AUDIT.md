# AI_FEATURE_FLOW_AUDIT — AI 动态内容闭环审计

> 日期：2026-09-24（TASK-024 第一阶段产物）
> 范围：6 个 AI 生成功能的完整闭环（输入 → 返回 → 转换 → 消费）

---

## 1. context_event（上下文事件）

| 环节 | 内容 |
|---|---|
| AI 输入 | `context`（player_level / combat_style / upgrade_preference / current_health_percent 等，由 AIContextManager.get_event_context() 提供） |
| AI 返回 | JSON `{title, description, choices: [{text, reward, risk}]}` |
| 转换 | `AIResponseAdapter.to_safe_dictionary` → `AIEventData.from_dict()`（choices 逐项验证，TASK-022/023） |
| 消费 | `FloorManager._request_ai_room_content` → `ai_event_received` 信号 → `GameScene._on_ai_event_received` → `AIEventPanel.show_event()`（无面板时 HUD 兜底） |
| 闭环状态 | ✅ **完整闭环**（进房后事件面板弹出，玩家可选） |

## 2. difficulty_adjustment（动态难度）

| 环节 | 内容 |
|---|---|
| AI 输入 | `context`（玩家战斗表现：death_rate / damage_rate / no_hit_rate 等） |
| AI 返回 | JSON `{enemy_hp_multiplier, enemy_damage_multiplier, elite_spawn_rate, reward_multiplier}` |
| 转换 | `_parse_difficulty_response` → to_float 规整（TASK-023）→ `FloorManager._difficulty_adjustment` 存储 |
| 消费 | ❌ **仅 ai_debug_panel.gd:81 调试面板显示**——怪物生成（room_spawner._apply_monster_clamp）、Damage 计算（damage_system）**均不读取** |
| 闭环状态 | ❌ **断裂**（AI 生成 → 存储 → 死水。详见 TASK-024_AUDIT_REPORT F-2） |

## 3. npc_dialogue（NPC 对白）

| 环节 | 内容 |
|---|---|
| AI 输入 | `npc_type / room_environment / player_state` |
| AI 返回 | JSON `{dialogue: [String]}` |
| 转换 | `AIResponseAdapter.to_string_array`（TASK-023，崩溃点已修） |
| 消费 | ❌ **零 UI 消费**——`FloorManager._request_ai_room_content` 拿到后仅 `print("[FloorManager] AI dialogue received: N lines")` 日志 |
| 闭环状态 | ❌ **断裂**（玩家看不到 AI 对白。详见 TASK-024_AUDIT_REPORT F-3） |

## 4. room_content（房间内容增强）

| 环节 | 内容 |
|---|---|
| AI 输入 | `room_id / room_type / floor_level` |
| AI 返回 | JSON `{monsters: [{id, count, level}], rewards: {count, quality, strategy, items}}` |
| 转换 | `AIParser.parse_room_content`（手动循环 + TASK-022/023 适配）→ RoomContentData；经 `validate_for_room_type` 规则校验；`finalize()` 锁定 |
| 消费 | ✅ `room.content = content` → 进房时 `spawn_monsters(content)` / `spawn_rewards(content)` |
| 闭环状态 | ✅ **完整闭环**（AI 怪物数量/等级/奖励品质真正生效；有 finalize 防覆盖保护） |

## 5. reward_generation（奖励生成）

| 环节 | 内容 |
|---|---|
| AI 输入 | 随 room_content 一起（rewards 段），也可有 reward_strategy |
| AI 返回 | JSON `rewards: {count, quality, strategy, items: [{type, value}]}` |
| 转换 | `RoomContentData.reward_items/reward_quality/reward_strategy`（TASK-022 修类型） |
| 消费 | ✅ `RoomSpawner.spawn_rewards` → `has_reward_strategy()` → `_generate_reward_from_strategy` → `_reward_from_config`（type/value 映射为 RewardData；value≤0 时随机兜底） |
| 闭环状态 | ✅ **完整闭环**（AI 指定的奖励类型与数值生效，战斗房清怪/奖励房/宝箱房均走此路径） |

## 6. upgrade_options（强化选项）

| 环节 | 内容 |
|---|---|
| AI 输入 | `player_level / player_stats` |
| AI 返回 | JSON `{upgrades: [{id, name, description, type, rarity, modifiers, percent_modifiers}]}` |
| 转换 | `AIResponseAdapter.to_dictionary_array`（TASK-023）→ UpgradeManager 内转换为 UpgradeData（AI 优先，不足 3 个时本地强化池补足） |
| 消费 | ✅ `UpgradeManager._generate_upgrade_options(3)` → `LevelUpPanel.show_upgrade_panel` → 玩家选择 → `apply_upgrade()` 写入 PlayerStats |
| 闭环状态 | ✅ **完整闭环**（升级面板 3 选 1 中 AI 选项真实可选可生效） |

---

## 汇总

| AI 功能 | AI 生成 | 转换 | 游戏消费 | 闭环 |
|---|---|---|---|---|
| context_event | ✅ 200 | ✅ | ✅ 事件面板 | ✅ |
| difficulty_adjustment | ✅ 200 | ✅ | ❌ 仅调试面板 | ❌ 断裂 |
| npc_dialogue | ✅ 200 | ✅ | ❌ 仅日志 | ❌ 断裂 |
| room_content | ✅ 200 | ✅ | ✅ 怪物/奖励生成 | ✅ |
| reward_generation | ✅ 200 | ✅ | ✅ Reward 系统 | ✅ |
| upgrade_options | ✅ 200 | ✅ | ✅ Upgrade 系统 | ✅ |

**结论：4/6 完整闭环；2 处断裂（难度调整、NPC 对白）——修复方案见 TASK-024_AUDIT_REPORT.md。**

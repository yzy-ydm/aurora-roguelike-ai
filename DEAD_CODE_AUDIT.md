# DEAD_CODE_AUDIT — 死代码审计报告

> 生成日期：2026-09-24
> 审计方法：
> 1. 全量提取客户端 100 个源脚本的 `class_name`，逐一统计跨文件引用次数；
> 2. 对比"磁盘脚本全集"与"全部 `load()` 动态加载路径 + tscn 挂载路径 + autoload 清单 + class_name 引用"，筛出无任何进入路径的脚本；
> 3. 逐函数追踪关键系统的调用点（AI 各 generate 函数、BossController、SaveSystem 等）；
> 4. 对关键状态变量做"写入点/读取点"配对分析（难度调整、暴击、移速、击杀回血）。
>
> **重要约束：本报告只记录，不删除任何代码。**（按项目约束"不要删除"，清理动作是否执行由 FINAL_DEVELOPMENT_PLAN 决定并经用户确认。）

---

## 一、完全死代码 —— 文件级（零运行时进入路径）

### A1. 被取代的旧世界系统（Phase 10.1.5 重构遗留）

| 文件 | 说明 | 证据 |
|---|---|---|
| client/scripts/world/room_graph.gd | 旧房间图（AI 楼层接入点） | 全工程零 load/实例化；其 `generate_new_floor` 是 AIContentService.generate_floor_content 唯一调用方 |
| client/scripts/world/room_manager.gd | 旧房间状态管理 | 零 load/实例化 |
| client/scripts/world/world_manager.gd | 旧世界管理 | 零 load/实例化 |
| client/scripts/world/room_content_manager.gd | 旧房间内容管理 | 零 load/实例化；是旧版 `generate_room_content(RoomNodeData)` 的唯一调用方 |
| client/scripts/world/map_renderer.gd | 旧地图渲染（挂载于 world.tscn） | world.tscn 永不被任何代码实例化 |
| client/scenes/world/world.tscn | 旧世界场景 | 零实例化 |

### A2. 被取代的旧战斗/掉落子系统

| 文件 | 说明 | 证据 |
|---|---|---|
| client/scripts/enemy/monster_spawner.gd | 旧怪物生成器（RoomSpawner 取代） | 零 load/实例化 |
| client/scripts/drop/drop_manager.gd | 旧掉落管理（RoomSpawner 取代） | 零 load/实例化 |
| client/scripts/entity/entity_manager.gd | 实体管理器 | 全工程零引用（连注释都没有外部引用） |
| client/scripts/entity/player_entity.gd | 旧玩家实体 | 仅被 monster_entity.gd 做类型检查引用（运行时永不匹配） |
| client/scripts/boss/boss_controller.gd（技能/阶段部分） | Boss 控制器整体被创建，但**驱动逻辑全部死**：`update()/_decide_action/_chase_player/_check_phase_transition/_try_use_skill/_use_skill/_execute_charge_attack/_execute_aoe_attack/_execute_projectile_attack/_execute_melee_attack/_spawn_aoe_warning/_spawn_projectile/_update_skill_cooldowns` 全工程零调用点；Boss 实际由 MonsterAI（monster.tscn）驱动。存活的仅 `initialize/take_damage/get_attack/get_defense/get_monster_entity/get_boss_data` 等被动接口 | update() 等无任何 `.update(` 调用 |

### A3. 从未被实例化的 UI / 管理器

| 文件 | 说明 | 证据 |
|---|---|---|
| client/scripts/events/ai_event_manager.gd | AI 事件管理器（状态机/奖励应用） | 零 load/实例化；AIEventPanel.set_event_manager 是唯一接口，但面板本身也未实例化 |
| client/scripts/ui/ai_event_panel.gd | AI 事件面板 | game_scene.tscn 无 UI/AIEventPanel 节点；game_scene 仅 HUD 兜底文本 |
| client/scripts/ui/ai_debug_panel.gd | AI 调试面板 | 零 load/实例化（FloorManager.get_difficulty_adjustment 的唯一读取者 → 难度数据事实上零 UI 出口） |
| client/scripts/ui/ai_status_display.gd | AI 状态显示 | 零 load/实例化，零外部引用 |
| client/scripts/ui/network_stats_ui.gd | 网络统计 UI | 零 load/实例化，零外部引用 |
| client/scripts/ai/ai_room_content.gd | AIRoomContent 类 | class_name 引用计数 0，零 load |
| client/scripts/object/test_chest.gd | 测试宝箱 | class_name TestChest 引用计数 0 |
| client/scripts/managers/save_system.gd | **本地 JSON 存档系统** | game_scene 实例化并连接信号，但 `save_game()/load_game()/delete_save()` **零调用**（真实存档走 SaveService→服务端→MySQL）。运行时仅 _ready 建目录 |
| client/scripts/ai/fake_ai_service.gd | 本地模拟 AI 服务 | game_scene 固定 `set_service_type(REAL)`（game_scene.gd:310），FAKE 分支不可达；fallback 楼层走 FloorGenerator、fallback 内容走 RoomContentData 默认值，均不经 FakeAIService |

### A4. 旧数据模型（仅被死代码引用）

| 文件 | 说明 |
|---|---|
| client/scripts/models/room_node_data.gd | 仅被：旧 generate_room_content 路径（死）、new_room_data 兼容转换、room_content_data.from_room_node、floor_generator（死函数）、room_manager（死）引用 → 实质死 |
| client/scripts/models/room_data.gd | 引用者多为死文件（map_renderer/room_manager/world_manager/monster_spawner）；活文件中的引用为兼容分支 |
| client/scripts/models/map_data.gd | 引用者：resource_service（资源浏览）、resource_center（UI）、map_renderer/world_manager（死）→ 仅资源中心 UI 存活 |
| client/scripts/models/event_data.gd | 仅 resource_service/resource_center 引用（资源目录数据），游戏内事件已改用 Dictionary/AIEventData |

---

## 二、部分死代码 —— 函数/分支级（所在文件存活，但函数不可达）

### B1. AIContentService 中的死函数（client/scripts/ai/ai_content_service.gd）

| 函数 | 状态 | 证据 |
|---|---|---|
| generate_floor_content + _call_ai_service_floor + _call_cloud_ai_floor | 死 | 唯一调用方 room_graph.gd（死）；Phase 25 楼层拓扑锁定，设计上不再调用 |
| generate_room_content（旧 RoomNodeData 版）+ _call_ai_service_room + _call_cloud_ai_room | 死 | 唯一调用方 room_content_manager.gd（死）；现役路径为 generate_room_content_from_new |
| generate_room_event + _call_ai_service_event + _call_cloud_ai_event | 死 | 全工程零调用点；事件房用 game_scene._generate_random_event 本地事件 |
| generate_room_strategy + _call_ai_service_room_strategy + _call_cloud_ai_room_strategy + 全部 mock 实现 | 死 | 零调用点 |
| generate_npc_memory_response + _call_ai_service_npc_memory + _call_cloud_ai_npc_memory | 死 | 零调用点 |
| save_cache / clear_cache / print_status | 死 | 唯一调用方 ai_debug_panel.gd（死） |
| _generate_fallback_floor | 活（未初始化/质量不达标时的降级路径） | — |

### B2. FloorGenerator 死函数（client/scripts/world/floor_generator.gd）

| 函数 | 证据 |
|---|---|
| create_rooms_from_ai_data / _parse_room_type | 零调用点（AI 楼层路径废弃后的残留） |
| print_floor_graph / get_floor_graph_string | 零调用点（调试工具残留） |

### B3. GameScene 死路径（client/scenes/game/game_scene.gd）

| 函数/分支 | 证据 |
|---|---|
| _handle_weapon_pickup / _find_game_object_by_interactive_id / _on_interaction_triggered 的武器分支 | 前置条件为 ObjectManager 中存在 GameObject——运行时零对象生成（add_object/spawn_object 零调用）→ 不可达 |
| _inventory_manager / _equipment_manager 的业务使用 | 唯一写入点 add_weapon 位于上面的死路径中 → 背包/装备运行时恒空 |
| _generate_random_event（事件房） | 与 AI 无关的本地硬编码事件（非死代码，但属"AI 断裂"证据） |

### B4. 其它文件死函数

| 位置 | 函数 | 证据 |
|---|---|---|
| room_spawner.gd | _apply_level_modifier | 注释自认"已废弃：保留供调试和降级"；零调用 |
| boss_health_bar.gd | set_controller | 零调用者 → Boss 血条只显示初值、不随受击更新 |
| game_flow_controller.gd | load_saves() 由 start_game 链调用（活）；`_player_cache` 只写不读 | 缓存写入后无任何读取路径（Phase 22.1.1 设计如此） |
| analytics_manager.gd | 记录的数据（start_run 启动统计） | 全工程无读取者：run 数据只进不出 |

---

## 三、无消费者变量 / 信号（数据死水 —— 写入但永远不被读取）

| 变量 | 写入点 | 读取点 | 影响 |
|---|---|---|---|
| FloorManager._difficulty_adjustment | _request_difficulty_adjustment（每层生成时 AI 结果） | 仅 ai_debug_panel.gd（死代码）→ **零有效消费者** | AI 动态难度完全无效（F-2） |
| PlayerStats.crit_rate_bonus | upgrade_manager 强化"暴击率 +N%" | 零（get_crit_rate() 自身零调用；weapon._fire 硬编码 0.1） | 暴击强化无效（F-3） |
| PlayerStats.crit_damage_bonus | 强化"暴击伤害 +N%" | 零（get_crit_multiplier() 零调用；damage_system 硬编码 ×1.5） | 暴击伤害强化无效（F-3） |
| PlayerStats.move_speed / move_speed_bonus | 初始化/强化"移速 +N%" | 零（_physics_process 用 MOVE_SPEED=200 常量；get_final_move_speed() 零调用） | 移速强化无效（F-5） |
| PlayerStats.heal_on_kill | upgrade_manager:242 强化"嗜血" | 零 | 击杀回血强化无效（F-4） |
| GameStateManager._play_time 之外的存档统计 | get_save_data 读 _current_save 的 kill_count/gold_collected | 无任何累加写入 → 恒 0 | 存档统计无意义（F-7） |
| AnalyticsManager 全部统计字段 | 战斗/升级信号驱动记录 | 零读取（难度上下文实际来自 BehaviorAnalyzer，不是 AnalyticsManager） | 数据统计系统只写不读 |
| NPCMemoryManager 记忆数据 | ai_context_manager 读取并送入 NPC 对白上下文 | 对白结果本身只 print → 记忆数据最终仍无玩家可见出口 | 链条末端断裂 |
| GameFlowController._player_cache | 登录成功时写盘 | 零读取（Phase 22.1.1 明确"只保存，不用于自动登录"） | 设计性死数据 |

---

## 四、服务端检查结论

- server/app 与 server/ai 经检查**无明显死代码**：全部路由已注册（main.py）、全部 Provider 已注册（ProviderFactory：mock/agnes/mimo）、monster_balance/prompt_builder/validator/quality_checker 均被 ai_service 使用。
- server/tools/ai_benchmark.py 为独立压测工具（非死代码，按需手动运行）。
- 服务端唯一实质缺陷为业务级：save_service.create_save 硬编码 current_floor=1（见主报告 F-6）。

---

## 五、处置建议（不删除为前提）

1. **本轮不动**：所有死代码保留原样——部分文件（BossController、AIEventPanel/AIEventManager、旧模型）是答辩讲解"系统演进"和后续修复（P1/P2 任务）的现成材料。
2. **若做清理（P2 可选任务）**：优先只处理"完全死代码"（§一 A1/A2/A3 中确认零引用、零实例化的文件），并先提交一版全量备份（git 已可回溯，风险可控）；函数级死代码（§二）与数据死水（§三）留待对应功能接线任务完成后自然消化。
3. **禁止删除**（即使看似死）：save_system.gd（本地存档兜底方案，答辩可讲"双存档方案设计"）、fake_ai_service.gd（AI 降级链路的组成件，论文降级策略章节的代码证据）。

---

**本报告基于 2026-09-24 当前代码生成，未删除任何文件。**

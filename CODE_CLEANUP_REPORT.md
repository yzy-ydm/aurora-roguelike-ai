# CODE_CLEANUP_REPORT — Phase 18.2 代码清理报告

> 日期：2026-09-24
> 原则：确认废弃的代码**移动到 deprecated/**（可追溯、可恢复），不直接删除；
> 不删除可能影响功能的代码。

---

## 1. 已移动至 client/deprecated/（含来源与原因）

| 归档文件 | 来源 | 内容 | 原因 | 影响 |
|---|---|---|---|---|
| player_controller_revive.gd.txt | player_controller.gd | `revive()` 函数 | 零调用点（TASK-028 起 restart_run 改用 reset_stats_to 重建全新 PlayerStats + 清死亡锁）；revive 仅回血会残留等级/金币/强化 | 无（无任何调用方） |
| room_spawner_apply_level_modifier.gd.txt | room_spawner.gd | `_apply_level_modifier()` 函数 | 自标注"已废弃"且零调用点（怪物数值统一由 MonsterBalanceConfig 生成后钳制） | 无 |
| game_scene_boss_controller_var.txt | game_scene.gd | `var _boss_controller` 声明 | 声明后全文件零使用（Boss 控制器由 room_spawner 内部创建持有） | 无 |
| deprecated/README.md | — | 归档索引 | — | — |

## 2. 本轮扫描但**保留**（说明原因）

| 项 | 原因 |
|---|---|
| 交互/物品子系统（interactive_object/interaction_manager/detector/hint、weapon_object、object_manager、inventory/equipment_manager） | 运行时零对象生成，但属完整功能子系统——"可能影响功能的代码"，不删除；论文可讲交互架构 |
| ai_event_manager.gd / ai_event_panel.gd | 未实例化，但为 context_event 面板接线（后续任务）的现成材料 |
| GameFlowController.reset() | reset_flow() 的兼容别名（1 行转调），保留对外兼容 |
| PlayerStats.revive()（stats 级） | 被 reset_stats_to 之外的潜在路径使用（玩家死亡恢复逻辑的原子操作） |
| test_weapon_growth.gd | 需包装脚本运行（已知脚手架限制），保留 |

## 3. 历史清理记录（TASK-030，已删除——git 可回溯）

- 本地 JSON 存档系统 save_system.gd（重复存档逻辑）
- 旧世界系统 6 文件（room_graph/room_content_manager/room_manager/world_manager/map_renderer/world.tscn/room.tscn）
- 旧怪物/掉落/实体 5 文件、4 个死 UI、room_node_data.gd
- AI 楼层生成/旧事件/策略/NPC 记忆生成器等死函数
- 6 个零引用 API 常量

## 4. 重复 reset 逻辑梳理（审计结论）

| 函数 | 归属 | 职责 | 结论 |
|---|---|---|---|
| GameFlowController.reset_flow() | 游戏流程生命周期 | 流程状态→IDLE（登录/退出必经） | ✅ 唯一入口（reset() 为兼容别名） |
| GameStateManager.reset_run_state() | 单次 run | 清运行时引用/扩展数据/时长/楼层/存档，保留 profile 基线 | ✅ 唯一入口 |
| GameStateManager.reset() | 全量 | 清一切（含 profile）——仅测试与极端场景 | ✅ 保留 |
| SaveService.reset_state() | 存档服务 | 强制释放状态锁 | ✅ 唯一入口 |
| player_controller.reset_stats_to() | 玩家 | 重建全新 PlayerStats（重启 run） | ✅ 唯一入口 |
| player_controller.reset_weapon_to_default() | 武器 | 武器重置 | ✅ 唯一入口 |

**结论：无重复 reset 逻辑**——6 个重置函数各司其职（Phase 18.2 起运行时数据禁止回写基线后职责边界清晰）。

## 5. 临时 debug 代码扫描

- 全部 [Jump *]/[Bullet] 刷屏日志：TASK-027 已移除 ✓
- 探针/临时脚本：均位于系统临时目录，从未入库 ✓
- 保留的日志（[SAVE]/LOAD_*/[RestartAudit]/[RoomTypeValidation]/[StateRestoreWarning]）：为验收排障证据，按用户要求保留

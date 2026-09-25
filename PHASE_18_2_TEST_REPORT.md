# PHASE_18_2_TEST_REPORT — Phase 18.2 稳定性修复测试报告

> 日期：2026-09-24
> 状态：**实施完成，等待人工验收**（按要求未提交 git）
> 配套：CODE_CLEANUP_REPORT.md（代码清理清单）

---

## 1. 修改文件列表

| # | 文件 | 改动 |
|---|---|---|
| 1 | client/scripts/managers/game_state_manager.gd | 三生命周期分离（新增 _profile_data + get_profile_data）；get_player_data/set_runtime_stats/sync_from_runtime_stats/get_save_data **运行时禁止回写基线**；set_current_save 恢复字段完整性检查 + [StateRestoreWarning] |
| 2 | client/scenes/game/game_scene.gd | restart_run 全新基线 = 默认属性 + 账号昵称（禁止读取死亡 PlayerStats/profile 属性快照） |
| 3 | client/scripts/player/player_controller.gd | reset_stats_to 增加 [RestartAudit] 审计日志（old/new/source）；revive() 归档移除 |
| 4 | client/scripts/world/floor_manager.gd | AI 内容应用层强制 room_type=房间类型（[RoomTypeValidation] 日志） |
| 5 | client/scripts/models/room_content_data.gd | 事件房 validate 增加输入/输出审计日志 |
| 6 | client/scripts/world/room_spawner.gd | _apply_level_modifier 归档移除 |
| 7 | client/deprecated/（新增目录）| 3 个废弃代码归档 + README 索引 |
| 8 | client/tests/test_restart_audit.gd | **新增**：重启 run 数据污染修复 13 检查项 |
| 9 | client/tests/test_event_room_purity.gd | **新增**：事件房纯净性 4 检查项（连续 10 次） |

## 2. 问题根因与修复（要点）

### 问题 1: Restart Run 数据污染（hp=0/level=3/gold=105）
- **根因**：`get_player_data()`（读取时回写）/`set_runtime_stats()`/`sync_from_runtime_stats()` 三处把**运行时数据（含死亡 hp=0）写回 `_player_data` 基线** → reset_run_state 保留污染基线 → restart 读取死数据。
- **修复**：三个数据生命周期分离——ProfileData（`_profile_data`，仅登录写入）/ SaveData（`_current_save`）/ RunData（`_runtime_stats`）；运行时读取经 runtime-first 分支实时返回，**永不回写基线**；restart 基线 = 默认属性 + 昵称。
- **审计日志**：`[RestartAudit] old stats / new stats / source`。

### 问题 2: 事件房怪物污染（Room Type:event 但 Finalized (combat) monsters=3）
- **根因**：`RoomContentData.room_type` 取自 **AI 响应**（可携带错误类型 + monsters）→ 事件房按 combat 规则校验放行怪物。
- **修复**：应用层（prefetch/apply）**强制 room_type=房间类型**（[RoomTypeValidation] 日志）→ validate_for_room_type 事件房怪物归零（输入/输出日志）。双保险：即使 AI 正确返回 event 类型，validate 兜底也归零。
- **规则固化**：event 房 monsters=0（对话/选择/奖励/属性变化/伤害事件允许；禁止 MonsterNode 生成）。

### 问题 3: 恢复链关键字段告警
- `set_current_save` 恢复时检查 9 个关键字段（level/experience/experience_to_next/max_health/current_health/attack/defense/gold/move_speed），缺失 → `[StateRestoreWarning] missing field=X` + 默认值（禁止静默隐藏错误）；字段名统一（Phase 18.1 已规整 health→current_health 等）。

## 3. 测试结果（全部真实运行）

| # | 用户要求 | 套件 | 结果 |
|---|---|---|---|
| 1 | 完整启动测试 | Godot headless --quit | ✅ 0 脚本错误 |
| 2 | 死亡 → Restart Run（HP 非 0/Level=1/Gold=0/武器默认） | test_restart_audit（新） | ✅ 13/13 |
| 3 | 事件房间连续 10 次（无隐藏怪物/无随机伤害） | test_event_room_purity（新） | ✅ 4/4 |
| 4 | 存档恢复（保存一次+重新登录一次，HUD/PlayerStats/WeaponInstance 一致） | test_full_progress_save_restore | ✅ 17/17 |
| 5 | 全部既有测试 | 其余 21 套客户端（16/2001/20/13/11/12/35/19/11/8/6/8/11/8/4/7/11/12/15/10） | ✅ 全绿 |
| 6 | 集成测试（真实 HTTP） | test_save_integration | ✅ 12/12 |
| 7 | 服务端 pytest | app/tests 5 + ai/tests 143 | ✅ 全过 |

## 4. 剩余风险

| # | 风险 | 说明 |
|---|---|---|
| R1 | room 级进度不存档 | 继续游戏当前楼层重新生成（设计限制） |
| R2 | profile 快照永不回写 | 主菜单玩家信息面板显示注册快照（分层设计） |
| R3 | move_speed/crit 加成字段游戏内消费 | 存档/恢复完整，消费为 backlog，不影响一致性 |

## 5. 人工验收步骤（服务端已运行、存档已清空）

**验收1（死亡重开）**：新游戏 → 升级到 Lv3+、捡金币 → 故意死亡 → GameOver → 点"重新开始" → 控制台出现 `[RestartAudit] old stats / new stats / source`，HUD 显示 **HP=100/100、Lv1、金币 0、初始武器**。
**验收2（事件房）**：连续进入 5+ 个事件房 → 无怪物出现、无异常伤害、事件面板正常；控制台无"Finalized room X (combat)"（事件房日志类型应为 event）。
**验收3（存档恢复）**：打到 3 层保存退出 → 重新登录 → 继续游戏 → 等级/经验/金币/HP/武器全部一致。

---

**Phase 18.2 实施完成。未提交 git，等待人工验收。**

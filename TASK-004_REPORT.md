# TASK-004_REPORT — 修复事件房错误进入战斗流程

> 任务等级：LEVEL-2（房间分发架构修改）
> 验证方式：代码检查 + 无头分发流程测试 + 无头启动检查 + 历史回归测试（未运行完整游戏流程，符合任务约束）

## 1. 根因分析

实机日志：`Room Type:event` 但依然 `Spawn monsters` + `CombatManager进入COMBAT`。

排查房间系统全链路（FloorManager → GameScene → RoomSpawner/RoomContentData → CombatManager），确认根因是**三层叠加**：

| 层 | 位置 | 旧代码 | 问题 |
|---|---|---|---|
| 数据层 | `room_content_data.gd` `setup_defaults_for_type("event")` | `monster_count = randi_range(0, 2)` | 事件房默认内容**66% 概率自带 1-2 只怪** |
| 校验层 | `room_content_data.gd` `validate_for_room_type()` | `"event": clampi(monster_count, 0, 2)` | 旧规则注释为"允许少量怪物"，本地与 AI 生成的怪物都被放行 |
| 流程层 | `game_scene.gd` `_on_fm_room_entered()` | `if content.monster_count > 0:` 就生成怪物+开战 | **不分房间类型**，在任何类型分发之前执行 |

结果：事件房只要内容带怪（默认 66% 概率），就先生成怪物、进入 COMBAT 状态，然后才走到 `_handle_event_room()` 显示面板——两种流程并行，正是日志所见。

顺带确认：reward 房默认/校验都是 0 怪（无此问题）；treasure 房默认可能有 1 怪但校验层已强制归零（无此问题）；仅 event 房的校验规则本身放行怪物。

## 2. 修改文件

| 文件 | 修改 |
|---|---|
| `client/scenes/game/game_scene.gd` | `_on_fm_room_entered()` 怪物生成+战斗启动分支增加房间类型闸门：仅 `COMBAT`/`ELITE` 型房间允许（BOSS 房此前已独立提前返回） |
| `client/scripts/models/room_content_data.gd` | ① `setup_defaults_for_type("event")` 改为 `monster_count = 0`；② `validate_for_room_type()` 的 event 规则改为强制 `monster_count = 0`（AI 内容同样归零）；③ 更新规则注释 |
| `client/tests/test_room_type_dispatch.gd` | **新增**永久回归测试（数据层 6 项 + 流程层 12 项 + 护栏 1 项 = 19 项断言） |

**未修改**：房间生成算法、AI 生成接口（`generate_room_content_from_new` 等调用链原样，校验层本来就是设计好的强制点）、奖励系统、战斗系统、CombatManager、RoomSpawner 内部逻辑。

## 3. 修改内容

### 3.1 流程层闸门（game_scene.gd）

```gdscript
# 普通战斗房间（TASK-004: 仅战斗型房间走怪物生成+战斗流程）
# 事件/奖励/宝箱等非战斗房禁止生成怪物，由下方类型分发处理各自流程
if room.room_type in [NewRoomData.RoomType.COMBAT, NewRoomData.RoomType.ELITE] and content.monster_count > 0:
	var monster_count = _room_spawner.spawn_monsters(content, room.position)
	if monster_count > 0:
		_combat_manager.start_combat(content)
```

即使未来 AI 或旧存档给事件房注入了带怪物的内容，流程层也会直接拦下。

### 3.2 数据层规则收紧（room_content_data.gd）

- 默认内容：event 房 `monster_count = 0`（不再随机 0-2）；
- 规则校验：event 房强制 `monster_count = 0`（原来 `clampi(0,2)` 放行）。

双保险后，事件房在数据源头就不可能携带怪物。

### 3.3 修复后的事件房完整流程

进入事件房 → 暂停玩家控制 → 显示事件面板 → 玩家选择 → 获得奖励/效果 → 恢复控制 → 1.5s 后完成房间 → 生成出口传送门。全程无怪物、无 COMBAT 状态。

## 4. 测试结果

| 测试 | 结果 |
|---|---|
| 无头启动检查（`--headless --quit`） | ✅ 零脚本错误 |
| 新增 `test_room_type_dispatch.gd` | ✅ **19/19** |
| 回归 `test_reward_system.gd`（TASK-001） | ✅ 12/12 |
| 回归 `test_reward_spawn_position.gd`（TASK-002） | ✅ 11/11 |
| 回归 `test_event_room.gd`（TASK-003） | ✅ 16/16 |

新测试覆盖点（按任务要求）：

- **数据层**：event 默认内容 0 怪；event 规则校验强制归零（含模拟 AI 注入 5 怪）；treasure/reward 校验 0 怪、combat/elite 校验 ≥1 怪（保证战斗房不受影响）；
- **流程层**（真实 game_scene 代码路径）：事件房内容带 2 怪（最坏情况）→ **monster_count==0**、**不触发 Combat Start**、控制暂停→恢复、**事件流程完成**、**portal 生成**（指向正确目标房）；战斗房回归 → 正常生成怪物+进入战斗；奖励房回归 → 无怪物+正常生成奖励。

## 5. 影响范围

- **行为变化**：事件房不再生成怪物/进入战斗（这就是修复目标）；奖励房/宝箱房/起始房行为不变；战斗房（COMBAT/ELITE）行为不变；
- 已知遗留（不在本任务范围，记录备查）：战斗房在进房时也走 `_` 分支提前创建传送门（B-05/B-10 已登记）；`GameStateManager` 状态机在测试环境从 0 态跳转有告警（仅测试环境，真实游戏流程正常）；
- 不影响：AI 生成接口、服务端、存档、怪物 AI。

## 6. 人工验收步骤（约 5-10 分钟）

1. **操作步骤**：① 正常启动游戏并登录（test001/test123456）② 前进多进几个房间，直到进入事件房（楼层中有事件标记的房间，可多打几层遇到）③ 观察进入瞬间是否有怪物出现、是否出现战斗提示 ④ 完成事件后进入下一房间，再打一个战斗房
2. **观察目标**：进入事件房**没有任何怪物生成**、HUD **不出现**"战斗开始"提示；面板弹出期间角色静止；事件完成后出口传送门出现；随后战斗房**依然正常**出怪、清怪后掉奖励
3. **通过标准**：事件房无怪物+无战斗提示+传送门正常，且战斗房流程与之前一致 = 通过；事件房仍出怪或战斗房不再出怪 = 不通过（截图/日志发我）

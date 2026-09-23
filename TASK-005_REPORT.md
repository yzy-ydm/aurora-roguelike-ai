# TASK-005_REPORT — 房间生命周期状态机重构

> 任务等级：LEVEL-2（架构重构 + 无头流程测试 + 全量回归）
> 验证方式：代码检查 + 无头状态机测试 + 无头启动检查 + 4 套历史回归测试
> 分析报告：TASK-005_IMPLEMENT_PLAN.md（阶段一产物，7 问题 P1-P7 详析）

## 1. 问题描述（实机日志驱动）

| # | 实机问题 | 根因 |
|---|---|---|
| P1 | 房间状态职责混乱：`visited`/`completed`/`enter_count` 三字段语义重叠，用"进入次数"推断"已完成" | `enter_count >= 2` 是启发式规则而非状态机 |
| P2 | `[PlatformRoom] Created exit portal to room 9` 重复出现两次（传送门重复创建） | 战斗房进房即建门 + 清怪再建门；渲染层无去重 |
| P3 | 奖励房完成后出口无法稳定进入：`[Portal] Current Room:9 Target Room:6` → 进入被拒 `already entered/completed, skipping`（玩家卡住） | 传送门目标③级兜底允许选择已完成房间 → `enter_room` 拒绝 |
| P4 | Boss 双重完成逻辑 | combat_manager 与 game_scene 各写一次 `_floor_manager._current_floor.complete_current_room()` |
| P5 | 战斗房清怪即出传送门（先于奖励拾取），与目标流程"奖励完成→出口"不符 | `_on_combat_cleared` 直接 `_complete_current_room("all_monsters_dead")` |
| P6 | 重复触发防护靠 `completed` 布尔锁 + 信号断开/重连 hack | TASK-001 遗留的幂等补丁 |
| P7 | 多脚本穿透 `_floor_manager._current_floor` 直写内部状态 | CombatManager 越权改房间完成状态 |

## 2. 架构修改方案

新增统一房间状态机（**NewRoomData** 为唯一权威来源）：

- **状态**：`RoomState { ENTERING, COMBAT, REWARD, EVENT, COMPLETED, EXITING }`
- **唯一入口**：`transition_to()` —— 合法转换表校验 + 完整日志；非法转换直接 REJECTED
- **进入限制**：统一使用 `is_completed()`（RoomState.COMPLETED 终态）；`enter_count` 仅保留为调试/存档/统计字段（禁止业务使用）
- **完成快照**：`completed` 保留为存档兼容快照（`transition_to(COMPLETED)` 时同步写）；业务判断一律读 `state`
- **传送门唯一性双保险**：状态机保证 `transition_to(COMPLETED)` 只成功一次（建门只在成功转换后执行）+ 渲染层 `_has_exit_portal` 同房去重
- **职责矩阵**：

| 脚本 | 允许 | 禁止 |
|---|---|---|
| NewRoomData | 唯一 transition_to() 校验器 + is_completed()/can_enter() | — |
| FloorData | 唯一状态写入口：complete_current_room() / set_current_room_state() | — |
| FloorManager | 进/出房调 FloorData 接口（EXITING/ENTERING + 拒绝 COMPLETED） | 直写 completed/visited/enter_count |
| GameScene | 流程编排：调统一接口推进状态；转换成功才建传送门 | 直写 completed/visited |
| CombatManager | 只管理战斗（怪物统计/清怪/Boss战） | 访问 `_floor_manager._current_floor`；修改任何房间状态 |

## 3. 状态流程图

```
战斗房: 进入→ENTERING→COMBAT(出怪开战)→怪物全部死亡→REWARD(生成奖励,无出口)
        →奖励全部领取→COMPLETED→创建唯一出口
奖励房: 进入→REWARD→全部奖励领取→COMPLETED→出口
事件房: 进入→EVENT→事件选择完成(1.5s)→COMPLETED→出口（全程无怪无战斗）
宝箱房: 进入→REWARD→宝箱全部打开→COMPLETED→出口
起始/商店/空房: 进入→COMPLETED→出口
Boss房: 进入→COMBAT→Boss死亡→REWARD(Boss奖励)→COMPLETED→楼层检查→下一层门

回溯: 未完成房被离开 → EXITING；再次进入 → ENTERING（可重打）
     COMPLETED = 终态：不可再转换、不可再进入

合法转换表:
  ENTERING → COMBAT / REWARD / EVENT / COMPLETED / EXITING
  COMBAT   → REWARD / EXITING / COMPLETED（仅异常兜底，如Boss生成失败）
  REWARD   → COMPLETED / EXITING
  EVENT    → COMPLETED / EXITING
  COMPLETED → （终态）
  EXITING  → ENTERING
```

## 4. 修改文件列表

| 文件 | 修改内容 |
|---|---|
| `client/scripts/models/new_room_data.gd` | 新增 RoomState 枚举、`state` 字段、`transition_to()`（合法转换表 + `[RoomState] Room ID: X \| OLD -> NEW` 日志 + 非法转换 REJECTED）、`is_completed()`/`can_enter()`/`state_to_string()`；`mark_completed` 降级为兼容接口；`is_cleared()` 改读 state；`to_dict` 增加 state；**保留** enter_count（统计）与 completed（兼容快照） |
| `client/scripts/models/floor_data.gd` | `complete_current_room()` 改走 `transition_to(COMPLETED)` 并返回 bool（删除 `enter_count = 2`）；新增 `set_current_room_state()`；`is_floor_complete()`/`get_completed_count()` 改读 RoomState |
| `client/scripts/world/floor_manager.gd` | `enter_room`：拒绝条件 `enter_count >= 2` → `room.is_completed()`；旧房未完成时 `transition_to(EXITING)`；新房 `transition_to(ENTERING)`；`enter_count += 1` 降级为统计字段 |
| `client/scenes/game/game_scene.gd` | ① 进房入口 `is_completed()` 防护（与 FloorManager 双层防御）② Boss 房进入转 COMBAT ③ 战斗房显式 COMBAT/ELITE 分支（不再落入 `_` 建门），出怪开战成功才转 COMBAT ④ REWARD/EVENT/TREASURE 分支进房转对应状态 ⑤ `_` 分支（START/商店/空房）改 `_complete_current_room("empty_room")` ⑥ Boss 失败兜底改统一完成入口 ⑦ 清怪回调：完成调用改为转 REWARD（**不出门**）⑧ `_complete_current_room` 重写：`is_completed()` 前置检查 → FloorData 统一接口 → 成功才建门 ⑨ `_create_room_exits`：目标过滤已完成房间，无有效目标时楼层完成走下一层流程否则不建门 ⑩ Boss 结算状态链 COMBAT→REWARD→COMPLETED |
| `client/scripts/combat/combat_manager.gd` | **删除** `on_boss_defeated` 中直写 `_floor_manager._current_floor.complete_current_room()`（Boss 完成统一由 GameScene 处理） |
| `client/scripts/world/room_renderer.gd` | 新增 `_has_exit_portal` 同房去重防护（`clear_exit_portals` 时重置）——状态机 + 渲染层双保险 |
| `client/tests/test_room_lifecycle.gd` | **新增**状态机测试（见 §5） |
| `client/tests/test_room_type_dispatch.gd` | TASK-004 测试桩补 `set_current_room_state` 桩方法（断言不变） |
| `TASK-005_IMPLEMENT_PLAN.md` | 阶段一分析报告（本任务分析产物，随提交入库） |

**未修改**：AI 系统、数据库、玩家系统、战斗数值、美术资源、房间生成算法、存档格式（to_dict 只增 `state` 字段，读取路径不变）。

## 5. 测试结果

| 测试 | 结果 |
|---|---|
| 无头启动检查（`--headless --quit`） | ✅ 零脚本错误 |
| 新增 `test_room_lifecycle.gd` | ✅ **35/35** |
| 回归 `test_reward_system.gd`（TASK-001） | ✅ 12/12 |
| 回归 `test_reward_spawn_position.gd`（TASK-002） | ✅ 11/11 |
| 回归 `test_event_room.gd`（TASK-003） | ✅ 16/16 |
| 回归 `test_room_type_dispatch.gd`（TASK-004） | ✅ 19/19 |
| 静态检查 | ✅ `enter_count >= 2` 业务判断清零；`completed` 业务读取仅存死代码；CombatManager 直写已删除 |

新测试覆盖点（真实 NewRoomData + 真实 FloorData + 真实 game_scene 代码路径）：

1. **转换合法性**：默认 ENTERING；ENTERING→COMBAT→REWARD→COMPLETED 合法链（含 completed 兼容快照同步）；COMPLETED 终态拒绝；COMBAT→COMPLETED 异常兜底路径；COMBAT→EVENT 非法拒绝且状态不变；EXITING→ENTERING 回溯合法；`can_enter()` 语义；
2. **战斗房完整生命周期**：进房出怪开战转 COMBAT、**进房无出口**；清怪转 REWARD、生成奖励、**仍无出口**；奖励领取完转 COMPLETED、**恰好 1 个出口**、目标正确；
3. **奖励房生命周期**：无怪无战斗、进房转 REWARD、拾取完成转 COMPLETED、1 个出口；
4. **事件房生命周期**：内容带 2 怪（最坏情况）仍无怪无战斗、转 EVENT、控制暂停、1.5s 后转 COMPLETED、1 个出口；
5. **重复完成保护**：二次调用完成逻辑被终态拦截（`Room already COMPLETED, skip`）不产生第二个出口；重复进入已完成房不生成任何内容。

测试环境已知无害警告：`[GameStateManager] Invalid state transition: 0 -> 3`（仅测试环境从 0 态跳转，真实游戏流程正常，TASK-004 已记录）。

## 6. 已知风险

| # | 风险 | 评估 |
|---|---|---|
| R1 | 战斗房出口从"清怪即出"改为"奖励领取完才出"，若奖励无法拾取会无出口（软锁） | TASK-001 保证至少 1 奖励、TASK-002 保证可拾取；新测试覆盖全流程；人工验收重点观察战斗房出口 |
| R2 | 起始/商店/空房现在也会变 COMPLETED | `is_floor_complete` 只看 Boss 房，不受影响；`get_completed_count` 统计含义变化无害 |
| R3 | COMBAT→COMPLETED 为异常兜底路径放宽了转换表 | 仅 Boss 生成失败等异常兜底使用；正常战斗流程代码路径仍强制经 REWARD |
| R4 | 传送门目标过滤后无有效目标时不建门 | 正常线性推进必有未访问目标；楼层完成时走下一层门；异常情况下玩家会看到"附近没有可探索的房间了"提示（比旧版"进入被拒卡死"更好） |
| R5 | 存档兼容 | to_dict 只增 state 字段；completed/visited 快照字段原样保留，旧存档读取路径不变 |

## 7. 人工验收步骤（约 10 分钟）

1. **操作步骤**：① 正常启动游戏并登录（test001/test123456）② 打一个战斗房：击杀全部怪物 → 观察此时**没有**出口传送门 → 拾取所有奖励 → 出口传送门出现 → 进入 ③ 打一个奖励房：拾取所有奖励 → 出口出现且**可以进入** ④ 打一个事件房：完成事件 → 出口出现 ⑤ 观察控制台日志，确认每个房间只有一条 `[RoomState] Room ID: X | ... -> COMPLETED`、只有一条 `Created exit portal`
2. **观察目标**：出口传送门**恰好一个**且只在完成流程后出现；日志中不再出现重复 `Created exit portal`；进入出口后不再出现 `already entered/completed, skipping`
3. **通过标准**：三个房型出口都唯一且可进入、无重复建门日志、无 "skipping" = 通过；出口不出现或重复建门 = 不通过（截图/日志发我）

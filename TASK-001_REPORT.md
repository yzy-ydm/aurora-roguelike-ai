# TASK-001_REPORT — 奖励系统修复（B-01）

> 任务等级：LEVEL-2（奖励系统模块）
> 状态：已完成，用户已确认核心闭环（战斗/怪物/EXP升级/奖励/传送门全部正常）

## 1. 修改内容

| 文件 | 修改 |
|---|---|
| `client/scripts/drop/reward_item.gd` | 新增 `set_spawn_position()`：出生点由 RoomSpawner 在 add_child **之前**设置，同时校准浮动动画起点；删除调试刷屏日志 |
| `client/scripts/world/room_spawner.gd` | `spawn_rewards` 奖励数钳制 `maxi(1, reward_count)`；新增公开接口 `spawn_reward(reward_data, local_pos)`；`_spawn_single_reward` 改为"先定位后入树"；`_on_reward_collected` 按 bind 的节点引用精确移除已收集奖励（修复收集后列表不清空 → 出口永不出现） |
| `client/scenes/game/game_scene.gd` | 宝箱房 `_handle_treasure_room` 改用公开 `spawn_reward()` 接口并生成在地面高度（旧代码生成在 y∈[-30,30] 空中不可达）；`_complete_current_room` 幂等保护（已完成房间不重复创建传送门） |
| `client/scripts/world/world_coordinate.gd` | 怪物出生高度 298→282（怪物 28px 高，出生在地面站立位置而非陷入地面 16px）——修复子弹无法命中怪物的真因 |
| `client/scripts/combat/bullet.gd` | 仅注释修正：明确碰撞层数值约定（Wall=1, Player=2, Enemy=4, PlayerBullet=8, EnemyBullet=16），掩码 5 = Wall+Enemy 经核对正确并还原 |
| `client/tests/test_reward_system.gd` | 新增永久回归测试（4 组：出生位置/浮动动画/物理拾取/信号链），12/12 通过 |

## 2. 修改原因

B-01：奖励在 Reward/宝箱房生成后不可见、不可拾取。两个根因：

1. `_ready` 在 add_child 时触发，先于 position 赋值，捕获出生点为 (0,0)；浮动动画每帧把 `position.y` 写回 `_start_position.y + sin(...)`，把奖励拉回房间中心高度；
2. 收集回调通过 `queue_free` 时序清列表，已收集节点在 tween 结束前仍在列表中 → `all_rewards_collected` 永不触发 → 房间死锁、出口不出现。

沿路发现的关联问题一并修复（怪物陷入地面导致子弹打不到、战斗房双传送门重复创建）。

## 3. 影响范围

- 奖励生成链路：`RoomSpawner.spawn_rewards / spawn_reward`（战斗清房奖励、Reward 房、宝箱房、Boss 奖励共用同一接口）
- 房间完成状态机：`_complete_current_room` 幂等化（对 `floor_data.complete_current_room` 与传送门创建）
- 怪物出生坐标：所有战斗房间的怪物生成位置（世界坐标不变，仅高度修正）
- 不影响：存档、AI 生成、服务端、房间拓扑生成架构

## 4. 测试方法

1. 无头回归测试：`test_reward_system.gd` —— **12/12 通过**
2. 实机验证（Windows GUI 自动化）：登录 → 进入战斗房 → 击杀 4 只怪物 → 奖励生成 → 拾取（`[Reward] Collected: 基础手枪`，武器已装备、伤害 20）→ `[RoomComplete]` → 传送门创建
3. 用户人工验收：已确认战斗流程/怪物生成/EXP升级/奖励系统/传送门创建全部正常

## 5. 测试结果

**通过。** 奖励生成→显示→拾取→出口闭环成立。

## 发现的其他问题（本任务未处理，后续任务跟踪）

- **B-09**：战斗房地面高度平台可能阻挡玩家拾取（实机第 2 个奖励被平台挡住）→ 已由 TASK-002 承接
- **monster_node.gd 碰撞掩码 11→263**（早期会话遗留 WIP）：263 = Wall+Player+Enemy+256（层 256 全项目无人使用，位元为死值）；缺 PlayerBullet(8) 位目前无害（子弹 Area2D 用自身掩码 5 检测怪物），但怪物间碰撞（Enemy 位）与死位应在战斗任务（B-02/B-03）中一并核对清理
- 战斗房在**进入房间时**即创建传送门的分发缺陷（`match` 的 `_` 分支）——TASK-001 幂等保护已保证不重复创建，但正确性修复归入房间导航任务（B-05/B-10）

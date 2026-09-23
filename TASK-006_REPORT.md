# TASK-006_REPORT — 楼层地图探索闭环修复

> 任务等级：LEVEL-2（地图生成算法重写 + 无头生成测试 + 全量回归）
> 验证方式：代码检查 + 无头生成测试（200层×10项）+ 无头启动检查 + 5 套历史回归测试
> 前置文档：TASK-006_ANALYSIS_REPORT.md（根因分析）、TASK-006_IMPLEMENT_PLAN.md（实施计划）

## 1. 问题描述（实机日志驱动）

| # | 实机问题 | 根因 |
|---|---|---|
| P1 | 完成第 10 个战斗房后：`[GameScene] No valid exit targets, skip portal creation` → 玩家软锁 | 房间连接是无向**树**：每层产生 3~6 个分支叶子死胡同 |
| P2 | 导航策略是**前向单向推进** + 已完成房禁止进入 | 与树形拓扑结构性矛盾：走进分支叶子房后，唯一邻居已完成 → 无出口 |
| P3 | Boss 可达率仅 36%~86%（理论推算） | 树形生成下 Boss 永远是叶子，是否落在可达分支纯靠运气 |

**结论**：软锁不是偶发 bug，而是"树形地图 × 单向禁回溯导航"的结构矛盾，必须修复地图拓扑。

## 2. 架构修改方案

**核心：树形随机生成 → 分层 DAG（前向无环图）**

```
START(层0) → 中间层1 → 中间层2 → ... → 中间层4~6 → BOSS(最后一层，唯一)
```

| 用户要求 | 落地 |
|---|---|
| START 层 → 4~6 层中间节点 → 最后一层唯一 Boss | 层容量分配 `[1] + [1]*mid_layers + [1]`（中间层每层 1~3 房） |
| 所有普通房 ≥1 个下一层连接 | 4c 出边保证（缺者随机补边） |
| Boss 无下一层 | Boss 层为最后一层，永不加前向边 |
| 禁止回边 | 生成只加"层号+1"方向边（反向条目为双向对账记录） |
| 禁止自环 | 跨层连接天然无自环 + 校验 V7 显式断言 |
| 禁止重复连接 | `add_connection` 自带去重 + 校验 V7 显式断言 |
| start→boss 永远可达 | 4a spine 主干（每层第0房连下一层第0房）+ 4b 入边保证 + 校验断言 |
| 总房数 8~13（原 9~13） | `_min_rooms/_max_rooms` 语义改为总房数 |

**连接生成 4 步骤**（每步只加前向边，`add_connection` 自动双向对账 + 去重）：
- **4a spine**：`layer[l][0] ↔ layer[l+1][0]`（l=0..最后，直连 Boss）→ 主干路径由构造保证
- **4b 入边保证**：`layer[l+1]` 每个房 ≥1 条来自 `layer[l]` 的边
- **4c 出边保证**：`layer[l]` 每个房 ≥1 条去往 `layer[l+1]` 的边（**无死胡同**）
- **4d 可选第二前向边**：概率 `_branch_chance=0.4`，连下一层另一未连房

**校验 `validate_floor()`（V1~V7，失败自动重试最多 5 次）**：

| # | 检查项 | 对应要求 |
|---|---|---|
| V1 | 房间数 ∈ [8,13] | 数量规模 |
| V2 | START 恰 1 个且 id=0；BOSS 恰 1 个且 id=最后 | Boss 存在 |
| V3 | START 沿前向边 BFS 可达全部房间 | 所有房间可达 |
| V4 | BFS 可达集包含 BOSS | START→Boss 路径存在 |
| V5 | 非 Boss 房前向出度 ≥1 | 无死胡同 |
| V6 | Boss 前向出度 = 0 | Boss 为终点 |
| V7 | 无自环/无重复/双向对账/仅相邻层连接 | 无环/无回边/无跨层 |

**出口逻辑（保持 TASK-005 语义不变：单出口、已完成房排除、楼层完成→下一层门）**：

```
[PortalSelection] room X candidates=[...]           ← 防御日志
[PortalSelection] priority1 unvisited -> room Y     ← 优先未访问
[PortalSelection] priority2 unfinished -> room Y    ← 次选未完成
无有效目标且楼层未完成 → 紧急出口（理论不可达的防御兜底，绝不软锁）:
  优先级: 未完成BOSS房 > 未访问非当前房 > 未完成非当前房
  [PortalSelection] EMERGENCY: portal to room Y (reason)
绝对兜底 → [PortalSelection] ERROR + HUD 提示
```

**层号推算**：`layer = int(round(position.x / ROOM_SPACING_X))`，生成时 `x = 层号 × 1240` 精确整数值，无浮点误差；校验器与生成器同文件，契约封闭。

## 3. 修改文件列表

| 文件 | 修改内容 |
|---|---|
| `client/scripts/world/floor_generator.gd` | **重写**生成算法：`generate_floor()` 树形 → 分层 DAG（签名/返回类型不变，FloorManager 与 AI 降级路径透明兼容）；新增 `validate_floor()`（V1~V7 + `[FloorValidation]` 日志）+ 校验失败重试（`MAX_GENERATE_ATTEMPTS=5`）；新增 `_generate_layered_floor()` / `_connect_forward()` / `_get_room_layer()`；`_min_rooms/_max_rooms` 语义改为总房数 8~13；`_branch_chance` 改义为第二前向边概率；**未动**：`_get_random_room_type` / `print_floor_graph` / `get_floor_graph_string` / `create_rooms_from_ai_data` / `_parse_room_type` |
| `client/scenes/game/game_scene.gd` | `_create_room_exits()`：新增 `[PortalSelection]` 防御日志（候选列表/选中原因）；无有效目标时：楼层完成走下一层流程，否则新增 `_emergency_exit_portal()` 紧急出口兜底（未完成BOSS > 未访问 > 未完成；绝对兜底 HUD 提示）。**保持**：单出口 / completed 房禁止进入 / 其余流程零改动 |
| `client/tests/test_floor_generation.gd` | **新增**（见 §5） |
| `TASK-006_ANALYSIS_REPORT.md` | 阶段一根因分析报告（随提交入库） |
| `TASK-006_IMPLEMENT_PLAN.md` | 阶段一实施计划（随提交入库） |

**未修改**：TASK-005 房间状态机（RoomState/transition_to/completed 业务逻辑/CombatManager 流程）、AI 系统、数据库、玩家系统、武器、怪物、战斗数值、存档格式（存档不存地图拓扑，生成算法变化对存档透明）；**未清理**死代码（RoomGraph/RoomManager/map_renderer 保持原样）。

## 4. 测试结果

| 测试 | 结果 |
|---|---|
| 新增 `test_floor_generation.gd`（200 层 × 10 项 + 元护栏 = 2001 项） | ✅ **2001/2001** |
| 回归 `test_reward_system.gd`（TASK-001） | ✅ 12/12 |
| 回归 `test_reward_spawn_position.gd`（TASK-002） | ✅ 11/11 |
| 回归 `test_event_room.gd`（TASK-003） | ✅ 16/16 |
| 回归 `test_room_type_dispatch.gd`（TASK-004） | ✅ 19/19 |
| 回归 `test_room_lifecycle.gd`（TASK-005） | ✅ 35/35 |
| 无头启动检查（`--headless --quit`） | ✅ 零脚本错误 |

新测试每层 10 项检查（F1~F10）：房间数 8~13 / START 唯一 / BOSS 唯一且 id=最后 / 全房间可达 / Boss 可达 / 无死胡同 / Boss 出度=0 / 连接合法（无自环/无重复/双向对账/相邻层）/ `validate_floor()` 通过 / **遍历模拟（镜像 `_create_room_exits` 选路策略，从 START 一路走到 BOSS，即 Room10 软锁现场回归）**。附元护栏：2000 项楼层检查 + 1 项护栏自身必须全部执行，防止运行时错误静默中断。

200 次随机生成统计（随机种子，每次运行分布不同）：

```
Room count distribution: {8:38, 9:40, 10:30, 11:30, 12:35, 13:27}
Layer count distribution: {6:68, 7:73, 8:59}   ← 中间层4~6 + START层 + Boss层
```

## 5. 已知风险

| # | 风险 | 评估 |
|---|---|---|
| R1 | 同层房间 x 坐标相同、y 仅抖动 ±50 → 虚拟坐标重叠 | 无害：同一时刻只渲染当前房（render_room 独占渲染），坐标仅是内容锚点 |
| R2 | 单出口自动选路 → 未选中的同层分支内容不可见 | 已确认的设计取舍（单出口由需求固定），不属缺陷 |
| R3 | AI 降级路径 `_generate_fallback_floor` 复用 `generate_floor` | 签名/返回不变 → 透明兼容；AI 系统零改动 |
| R4 | `_min_rooms/_max_rooms` 语义变化（旧：偏置计数 → 新：总房数） | 仅 floor_generator 内部使用，无外部引用 |
| R5 | 存档兼容 | 已核实存档不存拓扑（只存楼层号+玩家状态）→ 无影响 |
| R6 | 校验依赖 `position.x` 推层号 | x 恒为 `层号 × 1240` 精确赋值；校验器与生成器同文件，契约封闭 |
| R7 | 紧急出口属"理论不可达"防御路径 | DAG 结构保证正常不会触发；若实机出现 `[PortalSelection] WARNING/EMERGENCY` 日志，请截图反馈（说明校验有漏洞） |

## 6. 人工验收步骤（约 15 分钟）

1. **操作步骤**：① 正常启动游戏并登录（test001/test123456）② 完整打一整层楼：从 START 出发，每完成一个房间（战斗/奖励/事件/商店）就走进出口传送门，连续推进直到 Boss 房 ③ 击败 Boss → 楼层完成 → 下一层门出现 → 进入下一层 ④ 再重复打 1~2 层确认可持续 ⑤ 过程中留意控制台日志
2. **观察目标**：每层生成时日志出现 `[Floor] Generated X rooms (layered DAG, validated)` 与 `[FloorValidation] ALL CHECKS PASSED`；每个房间完成后出口正常出现；出现 `[PortalSelection] room X candidates=[...]` 日志；**不再出现**旧软锁日志 `No valid exit targets, skip portal creation`
3. **通过标准**：连续推进直到 Boss 并正常完成至少 1 层、可进入下一层继续推进 = 通过；任何房间完成后无出口 / 无法到达 Boss / 出现 `[PortalSelection] WARNING` 或 `EMERGENCY` 日志 = 不通过（截图/日志发我）

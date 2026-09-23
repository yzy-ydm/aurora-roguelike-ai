# TASK-006_ANALYSIS_REPORT — 楼层地图探索闭环审计

> 阶段：TASK-006 第一阶段（分析审计，**不修改任何代码**）
> 日期：2026-09-23
> 范围：FloorGenerator / FloorData / RoomGraph / 房间连接算法 / _create_room_exits 出口生成
> 触发现场：实机完成第 10 个战斗房（room_id=10, type=combat）后日志出现
> `[GameScene] No valid exit targets, skip portal creation`，玩家卡死。

---

## 0. 结论摘要（TL;DR）

1. **卡死直接原因**：房间 10 是一个"分支死胡同"房间，它的唯一连接（父房）已经 COMPLETED。TASK-005 修正后的 `_create_room_exits` 正确排除了已完成房，导致"无有效目标 → 不建门"，玩家被软锁。**TASK-005 的逻辑没有错，是地图生成算法产出的拓扑违法了出口策略的前提。**
2. **系统性根因**：地图是**无向树**（每层 3~6 个死胡同分支），而导航是**严格前向、禁止返回已完成房**。生成假设"可以走回头路"，导航禁止"走回头路"——两个系统的契约互相矛盾。
3. **Boss 可达性不保证**：树中 start→boss 路径必然存在，但导航遍历会被"挂在最后一个主线房上的分支"先劫持，走进分支后困死在叶子房。估算 **36%~86% 的楼层（取决于随机参数）永远走不到 Boss**。
4. **修复方向**：把地图从"树 + 死胡同"改为**分层前向 DAG**（杀戮尖塔式），死胡同在结构上不可能出现，卡死从根上消除；TASK-005 状态机规则**一行都不用改**。
5. 本报告 §4 给出正式 TASK-006 设计方案（A~E），**等待确认后实施**。

---

## 1. 现场证据还原：为什么 Room 10 没有出口

### 1.1 日志链路

```
[RoomComplete] room_id=10 type=combat reason=reward_phase_completed
[RoomState] Room ID: 10 | REWARD -> COMPLETED
[GameScene] No valid exit targets, skip portal creation
```

对应代码路径：

1. 战斗房 10 清怪 → `REWARD`（[game_scene.gd:760](client/scenes/game/game_scene.gd#L760)），奖励拾取完 → `_on_combat_room_completed` → `_complete_current_room("reward_phase_completed")`（[game_scene.gd:763-766](client/scenes/game/game_scene.gd#L763-L766)）→ `transition_to(COMPLETED)` 成功（[new_room_data.gd:127](client/scripts/models/new_room_data.gd#L127)）。
2. 随后调用 `_create_room_exits()`（[game_scene.gd:1027](client/scenes/game/game_scene.gd#L1027)）：
   - 取 `get_available_exit_ids()` = 房间 10 的 `connections.duplicate()`（[floor_data.gd:86-90](client/scripts/models/floor_data.gd#L86-L90)）。
   - 第一优先"未访问房"：房间 10 的全部连接都已访问过 → 无候选。
   - 第二优先"未完成房"：唯一邻居是它的父房（分支挂靠点），**已被玩家完成过** → 无候选。
   - `target_id == -1` 且 `is_floor_complete() == false`（Boss 未打）→ 打印 `No valid exit targets, skip portal creation`，不建门（[game_scene.gd:1075-1082](client/scenes/game/game_scene.gd#L1075-L1082)）。
3. 玩家所在房间没有传送门、进不来也出不去 → **软锁**。

### 1.2 为什么房间 10 会处在这个位置

由 §2 的生成算法可知：房间 10 是**分支房**（id 顺序上 main path 最多到 6，Boss 是最后一个 id；日志 type=combat 排除 Boss）。分支房只有一条连接（挂靠的父房），且父房早在玩家走到这里之前就已经 COMPLETED。**死胡同 + 禁止回已完成房 = 无路可走。**

---

## 2. 地图生成审计

### 2.1 架构现状（谁在管地图）

| 脚本 | 状态 | 职责 |
|---|---|---|
| [floor_generator.gd](client/scripts/world/floor_generator.gd) | **活跃，唯一拓扑生成源** | 随机生成一层房间结构 |
| [floor_data.gd](client/scripts/models/floor_data.gd) | 活跃 | 拓扑存储 + 查询 + 完成判定 |
| [floor_manager.gd](client/scripts/world/floor_manager.gd) | 活跃 | 进房/出房/导航执行 |
| [room_graph.gd](client/scripts/world/room_graph.gd) | **死代码**（标注 @deprecated，全工程无实例化） | 旧实现，已停用 |
| [room_manager.gd](client/scripts/world/room_manager.gd) | **死代码**（同上） | 旧实现，已停用 |
| [map_renderer.gd](client/scripts/world/map_renderer.gd) | **死代码**（@deprecated，用旧 RoomData 模型） | 旧实现，已停用 |

> 说明：AI 楼层生成已由 Phase 25 锁定（[floor_manager.gd:162-167](client/scripts/world/floor_manager.gd#L162-L167)），FloorGenerator 是唯一拓扑来源。RoomGraph/RoomManager/map_renderer 三份死代码建议日后清理（本次不涉及）。

### 2.2 当前生成算法逐行分析（[floor_generator.gd:20-82](client/scripts/world/floor_generator.gd#L20-L82)）

```
room_count = randi_range(8, 12)            # 实际总房数 = room_count + 1 = 9~13
START(0) → 主路径 mp = randi_range(4,6) 个房间(1..mp) 向右延伸
分支 b = room_count - mp - 1 个房间(mp+1..mp+b)：
    每个分支随机挂在 rooms[randi() % rooms.size()] 上（含 START/主线/已生成的分支）
Boss(mp+b+1 = room_count) 挂在"最后一个主线房"右侧
```

**结构性质（数学推导，非推测）**：

1. **是树**：每个新房间恰好新增 1 条双向边挂到已有房间 → n 房 n-1 边且连通 → 无环、无孤立点。
2. **死胡同必然存在**：每层的 3~6 个分支房中，凡是"没有被后续分支挂靠"的，都是叶子（只有一条连接）。分支链的末端必然是叶子。
3. **Boss 永远是叶子**：分支只挂在"生成时刻已存在的房间"上，Boss 最后创建 → 没有任何分支能挂到 Boss。
4. **start→boss 路径在图里必然存在**（树连通），但**导航走不走得到是另一回事**（见 §2.4）。

### 2.3 四个审计问题的回答

| 审计问题 | 结论 | 证据 |
|---|---|---|
| 房间连接是否保证连通 | ✅ 保证（树构造：每个新房间都挂到已有房间） | floor_generator.gd:43-44、66-67、76-77 |
| 是否可能生成死胡同 | ❌ **必然生成**（每层 3~6 个分支即 3~6 个死胡同叶子） | 分支只加一条边（:66-67），叶子无出口 |
| 是否保证 Boss 房为终点 | ⚠️ 图结构上是叶子；**导航上不保证能到达**（会被分支劫持，见 §2.4） | 连接顺序 `[mp-1, 分支…, boss]`，boss 排在分支之后 |
| 是否保证 start 到 boss 存在路径 | ✅ 图里存在（树连通）；❌ **导航不一定能走通** | 导航在前向单出口 + 禁止回已完成房规则下会困死在分支叶子 |

### 2.4 导航走不到 Boss 的机制与概率

`_create_room_exits` 选择"**connections 中第一个未访问房**"（[game_scene.gd:1056-1062](client/scenes/game/game_scene.gd#L1056-L1062)）。而 `connections` 的 append 顺序是：主路径边先加、分支边后加、**Boss 边最后加**。因此：

- 在主线房 k（k < mp）：connections = `[k-1, k+1, 分支…]` → 第一个未访问总是 k+1 → 被强制走主线。
- 在最后一个主线房 mp：connections = `[mp-1, 挂在mp上的分支…, boss]` → mp-1 已完成 → **第一个未访问是"挂在 mp 上的第一个分支"**（如果有），Boss 排在分支之后永远轮不到。
- 走进分支链 → 走到链末端叶子 → 叶子唯一邻居（父房）已 COMPLETED → 卡死（即 Room 10 现场）。

**Boss 可达概率** = P(没有任何分支挂在 mp 上) = ∏(1 − 1/(mp+1+i)) = **mp / (room_count − 1)**：

| room_count | mp=4 | mp=5 | mp=6 |
|---|---|---|---|
| 8 (b=1~3) | 57% | 71% | 86% |
| 10 | 44% | 56% | 67% |
| 12 | **36%** | 45% | 55% |

即**最坏约三分之二的楼层必然走不到 Boss**；即便走得通，挂在 0..mp−1 上的分支也永远轮不到访问（内容浪费）。玩家没有任何选择权——不是"玩家选错了路"，而是"随机生成决定这一局是否必死"。

---

## 3. 出口生成审计（_create_room_exits）

### 3.1 当前逻辑（[game_scene.gd:1035-1087](client/scenes/game/game_scene.gd#L1035-L1087)）

```
候选 = 当前房.connections（全部邻居，含已完成房）
优先1：未访问房（visited == false）
优先2：未完成房（is_completed() == false，允许回溯到未完成房）
两者都无：
  楼层完成(Boss已完成) → 下一层门
  否则 → "No valid exit targets, skip portal creation"（本次卡死点）
```

### 3.2 问题一：为什么 Room 10 没有出口

见 §1。直接原因：**唯一邻居已完成**；深层原因：**生成器产出了死胡同叶子，而出口策略合法地拒绝指向已完成房**。TASK-005 删除旧"任意房兜底"是对的（旧兜底导致 P3"进入已完成房被拒"），但暴露出生成层缺陷：导航层此前是靠"错误兜底"苟活的。

### 3.3 问题二：当前设计是否允许返回已完成房

**不允许，且是双重禁止**：

1. `FloorManager.enter_room`：`is_completed()` → 拒绝（[floor_manager.gd:184-186](client/scripts/world/floor_manager.gd#L184-L186)）。
2. `_create_room_exits`：已完成房一律排除出传送门候选（[game_scene.gd:1065-1072](client/scenes/game/game_scene.gd#L1065-L1072)）。

另有两点佐证：

- "优先2 未完成房"在真实流程中**几乎不可能触发**：房一旦被访问，玩家只能在完成它之后才离得开（出口只在 COMPLETED 后创建），所以"已访问未完成"的邻居在正常游玩中不存在——这是防御性死代码，但也说明**系统完全没有回溯能力**。
- 玩家无法"回头"：一旦走进分支，主线方向全部封死。

### 3.4 问题三：是否符合 Roguelike 地图设计

**不符合。** 对照三类主流设计：

| 范式 | 地图结构 | 导航规则 | 本项目现状 |
|---|---|---|---|
| 杀戮尖塔（爬塔） | 分层 DAG，只前向、多路径汇聚到 Boss | 不回退 | ✅ 本项目导航规则 = 爬塔式 |
| Dead Cells（横版动作） | 树/网 + 双向门 | **可自由回已完成房** | ❌ 本项目地图 = 树，但禁止回已完成房 |
| 哈迪斯 | 房间网，自由回溯 | 可回已完成房 | ❌ 同上 |

**结论：本项目是"爬塔式导航规则"配了"Dead Cells 式树形地图"——两套不兼容的设计被拼在了一起。** 爬塔式导航的前提是 DAG（每个节点必有前向出边）；树形地图的前提是可回溯。当前系统两者皆无，软锁是结构必然，不是偶发 bug。

---

## 4. 正式 TASK-006 设计方案

### 4.0 总原则

> **生成器保证"图合法"，导航器保证"流程合法"。** 图合法 = 不存在死胡同、Boss 可达、每房必有前向出边；流程合法 = TASK-005 状态机规则原样不动。两件事解耦后，卡死从结构上不可能发生。

### A. 地图生成约束

1. **分层结构**：L 层（L = 4~6，随机）。第 0 层 = START 单房；第 L−1 层 = BOSS 单房；中间层各 1~3 房。总房数保持 8~13 量级（与现状一致）。
2. **方向约束**：房间只允许连接"下一层"的房间（前向边）；**禁止同层边、禁止回边、禁止自环、禁止重复边**。
3. **出度约束**：每个非 Boss 房 **≥1 条前向边**（死胡同在结构上不可能出现）。
4. **入度约束**：每个非 START 房 ≥1 条入边（所有房间可达）。
5. **主干道（spine）**：每层第 0 号房必须前向连接下一层第 0 号房 → **start→boss 路径由构造保证**，不依赖随机。
6. **生成后校验** `_validate_floor(rooms) -> bool`：校验出度/入度/Boss 可达/无孤立房，失败则重新生成一次，再失败打印 ERROR 日志（绝不让非法拓扑进入游戏）。
7. **坐标约束**：x = 层号 × ROOM_SPACING_X（保持门对门对齐与传送门位置语义），y 保留 ±50 级微抖动。

### B. 房间连接规则

1. 仅前向连接；每房 1~2 条前向边（随机选择下一层的目标房）。
2. spine 规则（A.5）为硬约束，其余前向边随机补充。
3. 连接 append 顺序：先 spine 边、后随机边 → 保证"第一个未访问房"策略仍能稳定工作。
4. 分支语义 = 中间层的额外房间：从任何房间出发，其前向边目标在首次到达时**必然全部未访问**（前向单行道不可能预先访问）→ 出口策略永远不会空手而归。
5. 房间类型概率、内容生成（AI 增强/规则校验）**全部不变**——本次只改拓扑，不动内容系统。

### C. Boss 房生成规则

1. Boss 单独占最后一层、单房（现状语义保持）。
2. 由 spine 保证可达；由出度规则保证"从任意房间出发都能继续前向推进，最终必然抵达 Boss 层"。
3. Boss 无前向边（叶子）→ 完成即 `is_floor_complete()` → 下一层传送门（现有 `_on_boss_defeated` / `_on_floor_completed` 流程**不变**）。
4. `_validate_floor` 中显式断言"Boss 存在且可达"。

### D. 出口选择策略（_create_room_exits 调整方向）

1. **优先 1**：前向未访问房（DAG 构造保证 ≥1 个存在 → "无有效目标"分支成为不可达死代码）。
2. **优先 2**（防御保留）：未完成房（TASK-005 语义不变，仅作防御）。
3. **兜底逃生舱**：若仍无目标（理论上不可能，防御性兜底）——楼层完成 → 下一层门；否则打印 `[GameScene] ERROR: no exit target (should not happen)` 并**直连未访问 Boss 房作为紧急出口**。**宁可让玩家跳过探索，绝不软锁。**
4. **单出口 vs 多出口**：本任务保持**单出口**（稳定性优先、改动最小、与 TASK-005"一房一出口"规则一致）；"多出口 = 玩家选择分支"是后续可选的玩法扩展，不属本任务。
5. 目标过滤规则不变：**已完成房一律排除**（TASK-005 已验收规则，不动）。

### E. 状态机与地图系统之间的职责划分

| 层 | 职责 | 禁止 |
|---|---|---|
| NewRoomData / RoomState | 单房生命周期状态机（TASK-005 **原样不动**） | 不感知拓扑结构 |
| FloorGenerator | 拓扑构建 + 结构不变量保证（连通/前向边/入边/Boss 可达/生成后校验） | 不感知 RoomState、不参与运行时流程 |
| FloorData | 拓扑存储 + 查询（get_room / get_available_exit_ids / is_floor_complete） | 不决定出口策略 |
| FloorManager | 进房/出房执行（拒绝 COMPLETED、EXITING/ENTERING 转换，TASK-005 不变） | 不建门、不选目标 |
| GameScene._create_room_exits | 出口**策略**：在合法拓扑内按状态过滤选目标 + 逃生舱兜底 | 不再承担"防止卡死"的结构责任 |

**关键解耦**：卡死问题从此由 FloorGenerator 的校验兜底（生成侧保证），而不是由 GameScene 的 if-else 兜底（运行侧救火）。运行侧兜底只保留为最后一道防御。

### 4.1 备选方案（不推荐本次采用）：回溯式（Dead Cells 式）

- 做法：修改 TASK-005 规则，允许 COMPLETED 房"路过式重入"（进入后直接重建出口、无内容、不重置状态），树形地图原样保留。
- 优点：符合横版动作类体验，玩家可自由清分支。
- 缺点：**推翻用户已验收的 TASK-005 决策**（COMPLETED 终态禁止重入）；状态机需引入"路过"语义（COMPLETED 不再终态）；测试面扩大；稳定性风险高。
- 结论：**不推荐**。方案一（DAG）在不动 TASK-005 的前提下根治问题，符合"稳定性 > 新功能"。

### 4.2 存档兼容性

已核实：存档系统**不存房间拓扑**（`_auto_save` 只存 `current_floor` 楼层号与玩家状态，[game_scene.gd:989-1003](client/scenes/game/game_scene.gd#L989-L1003)）。拓扑算法改动**不影响存档兼容**。

---

## 5. 实施阶段预览（待确认后展开，本次不动手）

| 项 | 内容 |
|---|---|
| 修改文件 | `floor_generator.gd`（分层 DAG 生成 + `_validate_floor` 校验）、`game_scene.gd`（`_create_room_exits` 逃生舱兜底，小改）、`floor_data.gd`（如需要前向边查询接口） |
| 不动 | TASK-005 状态机、CombatManager、渲染层、内容系统、存档格式、AI 系统、战斗数值 |
| 新增测试 | `test_floor_generation.gd`：生成 200 层统计校验（每层：全部房入度≥1、非 Boss 出度≥1、无环、Boss 可达、无孤立点、房数在范围）+ 卡死回归测试（模拟任意遍历路径都能走到 Boss / 走到叶子也能继续走） |
| 回归 | 全部 5 套现有测试（35/12/11/16/19） |
| 已知风险 | ① 分支内容变少（单出口自动选路，玩家看不到未选分支）——可接受，属设计取舍；② display_index 需按遍历/层级重排，HUD 编号语义微调；③ 商店房当前"进房秒完成"（商店 UI 未实现）与本次无关，维持现状 |

---

## 6. 本阶段审计结论

- 本阶段**未修改任何 .gd 文件**，仅新增本报告。
- Room 10 卡死 = 树形地图死胡同 × 前向禁回溯导航的结构性矛盾，TASK-005 代码无过错（旧"任意房兜底"被正确移除）。
- 正式方案：**分层前向 DAG 地图 + spine 保证 Boss 可达 + 生成后校验 + 导航逃生舱**，TASK-005 零改动。
- **等待确认后实施**：实施顺序建议为 生成器改造 → 校验 → 出口策略兜底 → 新测试 + 全量回归 → TASK-006_REPORT → 提交（`TASK-006: ...`）→ 停止等人工验收。

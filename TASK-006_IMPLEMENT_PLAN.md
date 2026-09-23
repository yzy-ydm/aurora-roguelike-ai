# TASK-006_IMPLEMENT_PLAN — 楼层地图探索闭环修复实施计划

> 阶段：TASK-006 第一阶段产物（**仅计划，未修改任何代码**）
> 前置分析：TASK-006_ANALYSIS_REPORT.md（结构矛盾：树形地图 × 前向禁回溯导航）
> 日期：2026-09-23
> 状态：**等待确认后实施**

---

## 1. 现状分析（floor_generator.gd）

### 1.1 当前生成逻辑（[floor_generator.gd:20-82](client/scripts/world/floor_generator.gd#L20-L82)）

```
room_count = randi_range(8, 12)                    → 实际总房数 = room_count + 1 = 9~13
① START(0) 固定 (0,0)
② 主路径 4~6 房向右延伸，x += 1240，y 抖动 ±50
③ 分支 b = room_count - 主线长 - 1 个房，随机挂到任意已有房（含分支→可成链）
④ BOSS 挂最后主线房右侧
结果：无向树；每层 3~6 个分支 = 死胡同叶子；BOSS 永远叶子且排在分支之后
```

### 1.2 数据结构确认（改造涉及的全部结构，均**不改动**）

| 结构 | 使用字段 | 改造影响 |
|---|---|---|
| NewRoomData | `id / room_type / position / connections / content` | **零改动**。层号由 `position.x / ROOM_SPACING_X` 推算，不新增字段 |
| FloorData | `rooms / current_room_id` | 零改动 |
| FloorManager | `generate_floor()` → 赋值 `rooms` → `assign_display_indices()` | 零改动（生成器返回格式不变） |
| connections 语义 | 双向对称记录（`add_connection` 双方各加、自带去重） | 保持。前向边 = 层号 +1 的边；反向条目只是同一前向边的对账记录 |

### 1.3 消费者清单（改造兼容性）

| 消费者 | 路径 | 影响 |
|---|---|---|
| FloorManager.generate_floor | [floor_manager.gd:130](client/scripts/world/floor_manager.gd#L130) | 主路径。签名/返回类型不变 → 透明 |
| AIContentService._generate_fallback_floor | [ai_content_service.gd:617](client/scripts/ai/ai_content_service.gd#L617) | AI 降级路径（Phase 25 后休眠）。签名不变 → 透明；**不改 AI 系统** |
| RoomGraph | room_graph.gd:71 | 死代码，不清理（禁止事项），对新算法透明 |

### 1.4 修改点结论

| 位置 | 动作 |
|---|---|
| `floor_generator.gd` | ① `generate_floor()` 树形 → 分层 DAG 重写（签名/返回不变）② 新增 `validate_floor(rooms) -> bool` + `[FloorValidation]` 日志 ③ `_min_rooms/_max_rooms` 语义改为总房数 8~13 ④ `_branch_chance` 改义为"第二前向边概率" |
| `game_scene.gd` | `_create_room_exits()` 增加 `[PortalSelection]` 防御日志 + 紧急出口（结构不变：单出口、排除已完成房） |
| 其余 | **一律不动**（状态机/战斗/奖励/AI/玩家/存档格式；不清理旧代码） |

---

## 2. 分层 DAG 生成算法设计

```
generate_floor(floor_level):
  ① 参数
     total_rooms = randi_range(_min_rooms, _max_rooms)   # 8~13（总房数，含 START+BOSS）
     mid_layers  = randi_range(4, 6)                     # 中间层数 4~6
  ② 层容量分配（每层 ≥1，中间层 ≤3）
     layer_sizes = [1] + [1]*mid_layers + [1]            # START | 中间层 | BOSS
     remaining = total_rooms - 2 - mid_layers
     while remaining > 0:
         随机挑一个 <3 的中间层 +1
  ③ 建房间（id 按层顺序 0..total-1；BOSS = total-1）
     type: START / _get_random_room_type(floor_level) / BOSS
     position.x = 层号 * ROOM_SPACING_X                  # 精确整数值，供校验推层号
     position.y = randf_range(-50, 50)
  ④ 连接（只加前向边；add_connection 双向对账 + 自动去重）
     4a spine：layer[l][0] ↔ layer[l+1][0]（l=0..mid_layers，最后连 BOSS）
              → start→boss 路径由构造保证
     4b 入边保证：layer[l+1] 每个房 ≥1 条来自 layer[l] 的边（[0] 已被 spine 覆盖）
     4c 出边保证：layer[l] 每个房 ≥1 条去往 layer[l+1] 的边（缺者随机补）
     4d 可选第二前向边：概率 _branch_chance(0.4)，连 layer[l+1] 另一未连房（该层 >1 房时）
  ⑤ 校验
     if not validate_floor(rooms): 重试（最多 5 次）→ 仍失败打印 ERROR 并返回最后一次结果
```

**规则落地对照**：

| 用户要求 | 落地 |
|---|---|
| 所有普通房 ≥1 个下一层连接 | 4c 出边保证 |
| Boss 无下一层 | Boss 层为最后一层，永不加前向边 |
| 禁止回边 | 生成只加"层号+1"方向边（反向条目为对账记录） |
| 禁止自环 | 跨层连接天然无自环；校验显式断言 |
| 禁止重复连接 | `add_connection` 自带去重；校验显式断言 |
| start→boss 永远可达 | 4a spine + 4b 入边 + 校验断言 |

## 3. _validate_floor 设计

`func validate_floor(rooms: Array[NewRoomData]) -> bool`（public，供测试直接调用）

层号推算：`layer = int(round(position.x / ROOM_SPACING_X))`（x 恒为精确整数值，无浮点误差）。

| # | 检查项 | 判定 |
|---|---|---|
| V1 | 房间数 ∈ [8,13] | 数量断言 |
| V2 | START 恰 1 个且 id=0；BOSS 恰 1 个且 id=最后 | Boss 存在 |
| V3 | 从 START 沿前向边 BFS 可达全部房间 | 所有房间可达 |
| V4 | BFS 可达集包含 BOSS | START→Boss 路径存在 |
| V5 | 每个非 Boss 房前向出度 ≥1 | 无死胡同 |
| V6 | Boss 前向出度 = 0 | Boss 为终点 |
| V7 | 每条连接 (u,v)：u≠v（无自环）；\|layer(u)−layer(v)\| == 1（无环/无回边/无跨层）；双向对账（对称）；connections 无重复 id | 无环/无自环/无重复 |

日志格式（每个检查项一条，全过再打汇总）：

```
[FloorValidation] CHECK reachable_from_start: PASS (12/12 rooms)
[FloorValidation] CHECK boss_out_degree: FAIL (boss room 11 has forward edge to 12)
[FloorValidation] ALL CHECKS PASSED (12 rooms, 6 layers)
[FloorValidation] FAILED (reason), retry 2/5
```

## 4. 出口逻辑调整设计（game_scene._create_room_exits）

**保持**：单出口；已完成房一律排除；楼层完成 → 下一层门（TASK-005 语义全部不动）。

**新增**：

1. `[PortalSelection]` 防御日志：
   ```
   [PortalSelection] room X candidates=[...]
   [PortalSelection] priority1 unvisited -> room Y
   [PortalSelection] priority2 unfinished -> room Y
   ```
2. **紧急出口（理论不可达的防御兜底）**——DAG 结构保证"无有效目标"不会发生，但绝不再软锁：
   ```
   无目标 且 楼层未完成 时：
     [PortalSelection] WARNING: no valid forward target (should not happen)
     全层扫描：优先"未完成的 BOSS 房"；其次未访问非当前房；再其次未完成非当前房
     命中 → 直接建门 + [PortalSelection] EMERGENCY: portal to room Y (reason)
     未命中（绝对兜底）→ [PortalSelection] ERROR: no emergency target + HUD 提示
   ```

## 5. 测试计划（test_floor_generation.gd）

沿用现有测试脚手架模式（SceneTree + `_check` + 元护栏）。

- 循环 **200 次** `generate_floor(1)`（真实 floor_generator.gd）
- 每次 10 项检查（F1~F10），失败收集、每层打印一行 PASS/FAIL 摘要
- 元护栏 `EXPECTED_CHECKS = 200 × 10 + 1 = 2001`

| # | 检查项 |
|---|---|
| F1 | 房间数 ∈ [8,13] |
| F2 | START 恰 1 个、id=0 |
| F3 | BOSS 恰 1 个、id=最后 |
| F4 | START 前向 BFS 可达全部房间（无孤立房） |
| F5 | BOSS 可达 |
| F6 | 非 Boss 房前向出度 ≥1（无死胡同） |
| F7 | Boss 前向出度 = 0 |
| F8 | 无自环/无重复/双向对账/相邻层连接（无环无回边） |
| F9 | `validate_floor()` 返回 true |
| F10 | **遍历模拟回归软锁现场**：镜像 `_create_room_exits` 选择策略（优先未访问→次未完成→排除当前房），从 START 逐步走到 BOSS，断言每步必有目标、步数 ≤ 总房数、终点是 BOSS |

**回归（必须全绿）**：TASK-001 `test_reward_system`（12）、TASK-002 `test_reward_spawn_position`（11）、TASK-003 `test_event_room`（16）、TASK-004 `test_room_type_dispatch`（19）、TASK-005 `test_room_lifecycle`（35）+ 无头启动检查。

## 6. 风险与边界

| # | 风险 | 评估 |
|---|---|---|
| R1 | 同层房间 x 相同、y 仅抖动 ±50 → 虚拟坐标重叠 | 无害：同一时刻只渲染当前房（render_room 独占渲染），坐标仅是内容锚点 |
| R2 | 单出口自动选路 → 未选中的同层分支内容不可见 | 已确认的设计取舍（用户定单出口），不属缺陷 |
| R3 | AI 降级路径 `_generate_fallback_floor` 复用 generate_floor | 签名不变 → 透明兼容；AI 系统零改动 |
| R4 | `_min_rooms/_max_rooms` 语义变化（旧：偏置计数 → 新：总房数） | 仅 floor_generator 内部使用，无外部引用 |
| R5 | 存档兼容 | 已核实存档不存拓扑（只存楼层号+玩家状态）→ 无影响 |
| R6 | 校验依赖 position.x 推层号 | x 恒为 `层号 × 1240` 精确赋值，无浮点误差；校验器与生成器同文件，契约封闭 |

## 7. 实施步骤（等确认后执行，严格按序）

1. 重写 `floor_generator.gd`：分层 DAG 生成 + `validate_floor` + `[FloorValidation]` 日志
2. 修改 `game_scene.gd` `_create_room_exits`：`[PortalSelection]` 日志 + 紧急出口
3. 新增 `client/tests/test_floor_generation.gd`（200 次 × 10 项）
4. 运行：新测试 → 5 套回归 → 无头启动检查
5. 输出 `TASK-006_REPORT.md`（修改文件/架构变化/测试结果/已知风险/人工验收步骤）
6. `git add .` → 提交 `TASK-006: Fix floor map exploration loop (layered DAG generation)` → 推送
7. **停止，等人工验收**

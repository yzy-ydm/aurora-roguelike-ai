# TASK-005 实施计划 — 房间生命周期状态机重构

> 阶段一产物：代码分析 + 实施计划。**本文件不包含代码修改，等待确认后实施。**

## 1. 当前问题（已核实，含精确代码位置）

### 1.1 房间状态流转现状

```
enter_room(room_id) [floor_manager.gd:172]
  ├─ 拒绝: room.enter_count >= 2  [floor_manager.gd:183]
  ├─ 旧房 _exit_room → 清渲染/怪物/奖励
  ├─ set_current_room → mark_visited()  [floor_data.gd:66]
  ├─ enter_count += 1  [floor_manager.gd:196]
  ├─ _ensure_room_content → validate
  ├─ render_room → room_entered 信号
  └─ game_scene._on_fm_room_entered [game_scene.gd:548]
       ├─ BOSS → _start_boss_fight；死亡后双完成路径（见 P4）
       ├─ COMBAT/ELITE 有怪 → 出怪+开战 → 落入 match `_` 分支
       │        → _create_room_exits()  ← 进房即建门①  [game_scene.gd:610]
       │   清怪 → _on_combat_cleared → 生成奖励
       │        → _complete_current_room("all_monsters_dead")  ← 建门②  [game_scene.gd:743]
       │   奖励拾取完 → room_completed → _on_combat_room_completed
       │        → _complete_current_room("reward_phase_completed")  ← 被 completed 锁挡下
       ├─ REWARD → 生成奖励；全拾取后两条完成路径竞争（reward_collected / reward_phase_completed）
       ├─ EVENT → 面板 → 选择 → 1.5s → _complete_current_room("event_completed")
       ├─ TREASURE → 奖励 → 全拾取 → _complete_current_room("treasure_opened")
       └─ START/SHOP/空房 → _create_room_exits() 直接建门（不标完成！）

_create_room_exits() 目标选择 [game_scene.gd:1028-1055]:
  ① 未访问 → ② 已访问未完成 → ③ 任意非当前（含已完成！）
portal body_entered → _on_exit_portal_entered → enter_room(target)  [game_scene.gd:1007]
```

### 1.2 七个问题

| # | 问题 | 根因 | 证据 |
|---|---|---|---|
| P1 | 状态职责混乱：visited/completed/enter_count 三字段语义重叠，"进入次数"推断"已完成" | enter_count>=2 是启发式而非状态机 | [new_room_data.gd:37-42](client/scripts/models/new_room_data.gd#L37-L42) |
| P2 | 传送门重复创建（实机日志两次 "Created exit portal"） | 战斗房进房建门① + 清怪建门②；渲染器无去重 | [game_scene.gd:610](client/scenes/game/game_scene.gd#L610) + [game_scene.gd:743](client/scenes/game/game_scene.gd#L743)；[room_renderer.gd:496](client/scripts/world/room_renderer.gd#L496) |
| P3 | 奖励房完成后出口不稳定（实机 "Target Room:6" → "already entered/completed, skipping"） | 目标选择③级兜底允许选已完成房间 → enter_room 拒绝 → 玩家卡住 | [game_scene.gd:1046-1051](client/scenes/game/game_scene.gd#L1046-L1051) |
| P4 | Boss 双重完成逻辑 | combat_manager 与 game_scene 各写一次 `_floor_manager._current_floor.complete_current_room()` | [combat_manager.gd:217-218](client/scripts/combat/combat_manager.gd#L217-L218)、[game_scene.gd:1419-1420](client/scenes/game/game_scene.gd#L1419-L1420) |
| P5 | 战斗房清怪即出传送门（先于奖励拾取），与目标流程"奖励完成→出口"不符 | [game_scene.gd:740-743](client/scenes/game/game_scene.gd#L740-L743) |
| P6 | 重复触发防护靠 completed 布尔锁 + 信号断开/重连 hack | [game_scene.gd:990](client/scenes/game/game_scene.gd#L990)、[game_scene.gd:793-797](client/scenes/game/game_scene.gd#L793-L797) |
| P7 | 多脚本穿透 `_floor_manager._current_floor` 直写内部状态 | [combat_manager.gd:218](client/scripts/combat/combat_manager.gd#L218)、[game_scene.gd:995](client/scenes/game/game_scene.gd#L995)、[game_scene.gd:1420](client/scenes/game/game_scene.gd#L1420) |

### 1.3 关键点全量清单

**completed 写点（活跃代码 3 处 + 定义 2 处）：**
- 定义：`new_room_data.gd:110` mark_completed()；`floor_data.gd:104` complete_current_room()
- 调用：`game_scene.gd:995`（统一完成路径）、`game_scene.gd:1420`（Boss）、`combat_manager.gd:218`（Boss，冗余直写）

**portal 创建点（建门函数 2 个 + 调用 7 处）：**
- 底层：`room_renderer.create_exit_portal`（:496，唯一建门点，game_scene:1061 调用）、`room_renderer.create_next_floor_portal`（:579）
- `_create_room_exits()` 调用点：`game_scene.gd:577`（无内容房）、`:610`（`_` 分发=战斗房进房建门源）、`:623/:630`（Boss 失败兜底）、`:816`（事件无事件兜底）、`:1002`（完成路径）、`:1430`（Boss 完成）
- 下一层门：`game_scene.gd:688`（_on_floor_completed）

**enter_room 调用点：**
- `floor_manager.gd:150`（generate_floor 进起始房）、`game_scene.gd:1007`（传送门触发）
- enter_room 内部：拒绝（:183）→ 退出旧房（:188-190）→ set_current_room/visited（:193）→ enter_count+=1（:196）→ 内容（:199）→ 渲染（:202）→ 信号（:205）

**visited 写点：** `floor_data.gd:66`（唯一活跃写点）；mark_completed 内部同步写 visited=true

**死代码（不处理）：** room_manager.gd / room_graph.gd / room_node_data.gd —— 全项目无实例化点，仅 monster_spawner 有注释级引用

## 2. 状态机设计

### 2.1 状态定义（新增到 NewRoomData）

```gdscript
enum RoomState { ENTERING, COMBAT, REWARD, EVENT, COMPLETED, EXITING }
```

### 2.2 合法转换表（唯一入口 transition_to，非法转换拒绝并打日志）

```
ENTERING → COMBAT（战斗房出怪开战）| REWARD（奖励/宝箱房）| EVENT（事件房）
         | COMPLETED（起始/商店/空房：进房即完成）
COMBAT  → REWARD → COMPLETED（奖励拾取完 → 建唯一出口）
EVENT   → COMPLETED（事件完成 → 建唯一出口）
任意态  → EXITING（玩家离开；完成房保持 COMPLETED 不再转换）
EXITING → ENTERING（回溯进入未完成房，重新走流程）
COMPLETED = 终态：不可重复转换、不可再进入
```

- **传送门唯一性由状态机保证**：`transition_to(COMPLETED)` 只成功一次 → 建门代码只在转换成功时执行 → 删除 already_completed 布尔锁
- **重复进入防护**：enter_room 拒绝 `is_completed()`（替换 enter_count>=2）；**enter_count 字段彻底删除**
- **completed 字段降级为兼容快照**（transition_to(COMPLETED) 时同步写，供存档序列化）；业务判断一律读 state
- **visited 保留**（传送门目标优先级需要），只允许 floor_data.set_current_room 写

### 2.3 职责分配

| 脚本 | 允许 | 禁止 |
|---|---|---|
| NewRoomData | 唯一 transition_to() 校验器 + is_completed()/can_enter() | — |
| FloorData | 唯一状态写入口：complete_current_room() / set_current_room_state()（内部调 transition_to） | — |
| FloorManager | 进/出房调 FloorData 接口（EXITING/ENTERING + 拒绝 COMPLETED） | 直写 completed/visited/enter_count |
| GameScene | 流程编排：调 FloorData 接口推进状态；转换成功才建传送门 | 直写 completed/visited |
| CombatManager | 只管理战斗（怪物统计/清怪/Boss战） | 访问 `_floor_manager._current_floor`；修改任何房间状态 |

## 3. 修改文件与修改内容

| 文件 | 修改内容 |
|---|---|
| `client/scripts/models/new_room_data.gd` | 新增 RoomState 枚举、`state` 字段、`transition_to()`（合法转换表校验）、`is_completed()`/`can_enter()`/`get_state_string()`；mark_completed 保留为内部兼容快照（completed 同步写）；**删除 enter_count**；to_dict 增加 state |
| `client/scripts/models/floor_data.gd` | complete_current_room() 改为 `transition_to(COMPLETED)`（删除 enter_count=2）；新增 set_current_room_state()；is_floor_complete/get_completed_count 改读 state |
| `client/scripts/world/floor_manager.gd` | enter_room：拒绝条件改 `room.is_completed()`；删除 enter_count 读写；退出旧房时未完成房 transition_to(EXITING) |
| `client/scenes/game/game_scene.gd` | ① _on_fm_room_entered 开头加 `if room.is_completed(): return`（重复进入防护，与 floor_manager 双层）② match 增加 COMBAT/ELITE 显式分支（出怪开战后 return，**不再落 `_` 建门**）③ REWARD/EVENT 分支内先 transition 对应状态 ④ `_` 分支（START/SHOP/空房）改 `_complete_current_room("empty_room")` ⑤ _on_combat_cleared：删除 :743 完成调用，奖励生成后转 REWARD（**不出门**）⑥ _complete_current_room 重写：is_completed 前置检查 → floor 统一接口 → 成功才建门 ⑦ _create_room_exits：目标选择**过滤已完成房间**，无有效目标时改判楼层完成→下一层门，否则不建门 ⑧ Boss 处理（1390-1434）：完成改走统一接口，建门仅 :1430 一处 |
| `client/scripts/combat/combat_manager.gd` | **删除 :217-218** 直写 `_floor_manager._current_floor.complete_current_room()`（Boss 完成统一由 game_scene 处理） |
| `client/scripts/world/room_renderer.gd` | create_exit_portal 增加同房间去重防护（记录已建门房间 id，同房重复调用直接忽略） |
| `client/tests/test_room_lifecycle.gd` | **新增**（见 §5） |

## 4. 风险与对策

| # | 风险 | 对策 |
|---|---|---|
| R1 | 战斗房出口从"清怪即出"改为"奖励拾取完才出"，若奖励无法拾取会无出口（软锁） | TASK-001 保证至少 1 奖励、TASK-002 保证可拾取；新测试覆盖全流程；人工验收重点观察 |
| R2 | START/商店/空房改为走 _complete_current_room → 房间变 COMPLETED | is_floor_complete 只看 Boss 房，不受影响；get_completed_count 统计含义变化无害 |
| R3 | 误伤死代码（room_manager/room_graph/room_node_data） | 明确不处理，仅记录 |
| R4 | call_deferred 建门时序 + body_entered 双触发 | 状态机一次转换 + 渲染器同房去重，双保险 |
| R5 | 旧测试破坏 | TASK-003/004 桩 floor.complete_current_room 计数调用链保留（统一接口仍在 FloorData 上）；TASK-004 B2 未断言战斗房进房建门，不受影响；全量回归验证 |
| R6 | 存档兼容 | to_dict 增加 state 字段，completed 兼容快照保留，旧存档读取路径不变 |

## 5. 测试方案

### 5.1 新增 test_room_lifecycle.gd（真实 game_scene + 桩，沿用 TASK-003/004 脚手架）

1. **战斗房完整流程**：进入→生成怪物+开战→清怪（_on_combat_cleared）→生成奖励、**无出口**→奖励拾取完（_on_all_rewards_collected→room_completed）→COMPLETED→**恰好 1 个出口**
2. **奖励房流程**：进入→生成奖励→拾取完成→COMPLETED→1 个出口
3. **事件房流程**：进入→面板→事件完成（1.5s 后）→COMPLETED→1 个出口，全程无怪无战斗
4. **重复完成保护**：同一房间两次调用完成逻辑→portal 数恒为 1；重复 _on_fm_room_entered 已完成房→不生成怪物/奖励/出口
5. **非法状态转换**：transition_to 合法性表单测（COMBAT→EVENT 拒绝、COMPLETED 重复转换拒绝、EXITING→ENTERING 允许、COMBAT→REWARD→COMPLETED 合法链）
6. **传送门目标过滤**：completed 房间不被选为目标；无有效目标时不建门

### 5.2 回归与静态检查

- 全量回归：test_reward_system（12）、test_reward_spawn_position（11）、test_event_room（16）、test_room_type_dispatch（19）
- 无头启动检查零脚本错误
- 静态检查：`enter_count` 全项目清零；`completed =`/`mark_completed` 仅存兼容点（new_room_data 内部 + 死代码）；`_floor_manager._current_floor` 仅存统一接口处

### 5.3 人工验收（约 10 分钟）

战斗房（清怪→领完奖励→出口出现→进入下一房）、奖励房（领完→出口可进）、事件房（完成→出口）、回溯未完成房（可重打）、已完成后不再生成内容。通过标准：每个房间**出口恰好一个且可进入**，无 "already entered/completed, skipping"。

## 6. 实施顺序（阶段二→六）

1. new_room_data + floor_data（状态机内核）→ 2. floor_manager（进/出房转换）→ 3. game_scene（分发+完成路径+传送门）→ 4. combat_manager（删直写）→ 5. room_renderer（去重）→ 6. 新测试+全量回归 → 7. TASK-005_REPORT.md → 8. git 提交推送（TASK-005: Refactor room lifecycle state machine）

## 7. 不变更项

AI 系统、数据库、玩家系统、战斗数值、美术资源、房间生成算法、存档格式（只增 state 字段）。

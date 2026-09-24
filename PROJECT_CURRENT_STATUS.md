# PROJECT_CURRENT_STATUS — 工程级状态审计报告

- 审计日期：2026-09-24
- 审计方式：纯静态分析（未修改任何代码）+ Godot 4.7 无头启动验证（`--headless --quit`，启动到登录界面，无脚本错误）
- 当前 git 状态：main 分支，TASK-001 ~ TASK-006 已提交（62df83c → 84eecb3）；工作区仅有一个未跟踪文件 `TASK-007_ANALYSIS_REPORT.md`（奖励选择分析，按指示**不进入开发**）

---

## 一、当前已完成系统

| 系统 | 状态 | 关键文件 | 说明 |
|---|---|---|---|
| Godot 4 客户端框架 | ✅ 完成 | [game_scene.tscn](client/scenes/game/game_scene.tscn)、[project.godot](client/project.godot) | 登录→主菜单→游戏场景链路可用，11 个 Autoload 正常注册 |
| FastAPI 游戏服务端 | ✅ 完成 | [server/main.py](server/main.py)、[server/app/api/](server/app/api/) | 认证/玩家/存档/怪物/武器/地图/事件路由齐全，JWT 认证 |
| AI 服务端 | ✅ 完成 | [server/ai/main.py](server/ai/main.py)、[server/ai/services/](server/ai/services/) | Agnes/MiMo 双 Provider + 质量校验，143 项 pytest 通过 |
| AI 内容生成（客户端） | ✅ 完成 | [client/scripts/ai/](client/scripts/ai/) | 内容服务/校验器/缓存/上下文管理；楼层结构已冻结，AI 只增强房间内容与难度 |
| 房间系统 | ✅ 完成 | [floor_generator.gd](client/scripts/world/floor_generator.gd)、[floor_manager.gd](client/scripts/world/floor_manager.gd)、[room_renderer.gd](client/scripts/world/room_renderer.gd) | TASK-006 分层 DAG 楼层（8~13 房，START→中间层→BOSS），V1~V7 校验；房间生命周期状态机（TASK-005） |
| 战斗基础系统 | ⚠️ 部分完成 | [combat_manager.gd](client/scripts/combat/combat_manager.gd)、[damage_system.gd](client/scripts/combat/damage_system.gd)、[bullet.gd](client/scripts/combat/bullet.gd) | 玩家→怪物伤害链（武器→子弹→DamageSystem）已验证可用；**怪物→玩家方向断裂**（见 B-02） |
| Reward 系统 | ✅ 完成 | [room_spawner.gd](client/scripts/world/room_spawner.gd)、[reward_item.gd](client/scripts/drop/reward_item.gd) | TASK-001 出生点/收集闭环修复；TASK-002 平台感知奖励采样（地面带→可达平台→系统扫描三级兜底） |
| Upgrade 系统 | ✅ 完成 | [upgrade_manager.gd](client/scripts/progression/upgrade_manager.gd)、[level_up_panel.gd](client/scripts/ui/level_up_panel.gd) | 经验/升级/强化选择链已接通（TASK-001 验证） |
| Save 系统框架 | ⚠️ 仅框架 | [save_service.gd](client/scripts/services/save_service.gd)、[save_system.gd](client/scripts/managers/save_system.gd)、[server/app/api/save/router.py](server/app/api/save/router.py) | 服务端接口完整（POST/GET/PUT + 404/409 处理）；**客户端保存确认与加载链路断裂**（见 S-01/S-02/S-03） |
| 测试体系 | ✅ 完成 | [client/tests/](client/tests/) | 6 套测试：奖励 12、奖励坐标 11、事件房 16、类型分发 19、房间生命周期 35、楼层生成 2001，全部通过（TASK-006 回归） |

---

## 二、当前未完成系统

| 系统 | 状态 | 缺口 |
|---|---|---|
| 怪物 AI | ❌ 断裂 | 追击/攻击状态机存在但**坐标空间混用**导致永不触发（B-02）；速度数值失衡（B-02b） |
| 战斗闭环（怪物→玩家） | ❌ 断裂 | 怪物无法攻击玩家，玩家无威胁，战斗不成立（B-02/B-02c） |
| 平台碰撞 | ❌ 断裂 | 平台无单向碰撞 + 生成位置嵌入地面（C-01/C-02） |
| 怪物生成合法性 | ❌ 缺失 | 怪物出生点未做平台避让，可生成在平台内部（M-01） |
| 存档（保存/加载闭环） | ❌ 断裂 | 保存成功判定分支永远走不到、首次保存 404 重试响应被丢弃、**加载入口完全缺失**（S-01/S-02/S-03/S-04） |
| Boss 战 | ⚠️ 部分 | BossController 框架存在，但 Boss 复用 monster_ai.gd，受同一坐标 Bug 影响；技能驱动待战斗任务核对 |
| 成长奖励系统 | 📋 已规划未开发 | TASK-007 奖励选择（按指示延后，最后处理） |

---

## 三、所有已知 Bug 列表

### A. 平台碰撞问题

#### C-01【P0】平台无单向碰撞，从下方无法跳上、像墙一样阻挡
- **现象**：玩家站在平台下方无法跳上；横向走过低平台时被侧壁挡住。
- **根因**：[room_renderer.gd:265-290](client/scripts/world/room_renderer.gd#L265-L290) `_create_platform()` 创建的碰撞形状是普通实心矩形，未设置 `one_way_collision = true`。玩家跳跃上升时头顶撞到平台底面即被完全阻挡（Godot 标准方案：单向碰撞允许从下往上穿过、从上往下落地）。怪物同理也无法穿过。
- **影响**：战斗房 3 个平台、精英房 4 个平台形同墙壁，横版平台玩法核心手感失效。

#### C-02【P0】平台生成位置嵌入地面/与地面重叠，形成地面上的"墙"
- **现象**：部分平台插进地面里，露出的部分像地面上的矮墙挡住去路。
- **根因**：[room_renderer.gd:336-341](client/scripts/world/room_renderer.gd#L336-L341) 战斗房平台中心 y 取 `GROUND_Y - randf_range(20, 56)` → y ∈ [272, 308]，平台厚 16px。地面顶部 y=296：**py > 288 的平台矩形底边（py+8 > 296）就嵌进地面**。站在地面的玩家（身体 y ∈ [264, 296]）水平移动时撞到突出部分，被当墙挡住。
- **影响**：即使修好 C-01，这些嵌地平台仍是地面障碍；生成结果随机，每局表现不同，难以预期。

#### C-03【P2】宝箱/商店/事件房装饰平台不可达（观察项）
- **现象**：这些房的平台生成在房间顶部（y ≈ -20 ~ 28，相对房间中心），距地面 300px+，跳跃不可能到达。
- **根因**：[room_renderer.gd:415-436](client/scripts/world/room_renderer.gd#L415-L436) 商店/事件/宝箱房平台坐标用绝对小数值（y=15/20/-20），而地面在 y=328，明显是旧俯视角坐标残留。
- **影响**：视觉装饰（无害但误导），TASK-002 奖励采样已自动避开（`REWARD_PLATFORM_TOP_MIN_Y=226`）。

### B. 怪物问题

#### B-02【P0】怪物不会主动移动、不会攻击玩家（战斗闭环断裂核心）
- **现象**：怪物静止不动；玩家贴脸经过也不受伤害。
- **根因（三层叠加）**：
  1. **坐标空间混用**：[monster_ai.gd:87](client/scripts/enemy/monster_ai.gd#L87) `distance_to_player = _monster_node.position.distance_to(_player_node.position)`。怪物 `position` 是**房间内 local 坐标**（挂载在 `Room_<id>` 节点下，房间中心偏移 ±300 内），而玩家 `position` 是**世界坐标**（`GameWorld/Player`，GameWorld 在原点）。第 2 层及以后的房间，房间中心 x = 层号×1240，两者差距 1000px+，永远大于 `IDLE_DISTANCE=300` → AI 永远停在 IDLE 状态。`_do_attack` 要求 `distance <= attack_range(50)` 也永远不成立 → 怪物从不攻击。**正确做法：双方都用 `global_position`。**
  2. **速度数值失衡**：[monster_data.gd:18](client/scripts/models/monster_data.gd#L18) 默认 speed=10；数据库怪物 speed 为 3~15（[insert_test_data.sql](database/sql/insert_test_data.sql)）；而玩家 `MOVE_SPEED=200`。即使坐标修好，怪物也只能以 3~15 px/s 蠕动，观感上仍是"不会移动"。需重平衡到约 60~150 px/s。
  3. **无接触伤害**：伤害只由 AI 攻击触发（冷却 1.5s、射程 50px），没有身体接触伤害兜底。玩家以 200 px/s 穿过怪物，几乎不会被打到。
- **影响**：战斗闭环只剩玩家单方面输出，核心玩法不成立。Boss 复用同一 AI 脚本，受同样影响。

#### M-01【P0】怪物可能生成在平台内部 → 无法击杀 → 房间无法完成
- **现象**：部分情况下怪物卡在平台里，子弹打不到，战斗房永远无法清空。
- **根因**：[world_coordinate.gd:53-78](client/scripts/world/world_coordinate.gd#L53-L78) `monster_spawn_pos()` 的 y 固定为地面高度 282（local），**完全不做平台避让**（TASK-002 只给奖励做了平台感知）。战斗房平台 y ∈ [272, 308]（厚 16 → 矩形 [264, 316]），怪物身体 [268, 296]、x ∈ [-330, 330] 与平台 x ∈ [-400, 400] 高概率重叠 → 怪物出生在平台内部，被物理卡住。
- **堵死链路**：怪物卡在平台里 → [bullet.gd:181-183](client/scripts/combat/bullet.gd#L181-L183) 子弹撞任何 StaticBody2D（含平台）即销毁 → 子弹无法命中平台内的怪物 → 怪物不死 → `all_monsters_dead` 不触发 → 无奖励、无出口 → 房间无法完成（软锁）。

#### B-03【P1】怪物碰撞掩码存在错位（潜在项）
- **现象**：暂无可见影响，代码层面有错位。
- **根因**：[monster_node.gd:45](client/scripts/enemy/monster_node.gd#L45) `collision_mask = 263 = 1+2+4+256`，其中 256 位是无效层（应为 PlayerBullet=8）。当前无害（子弹靠自身 mask 检测怪物），但语义错误，战斗任务中应一并修正。

### C. 存档问题

#### S-01【P0】保存成功判定永远走不到 → UI 卡"保存中..."、退出流程卡死
- **现象**：暂停菜单点保存后按钮永远禁用、状态永远"保存中..."；点"退出登录"后永远停在"保存游戏数据..."。
- **根因**：[save_service.gd:100-108](client/scripts/services/save_service.gd#L100-L108) `_on_api_success` 的分支顺序：**先**判断 `result.has("slot_number")` → 归类为"单存档响应"发 `save_loaded`；**后**才判断 `has("id") and has("save_name")` → 发 `save_saved`。而服务端 `SaveResponse` 必然包含 `slot_number`（[save.py:218](server/app/schemas/save.py#L218)）→ **每次保存成功都被当成"加载响应"**，`save_saved` 信号永远不会发射。后果：
  - 暂停菜单 [pause_menu.gd:77-88](client/scripts/ui/pause_menu.gd#L77-L88) 收不到成功/失败 → 按钮不复原。
  - [game_flow_controller.gd:190-195](client/scripts/managers/game_flow_controller.gd#L190-L195) `_on_save_saved` 不触发 → 退出流程卡死在 SAVING 状态，无法回到主菜单。

#### S-02【P0】首次保存（槽位不存在）走 404→POST 重试，但重试响应被客户端丢弃
- **现象**：第一次保存时服务端其实**已成功写入**，但客户端毫无反应（表现为 S-01 的卡死，且用户误以为"没存上"）。
- **根因**：[save_service.gd:115-116](client/scripts/services/save_service.gd#L115-L116) `_on_api_error` 第一行就把 `_is_loading = false`，随后发起的 POST 重试**没有再置回 true**；重试响应到达 `_on_api_success` 时被 `if not _is_loading: return` 直接丢弃。**修复：重试前重新置 `_is_loading = true`，并让重试响应也走保存成功分支。**

#### S-03【P0】存档加载功能完全缺失
- **现象**：没有"加载存档"入口——主菜单只有"刷新/退出登录"；登录后永远是全新开局。
- **根因（三层）**：
  1. 加载唯一入口是 `GameFlowController.enter_game(save_slot)`，但所有调用方（[login_scene.gd:251,259](client/scenes/login/login_scene.gd#L251-L259)）都**不带参数**（save_slot=-1）→ `set_current_save` 永远不被调用。
  2. `GameStateManager._current_slot` 全程为 -1 → 暂停菜单保存按钮直接显示"无存档槽位"（[pause_menu.gd:58-63](client/scripts/ui/pause_menu.gd#L58-L63)）；自动保存只能硬编码回退到槽位 1。
  3. 游戏内"存档选择界面"（[save_selection.gd](client/scripts/ui/save_selection.gd)）实际行为是**保存**（`_on_save_selected` → `SaveService.save_game`）而非加载，且保存后不设置 `_current_slot`。
- **修复方向**：主菜单增加"继续游戏/加载存档"入口 → `enter_game(slot)`；保存成功后同步 `GameStateManager._current_slot`。

#### S-04【P1】即使加载成功，楼层进度也不会恢复
- **根因**：[game_scene.gd:387](client/scenes/game/game_scene.gd#L387) 进入游戏场景后**硬编码** `_floor_manager.generate_floor(1)`，无视存档里的 `current_floor`。加载存档后永远从第 1 层重新开始，玩家状态（等级/武器）能恢复但进度丢失。
- **影响**：Roguelike 存档的意义（进度续玩）不成立。

#### S-05【P2】双存档系统并存，本地 SaveSystem 是死代码
- **根因**：[save_system.gd](client/scripts/managers/save_system.gd)（本地 user:// JSON 存档）被 game_scene 实例化并连接信号，但**没有任何调用方**调用它的 save_game/load_game；实际全部走 SaveService（服务端 API）。
- **影响**：维护混乱、误导后续开发。存档任务中应统一为一条链路（服务端），删除或明确废弃本地实现。
- 附带隐患：`save_system.gd:31` 用 `DirAccess.dir_exists_absolute("user://save/")` 判断目录（user:// 不是绝对路径，若未来被启用需改为 `DirAccess.open("user://")` + `dir_exists()` 写法）。

#### S-06【P2】保存数据不完整（字段缺口）
- **根因**：[game_state_manager.gd:322-328](client/scripts/managers/game_state_manager.gd#L322-L328) `get_save_data()` 只保存 current_floor/player_state/play_time/kill_count/gold_collected；kill_count 与 gold_collected 无任何系统累加（恒为 0）；房间级进度（哪些房已完成）不保存，重进楼层必然重置。

---

## 四、Bug 影响等级汇总

### P0（阻止 Demo 正常运行的问题）
| ID | 问题 | 后果 |
|---|---|---|
| B-02 | 怪物 AI 坐标混用 + 速度失衡 + 无接触伤害 | 怪物不移动不攻击，战斗闭环不成立 |
| M-01 | 怪物生成在平台内部 → 子弹被平台挡 | 怪物无法击杀 → 战斗房无法完成 → 软锁 |
| C-01 | 平台无单向碰撞 | 平台当墙用，横版跳跃玩法失效 |
| C-02 | 平台生成嵌入地面 | 地面出现随机"墙"，与 C-01 叠加恶化通行体验 |
| S-01 | 保存成功判定分支顺序错误 | 暂停菜单/退出流程卡死 |
| S-02 | 404→POST 重试响应被丢弃 | 首次保存无反馈（服务端实际已写入） |
| S-03 | 存档加载入口缺失 | 存档功能形同虚设 |

### P1（影响体验的问题）
| ID | 问题 |
|---|---|
| S-04 | 加载存档后楼层进度硬编码回 1 层 |
| B-03 | 怪物碰撞掩码 263 含无效 256 位（语义错位，随战斗任务修） |
| M-02 | 怪物 AI 攻击判定窗口过小（射程 50px + 冷却 1.5s），修复坐标后需同步调参 |

### P2（优化/清理问题）
| ID | 问题 |
|---|---|
| S-05 | save_system.gd 本地存档死代码双系统并存 |
| S-06 | kill_count/gold_collected 无累加来源、房间级进度不存档 |
| C-03 | 宝箱/商店/事件房顶部装饰平台不可达（旧坐标残留） |
| P-01 | 玩家出生点 y=298 嵌入地面 18px（物理自动推出，可对齐为 280） |
| P-02 | 房间间距 1240 < 房间宽 1280，相邻房间 40px 重叠（当前只渲染一个房间，暂无实害，保留观察） |

> 附注（安全，独立于玩法）：`server/.env.example` 曾推送真实 API Key 到公开仓库，用户需尽快轮换 Agnes/MiMo 两个 Key；在此之前新改动不得写入密钥。（已知事项，不影响本报告优先级。）

---

## 五、推荐开发顺序

严格按当前优先级执行：**战斗闭环 → 碰撞系统 → 怪物AI → 生成合法性 → 存档 → 成长奖励**。每个任务完成后照常输出 TASK_REPORT 并停止，等待人工验收。

| 顺序 | 任务 | 目标 | 关键文件 |
|---|---|---|---|
| 1 | **战斗闭环（怪物会动、会打人）** | 修 AI 坐标（双方用 global_position）；速度重平衡（60~150）；攻击距离/冷却调参使玩家经过会被打；验证清怪→奖励→出口全链路 | [monster_ai.gd](client/scripts/enemy/monster_ai.gd)、[monster_data.gd](client/scripts/models/monster_data.gd)、[monster_balance_config.gd](client/scripts/models/monster_balance_config.gd) |
| 2 | **碰撞系统（平台）** | 平台加 `one_way_collision`；平台生成 y 钳制到地面以上（py ≤ 288），消灭嵌地平台 | [room_renderer.gd](client/scripts/world/room_renderer.gd) |
| 3 | **怪物AI完善** | 追击/攻击状态细化、接触伤害兜底、受击硬直与追击衔接、Boss 同链路验证；顺手修 B-03 掩码 | [monster_ai.gd](client/scripts/enemy/monster_ai.gd)、[monster_node.gd](client/scripts/enemy/monster_node.gd)、[boss_controller.gd](client/scripts/boss/boss_controller.gd) |
| 4 | **生成合法性** | 怪物出生点平台感知采样（复用 TASK-002 的 `_platform_rects` 思路），保证怪物永远生成在空地/地面带，彻底消除 M-01 软锁 | [world_coordinate.gd](client/scripts/world/world_coordinate.gd)、[room_spawner.gd](client/scripts/world/room_spawner.gd) |
| 5 | **存档完整链路** | 修 S-01 分支顺序、S-02 重试标志；主菜单加加载入口并设置 `_current_slot`；加载时恢复 `current_floor`（S-04）；清理 save_system.gd 死代码（S-05）；补齐 S-06 字段 | [save_service.gd](client/scripts/services/save_service.gd)、[game_flow_controller.gd](client/scripts/managers/game_flow_controller.gd)、[game_scene.gd](client/scenes/game/game_scene.gd)、[main_scene.gd](client/scenes/main/main_scene.gd) |
| 6 | **成长奖励系统** | TASK-007 奖励选择（已有 TASK-007_ANALYSIS_REPORT.md 未提交，届时先提交/合并该分析） | [upgrade_manager.gd](client/scripts/progression/upgrade_manager.gd) 等 |

**顺序说明**：任务 1 完成后怪物已可击杀（现有伤害链），但 M-01 仍可能造成软锁，因此任务 4 必须紧随任务 2/3；任务 2 与 1 无强依赖，可按 1→2→3→4 串行推进。

---

## 六、验证与测试基线（供后续任务回归）

- 客户端 6 套测试全绿：reward 12/12、reward_spawn_position 11/11、event_room 16/16、room_type_dispatch 19/19、room_lifecycle 35/35、floor_generation 2001/2001。
- 服务端 pytest 143 项通过；AI 服务端测试通过。
- 本次审计已执行 `Godot --headless --path client --quit`：正常启动至登录界面，无解析错误。
- 已知测试脚手架坑（供后续任务参考）：含 await 的搭建函数必须 await 调用；`--script` 模式下 autoload 引用需在测试函数内 load；枚举需实例访问（`rooms[0].RoomType`）。

**审计结束。未修改任何代码，等待下一步指令。**

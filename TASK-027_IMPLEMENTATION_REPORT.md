# TASK-027_IMPLEMENTATION_REPORT — 稳定性修复批次（死亡流程/存档生命周期/第一层平衡/AI事件门控）

> 日期：2026-09-24
> 状态：**实施完成，等待人工验收**
> 触发：TASK-026 存档修复后的真实验收日志（死亡后 hp=0 写入存档、"Already loading, skipping"卡死、第一层混沌领主 HP1007、START 房弹 AI 事件）

---

## 1. 修改文件列表

| # | 文件 | 改动 |
|---|---|---|
| 1 | client/scripts/services/save_service.gd | **重写为独立 HTTP 层**（见问题2） |
| 2 | client/scripts/managers/game_state_manager.gd | 新增 `reset_run_state()` |
| 3 | client/scripts/managers/game_flow_controller.gd | enter_game 先重置 run 状态；exit_game 死亡禁存 |
| 4 | client/scenes/game/game_scene.gd | 死亡不自动存档；死亡跳过存档面板；保存入口死档防护；退出清理状态；Boss HP 500-800 |
| 5 | client/scenes/main/main_scene.gd | 继续游戏有效存档校验（hp≤0 拒绝） |
| 6 | client/scripts/ui/pause_menu.gd | 暂停保存按钮死档防护 |
| 7 | client/scripts/world/room_spawner.gd | **怪物选择按房间类型+楼层过滤**（问题4根因） |
| 8 | client/scripts/models/monster_balance_config.gd | Boss HP 800-1200 → **500-800** |
| 9 | client/scripts/world/floor_manager.gd | START 房禁 AI 事件/对白；AI 事件仅 EVENT 房 |
| 10 | client/scripts/player/player_controller.gd | 移除每跳 3 条刷屏调试日志 |
| 11 | client/scripts/combat/bullet.gd | 移除每发子弹 2 条刷屏日志 |
| 12 | client/tests/test_save_death.gd | **新增**：死亡/run 生命周期 8 检查项 |
| 13 | client/tests/test_monster_selection.gd | **新增**：怪物选择过滤 6 检查项 |
| 14 | client/tests/test_ai_event_gating.gd | **新增**：AI 事件门控 8 检查项 |
| 15 | client/tests/test_save_integration.gd | 新增 T8 状态锁释放检查（现 12 项） |

## 2. 每个问题根因与修复方案

### 问题1+3: 死亡后存档异常 / 死亡返回后继续游戏

**根因（三层）**：
1. `game_scene._on_player_dead` 调用 `_auto_save()` → 把 hp=0 的运行时状态写入正式存档槽位（验收日志 `Auto-save slot=1 floor=1 level=1 hp=0/100` 实锤）。
2. 死亡后 GameOver 面板"返回主菜单"走 `_on_exit_to_menu` → 打开存档选择面板 → 玩家可再次把死档存进槽位。
3. `GameStateManager._runtime_stats`（autoload 持有的旧场景 PlayerStats 引用）在死亡/退出后不清理 → 新游戏 `player._ready` sync_from_dict 到死数据 → **出生即死**（此前"继续游戏/新游戏"异常的隐藏根因）。

**修复方案**：
- 死亡回调**移除自动存档**（死亡即结束本次 run）。
- `_on_exit_to_menu`/`_on_save_selected`/`_auto_save`/pause_menu 保存按钮/GameFlow.exit_game 五处**死档防护**（player.is_dead() → 跳过保存）。
- 新增 `GameStateManager.reset_run_state()`：清空运行时统计/扩展数据/时长/楼层/存档，保留登录 profile 基线；在 `enter_game()`（每次进游戏前）与 `_exit_to_menu()`（每次回主菜单）调用。
- 主菜单"继续游戏"：存档 `player_state.current_health <= 0` → 显示**"没有有效存档"**并拒绝进入。

### 问题2: SaveService 状态锁 Bug

**根因（两个）**：
1. **共享信号串扰**：SaveService 监听全局 `ApiClient.request_completed`。资源加载等其它请求的响应在存档操作在途时会先到达 → 被误判为存档响应（假"保存成功"）→ 真实存档响应随后被丢弃。状态锁本身也会因错配提前释放。
2. **无超时**：ApiClient 的 HTTPRequest 未设 timeout，网络故障时请求永不完成 → `_is_loading` 永久卡死 → 后续 `load_saves()` 全部 "Already loading, skipping" → 面板永远"加载存档中"。

**修复方案**：SaveService 重写为**独立 HTTPRequest 层**（不再复用 ApiClient）：
- 每个操作自带状态机，`http.timeout = 10s` 保证信号必然发射 → **任何失败路径都会释放状态锁**。
- 状态日志：`LOAD_START / LOAD_SUCCESS / LOAD_FAILED / LOAD_RESET`（reset_state() 供场景切换兜底调用）。
- 公共 API 与信号签名完全不变（save_game/load_saves/get_save_by_slot/saves_loaded/save_saved/save_error），调用方零改动。
- 404→POST 创建、保存后刷新内存列表（TASK-026）行为保留。

### 问题4: 第一层战斗数值重平衡

**根因（数据流实锤）**：
- 默认战斗房 `RoomContentData.monster_types` 为空 → `room_spawner._get_monster_by_config` 旧逻辑"类型未指定 → 从**全部** DB 怪物随机抽" → 抽到 `混沌领主`（DB seeds：type='boss', min_floor=30）→ `_apply_monster_clamp` 按 boss 型钳制为 **HP 800-1200**（实测 1007）→ 第一层普通战斗房无法击杀。
- DB 的 `min_floor/max_floor` 字段客户端从未读取。
- AI 难度调整（enemy_multiplier）全工程零消费点 → **无异常来源**（不存在 AI 倍率把数值放大，已排除）。
- MonsterBalanceConfig 普通/精英范围本就正确（normal 50-150/5-15，elite 200-400），无需修改。

**修复方案**：
- `_get_monster_by_config` 重写：**房间类型约束**（combat→normal / elite→elite / boss→boss）+ **min_floor/max_floor 楼层过滤**（无匹配时回退仅类型约束，不产生无怪空房）；AI 指定类型在过滤后集合内优先。
- Boss HP 范围 800-1200 → **500-800**（MonsterBalanceConfig + game_scene Boss 生成 `clampi(500+(f-1)*60, 500, 800)`）。
- 玩家侧伤害公式**未改动**（武器双计 F-1 为已知问题，单独任务处理；本次修复后第一层已可达标：普通怪 2-5 击击杀、受击 7-20 次存活）。

### 问题5: START 房 AI 事件

**根因**：`floor_manager._request_ai_room_content` 对**所有房间类型**（含 START）发起 AI 上下文事件 + NPC 对白请求 → 出生房立刻弹"神秘宝箱"。

**修复方案**：新增门控 `_room_allows_ai_content`（START 一律禁止）/ `_room_allows_ai_event`（仅 EVENT 房）：
- START 房：不发任何 AI 请求（事件/对白全禁；START 房本就无奖励/宝箱——游戏分发层已有约束）。
- 其它房间：仅 EVENT 房触发 AI 上下文事件；NPC 对白保留（无 UI 消费，仅日志）。

### 问题6: 代码审计（不删除为前提）

| 项 | 结论 |
|---|---|
| 重复 Save 逻辑 | `managers/save_system.gd`（本地 JSON 存档）与 `services/save_service.gd`（服务端存档）并存；前者被 game_scene 实例化但 save_game/load_game **零调用**（运行时死代码）。按约束**保留**，论文可讲"双存档方案设计"。 |
| 无效状态变量 | `game_scene._boss_controller` 声明后全文件零使用（Boss 控制器由 room_spawner 内部创建）→ 记录，保留。 |
| 已废弃代码 | room_spawner._apply_level_modifier（自标注废弃）、旧世界系统/AI 死函数等 —— 见 DEAD_CODE_AUDIT.md，保留。 |
| debug 代码 | 已移除两处高频刷屏：player_controller 每跳 3 条 `[Jump Start/Peak/Landing]`、bullet 每发 2 条 `[Bullet] Created/Moving`（5发/秒时约 10 行/秒）。保留：`[HTTP DEBUG]`（存档链路排障需要）、`[Combat Debug]`（1次/秒）、`[Save Debug]`/`LOAD_*`（验收证据）。 |

## 3. 自动测试结果（全部真实运行）

| 套件 | 结果 |
|---|---|
| test_save_death（新） | ✅ 8/8 |
| test_monster_selection（新） | ✅ 6/6 |
| test_ai_event_gating（新） | ✅ 8/8 |
| test_save_integration（真实 HTTP，含新 T8 状态锁） | ✅ 12/12 |
| 旧 9 套回归（16/2001/20/13/11/12/35/19/11） | ✅ 全绿 |
| 服务端 pytest app/tests（存档） | ✅ 5 passed |
| 服务端 pytest ai/tests | ✅ 143 passed |
| Godot headless 启动 | ✅ 0 脚本错误 |

> 测试脚手架记录：① `:=` 推断自 Variant 返回值会触发"警告视为错误"解析失败（max()/动态脚本调用返回值），须显式类型标注；② --script 模式调用动态脚本的方法返回 Variant，`:=` 同样失败；③ 无头测试运行时错误会导致 quit() 不执行→进程挂起，须硬超时 kill；④ pytest 同时跑 app/tests+ai/tests 会因同名 tests 包收集失败，必须分开跑（既有约定）。

## 4. 需要人工验收的步骤（服务端已运行，存档数据已清空）

**验收 1 — 死亡不产生死档**：
1. 登录进入新游戏（第 1 层）→ 故意让怪物打死 → GameOver 面板出现。
2. 控制台确认**无** `Auto-save` 日志。
3. 点"返回主菜单" → 应**直接**回主菜单（不再弹存档面板）。
4. 点"继续游戏" → 显示**"没有有效存档，请先开始新游戏（登录后自动进入）"**。
5. 再点一次登录进入新游戏 → 玩家满血 100/100、第 1 层（不再"出生即死"）。

**验收 2 — 存活时保存/继续不受影响**：
1. 打到第 2 层 → ESC → 退出到主菜单 → 存档面板选槽位 1 → "保存成功！" → 回主菜单。
2. "继续游戏" → 第 2 层、属性一致。

**验收 3 — 第一层战斗可通过**：
1. 新游戏第 1 层战斗房：怪物应为普通怪（史莱姆/哥布林等），HP 50-150，2-5 次攻击可击杀；**不再出现"混沌领主/领主"类 boss 怪**。
2. 打到 Boss 房：Boss HP 在 500-800（HUD 血条可看到）。
3. 完整通关第 1 层（含 Boss）在正常操作下可行。

**验收 4 — START 房无 AI 内容**：
1. 新游戏进入出生房：**不再出现**"事件：神秘宝箱..."HUD 提示。
2. 进入事件房：可出现事件提示（本地事件面板）。
3. 连续游玩 5 分钟：控制台无 `[Jump ...]`/`[Bullet]` 刷屏，存档相关日志为 LOAD_START/LOAD_SUCCESS 格式。

**通过标准**：以上四项全部符合预期，无脚本报错，无"Already loading, skipping"持续出现（偶发一次属正常并发跳过后必须能恢复）。

---

**TASK-027 实施完成。按流程停止，等待人工验收后进入下一任务。**

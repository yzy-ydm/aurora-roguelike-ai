# TASK-019_AUDIT_REPORT — 稳定性审计报告（第一阶段：仅分析）

> 日期：2026-09-24
> 状态：**仅审计，未修改任何代码，等待确认后实施**
> 范围：019.0 战斗伤害链 / 019.1 AI服务连接 / 019.2 SaveService异步状态 / 019.3 游戏流程审查

---

## TASK-019.0 战斗伤害链审计

### 当前问题：铁剑配置 damage=5，实际造成 18/19 伤害

### 根因：武器伤害被双重计入

完整伤害链（实测推演，与 18/19 完全吻合）：

```
DB: 铁剑 damage=5（[insert_test_data.sql:41](database/sql/insert_test_data.sql#L41)）
  → WeaponData.damage=5 → WeaponInstance.get_damage() = 5（Lv1）
  → weapon._fire: bullet.setup(damage=5, ...)           ← 子弹携带武器伤害 5
  → bullet 命中 → DamageSystem.on_bullet_hit:
       weapon_damage = bullet.get_damage()              = 5
       attacker_attack = source.get_attack()
         = PlayerStats.attack(10) + weapon.get_damage()(5) = 15   ← 已含武器伤害！
       calculate_damage(15, 5, target_defense, 0)
         base = 15 + 5 = 20                              ← 武器伤害第二次加入！
  → 减伤: def 2~5 → 20×(1-def/(def+100)) = 19.6~19.0 → int **19**
         def 8~10 → 18.5~18.2 → int **18**
  → 暴击(10%硬编码) → ×1.5
```

**完整伤害公式（当前实际）**：
```
玩家对怪物: (攻击力 + 武器伤害×2) × (1 - 怪物防御/(怪物防御+100))，暴击 ×1.5
怪物对玩家: 怪物攻击力 × (1 - 玩家防御/(玩家防御+100))，随后 PlayerStats 再减一次防御（双重减伤，已知 D1）
```

冲突源头：[player_controller.get_attack()](client/scripts/player/player_controller.gd#L524-L532) 返回"攻击力+武器伤害"（语义：总攻击），而 [weapon.gd:147-148](client/scripts/combat/weapon.gd#L147-L148) 注释明确设计意图是"**子弹只传武器伤害，总伤害由 DamageSystem 命中时计算**"——DamageSystem 把两者**相加**，武器伤害算了两次。

隐藏倍率排查结论：
| 疑点 | 结论 |
|---|---|
| attack 属性 | ✅ 正常计入（1 次） |
| difficulty adjustment | **生成后零消费者**——`_difficulty_adjustment` 存于 FloorManager 但无任何代码读取它（怪物 clamp 不读 multiplier），难度调整无实际效果（见 019.3） |
| crit | 10% 硬编码（weapon.gd:137），暴击 ×1.5 只乘一次，无二次暴击 |
| random range | 无（伤害无随机区间） |

### 修改建议（最小，二选一，推荐 A）

- **方案 A（推荐）**：[damage_system.gd:65-67](client/scripts/combat/damage_system.gd#L65-L67) 改为读"裸攻击力"：`source.get_stats().attack`（或 `get_player_data()["attack"]`），保留 `get_attack()` 语义不动。1~2 行。全工程 `get_attack()` 唯一消费者就是此处（grep 确认），影响面窄。
- 方案 B：`get_attack()` 改回只返回 stats.attack。语义变化（未来 UI 若显示"总攻击"会变），不推荐。

### 风险评估

- ⚠️ **修复后玩家 DPS 从 20 降到 15（-25%）**。TASK-018.0 刚调平的开局体验（怪物 HP 50~150 需 4~10 发 vs 3~7 发）会变难。**修复必须联动人工实测**；若变难，后续可小幅下调怪物 HP 区间或上调基础攻击——不在本任务范围，先修公式再实测。
- 回归：现有 8 套测试不直接断言伤害数值（test_monster_ai 只断言"有伤害"），理论零影响；建议新增 1 个伤害公式断言测试。

---

## TASK-019.1 AI 服务连接审计

### 问题清单与根因

| # | 问题 | 根因 | 等级 |
|---|---|---|---|
| A1 | **Token 失效后永不刷新**：AI 服务重启/24h 过期后，客户端持旧 token 每次请求 401 → 永远 fallback，真实 AI 调用无法恢复 | ① 服务端 [auth.py](server/ai/security/auth.py) token 存**内存** `_active_tokens`，重启即全失效（TOKEN_EXPIRE_HOURS=24）；② 客户端 [ai_content_service.gd:432-434](client/scripts/ai/ai_content_service.gd#L432-L434) `_ensure_ai_token()` 若 `_ai_token != ""` **直接返回，永不重新获取**；③ 401 响应走 `status_code != 200 → 返回 {}` → fallback，无重取逻辑 | **P0**（"至少保证一次真实AI调用成功"的拦路石） |
| A2 | AI_BASE_URL 用 `http://localhost:8001`，游戏服务用 `http://127.0.0.1:8000` 不一致 | [api_config.gd:31](client/scripts/api/api_config.gd#L31)；localhost 可能解析为 IPv6 `::1`，而 uvicorn 默认只监听 127.0.0.1 → 连接拒绝 | P2 |
| A3 | HTTP timeout 设置 | ✅ 已有：token 请求 5s、AI 请求 10s（`http.timeout`）+ 手动轮询 100×0.1s 双重保护，超时走 fallback ✓ 无需改 | ✅ 无问题 |
| A4 | 轮询完成检测用 `get_http_client_status() == STATUS_DISCONNECTED`，随后 `request_completed.get_value()` | 正常流程可工作（完成即断连）；但若信号未 emit 而状态先断连，`get_value()` 返回 null → `result[0]` 崩溃（边缘时序） | P2 观察 |
| A5 | fallback 触发链 | ✅ 完整：未初始化/空响应/质量不达标/解析失败/超时 → fake/本地生成，多层兜底 ✓ **不删除** | ✅ 无问题 |
| A6 | 服务启动状态 | 8000/8001 未启动 → 请求失败 → fallback，游戏可玩 ✓ | ✅ 无问题 |

### 修改建议（最小）

1. **A1 修复**（核心，~15 行，都在 ai_content_service.gd）：
   - `_ensure_ai_token()` 增加 `force: bool = false` 参数；
   - `_send_ai_request()` 收到 **401** 时：清空 `_ai_token` → `await _ensure_ai_token(true)` 重取 → 重发一次请求；仍 401 才 fallback。
   - 服务端零改动（内存 token 存储保持，靠客户端自动重取兜底）。
2. **A2**：`AI_BASE_URL` 改为 `http://127.0.0.1:8001`（与游戏服务一致，1 行）。
3. A4 可顺手加固（`await http.request_completed` 代替轮询），但不强制——保持最小改动。

### 验证目标

AI 服务启动（`cd server/ai && ../venv/Scripts/python.exe main.py`）后：登录进游戏 → 日志出现 `Response status: 200` 的真实 AI 调用；重启 AI 服务后再次进游戏 → 客户端自动重取 token 并再次 200（不再永久 fallback）。

---

## TASK-019.2 SaveService 异步状态审计

### 问题：日志 "SaveService _on_api_success called, _is_loading:false, Not loading, ignoring response"

### 根因（三层）

| # | 根因 | 代码 | 后果 |
|---|---|---|---|
| S1 | **404 重试响应被丢弃**：`_on_api_error` 第一行把 `_is_loading=false`，随后发起的 POST 重试**没有再置回 true** → 重试成功响应到达 `_on_api_success` 时被 `if not _is_loading` 拦截（**正是用户看到的日志**） | [save_service.gd:115-133](client/scripts/services/save_service.gd#L115-L133) | 首次保存（槽位不存在）服务端已写入，客户端却"保存中..."卡死 |
| S2 | **保存成功判定分支顺序错误**：先判 `has("slot_number")`（SaveResponse 必含）→ 永远走 `save_loaded` 分支，`save_saved` 永不发射 | [save_service.gd:100-108](client/scripts/services/save_service.gd#L100-L108) | 暂停菜单/退出流程收不到成功 |
| S3 | **单布尔状态机无法区分请求类型（竞态）**：`_is_loading` 一个布尔同时代表"加载列表/加载单槽/保存/创建"，且 SaveService 监听**全局** `ApiClient.request_completed` → 任何并发响应都可能被误读或误忽略。场景：load_saves 期间其他请求的响应先到 → 被误当存档响应；或 saves_loaded 响应到达时 `_is_loading` 已被翻转 → **saves_loaded 丢失 → GameFlow 卡在 LOADING_SAVES → 登录流程卡死** | [save_service.gd:31-108](client/scripts/services/save_service.gd#L31-L108) | 登录/加载存档流程不稳定 |

### 修改建议（最小，~30 行，全在 save_service.gd）

1. 增加操作类型字段 `_pending_op: String`（"load_saves"/"load_slot"/"save"/"create"），`_on_api_success`/`_on_api_error` 按 `_pending_op` 分派，取代"看响应形状猜"逻辑；
2. 404 重试前 `_is_loading = true` 且 `_pending_op = "create"`；
3. 成功分支：`save`/`create` → `save_saved.emit(true,...)`；`load_slot` → `save_loaded.emit`；`load_saves`（Array）→ `saves_loaded.emit`；
4. 非 SaveService 发起的请求：`_pending_op == ""` 时直接忽略（现有 `_is_loading` 过滤保留作双保险）。

### 风险评估

- 低。改动封闭在 save_service.gd，信号签名不变，login/profile/load_saves 三流程的调用方（GameFlowController/login_scene/save_selection/pause_menu）零改动。
- 回归：服务端 pytest 143 不涉及；客户端现有测试不测 SaveService（无 HTTP 环境），靠人工验证三流程。

---

## TASK-019.3 游戏流程代码审查（只审计）

| # | 项 | 结论 | 等级 |
|---|---|---|---|
| F1 | 房间进入流程（enter_room → render → room_entered → 类型分发） | ✅ 健壮（TASK-004/005/006 验证；已完成房拒入、无内容统一完成入口） | ✅ |
| F2 | CombatManager 状态转换 | ✅ 健壮（清怪→REWARD→COMPLETED；Boss 独立结算；死亡通知幂等） | ✅ |
| F3 | Reward 生成 | ✅ 平台感知 + 至少 1 个 + 精确移除（TASK-001/002） | ✅ |
| F4 | Portal 生成 | ✅ 唯一出口 + 目标过滤 + 紧急出口兜底（TASK-005/006） | ✅ |
| F5 | Boss 流程 | ✅ 死亡→结算→楼层完成检查→下一层 portal；出生点已安全化（TASK-017.8） | ✅ |
| F6 | **AI 难度调整零消费者** | FloorManager 存 `_difficulty_adjustment`（enemy_hp_multiplier/enemy_damage_multiplier），**全工程无代码读取**——AI 难度调整对怪物数值零影响（怪物 clamp 只读 MonsterBalanceConfig） | **P1** |
| F7 | 事件房自动选第一个选项 | `_show_event_panel` 无选择 UI，自动应用 choice[0]（简化设计） | P3 |
| F8 | 玩家死亡自动存档走断裂链路 | `_on_player_dead → _auto_save`（S1/S2 卡死）→ 存档任务修复后自然恢复 | P2（随 019.2） |
| F9 | game_scene 直写 `_floor_manager._current_floor` | 状态机改造后保留的直写（进房 COMBAT/REWARD 标记），有状态机校验兜底 | P3 观察 |
| F10 | restart_run 未清理 `_current_save`/`_play_time` | 重开后存档槽位/计时残留（不清也不崩） | P3 观察 |

---

## 修改优先级总表（建议实施顺序）

| 顺序 | 任务 | 等级 | 修改文件 | 预计量 |
|---|---|---|---|---|
| 1 | 019.2 SaveService 操作类型状态机 + 404 重试 + 成功分支 | **P0** | save_service.gd | ~30 行 |
| 2 | 019.1 AI token 401 自动重取 + URL 统一 127.0.0.1 | **P0** | ai_content_service.gd、api_config.gd | ~18 行 |
| 3 | 019.0 武器伤害双计修复（方案 A） | **P1**（联动实测） | damage_system.gd + 新增测试断言 | ~2 行 + 测试 |
| 4 | F6 难度调整消费点（怪物 clamp 读 multiplier） | P1 | room_spawner.gd（消费侧，不动 AI 架构） | ~5 行 |
| 5 | F8/F9/F10/A4 观察项 | P2~P3 | — | 暂不改 |

> 注：第 3 项修复后玩家 DPS -25%，必须人工实测战斗手感，必要时配合怪物 HP 微调（另行确认）。第 4 项属于 AI 特色（毕设亮点"动态难度"），当前完全无效果，建议纳入。

**审计完成，未修改任何代码。等待确认实施范围与顺序。**

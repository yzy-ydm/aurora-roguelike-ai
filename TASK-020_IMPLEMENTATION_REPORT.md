# TASK-020_IMPLEMENTATION_REPORT — 系统稳定性修复实施报告

> 日期：2026-09-24
> 状态：**实施完成，等待人工验收**
> 范围：TASK-020.1 SaveService 状态机 / 020.2 AI Token 自动恢复 / 020.3 API 地址统一
> 前置审计：[TASK-019_AUDIT_REPORT.md](TASK-019_AUDIT_REPORT.md)

---

## 1. 修改文件

| # | 文件 | 改动 |
|---|---|---|
| 1 | [save_service.gd](client/scripts/services/save_service.gd) | 重写响应分派：新增操作类型常量 `OP_LOAD_SAVES/OP_LOAD_SLOT/OP_SAVE/OP_CREATE` 与 `_pending_operation` 字段；所有请求发送前 `_start_operation(op)` 设置类型；`_on_api_success` 按操作类型分派（不再按响应形状猜测）；404 仅在 OP_SAVE 时转 POST 创建且**重试前重新置位**（修复响应被丢弃）；OP_LOAD_SLOT 404 单独报"该槽位没有存档"。信号名与公共 API 全部不变 |
| 2 | [ai_content_service.gd](client/scripts/ai/ai_content_service.gd) | ① `_ensure_ai_token(force)` 支持强制刷新（清旧 token 与失败标记）；② `_send_ai_request` 拆分为包装层 + `_do_ai_request`：401 时自动清 token → 强制重取 → 重试一次，仍失败返回空走 fallback；`_do_ai_request` 非 200 时返回 `{"__http_status": code}` 内部标记 |
| 3 | [api_config.gd](client/scripts/api/api_config.gd) | `AI_BASE_URL`：`http://localhost:8001` → `http://127.0.0.1:8001`（与游戏服务一致） |

**未修改**（遵守限制）：地图生成、战斗数值、AI 架构（仅客户端 token 恢复逻辑，服务端零改动）、数据库结构、无新玩法。

---

## 2. 修改原因

1. **SaveService**：原单布尔 `_is_loading` 状态机存在三个已确认缺陷——①首次保存 PUT 404 转 POST 重试前 `_is_loading` 被清且不置回 → 重试成功响应被 "Not loading, ignoring response" 丢弃（用户日志实锤）；②保存成功判定按"响应形状"猜测（SaveResponse 必含 slot_number → 永远误判为加载响应，`save_saved` 永不发射）；③多请求并发时布尔状态无法区分请求类型。改为按操作类型分派后，三个问题一次性消除，且调用方（GameFlowController/login_scene/save_selection/pause_menu）零改动。
2. **AI Token**：原逻辑 `_ai_token != ""` 后永久使用——AI 服务 token 存内存、重启即失效，客户端持旧 token 每次 401 → 永久 fallback，真实 AI 调用无法恢复。现在 401 自动刷新并重试一次；失败仍走 fallback（**fallback 机制未删除**）。
3. **API 地址**：localhost 可能解析为 IPv6 `::1` 而 uvicorn 默认只监听 127.0.0.1，统一后消除潜在连接拒绝。

---

## 3. 风险

| # | 风险 | 评估 |
|---|---|---|
| R1 | SaveService 重写引入回归 | 低。信号名/公共方法签名不变；8 套客户端测试全量回归通过（虽不直接测 SaveService HTTP 路径，但启动零错误）；三个流程（login/profile/saves）依赖的信号名未动 |
| R2 | AI 401 重试增加一次请求延迟（最多 +10s 超时） | 低。仅在 401（token 失效）时发生一次；AI 调用本身是后台异步，不影响游戏运行 |
| R3 | `_ensure_ai_token(force)` 与其他调用方的并发时序 | 低。AI 请求为顺序 await 流程；force 时 `_token_loading` 等待逻辑原样保留 |
| R4 | 服务端无改动 | ✅ 内存 token 存储保持不变，靠客户端自动重取兜底（符合"不修改AI整体架构"约束） |

---

## 4. 测试结果

| 验证 | 结果 |
|---|---|
| Godot headless 启动（`--headless --quit`） | ✅ 0 脚本错误 |
| test_reward_system | 12/12 ✅ |
| test_reward_spawn_position | 11/11 ✅ |
| test_event_room | 16/16 ✅ |
| test_room_type_dispatch | 19/19 ✅ |
| test_room_lifecycle | 35/35 ✅ |
| test_floor_generation | 2001/2001 ✅ |
| test_monster_spawn_safety | 13/13 ✅ |
| test_monster_ai | 20/20 ✅ |
| 服务端 pytest（tests/ + ai/tests/） | ✅ 143 passed |

> SaveService/AI token 的 HTTP 行为无客户端自动化测试环境（需真实服务），其验证依赖人工验收步骤（下附）。

### 人工验收要点

1. **首次保存**（服务端 8000 + MySQL 启动）：进游戏 → 暂停 → 保存 → 状态显示"保存成功"（不再卡"保存中..."）；重复保存同样成功。
2. **AI token 恢复**（AI 服务 8001 启动）：进游戏日志出现 `Response status: 200`；**重启 AI 服务**后再次进游戏 → 日志出现 "401, refreshing token and retrying once" 后再次 `200`（不再永久 fallback）。
3. 登录 → 主菜单 → 进入游戏全流程无卡顿、无报错。

---

## 5. 剩余问题（已审计、未在本任务实施，留待后续）

| # | 问题 | 等级 | 状态 |
|---|---|---|---|
| 1 | 武器伤害双重计入（铁剑 18/19 伤害根因，公式应为 attack+weapon 一次） | P1 | TASK-019.0 已给方案 A（damage_system 读裸攻击力），待确认后实施（修复后玩家 DPS -25% 需联动实测） |
| 2 | AI 难度调整（enemy_hp/damage_multiplier）生成后零消费者，动态难度无效果 | P1 | TASK-019 F6，待确认 |
| 3 | 暴击率硬编码 0.1（成长加成无效） | P1 | TASK-007 G2 遗留 |
| 4 | 玩家双重减伤（DamageSystem 减伤 + PlayerStats 再减 defense） | P2 | TASK-019 D1 |
| 5 | 存档加载 UI 入口缺失（enter_game 从不带 slot）、楼层进度硬编码 1 | P0/P1 | 存档任务（TASK-019.2 只修了状态机，加载入口属 S-03/S-04） |
| 6 | 事件房自动选第一选项、装饰平台不可达等观察项 | P3 | 暂不改 |

---

**TASK-020 实施完成。按流程停止，等待人工验收后进入 TASK-021。**

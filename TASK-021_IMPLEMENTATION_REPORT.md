# TASK-021_IMPLEMENTATION_REPORT — AI 请求异步等待方式修复报告

> 日期：2026-09-24
> 状态：**实施完成，等待人工验收**
> 触发：TASK-020 后运行报错 `Invalid call. Nonexistent function 'get_value' in base 'Signal'`（ai_content_service.gd:496）

---

## 1. 修改文件

| # | 文件 | 改动 |
|---|---|---|
| 1 | [ai_content_service.gd](client/scripts/ai/ai_content_service.gd) | 两处 HTTP 响应等待逻辑：`_ensure_ai_token()` 与 `_do_ai_request()` 中"轮询 `get_http_client_status()` + `request_completed.get_value()`"改为 Godot 4 标准 **`await http.request_completed`**（信号返回 `[result, response_code, headers, body]` 数组），删除轮询循环与手动超时计数器 |

## 2. 修改原因

- `http.request_completed` 是 **Signal 对象**，Signal 没有 `get_value()` 方法（这是旧版本 API 的残留写法），运行时触发即报 `Invalid call`。
- 旧的等待模式还有隐性缺陷：轮询循环用 `STATUS_DISCONNECTED` 作为"完成"信号——请求刚发出、连接尚未建立时状态也是 DISCONNECTED，会**立即误判完成**并提前进入 get_value。
- 新写法：`await http.request_completed` 是 Godot 4 官方等待方式，配合已设置的 `http.timeout`（token 请求 5s、AI 请求 10s）**保证信号最终必然发射**（超时以 `RESULT_TIMEOUT` 发射），无需手动轮询。

## 3. 保持不变（按指令）

- ✅ AI 架构零改动（仅等待方式修复）
- ✅ token 逻辑设计不变（`_token_loading`/`_token_failed` 标志、`force` 强制刷新、401 自动重取 + 重试一次）
- ✅ fallback 机制不变（网络失败/超时/非 200 仍返回空走 fallback）
- ✅ 未修改数据库、未增加功能

## 4. 测试结果

| 验证 | 结果 |
|---|---|
| Godot headless 启动（`--headless --quit`） | ✅ **0 脚本错误**（SCRIPT ERROR / Parse Error / Invalid call 均为 0） |
| test_reward_system | 12/12 ✅ |
| test_reward_spawn_position | 11/11 ✅ |
| test_event_room | 16/16 ✅ |
| test_room_type_dispatch | 19/19 ✅ |
| test_room_lifecycle | 35/35 ✅ |
| test_floor_generation | 2001/2001 ✅ |
| test_monster_spawn_safety | 13/13 ✅ |
| test_monster_ai | 20/20 ✅ |
| 服务端 pytest（tests/ + ai/tests/） | ✅ 143 passed |

## 5. 剩余问题（延续自 TASK-019/020 报告，未在本任务实施）

| # | 问题 | 等级 |
|---|---|---|
| 1 | 武器伤害双重计入（铁剑 18/19 伤害根因） | P1 |
| 2 | AI 难度调整生成后零消费者 | P1 |
| 3 | 暴击率硬编码 0.1 | P1 |
| 4 | 玩家双重减伤 | P2 |
| 5 | 存档加载 UI 入口缺失、楼层进度硬编码 1 | P0/P1 |
| 6 | 事件房自动选第一选项等观察项 | P3 |

---

**TASK-021 实施完成。按流程停止，等待人工验收后进入下一任务。**

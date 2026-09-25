# TASK-026_IMPLEMENTATION_REPORT — 存档链路真实修复报告

> 日期：2026-09-24
> 状态：**实施完成，等待人工验收**
> 触发：用户人工验收"仍然无法正常保存" → 按"真实运行结果优先"重新审计 TASK-025
> 方法：真实 HTTP 全链路复现（客户端无头集成测试 + curl + MySQL 直查 + 服务重启恢复）

---

## 1. 真实链路复现结果（修复前）

| 环节 | 复现结果 |
|---|---|
| 服务端 PUT/POST/GET/409 | ✅ 本身正常（curl 验证，MySQL 有 2026-09-24 01:25 更新的真实存档记录） |
| **Bug S-A** 保存后内存列表过期 | ❌ 客户端保存成功后 `SaveService._saves` 不更新 → 同一会话点"继续游戏"读不到新档（新档显示"没有存档"、更新档显示旧楼层） |
| **Bug S-B** 首次保存丢失进度 | ❌ 服务端 `create_save` 硬编码 `current_floor=1` + SaveCreate schema 无进度字段 → 404→POST 创建路径丢弃楼层/时长/击杀/金币（集成测试实锤：传 floor=2 回读 1.0） |
| **Bug S-C** 保存无反馈 | ❌ 存档选择面板保存后固定 1 秒无条件回主菜单，成功/失败无任何提示 → 玩家无法判断保存结果 |
| **Bug S-D** 部署问题 | ❌ 正在运行的 :8000 服务是旧代码（uvicorn reload 未触发）；修复后必须重启服务才生效 |

## 2. 修改内容

### 服务端

| 文件 | 改动 |
|---|---|
| [schemas/save.py](server/app/schemas/save.py) | SaveCreate 新增 `current_floor/play_time/kill_count/gold_collected`（Optional，向后兼容） |
| [services/save_service.py](server/app/services/save_service.py) | create_save 使用请求携带的进度字段（缺省回退默认值） |

### 客户端

| 文件 | 改动 |
|---|---|
| [save_service.gd](client/scripts/services/save_service.gd) | `_on_api_success` 的 OP_SAVE/OP_CREATE 分支新增 `_refresh_saves_entry()`：保存成功后用响应刷新内存存档列表（同槽位替换/新槽位追加，JSON 浮点字段规整为 int）；`get_save_by_slot` 比较用 int() |
| [game_scene.gd](client/scenes/game/game_scene.gd) | `_on_save_selected`：等待真实保存结果（save_saved/save_error 信号，最长 10 秒）→ 面板+HUD 显示"保存成功/保存失败:原因"→ 成功才退出；失败停留 3 秒可重试 |
| [save_selection.gd](client/scripts/ui/save_selection.gd) | 新增 `set_status(text)` 供外部显示保存中/结果 |
| [main_scene.gd](client/scenes/main/main_scene.gd) | "继续游戏"防御兜底：内存列表为空时先 `load_saves()` 拉取再判断（防跨场景过期） |

### 测试与工具

| 文件 | 说明 |
|---|---|
| [test_save_integration.gd](client/tests/test_save_integration.gd) | **新增**真实链路集成测试（真实 HTTP+服务端+MySQL）：登录→保存(slot1)→新槽位保存(slot3 404→POST)→保存后立即查询→load_saves 刷新→回读→set_current_save 恢复链→首次保存楼层/时长持久化，共 11 检查项 |
| [test_save_api.py](server/app/tests/test_save_api.py) | **新增**服务端存档 API pytest 5 项（TestClient+真实 MySQL，自动注册唯一测试用户并清理） |
| [cleanup_test_saves.py](server/tools/cleanup_test_saves.py) | 测试存档清理工具 |

## 3. 测试结果（全部真实运行）

| 验证 | 结果 |
|---|---|
| 服务端 pytest app/tests（新增 5 项：进度字段持久化/回读/409/更新+404/默认值兼容） | ✅ 5 passed |
| 服务端 pytest ai/tests 全量回归 | ✅ 143 passed |
| 客户端集成测试 test_save_integration（真实 HTTP） | ✅ **11/11** |
| 客户端 9 套回归（16/2001/20/13/11/12/35/19/11） | ✅ 全绿 |
| Godot headless 启动 | ✅ 0 脚本错误 |

## 4. 真实运行证据（用户要求的三项）

### 4.1 保存成功日志（客户端真实 HTTP 链路）

```
[SaveService] _on_api_success called, op: create
[SaveService] Save success response
[SaveService] Memory save list refreshed (slot 3 appended)
[SaveService] Memory save list refreshed (slot 1 appended)
```

### 4.2 数据库记录（MySQL 直查，修复后）

```
id  user_id  save_name           slot  current_floor  play_time  kill_count  gold_collected
20  11       integration-slot1   1     4              321        9           40
21  11       integration-slot3   3     2              60         3           10
```

（首次保存 POST 路径的楼层/时长/击杀/金币全部真实落库）

### 4.3 重启恢复验证（修复后，真实执行）

1. PUT 写入标记存档 `current_floor=6, play_time=999` → 200
2. 完整停止游戏服务进程（taskkill）→ curl 连接拒绝
3. 全新启动游戏服务 → `/health` 正常
4. GET 回读 → `current_floor:6, play_time:999, kill_count:9, gold_collected:40` ✅ 数据完整

> 部署注意：修复前 :8000 上运行的旧代码进程（uvicorn reload 未触发热重载）已停止，**当前运行的游戏服务为修复后代码**。若用户自行重启服务，直接用原启动命令即可（`cd server && venv/Scripts/python.exe main.py`）。

## 5. 人工验收步骤（需 8000 游戏服务 + MySQL 运行，数据已清空为干净状态）

1. 登录进入游戏（新游戏，自动分配槽位 1）→ 打到第 2 层 → 按 ESC 暂停 → 点"退出到主菜单" → 存档面板点"槽位 1" → 面板显示**"保存成功！"** → 自动回主菜单。
2. 主菜单点"继续游戏" → 进入游戏 → HUD 显示**第 2 层**（非第 1 层）、等级/HP/金币与保存时一致。
3. 再次进游戏打 1~2 个房间 → ESC → 暂停菜单点"保存" → 显示**"保存成功"**。
4. 完全关闭游戏客户端和服务端 → 重新启动服务端 → 启动客户端 → 登录 → "继续游戏" → 楼层与属性与第 3 步保存时一致。
5. 通过标准：以上四步全部符合预期，无脚本报错，无"没有存档/无存档槽位"提示。

## 6. 已知剩余（不在本任务范围）

- 房间级进度（哪些房间已完成）不存档——继续游戏后当前楼层重新生成（既有设计，可接受）
- 三槽位 UI 仅槽位 1 走通主流程（槽位 2/3 面板可存，继续游戏按钮只读槽位 1）
- kill_count/gold_collected 客户端仍无累加来源（保存链路已通，数据源待 TASK 后续）

---

**TASK-026 实施完成。按流程停止，等待人工验收后进入下一任务（B: 房间生成顺序）。**

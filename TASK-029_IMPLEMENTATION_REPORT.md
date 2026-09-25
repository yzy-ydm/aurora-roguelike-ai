# TASK-029_IMPLEMENTATION_REPORT — GameFlow 生命周期与存档系统最终稳定性修复

> 日期：2026-09-24
> 状态：**实施完成，等待人工验收**（按要求未提交 git）

---

## 1. 修改文件列表

| # | 文件 | 改动 |
|---|---|---|
| 1 | client/scripts/managers/game_flow_controller.gd | **生命周期重设计**（新状态枚举 + 统一 reset_flow + begin_authentication） |
| 2 | client/scenes/login/login_scene.gd | 登录界面 _ready 强制 reset_flow；登录发起前 begin_authentication；登录/流程失败回 IDLE |
| 3 | client/scenes/main/main_scene.gd | 登出时 reset_flow |
| 4 | client/scenes/game/game_scene.gd | _exit_to_menu 统一 reset_flow；保存面板槽位解析（默认沿用当前槽位） |
| 5 | client/scripts/managers/game_state_manager.gd | 新增 resolve_save_slot()（槽位规则） |
| 6 | client/tests/test_gameflow_reset.gd | **新增**：生命周期重置 11 检查项（真实 HTTP 全链） |
| 7 | client/tests/test_save_slot_persistence.gd | **新增**：槽位持久化 12 检查项（真实 HTTP） |

## 2. 问题根因

### Bug 1: 重新登录无法进入游戏（ABORT at state 5）

**根因**：GameFlowController 是 autoload 单例，`_flow_state` 在进入游戏后为 IN_GAME(旧枚举=5)。退出游戏回主菜单 / 登出回登录界面时**没有任何路径重置它** → 重新登录 start_game() 命中旧状态 → `ABORT - flow_state is not IDLE or READY, current: 5` → 永远无法再进入游戏。

### Bug 2: 存档槽位从 1 变 2

**根因**：退出流程的存档选择面板三个槽位均可点选，`_on_save_selected(slot)` 直接把面板点击的槽位传给 SaveService → 点槽位 2 就创建 slot2 游离存档（LOAD_SUCCESS count=1 指 slot1 已有档，SAVE START slot=2 是误点面板槽位 2 的结果）。

## 3. 修改方案

### 生命周期重设计（不绕过、不加全局变量）

新状态机（FlowState 枚举重命名+扩展）：

```
IDLE(0) → AUTHENTICATING(1) → LOADING_PLAYER(2) → LOADING_SAVE(3)
→ LOADING_RESOURCE(4) → READY(5) → PLAYING(6)
退出保存: SAVING(7) → reset_flow() → IDLE
失败:     ERROR(8) → reset_flow() → IDLE
```

- `reset_flow()`：**统一退出出口**（清状态到 IDLE + 清错误信息），在四条路径调用：
  1. game_scene._exit_to_menu（返回主菜单，含死亡退出）
  2. GameFlowController.exit_game 完成/失败（含非游戏状态直接退出）
  3. main_scene 登出
  4. **login_scene._ready 兜底**（登录界面 = 生命周期起点，任何残留状态在此归零）
- `begin_authentication()`：登录请求发起前进入 AUTHENTICATING（login_scene 两处登录按钮调用）。
- start_game() 合法前置状态 = IDLE/READY/AUTHENTICATING；ERROR 自动 reset 后重试；**其它状态一律拒绝并明确日志**（不 force-continue）。配合 login_scene 的 flow_error 回调里 reset_flow → 异常状态自愈为可重试的 IDLE。
- 登录/注册请求失败回调 → reset_flow（失败可立即重试，无 AUTHENTICATING 残留）。
- `reset()` 旧接口保留，转调 reset_flow()。

### 存档槽位规则

- GameStateManager.resolve_save_slot(requested)：
  - 已有当前槽位（进入游戏时分配的，默认 1）→ **一律沿用当前槽位**；
  - 无当前槽位 → 返回请求值（默认 1）。
- game_scene._on_save_selected 经 resolve_save_slot 解析后保存，面板点选其它槽位时提示"默认使用槽位 N 保存..."。
- 效果：slot1 已有档 → 永远继续 slot1，**不自动创建 slot2/3**。

## 4. 测试结果（全部真实运行）

| 套件 | 结果 |
|---|---|
| test_gameflow_reset（新）| ✅ 11/11 —— 含关键 T5：模拟 PLAYING → 统一退出 → **重新登录再次完整进入游戏（旧代码在此 ABORT）** |
| test_save_slot_persistence（新）| ✅ 12/12 —— 槽位规则 4 项 + 真实保存 slot1 + 重载后 slot1 在/slot2 不存在 + 重新进入恢复楼层与 HP |
| 其余 16 套客户端测试 | ✅ 全绿（16/2001/20/13/11/12/35/19/11/8/6/8/11/8/4/7） |
| test_save_integration（真实 HTTP）| ✅ 12/12 |
| 服务端 pytest app/tests + ai/tests | ✅ 5 + 143 |
| Godot headless 启动 | ✅ 0 脚本错误 |

## 5. 人工验收步骤（服务端已运行、存档数据已清空）

**验收1（重新登录）**：
1. 登录 → 进入游戏 → 玩 1 分钟 → ESC → 退出到主菜单 → 点"退出登录"回登录界面。
2. **再次登录** → 应正常进入游戏（修复前：卡死无法进入）。
3. 再重复一遍"退出→登出→登录"流程，确认稳定。

**验收2（槽位）**：
1. 新游戏打到第 2 层 → ESC → 退出到主菜单 → 存档面板**故意点槽位 2** → 提示"默认使用槽位 1 保存..." → 保存成功（日志 `[SAVE] SUCCESS slot=1`，**无 slot=2**）。
2. 继续游戏 → 第 2 层恢复。

**验收3（死亡后流程）**：
1. 故意死亡 → 返回主菜单 → 继续游戏 → "没有有效存档"。
2. 再登录进游戏正常。

**通过标准**：三项全部符合预期、无脚本报错、日志中无 `ABORT`、无 `SAVE START slot=2`。

---

**TASK-029 实施完成。未提交 git，等待人工验收。**

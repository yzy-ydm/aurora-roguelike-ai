# TASK-003_REPORT — 修复事件房玩家物理处理错误

> 任务等级：LEVEL-2（事件房流程模块修改）
> 验证方式：代码检查 + 无头事件房流程测试 + 无头启动检查 + 历史回归测试（未运行完整游戏流程，符合任务约束）

## 1. 问题原因

**报错**：进入事件房时游戏崩溃：

```
Invalid call. Nonexistent function 'set_physics_processing' in base 'CharacterBody2D (player_controller.gd)'
调用栈: game_scene.gd:871 @ _show_event_panel() ← game_scene.gd:819 @ _handle_event_room()
       ← game_scene.gd:605 @ _on_fm_room_entered() ← floor_manager.gd:205 @ enter_room()
       ← game_scene.gd:1007 @ _on_exit_portal_entered()
```

**根因**：Godot 4 API 命名不对称。开启/关闭物理帧处理的方法是 `set_physics_process(bool)`，**不存在** `set_physics_processing()`。旧代码在 `_show_event_panel()` 暂停玩家时误用了不存在的 API 名，导致进入事件房即崩溃。

排查了全部 4 处相关调用（game_scene.gd 869/871/872/916/917 行）：

| 调用 | 方法名 | 结论 |
|---|---|---|
| 读取处理状态 | `is_physics_processing()` | ✅ Godot 4 合法 API（仅 getter 叫这个名字），无需修改 |
| 暂停玩家 | `set_physics_processing(false)` | ❌ 不存在 → 崩溃点 |
| 恢复玩家 | `set_physics_processing(true)` | ❌ 不存在 → 修复后必崩的隐藏炸弹 |

## 2. 修改文件

| 文件 | 修改 |
|---|---|
| `client/scripts/player/player_controller.gd` | 新增 `set_control_enabled(enabled: bool)` 封装方法：启用/关闭物理帧与输入处理；关闭时清零速度、中断冲刺与击退（`_is_dashing=false`、`_knockback_velocity=ZERO`、`_knockback_timer=0`）。恢复时玩家从静止状态重新开始 |
| `client/scenes/game/game_scene.gd` | `_show_event_panel()`：删除错误的 `set_physics_processing(false)` + `set_process_input(false)` + `was_physics` 捕获，改为 `player.set_control_enabled(false)`；`_apply_event_choice()`：删除 `was_physics: bool = true` 参数，恢复段改为 `player.set_control_enabled(true)` |
| `client/tests/test_event_room.gd` | **新增**永久回归测试（2 组共 16 项断言，含"全部断言已执行"护栏） |

## 3. 修改内容

### 3.1 修复方式（不新增系统，只封装正确 API）

player_controller.gd 新增：

```gdscript
## 设置玩家控制开关（TASK-003: 事件面板等UI弹出时禁用控制，关闭后恢复）
## 注意: Godot 4 正确API是 set_physics_process / is_physics_processing，
## 不存在 set_physics_processing（曾导致事件房崩溃）
## 禁用时: 关闭物理帧与输入处理，清零速度并中断冲刺/击退 → 恢复时玩家从静止状态开始
func set_control_enabled(enabled: bool) -> void:
	set_physics_process(enabled)
	set_process_input(enabled)
	if not enabled:
		velocity = Vector2.ZERO
		_is_dashing = false
		_knockback_velocity = Vector2.ZERO
		_knockback_timer = 0.0
```

game_scene.gd 事件房流程改为：

- 面板打开：`player.set_control_enabled(false)` → 物理帧停、输入停、速度清零、冲刺/击退中断；
- 选项应用：奖励/风险生效、HUD 状态更新；
- 面板关闭：`player.set_control_enabled(true)` → 物理帧与输入恢复，玩家从静止状态恢复操作；
- 1.5 秒后 `_complete_current_room("event_completed")` → 出口传送门出现。

### 3.2 为什么用封装而不是直接改名

- 玩家暂停/恢复的语义不止一个 API 调用（物理帧 + 输入 + 速度 + 状态），散落在 game_scene 里容易再次写错；
- 把正确 API 写进 player_controller 一处，调用方只表达意图（`set_control_enabled(false)`），未来任何 UI 面板（商店、升级等）都可以复用；
- 玩家已有的 `_die()`/`revive()` 使用正确 API 且逻辑独立，未改动。

### 3.3 测试说明

`test_event_room.gd` 两处脚手架要点（测试自身踩坑记录）：

1. **不能在成员初始化器里 load 真实脚本**：测试脚本实例化早于 autoload 注册，`player_controller.gd` 引用的 `GameStateManager`（autoload）全局名尚不存在 → 编译失败。必须在测试函数体内（autoload 已加载后）再 load。
2. **game_scene.gd 继承 Node2D**，测试宿主节点必须用 `Node2D.new()`；Godot 4.7 中父类 @onready 由 implicit_ready 触发（子类空 `_ready` 不会阻止），缺失节点报错为无害噪音，注入桩在 ready 后覆盖即可。

## 4. 测试结果

| 测试 | 结果 |
|---|---|
| 无头启动检查（`--headless --quit`） | ✅ 零脚本错误 |
| 新增 `test_event_room.gd`（真实 player_controller + 真实 game_scene 事件房流程） | ✅ **16/16**（15 项断言 + 护栏） |
| 回归 `test_reward_system.gd`（TASK-001） | ✅ 12/12 |
| 回归 `test_reward_spawn_position.gd`（TASK-002） | ✅ 11/11 |
| 静态检查：全项目 `set_physics_processing` 调用 | ✅ 0 处（仅剩 3 处注释说明，无实际调用） |

新测试覆盖点：控制开关切换（物理帧/输入标志）、禁用时速度清零+冲刺/击退中断、启用时恢复、事件面板打开→标题显示→奖励生效→控制恢复→完成提示→延迟后房间完成。

## 5. 影响范围

- **事件房流程**（唯一行为变化点）：进入事件房不再崩溃，面板期间玩家冻结，完成后恢复；
- 新增 `set_control_enabled()` 为公开方法，其他系统**未调用**，无副作用；
- **不影响**：房间生成算法、奖励系统、战斗系统、AI 系统、服务端；
- 玩家原有 `_die()`/`revive()` 逻辑未改动。

## 6. 人工验收步骤（约 5 分钟）

1. **操作步骤**：① 正常启动游戏并登录（test001/test123456）② 进入游戏前进，通过战斗房进入一个事件房（楼层中带有事件标记的房间）③ 观察进入瞬间是否崩溃、面板是否弹出 ④ 等待面板完成，尝试移动/跳跃/攻击
2. **观察目标**：进入事件房**不崩溃**；面板弹出期间角色静止（无漂移）；面板显示事件标题与选项；完成后约 1.5 秒出口传送门出现；角色恢复正常移动、跳跃、攻击
3. **通过标准**：进房不崩溃 + 面板期间角色静止 + 完成后角色可正常操作 = 通过；任何崩溃或完成后角色无法移动 = 不通过（截图/日志发我）

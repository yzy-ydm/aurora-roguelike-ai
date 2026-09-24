# TASK-017.7_IMPLEMENT_REPORT — 战斗闭环修复实施报告

> 日期：2026-09-24
> 状态：**实施完成，等待人工验收**
> 前置分析：[TASK-017.7_ANALYSIS_REPORT.md](TASK-017.7_ANALYSIS_REPORT.md)

---

## 1. 修改文件列表

| # | 文件 | 改动内容 |
|---|---|---|
| 1 | [monster_ai.gd](client/scripts/enemy/monster_ai.gd) | 4 处坐标统一为 `global_position`：① 距离计算（:90）② `_do_chase` 追击 dx（:138）③ `_do_attack` 接近 dx（:166）④ fallback 攻击击退参数（:192） |
| 2 | [monster_entity.gd](client/scripts/enemy/monster_entity.gd) | `attack_range: 50.0 → 60.0`（默认近战射程，Boss 同享） |
| 3 | [damage_system.gd](client/scripts/combat/damage_system.gd) | `on_monster_attack_player` 击退方向基准改传 `attacker.global_position` |
| 4 | [monster_node.gd](client/scripts/enemy/monster_node.gd) | `attack_player` fallback 路径击退参数改传 `global_position` |
| 5 | [monster_balance_config.gd](client/scripts/models/monster_balance_config.gd) | 新增速度配置：normal 60~90 / elite 70~120 / boss 90~130 px/s；楼层成长每层 +5%（独立于属性缩放），上限 +50%；`get_range()`/`generate_monster_stats()` 输出 `speed` 字段 |
| 6 | [room_spawner.gd](client/scripts/world/room_spawner.gd) | `_apply_monster_clamp()` 增加一行 `monster.speed = stats["speed"]`，速度配置真正写入怪物实例 |
| 7 | [test_monster_ai.gd](client/tests/test_monster_ai.gd) | **新增**测试（13 检查项 + 元护栏） |

**未修改**（遵守指令）：奖励系统、AI 生成系统、平台系统、存档系统、Boss 技能系统、数据库、楼层生成器。

---

## 2. 修改原因

### 2.1 坐标空间混用（战斗闭环断裂根因）

怪物 `position` 是房间内 local 坐标（挂 `Room_<id>` 下，±330 范围），玩家 `position` 是世界坐标。第 1 战斗房两者差 700~1030px，永远大于追击阈值 300 → AI 永远 IDLE → 怪物不移动、不攻击。修复后全部距离/方向/击退计算使用 `global_position`，双方同处世界坐标系。

### 2.2 怪物速度失衡

修复前怪物 speed 数据为 3~15 px/s（玩家 200），即使坐标修好也是"蠕动"。现在由 MonsterBalanceConfig 统一生成（与 HP/ATK/DEF 同一配置体系）：normal 60~90（约为玩家 1/3，追击感明显但玩家可风筝）、elite 70~120（更有压迫感），每层 +5% 封顶 +50%（保证怪物永远追不上玩家）。**不动数据库**，仅客户端配置。

### 2.3 攻击射程 50→60

玩家移速 200，旧射程 50px 下玩家 0.5s 即可穿过攻击窗口，怪物几乎打不中。微调至 60 保证近距离攻击可命中。**未新增接触伤害**（按指令，留后续怪物AI任务）。

### 2.4 击退方向修复

`damage_system`/`monster_node` 原传递 `attacker.position`（房间 local），与玩家世界坐标相减后击退方向错乱。统一传 `attacker.global_position`，被攻击时玩家会沿"远离怪物"的正确方向被击退。

---

## 3. 测试结果

### 3.1 新增测试 test_monster_ai.gd：✅ 14/14 通过（13 检查项 + 元护栏）

| 测试 | 内容 | 结果 |
|---|---|---|
| T1 跨房间坐标 | 怪物 local(-300,282) 挂房间(x=1240) vs 玩家世界(700,280)：AI 进入 CHASE 而非 IDLE，velocity 生效 | ✅ |
| T2 追击方向 | 玩家在左 → velocity.x < 0；玩家在右 → velocity.x > 0 | ✅ |
| T3 攻击触发 | 距离 55px（旧射程 50 之外、新射程 60 之内）攻击落地、玩家掉血；1.5s 冷却内不重复攻击 | ✅ |
| T4 伤害来源坐标 | DamageSystem 路径下 attacker_position == 怪物 global_position（世界坐标） | ✅ |
| T5 速度配置 | normal[60,90] / elite[70,120] / 楼层5成长[72,108] / room_spawner clamp 真正写入 MonsterData | ✅ |

### 3.2 旧测试全量回归：✅ 零失败

| 测试套件 | 结果 |
|---|---|
| test_reward_system | 12/12 ✅ |
| test_reward_spawn_position | 11/11 ✅ |
| test_event_room | 16/16 ✅ |
| test_room_type_dispatch | 19/19 ✅ |
| test_room_lifecycle | 35/35 ✅ |
| test_floor_generation | 2001/2001 ✅ |

### 3.3 其他验证

| 验证 | 结果 |
|---|---|
| Godot headless 启动（`--headless --quit`） | ✅ 零脚本错误，正常启动至登录界面 |
| 服务端 pytest（tests/ + ai/tests/） | ✅ 143 passed |

---

## 4. 人工验收步骤

> 启动方式：`cd server && venv/Scripts/python.exe main.py`（:8000，需 MySQL）+ 客户端正常启动登录。

1. **怪物追击**：进入第 1 层任一战斗房，站在怪物 300px 以内 → 观察怪物**主动向玩家方向移动**（速度明显可见，约玩家 1/3~1/2）。
2. **怪物攻击**：站到怪物身边 1 秒以上 → 玩家 HUD 血量下降、出现红色伤害数字、玩家被击退且方向为**远离怪物**。
3. **攻击节奏**：被攻击后 0.8 秒内连续贴脸 → 伤害间隔约 1.5 秒（冷却 + 无敌），不会每帧掉血。
4. **战斗房闭环**：击杀全部怪物 → 房间清空 → 奖励生成 → 拾取 → 出口出现 → 进入下一房（本链路未改动，回归验证）。
5. **Boss 房**：Boss 会主动接近玩家并攻击（Boss 复用同一 AI）；击杀 Boss → 正常结算下一层。
6. **精英怪**：精英房怪物速度更快（70~120），追击压迫感更强。

**通过标准**：以上 1~6 全部符合预期，且无脚本报错、无怪物瞬移/穿墙异常。

---

## 5. 已知剩余问题（不在本任务范围）

| # | 问题 | 说明 | 计划 |
|---|---|---|---|
| 1 | BossController.update() 零调用点 | Boss 技能释放/阶段转换是死代码；本次修复后 Boss 由 MonsterAI 驱动为"会动的普通大怪"，技能仍不释放 | 后续"怪物AI完善"任务 |
| 2 | 玩家双重减伤 | DamageSystem 防御公式减伤后，PlayerStats.take_damage 又减一次 defense，玩家实际承伤低于设计值 | 需单独平衡确认后修 |
| 3 | 怪物无接触伤害 | 玩家快速穿过怪物可能不被打中（攻击窗口 60px） | 后续"怪物AI完善"任务评估 |
| 4 | 怪物碰撞掩码 263 含无效 256 位 | 实际无害（子弹靠自身 mask 检测怪物），语义错位 | 后续战斗任务顺带修 |
| 5 | M-01 怪物可生成在平台内部 | 导致无法击杀→房间软锁，本任务未动生成逻辑 | **下一优先级：生成合法性任务** |
| 6 | C-01/C-02 平台无单向碰撞/嵌入地面 | 怪物追击会被平台阻挡（无跳跃），平台下打转 | 平台碰撞任务（顺序第 2） |
| 7 | 怪物追击穿不过平台 | 与 #6 同源，平台单向碰撞修复后怪物也可穿过平台底部 | 平台碰撞任务 |

---

**实施完成。按流程停止，等待你人工验收后再进入下一任务。**

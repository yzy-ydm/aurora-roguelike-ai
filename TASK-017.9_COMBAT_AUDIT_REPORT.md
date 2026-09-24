# TASK-017.9_COMBAT_AUDIT_REPORT — 战斗系统全面审计报告

> 日期：2026-09-24
> 状态：**仅审计，未修改任何代码，等待确认后实施**
> 触发背景：TASK-017.8 后人工测试——怪物正常追击，但石头傀儡（精英）持续攻击导致玩家 HP 快速归零、战斗无法推进

---

## 1. 四大审计块结论

### 一、怪物攻击系统（monster_ai.gd / monster_node.gd）

| 检查项 | 结论 |
|---|---|
| 攻击触发条件 | ✅ 存在：`distance ≤ attack_range(60)` 且冷却结束（[monster_ai.gd:158](client/scripts/enemy/monster_ai.gd#L158)） |
| 攻击距离 | ✅ attack_range=60（TASK-017.7 调整）；进入 ATTACK 状态阈值 100 |
| 攻击 CD | ✅ **存在**：`ATTACK_COOLDOWN_TIME = 1.5s`，每怪独立计时 |
| 是否可能每帧攻击 | ❌ **不存在每帧攻击 bug**。CD 逻辑正确（攻击后置 1.5s，逐帧递减） |
| 攻击状态机 | ✅ 完整：IDLE/CHASE/ATTACK/DEAD，受击硬直期间 AI 挂起 |

**但存在两个机制缺陷**：
- **A1 无攻击前摇**：`_perform_attack()` 判定距离后**伤害瞬间生效**（[monster_ai.gd:173-185](client/scripts/enemy/monster_ai.gd#L173-L185)），玩家无预警、无法靠走位躲避（唯一躲避方式是全程保持 60px 外）
- **A2 多怪独立 CD 集火**：2~4 只怪各自 1.5s 周期独立攻击 → 玩家承受的攻击**时间上互相错开**，形成"持续攻击"节奏

### 二、玩家受伤系统（player_controller.gd）

| 检查项 | 结论 |
|---|---|
| 受伤无敌时间 | ✅ 存在：`INVINCIBLE_TIME = 0.8s` + 闪烁 |
| 击退 | ✅ 存在：强度 150、持续 0.15s（位移约 22px），方向已由 TASK-017.7 修复为世界坐标 |
| 死亡状态处理 | ✅ 完整：`_die()` → `player_dead` 信号 → GameOver 面板 + 停怪物 + 自动存档；`_is_dying` 防重复 |
| 连续受伤保护 | ⚠️ **保护不足**：无敌 0.8s < 怪物攻击间隔 1.5s → **每次攻击都在无敌窗口外命中**，无敌形同虚设；多怪错开攻击时伤害密度更高 |

### 三、玩家攻击链（weapon / bullet / damage 系统）

```
点击鼠标左键 → _try_attack → weapon.try_attack
  → 冷却检查(fire_rate=0.2s) → _fire: 子弹出生(owner+20px) + setup + 入容器
  → bullet(Area2D, mask=Wall+Enemy) 飞行
  → body_entered: 怪物 → DamageSystem.on_bullet_hit
  → calculate_damage(玩家atk+武器伤害, 目标def) → monster.take_damage
  → MonsterEntity.health -= → die() → MonsterNode.on_death
  → RoomSpawner.on_monster_died → _current_monsters.erase
  → alive_monsters 减少 → 全灭 → all_monsters_dead ✓
```

**链路完整（TASK-001 已验证），但存在三个输出端缺陷**：
- **B1【P1】攻击输入是"单发点击"模型**：`_input` 只在鼠标按下事件时打一发（[player_controller.gd:231-235](client/scripts/player/player_controller.gd#L231-L235)），**按住不放不会连发**。理论射速 5 发/秒，实际需每秒狂点 5 次 → 被围殴时玩家实际输出远低于理论值
- **B2【P1】暴击率硬编码 0.1**（[weapon.gd:137](client/scripts/combat/weapon.gd#L137)）：`PlayerStats.get_crit_rate()` 无消费点（TASK-007 分析 G2 已记录）
- **B3【P1】平射子弹会被低平台挡住**：子弹撞任何 StaticBody2D 即销毁（[bullet.gd:181-183](client/scripts/combat/bullet.gd#L181-L183)），战斗房低平台（py∈[272,288]）高度正覆盖平射弹道（y≈280）→ 平台后怪物打不到，玩家必须跳过平台，与怪物追击叠加更被动

### 四、战斗流程（CombatManager / RoomSpawner / RoomState）

```
进房 → ENTERING → 生成怪物(平台感知✓) → COMBAT(0/N进度) → 击杀全部
  → all_monsters_dead → CLEARED → combat_cleared(deferred)
  → 清房反馈 + spawn_rewards(平台感知✓) → 房间 REWARD 状态
  → 全部拾取 → complete_reward_phase → room_completed
  → COMPLETED → 创建唯一出口 → 下一房
```

**流程完整无软锁**（TASK-005/006/008 已层层验证）。**"战斗无法正常推进"的真实根因不是流程阻塞，而是玩家先死**（死亡 → GameOver）。流程侧唯一观察项：玩家死亡自动存档走的是已知断裂的存档链路（S-01/S-02，存档任务处理，无害）。

---

## 2. 当前问题列表（含本次现象根因）

| # | 等级 | 问题 | 位置 |
|---|---|---|---|
| P0-1 | **P0** | **生存失衡：玩家 100 HP 无法承受精英怪集火**。石头傀儡 ATK 被 clamp 至 12~25/发（[monster_balance_config.gd](client/scripts/models/monster_balance_config.gd) ELITE_ATK），2 只精英 × 1.5s 独立 CD ≈ 每秒 1.3 次 × 平均 18 伤害 ≈ **24 dps → 约 4 秒死亡**；普通房 2~4 只怪集火 ≈ 14 dps → 约 7 秒死亡 | 数值组合（见 §3） |
| A1 | P1 | 怪物攻击无前摇，伤害瞬间生效，无法躲避 | monster_ai.gd |
| A2 | P1 | 多怪独立 CD 时间上错开，形成持续掉血节奏 | monster_ai.gd |
| B1 | P1 | 玩家攻击单发点击，不能按住连发，实际 DPS 远低于理论 | player_controller.gd |
| B2 | P1 | 暴击率硬编码 0.1，成长加成无效（TASK-007 G2 遗留） | weapon.gd |
| B3 | P1 | 平射子弹被低平台（py∈[272,288]）遮挡 | bullet.gd |
| D1 | P2 | 双重减伤：DamageSystem 公式减伤 + PlayerStats.take_damage 再减 defense，数值混乱 | damage_system.gd + player_stats.gd |
| D2 | P2 | 玩家无敌 0.8s 与怪物攻击间隔 1.5s 错开，无敌保护实际无效 | player_controller.gd |
| D3 | P3 | 玩家出生点 y=298 嵌入地面 18px（物理自动推出，已知 P-01） | world_coordinate.gd |
| D4 | P3 | 怪物硬直仅 0.1s 且被子弹间隔 0.2s 覆盖，硬直减速效果有限（对玩家有利项，非问题） | monster_node.gd |

---

## 3. 根因分析（本次现象的完整因果链）

```
TASK-017.7 修复（怪物会追、会打） ← 期望行为
        +
① 精英怪 ATK 12~25（clamp 后） vs 玩家初始 100 HP / 0 防御
② 2~4 怪独立 CD 1.5s → 攻击时间错开 → "持续攻击"体感
③ 玩家无敌 0.8s < 攻击间隔 → 每次攻击均命中
④ 击退仅 22px，怪物 70~120 速度 0.2~0.3s 贴回
⑤ 玩家输出端：单发点击模型 + 子弹被平台遮挡 → 实际 DPS 低
        ↓
玩家无法在死亡前清空房间 → HP 快速归零 → GameOver → "战斗无法推进"
```

**结论：不是单一 bug，而是 TASK-017.7 激活怪物进攻能力后，暴露的攻防数值/机制失衡。** 战斗流程本身无软锁。

---

## 4. 建议修复顺序（最小改动，不新增系统）

| 顺序 | 修复 | 方案 | 预期效果 |
|---|---|---|---|
| 1 | **玩家攻击按住连发**（B1） | player_controller 增加 `_physics_process` 中检测 `Input.is_mouse_button_pressed(LEFT)` 持续调用 `_try_attack()`（保留武器冷却），移除/保留点击逻辑均兼容 | 玩家输出恢复理论值（5 发/秒），是"战斗可推进"的关键 |
| 2 | **怪物攻击前摇**（A1） | `_perform_attack` 前加 0.3s 准备期（怪物停止移动/闪烁预警），期间玩家可走位脱离 60px 范围 → 攻击落空 | 玩家获得躲避窗口，承受伤害大幅下降 |
| 3 | **攻击 CD 延长**（A2） | `ATTACK_COOLDOWN_TIME` 1.5 → 2.5s | 承受 dps 降低 40% |
| 4 | **玩家无敌延长**（D2） | `INVINCIBLE_TIME` 0.8 → 1.0s | 连续受击有真实保护窗口 |
| 5 | **击退增强**（可选） | `KNOCKBACK_STRENGTH` 150 → 220 | 被击退后怪物贴回时间延长，配合前摇形成风筝空间 |
| 6 | B2 暴击率接线 / D1 双重减伤 | 顺带或留 TASK-007 / 单独数值任务 | 数值体系统一 |

> 6 之后建议人工实测再迭代数值（本报告给的 CD/前摇数值为起点，以手感验收为准）。

---

## 5. 预计修改文件

| 文件 | 改动 |
|---|---|
| [player_controller.gd](client/scripts/player/player_controller.gd) | 按住连发（~10 行）；INVINCIBLE_TIME 0.8→1.0；KNOCKBACK_STRENGTH 150→220 |
| [monster_ai.gd](client/scripts/enemy/monster_ai.gd) | ATTACK_COOLDOWN_TIME 1.5→2.5；攻击前摇 0.3s（~15 行，含准备期速度归零与预警状态） |
| [test_monster_ai.gd](client/tests/test_monster_ai.gd) | 扩展：前摇时序断言（准备期内不产生伤害）、新 CD 断言、连发模型断言（按住状态多次调用 try_attack 按武器冷却发弹） |

（B2/D1 按用户确认范围决定是否纳入本任务。）

---

## 6. 修改风险

| # | 风险 | 评估 |
|---|---|---|
| R1 | 前摇实现与受击硬直/死亡竞态 | 低。前摇期间被击杀 → 检查 `is_alive` 后取消攻击（参考 BossController 现有前摇写法 [boss_controller.gd:227-235](client/scripts/boss/boss_controller.gd#L227-L235)）；受击硬直期间 AI 本就挂起，无冲突 |
| R2 | 连发模型改变战斗手感 | 低。武器冷却 0.2s 保持不变，仅输入从"点击"变"按住"，属普遍横版射击标准操作 |
| R3 | CD 延长导致怪物威胁不足（矫枉过正） | 低~中。2.5s + 前摇 + 无敌 1.0s 组合可能偏保守——**以人工实测为准再微调**，代码常量集中便于调参 |
| R4 | 与 TASK-007（奖励选择）交集 | 无。本任务不触碰奖励/升级系统；B2 暴击率接线是否纳入需你确认 |
| R5 | 现有 8 套测试回归 | test_monster_ai.gd 的 T3 断言"冷却 1.5s 内不重复"需随新 CD 值同步更新（仅测试文件）；其余套件不涉及 |

---

**审计完成，未修改任何代码。等待你确认修复方案与范围（重点确认：① 是否按建议顺序 1~5 全部实施；② B2 暴击率接线是否纳入本任务）后进入实施。**

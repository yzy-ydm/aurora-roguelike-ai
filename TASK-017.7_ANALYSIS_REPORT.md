# TASK-017.7_ANALYSIS_REPORT — 战斗闭环修复 第一阶段分析

> 阶段：仅分析，**未修改任何代码**
> 目标：修复"怪物→玩家"方向的战斗闭环（怪物会动、会攻击、玩家会受伤）
> 日期：2026-09-24
> 状态：等待确认后进入实施

---

## 1. 当前怪物 AI 执行流程

### 1.1 驱动链（谁在每帧驱动怪物）

```
monster_node.gd::_physics_process(delta)          [每物理帧]
  ├─ 实体死亡检查 → 返回
  ├─ 受击硬直(_is_hit_stunned) → velocity=0, 返回
  ├─ 重力/落地/掉落保护(FALL_LIMIT=1000)
  ├─ _monster_ai.update(delta)        ← AI 决策与移动在此
  └─ move_and_slide()                 ← 应用 velocity
```

### 1.2 monster_ai.gd 状态机

```
enum AIState { IDLE, CHASE, ATTACK, DEAD }

update(delta):
  玩家死亡 → IDLE + velocity=0
  硬直中 → 跳过
  冷却计时递减
  distance = monster.position.distance_to(player.position)   ← ★问题核心
  _decide_state(distance):
      distance ≤ 100 (CHASE_DISTANCE)  → ATTACK
      distance ≤ 300 (IDLE_DISTANCE)   → CHASE
      else                              → IDLE
  _execute_state(distance):
      IDLE   → 不动
      CHASE  → velocity.x = sign(dx) * entity.speed（纯水平追击）
      ATTACK → distance ≤ attack_range(50) 且冷却(1.5s)结束 → attack_player()
               否则继续水平接近
```

### 1.3 怪物→玩家伤害链（链路本身存在、可复用）

```
monster_ai._perform_attack()
  → monster_node.attack_player(player)
    → DamageSystem.on_monster_attack_player(monster, player)
        attacker_attack = entity.get_attack()          # 已按楼层 clamp（5~15）
        target_defense  = player.get_player_data()["defense"]
        final = calculate_damage(attack, 0, defense, 0)
        → apply_damage_to_player(player, final, attacker.position)   ← ★击退方向错
          → player.take_damage(damage, attacker_position)
              PlayerStats.take_damage: actual = max(1, amount - defense)  ← 二次减伤(观察项)
              无敌 0.8s / 击退 / player_damaged 信号 → HUD 刷新
              死亡 → player_dead → GameScene GameOver
```

**结论：伤害计算与结算链路是通的，断点全在"AI 永远走不到攻击分支"上。**

---

## 2. 坐标问题确认（B-02 主因）

### 2.1 坐标系错位事实

| 对象 | 挂载位置 | position 含义 |
|---|---|---|
| 玩家 | `GameWorld/Player`（GameWorld 在原点） | **世界坐标** |
| 怪物 | `Room_<id>/MonsterContainer/Monster`（Room_<id> 位于 `room.position`） | **房间内 local 坐标**（±330 范围内） |

房间位置：第 n 层房间中心 x = n × 1240（[floor_generator.gd:82](client/scripts/world/floor_generator.gd#L82)）。

### 2.2 所有受影响代码点（坐标混用清单）

| # | 位置 | 代码 | 影响 |
|---|---|---|---|
| 1 | [monster_ai.gd:87](client/scripts/enemy/monster_ai.gd#L87) | `_monster_node.position.distance_to(_player_node.position)` | **主因**。第 1 战斗房：玩家世界 x≈700，怪物 local x∈[-330,330] → 距离 ∈ [370,1030]，永远 >300 → AI 永远 IDLE，追击/攻击分支永不执行 |
| 2 | [monster_ai.gd:190](client/scripts/enemy/monster_ai.gd#L190) | fallback `take_damage(damage, _monster_node.position)` | 击退方向错乱 |
| 3 | [monster_node.gd:258](client/scripts/enemy/monster_node.gd#L258) | fallback `take_damage(..., position)` | 同上 |
| 4 | [damage_system.gd:133](client/scripts/combat/damage_system.gd#L133) | `apply_damage_to_player(target, final_damage, attacker.position)` | **击退方向错乱**（玩家世界坐标 - 怪物 local 坐标 → 击退方向错误） |
| 5 | [boss_controller.gd:208/272/284/306/321/338/386](client/scripts/boss/boss_controller.gd#L208) | 多处 `.position.distance_to` | 见 §4（Boss 专属，本阶段只修其实际生效路径） |

**正确做法**：所有距离/方向计算统一使用 `global_position`。

### 2.3 验证推演（修复前后对比）

```
修复前：怪物 local(-300,282) vs 玩家 world(700,280) → dist≈1000 → IDLE（永远）
修复后：怪物 global(940,282) vs 玩家 global(700,280) → dist≈240 → CHASE（追击）
        玩家靠近到 dist<100 → ATTACK；dist<50 冷却结束 → 攻击
```

---

## 3. 攻击流程问题（除坐标外的叠加因素）

| # | 问题 | 证据 | 等级 |
|---|---|---|---|
| A1 | **速度严重失衡**：怪物 speed 3~15 px/s，玩家 200 px/s | DB 种子 speed 3~15（[insert_test_data.sql](database/sql/insert_test_data.sql)）；客户端默认 10（[monster_data.gd:18](client/scripts/models/monster_data.gd#L18)）；玩家 `MOVE_SPEED=200`（[player_controller.gd:18](client/scripts/player/player_controller.gd#L18)）。即使坐标修好，怪物也是"蠕动"，观感=不会动 | 必修 |
| A2 | **攻击窗口小**：进入 ATTACK 需距离≤100，实际开打需≤50（attack_range），冷却 1.5s；玩家 200px/s 冲过怪物约 0.5s 穿过攻击范围 → 大概率打空；**无接触伤害兜底** | [monster_ai.gd:33-34,103,158](client/scripts/enemy/monster_ai.gd#L33-L34) | 必修（射程微调），接触伤害留后续任务 |
| A3 | **击退方向错乱**（坐标 bug 衍生） | §2.2 表格 #2/#3/#4 | 随坐标修复一并修 |
| A4 | **双重减伤**：DamageSystem 按防御公式减伤一次，`PlayerStats.take_damage` 又 `amount - defense` 减第二次 → 玩家实际承受伤害低于设计值 | [damage_system.gd:26-42](client/scripts/combat/damage_system.gd#L26-L42) + [player_stats.gd:181-182](client/scripts/player/player_stats.gd#L181-L182) | 观察项，本阶段**不修**（修了玩家变脆，需单独平衡确认） |
| A5 | 怪物碰撞掩码 263 含无效 256 位 | [monster_node.gd:45](client/scripts/enemy/monster_node.gd#L45) | 实际无害，**本阶段不动**（留怪物AI任务） |

---

## 4. Boss 是否复用怪物 AI：**是（且是双重AI并存）**

### 4.1 确认事实

1. **Boss 出生即挂 MonsterAI**：[room_spawner.gd:302-308](client/scripts/world/room_spawner.gd#L302-L308) `spawn_boss()` 实例化的是 `monster.tscn`（挂 monster_node.gd），其 `_ready → _setup_ai()` **无条件**创建 MonsterAI 子节点。因此 Boss 的 `_physics_process` 每帧执行 `_monster_ai.update(delta)` —— **Boss 的实际移动行为由 MonsterAI 驱动**（受同一个坐标 Bug 影响：Boss 也不动）。
2. **BossController.update() 全工程零调用点**（grep 确认，唯一 `.update(delta)` 调用是 monster_node.gd:140 → MonsterAI）。即 BossController 的技能释放（`_try_use_skill`）、阶段转换（`_check_phase_transition`）、`_chase_player` 全是**死代码**。目前 Boss 能工作的只有：受伤通知（monster_node 主动通知）与死亡信号（TASK-001 已验证）。
3. BossController 内部同样存在坐标混用（§2.2 #5），但因其 update 无人调用，**当前无实际影响**。

### 4.2 对本次任务的影响

- 修复 MonsterAI 坐标后，**Boss 会自动获得追击/攻击行为**（作为"大号普通怪"，速度来自 `spawn_boss` 里 `monster_data.speed = int(boss_data.speed)` ≈ 54~66/层，也偏慢——建议顺手纳入速度配置，见 §7）。
- BossController 技能系统**不在本阶段修复**（属于"怪物AI完善"后续任务，避免范围膨胀）。

---

## 5. 需要修改文件

| 文件 | 改动点 | 性质 |
|---|---|---|
| [monster_ai.gd](client/scripts/enemy/monster_ai.gd) | ① 距离计算改 `global_position`（#1）② fallback 击退传 `global_position`（#2） | 必修（2 处，各 1~2 行） |
| [damage_system.gd](client/scripts/combat/damage_system.gd) | `on_monster_attack_player` 传 `attacker.global_position`（#4） | 必修（1 行） |
| [monster_node.gd](client/scripts/enemy/monster_node.gd) | fallback 击退传 `global_position`（#3） | 顺手修（1 行） |
| [monster_balance_config.gd](client/scripts/models/monster_balance_config.gd) | `generate_monster_stats()` 增加 `speed` 字段（normal 60~90 / elite 70~120，楼层轻微缩放） | 必修（速度重平衡，与现有 HP/ATK/DEF 统一管理原则一致） |
| [room_spawner.gd](client/scripts/world/room_spawner.gd) | `_apply_monster_clamp()` 加一行 `monster.speed = stats["speed"]` | 必修（1 行；时序安全：clamp 在 `set_monster_data` 之前，实体读取到的即新值） |
| [test_monster_ai.gd](client/tests/) | **新增**测试文件（见 §8） | 新增 |

**明确不修改**（遵守禁令）：boss_controller.gd、reward/奖励系统、AI 生成系统（ai_content_service 等）、floor_generator.gd、碰撞/平台、存档、数据库种子、怪物掩码。

---

## 6. 修改风险

| # | 风险 | 评估 |
|---|---|---|
| R1 | 怪物开始追击后，被平台挡住（怪物无跳跃能力，会在平台下打转） | 低。平台任务（C-01/C-02）在后续顺序中解决；本阶段行为可接受（怪物仍会沿地面追到平台边缘） |
| R2 | 速度提升（60~120）改变战斗难度，玩家风筝能力下降 | 低~中。玩家 200 仍是怪物 2~3 倍，风筝成立；数值取保守区间，实施后人工验收再调 |
| R3 | Boss 随 MonsterAI 修复开始主动追击（行为改变） | 正面变化（Boss 不再站桩）。Boss 速度 54~66 偏慢，建议 speed 配置顺带覆盖（见 §7 备注） |
| R4 | 击退方向修复后玩家被击退距离/方向变化 | 预期改善（原先方向错乱）；测试覆盖 |
| R5 | 现有 6 套测试回归 | 理论无冲突（它们不覆盖 monster_ai 的距离/速度逻辑），实施时全量回归验证 |
| R6 | 修复后攻击频率与无敌 0.8s 的交互（怪物 1.5s 冷却 > 无敌 0.8s → 每次攻击都可能命中） | 设计合理，无需处理 |

---

## 7. 最小修改方案

### 7.1 monster_ai.gd（2 处）

```gdscript
# ① update() 中（~L87）
var distance_to_player = _monster_node.global_position.distance_to(_player_node.global_position)

# ② _perform_attack() fallback（~L190）
_player_node.take_damage(damage, _monster_node.global_position)
```

> 说明：`_do_chase`/`_do_attack` 的 dx 计算用 `position.x` 差值，两个点同属"怪物 vs 玩家"差值，**方向符号不受坐标空间影响**（世界差值与 local 差值在 x 方向相同，因为房间 y 偏移 <100 且玩家/怪物同房间时玩家 global - 怪物 global 的 x 分量 = 正确方向）。最小方案只改"决定状态的距离"与"击退参数"；若想彻底统一，可将 `_do_chase/_do_attack` 的 dx 也换为 `global_position.x`（同任务一并改，行为一致，属防御性统一）。

### 7.2 damage_system.gd（1 处）

```gdscript
# on_monster_attack_player() 中（~L133）
apply_damage_to_player(target, final_damage, attacker.global_position)
```

### 7.3 monster_node.gd（1 处，防御性）

```gdscript
# attack_player() fallback（~L258）
player_node.take_damage(_monster_entity.get_attack(), global_position)
```

### 7.4 速度重平衡（配置统一，不动数据源）

monster_balance_config.gd 增加速度区间常量并在 `generate_monster_stats()` 返回：

```gdscript
const NORMAL_SPEED_MIN: float = 60.0
const NORMAL_SPEED_MAX: float = 90.0
const ELITE_SPEED_MIN: float  = 70.0
const ELITE_SPEED_MAX: float  = 120.0
# 楼层缩放: speed = base * (1.0 + (floor-1) * 0.05)，上限 +50%
# 返回字典增加 "speed": 按类型与楼层取值
```

room_spawner.gd `_apply_monster_clamp()` 加一行：

```gdscript
monster.speed = stats["speed"]
```

**数值理由**：玩家 200。normal 60~90（≈玩家 1/3，追击感明显但可风筝）；elite 70~120（更快更有压迫感）。楼层每层 +5%、封顶 +50%，与 HP 缩放风格一致。

> 备注（Boss）：`spawn_boss` 自建 MonsterData（speed≈54~66），不走 `_apply_monster_clamp`，Boss 修复坐标后能追但偏慢。**是否本轮顺带把 Boss speed 提升（如 80~110）**——可选 1 行改动，建议实施时询问或按默认不动（本报告默认**不动 Boss 数值**，行为改变最小化）。

### 7.5 攻击窗口微调（可选，低风险）

- `attack_range`（MonsterEntity 默认 50）→ 60：让贴脸攻击更容易命中。
- 决策阈值 CHASE_DISTANCE=100 / IDLE_DISTANCE=300 保持不动。
- **不新增接触伤害**（属新机制，留"怪物AI完善"任务）。

### 7.6 明确不做（本阶段）

- 不修 BossController 技能系统（update 无调用点是已知死代码，留后续任务）
- 不修双重减伤（A4，需单独平衡确认）
- 不修怪物碰撞掩码（A5）
- 不碰平台/生成合法性/存档/奖励/AI 生成

---

## 8. 测试方案

### 8.1 新增 test_monster_ai.gd（沿用现有 SceneTree + `_check` 元护栏脚手架）

| # | 检查项 | 内容 |
|---|---|---|
| T1 | 坐标修复 | 模拟"第 1 战斗房"场景：怪物挂 Room_<id>（位置 x=1240）下、玩家在 GameWorld 世界坐标 → AI 决策应为 CHASE（修复前为 IDLE）。断言 `get_ai_state() == CHASE` |
| T2 | 追击方向 | 玩家在右 → velocity.x > 0；玩家在左 → velocity.x < 0 |
| T3 | 攻击触发 | 距离 ≤ attack_range 且冷却结束 → 攻击桩计数 +1；冷却内不重复触发 |
| T4 | 击退方向 | DamageSystem.on_monster_attack_player → 玩家桩收到的 attacker_position 为怪物的**世界坐标**（≈ 房间偏移 + local） |
| T5 | 速度生成 | MonsterBalanceConfig.generate_monster_stats("normal"/"elite", 1) 的 speed ∈ 各自区间；楼层 5 的 speed > 楼层 1 |
| T6 | clamp 应用 | `_apply_monster_clamp` 后 monster.speed == stats["speed"] |
| T7 | 回归护栏 | 元护栏：断言总数与通过数一致（照 TASK-006 模式，护栏自身计数前评估 `_passed + 1`） |

已知脚手架坑（沿用经验）：`--script` 模式 autoload 引用须在测试函数内 load；含 await 的搭建子函数必须 await 调用；枚举经脚本资源访问失败，需实例访问。

### 8.2 回归

- 现有 6 套测试全量回归（reward 12 / reward_pos 11 / event 16 / dispatch 19 / lifecycle 35 / floor 2001）
- `Godot --headless --path client --quit` 启动验证无解析错误

### 8.3 人工验收步骤（实施后供用户实测）

1. 进入第 1 层任一战斗房 → 观察怪物**主动朝玩家移动**（不再是原地不动）
2. 站到怪物身边 1 秒以上 → 玩家 HUD 血量下降、出现伤害数字与击退（方向为"远离怪物"）
3. 击杀全部怪物 → 房间清空 → 奖励生成 → 拾取 → 出口出现 → 进入下一房
4. Boss 房 → Boss 主动接近玩家并造成伤害；击杀 Boss → 正常结算
5. 通过标准：怪物会动、会打人、被击退方向正确、房间完成链路不受影响

---

## 9. 结论

战斗闭环断点已全部定位：**根因是 monster_ai.gd 用 `position` 混算 local/世界坐标，导致追击/攻击分支永远不可达**；叠加怪物速度数值失衡（3~15 vs 200）使"修复坐标"仍不够。修复方案为 4 个生产文件的小改（累计约 6~8 行）+ 1 个新测试文件，不新增任何系统，不触碰禁止范围。Boss 复用同一 AI，修复后自动受益；BossController 技能系统为死代码，留后续"怪物AI完善"任务。

⏸️ **分析完成，未修改任何代码。等待确认后进入实施阶段。**

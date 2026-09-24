# TASK-018.0 战斗开局体验审计报告

> 日期：2026-09-24
> 状态：**仅审计，未修改任何代码，等待确认后实施**
> 触发背景：进入 combat 房后怪物几乎立即贴脸，玩家无反应时间，HP 快速归零（日志证明无每帧攻击 bug）

---

## 1. 当前怪物生成流程

```
floor_manager.enter_room → render_room（平台/地面/墙渲染，记录 _platform_rects）
  → game_scene._on_fm_room_entered
      ① player.global_position = player_spawn_pos(room.position)     ← 先传送玩家
      ② _room_spawner.spawn_monsters(content, room.position)          ← 再生成怪物
      ③ _combat_manager.start_combat(content) → ENTERING(0.1s) → COMBAT
  → RoomSpawner.spawn_monsters:
      for i in range(monster_count):   # combat 2~4 / elite 1~2
        monster_spawn_pos(room_center, i, total, platform_rects)      [TASK-017.8 平台感知]
          ├─ 槽位 x: total=2→[-130,130] / total=3→[-180,180] / total=4→[-210,210]（中央带）
          ├─ 第1层: 槽位±30 随机抖动 12 次（钳制 ±550），找平台安全点
          ├─ 第2层: 系统扫描 起点 = **-550** + index*8，步进 56，扫至 +550
          └─ 第3层: 兜底旧槽位
        y = 282（地面站立高度）
      → monster.tscn 实例化 → add_child（挂 Room_<id> 下）
      → **MonsterAI 立即激活**（set_monster_entity → initialize，无任何延迟）
```

## 2. 玩家出生流程

```
player_spawn_pos(room_center) = room_center + (-540, 298)   [world_coordinate.gd:223]
  即: 房间最左端（距左墙 100px），贴地
进入战斗房后玩家固定出生在此位置，怪物在其右侧生成。
```

## 3. 怪物距离玩家实际数值（贴脸证据）

| 数值 | 值 |
|---|---|
| 玩家出生 x | **-540**（local） |
| 怪物旧槽位带（total≥2） | [-210, 210]，与玩家最近距离 **330px**（旧逻辑不会贴脸） |
| TASK-017.8 第2层扫描起点 | **-550**（local） |
| **扫描起点与玩家出生点距离** | **10px** ← 贴脸 |
| ATTACK 决策阈值（CHASE_DISTANCE） | 100px |
| 攻击射程（attack_range） | 60px |
| 怪物速度 | 60~120 px/s（TASK-017.7 重平衡后） |
| 攻击冷却 | 1.5s（正常，无每帧攻击） |

**贴脸场景推演**：某怪第 1 层 12 次抖动失败（槽位附近 60px 窗口被平台覆盖，单怪概率约 5~15%，2~4 怪房间 10~30%）→ 进入第 2 层扫描 → 起点 -550 大概率安全（平台集中在中央带）→ **怪物出生在玩家左侧 10px 处** → 距离 10 < 100 → 生成后第一个物理帧即进入 ATTACK 状态 → 冷却 0 → **玩家进房约 1/60 秒后吃到第一发攻击**，之后怪物贴身持续攻击，玩家 200px/s 也甩不开 60px 射程的持续追击。

## 4. 导致贴脸的根因

| # | 根因 | 说明 |
|---|---|---|
| **R1（主因）** | **TASK-017.8 平台避让第 2 层扫描起点 -550 与玩家出生点 -540 几乎重合** | 旧逻辑怪物出生在中央带 [-210,210]（距玩家 ≥330px，安全）；平台避让扫描把出生点扩展到了玩家出生点一侧，**引入贴脸出生**。扫描起点本意是"从最左找空地"，但最左正是玩家出生区 |
| R2 | **怪物无出生保护期** | MonsterAI 在 spawn 瞬间激活，无任何延迟/觉醒期，第一个物理帧即可攻击 |
| R3 | **无 combat 保护时间** | CombatManager 的 ENTERING(0.1s) 只是状态显示，怪物 AI 不等待战斗状态，玩家无缓冲 |
| R4（放大） | 攻击无前摇（TASK-017.9 A1）+ 玩家单发点击输出受限（TASK-017.9 B1） | 贴脸后玩家既无法躲避（伤害瞬间生效）也无法快速反击（需每秒狂点 5 次） |

**结论：三个怀疑全部成立，其中"生成位置过近"是主因（TASK-017.8 的副产物），"缺少保护时间"与"攻击无预警"为放大因素。**

---

## 5. 最小修改方案（建议，等确认）

### 5.1 出生带隔离（修 R1，主修复）

`monster_spawn_pos` 扫描范围从 ±550 改为 **[-330, 550]**（world_coordinate.gd 约 3 处）：

- 怪物永远出生在玩家出生点（-540）右侧 **≥210px** 处 → 永不进入贴脸区（ATTACK 阈值 100、射程 60 都够不着）
- 210 < CHASE 阈值 300 → 玩家稍一移动怪物就会正常追击（保留 TASK-017.7 的追击体验）
- 扫描带宽度 880px > 平台最大总宽 800px（elite 4×200）→ **第 2 层扫描仍必能找到安全点**，TASK-017.8 防卡平台的保证不退化
- 右侧 550 安全（墙内侧面 630，怪物半宽 14；portal 是 Area2D 无物理体）

### 5.2 怪物出生保护期（修 R2，兜底）

MonsterAI 增加 `SPAWN_PROTECTION_TIME = 0.8s`：initialize 时启动计时，保护期内 update 直接返回（不决策、不攻击、不追击；重力仍由 monster_node._physics_process 正常处理，怪物正常落地）。

- 任何异常出生点/未来改动下，玩家进房后至少 0.8s 不会被打
- 零耦合（怪物自身计时，不动 CombatManager/战斗状态机）

### 5.3 可选（TASK-017.9 遗留，是否纳入由你确认）

| 项 | 内容 | 状态 |
|---|---|---|
| 攻击前摇 0.3s | 怪物攻击前停止+预警，玩家可走位躲避 | 建议纳入（5.2 的保护期结束后，前摇提供持续性的躲避窗口） |
| 按住连发 | 玩家输出恢复理论值 | 建议纳入（解决"玩家无法输出"） |

---

## 6. 预计修改文件

| 文件 | 改动 |
|---|---|
| [world_coordinate.gd](client/scripts/world/world_coordinate.gd) | 扫描范围常量与钳制：±550 → -330~550（~3 行） |
| [monster_ai.gd](client/scripts/enemy/monster_ai.gd) | 出生保护期计时器（~8 行）；（可选）攻击前摇 |
| [player_controller.gd](client/scripts/player/player_controller.gd) | （可选）按住连发 |
| [test_monster_spawn_safety.gd](client/tests/test_monster_spawn_safety.gd) | 扩展：出生点 x ∈ [-330, 550] 断言（并入现有检查） |
| [test_monster_ai.gd](client/tests/test_monster_ai.gd) | 扩展：保护期内 IDLE 不攻击；保护期结束恢复正常追击/攻击 |

## 7. 修改风险

| # | 风险 | 评估 |
|---|---|---|
| R1 | 扫描范围改动破坏 TASK-017.8 防卡平台保证 | 低。880px 扫描带 > 800px 平台总宽，数学上保证安全点存在；且现有 13 项出生点测试全量回归 |
| R2 | 出生保护期让"进房先手"消失，玩家开局太安逸 | 低。0.8s 很短，且保护期结束后怪物立即追击；数值可调 |
| R3 | 出生带右移后怪物集中在玩家右侧 | 无碍。玩家子弹向右射击正是面朝方向，反而更利于开局输出 |
| R4 | 与 TASK-017.9 建议（CD/无敌/击退）叠加后难度过低 | 本次只做开局保护，不动攻击数值——CD/无敌/击退调整是否实施由你另行确认 |
| R5 | 现有 8 套测试回归 | test_monster_spawn_safety 增加 x 范围断言后重跑；其余套件不涉及出生坐标范围 |

---

**审计完成，未修改任何代码。等待确认：① 按 5.1+5.2 最小方案实施；② 5.3 的两项（前摇/连发）是否一并纳入。**

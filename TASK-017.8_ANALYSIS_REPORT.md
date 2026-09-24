# TASK-017.8_ANALYSIS_REPORT — 战斗流程稳定性审计与怪物生成安全修复（第一阶段：仅分析）

> 日期：2026-09-24
> 状态：**仅分析，未修改任何代码，等待确认后实施**
> 前置背景：TASK-017.7 已修复怪物AI（追击/攻击/速度），人工测试发现怪物出生在平台内部导致战斗房永久阻塞（P0）

---

## 1. 当前问题根因

### 1.1 怪物生成流程（现状）

```
game_scene._on_fm_room_entered(room)                  [game_scene.gd:606]
  COMBAT/ELITE 且 content.monster_count > 0
  → room_spawner.spawn_monsters(content, room.position)
      ├─ _monster_container = RoomRenderer.get_monster_container()   ← 当前房间渲染节点的子容器
      └─ for i in range(monster_count):                               [room_spawner.gd:140]
           monster_data = _get_monster_by_config(...)                 ← HP/ATK/DEF/速度 clamp
           world_pos = WorldCoordinate.monster_spawn_pos(room_center, i, total)
                        └─ x_offset: total=1 时 ±[200,400]；total>1 时 -300+spacing*(i+1) ±30（±180 内）
                        └─ y = 282 固定（地面站立高度，local）
           local_pos = world_pos - room_center        ← 房间内坐标
           _spawn_single_monster(monster_data, local_pos)
                → 实例化 monster.tscn（28×28 碰撞体）
                → monster_node.position = local_pos   ← 挂 Room_<id>/MonsterContainer 下（Room_<id> 位于 room.position）
                → global = room.position + local ✓（与房间渲染坐标系一致，TASK-017.7 已确认）

Boss（独立路径）:                                     [room_spawner.gd:328]
  spawn_boss → boss_local_pos = Vector2.ZERO          ← 房间中心 (0,0)，即半空（房间中心 y=0，地面在 y=328）
                Boss 靠重力落到地面/中央平台
```

### 1.2 为什么怪物可以进入平台内部（根因链）

**根因①：怪物出生点完全不做平台避让。**
[world_coordinate.gd:53-78](client/scripts/world/world_coordinate.gd#L53-L78) `monster_spawn_pos()` 的 y 恒为 282（地面高度），x 只有槽位分布逻辑。TASK-002 给奖励做了平台感知三级采样，**怪物没有**。

**根因②：平台生成 y 带与怪物出生 y 带大面积重叠。**
战斗房平台（[room_renderer.gd:333-341](client/scripts/world/room_renderer.gd#L333-L341)）：`py = GROUND_Y(328) - randf_range(20, 56)` → 平台中心 y ∈ **[272, 308]**，厚 16px → 矩形 y ∈ [py-8, py+8] ⊆ [264, 316]。怪物身体 y ∈ **[268, 296]**（中心 282，高 28）。
相交条件：`py-8 ≤ 296 且 py+8 ≥ 268` → **py ∈ [260, 304]**，而平台生成范围是 [272, 308] → 89% 的平台在相交带内。

**根因③：x 范围大面积重叠。**
平台中心 px ∈ [-300, 300]、宽 200 → 矩形 x ∈ [-400, 400]。怪物中心 x ∈ [-330, 330]（total=1 时甚至到 ±400）。单怪与单平台 x 相交概率 ≈ 228/600 ≈ **38%**。

**叠加概率**（combat 房 3 平台、2~4 只怪）：
- 单只怪被任一平台覆盖 ≈ 0.76（x）× 0.89（y）≈ **68%**
- 房间内 2 只怪至少有 1 只卡住 ≈ **90%**；3 只怪 ≈ **97%**

**结论：几乎每场战斗房必然有怪物出生在平台内部。** 与人工测试"部分怪物生成在平台内部"完全吻合。

### 1.3 卡怪 → 软锁的完整链条

```
怪物出生在平台内部（与 StaticBody2D 重叠）
  → 怪物被平台物理卡住（AI 追击也无法脱出）
  → 玩家子弹撞任何 StaticBody2D（含平台）即销毁  [bullet.gd:181-183]
  → 子弹无法命中平台内的怪物
  → 怪物不死 → RoomSpawner._current_monsters 不空
  → all_monsters_dead 不触发 → CombatManager 停在 COMBAT
  → 无奖励、无出口 Portal → 房间永久阻塞（用户实测现象 1~6）
```

---

## 2. 影响范围

| 房间类型 | 是否有怪 | 受影响 |
|---|---|---|
| COMBAT（2~4 怪，3 平台） | ✅ | **严重**：约九成场次至少 1 怪卡平台 |
| ELITE（1~2 怪，4 平台） | ✅ | **严重**：4 平台 150~200 宽，重叠概率同量级 |
| BOSS（1 只） | ✅ | 出生 (0,0) 半空，落点被中央平台（[-150,150]×[278,326]）接住/可能卡在平台侧；当前不必然软锁但出生路径不合规 |
| REWARD/TREASURE/SHOP/EVENT/START | 无怪（validate_for_room_type 强制 0） | 不受影响 |

影响面：**所有战斗房/精英房/Boss 房**，即核心玩法主链路。属 P0。

---

## 3. 隐藏风险检查（A/B/C/D）

### A. 怪物出现在地图外 / 墙里 / 不可达位置

| 检查项 | 结论 |
|---|---|
| 地图外 | ✅ 安全。x ∈ [-400,400]（单怪）或 [-180,180]（多怪），左右墙在 ±640±10 |
| 墙里 | ✅ 安全。怪物半宽 14，最远 x=400+14=414 << 630 墙内侧面 |
| 玩家不可达位置 | ✅ 安全（修复后）。怪物 y=282 恒为地面；修复平台避让后全部出生在地面空地，玩家可达、子弹可命中 |
| 追击出界 | ✅ 安全。房间左右边界墙（StaticBody2D）阻挡；怪物互相碰撞（mask 含 Enemy 层）不会穿墙 |
| 掉落出界 | ✅ 已有 FALL_LIMIT=1000 掉落保护（[monster_node.gd:133](client/scripts/enemy/monster_node.gd#L133)） |

### B. 奖励生成卡平台 / 无法拾取

- ✅ TASK-002 已完成平台感知三级采样（地面带→可达平台顶面→系统扫描），战斗房地面带 800px 远大于平台总宽（600px），不可能全覆盖；不可达装饰平台（顶部 y≈20）被 `REWARD_PLATFORM_TOP_MIN_Y=226` 过滤。
- ✅ 时序正确：`_platform_rects` 由 render_room 填充、clear_room 清空；奖励生成总在渲染之后。
- 残余风险（极低）：理论兜底分支 `(0, ground_y)` 若恰好被平台覆盖会卡一个奖励，但前面三级采样 12 次 + 系统扫描使该分支实际不可达。**本任务不动奖励系统。**

### C. Portal 生成在不可达位置

- ✅ exit portal 位于 local (600, 298)，矩形 [580,620]×[268,328]，玩家站在地面（身体 [264,296]）走过即触发 body_entered，始终可达。
- ✅ 战斗/精英房平台 x ∈ [-400,400]，Boss 房平台 x ∈ [-500,500]，portal x=600 无遮挡。
- ✅ TASK-005/006 已保证：唯一出口（`_has_exit_portal` 去重）+ 无有效目标时紧急出口兜底 + 楼层完成走下一层传送门。**Portal 链路无软锁。**

### D. 房间完成逻辑其他软锁检查

| 场景 | 兜底 | 结论 |
|---|---|---|
| 怪物出生失败（无容器/无怪物数据）→ spawned=0 | game_scene 走 `_complete_current_room("no_monsters")`（TASK-005） | ✅ 无软锁 |
| 战斗房无怪内容（monster_count=0） | 同上 | ✅ |
| 怪物死亡通知丢失 | MonsterNode 双路径通知（父节点/RoomSpawner 查找）+ `_current_monsters.erase` 幂等 + `_is_dying` 防重复 | ✅ |
| 奖励全拾取信号 | TASK-001 精确移除节点引用，不会漏触发 | ✅ |
| 事件房 | 1.5s 后统一完成入口 | ✅ |
| Boss 死亡 | BossController 死亡信号 → CombatManager（TASK-001 已验证） | ✅ |
| 清怪后奖励生成失败（容器 null） | 容器由 render_room 创建，实战非 null；若失败则卡 REWARD——**低概率观察项**，本任务不动 | ⚠️ 极低 |
| **怪物卡平台（本任务）** | **无兜底** | ❌ **唯一高概率软锁** |

**结论：全链路除"怪物出生点平台避让"外，软锁兜底均已由 TASK-001/002/005/006 建立。本任务聚焦单点修复。**

---

## 4. 修复方案（最小修改，保持现有架构）

### 方案：怪物出生点平台感知采样（复用 TASK-002 现有基础设施）

`_platform_rects` 基础设施已存在（room_renderer 记录、room_spawner 已有 `_get_platform_rects()`），零新系统。

#### 4.1 world_coordinate.gd — `monster_spawn_pos()` 增加可选参数

```
monster_spawn_pos(room_center, index, total, platform_rects: Array[Rect2] = [])
```

- **默认 [] 保持完全向后兼容**（旧调用方与现有测试零影响）。
- 采样逻辑（y 恒 282 地面高度，怪物不会飞，不做平台顶面——保证行为一致：怪物永远在地面）：
  1. **槽位抖动采样**：在现有 x 槽位附近 ±30 抖动尝试 12 次，找第一个不与平台碰撞的点
  2. **系统化地面扫描兜底**：x 从 -550 步进 56 扫描到 +550（墙内侧面 ±630，怪物半宽 14 → ±550 安全），找第一个安全点
  3. **最终兜底**：返回原槽位点（地面带 1100px 空间 vs 平台总宽 ≤800px，实际不可达，防御性保留）
- 碰撞判定：怪物碰撞矩形 28×28（半宽 14）+ 安全间隙 4px → 判定点是否落在 `rect.grow(14+4)` 内（与 TASK-002 `_reward_pos_clear` 同思路）
- 新增常量：`MONSTER_HALF_WIDTH = 14.0`、`MONSTER_PLATFORM_CLEARANCE = 4.0`

#### 4.2 room_spawner.gd — 两处调用点传入平台矩形

1. `spawn_monsters()`：`WorldCoordinate.monster_spawn_pos(room_center, i, count, _get_platform_rects())`（1 行）
2. `spawn_boss()`：Boss 出生点从半空 (0,0) 改为地面安全点——同一函数 `monster_spawn_pos(room_center, 0, 1, _get_platform_rects())`，再转 local。Boss 房中央平台覆盖 x=0，采样会自动避让到安全地面点（例如 x≈±160~500 的空档）；极端兜底时保留旧行为（半空出生，靠重力落地，现状已可玩）

#### 4.3 明确不做（遵守限制）

- ❌ 不改房间平台生成布局（room_renderer 平台参数原样保留——嵌地平台问题属于平台任务）
- ❌ 不改 Floor 生成算法、AI 系统、数据库、存档系统
- ❌ 不新增接触伤害/新系统
- ❌ 不动奖励采样（TASK-002 已闭环）

---

## 5. 修改文件列表（预计）

| 文件 | 改动 | 量级 |
|---|---|---|
| [world_coordinate.gd](client/scripts/world/world_coordinate.gd) | `monster_spawn_pos` 加可选 `platform_rects` 参数 + 三级采样 + 2 个新常量 | ~40 行 |
| [room_spawner.gd](client/scripts/world/room_spawner.gd) | `spawn_monsters` 传平台矩形（1 行）；`spawn_boss` 出生点改安全采样（~3 行） | ~4 行 |
| [test_monster_spawn_safety.gd](client/tests/) | 新增测试（见 §6） | 新文件 |

---

## 6. 测试方案

### 6.1 新增 test_monster_spawn_safety.gd（沿用现有 SceneTree 脚手架）

| # | 检查项 | 内容 |
|---|---|---|
| T1 | 平台避让（核心） | 用真实 room_renderer 代码路径生成 combat 房 3 平台矩形 → 对 2~4 只怪采样 ≥100 次 → 断言**所有**生成点不与任一平台矩形 grow(18) 相交 |
| T2 | 精英房避让 | 真实 elite 房 4 平台矩形 → 采样 1~2 只怪 → 全部安全 |
| T3 | Boss 房出生 | 真实 boss 房 3 平台矩形 → Boss 采样点安全（不与平台相交）或（兜底分支）等于旧行为 |
| T4 | 坐标正确性 | 生成点 local 范围：x ∈ [-550, 550]、y == 282 恒地面；世界转换正确（world = room_center + local） |
| T5 | 向后兼容 | 不传 platform_rects（默认 []）→ 结果落在旧 x 槽位范围（total=1: ±[200,400]；total>1: ±[150,210] 槽位带），旧调用方行为不变 |
| T6 | 全房间覆盖 | 对 combat 房 2/3/4 怪各采样 50 次 → 每组生成点两两 x 互异且全部安全（防重叠回归） |

### 6.2 回归

- 现有 7 套客户端测试全量回归（含 TASK-017.7 的 test_monster_ai 14/14）
- Godot headless 启动零错误
- 服务端 pytest 143

### 6.3 人工验收步骤（实施后）

1. 连续进入 **≥5 个战斗房/精英房**：每房观察所有怪物**出生在地面空地**（不在平台内部、不悬空）
2. 每房用子弹击杀全部怪物 → `alive_monsters` 归零 → 奖励出现 → 拾取 → 出口 Portal 出现（**无一场阻塞**）
3. Boss 房：Boss 出生在地面（或平台上但可被击中），可正常击杀并结算下一层
4. 通过标准：5 场战斗房全流程无软锁、无怪物卡平台

---

## 7. 结论

- 根因明确：怪物出生点无平台避让（TASK-002 的奖励采样从未覆盖怪物）+ 平台 y 带 [272,308] 与怪物身体带 [268,296] 大面积重叠 → 约九成战斗房至少一怪卡在平台内 → 子弹无法穿透平台 → 房间永久阻塞。
- 全链路软锁兜底审计：除本问题外，出生失败/无怪/死亡通知/奖励拾取/事件房/Boss 死亡/出口唯一性均已有兜底，无其他高概率软锁。
- 修复为单点最小改动：复用现有 `_platform_rects` 基础设施给怪物出生点加三级采样，不改任何被禁止的系统。

⏸️ **分析完成，未修改任何代码。等待确认后进入实施。**
